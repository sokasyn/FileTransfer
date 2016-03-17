//
//  FileUploadViewController.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "FileUploadViewController.h"

@interface FileUploadViewController ()

@property (retain, nonatomic) NSMutableArray<UIImage *> *pickedImageArray;
//@property (retain, nonatomic) NSMutableArray<UIImage *> *uploadImageArray;
@property (retain, nonatomic) UIActivityIndicatorView *indicatorView;
@property (retain, nonatomic) UIView *indicatorBackgroundView;
@property (retain, nonatomic) NSBlockOperation *pickImageOperation;
@property (weak, nonatomic) UIAlertController *alertController;

// 子视图控制器
@property (strong, nonatomic) UIViewController *currentVC;
@property (strong, nonatomic) FileCollectionViewController *uploadingController;
@property (retain, atomic) NSMutableArray<NSMutableDictionary *> *uploadingTaskArray;
//@property (retain, nonatomic) NSMutableArray<UIImage *> *uploadingImageArray;
@property (strong, nonatomic) FileCollectionViewController *uploadedController;
@property (retain, nonatomic) NSMutableArray<NSMutableDictionary *> *uploadedTaskArray;
@property (retain, nonatomic) NSMutableArray* uploadedImageArray;
// 子视图加载的parentView
@property (strong, nonatomic) UIView *childView;
@property (assign, nonatomic) NSInteger currentChildIndex;

@end

@implementation FileUploadViewController

@synthesize socketIp = socketIp_;
@synthesize socketPort = socketPort_;
@synthesize pickedImageArray = pickedImageArray_;
//@synthesize uploadImageArray = uploadImageArray_;
@synthesize uploadTaskArray = uploadTaskArray_;
@synthesize indicatorView = indicatorView_;
@synthesize indicatorBackgroundView = indicatorBackgroundView_;
@synthesize pickImageOperation = pickImageOperation_;
@synthesize alertController = alertController_;

@synthesize currentVC = currentVC_;
@synthesize uploadingController = uploadingController_;
@synthesize uploadingTaskArray = uploadingTaskArray_;
@synthesize uploadedController = uploadedController_;
@synthesize uploadedTaskArray = uploadedTaskArray_;
@synthesize uploadedImageArray = uploadedImageArray_;
@synthesize childView = childView_;
@synthesize currentChildIndex = currentChildIndex_;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenRect = [mainScreen bounds];
    CGPoint center = CGPointMake(screenRect.size.width/2, screenRect.size.height/2);
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicatorView setCenter:center];
    indicatorView.hidesWhenStopped = YES;
    [self.view addSubview:indicatorView];
    [indicatorView startAnimating];

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_async(group,queue , ^{
        // 未来数据改为从sqlit中读取,故此处用多线程避免主线程阻塞
        [self initData];
    });
    
    dispatch_group_notify(group, queue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initComponents];
            [indicatorView stopAnimating];
        });
    });
}

- (void)viewWillAppear:(BOOL)animated{
    NSLog(@"Method [%@] begin.",NSStringFromSelector(_cmd));
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated{
    if (self.pickImageOperation && ![self.pickImageOperation isFinished]) {
        NSLog(@"取消选图片线程");
        [self.pickImageOperation cancel];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    NSLog(@"viewDidDisappear");
}

#pragma mark - IBActions
- (IBAction)barItemAddPressed:(id)sender{
    [self newUploadTask];
}

- (IBAction)segmentValueChanged:(id)sender{
    NSInteger index = self.uploadSegment.selectedSegmentIndex;
    if (index == self.currentChildIndex) {
        return;
    }
    switch (index) {
        case 0:{
            NSLog(@"切换到正在上传视图");
            [self replaceController:self.currentVC newController:self.uploadingController];
            [self addBarButonItem];
            break;
        }
        case 1:{
            NSLog(@"切换到已经上传视图");
            self.navigationItem.rightBarButtonItem = nil;
            [self replaceController:self.currentVC newController:self.uploadedController];
            break;
        }
        default:
            break;
    }
    self.currentChildIndex = index;
}

#pragma mark - initialize
// 数据初始化
- (void)initData{
    self.uploadTaskArray = [[NSMutableArray alloc] init];
    self.uploadingTaskArray = [[NSMutableArray alloc] init];
    self.uploadedTaskArray = [[NSMutableArray alloc] init];
    [self getTaskListFromDatabase];
}

// 懒加载uploadTaskArray
//- (NSMutableArray *)uploadTaskArray{
//    if (!uploadTaskArray_) {
//        uploadTaskArray_ = [[NSMutableArray alloc] init];
//    }
//    return uploadTaskArray_;
//}

// 懒加载 image picker 选取的媒体
- (NSMutableArray *)selectedImages{
    if (!pickedImageArray_) {
        pickedImageArray_ = [[NSMutableArray alloc] init];
    }
    return pickedImageArray_;
}

- (NSMutableArray *)uploadedImageArray{
    if (!uploadedImageArray_) {
        uploadedImageArray_ = [[NSMutableArray alloc] init];
    }
    return uploadedImageArray_;
}

// 从数据库中获取文件传输任务数据,并将数据分类,分派到相应的子控制器
// 有些任务由于断点续传,用户可能退出该界面,当再次进来时,需要把之前的任务一览,包括他们的状态,进度都要跟进的.
// 已经上传完成的任务,不需要做上传的各种操作和数据更新,只是数据的展示,所以,跟"正在上传"的任务区分开来便于做数据处理或是仅仅展示
- (void)getTaskListFromDatabase{
    NSArray *taskList = [[UserDefaultsManager defaultManager] getTaskList];
    for (NSDictionary *iter in taskList){
        NSMutableDictionary *taskInfo = [[NSMutableDictionary alloc] initWithDictionary:iter];
        NSInteger taskStatus = [[taskInfo objectForKey:kKeyTaskStuatus] integerValue];
        [self.uploadTaskArray insertObject:taskInfo atIndex:0];
        if (taskStatus == FileTransferTaskStatusFishined) {
            // 由于已经上传只是对数据的展示,不像正在上传视图需要对数据做过多的处理,在这里组织好数据
            // 顺序从晚到早,即最新上传完的放在展示在最前
            [self.uploadedTaskArray insertObject:taskInfo atIndex:0];
            NSString *imagePath = [taskInfo objectForKey:kKeyLocalFilePath];
            UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
            if (image) {
                [self.uploadedImageArray insertObject:[UIImage imageWithContentsOfFile:imagePath] atIndex:0];
            }else{
                // 如果该路劲下获取的image为nil(可能找不到该图片),则在数组中加入NSNull对象作为占位符以保证图片位置与任务信息的统一
                [self.uploadedImageArray insertObject:[NSNull null] atIndex:0];
            }
        }else{
            // 用addObject保持顺序,正在上传子视图在做处理的时候再做顺序以及任务关联等处理
            [self.uploadingTaskArray addObject:taskInfo];
        }
    }
}

// 组件初始化
- (void)initComponents{
    [self addBarButonItem];
    [self initIndicator];
    [self addBackgroundTap];
    [self initChildViewController];
}

- (void)addBarButonItem{
    UIBarButtonItem *barButtonItemAdd = [[UIBarButtonItem alloc] initWithTitle:@"新增"
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(newUploadTask)];
    self.navigationItem.rightBarButtonItem = barButtonItemAdd;
}



// 子视图控制器初始化
- (void)initChildViewController{
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat screenWidth = [screen bounds].size.width;
    CGFloat screenHeight = [screen bounds].size.height;
    
    CGFloat segmentY = self.uploadSegment.frame.origin.y;
    CGFloat segmentHeight = self.uploadSegment.frame.size.height;
    
    CGFloat y = segmentY + segmentHeight + 5;
    CGRect rect = CGRectMake(0, y, screenWidth, screenHeight - y );
    if (!self.childView) {
        self.childView = [[UIView alloc] init];
    }
    [self.childView setFrame:rect];
    [self.view addSubview:self.childView];
    UIColor *color = [UIColor colorWithRed:(170.0f/255.0f)
                                     green:(150.0f/255.0f)
                                      blue:(130.0f/255.0f)
                                     alpha:1.0f];
    self.childView.layer.borderColor = color.CGColor;
    self.childView.layer.borderWidth = 0.5f;
    
    // 正在下载
    [self addUploadingViewController];
    // 已经下载
    [self addUploadedViewController];
}

- (void)addBackgroundTap{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTap:)];
    [self.view addGestureRecognizer:tap];
    tap.numberOfTapsRequired = 1;
}

- (void)backgroundTap:(id)sender{
    NSLog(@"backgroundTap");
#warning test
    [self printTasListInUserdefaults];
}

// 发送socket设置变更广播
- (void)postNotificationSocketSettingChanged{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:self.socketIp,kKeySocketIp,
                              self.socketPort,kKeySocketPort, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSocketSettingChanged
                                                        object:nil
                                                      userInfo:userInfo];
}

#pragma mark -等待齿轮
- (void)initIndicator{
    if (!indicatorView_) {
        UIScreen *mainScreen = [UIScreen mainScreen];
        CGRect screenRect = [mainScreen bounds];
        CGPoint center = CGPointMake(screenRect.size.width/2, screenRect.size.height/2);
        indicatorView_ = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
//        [indicatorView_ setFrame:rect];
        indicatorView_.center = center;
//        indicatorView_.backgroundColor = [UIColor whiteColor];
        indicatorView_.color = [UIColor grayColor];
        indicatorView_.hidesWhenStopped = YES;
        if (!indicatorBackgroundView_) {
            indicatorBackgroundView_ = [[UIView alloc] initWithFrame:mainScreen.bounds];
            indicatorBackgroundView_.alpha = 0.1;
            indicatorBackgroundView_.backgroundColor = [UIColor whiteColor];
            [indicatorBackgroundView_ addSubview:indicatorView_];
        }
    }
}

- (void)showIndicator{
    // 正在访问相册,请稍后...
    [self.indicatorView startAnimating];
    [self.view addSubview:self.indicatorView];
//    [self.view addSubview:self.indicatorBackgroundView];
//    self.barButtonItemAdd.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
}

- (void)hideIndicator{
    [self.indicatorView stopAnimating];
    [self.indicatorView removeFromSuperview];
//    [self.indicatorBackgroundView removeFromSuperview];
//    self.barButtonItemAdd.enabled = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

#pragma mark - Add child view controller
// 正在上传子视图控制器
- (void)addUploadingViewController{
    self.uploadingController = [[FileCollectionViewController alloc] init];
    self.uploadingController.dataArray = self.uploadingTaskArray;
    self.uploadingController.delegate = self;
    self.uploadingController.fileCollectionType = FileCollectionTypeUploading;
    [self addChildViewController:self.uploadingController];
    [self.childView addSubview:self.uploadingController.view];
    self.currentVC = self.uploadingController;
}

// 已经上传子视图控制器
- (void)addUploadedViewController{
    self.uploadedController = [[FileCollectionViewController alloc] init];
    self.uploadedController.dataArray = self.uploadedTaskArray;
    self.uploadedController.imageArray = self.uploadedImageArray;
    self.uploadedController.delegate = self;
    self.uploadedController.fileCollectionType = FileCollectionTypeUploaded;
    [self addChildViewController:self.uploadedController];
}

//  子视图控制器的切换
- (void)replaceController:(UIViewController *)oldController newController:(UIViewController *)newController
{
    /**
     *            着重介绍一下它
     *  transitionFromViewController:toViewController:duration:options:animations:completion:
     *  fromViewController      当前显示在父视图控制器中的子视图控制器
     *  toViewController        将要显示的姿势图控制器
     *  duration                动画时间(这个属性,old friend 了 O(∩_∩)O)
     *  options                 动画效果(渐变,从下往上等等,具体查看API)
     *  animations              转换过程中得动画
     *  completion              转换完成
     */
    
    //    [self addChildViewController:newController];
    [self transitionFromViewController:oldController toViewController:newController duration:0.1 options:UIViewAnimationOptionTransitionNone animations:nil completion:^(BOOL finished) {
        if (finished) {
            [newController didMoveToParentViewController:self];
            [oldController willMoveToParentViewController:nil];
            //            [oldController removeFromParentViewController];
            NSLog(@"切换成功!");
            self.currentVC = newController;
        }else{
            NSLog(@"切换失败!");
            self.currentVC = oldController;
            
        }
    }];
}

#pragma mark - User Actions
- (void)newUploadTask{
    
    // 追加iOS 版本的适配
    /*
    UIDevice *device = [UIDevice currentDevice];
    NSString *name = [device name];
    NSLog(@"device name:%@",name);
    NSString *systemVersion = [device systemVersion];
    NSLog(@"device systemVersion:%@",systemVersion);
    */
    
    // 先从相册中选取上传的文件
//    [self showActionSheetForPickingFile];
    
/*
#ifdef __IPHONE_7_0
    [self showActionSheetForPickingFileOnIOS7];
#endif
  */  
#ifdef __IPHONE_8_0
    [self showActionSheetForPickingFile];
#endif
    
}

#pragma mark -选择图片Action sheet iOS 8.0以下
- (void)showActionSheetForPickingFileOnIOS7{
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"新增图片" delegate:self cancelButtonTitle:@"取消" destructiveButtonTitle:@"挑选图片" otherButtonTitles:@"拍摄", nil];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    switch (buttonIndex) {
        case 0:{
            NSLog(@"触发选择相册内图片");
            [self showIndicator];
            NSOperationQueue *queue = [[NSOperationQueue alloc] init];
            self.pickImageOperation = [NSBlockOperation blockOperationWithBlock:^{
                [self pickingMediaFromLibrary];
            }];
            [self.pickImageOperation setCompletionBlock:^{
                NSLog(@"self.pickImageOperation 执行完毕!");
            }];
            [queue addOperation:self.pickImageOperation];
            break;
        }
        case 1:
            NSLog(@"");
            break;
        default:
            break;
    }
}


- (void)finishPickingFile{
    NSLog(@"Method %@",NSStringFromSelector(_cmd));
    [self uploadTaskWithImageArray:self.pickedImageArray];
}

- (void)uploadTaskWithImageArray:(NSArray<UIImage *> *)imageArray{
    for (UIImage *image in imageArray) {
        [self uploadTaskWithImage:image];
    }
    [self.uploadingController.collectionView reloadData];
}

- (void)uploadTaskWithImage:(UIImage *)image{
    // 将图片缓存在本地后,获得该图片的路劲
    NSString *imagePath = [self cacheImage:image];
    if (!imagePath) {
        NSLog(@"无法缓存图片并获取该路劲");
        return;
    }

    // 用户点击新增的任务,不一定立即上传的,可能会退出该界面,需要持久化这部分数据,以当用户再次进来时可以初始化
    NSString *taskId = [[NSString alloc] initWithFormat:@"%d",[self getIncrementalKey]];
    NSMutableDictionary *taskInfo = [[NSMutableDictionary alloc] init];
    [taskInfo setValue:self.socketIp forKey:kKeySocketIp];
    [taskInfo setValue:self.socketPort forKey:kKeySocketPort];
    [taskInfo setValue:@"null" forKey:kKeySourceId];
    [taskInfo setValue:taskId forKey:kKeyTaskId];
    [taskInfo setValue:imagePath forKey:kKeyLocalFilePath];
    [taskInfo setValue:@"null" forKey:kKeyServerFilePath];
    [taskInfo setValue:@"0" forKey:kKeyPosition];
    [taskInfo setValue:@"1" forKey:kKeyTransferType];
    [taskInfo setValue:@"0" forKey:kKeyTaskStuatus];
    [taskInfo setValue:@"0.00" forKey:kKeyTaskProgress];
    [[UserDefaultsManager defaultManager] addTaskInfo:taskInfo];
    [self.uploadingTaskArray addObject:taskInfo];
    [self.uploadingController receiveTask:taskInfo];
}

- (NSInteger)getIncrementalKey{
    // 程序内部自管理的taskId自增,sourceId是开始上传后服务器返回的(通常情况下,是服务器表的一个主键)
    return [[UserDefaultsManager defaultManager] increaseKey];
}

#define kDirectoryUpload  @"Upload"
#pragma mark -缓存图片到程序cache目录
- (NSString *)cacheImage:(UIImage *)image{
    // 获取应用沙盒中的Caches目录
    NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = [cachesPaths objectAtIndex:0];  // /Library/Caches
    
    // 在该目录下建立名称为"Upload"文件夹用来储存上传的临时文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *cachesUploadPath = [cacheDir stringByAppendingPathComponent:kDirectoryUpload]; // /Library/Caches/Upload
    
    // 如果该目录不存在,则创建
    BOOL isDirectory;
    /* 该API与(BOOL)fileExistsAtPath:(NSString *)path的区别在于后者只要路劲存在(不管是文件还是文件夹,返回都是YES)
     * 前者返回值为YES,则只表示该路劲存在(可能是文件也可能是文件夹),如果方法执行后isDirectory为YES,则确定为文件夹,否则是个文件
     * 而如果返回值为NO,表示该路劲根本就不存在,则讨论isDirectory的值是毫无意义的
    */
    BOOL dirExist = [fileManager fileExistsAtPath:cachesUploadPath isDirectory:&isDirectory];
    if (!(dirExist == YES && isDirectory == YES)) {
#warning 错误的处理,设计程序的错误处理系统
        NSError *error;
        if(![fileManager createDirectoryAtPath:cachesUploadPath withIntermediateDirectories:YES attributes:nil error:&error]){
            NSLog(@"Upload目录创建失败!");
            return nil;
        }
    }
    
    // 为目标文件命名,并在目录下创建该文件
    NSString *imageName = [[NSString alloc] initWithFormat:@"%@.jpg",[self createNameForImage]];
    NSString *imagePath = [cachesUploadPath stringByAppendingPathComponent:imageName];
    NSLog(@"imagePath:%@",imagePath);
    
    // 判断该文件是否存在
    if (![self fileExistsAtPath:imagePath]) {
#warning 上传的图片有原图的设定,默认是压缩后的
        // 压缩图片并保存到caches/Upload目录下
        NSData *imageData = UIImageJPEGRepresentation(image, 0.1);
        BOOL createSuccess = [fileManager createFileAtPath:imagePath contents:imageData attributes:nil];
        if (createSuccess) {
            NSLog(@"在caches/Upload目录下创建文件成功");
        }else{
            NSLog(@"创建文件失败!");
        }
        
    }else{
        NSLog(@"该文件已经存在!");
    }
    return imagePath;
}

// 以精确到毫秒的时间为文件创建个名字,为确保唯一,让线程休眠1毫秒
- (NSString *)createNameForImage{
    NSDate *date = [NSDate date];
    NSString *template = @"yyyyMMddHHmmssSSS";
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:template];
    NSString *timeString = [dateFormat stringFromDate:date];
    [NSThread sleepForTimeInterval:0.001];
    return timeString;
}

#pragma mark 检查文件是否存在
- (BOOL)fileExistsAtPath:(NSString *)filePath{
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath] ? YES : NO;
}

#pragma mark -选择图片Action sheet iOS 8.0
- (void)showActionSheetForPickingFile{
    UIAlertController *imgSourceAlert = [UIAlertController alertControllerWithTitle:@"选取图片" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *selectFromPhoto = [UIAlertAction actionWithTitle:@"挑选几张" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSLog(@"触发选择相册内图片");
        [self showIndicator];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        self.pickImageOperation = [NSBlockOperation blockOperationWithBlock:^{
            [self pickingMediaFromLibrary];
        }];
        [self.pickImageOperation setCompletionBlock:^{
            NSLog(@"self.pickImageOperation 执行完毕!");
        }];
        [queue addOperation:self.pickImageOperation];
    }];
    UIAlertAction *takePhoto = [UIAlertAction actionWithTitle:@"现拍一张" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSLog(@"触发现拍一张");
        [self pickingMediaFromCamera];
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){
        NSLog(@"触发取消");
    }];
    [imgSourceAlert addAction:selectFromPhoto];
    [imgSourceAlert addAction:takePhoto];
    [imgSourceAlert addAction:cancel];
    [self presentViewController:imgSourceAlert animated:YES completion:nil];
}

#pragma mark -从图片库中选择媒体文件
- (void)pickingMediaFromLibrary{
    NSLog(@"Method %@ begin.",NSStringFromSelector(_cmd));
    if ([self.selectedImages count]) {
        NSLog(@"清空购物车,继续选购..");
        [self.selectedImages removeAllObjects];
    }
    // UIImagePickerControllerSourceTypeSavedPhotosAlbum
    // UIImagePickerControllerSourceTypeCamera
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    NSArray<NSString *> *array = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
    NSLog(@"availableMediaTypes:%@",array); // ("public.image","public.movie")
    
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        NSLog(@"支持访问相册");
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        NSLog(@"检查mediaTypes");
        NSArray<NSString *> *array = picker.mediaTypes; // 模拟器中是"public.image"
        NSLog(@"picker.mediaTypes:%@",array);
        
        NSLog(@"即将显示picker");
        if ([self.pickImageOperation isCancelled]) {
            NSLog(@"self.pickImageOperation isCancelled ,不往下走了,不必显示picker了");
            return;
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self hideIndicator];
            [self presentViewController:picker animated:YES completion:nil];
        }];
    }else{
        NSLog(@"请设置应用允许使用相册.");
    }
}

#pragma mark -从摄像机拍摄
- (void)pickingMediaFromCamera{
    NSLog(@"Method %@ begin.",NSStringFromSelector(_cmd));
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    NSArray<NSString *> *array = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
    NSLog(@"availableMediaTypes:%@",array); // 模拟器中是null
}

#pragma mark -UIImagePickerControllerDelegate
//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary<NSString *,id> *)editingInfo{
//    NSLog(@"didFinishPickingImage委托方法");
//    
//    NSLog(@"selected image description:%@",[image description]);
//    [self.pickedImageArray addObject:image];
//}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    NSLog(@"Method %@ begin.",NSStringFromSelector(_cmd));
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self.pickedImageArray addObject:image];
    [picker dismissViewControllerAnimated:YES completion:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self finishPickingFile];
        }];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    NSLog(@"Method %@ begin.",NSStringFromSelector(_cmd));
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - FileCollectionViewDelegate
- (void)fileCollectionViewDidLoad:(UICollectionView *)collectionView{
    CGRect rect = CGRectMake(0, 0, 320, self.childView.frame.size.height);
    [collectionView setFrame:rect];
    
    // 正在上传的任务才会处理socket网络配置的广播,已经上传完成的不会再发起socket事件了,不用处理该广播
    if (collectionView == self.uploadingController.collectionView) {
        NSLog(@"正在上传 子视图collection view加载完成");
        [self postNotificationSocketSettingChanged];
    }
    if (collectionView == self.uploadedController.collectionView) {
        NSLog(@"已经在上传 子视图collection view加载完成");
    }
}

#warning self.alertController 有时候会收到nil的异常
- (void)uploadingOccurredError:(ErrorInfo *)error{
    NSLog(@"FileUploadViewController occurredError委托通知");
    NSString *message = error.errorMessage;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"出现异常!"
                                                                            message:message
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定"
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action){
                                                           NSLog(@"点击了确定");
                                                           [self.alertController dismissViewControllerAnimated:YES completion:nil];
                                                       }];
        [errorAlert addAction:action];
        [self presentViewController:errorAlert animated:YES completion:nil];
    });
    
    
    /*
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.alertController) {
            self.alertController = [UIAlertController alertControllerWithTitle:@"出现异常!"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定"
                                                             style:UIAlertActionStyleCancel
                                                           handler:^(UIAlertAction *action){
                NSLog(@"点击了确定");
//                [self.alertController dismissViewControllerAnimated:YES completion:nil];
            }];
            [self.alertController addAction:action];
            [self presentViewController:self.alertController animated:YES completion:nil];
        }else{
            NSLog(@"弹出异常提示框已经存在");
        }
    });*/
}

- (void)uploadingTask:(FileTranserTask *)task didFinishUploadingImage:(UIImage *)image{
    // 从"正在下载"数组中移除该信息
    for (NSMutableDictionary *taskInfo in self.uploadingTaskArray) {
        NSString *taskId = [taskInfo objectForKey:kKeyTaskId];
        if ([task.taskId isEqualToString:taskId]) {
            // 往"已经下载"数组中加入该信息
            [self.uploadedTaskArray insertObject:taskInfo atIndex:0];
            self.uploadedController.dataArray = self.uploadedTaskArray;
            // 此处的arry的顺序要跟初始化的一致,如果初始化是addObject,这里就是addObject,如果是insertObject,这里就是insertObject
            [self.uploadedController.imageArray insertObject:image atIndex:0];
            
            // 此处移除uploadingTaskArray中相关的taskInfo为了保证数据的一致性
            [self.uploadingTaskArray removeObject:taskInfo];
            break;
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.uploadingController) {
            NSLog(@"刷新正在下载视图");
            [self.uploadingController.collectionView reloadData];
        }
        if (self.uploadedController) {
            NSLog(@"刷新已经下载视图");
            [self.uploadedController.collectionView reloadData];
        }
    });
}

#warning 测试完之后删除
#pragma mark -Test Method
     
- (void)printTasListInUserdefaults{
    [[UserDefaultsManager defaultManager] printUserDefaultsInfo];
}

- (void)iosVersionCheck{
    if ([self isiOS8OrAbove]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"title"
                                                                                 message:@"message"
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
                                                             [self.navigationController popViewControllerAnimated:YES];
                                                         }];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"title"
                                                             message:@"message"
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles: nil];
        [alertView show];
        [self.navigationController popViewControllerAnimated:YES];
    }
}


- (BOOL)isiOS8OrAbove {
    NSComparisonResult order = [[UIDevice currentDevice].systemVersion compare: @"8.0"
                                                                       options: NSNumericSearch];
    return (order == NSOrderedSame || order == NSOrderedDescending);
}

@end

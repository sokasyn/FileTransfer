//
//  FileCollectionViewController.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/4.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "FileCollectionViewController.h"

@interface FileCollectionViewController ()

// 有task才会去增加cell
//@property (retain, nonatomic) NSMutableArray<FileTranserTask *> *taskList;
@property (retain, nonatomic) NSMutableArray<FileTranserTask *> *fileTranserTaskList;
@property (retain, nonatomic) UIActivityIndicatorView *indicatorView;

@end

@implementation FileCollectionViewController

@synthesize collectionView = collectionView_;
@synthesize fileCollectionType = fileCollectionType_;
@synthesize dataArray = dataArray_;
@synthesize imageArray = imageArray_;
@synthesize delegate = delegate_;
@synthesize fileTranserTaskList = fileTranserTaskList_;
@synthesize indicatorView = indicatorView_;

#warning 正在上传和已经上传是否要区分
static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad {
    [super viewDidLoad];
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Register cell classes
//    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:reuseIdentifier];
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGRect screenRect = [mainScreen bounds];
    CGPoint center = CGPointMake(screenRect.size.width/2, screenRect.size.height/2 - 72);
    self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.indicatorView setCenter:center];
    self.indicatorView.hidesWhenStopped = YES;
    [self.view addSubview:self.indicatorView];
    [self.indicatorView startAnimating];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_async(group,queue , ^{
       [self initData];
    });
    dispatch_group_notify(group, queue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadCollectionView];
            if (self.delegate && [self.delegate respondsToSelector:@selector(fileCollectionViewDidLoad:)]) {
                [self.delegate fileCollectionViewDidLoad:self.collectionView];
            }
            [self.indicatorView stopAnimating];
        });
    });
}
/* 原子性数据,多线程安全
- (id)imageArray{
    if (!imageArray_) {
        imageArray_ = [[NSMutableArray alloc] init];
    }
    return imageArray_;
}*/

- (void)initData{
    // 由于正在上传的任务信息需要及时更新反馈,所以过程中需要做额外的工作
    // 已经上传的完成的任务,只需要做展示
    switch (self.fileCollectionType) {
        case FileCollectionTypeUploading:{
            [self initTaskListWithDataSource:self.dataArray];
            break;
        }
        case FileCollectionTypeUploaded:{
            // 已经上传 视图的数据只是简单的展示,无需做处理,父视图准备的数据就足够了
            /*
            for (NSMutableDictionary *taskInfo in self.dataArray) {
                NSString *imagePath = [taskInfo objectForKey:kKeyLocalFilePath];
                [self.imageArray insertObject:[UIImage imageWithContentsOfFile:imagePath] atIndex:0];
            }*/
            break;
        }
        default:
            break;
    }
}

/*
 * FileUploadViewController 传入的dataArray是从数据库中获取的,
 * 这些数据其中包含了在后台通过多线程正在上传中的,这部分数据动态持续更新的(内存中),对应的task应当直接从内存中获取;
 * 也有部分数据是用户新增但没还开始传.这部分数据则相当于静态的
 * collection view显示的每一个cell都以任务为基准,有一个任务,才有一个cell的展示.
 */
- (void)initTaskListWithDataSource:(NSMutableArray<NSMutableDictionary *> *)dataArray{
    for (NSMutableDictionary *taskInfo in dataArray) {
        [self receiveTask:taskInfo];
    }
}

- (void)receiveTask:(NSMutableDictionary *)taskInfo{
    NSString *taskId = [taskInfo valueForKey:kKeyTaskId];
    // 如果上传下载任务队列中有任务数据,则关联进来.因为存在用户退出画面,但是线程还在上传
    FileTranserTask *task = [FileTranserTask searchTaskInTaskQueueWithTaskId:taskId];
    NSString *localFilePath = [taskInfo valueForKey:kKeyLocalFilePath];
    if (!task) {
        NSString *serverFilePath = [taskInfo valueForKey:kKeyServerFilePath];
        task = [[FileTranserTask alloc] initWithLocalFilePath:localFilePath serverFilePath:serverFilePath];
        task.taskId = taskId;
        [task setFileTransferType:FileTransferTypeUpload];
        task.localFilePath = localFilePath;
        task.serverFilePath = [taskInfo valueForKey:kKeyServerFilePath];
        task.startPosition = [[taskInfo valueForKey:kKeyPosition] integerValue];
        task.taskStatus = [[taskInfo valueForKey:kKeyTaskStuatus] integerValue];
        task.progress = [[taskInfo valueForKey:kKeyTaskProgress] floatValue];
        task.socketIp = [taskInfo valueForKey:kKeySocketIp];
        task.socketPort = [[taskInfo valueForKey:kKeySocketPort] integerValue];
    }else{
        NSLog(@"队列中存在task,直接加入taskList.%@",task.taskId);
    }
    [self.fileTranserTaskList insertObject:task atIndex:0];
#warning 关于collection view 加载的图片比较多造成的顿卡问题
    [self.imageArray insertObject:[UIImage imageWithContentsOfFile:localFilePath] atIndex:0];
}

- (NSMutableArray<FileTranserTask *> *)fileTranserTaskList{
    if (!fileTranserTaskList_) {
        fileTranserTaskList_ = [[NSMutableArray alloc] init];
    }
    return fileTranserTaskList_;
}

#warning writable atomic property cannot pair a synthesized setter with a user defined getter
//- (NSMutableArray<NSMutableDictionary *> *)dataArray{
//    if (!dataArray_) {
//        dataArray_ = [[NSMutableArray alloc] init];
//    }
//    return dataArray_;
//}

- (void)loadCollectionView{
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat screenWidth = [screen bounds].size.width;
    CGFloat y = 0;
    CGFloat height = self.view.frame.size.height;
    CGRect rect = CGRectMake(0, y, screenWidth, height - y);
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    flowLayout.minimumLineSpacing = 5.0f;
    flowLayout.minimumInteritemSpacing = 1.0f;
    
    self.collectionView = [[UICollectionView alloc] initWithFrame:rect collectionViewLayout:flowLayout];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    UIColor *backgroudColor = [UIColor colorWithRed:(246.0f/255.0f) green:(246.0f/255.0f) blue:(246.0f/255.0f) alpha:1.0f];
    self.collectionView.backgroundColor = backgroudColor;
    self.collectionView.scrollEnabled = YES;
    self.collectionView.showsVerticalScrollIndicator = YES;
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:reuseIdentifier];
    [self.view addSubview:self.collectionView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(collectionViewTapped:)];
    [self.collectionView addGestureRecognizer:tap];
    tap.numberOfTapsRequired = 1;
}

- (void)collectionViewTapped:(id)sender{
    NSLog(@"collectionViewTapped");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark <UICollectionViewDataSource>
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger itemCount = 0;
    if (self.fileCollectionType == FileCollectionTypeUploading) {
        itemCount = [self.fileTranserTaskList count];
    }else{
        itemCount = [self.dataArray count];
    }
    return itemCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Method [%@] begin.",NSStringFromSelector(_cmd));
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    // ------------ cell 样式设置
    // 颜色渐变
    CGFloat clolorOffset = 150.0f;
    UIColor *color = [UIColor colorWithRed:(clolorOffset/255.0f)
                                     green:(clolorOffset/255.0f)
                                      blue:(clolorOffset/255.0f)
                                     alpha:1.0f];
    cell.layer.borderColor = color.CGColor;
    cell.layer.borderWidth = 0.5f;
    
    // 圆角设置
    CGFloat cornerRadius = 9;
    cell.layer.masksToBounds = YES;
    cell.layer.cornerRadius = cornerRadius;
    cell.layer.borderWidth = 0.5f;
    
    // ------------ ImageTransferTaskView 样式设置
    NSInteger index = indexPath.item;
    ImageTransferTaskView *taskView = [[ImageTransferTaskView alloc]initWithFrame:cell.contentView.frame];

    NSString *imagePath = [[NSString alloc] init];
    if (self.fileCollectionType == FileCollectionTypeUploading) {
        if (!self.fileTranserTaskList || [self.fileTranserTaskList count] == 0) {
            return nil;
        }
        FileTranserTask *task = [self.fileTranserTaskList objectAtIndex:index];
        task.delegate =  self;
        taskView.viewId = task.taskId;
        taskView.delegate = self;
        imagePath = task.localFilePath;
        [taskView updateProgress:task.progress];
        [taskView bindingImageTransferTask:task];
    }else if(self.fileCollectionType == FileCollectionTypeUploaded){
        if (!self.dataArray || [self.dataArray count] == 0) {
            return nil;
        }
        NSMutableDictionary *taskInfo = [self.dataArray objectAtIndex:index];
        imagePath = [taskInfo objectForKey:kKeyLocalFilePath];
        NSLog(@"已经下载 加载cell:taskId:%@, imagePath:%@",[taskInfo objectForKey:kKeyTaskId],imagePath);
        [taskView removeProgress];
    }
    UIColor *viewColor = [UIColor colorWithRed:(237.0f/255.0f)
                                         green:(237.0f/255.0f)
                                          blue:(237.0f/255.0f)
                                         alpha:1.0f];
    taskView.backgroundColor = viewColor;

#warning image的加载(性能有待优化)
    // image的加载(性能有待优化)
    UIImage *image = nil;
    if (self.imageArray && [self.imageArray count] > index) {
        image = [self.imageArray objectAtIndex:index];
    }else{
        image = [UIImage imageWithContentsOfFile:imagePath];
    }
    
    if (image && ![image isEqual:[NSNull null]]) {
        [taskView setImage:image];
    }
    
    for (id subView in cell.contentView.subviews) {
        [subView removeFromSuperview];
    }
    [cell.contentView addSubview:taskView];
    return cell;
}

#pragma mark -UICollectionViewDelegateFlowLayout
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    return CGSizeMake(100, 100);
//    return CGSizeMake(75, 75);
}

//定义每个UICollectionView 的 margin
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(5, 5, 5, 5);
//    return UIEdgeInsetsMake(4, 4, 4, 4);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 5.0;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 1.0;
}

#pragma mark <UICollectionViewDelegate>

/*
// Uncomment this method to specify if the specified item should be highlighted during tracking
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}
*/

/*
// Uncomment this method to specify if the specified item should be selected
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/

/*
// Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	return NO;
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	
}
*/
#pragma mark - 任务动作Action sheet
//弹出ActionSheet以供用户选择任务的动作(开始,暂停,继续,取消等)
- (void)showActionSheetForTaskAction:(FileTranserTask *)task{
    UIAlertController *taskActonAlter = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *uploadStart = [UIAlertAction actionWithTitle:@"开始上传"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action){
                                                            NSLog(@"触发开始上传");
                                                            [self taskStart:task];
                                                        }];
    UIAlertAction *uploadPause = [UIAlertAction actionWithTitle:@"暂停上传"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action){
                                                            NSLog(@"触发暂停上传");
                                                            [self taskPause:task];
                                                        }];
    UIAlertAction *uploadResume = [UIAlertAction actionWithTitle:@"继续上传"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action){
                                                             NSLog(@"触发继续上传");
                                                             [self taskResume:task];
                                                         }];
    UIAlertAction *uploadCancel = [UIAlertAction actionWithTitle:@"放弃上传"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action){
                                                             NSLog(@"触发放弃上传");
                                                             [self taskCancel:task];
                                                         }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    
    if (task.taskStatus == FileTransferTaskStatusReady ||
        task.taskStatus == FileTransferTaskStatusCanceled) {
        [taskActonAlter addAction:uploadStart];
        [taskActonAlter addAction:cancel];
    }
    
    if (task.taskStatus == FileTransferTaskStatusRunning) {
        [taskActonAlter addAction:uploadPause];
        [taskActonAlter addAction:uploadCancel];
        [taskActonAlter addAction:cancel];
    }
    if (task.taskStatus == FileTransferTaskStatusPaused ||
        task.taskStatus == FileTransferTaskStatusError) {
        [taskActonAlter addAction:uploadResume];
        [taskActonAlter addAction:uploadCancel];
        [taskActonAlter addAction:cancel];
    }
    if (task.taskStatus == FileTransferTaskStatusFishined) {
        NSLog(@"该任务是个已经完成的任务,不用弹出上传功能选项..");
        return;
    }
    [self presentViewController:taskActonAlter animated:YES completion:nil];
}

#pragma mark -开始任务
- (void)taskStart:(FileTranserTask *)task{
    NSLog(@"界面发送任务开始消息:%@",task.taskId);
    if (task) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [task start];
        });
    }else{
        NSLog(@"异常,无法启动该任务");
    }
}

#pragma mark -暂停任务
- (void)taskPause:(FileTranserTask *)task{
    if (task) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [task pause];
        });
    }
}

#pragma mark -继续任务
- (void)taskResume:(FileTranserTask *)task{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [task resume];
    });
}

#pragma mark -取消任务
- (void)taskCancel:(FileTranserTask *)task{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [task cancel];
    });
}

#pragma mark - ImageTransferTaskViewDelegate
// 点击事件委托
- (void)imageTransferTaskViewDidTapped:(FileTranserTask *)task{
    if (task.taskStatus == FileTransferTaskStatusFishined) {
        NSLog(@"该图片已经上传完成了的!");
#warning 一张已经上传完成的图片,点击效果是弹出对这张图片的查看器
    }else{
         NSLog(@"该图片还没上传完!");
        [self showActionSheetForTaskAction:task];
    }
}

// 长按事件委托
- (void)imageTransferTaskView:(ImageTransferTaskView *)taskView didLongPressed:(id)sender{
    NSLog(@"长按事件委托");
}

/* 更新进度后,将相应的task的信息更新,因为进度一直处于更新的状态,必须保证用户在滑动collection view的时候,能刷新这部分数据
 * 正在上传的任务才有进度的更新,故用taskList取代原先的dataArray
*/
- (void)imageTransferTask:(FileTranserTask *)task didUpdateProgress:(float)progress{
    for (FileTranserTask *iter in self.fileTranserTaskList) {
        if (iter.taskId == task.taskId) {
            iter.progress = task.progress;
            break;
        }
    }
}

#pragma mark - FileTransferTaskDelegate
/*
 * 正在上传的controller中能接收task的反馈,但是已经上传的controller并不能得到反馈
 * 需要给parent controller发送消息,并对已经上传的视图做相关的操作
 */
- (void)fileTranserTaskDidFinish:(FileTranserTask *)task{
    NSLog(@"FileCollectionViewController 上传完成委托通知 taskId:%@",task.taskId);
    for (int i = 0; i < [self.fileTranserTaskList count]; i++) {
        if ([self.fileTranserTaskList objectAtIndex:i].taskId == task.taskId) {
            [self.imageArray removeObjectAtIndex:i];
            break;
        }
    }
    [self.fileTranserTaskList removeObject:task];
    
    // 通过parent view controller去刷新,因为还要在"已经下载"视图中加入该任务信息
    if (self.delegate && [self.delegate respondsToSelector:@selector(uploadingTask:didFinishUploadingImage:)]) {
        NSLog(@"任务下载完成,通知父控制器刷新\"正在下载\"和\"已经下载\"视图.");
        UIImage *image = [UIImage imageWithContentsOfFile:task.localFilePath];
        [self.delegate uploadingTask:task didFinishUploadingImage:image];
    }
}

- (void)fileTranserTask:(FileTranserTask *)task occurredError:(ErrorInfo *)error{
    NSLog(@"FileCollectionViewController occurredError委托通知 taskId:%@",task.taskId);
    if (self.delegate && [self.delegate respondsToSelector:@selector(uploadingOccurredError:)]) {
        [self.delegate uploadingOccurredError:error];
    }
}

@end

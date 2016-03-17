//
//  ImagePickerController.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/21.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "ImagePickerController.h"

@interface ImagePickerController ()

@property (retain,nonatomic) UIImage *image;

//@property (retain,nonatomic) UIImagePickerController *picker; // 调查方向2
@end

@implementation ImagePickerController

@synthesize image = image_;
//@synthesize picker = picker_;
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initImagePicker];
    
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
- (void)initImagePicker{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
    NSLog(@"willShowViewController");
    NSLog(@"navigationController:%@",navigationController); // <UIImagePickerController: 0x7abe3000>
    NSLog(@"viewController:%@",viewController); // <PUUIAlbumListViewController: 0x7b3e9e00>
    NSLog(@"navigationController title:%@",[navigationController title]);
    NSLog(@"viewController title:%@",[viewController title]);
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
    NSLog(@"didShowViewController");
    NSLog(@"navigationController:%@",navigationController);  // <UIImagePickerController: 0x7abe3000>
    NSLog(@"viewController:%@",viewController);  // <PUUIAlbumListViewController: 0x7b3e9e00>
    NSLog(@"navigationController title:%@",[navigationController title]);
    NSLog(@"viewController title:%@",[viewController title]);
    [viewController setTitle:@"customized title"];
}

#pragma mark -UIImagePickerControllerDelegate
//- (void)imagePickerController:(UIImagePickerController *)picker
//        didFinishPickingImage:(UIImage *)image
//                  editingInfo:(NSDictionary<NSString *,id> *)editingInfo{
//    NSLog(@"didFinishPickingImage");
//}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    NSLog(@"didFinishPickingMediaWithInfo picker:%@",picker);
    NSString *title = picker.title;
    NSLog(@"title:%@",title);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    NSLog(@"imagePickerControllerDidCancel picker:%@",picker);
    [picker dismissViewControllerAnimated:YES completion:nil];
}





#pragma mark get/show the UIView we want
//Find the view we want in camera structure.
-(UIView *)findView:(UIView *)aView withName:(NSString *)name{
    Class cl = [aView class];
    NSString *desc = [cl description];
    
    if ([name isEqualToString:desc])
        return aView;
    
    for (NSUInteger i = 0; i < [aView.subviews count]; i++)
    {
        UIView *subView = [aView.subviews objectAtIndex:i];
        subView = [self findView:subView withName:name];
        if (subView)
            return subView;
    }
    return nil;
}

/*
 -(void)addSomeElements:(UIViewController *)viewController{
 //Add the motion view here, PLCameraView and picker.view are both OK
 UIView *PLCameraView=[self findView:viewController.view withName:@"PLCameraView"];
 [PLCameraView addSubview:touchView];//[viewController.view addSubview:self.touchView];//You can also try this one.
 
 //Add button for Timer capture
 [PLCameraView addSubview:timerButton];
 [PLCameraView addSubview:continuousButton];
 
 [PLCameraView insertSubview:bottomBarImageView atIndex:1];
 
 //Used to hide the transiton, last added view will be the topest layer
 [PLCameraView addSubview:myTransitionView];
 
 //Add label to cropOverlay
 UIView *cropOverlay=[self findView:PLCameraView withName:@"PLCropOverlay"];
 [cropOverlay addSubview:lblWatermark];
 
 //Get Bottom Bar
 UIView *bottomBar=[self findView:PLCameraView withName:@"PLCropOverlayBottomBar"];
 
 //Get ImageView For Save
 UIImageView *bottomBarImageForSave = [bottomBar.subviews objectAtIndex:0];
 
 //Get Button 0
 UIButton *retakeButton=[bottomBarImageForSave.subviews objectAtIndex:0];
 [retakeButton setTitle:@"重拍" forState:UIControlStateNormal];
 
 //Get Button 1
 UIButton *useButton=[bottomBarImageForSave.subviews objectAtIndex:1];
 [useButton setTitle:@"保存" forState:UIControlStateNormal];
 
 //Get ImageView For Camera
 UIImageView *bottomBarImageForCamera = [bottomBar.subviews objectAtIndex:1];
 
 //Set Bottom Bar Image
 UIImage *image=[[UIImage alloc] initWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"BottomBar.png"]];
 bottomBarImageForCamera.image=image;
 
 //Get Button 0(The Capture Button)
 UIButton *cameraButton=[bottomBarImageForCamera.subviews objectAtIndex:0];
 [cameraButton addTarget:self action:@selector(hideTouchView) forControlEvents:UIControlEventTouchUpInside];
 
 //Get Button 1
 UIButton *cancelButton=[bottomBarImageForCamera.subviews objectAtIndex:1];
 [cancelButton setTitle:@"取消" forState:UIControlStateNormal];
 [cancelButton addTarget:self action:@selector(hideTouchView) forControlEvents:UIControlEventTouchUpInside];
 }
 */

#pragma mark -调查方向2
/*
 
 - (void)showCustomizedImagePicker{
 //    ImagePickerController *picker = [[ImagePickerController alloc] init];
 //    picker.title = @"自定义的Image picker";
 //    [self presentViewController:picker animated:YES completion:^{
 //        NSLog(@"自定义的Image picker加载完成");
 //    }];
 }
 
 // Transform values for full screen support:
 #define CAMERA_TRANSFORM_X 1
 // this works for iOS 4.x
 #define CAMERA_TRANSFORM_Y 1.24299
 
 - (void)showImagePickerView{
 
 //     typedef NS_ENUM(NSInteger, UIImagePickerControllerSourceType) {
 //     UIImagePickerControllerSourceTypePhotoLibrary,
 //     UIImagePickerControllerSourceTypeCamera,
 //     UIImagePickerControllerSourceTypeSavedPhotosAlbum
 //     };
 
 // 检查支持的source type
 //    BOOL photoLibrary = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]; // YES
 //    BOOL camera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];  // NO
 //    BOOL savedPhotosAlbum = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum]; // YES
 
 // 检查支持的媒体类型
 NSArray<NSString *> *mPhotoLibrary = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
 NSLog(@"mPhotoLibrary:%@",mPhotoLibrary);  // mPhotoLibrary:( "public.image","public.movie")
 NSArray<NSString *> *mCamera = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
 NSLog(@"mCamera:%@",mCamera);  // mCamera:(null)
 NSArray<NSString *> *mSavedPhotosAlbum = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
 NSLog(@"mSavedPhotosAlbum:%@",mSavedPhotosAlbum); //mSavedPhotosAlbum:( "public.image", "public.movie" )
 
 //    PLCameraController *pl = [[PLCameraController alloc] init];
 UIImagePickerController *picker = [[UIImagePickerController alloc] init];
 picker.delegate = self;
 NSLog(@"picker info:%@",[picker description]);  // <UIImagePickerController: 0x7abe3000>
 picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
 self.picker = picker;
 [self presentViewController:picker animated:YES completion:^{
 NSLog(@"Picker present completion.");
 NSLog(@"title while present comlete:%@",[picker title]);
 UIImagePickerControllerSourceType currentSourceType= picker.sourceType;
 NSLog(@"current source type:%d",currentSourceType);
 }];
 
 //    PUUIAlbumListViewController *control =
 
 }
 
 #pragma mark UINavigationControllerDelegate
 - (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
 NSLog(@"willShowViewController");
 NSLog(@"navigationController:%@",navigationController); // <UIImagePickerController: 0x7d37bc00>
 NSLog(@"viewController:%@",viewController); // <PUUIAlbumListViewController: 0x7d366a00>
 NSLog(@"navigationController title:%@",[navigationController title]);
 NSLog(@"viewController title:%@",[viewController title]);
 
 // 导航的设置
 UIBarButtonItem *cancelBtn = [[UIBarButtonItem alloc]
 initWithTitle:@"取消"
 style:UIBarButtonItemStylePlain
 target:self action:@selector(pickerCancel)];
 viewController.navigationItem.rightBarButtonItem = cancelBtn;
 
 // 自定义title view
 [self createTitleViewForController:viewController];
 }
 
 - (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated{
 NSLog(@"didShowViewController");
 NSLog(@"navigationController:%@",navigationController);  // <UIImagePickerController: 0x7d37bc00>
 NSLog(@"viewController:%@",viewController);  // <PUUIAlbumListViewController: 0x7d366a00>
 NSLog(@"navigationController title:%@",[navigationController title]);
 NSLog(@"viewController title:%@",[viewController title]);
 //    [viewController setTitle:@"customized title"];
 }
 
 - (void)pickerCancel{
 NSLog(@"pickerCancel");
 [self.picker dismissViewControllerAnimated:YES completion:nil];
 }
 
 - (void)createTitleViewForController:(UIViewController *)controller{
 CGFloat width = 200;
 CGFloat x = (320 - width)/2;
 CGRect tileRect = CGRectMake(x, 0, width, 40);
 UILabel *lblTitle = [[UILabel alloc] initWithFrame:tileRect];
 lblTitle.textAlignment  = NSTextAlignmentCenter;
 [controller.navigationItem setTitleView:lblTitle];
 [lblTitle setText:@"相册胶卷"];
 lblTitle.userInteractionEnabled = YES;
 UIColor *borderLindColor = [UIColor borderLindColor];
 lblTitle.layer.borderColor  = borderLindColor.CGColor;
 lblTitle.layer.borderWidth = 1;
 lblTitle.layer.cornerRadius = 6;
 
 
 UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(titleViewTapped:)];
 tapGesture.numberOfTapsRequired = 1;
 [lblTitle addGestureRecognizer:tapGesture];
 }
 
 - (void)titleViewTapped:(id)sender{
 NSLog(@"titleViewTapped");
 CGFloat stateBarHeight = 20;
 CGFloat naviHeight = self.picker.navigationBar.frame.size.height;
 CGFloat y = stateBarHeight + naviHeight;
 CGRect rect = CGRectMake(0, y, 320, 100);
 UIView *listView = [[UIView alloc] initWithFrame:rect];
 listView.backgroundColor = [UIColor lightGrayColor];
 [self.picker.view addSubview:listView];
 
 listView.userInteractionEnabled = YES;
 UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(listViewTapped:)];
 tapGesture.numberOfTapsRequired = 1;
 [listView addGestureRecognizer:tapGesture];
 }
 
 - (void)listViewTapped:(id)sender{
 UITapGestureRecognizer *tapGesture = (UITapGestureRecognizer *)sender;
 [tapGesture.view removeFromSuperview];
 }
 
 #pragma mark -customized UIImageViewPickerController
 
 //- (void)test{
 //    //设置拍照时的下方的工具栏是否显示，如果需要自定义拍摄界面，则可把该工具栏隐藏
 //    imagepicker.showsCameraControls  = NO;
 //    UIToolbar* tool = [[UIToolbar alloc]initWithFrame:CGRectMake(0, self.view.frame.size.height-55, self.view.frame.size.width, 75)];
 //    tool.barStyle = UIBarStyleBlackTranslucent;
 //    UIBarButtonItem* cancel = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelCamera)];
 //    UIBarButtonItem* add = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(savePhoto)];
 //    [tool setItems:[NSArray arrayWithObjects:cancel,add, nil]];
 //    //把自定义的view设置到imagepickercontroller的overlay属性中
 //    imagepicker.cameraOverlayView = tool;
 //}
 
 
 #pragma mark -UIImagePickerControllerDelegate
 //- (void)imagePickerController:(UIImagePickerController *)picker
 //        didFinishPickingImage:(UIImage *)image
 //                  editingInfo:(NSDictionary<NSString *,id> *)editingInfo{
 //    NSLog(@"didFinishPickingImage");
 //}
 
 - (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
 NSLog(@"didFinishPickingMediaWithInfo picker:%@",picker);
 NSString *title = picker.title;
 NSLog(@"title:%@",title);
 }
 
 - (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
 NSLog(@"imagePickerControllerDidCancel picker:%@",picker);
 [picker dismissViewControllerAnimated:YES completion:nil];
 }
 */


@end

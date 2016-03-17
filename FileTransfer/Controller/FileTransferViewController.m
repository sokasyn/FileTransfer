//
//  FileTransferViewController.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "FileTransferViewController.h"

@interface FileTransferViewController ()

//@property (retain, nonatomic) NSTimer *timer;
@property (retain, nonatomic) NSString *socketIp;
@property (retain, nonatomic) NSNumber *socketPort;

@end

@implementation FileTransferViewController

//@synthesize timer = timer_;
@synthesize socketIp = socketIp_;
@synthesize socketPort = socketPort_;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initData];
    [self initComponents];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Intialize
#pragma mark -Data intialize
- (void)initData{
    [self envSetting];
}

// 初始化自增的键值,以供生成可以做成简单唯一标识的值
- (void)envSetting{
    [[UserDefaultsManager defaultManager] initialIncresementKey];
    [self updateUploadDirectory];
}

#warning  由于在开发过程中,重新编译之后,程序沙盒的响应文件路劲有变.正式版本不需要该操作
// 确认缓存路径
- (void)updateUploadDirectory{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesPath = [paths objectAtIndex:0];
    NSString *uploadDirectory = [cachesPath stringByAppendingPathComponent:@"Upload"];
    
    NSMutableArray *taskList = [[NSMutableArray alloc] init];
    NSArray *currentList = [[UserDefaultsManager defaultManager] getTaskList];
    for (int i = 0 ; i < [currentList count]; i++) {
        NSDictionary *iter = [currentList objectAtIndex:i];
        NSString *fileName = [[iter valueForKey:kKeyLocalFilePath] lastPathComponent];
        NSLog(@"fileName:%@",fileName);
        NSString *newFilePath = [uploadDirectory stringByAppendingPathComponent:fileName];
        
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:iter];
        [dic setValue:newFilePath forKey:kKeyLocalFilePath];
        [taskList addObject:dic];
    }
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    [userInfo setObject:taskList forKey:@"taskList"];
    [userInfo synchronize];
}

#pragma mark -Components intialize
- (void)initComponents{
    [self addTapGestureForBackgroud];
    [self settingTipsView];
    [self settingTextFields];
}

// 背景的点击手势
- (void)addTapGestureForBackgroud{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped:)];
    [self.view addGestureRecognizer:tapGesture];
    tapGesture.numberOfTapsRequired = 1;
}

// 背景的点击事件
- (void)backgroundTapped:(id)sender{
    [self.view endEditing:YES];
    self.socketIp = [self getInputSocktIp];
    self.socketPort = [self getInputSocktPort];
    
    [self validateTextField:self.txtFieldSocketIp1];
    [self validateTextField:self.txtFieldSocketIp2];
    [self validateTextField:self.txtFieldSocketIp3];
    [self validateTextField:self.txtFieldSocketIp4];
    [self validateTextField:self.txtFieldSocketPort];
    // 保存用户输入的ip和端口
    [self updateSocketIpAndPort];
}

// 提示view设置
- (void)settingTipsView{
    self.tipViewIP1.hidden = YES;
    self.tipViewIP1.layer.cornerRadius = 5;
    
    self.tipViewIP2.hidden = YES;
    self.tipViewIP2.layer.cornerRadius = 5;
    
    self.tipViewIP3.hidden = YES;
    self.tipViewIP3.layer.cornerRadius = 5;
    
    self.tipViewIP4.hidden = YES;
    self.tipViewIP4.layer.cornerRadius = 5;
    
    self.tipViewPort.hidden = YES;
    self.tipViewPort.layer.cornerRadius = 5;
}

// 输入框设置
#define kViewTagIp1           101
#define kViewTagIp2           102
#define kViewTagIp3           103
#define kViewTagIp4           104
#define kViewTagSocketPort    105
- (void)settingTextFields{
    [self.txtFieldSocketIp1  setTag:kViewTagIp1];
    [self.txtFieldSocketIp2  setTag:kViewTagIp2];
    [self.txtFieldSocketIp3  setTag:kViewTagIp3];
    [self.txtFieldSocketIp4  setTag:kViewTagIp4];
    [self.txtFieldSocketPort setTag:kViewTagSocketPort];
    
    self.txtFieldSocketIp1.delegate = self;
    self.txtFieldSocketIp2.delegate = self;
    self.txtFieldSocketIp3.delegate = self;
    self.txtFieldSocketIp4.delegate = self;
    self.txtFieldSocketPort.delegate = self;
    // ip地址的值
    NSString *ipAddr = [[UserDefaultsManager defaultManager] getSocketIp];
    if (ipAddr && [ipAddr isIpAddressString]) {
        NSArray *ipElements = [ipAddr componentsSeparatedByString:@"."];
        self.txtFieldSocketIp1.text = [ipElements objectAtIndex:0];
        self.txtFieldSocketIp2.text = [ipElements objectAtIndex:1];
        self.txtFieldSocketIp3.text = [ipElements objectAtIndex:2];
        self.txtFieldSocketIp4.text = [ipElements objectAtIndex:3];
    }
    // 端口
    NSInteger port = [[UserDefaultsManager defaultManager] getSocketPort];
    self.txtFieldSocketPort.text = [NSString stringWithFormat:@"%d",port];
    self.socketPort = [NSNumber numberWithInteger:port];
    self.socketIp = ipAddr;
}

#pragma mark - IBActions
- (IBAction)backBarItemPressed:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

// 清理缓存
- (IBAction)clearTaskList:(id)sender{
    [[UserDefaultsManager defaultManager] clearItemForKey:@"taskList"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self clearCachesImage];
    });
}

// 查看数据库信息
- (IBAction)showUserDefaluts:(id)sender{
    [[UserDefaultsManager defaultManager] printUserDefaultsInfo];
}

- (void)clearCachesImage{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesPath = [paths objectAtIndex:0];
    NSString *uploadDirectory = [cachesPath stringByAppendingPathComponent:@"Upload"];
    // 如果uploadDirectory不存在,则返回nil,如果存在但是里面没有内容,则返回一个empty 的array
    // 如果有内容,则该数组中的元素是文件的全名(不包含路劲的)
    NSArray<NSString *> *contentItems = [fileManager contentsOfDirectoryAtPath:uploadDirectory error:nil];
    if (contentItems) {
        for (NSString *item in contentItems) {
            NSString *itemPath = [uploadDirectory stringByAppendingPathComponent:item];
            if ([fileManager removeItemAtPath:itemPath error:nil]) {
                NSLog(@"删除图片成功:%@",itemPath);
            }else{
                NSLog(@"删除图片失败:%@",itemPath);
            }
        }
    }else{
        NSLog(@"目录不存在:%@",uploadDirectory);
    }
}

// 检查用户的输入
- (void)validateTextField:(UITextField *)textField{
    NSInteger value = textField.text.integerValue;
    if (textField == self.txtFieldSocketPort) {
        if (value < 0 && value > kMaximumPort) {
            [self showTipsView:self.tipViewPort];
        }
    }else{
        if (value > 255) {
            switch (textField.tag) {
                case kViewTagIp1:{
                    [self showTipsView:self.tipViewIP1];
                    break;
                }
                case kViewTagIp2:{
                    [self showTipsView:self.tipViewIP2];
                    break;
                }
                case kViewTagIp3:{
                    [self showTipsView:self.tipViewIP3];
                    break;
                }
                case kViewTagIp4:{
                    [self showTipsView:self.tipViewIP4];
                    break;
                }
                default:
                    break;
            }
        }
    }
}

// 获取用户输入的ip地址
- (NSString *)getInputSocktIp{
    NSString *ipAddr = [NSString stringWithFormat:@"%@.%@.%@.%@",
                        self.txtFieldSocketIp1.text,
                        self.txtFieldSocketIp2.text,
                        self.txtFieldSocketIp3.text,
                        self.txtFieldSocketIp4.text];
    return ipAddr;
}

// 获取用户输入的端口号
- (NSNumber *)getInputSocktPort{
    return [NSNumber numberWithInteger:self.txtFieldSocketPort.text.integerValue];
}
// 保存用户输入的ip和端口
- (void)updateSocketIpAndPort{
    [[UserDefaultsManager defaultManager] updateSocketIp:self.socketIp port:[self.socketPort integerValue]];
}

#pragma mark - Navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([self.testMode isOn]) {
        if ([[segue destinationViewController] respondsToSelector:NSSelectorFromString(@"setTest:")]) {
            [[segue destinationViewController] setValue:@"YES" forKeyPath:@"test"];
        }
    }
    if ([segue.identifier isEqualToString:kSegueFileUploadViewController]) {
        id controller = [segue destinationViewController];
        if (controller && [controller respondsToSelector:NSSelectorFromString(@"setSocketIp:")]) {
            [controller setValue:[self getInputSocktIp] forKey:@"socketIp"];
        }
        if (controller && [controller respondsToSelector:NSSelectorFromString(@"setSocketPort:")]) {
            [controller setValue:[self getInputSocktPort] forKey:@"socketPort"];
        }
    }
}

#pragma mark -UITextFieldDelegate
#warning NSAttributedString
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{        // return NO to disallow editing.
    if (textField == self.txtFieldSocketPort) {
        textField.clearsOnBeginEditing = NO;
    }else{
        textField.clearsOnBeginEditing = YES;
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField; {
    [self validateTextField:textField];
}

// 输入框的输入监听
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    // return NO to not change text
    // 键盘的删除事件,允许用户删除输入框的值
    if ([string isEqualToString:@""]) {
        return YES;
    }
    NSString *oldString = textField.text;
    // 端口有效性验证(0-65535)
    if (textField == self.txtFieldSocketPort) {
        // 原来的长度超过5,将不会追加输入的值
        if ([oldString length] >= 5){
            [self showTipsView:self.tipViewPort];
            return NO;
        }
    }else{
        // ip地址输入框,满3位数则自动转到下一个ip地址输入框
        NSInteger tag = textField.tag;
        if ([oldString length] >= 3) {
            UITextField *nextTextField = (UITextField *)[self.view viewWithTag:tag + 1];
            if (nextTextField) {
                [nextTextField becomeFirstResponder];
                if (nextTextField == self.txtFieldSocketPort) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

#pragma mark - 提示view的显示和隐藏动画效果
// 显示提示view,并自动隐藏
- (void)showTipsView:(UIView *)tipView{
    [UIView animateWithDuration:2 delay:2 options:UIViewAnimationOptionTransitionCrossDissolve
                     animations:^{
                         tipView.hidden = NO;
                     }completion:^(BOOL finish){
                         NSLog(@"隐藏view完成");
                         CATransition *animation = [CATransition animation];
                         animation.type = kCATransitionFade;
                         animation.duration = 5;//0.4;
                         [tipView.layer addAnimation:animation forKey:nil];
                         tipView.hidden = YES;
                     }];
}

@end

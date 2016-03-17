//
//  FileTransferViewController.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Common.h"
#import "UserDefaultsManager.h"
#import "NSString+StringValidator.h"

@interface FileTransferViewController : UIViewController<UITextFieldDelegate>

@property (weak,nonatomic) IBOutlet UISwitch* testMode;

@property (weak, nonatomic) IBOutlet UITextField *txtFieldSocketIp1;

@property (weak, nonatomic) IBOutlet UITextField *txtFieldSocketIp2;

@property (weak, nonatomic) IBOutlet UITextField *txtFieldSocketIp3;

@property (weak, nonatomic) IBOutlet UITextField *txtFieldSocketIp4;

@property (weak, nonatomic) IBOutlet UITextField *txtFieldSocketPort;

@property (weak, nonatomic) IBOutlet UIView *tipViewPort;

@property (weak, nonatomic) IBOutlet UIView *tipViewIP1;

@property (weak, nonatomic) IBOutlet UIView *tipViewIP2;


@property (weak, nonatomic) IBOutlet UIView *tipViewIP3;

@property (weak, nonatomic) IBOutlet UIView *tipViewIP4;

@end

//
//  FileUploadViewController.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FileTranserTask.h"
#import "Common.h"
#import "UserDefaultsManager.h"
#import "FileCollectionViewController.h"
#import "NSString+StringValidator.h"

@interface FileUploadViewController : UIViewController<UINavigationControllerDelegate,UIImagePickerControllerDelegate,FileCollectionViewDelegate,UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *barButtonItemAdd;
@property (weak, nonatomic) IBOutlet UISegmentedControl *uploadSegment;

@property (retain, atomic) NSMutableArray<NSMutableDictionary *> *uploadTaskArray; // 定义为原子性,确保线程安全

@property (retain, nonatomic) NSString *socketIp;
@property (retain, nonatomic) NSNumber *socketPort;

- (void)uploadTaskWithImageArray:(NSArray<UIImage *> *)imageArray;
- (void)uploadTaskWithImage:(UIImage *)image;
//- (void)uploadImageAtPath:(NSString *)localFilePath;

@end

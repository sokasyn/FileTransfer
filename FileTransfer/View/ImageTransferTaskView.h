//
//  ImageTransferTaskView.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FileTranserTask.h"
#import "UIColor+AppColor.h"

@protocol ImageTransferTaskViewDelegate;

@interface ImageTransferTaskView : UIImageView<FileTransferTaskDataSource>

@property (retain, nonatomic) NSString *viewId;
@property (retain,nonatomic) FileTranserTask *imgTransferTask;
@property (weak, nonatomic) id<ImageTransferTaskViewDelegate> delegate;

#pragma mark -initial
- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame progressValue:(float)progressValue;

#pragma mark -progress
- (void)updateProgress:(float)progress;
- (float)getProgress;
- (void)hideProgress;
- (void)removeProgress;
// 绑定一个图片传输的任务
- (void)bindingImageTransferTask:(FileTranserTask *)task;

@end

@protocol ImageTransferTaskViewDelegate <NSObject>

@optional
//- (void)imageTransferTaskView:(ImageTransferTaskView *)taskView didTapped:(id)sender;
- (void)imageTransferTaskView:(ImageTransferTaskView *)taskView didLongPressed:(id)sender;
- (void)imageTransferTaskViewDidTapped:(FileTranserTask *)task;
- (void)imageTransferTask:(FileTranserTask *)task didUpdateProgress:(float)progress;

@end



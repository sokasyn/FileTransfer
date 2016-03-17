//
//  ImageTransferTaskView.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "ImageTransferTaskView.h"

@interface ImageTransferTaskView()

@property (assign,nonatomic) float progress;
@property (weak, nonatomic) UILabel *lblProgress;
@property (weak, nonatomic) UIProgressView *progressView;

@end

@implementation ImageTransferTaskView

@synthesize viewId = viewId_;
@synthesize progress = progress_;
@synthesize lblProgress = lblProgress_;
@synthesize progressView = progressView_;
@synthesize imgTransferTask = imgTransferTask_;
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        progress_ = 0.0;
        // 进度条
        CGFloat space = 10;
        CGFloat x = space;
        CGFloat height = 8;
        CGFloat y = (frame.size.height - height)/2 ;
        CGFloat width = frame.size.width - space * 2;
        CGRect progressViewRect = CGRectMake(x, y, width, height);
        UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        progressView.frame = progressViewRect;
        progressView.trackTintColor=[UIColor blackColor];
        progressView.progress = progress_;
        progressView_ = progressView;
        [self addSubview:progressView_];
        
        // 进度标签
        UILabel *label = [[UILabel alloc] init];
        CGFloat lblWidth = 45;
        CGFloat lblHeight = 17;
        CGFloat lblX = (frame.size.width - lblWidth)/2;
        CGFloat lblY = y + height + 1;
        label.frame = CGRectMake(lblX, lblY, lblWidth, lblHeight);
        label.font = [UIFont boldSystemFontOfSize:15];
        label.text = @"0%";
        label.textAlignment = NSTextAlignmentCenter;
        label.adjustsFontSizeToFitWidth = YES;
        lblProgress_ = label;
        [self addSubview:lblProgress_];
        [self setContentMode:UIViewContentModeScaleAspectFit];
        
        // 圆角设置
        CGFloat cornerRadius = 9;
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = cornerRadius;
        self.layer.borderWidth = 0.5f;
        self.layer.borderColor = [[UIColor borderLindColor] CGColor];
        
        [self setUserInteractionEnabled:YES];
        [self addTappedGesture];
        [self addLongPressedGesture];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame progressValue:(float)progressValue{
    self = [self initWithFrame:frame];
    if (self) {
        progressView_.progress = progressValue;
        int progressInt = progressValue * 100;
        NSString *progressStr = [[NSString alloc] initWithFormat:@"%d%@",progressInt,@"%"];
        lblProgress_.text = progressStr;
    }
    return self;
}
// 加入点击手势
- (void)addTappedGesture{
    
//    SEL action = NSSelectorFromString(@"viewTapped");
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(viewTapped:)];
    tapGesture.numberOfTapsRequired = 1;
    [self addGestureRecognizer:tapGesture];
}

// 手势长按事件
- (void)addLongPressedGesture{
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc]
                                                      initWithTarget:self
                                                      action:@selector(viewLongPressed:)];
    longPressGesture.minimumPressDuration = 1;
    longPressGesture.allowableMovement = 2;
    [self addGestureRecognizer:longPressGesture];
}

- (void)viewTapped:(id)sender{
    NSLog(@"viewTapped");
    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(imageTransferTaskViewDidTapped:)]) {
        [self.delegate imageTransferTaskViewDidTapped:self.imgTransferTask];
    }
}

- (void)viewLongPressed:(id)sender{
    UILongPressGestureRecognizer *gesture = (UILongPressGestureRecognizer *)sender;
    NSLog(@"viewLongPressed");
    if(gesture.state == UIGestureRecognizerStateBegan){
        NSLog(@"UIGestureRecognizerStateBegan");
    }else if(gesture.state == UIGestureRecognizerStateEnded){
        NSLog(@"UIGestureRecognizerStateEnded");
        if (self.delegate &&
            [self.delegate respondsToSelector:@selector(imageTransferTaskView:didLongPressed:)]) {
            [self.delegate imageTransferTaskView:self didLongPressed:nil];
        }
    }else if(gesture.state == UIGestureRecognizerStateChanged){
        NSLog(@"UIGestureRecognizerStateChanged");
    }else if(gesture.state == UIGestureRecognizerStateCancelled){
        NSLog(@"UIGestureRecognizerStateCancelled");
    }
}

- (void)updateProgress:(float)progress{
    self.progress = (progress >= 1.0 ? 1.0 : progress);
    self.progressView.progress = self.progress;
    int progressInt = self.progress * 100;
    NSString *progressStr = [[NSString alloc] initWithFormat:@"%d%@",progressInt,@"%"];
    self.lblProgress.text = progressStr;

    if (self.progress == 1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgress];
        });
    }
}

- (float)getProgress{
    return self.progress;
}

- (void)hideProgress{
    self.progressView.hidden = YES;
    self.lblProgress.hidden = YES;
}

- (void)removeProgress{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView removeFromSuperview];
        [self.lblProgress removeFromSuperview];
    });
}

- (void)bindingImageTransferTask:(FileTranserTask *)task{
    self.imgTransferTask = task;
    self.imgTransferTask.dataSource = self;
}

#pragma mark - FileTransferTaskDataSource
- (void)fileTranserTask:(FileTranserTask *)task didPrepareForTransfer:(NSDictionary *)userInfo{
    dispatch_async(dispatch_get_main_queue(), ^{
       self.lblProgress.text = @"等待中..";
    });
}

- (void)fileTranserTask:(FileTranserTask *)task didFailForTranster:(NSDictionary *)userInfo{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.lblProgress.text = @"已终止.";
    });
}

- (void)fileTranserTask:(FileTranserTask *)task didTransferLength:(uint64_t)transferedLength totalLength:(uint64_t)maxLength{
    float progress = (float)transferedLength/(float)maxLength;
    NSLog(@"progress:%f",progress);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateProgress:progress];
        if ([self.delegate respondsToSelector:@selector(imageTransferTask:didUpdateProgress:)]) {
            [self.delegate imageTransferTask:self.imgTransferTask didUpdateProgress:progress];
        }
    });
}

@end

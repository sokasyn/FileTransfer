//
//  FileCollectionViewController.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/4.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ImageTransferTaskView.h"
#import "FileTranserTask.h"

@protocol FileCollectionViewDelegate;

typedef NS_ENUM(NSUInteger, FileCollectionType) {
    FileCollectionTypeNone = 0,
    FileCollectionTypeUploading, // 正在上传
    FileCollectionTypeUploaded   // 已经上传
};
@interface FileCollectionViewController : UIViewController<ImageTransferTaskViewDelegate,FileTransferTaskDelegate,UICollectionViewDataSource,UICollectionViewDelegateFlowLayout>

@property (retain, nonatomic) UICollectionView *collectionView;
@property (assign ,nonatomic) FileCollectionType fileCollectionType;
@property (retain, atomic) NSMutableArray<NSMutableDictionary *> *dataArray; // 定义为原子性,确保线程安全
@property (retain, atomic) NSMutableArray<UIImage *> *imageArray; //性能优化,缓存的图片,不用到磁盘去读取

@property (weak, nonatomic) id<FileCollectionViewDelegate> delegate;

- (void)receiveTask:(NSMutableDictionary *)taskInfo;
//- (void)removeTask:(NSMutableDictionary *)taskInfo;

@end

@protocol FileCollectionViewDelegate <NSObject>

@optional
- (void)uploadingOccurredError:(ErrorInfo *)error;
- (void)uploadingTask:(FileTranserTask *)task didFinishUploadingImage:(UIImage *)image;
- (void)fileCollectionViewDidLoad:(UICollectionView *)collectionView;

@end

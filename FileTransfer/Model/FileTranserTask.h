//
//  FileTranserTask.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Common.h"
#import "UserDefaultsManager.h"
#import "ErrorInfo.h"
#import "NSString+StringValidator.h"

@protocol FileTransferTaskDataSource;
@protocol FileTransferTaskDelegate;

typedef NS_ENUM(NSUInteger, FileTransferTaskStatus) {
    FileTransferTaskStatusReady = 0,
    FileTransferTaskStatusRunning,
    FileTransferTaskStatusPaused,
    FileTransferTaskStatusCanceled,
    FileTransferTaskStatusFishined,
    FileTransferTaskStatusError
};

typedef NS_ENUM(NSUInteger, FileTransferType) {
    FileTransferTypeUnkown = 0,
    FileTransferTypeUpload ,
    FileTransferTypeDownload,
};

@interface FileTranserTask : NSObject<NSStreamDelegate>

@property (retain, nonatomic) NSString *socketIp;
@property (assign, nonatomic) NSInteger socketPort;
@property (retain, nonatomic) NSString *taskId;
@property (retain, nonatomic) NSString *localFilePath;
@property (retain, nonatomic) NSString *serverFilePath;
@property (assign, nonatomic) FileTransferType transferType;
@property (weak ,nonatomic) id<FileTransferTaskDataSource> dataSource;
@property (weak ,nonatomic) id<FileTransferTaskDelegate> delegate;

@property (retain, nonatomic) NSString *sourceId;
@property (assign, nonatomic) FileTransferTaskStatus taskStatus;
@property (assign, nonatomic,getter=isStop) Boolean stop;
@property (assign, nonatomic) uint64_t fileSize;
@property (assign, nonatomic) uint64_t startPosition;   // 断点续传的断点位置(服务器通过socket返回的该文件的长度)
@property (assign, nonatomic) float progress;

#define kBufferSize     1024
#define kSocketTimeout   15

#pragma mark -initial
- (id)init;
- (id)initWithLocalFilePath:(NSString *)localFilePath serverFilePath:(NSString *)serverFilePath;

#pragma mark - managed task array
+ (NSMutableArray *)sharedTaskQueue;
// 搜索任务队列中的任务
+ (id)searchTaskInTaskQueueWithTaskId:(NSString *)taskId;

#pragma mark - task actions
- (void)start;
- (void)pause;
- (void)resume;
- (void)cancel; // 任务取消,该任务的信息还是要保存在本地的
- (void)clearTask:(FileTranserTask *)task; // 清除任务相关的信息都会清空,用户会无法找回
- (void)setFileTransferType:(FileTransferType)transferType; // 任务的类型一旦设置为上传或下载,则不能再更改
@end

/*
 * 委托
 * 用于反馈任务的进行情况,如文件传输的进度,任务当前的状态等.
 */
@protocol FileTransferTaskDataSource <NSObject>

@optional
- (void)taskDidStrat;
- (void)fileTranserTask:(FileTranserTask *)task didTransferLength:(uint64_t)transferedLength totalLength:(uint64_t)maxLength;
// 任务通过socket传输文件的过程回执,委托者可选择自身关心的事件
- (void)fileTranserTask:(FileTranserTask *)task didPrepareForTransfer:(NSDictionary *)userInfo;
- (void)fileTranserTask:(FileTranserTask *)task didFailForTranster:(NSDictionary *)userInfo;
- (void)fileTranserTask:(FileTranserTask *)task didSendingSocketHead:(NSDictionary *)userInfo;
- (void)fileTranserTask:(FileTranserTask *)task didReceivedSocketHead:(NSDictionary *)userInfo;
- (void)fileTranserTask:(FileTranserTask *)task didSendingFileBytes:(NSDictionary *)userInfo;

@end

@protocol FileTransferTaskDelegate <NSObject>

@optional
- (void)fileTranserTask:(FileTranserTask *)task occurredError:(ErrorInfo *)error;
- (void)fileTranserTask:(FileTranserTask *)task occurredException:(ErrorInfo *)error;
- (void)fileTranserTaskDidFinish:(FileTranserTask *)task;

@end

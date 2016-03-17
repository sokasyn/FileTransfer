//
//  FileTranserTask.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/15.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "FileTranserTask.h"

@interface FileTranserTask()

@property (weak, nonatomic) NSInputStream *inputStream;  // socket input stream
@property (weak, nonatomic) NSOutputStream *outputStream; // socket output stream
@property (assign, nonatomic,getter=isTimeout) BOOL timeout;
@property (assign, nonatomic,getter=isErrorOccurred) BOOL errorOccurred;
@property (weak, nonatomic) NSTimer *timer;
@property (assign, nonatomic) uint64_t bytesHasSendForFile;
@end

@implementation FileTranserTask

@synthesize socketIp = socketIp_;
@synthesize socketPort = socketPort_;
@synthesize taskId = taskId_;
@synthesize localFilePath = localFilePath_;
@synthesize serverFilePath = serverFilePath_;
@synthesize transferType = transferType_;
@synthesize dataSource = dataSource_;
@synthesize delegate = delegate_;
@synthesize sourceId = sourceId_;
@synthesize taskStatus = taskStatus_;
@synthesize stop = stop_;
@synthesize fileSize = fileSize_;
@synthesize startPosition = startPosition_;
@synthesize progress = progress_;
@synthesize inputStream = inputStream_;
@synthesize outputStream = outputStream_;
@synthesize timeout = timeout_;
@synthesize errorOccurred = errorOccurred_;
@synthesize timer = timer_;
@synthesize bytesHasSendForFile = bytesHasSendForFile_;

#define kSocketStreamOpenTimeout   15

#pragma mark - FileTranserTask interface methods
#pragma mark -initial
- (id)init{
    self = [super init];
    if (self) {
        taskStatus_ = FileTransferTaskStatusReady;
        transferType_ = FileTransferTypeUnkown;
        stop_ = YES;
        // 注册socket设置变更的广播
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSocketSettingChangedNotification:)
                                                     name:kNotificationSocketSettingChanged
                                                   object:nil];
    }
    return self;
}

- (id)initWithLocalFilePath:(NSString *)localFilePath serverFilePath:(NSString *)serverFilePath{
    self = [self init];
    if (self) {
        localFilePath_ = localFilePath;
        serverFilePath_ = serverFilePath;
        fileSize_ = [self getSizeForFileAtPath:localFilePath_];
    }
    return self;
}

#pragma mark -managed task arry
+ (NSMutableArray *)sharedTaskQueue{
    static NSMutableArray<FileTranserTask *> *taskArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taskArray = [[NSMutableArray alloc] init];
    });
    return taskArray;
}
    
#pragma mark - Task Actions
#pragma mark -文件大小
- (uint64_t)getSizeForFileAtPath:(NSString *)filePath{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    uint64_t fileSize = [[fileManager attributesOfItemAtPath:filePath error:nil] fileSize];
    return fileSize;
}
// 设置任务的类型,是上传还是下载的,初始化是FileTranserTaskTypeUnkown,一旦设置了上传或下载类型,则不可再更改
- (void)setFileTransferType:(FileTransferType)transferType{
    if (transferType_ == FileTransferTypeUnkown) {
        transferType_ = transferType;;
    }
}

#pragma mark -检查当前任务是否已经在单例的管理任务队列中
- (BOOL)taskIsExistInTaskQueue:(NSString *)taskId{
    BOOL isExist = NO;
    if ([[self class] searchTaskInTaskQueueWithTaskId:taskId]) {
        isExist = YES;
    }
    return isExist;
}

+ (id)searchTaskInTaskQueueWithTaskId:(NSString *)taskId{
    FileTranserTask *task = nil;
    if (taskId){
        NSMutableArray *array = [[self class] sharedTaskQueue];
        for (FileTranserTask *iter in array) {
            if(iter.taskId == taskId){
                task = iter;
                break;
            }
        }
    }
    return task;
}

#pragma mark -开始任务
- (void)start{
//    [self updateTaskStatus:FileTransferTaskStatusReady];
    [self updateTaskStatus:FileTransferTaskStatusRunning];
    BOOL success = [self prepareForTransfer];
    if(success){
        NSLog(@"socket头信息交互成功,文件即将传输!");
        switch (self.transferType) {
            // 上传
            case FileTransferTypeUpload:{
                [self uploadFileAtPath:self.localFilePath startAtPosition:self.startPosition];
                break;
            }
            // 下载
            case FileTransferTypeDownload:{
                break;
            }
            default:{
                NSLog(@"error:传输类型必须要设置!");
                break;
            }
        }
        [self closeSocketStreams];
    }else{
        NSLog(@"任务在传输的准备阶段(收发头信息)失败!,taskId:%@",self.taskId);
    }
    NSLog(@"任务结束.");
}

#pragma mark -暂停任务
- (void)pause{
    [self updateTaskStatus:FileTransferTaskStatusPaused];
    if ([self isStop]){
        NSLog(@"点击暂停之前,就是stop的了..可能哪里没控制好!!");
        return;
    }
    self.stop = YES;
}

#pragma mark -继续任务
- (void)resume{
    self.stop = NO;
    [self start];
}

#pragma mark -取消任务
- (void)cancel{
    [self updateTaskStatus:FileTransferTaskStatusCanceled];
    self.stop = YES;
#warning 取消任务,告知主机,让主机删除该任务信息,但是客户端保留该文件信息,用户可以从新开始该任务
}

#pragma mark -删除任务,清理持久化的任务信息
- (void)clearTask:(FileTranserTask *)task{
    NSLog(@"要清除任务,taskId:%@",task.taskId);
    [task cancel];
    [[[self class] sharedTaskQueue] removeObject:task];
    [[UserDefaultsManager defaultManager] clearTask:task.taskId];
}

// 更新任务状态
- (void)updateTaskStatus:(FileTransferTaskStatus)taskStatus{
    self.taskStatus = taskStatus;
    NSString *status = [[NSString alloc] initWithFormat:@"%d",self.taskStatus];
    [self updateValue:status forKey:kKeyTaskStuatus forTask:self.taskId];
    NSLog(@"已经在数据库中更新任务的状态:%@ taskId:%@",status,self.taskId);
}

#pragma mark - 文件传输准备工作
// socket连接以及相关数据的初始化
- (BOOL)prepareForTransfer{
    [self feedbackTaskPrepare];
    // 重置timeout
    self.timeout = NO;
    self.errorOccurred = NO;
    // socket连接
    BOOL success = [self connectToHost:self.socketIp port:self.socketPort];
    if(success){
        /* 文件传输前客户端与主机的信息交互
         * 1.客户端向主机发送信息(文件的信息,如路劲,文件断点等)
         * 2.客户端响应主机的信息(文件的信息,如路劲,文件断点等)
         */
        self.stop = NO;
        // 文件开始传输之前还有一些准备工作的,比如socket连接以及传输之前文件的发送socket头信息以确认断点等
        // 如果该任务不在管理的任务数组中,则加进来
        if (![self taskIsExistInTaskQueue:self.taskId]) {
            [[[self class] sharedTaskQueue] addObject:self];
        }
        success = [self messageInteraction];
        if(!success){
            NSLog(@"收发socket头信息阶段出现异常!,文件上传失败!");
            [self closeSocketStreams];
        }
    }
    return success;
}

#pragma mark -socket连接主机
- (BOOL)connectToHost:(NSString *)host port:(NSInteger)port{
    BOOL conectSuccess = NO;
    // NSStream框架
    NSInputStream *input;
    NSOutputStream *output;
    [NSStream getStreamsToHostWithName:host port:port inputStream:&input outputStream:&output];
    
    if (input && output) {
        NSLog(@"配置socket input/output stream.");
        self.inputStream = input;
        self.outputStream = output;
        [self openSocketStreams];
        conectSuccess = YES;
    }else{
        NSLog(@"获取socket流失败!");
    }
    return conectSuccess;
}

#pragma mark -打开socket流,分配资源
- (void)openSocketStreams{
    self.inputStream.delegate = self;
    [self.inputStream open];
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    self.outputStream.delegate = self;
    [self.outputStream open];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)openSocketStream:(NSStream *)stream{
    stream.delegate = self;
    [stream open];
    [stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark -关闭socket流,释放资源
- (void)closeSocketStreams{
    NSLog(@"socket流已关闭");
    [self.inputStream close];
    self.inputStream.delegate = nil;
    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.outputStream close];
    self.outputStream.delegate = nil;
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)closeSocketStream:(NSStream *)stream{
    [stream close];
    stream.delegate = nil;
    [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark - 文件传输前客户端与主机的信息交互
- (BOOL)messageInteraction{
    NSLog(@"您要上传文件:%@",self.localFilePath);
    NSString *sendMessage = [self buildHeadMessage];
    NSLog(@"send message:%@",sendMessage);
    BOOL success = [self sendSocketHeadMessage:sendMessage];
    if (success) {
        NSString *receivedMessage = [self receiveSocketHeadMessage];
//        [self feedbackReceivedSocketHeadMessage:receivedMessage];
        // 解析服务器返回的socket头信息,并做相应的持久化处理
        if (receivedMessage || [receivedMessage length] != 0) {
            [self parseHeadMessage:receivedMessage];
        }else{
            NSLog(@"接受socket头信息失败!taskId:%@",self.taskId);
            success = NO;
        }
    }else{
        NSLog(@"发送socket头信息失败.taskId:%@",self.taskId);
    }
    return success;
}

#warning 设置,兼容上传和下载socket head message
// Content-Length=234567;fileName="";sourceId="";\r\n
// 文件类型:Content-Type="jpg"  上传下载标志位:download=0;
#pragma mark -设置上传文件之前的socket头协议信息(自定义)
- (NSString *)buildHeadMessage{
    NSDictionary *taskInfo = [[UserDefaultsManager defaultManager] getTaskInfoWithTaskId:self.taskId];
    // 获取sourceId
    NSString *sourceId = [taskInfo valueForKey:kKeySourceId];
    if ([sourceId isEqualToString:@"null"]) {
        sourceId = @"";
    }
    // 文件名称,如果是断点续传的,则该名称是服务器中该文件的路劲
    NSString *fileName = [taskInfo valueForKey:kKeyServerFilePath];
    if ([fileName isEqualToString:@"null"]) {
        fileName = @"";
    }
    // message
    NSString *socketHeadString = [NSString stringWithFormat:@"Content-Length=%llu;fileName=%@;sourceId=%@;\r\n",
                                  self.fileSize,fileName,sourceId];
    return socketHeadString;
}

#pragma mark -向主机发送socket头信息
/* 上传/下载步骤1:客户端向主机发送协议(自定义的)头信息
 * 自定义的协议头信息如:Content-Length=234567;fileName="";sourceId="";\r\n
 * 该过程是要主机确认文件是否曾传输过,并返回该文件的信息,如断点信息
 */
- (BOOL)sendSocketHeadMessage:(NSString *)message{
//    [self feedbackSendingSocketHeadMessage:message];
    NSData *socketHeadData = [message dataUsingEncoding:NSUTF8StringEncoding];
    return [self sendSocketHeadData:socketHeadData];
}

// 发送头信息数据流
- (BOOL)sendSocketHeadData:(NSData *)data{
    NSInteger length = [self sendSocketData:data];
    NSLog(@"sendSocketHeadData :%d",length);
    return length > 0 ? YES : NO;
}

- (NSInteger)sendSocketData:(NSData *)data{
    // 阻塞以确保output stream可以写入,避免读写脱节造成字节丢失.
    [self blockWhenStreamReadyToWrite:self.outputStream];
    if (self.isErrorOccurred) {
        [self taskOccouredError];
        return 0;
    }
    
    NSInputStream *inputStream = [[NSInputStream alloc] initWithData:data];
    [inputStream open];
    uint8_t buffer[kBufferSize];
    NSInteger bytesRead = 0;
    NSInteger bytesWritten = 0;
    while (!self.isStop) {
        if ([inputStream hasBytesAvailable] && [self.outputStream hasSpaceAvailable]) {
            bytesRead = [inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead > 0 ) {
                bytesWritten = [self.outputStream write:buffer maxLength:bytesRead];
                NSLog(@"发送socket头信息:%d",bytesWritten);
            }
        }else{
            NSLog(@"数据源已经读完..");
            break;
        }
    }
    [inputStream close];
    [self printStreamStatus];
    return bytesWritten;
    
    /* 方法2
     // 将data转成字节数组
     NSInteger dataLength = [data length];
     uint8_t *dataBytes = (uint8_t *)[data bytes];
     // 发送字节
     NSInteger bytesWritten = 0;
     while (!self.isStop) {
     if ([self.outputStream hasSpaceAvailable]) {
     NSInteger writheBufferLen = (dataLength - bytesWritten >= kBufferSize) ? kBufferSize : (dataLength - bytesWritten);
     NSInteger length = [self.outputStream write:dataBytes maxLength:writheBufferLen];
     // 移动字节指针
     dataBytes += length;
     // 计算总的写入流的长度
     bytesWritten += length;
     // 如果写到了末尾,返回-1,则退出循环否则,继续写
     if (length > 0) {
     NSLog(@"write bytes :%d",length);
     }else{
     NSLog(@"write bytes :%d",length);
     break;
     }
     }
     }
     // 这种方法写完后,outputStream就关闭了
     [self printStreamStatus];
     return bytesWritten;
     */
}

#pragma mark -接收主机发送的socket头信息
/* 上传步骤2(下载不用做这步):客户端接收主机回馈的协议(自定义)头信息
 * 自定义的协议头信息如:
 * souceId=20;fileName=/Users/samtsang/iWork/Java/Temp/server/20151114055253123.jpg;position=0\r\n
 * 该过程是要主机确认文件是否曾传输过,并返回该文件的信息,如断点信息
 */
- (NSString *)receiveSocketHeadMessage{
    // e.g souceId=0;fileName=/Users/samtsang/iWork/Temp/server/20151114055253.jpg;position=0
    uint8_t buffer[kBufferSize];
    int bytesRead = 0;
    NSMutableString *responseString = [[NSMutableString alloc] init];
#warning 需要设置等待时间
    // 通过循环监听服务器端写进socket的数据,以读出来,如果没有返回则一直等待
    [self printStreamStatus];
    while (![self isStop] && 1) {
        if ([self.inputStream hasBytesAvailable]) {
            bytesRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead > 0) {
                NSLog(@"found bytes in socket input stream...%d",bytesRead);
                NSString *readString = [[NSString alloc] initWithBytes:buffer length:bytesRead encoding:NSUTF8StringEncoding];
                [responseString appendString:readString];
                if ([readString hasSuffix:@"\r\n"]) {
                    NSLog(@"Found \\r\\n");
                    break;
                }
            }else{
                break;
            }
        }
        [NSThread sleepForTimeInterval:0.05];
        NSLog(@"Waiting for server response socket head message..%@",self.taskId);
    }
    return responseString;
}

// 解析主机返回的socket头信息,断点续传(上传)需要确定从文件的断点处开始上传
- (void)parseHeadMessage:(NSString *)message{
    if (!message || [message length] == 0) {
        return;
    }
    NSArray *elements = [message componentsSeparatedByString:@";"];
    if ([elements count] < 3) {
        NSLog(@"服务器端返回的信息不满足协议格式!");
    }
    
    // 正常情况下,当客户端请求(上传/下载)成功,主机生成一条记录,sourceId为主键
    NSString *sourceId = [[[elements objectAtIndex:0] componentsSeparatedByString:@"="] objectAtIndex:1];
    self.sourceId = sourceId;
    
    // 头信息返回的该域,为主机中目标文件的路劲
    NSString *fileName= [[[elements objectAtIndex:1] componentsSeparatedByString:@"="] objectAtIndex:1];
    self.serverFilePath = fileName;
    
    // 文件的断点信息
    NSString *position = [[[elements objectAtIndex:2] componentsSeparatedByString:@"="] objectAtIndex:1];
    position = [position stringByReplacingOccurrencesOfString: @"\r" withString:@""];
    position = [position stringByReplacingOccurrencesOfString: @"\n" withString:@""];
    self.startPosition = position.integerValue;
    self.bytesHasSendForFile = self.startPosition;
    
    // 保存任务的类型,上传或者下载,画面中需要区分,上传的界面加载上传类型的任务等..
    NSString *type = [[NSString alloc] initWithFormat:@"%d",self.transferType];
    NSString *status = [[NSString alloc] initWithFormat:@"%d",self.taskStatus];
    
    // 在本地中保存起来,以前界面交互中随时读取并加载.
    // 界面初次新增的任务的时候,保存过初始化的信息,真正上传之后会跟服务器有了交互,将这部分信息更新进去
    NSDictionary *taskInfo = [[NSMutableDictionary alloc] init];
    [taskInfo setValue:[NSString stringWithFormat:@"%llu",self.fileSize] forKey:kKeySourceId];
    [taskInfo setValue:sourceId forKey:kKeySourceId];
    [taskInfo setValue:self.localFilePath forKey:kKeyLocalFilePath];
    [taskInfo setValue:fileName forKey:kKeyServerFilePath];
    [taskInfo setValue:position forKey:kKeyPosition];
    [taskInfo setValue:type forKey:kKeyTransferType];
    [taskInfo setValue:status forKey:kKeyTaskStuatus];
    [[UserDefaultsManager defaultManager] updateTaskInfo:taskInfo withTaskId:self.taskId];
}

#pragma mark - 发送目标文件流
- (void)uploadFileAtPath:(NSString *)filePath startAtPosition:(uint64_t)position{
    NSNumber *offset = [NSNumber numberWithInteger:(NSInteger)position];
    NSInputStream *fileInputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    [fileInputStream setProperty:offset forKey:NSStreamFileCurrentOffsetKey];
    [fileInputStream open];

    // 阻塞以确保output stream可以写入,避免读写脱节造成字节丢失.
    [self blockWhenStreamReadyToWrite:self.outputStream];
    if (self.isErrorOccurred) {
        [self taskOccouredError];
        return;
    }
    
    uint8_t buffer[kBufferSize];
    NSInteger bytesRead = 0;
    NSInteger byteWritten = 0;
    // 断点续传的时候,总的进度要计算之前上传的长度,否则画面显示的只是当前上传的进度.
    // bytesHasSendForFile在接收服务器返回的头信息时,已经加上了之前上传的部分长度(即self.startPosition)
    while (![self isStop]) {
        if([fileInputStream hasBytesAvailable] && [self.outputStream hasSpaceAvailable]) {
            // 最后一次是0而不是-1,倒数第2次是一个小于buffer的数值
            bytesRead = [fileInputStream read:buffer maxLength:sizeof(buffer)];
            NSLog(@"上传文件 bytesRead:%d",bytesRead);
            if (bytesRead > 0) {
                byteWritten = [self.outputStream write:buffer maxLength:bytesRead];
                NSLog(@"--byteWritten:%d --",byteWritten);
                if (byteWritten > 0){
                    self.bytesHasSendForFile += byteWritten;
                    // delegate模式反馈信息
                    NSLog(@"--byteWrittenTotal:%llu --",self.bytesHasSendForFile);
                    [self delegateCallBackTansferLength:self.bytesHasSendForFile];
                }
            }
        }else{
            break;
        }
#warning 测试完删除
        [NSThread sleepForTimeInterval:0.1];
    }
    [fileInputStream close];
    
    // 此次过程结束的收尾事件
    NSLog(@"本次上传结束.taskId:%@",self.taskId);
    [self handleFileTansferOverEvent];
}

#pragma mark -数据上传的进度 告诉委托更新UI
// ImageTransferTaskView 实现了更新进度委托,ImageTransferTaskView与task进度一对一更新
- (void)delegateCallBackTansferLength:(uint64_t)length{
    if ( self.dataSource && [self.dataSource respondsToSelector:@selector(fileTranserTask:didTransferLength:totalLength:)]) {
        [self.dataSource fileTranserTask:self didTransferLength:length totalLength:self.fileSize];
    }else{
        NSLog(@"delegate is nil");
    }
}

#pragma mark -一次上传文件过程的结束事件
- (void)handleFileTansferOverEvent{
    [self printStreamStatus];
    // 更新数据库上传长度信息
    [self updateValue:[[NSString alloc]initWithFormat:@"%llu",self.bytesHasSendForFile]
               forKey:kKeyPosition forTask:self.taskId];
    // 更新数据库进度信息
    self.progress = (float)self.bytesHasSendForFile/(float)self.fileSize;
    [self updateValue:[[NSString alloc] initWithFormat:@"%.2f",self.progress]
               forKey:kKeyTaskProgress forTask:self.taskId];
    
    // 1.用户选择结束事件,pause和cancel操作已经修改过了任务的状态
    if (self.taskStatus == FileTransferTaskStatusPaused ||
        self.taskStatus == FileTransferTaskStatusCanceled) {
        return;
    }
    /* 2.非用户选择的结束,可能是文件已经上传完毕,或者中途出现了意外状态导致中断
     * 文件上传过程是个相对比较耗时的过程,其中可能会出现各种导致上传中断的状况,比较网络中断等
     * 这些非程序内部的因素.需要通过退出发送数据逻辑后检查socket的stream的状态做相应处理.
     * 在意外情况下,文件上传也是终止的,得把任务状态设置为pause,cancel或者error,以便用户下次可以选择相关的操作继续上传
    */
    else{
        [self handleStreamEvents:self.outputStream];
    }
}

#pragma mark -处理stream事件
- (void)handleStreamEvents:(NSStream *)stream{
    NSStreamStatus status = [stream streamStatus];
    // 如果是上传的总长度与文件的总长度相等,说明是正常上传完毕的
    if (self.bytesHasSendForFile == self.fileSize){
        NSLog(@"文件传完..");
        [self taskFinishedComplete];
//        return;
    }else{
        if (status == NSStreamStatusError) {
            [self taskOccouredError];
        }else{
            [self taskOccouredException];
        }
    }
    switch (status) {
        case NSStreamStatusNotOpen:{
            NSLog(@"NSStreamStatusNotOpen");
            break;
        }
        case NSStreamStatusOpening:{
            NSLog(@"NSStreamStatusOpening");
            break;
        }
        case NSStreamStatusOpen:{
            NSLog(@"NSStreamStatusOpen");
            break;
        }
        case NSStreamStatusReading:{
            NSLog(@"NSStreamStatusReading");
            break;
        }
        case NSStreamStatusWriting:{
            NSLog(@"NSStreamStatusWriting");
            break;
        }
        case NSStreamStatusAtEnd:{
            NSLog(@"NSStreamStatusAtEnd");
            break;
        }
        case NSStreamStatusClosed:{
            NSLog(@"NSStreamStatusClosed");
            break;
        }
        case NSStreamStatusError:{
            NSLog(@"NSStreamStatusError");
//            [self taskOccouredError];
            break;
        }
        default:
            break;
    }
}

#pragma mark - 任务过程回执
// 用户可能会关心任务的执行过程,界面需要反馈这些信息,如等待中,已准备就绪,文件开始传输
#pragma mark -准备过程回执
- (void)feedbackTaskPrepare{
    NSLog(@"等待中.");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (self.dataSource &&
            [self.dataSource respondsToSelector:@selector(fileTranserTask:didPrepareForTransfer:)]) {
            [self.dataSource fileTranserTask:self didPrepareForTransfer:nil];
        }
    });
}

#pragma mark -socket头信息发送回执
- (void)feedbackSendingSocketHeadMessage:(NSString *)message{
    NSLog(@"准备就绪中,准备传输");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.dataSource &&
            [self.dataSource respondsToSelector:@selector(fileTranserTask: didSendingSocketHead:)]) {
            [self.dataSource fileTranserTask:self didSendingSocketHead:nil];
        }
    });
}

#pragma mark -socket头信息发送回执
- (void)feedbackReceivedSocketHeadMessage:(NSString *)message{
    NSLog(@"准备就绪中,准备传输");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.dataSource &&
            [self.dataSource respondsToSelector:@selector(fileTranserTask: didReceivedSocketHead:)]) {
            [self.dataSource fileTranserTask:self didReceivedSocketHead:nil];
        }
    });
}

#pragma mark -文件流传输回执
- (void)feedbackFileBytesSending{
    NSLog(@"开始传输,实时更新进度");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.dataSource &&
            [self.dataSource respondsToSelector:@selector(fileTranserTask:didSendingFileBytes:)]) {
            [self.dataSource fileTranserTask:self didSendingFileBytes:nil];
        }
    });
}

#pragma mark -任务完成
- (void)taskFinishedComplete{
    [self updateTaskStatus:FileTransferTaskStatusFishined];
    // 将该任务从任务队列中移除
    [[[self class] sharedTaskQueue] removeObject:self];
    self.stop = YES;
    // 移除广播,任务完成后不在监听socket设置变更的广播
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationSocketSettingChanged object:nil];
    
    // 文件传输完毕,当立即返回以关闭socket流,终结跟服务器的连接,采用多线程去通知委托处理相关事宜
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(fileTranserTaskDidFinish:)]) {
            [self.delegate fileTranserTaskDidFinish:self];
        }
    });
}

#pragma mark -任务传输中发生错误
- (void)taskOccouredError{
    [self updateTaskStatus:FileTransferTaskStatusError];
    self.stop = YES;
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(fileTranserTask:didFailForTranster:)]) {
        [self.dataSource fileTranserTask:self didFailForTranster:nil];
    }
    
    // 文件传输异常,当立即返回以关闭socket流,终结跟服务器的连接,采用多线程去通知委托处理相关事宜
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(fileTranserTask:occurredError:)]) {
            ErrorInfo *errorInfo = [[ErrorInfo alloc] init];
            errorInfo.errorMessage = [NSString stringWithFormat:@"无法连接到主机!\n IP:%@ 端口:%d",self.socketIp,self.socketPort];
            [self.delegate fileTranserTask:self occurredError:errorInfo];
        }
    });
}

- (void)taskOccouredException{
    [self updateTaskStatus:FileTransferTaskStatusPaused];
    self.stop = YES;
    // 文件传输异常,当立即返回以关闭socket流,终结跟服务器的连接,采用多线程去通知委托处理相关事宜
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(fileTranserTask:occurredError:)]) {
            ErrorInfo *errorInfo = [[ErrorInfo alloc] init];
            errorInfo.errorMessage = [NSString stringWithFormat:@"非socket错误的意外情况!文件无法传输成功!"];
            [self.delegate fileTranserTask:self occurredError:errorInfo];
        }
    });
}

#define mark - Stream的状态确认与超时跟踪
- (void)printStreamStatus{
    NSStreamStatus inputStatus = [self.inputStream streamStatus];
    NSStreamStatus outputStatus = [self.outputStream streamStatus];
    NSLog(@"inputStatus:%d,outputStatus:%d",inputStatus,outputStatus);
}

- (void)blockWhenStreamReadyToWrite:(NSOutputStream *)stream{
    [self printStreamStatus];
    // 启动计时器以计算超时.未来可以考虑用socket自身的超时设置
//    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(calculateTimeout) object:nil];
//    [thread start];
    while ([stream streamStatus] != NSStreamStatusOpen || ![stream hasSpaceAvailable]) {
        NSLog(@"Waiting for stream opening and available space for task:%@",self.taskId);
        [NSThread sleepForTimeInterval:0.001];
        if ([stream streamStatus] == NSStreamStatusError) {
            NSLog(@"服务器异常..");
            self.errorOccurred = YES;
            break;
        }
        if (self.isTimeout) {
            NSLog(@"响应超时.无法打开流");
            break;
        }
    }
//    [thread cancel];
//    [self stopTimer];
}

#warning 超时的处理
#pragma mark -超时的处理
- (void)stopTimer{
    if (self.timer) {
        if ([self.timer isValid]) {
            [self.timer invalidate];
        }
        self.timer = nil;
    }
    sTime = 0;
}

- (void)calculateTimeout{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] run];
}

static NSInteger sTime = 0;
- (void)timerFired{
    sTime ++;
    if (sTime >= kSocketTimeout) {
        NSLog(@"响应时间超过十秒了");
        self.timeout = YES;
        [self stopTimer];
    }
}

#pragma mark -socket输出流处理
/*
 * 对于客户端来讲,接收主机的数据,都是往inputStream里读字节
 */
- (void)acceptFileData:(NSData *)data{
    NSLog(@"acceptSocketData");
}

#pragma mark -更新任务某项信息
- (void)updateValue:(NSString *)value forKey:(NSString *)key forTask:(NSString *)taskId{
    [[UserDefaultsManager defaultManager] updateValue:value forKey:key forTask:taskId];
}

#pragma mark -获取任务某一项信息
- (NSString *)selectValueForKey:(NSString *)key forTask:(NSString *)taskId{
    return [[UserDefaultsManager defaultManager] selectValueForKey:key forTask:taskId];
}

#pragma mark - NSNotification广播处理
- (void)handleSocketSettingChangedNotification:(NSNotification *)notification{
    NSLog(@"处理广播事件.接受广播的任务id:%@",self.taskId);
    NSDictionary *userInfo = notification.userInfo;
    NSString *socketIp = [userInfo objectForKey:kKeySocketIp];
    NSNumber *socketPort = [userInfo objectForKey:kKeySocketPort];
    self.socketIp = socketIp;
    self.socketPort = [socketPort integerValue];
}

#pragma mark - NSStream delegate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    NSLog(@"stream delegate method called");
    if (aStream == self.inputStream) {
        NSLog(@"self.inputStream delegate called");
    }
    if (aStream == self.outputStream) {
        NSLog(@"self.outputStream delegate called");
    }
    switch (eventCode) {
        case NSStreamEventNone:{
            NSLog(@"NSStreamEventNone");
            break;
        }
        case NSStreamEventOpenCompleted:{
            NSLog(@"NSStreamEventOpenCompleted");
            break;
        }
        case NSStreamEventHasBytesAvailable:{
            NSLog(@"NSStreamEventHasBytesAvailable");
            break;
        }
        case NSStreamEventHasSpaceAvailable:{
            NSLog(@"NSStreamEventHasSpaceAvailable");
            break;
        }
        case NSStreamEventEndEncountered:{
            NSLog(@"NSStreamEventEndEncountered");
            break;
        }
        case NSStreamEventErrorOccurred:{
            NSLog(@"NSStreamEventErrorOccurred发生错误!");
            self.stop = YES;
            [self closeSocketStreams];
            break;
        }
        default:
            break;
    }
}

@end

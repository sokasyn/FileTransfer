//
//  UserDefaultsManager.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/17.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSString+StringValidator.h"

@interface UserDefaultsManager : NSObject

#define kKeySocketIp    @"socketIp"
#define kKeySocketPort  @"socketPort"
#define kMaximumPort    65533

#define kKeyIncresementKey @"incresementKey"

#define kKeySourceId        @"sourceId"
#define kKeyTaskId          @"taskId"
#define kKeyLocalFilePath   @"localFilePath"
#define kKeyServerFilePath  @"serverFilePath"
#define kKeyPosition        @"startPosition"
#define kKeyTransferType    @"transferType"
#define kKeyTaskStuatus     @"taskStatus"
#define kKeyTaskProgress    @"taskProgress"

+ (UserDefaultsManager *)defaultManager;
- (void)printUserDefaultsInfo;
- (void)clearItemForKey:(NSString *)key;
- (void)clearTask:(NSString *)taskId;
- (void)initialIncresementKey;  // 自增键值的初始化
- (NSInteger)increaseKey; // 自增key,并返回自增后的key
- (NSInteger)getIncresementKey;
- (NSArray<NSDictionary *> *)getTaskList;
- (void)addTaskInfo:(NSDictionary *)taskInfo;
- (void)updateTaskInfo:(NSDictionary *)taskInfo withTaskId:(NSString *)taskId;
- (NSDictionary *)getTaskInfoWithTaskId:(NSString *)taskId;
- (void)updateValue:(NSString *)value forKey:(NSString *)key forTask:(NSString *)taskId;
- (NSString *)selectValueForKey:(NSString *)key forTask:(NSString *)taskId; // 获取任务某一项信息

//- (void)updateCachesUploadFileDirectory:(NSString *)targetDirectory;

- (void)updateSocketIp:(NSString *)socketIp port:(NSInteger)port;
- (NSString *)getSocketIp;
- (NSInteger)getSocketPort;

@end

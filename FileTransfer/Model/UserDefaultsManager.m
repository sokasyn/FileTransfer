//
//  UserDefaultsManager.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/11/17.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "UserDefaultsManager.h"

@implementation UserDefaultsManager

+ (UserDefaultsManager *)defaultManager{
    static UserDefaultsManager *defaultManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultManager = [[[self class] alloc] init];
    });
    return defaultManager;
}

- (void)printUserDefaultsInfo{
    /*
     NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
     [[NSUserDefaults standardUserDefaults]removePersistentDomainForName:appDomain];
     */
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    NSDictionary *dictionay = [userInfo dictionaryRepresentation];
    NSLog(@"NSUserDefaults info:%@",dictionay);
}

- (void)clearItemForKey:(NSString *)key{
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    [userInfo removeObjectForKey:key];
    [userInfo synchronize];
}

// 自增键值
- (void)initialIncresementKey{
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    if (![userInfo objectForKey:kKeyIncresementKey]) {
        [userInfo setInteger:1 forKey:kKeyIncresementKey];
        [userInfo synchronize];
    }
}

- (NSInteger)increaseKey{
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    NSInteger oldValue = [userInfo integerForKey:kKeyIncresementKey];
    NSInteger newValue = oldValue + 1;
    [userInfo setInteger:newValue forKey:kKeyIncresementKey];
    [userInfo synchronize];
    return newValue;
}

- (NSInteger)getIncresementKey{
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    return [userInfo integerForKey:kKeyIncresementKey];
}

- (NSArray<NSDictionary *> *)getTaskList{
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    NSArray *array = [userInfo objectForKey:@"taskList"];
    return array;
}

#define kKeyTaskId          @"taskId"
#define kKeyLocalFilePath   @"localFilePath"
#define kKeyServerFilePath  @"serverFilePath"
#define kKeyPosition        @"startPosition"
#define kKeyTransferType    @"transferType"
#define kKeyTaskStuatus     @"taskStatus"
#define kKeyTaskProgress    @"taskProgress"
- (void)addTaskInfo:(NSDictionary *)taskInfo{
    if (taskInfo) {
        NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
        NSArray *currentList = [userInfo objectForKey:@"taskList"];
        if (currentList) {
            NSMutableArray *list = [NSMutableArray arrayWithArray:currentList];
            [list addObject:taskInfo];
            [userInfo setObject:list forKey:@"taskList"];
        }else{
            NSArray *taskArray = [[NSArray alloc] initWithObjects:taskInfo, nil];
            [userInfo setObject:taskArray forKey:@"taskList"];
        }
        [userInfo synchronize];
    }
}

- (NSDictionary *)getTaskInfoWithTaskId:(NSString *)taskId{
    NSDictionary *taskInfo = nil;
    if (taskId) {
        NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
        NSArray *taskList = [userInfo objectForKey:@"taskList"];
        for (NSDictionary *iter in taskList) {
            NSString *tmpTaskId = [iter valueForKey:kKeyTaskId];
            if ([tmpTaskId isEqualToString:taskId]) {
                taskInfo = iter;
                break;
            }
        }
    }
    return taskInfo;
}

#pragma mark -清除任务的持久化信息
- (void)clearTask:(NSString *)taskId{
    if (taskId) {
        NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
        NSArray *currentList = [userInfo objectForKey:@"taskList"];
        NSMutableArray *taskList = [[NSMutableArray alloc] initWithArray:currentList];
        
        for (int i = 0 ; i < [taskList count]; i++) {
            NSDictionary *iter = [taskList objectAtIndex:i];
            NSString *tmpTaskId = [iter valueForKey:kKeyTaskId];
            if ([tmpTaskId isEqualToString:taskId]) {
                [taskList removeObjectAtIndex:i];
                break;
            }
        }
        [userInfo setObject:taskList forKey:@"taskList"];
        [userInfo synchronize];
    }
}

#pragma mark -更新任务信息
- (void)updateTaskInfo:(NSDictionary *)taskInfo withTaskId:(NSString *)taskId{
    if (taskId) {
        NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
        NSArray *currentList = [userInfo objectForKey:@"taskList"];
        NSMutableArray *taskList = [[NSMutableArray alloc] initWithArray:currentList];
        for (int i = 0 ; i < [taskList count]; i++) {
            NSDictionary *iter = [taskList objectAtIndex:i];
            NSString *tmpTaskId = [iter valueForKey:kKeyTaskId];
            if ([tmpTaskId isEqualToString:taskId]) {
                NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:iter];
                NSArray *keyArray = [taskInfo allKeys];
                for (NSString *key in keyArray) {
                    [dic setValue:[taskInfo valueForKey:key] forKey:key];
                }
                [taskList replaceObjectAtIndex:i withObject:dic];
                break;
            }
        }
        [userInfo setObject:taskList forKey:@"taskList"];
        [userInfo synchronize];
    }
}

#pragma mark -更新任务某一项的值
- (void)updateValue:(NSString *)value forKey:(NSString *)key forTask:(NSString *)taskId{
    if (taskId) {
        NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
        NSArray *currentList = [userInfo objectForKey:@"taskList"];
        NSMutableArray *taskList = [[NSMutableArray alloc] initWithArray:currentList];
        
        for (int i = 0 ; i < [taskList count]; i++) {
            NSDictionary *iter = [taskList objectAtIndex:i];
            NSString *tmpTaskId = [iter valueForKey:kKeyTaskId];
            if ([tmpTaskId isEqualToString:taskId]) {
//                NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:iter copyItems:YES];
                NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithDictionary:iter];
                [dic setValue:value forKey:key];
                [taskList replaceObjectAtIndex:i withObject:dic];
                break;
            }
        }
        [userInfo setObject:taskList forKey:@"taskList"];
        [userInfo synchronize];
    }
}

#pragma mark -获取任务某一项信息
- (NSString *)selectValueForKey:(NSString *)key forTask:(NSString *)taskId{

    NSDictionary *taskInfo = [self getTaskInfoWithTaskId:taskId];
    NSString *value = [taskInfo valueForKey:key];
    return value;
}

#pragma makr -更新socket ip 和 端口
- (void)updateSocketIp:(NSString *)socketIp port:(NSInteger)port{
    NSUserDefaults *userInfo = [NSUserDefaults standardUserDefaults];
    if ([socketIp isIpAddressString]) {
        [userInfo setValue:socketIp forKey:kKeySocketIp];
    }
    [userInfo setInteger:port forKey:kKeySocketPort];
    [userInfo synchronize];
}

- (NSString *)getSocketIp{
    return [[NSUserDefaults standardUserDefaults] valueForKey:kKeySocketIp];
}

- (NSInteger)getSocketPort{
    return [[NSUserDefaults standardUserDefaults] integerForKey:kKeySocketPort];
}

@end

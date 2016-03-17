//
//  ErrorInfo.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/3.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "ErrorInfo.h"

@implementation ErrorInfo

@synthesize errorMessage = errorMessage_;

- (id)init{
    self = [super init];
    if (self) {
        // 未来扩展
        errorMessage_ = @"error";
    }
    return self;
}

@end

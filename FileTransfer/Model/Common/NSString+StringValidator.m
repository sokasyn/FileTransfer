//
//  NSString+StringValidator.m
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/6.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import "NSString+StringValidator.h"

@implementation NSString (StringValidator)

- (BOOL)isNumberString{
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSInteger value;
    if ([scanner scanInteger:&value] && [scanner isAtEnd]) {
        return YES;
    }else{
       return NO;
    }
}

- (BOOL)isIpAddressString{
    BOOL isIpAddress = NO;
    NSArray *ipElements = [self componentsSeparatedByString:@"."];
    // ip地址分为4个部分
    if ([ipElements count]== 4) {
        for (NSString *element in ipElements) {
            // 检查每一部分是否是数字类型
            if ([element isNumberString]) {
                NSInteger value = [element integerValue];
                // 每部分在0-255之间
                if (value >= 0 && value <= 255) {
                    isIpAddress = YES;
                    continue;
                }else{
                    isIpAddress = NO;
                    NSLog(@"不满足ip的分段数值范围内:%@",element);
                    break;
                }
            }else{
                NSLog(@"element:%@ 不是数字类型..",element);
                isIpAddress = NO;
                break;
            }
        }
    }
    return isIpAddress;
}

@end

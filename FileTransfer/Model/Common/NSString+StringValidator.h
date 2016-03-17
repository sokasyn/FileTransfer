//
//  NSString+StringValidator.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/6.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (StringValidator)

- (BOOL)isNumberString;
- (BOOL)isIpAddressString;


@end

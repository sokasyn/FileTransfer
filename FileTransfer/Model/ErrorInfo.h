//
//  ErrorInfo.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/3.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ErrorInfo : NSObject

@property (retain,nonatomic) NSString *errorMessage;

- (id)init;

@end

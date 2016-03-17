//
//  TransferTaskViewCell.h
//  FileTransfer
//
//  Created by Sam Tsang on 15/12/2.
//  Copyright © 2015年 Sam Tsang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TransferTaskViewCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *lblProgress;

@end

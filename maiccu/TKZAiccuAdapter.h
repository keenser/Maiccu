//
//  TKZAiccuAdapter.h
//  maiccu
//
//  Created by Kristof Hannemann on 04.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "genericAdapter.h"

extern NSString * const TKZAiccuDidTerminate;
extern NSString * const TKZAiccuStatus;

@interface TKZAiccuAdapter : genericAdapter {
@private
    struct TIC_conf	*tic;
    NSTask *_task;
    NSPipe *_pipe;
    NSTimer *_postTimer;
    NSMutableArray *_statusQueue;
    NSUInteger _statusNotificationCount;
}

@property (strong) NSDictionary *tunnelInfo;

@end

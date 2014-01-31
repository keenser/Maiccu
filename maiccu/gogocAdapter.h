//
//  gogocAdapter.h
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "genericAdapter.h"

@interface gogocAdapter : genericAdapter {
@private
    NSTask *_task;
    NSPipe *_pipe;
    NSTimer *_postTimer;
    NSMutableArray *_statusQueue;
    NSUInteger _statusNotificationCount;
}

@end

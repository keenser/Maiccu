//
//  TKZMaiccu.h
//  maiccu
//
//  Created by Kristof Hannemann on 20.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "genericAdapter.h"
#import "TKZAiccuAdapter.h"
#import "gogocAdapter.h"
#import "TKZDetailsController.h"

@interface TKZMaiccu : NSObject  {
    NSFileManager *_fileManager;
    TKZAiccuAdapter *_aiccu;
    gogocAdapter *_gogoc;

    NSMutableArray *_postQueue;
    NSTimer *_postTimer;
    NSUInteger _postNotificationCount;
}

@property (strong) genericAdapter *adapter;
@property (strong) genericAdapter *runningAdapter;
@property (unsafe_unretained) NSTextView *logTextView;
@property TKZDetailsController *detailsController;
@property (strong) NSDictionary *adapterList;

- (BOOL) aiccuConfigExists;

- (NSString *)aiccuPath;

- (NSString *)maiccuLogPath;
- (BOOL) maiccuLogExists;

- (NSString *)launchAgentPlistPath;
- (BOOL)setToLaunchAgent:(BOOL)value;
- (BOOL)isLaunchAgent;

- (void)writeLogMessage:(NSString *)logMessage;
- (void)postNotification:(NSString *) message;

- (BOOL)startStopAdapter;
- (void)stopAdapter;
- (void)startAdapter;

- (void) setAdapterView:(NSString *)View;
- (NSArray*)adapters;

+ (id)defaultMaiccu;
@end

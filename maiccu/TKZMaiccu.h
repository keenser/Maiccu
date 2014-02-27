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

@interface TKZMaiccu : NSObject  {
    NSFileManager *_fileManager;
    TKZAiccuAdapter *_aiccu;
    gogocAdapter *_gogoc;
}

@property (strong) genericAdapter *adapter;
@property (strong) genericAdapter *runningAdapter;

- (BOOL) aiccuConfigExists;

- (NSString *)aiccuPath;

- (NSString *)maiccuLogPath;
- (BOOL) maiccuLogExists;

- (NSString *)launchAgentPlistPath;
- (BOOL)setToLaunchAgent:(BOOL)value;
- (BOOL)isLaunchAgent;

- (void)writeLogMessage:(NSString *)logMessage;

- (BOOL)startStopAdapter;
- (void)stopAdapter;
- (void)startAdapter;

- (void) setAiccuView:(NSMenuItem *)View;
- (void) setGogocView:(NSMenuItem *)View;
- (void) setAdapterView:(NSMenuItem *)View;
- (NSMenuItem *) adapterView;

+ (id)defaultMaiccu;
@end

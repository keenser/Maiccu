//
//  genericAdapter.h
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TKZSheetController.h"

extern NSString * const TKZAiccuDidTerminate;
extern NSString * const TKZAiccuStatus;

#define __cstons(__cstring__)  [NSString stringWithCString:__cstring__ encoding:NSUTF8StringEncoding]

#define nstocs(__nsstring__) (char *)[__nsstring__ cStringUsingEncoding:NSUTF8StringEncoding]

#define cstons(__cstring__)  [NSString stringWithCString:((__cstring__ != NULL) ?  __cstring__ : "") encoding:NSUTF8StringEncoding]

@interface genericAdapter : NSObject {
    BOOL validCredentials;
@private
    NSTask *_task;
    NSPipe *_pipe;
    NSTimer *_postTimer;
    NSUInteger _statusNotificationCount;
    NSMutableArray *_statusQueue;
}

@property (strong) NSString *name;
@property (strong) NSString *configfile;
@property (strong) NSMenuItem *view;

- (NSArray *)tunnelList;
- (NSArray *)serverList;
- (void)showSheet:(NSWindow*)window;

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path;

- (BOOL)startFrom:(NSString *)path withConfigDir:(NSString *)configPath;
- (BOOL)startFrom:(NSString *)path withConfigDir:(NSString *)configPath withArgs:(NSArray *)args;
- (void)stopFrom;

- (void)setConfig:(NSString*)value toKey:(NSString*)key;
- (NSString *)config:(NSString*)key;
- (NSDictionary *)config;
- (BOOL)forNat;
- (BOOL)isRunning;
- (BOOL)isValid;
- (NSDictionary*)tunnelInfo;
- (char*)device;

@end

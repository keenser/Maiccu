//
//  genericAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 German Skalauhov. All rights reserved.
//

#import "genericAdapter.h"

NSString * const TKZAiccuDidTerminate = @"AiccuDidTerminate";
NSString * const TKZAiccuStatus = @"AiccuStatus";

@implementation genericAdapter

- (id)init
{
    if (self=[super init]) {
        validCredentials = YES;
    }
    return self;
}

- (id)initWithHomeDir:(NSString*)path {
    if (self=[self init]) {
        [self setConfigPath:path];
    }
    return self;
}

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path {
    return YES;
}

- (BOOL)startFrom:(NSString *)path {
    return TRUE;
}

- (BOOL)startFrom:(NSString *)path withArgs:(NSArray *)args
{
    // Is the task running?
    if (![_task isRunning]){
        _task = [[NSTask alloc] init];
        [_task setLaunchPath:path];
		[_task setArguments:args];
		[_task setCurrentDirectoryPath:_configPath];
		// Create a new pipe
		_pipe = [[NSPipe alloc] init];
		[_task setStandardOutput:_pipe];
		[_task setStandardError:_pipe];
        
		NSFileHandle *fh = [_pipe fileHandleForReading];
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver:self];
		
		[nc addObserver:self
			   selector:@selector(dataReady:)
				   name:NSFileHandleReadCompletionNotification
				 object:fh];
		
		[nc addObserver:self
			   selector:@selector(taskTerminated:)
				   name:NSTaskDidTerminateNotification
				 object:_task];
		
		[_task launch];
        
		[fh readInBackgroundAndNotify];
	}
    return TRUE;
}


- (void)stopFrom {
    // Is the task running?
    if ([_task isRunning]) {
        [_task interrupt];
    }
}

- (BOOL)isRunning {
    return [_task isRunning];
}

- (void)dataReady:(NSNotification *)n
{
    NSData *data;
    data = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    
	if ([data length]) {
        
        NSString *wholeMessage = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:wholeMessage];
    }
    
	// If the task is running, start reading again
    if ([_task isRunning])
        [[_pipe fileHandleForReading] readInBackgroundAndNotify];
}

- (void)taskTerminated:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuDidTerminate object:@([_task terminationStatus])];
}

- (NSArray *)tunnelList
{
    return nil;
}

- (void)showSheet:(NSWindow*)window {
}

- (NSArray *)serverList
{
    return nil;
}

- (void)setConfig:(NSString*)value toKey:(NSString*)key {
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[self binary]]];
    config[key] = value;
    [[NSUserDefaults standardUserDefaults] setObject:config forKey:[self binary]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)config:(NSString*)key {
    NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:[self binary]][key];
    if (value) {
        return value;
    }
    return @"";
}

- (NSDictionary *)config {
    NSDictionary *value = [[NSUserDefaults standardUserDefaults] objectForKey:[self binary]];
    if (value) {
        return value;
    }
    return nil;
}

- (BOOL)forNat {
    return YES;
}

- (BOOL) isValid {
    return validCredentials;
}

- (NSDictionary*)tunnelInfo {
    return nil;
}

- (char*)device {
    NSString *dev = [self config:@"dev"];
    if ( [dev length] )
        return nstocs(dev);
    else {
        return "tun0";
    }
}

@end

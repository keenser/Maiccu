//
//  genericAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "genericAdapter.h"

NSString * const TKZAiccuDidTerminate = @"AiccuDidTerminate";
NSString * const TKZAiccuStatus = @"AiccuStatus";

@implementation genericAdapter

- (id)init
{
    if (self=[super init]) {
        _task = nil;
        _postTimer = nil;
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
    if (!_task){
        if(_statusQueue == nil) {
            _statusQueue = [[NSMutableArray alloc] init];
        }
        _statusNotificationCount = 0;
        [_postTimer invalidate];
        
        //_status = [[NSMutableString alloc] init];
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
    if (_task) {
        [_task interrupt];
    }
}

- (BOOL)isRunning {
    return [_task isRunning];
}

//- (void)shiftFIFOArray:(NSMutableArray *)array withObject:(id)object{
//    [array removeLastObject];
//    [array insertObject:object atIndex:0];
//}

- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
    
	if ([d length]) {
        
        NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
        [_statusQueue addObject:s];
        
        [_postTimer invalidate];
        _statusNotificationCount++;
        
        if (_statusNotificationCount >= 5) {
            if(!(_statusNotificationCount % 500)) {
                [_postTimer invalidate];
                [self postAiccuStatusNotification];
            }
            else {
                _postTimer = [NSTimer scheduledTimerWithTimeInterval:4.0f target:self selector:@selector(resetStatusNotificationCount) userInfo:nil repeats:NO];
            }
        }
        else {
            
            [self postAiccuStatusNotification];
        }
        
        
    }
    
	// If the task is running, start reading again
    if (_task)
        [[_pipe fileHandleForReading] readInBackgroundAndNotify];
}


- (void)postAiccuStatusNotification {
    
    NSMutableString *wholeMessage = [[NSMutableString alloc] init];
    for (NSString *message in _statusQueue) {
        [wholeMessage appendString:message];
    }
    
    if (![wholeMessage isEqualToString:@""]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:wholeMessage];
    }
    
    [_statusQueue removeAllObjects];
    
}

- (void)resetStatusNotificationCount {
    _statusNotificationCount = 0;
    [self postAiccuStatusNotification];
}

- (void)taskTerminated:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuDidTerminate object:@([_task terminationStatus])];
	_task = nil;
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

//
//  gogocAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "gogocAdapter.h"
#include "platform.h"
#include "gogoc_status.h"
#include "config.h"
#include "net.h"
#include "tsp_redirect.h"

gogoc_status         tspSetupTunnel        ( tConf *, net_tools_t *,
                                            sint32_t version_index,
                                            tBrokerList **broker_list );


@implementation gogocAdapter

- (id)init
{
    if (self=[super init]) {
        _task = nil;
        _postTimer = nil;
        
        [self setName:@"gogoc"];
        [self setConfig:@"gogoc.conf"];
    }
    return self;
}

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    
    return YES;
}

- (NSDictionary *)loadConfigFile:(NSString *)path {
    NSLog(@"Loading gogoc config file");
    
    NSDictionary *config = @{@"username": @"testuser",
                             @"password": @"testpass",
                             @"tunnel_id": @""};
    
    return config;
}

- (BOOL)startFrom:(NSString *)path withConfigFile:(NSString *)configPath
{
    // Is the task running?
    if (_task) {
//        [_task interrupt];
    } else {
        
        _statusNotificationCount = 0;
        _statusQueue = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", nil];
        [_postTimer invalidate];
        
        //_status = [[NSMutableString alloc] init];
        _task = [[NSTask alloc] init];
        [_task setLaunchPath:path];
        NSArray *args = @[@"start", configPath];
		[_task setArguments:args];
		
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

- (NSArray *)requestTunnelList
{
    NSLog(@"Request tunnel list");
    
    NSDictionary *tunnelInfo1 =  @{@"id": @"amsterdam.freenet6.net",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"heartbeat",
                                   @"popid": @"pop01"};
    NSDictionary *tunnelInfo2 =  @{@"id": @"anon-amsterdam.freenet6.net",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"ayiya",
                                   @"popid": @"pop02"};
    
    return @[tunnelInfo1, tunnelInfo2];
    //return [NSArray array];
	
}

- (NSArray *)requestServerList
{
    return @[@"server 1", @"server 2"];
}
@end

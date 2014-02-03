//
//  TKZAiccuAdapter.m
//  maiccu
//
//  Created by Kristof Hannemann on 04.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import "TKZAiccuAdapter.h"
#include "tic.h"
#include "aiccu.h"

#define __cstons(__cstring__)  [NSString stringWithCString:__cstring__ encoding:NSUTF8StringEncoding]

#define nstocs(__nsstring__) (char *)[__nsstring__ cStringUsingEncoding:NSUTF8StringEncoding]

#define cstons(__cstring__)  [NSString stringWithCString:((__cstring__ != NULL) ?  __cstring__ : "") encoding:NSUTF8StringEncoding]


NSString * const TKZAiccuDidTerminate = @"AiccuDidTerminate";
NSString * const TKZAiccuStatus = @"AiccuStatus";

@implementation TKZAiccuAdapter


- (id)init
{
    if (self=[super init]) {
        self.tunnelInfo = [[NSDictionary alloc] init];
        tic = (struct TIC_conf *)malloc(sizeof(struct TIC_conf));
        memset(tic, 0, sizeof(struct TIC_conf));
        _task = nil;
                
        _postTimer = nil;

    }
    return self;
}


- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    
    g_aiccu = (struct AICCU_conf *)malloc(sizeof(struct AICCU_conf));
    memset(g_aiccu, 0, sizeof(struct AICCU_conf));
    
    g_aiccu->username = nstocs(config[@"username"]);
    g_aiccu->password = nstocs(config[@"password"]);
    g_aiccu->protocol = nstocs(@"tic");
    g_aiccu->server = nstocs(@"tic.sixxs.net");
    g_aiccu->ipv6_interface = nstocs(@"tun0");
    g_aiccu->tunnel_id = nstocs(config[@"tunnel_id"]);
    g_aiccu->automatic = true;
    g_aiccu->setupscript = false;
    g_aiccu->requiretls = false;
    g_aiccu->verbose = false; //maybe true for debug
    g_aiccu->daemonize = false;
    g_aiccu->behindnat = false;//[[config objectForKey:@"behindnat"] intValue];
    g_aiccu->pidfile = nstocs(@"/var/run/aiccu.pid");
    g_aiccu->makebeats = true;
    g_aiccu->defaultroute = true;
    g_aiccu->noconfigure = false;
    
    
    
    if(!aiccu_SaveConfig(nstocs(path)))
    {
        NSLog(@"Unable to save aiccu config");
        free(g_aiccu);
        return NO;
    }
    
    free(g_aiccu);
    return YES;
}




- (NSDictionary *)loadConfigFile:(NSString *)path {
    NSLog(@"Loading aiccu config file");
    g_aiccu = NULL;
    aiccu_InitConfig();
    if (!aiccu_LoadConfig(nstocs(path)) ){
        NSLog(@"Unable to load aiccu config file");
        aiccu_FreeConfig();
        return nil;
    }
    
    NSDictionary *config = @{@"username": cstons(g_aiccu->username),
                            @"password": cstons(g_aiccu->password),
                            @"tunnel_id": cstons(g_aiccu->tunnel_id)};
    
    aiccu_FreeConfig();
    
    return config;
}


- (NSDictionary *)__requestTunnelInfoForTunnel:(NSString *)tunnel {
    struct TIC_Tunnel *hTunnel;
    
    hTunnel = tic_GetTunnel(tic, nstocs(tunnel));
    
    if (!hTunnel) return nil;
    
    
    return @{@"id": cstons(hTunnel->sId),
                            @"ipv4_local": cstons(hTunnel->sIPv4_Local),
                            @"ipv6_local": cstons(hTunnel->sIPv6_Local),
                            @"ipv4_pop": cstons(hTunnel->sIPv4_POP),
                            @"ipv6_pop": cstons(hTunnel->sIPv6_POP),
                            @"ipv6_linklocal": cstons(hTunnel->sIPv6_LinkLocal),
                            @"password": cstons(hTunnel->sPassword),
                            @"pop_id": cstons(hTunnel->sPOP_Id),
                            @"type": cstons(hTunnel->sType),
                            @"userstate": cstons(hTunnel->sUserState),
                            @"adminstate": cstons(hTunnel->sAdminState),
                            @"heartbeat_intervall": @(hTunnel->nHeartbeat_Interval),
                            @"ipv6_prefixlength": @(hTunnel->nIPv6_PrefixLength),
                            @"mtu": @(hTunnel->nMTU),
                            @"uses_tundev": @(hTunnel->uses_tundev)};
}





- (NSArray *)__requestTunnelList
{
    struct TIC_sTunnel *hsTunnel, *t;
    NSMutableArray *tunnels = [[NSMutableArray alloc] init];
    
	//if (!tic_Login(g_aiccu->tic, g_aiccu->username, g_aiccu->password, g_aiccu->server)) return 0;
    
	hsTunnel = tic_ListTunnels(tic);
    
	if (!hsTunnel) //if no tunnel is configured
	{
		
		return nil;
	}
    
    
    //catch all tunnel(-id)s from server
	for (t = hsTunnel; t; t = t->next)
	{
		//printf("%s %s %s %s\n", t->sId, t->sIPv6, t->sIPv4, t->sPOPId);
        NSDictionary *tunnelInfo =  @{@"id": cstons(t->sId),
                                    @"ipv6": cstons(t->sIPv6),
                                    @"ipv4": cstons(t->sIPv4),
                                    @"popid": cstons(t->sPOPId)};
        
        //build an array of NSDictionary
        [tunnels addObject:tunnelInfo];
	}
    
	tic_Free_sTunnel(hsTunnel);
	
    return tunnels;
}

- (NSInteger) __loginToTicServer:(NSString *)server withUsername:(NSString *)username andPassword:(NSString *)password
{
    //struct TIC_conf	*tic;
    NSInteger errCode;

    errCode = tic_Login(tic, nstocs(username), nstocs(password), nstocs(server));
    
    if (errCode != true){ 
        NSLog(@"Error retrieving data from tic server!!!");
        return errCode;
    }
    return 0;
}

- (void) __logoutFromTicServerWithMessage:(NSString *)message
{
    tic_Logout(tic, nstocs(message));
    memset(tic, 0, sizeof(struct TIC_conf));
}

- (BOOL)startStopFrom:(NSString *)path withConfigFile:(NSString *)configPath
{
    // Is the task running?
    if (_task) {
        [_task interrupt];

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
        return TRUE;
	}
    return FALSE;
}


- (void)shiftFIFOArray:(NSMutableArray *)array withObject:(id)object{
    [array removeLastObject];
    [array insertObject:object atIndex:0];
}

- (void)dataReady:(NSNotification *)n
{
    NSData *d;
    d = [[n userInfo] valueForKey:NSFileHandleNotificationDataItem];
	    
	if ([d length]) {
        
         NSString *s = [[NSString alloc] initWithData:d
                                            encoding:NSUTF8StringEncoding];
        [self shiftFIFOArray:_statusQueue withObject:s];
        
        [_postTimer invalidate];        
        _statusNotificationCount++;
        
        if (_statusNotificationCount >= [_statusQueue count] - 1) {
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
    
    _statusQueue = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", nil];

}

- (void)resetStatusNotificationCount {
    _statusNotificationCount = 0;
    [self postAiccuStatusNotification];
}

- (void)taskTerminated:(NSNotification *)note
{
    //NSLog(@"taskTerminated:");
	
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuDidTerminate object:@([_task terminationStatus])];
	_task = nil;
    //[startButton setState:0];
}

@end

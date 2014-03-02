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

@implementation TKZAiccuAdapter


- (id)init
{
    if (self=[super init]) {
        _tunnelList = [[NSMutableDictionary alloc] init];
        tic = (struct TIC_conf *)malloc(sizeof(struct TIC_conf));
        memset(tic, 0, sizeof(struct TIC_conf));
        
        [self setBinary:@"aiccu"];
        [self setConfigFile:@"aiccu.conf"];
        [self setName:@"SixXS.net"];
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
    g_aiccu->ipv6_interface = [self device];
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

#if 1 
- (NSDictionary *)requestTunnelInfoForTunnel:(NSString *)tunnel {
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

- (NSDictionary *)requestTunnelList
{
    struct TIC_sTunnel *hsTunnel, *t;
    NSMutableDictionary *tunnels = [[NSMutableDictionary alloc] init];
    
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
        NSMutableDictionary *tunnelInfo =  [NSMutableDictionary dictionaryWithDictionary:@{
                                    @"id": cstons(t->sId),
                                    @"ipv6": cstons(t->sIPv6),
                                    @"ipv4": cstons(t->sIPv4),
                                    @"popid": cstons(t->sPOPId)}];
        
        //build an array of NSDictionary
        tunnels[tunnelInfo[@"id"]] = tunnelInfo;
	}
    
	tic_Free_sTunnel(hsTunnel);
	
    return tunnels;
}

- (NSInteger) loginToTicServer
{
    NSInteger errCode;
    NSString *server = [self config][@"server"];
    NSString *username = [self config][@"username"];
    NSString *password = [self config][@"password"];
    
    errCode = tic_Login(tic, nstocs(username), nstocs(password), nstocs(server));
    
    if (errCode != true){ 
        NSLog(@"Error retrieving data from tic server!!!");
        return errCode;
    }
    return 0;
}

- (void) logoutFromTicServerWithMessage:(NSString *)message
{
    tic_Logout(tic, nstocs(message));
    memset(tic, 0, sizeof(struct TIC_conf));
}

#else

//this is a static test method for requestTunnelInfoForTunnel
- (NSDictionary *)requestTunnelInfoForTunnel:(NSString *)tunnel {
    
    NSLog(@"Request tunnel info");
    
    if ([tunnel isEqualToString:@"T12345"]) {
        
        return @{@"id": @"T12345",
                 @"ipv4_local": @"heartbeat",
                 @"ipv6_local": @"2a01:1234:5678:2c0::2",
                 @"ipv4_pop": @"1.2.3.4",
                 @"ipv6_pop": @"123:1233:232:1",
                 @"ipv6_linklocal": @"",
                 @"password": @"bablablabalbal",
                 @"pop_id": @"popid01",
                 @"type": @"6in4-heartbeat",
                 @"userstate": @"enabled",
                 @"adminstate": @"enabled",
                 @"heartbeat_intervall": @60U,
                 @"ipv6_prefixlength": @64U,
                 @"mtu": @1280U,
                 @"uses_tundev": @0U};
        
    }
    else if ([tunnel isEqualToString:@"T67890"]) {
        return @{@"id": @"T67890",
                 @"ipv4_local": @"ayiya",
                 @"ipv6_local": @"2a01:2001:2000::1",
                 @"ipv4_pop": @"1.2.3.4",
                 @"ipv6_pop": @"2a01::1",
                 @"ipv6_linklocal": @"",
                 @"password": @"blablabla",
                 @"pop_id": @"popo02",
                 @"type": @"ayiya",
                 @"userstate": @"enabled",
                 @"adminstate": @"enabled",
                 @"heartbeat_intervall": @60U,
                 @"ipv6_prefixlength": @64U,
                 @"mtu": @1280U,
                 @"uses_tundev": @1U};
        
        
    }
    
    return nil;
}

- (NSDictionary *)requestTunnelList
{
    NSLog(@"Request tunnel list");
    
    NSMutableDictionary *tunnelInfo1 = [NSMutableDictionary dictionaryWithDictionary:@{@"id": @"T12345",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"heartbeat",
                                   @"popid": @"pop01"}];
    NSMutableDictionary *tunnelInfo2 =  [NSMutableDictionary dictionaryWithDictionary:@{@"id": @"T67890",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"ayiya",
                                   @"popid": @"pop02"}];
    
    return @{tunnelInfo1[@"id"]:tunnelInfo1, tunnelInfo2[@"id"]:tunnelInfo2};
}

- (NSInteger) loginToTicServer
{
//    NSString *server = [self config][@"server"];
    NSString *username = [self config][@"username"];
    NSString *password = [self config][@"password"];

    NSLog(@"Login to tic server");
    if ([username isEqualToString:@"foo"] && [password isEqualToString:@"bar"]) {
        return 0;
    }
    return 1;
}

- (void) logoutFromTicServerWithMessage:(NSString *)message
{
    NSLog(@"Logout from tic server");
}

#endif

- (NSArray *)tunnelList
{
    return [_tunnelList allKeys];
}

- (NSArray *)serverList
{
    return @[@"tic.sixxs.net"];
}

- (BOOL)startFrom:(NSString *)path
{
    return [self startFrom:path withArgs:@[@"start", [self name]]];
}

- (void)showSheet:(NSWindow*)window {
    TKZSheetController *sheet = [[TKZSheetController alloc] init];

    [NSApp beginSheet:[sheet window] modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    [NSThread detachNewThreadSelector:@selector(doLogin:) toTarget:self withObject:sheet];
}

- (void)doLogin:(TKZSheetController *)sheet {
    
    NSInteger errorCode = 0;
    NSString *notificationMessage;
    
    [[sheet window] makeKeyAndOrderFront:nil];
    [[sheet window] display];
    
    [[sheet statusLabel] setTextColor:[NSColor blackColor]];
    [[sheet progressIndicator] setIndeterminate:NO];
    
    [[sheet statusLabel] setStringValue:@"Connecting to tic server..."];
    [[sheet progressIndicator] setDoubleValue:25.0f];
    [NSThread sleepForTimeInterval:0.5f];
    
    errorCode = [self loginToTicServer];
    
    [_tunnelList removeAllObjects];

    if (!errorCode) {
        
        [[sheet statusLabel] setStringValue:@"Retrieving tunnel list..."];
        [[sheet progressIndicator] setDoubleValue:50.0f];
        [NSThread sleepForTimeInterval:0.5f];
        
        [_tunnelList addEntriesFromDictionary:[self requestTunnelList]];

        double progressInc = 40.0f / [_tunnelList count];
        
        //NSUInteger tunnelSelectIndex = 0;
        NSArray *tunnels = [self tunnelList];
         for (id tunnel in tunnels)
         {
             //the behavior of "userstate: disabled" and "adminstate: requested" is not implemented yet
         
             [[sheet statusLabel] setStringValue:@"Fetching tunnel info..."];
             [[sheet progressIndicator] incrementBy:progressInc];
             [NSThread sleepForTimeInterval:0.2f];
             
             [_tunnelList[tunnel] addEntriesFromDictionary:[self requestTunnelInfoForTunnel:tunnel]];
             [_tunnelList setObject:[_tunnelList objectForKey:tunnel]
                             forKey:[NSString stringWithFormat:@"-- %@ - %@ --", tunnel, _tunnelList[tunnel][@"type"]]];
             [_tunnelList removeObjectForKey: tunnel];
         }
        
        [[sheet statusLabel] setStringValue:@"Successfully completed."];
        [[sheet progressIndicator] incrementBy:100.0f];
        [NSThread sleepForTimeInterval:0.5f];
        
        validCredentials = YES;
        notificationMessage = @"doLoginComplite";
    }
    //if something went wrong
    else {
        [[sheet statusLabel] setStringValue:@"Invalid login credentials"];
        [[sheet statusLabel] setTextColor:[NSColor redColor]];
        [[sheet progressIndicator] setIndeterminate:YES];
        [NSThread sleepForTimeInterval:2.0f];
        
        validCredentials = NO;
        notificationMessage = @"doLoginError";
    }
    
    [self logoutFromTicServerWithMessage:@"Bye Bye"];
    
    [NSApp endSheet:[sheet window]];
    [[sheet window] orderOut:nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:sheetControllerStatus object:notificationMessage];
}

- (BOOL)forNat {
    NSString *currentTunnel = [self config:@"tunnel_id"];
    return [_tunnelList[currentTunnel][@"type"] isEqualToString:@"ayiya"];
}

- (NSDictionary*)tunnelInfo {
    NSString *currentTunnel = [self config:@"tunnel_id"];
    return _tunnelList[currentTunnel];
}

@end

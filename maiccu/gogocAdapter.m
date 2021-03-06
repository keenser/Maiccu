//
//  gogocAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 German Skalauhov. All rights reserved.
//

#import "gogocAdapter.h"

#include <gogocmessaging/gogocuistrings.h>
#include <gogocconfig/gogocconfig.h>
#include <gogocconfig/gogocvalidation.h>
#include <gogocmessaging/gogocmsgdata.h>

NSDictionary *StatusList = @{@(GOGOC_CLISTAT__DISCONNECTEDIDLE):@"Disconnected. Idle",
               @(GOGOC_CLISTAT__DISCONNECTEDNORETRY):@"Disconnected. No retry",
               @(GOGOC_CLISTAT__DISCONNECTEDERROR):@"Disconnected. Error",
               @(GOGOC_CLISTAT__DISCONNECTEDHACCESSSETUPERROR):@"Disconnected. Haccess setup error",
               @(GOGOC_CLISTAT__DISCONNECTEDHACCESSEXPOSEDEVICESERROR):@"Disconnected. Haccess expose devices error",
               @(GOGOC_CLISTAT__CONNECTING):@"Connecting",
               @(GOGOC_CLISTAT__CONNECTED):@"Connected"};

NSDictionary *tunnelParams = @{
                                @STR_V6ANYV4:@{@"forNat":@YES},
                                @STR_V6V4:@{@"forNat":@NO},
                                @STR_V6UDPV4:@{@"forNat":@YES}
#ifdef V4V6_SUPPORT
                               ,@STR_V4V6:@{@"forNat":@NO}
#endif
                              };

NSDictionary *gTunnelList = @{@"-":@STR_V6ANYV4,@(TUNTYPE_V6V4):@STR_V6V4,@(TUNTYPE_V6UDPV4):@STR_V6UDPV4
#ifdef V4V6_SUPPORT
                ,@(TUNTYPE_V4V6):@STR_V4V6
#endif
                };

@implementation gogocAdapter

- (id)init
{
    if (self=[super init]) {
        [self setBinary:@"gogoc"];
        [self setConfigFile:@"gogoc.conf"];
        [self setName:@"Freenet6.net"];

        gTunnelInfo = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)saveConfig:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];

    using namespace gogocconfig;
    BOOL iRet = NO;
    GOGOCConfig* gpConfig = NULL;
    
    try
    {
        // Create new instance, initialize...
        gpConfig = new GOGOCConfig();
        gpConfig->Initialize( nstocs(path), AM_CREATE );
    }
    catch( error_t nErr )
    {
        return nErr;
    }
    try
    {
        std::string str_buf;
        str_buf = nstocs([self config:@"username"]);

        if (str_buf.empty()) {
            gpConfig->Set_AuthMethod(STR_ANONYMOUS);
            gpConfig->Set_BrokerLstFile("tsp-anonymous-list.txt");
        }
        else {
            gpConfig->Set_UserID(str_buf);
            gpConfig->Set_Passwd(nstocs([self config:@"password"]));
            gpConfig->Set_AuthMethod(STR_ANY);
            gpConfig->Set_BrokerLstFile("tsp-broker-list.txt");
        }
        gpConfig->Set_Server(nstocs([self config:@"server"]));
        gpConfig->Set_TunnelMode(nstocs([self config:@"tunnel_id"]));
        gpConfig->Set_Template("darwin");
        gpConfig->Set_IfTunV6V4( "gif0" );
        gpConfig->Set_IfTunV6UDPV4( [self device] );
//        gpConfig->Set_Log("file","3");
        gpConfig->Set_Log("stderr","1");
//        gpConfig->Set_LogFileName("/tmp/gogoc.log");

        // Saves the configuration
        iRet = gpConfig->Save() ? 0 : -1;
    }
    catch (error_t nErr )
    {
        iRet = nErr;
    }

    delete gpConfig;

    return iRet;
}

- (BOOL)startFrom:(NSString *)path
{
    NSString *config = [NSString stringWithFormat:@"%@/%@",[self configPath], [self configFile]];
    if ([self saveConfig:config]) {
        NSLog(@"save config error");
        return NO;
    };
    return [self startFrom:path withArgs:@[@"-y",@"-n"]];

}

- (void)taskTerminated:(NSNotification *)note
{
    [super taskTerminated:note];
    [gTunnelInfo removeAllObjects];
}

- (NSArray *)tunnelList
{
    return [gTunnelList allValues];
}

- (NSArray *)serverList
{
    NSMutableArray *brokerList;
    NSString  *broker_file;
    if ([[self config:@"username"] length]) {
        brokerList = [NSMutableArray arrayWithArray:@[@"authenticated.freenet6.net", @"broker.freenet6.net"]];
        broker_file = [NSString stringWithFormat:@"%@/tsp-broker-list.txt",[self configPath]];
    }
    else {
        brokerList = [NSMutableArray arrayWithArray:@[@"anonymous.freenet6.net"]];
        broker_file = [NSString stringWithFormat:@"%@/tsp-anonymous-list.txt",[self configPath]];
    }
    NSString *broker_file_contents = [NSString stringWithContentsOfFile:broker_file encoding:NSUTF8StringEncoding error:nil];
    [brokerList addObjectsFromArray:[broker_file_contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
    return [brokerList filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
}

- (BOOL)forNat {
    NSString *currentTunnel = [self config:@"tunnel_id"];
    return [tunnelParams[currentTunnel][@"forNat"]isEqual:@YES];
}

- (NSDictionary*)tunnelInfo {
    return gTunnelInfo;
}

- (oneway void) print:(NSDictionary*)message {
    @try {
        NSLog(@"print %@",message);
    }
    @catch (NSException *exception) {
        NSLog(@"statusUpdate %@",exception);
    }
}

- (oneway void) statusUpdate:(gogocStatusInfo*)pStatusInfo {
    @try {
        gTunnelInfo[@"eStatus"] = StatusList[@(pStatusInfo->eStatus)];
        gTunnelInfo[@"nStatus"] = cstons(get_mui_string(pStatusInfo->nStatus));
        NSString *wholeMessage = [NSString stringWithFormat:@"gogoc-messager state: %@. status: %@",gTunnelInfo[@"eStatus"],gTunnelInfo[@"nStatus"]];
        [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:wholeMessage];
    }
    @catch (NSException *exception) {
        NSLog(@"statusUpdate %@",exception);
    }
}

- (oneway void) tunnelUpdate:(gogocTunnelInfo*)pTunnelInfo {
    @try {
        gTunnelInfo[@"id"] = cstons(pTunnelInfo->szBrokerName);
        gTunnelInfo[@"ipv4_local"] = cstons(pTunnelInfo->szIPV4AddrLocalEndpoint);
        gTunnelInfo[@"ipv6_local"] = cstons(pTunnelInfo->szIPV6AddrLocalEndpoint);
        gTunnelInfo[@"ipv4_pop"] = cstons(pTunnelInfo->szIPV4AddrRemoteEndpoint);
        gTunnelInfo[@"ipv6_pop"] = cstons(pTunnelInfo->szIPV6AddrRemoteEndpoint);
        gTunnelInfo[@"type"] = gTunnelList[@(pTunnelInfo->eTunnelType)];
        gTunnelInfo[@"ipv6_delegatedprefix"] = cstons(pTunnelInfo->szDelegatedPrefix);
        gTunnelInfo[@"addr_dns"] = cstons(pTunnelInfo->szIPV6AddrDns);
        gTunnelInfo[@"pop_id"] = cstons(pTunnelInfo->szUserDomain);
        gTunnelInfo[@"mtu"] = @1280U;
        gTunnelInfo[@"ipv6_prefixlength"] = @128U;
    }
    @catch (NSException *exception) {
        NSLog(@"statusUpdate %@",exception);
    }
    
    NSString *ddnsTemplate = [self config:@"ddns"];
    if ([ddnsTemplate length]) {
        NSString *ddnsURL = [NSString stringWithFormat:ddnsTemplate,gTunnelInfo[@"ipv6_local"]];
        NSError *error = nil;
        NSString *ddnsRet = [NSString stringWithContentsOfURL:[NSURL URLWithString:ddnsURL] encoding:NSASCIIStringEncoding error:&error];
        [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:[NSString stringWithFormat:@"ddns update reply: %@",ddnsRet]];
        if (error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:[NSString stringWithFormat:@"ddns update error: %@. %@.",[error localizedDescription],[error localizedFailureReason]]];
        }
        
    }
}

- (oneway void) brokerUpdate:(gogocBrokerList*)gBrokerList {
    @try {
        while (gBrokerList) {
            NSLog(@"%s %d",gBrokerList->szAddress,gBrokerList->nDistance);
            gBrokerList = gBrokerList->next;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"statusUpdate %@",exception);
    }
}

@end

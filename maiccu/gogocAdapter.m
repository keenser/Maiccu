//
//  gogocAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "gogocAdapter.h"

#include <gogocmessaging/gogocuistrings.h>
#include <gogocconfig/gogocconfig.h>
#include <gogocconfig/gogocvalidation.h>
#include <gogocmessaging/gogocmsgdata.h>

@implementation gogocAdapter

- (id)init
{
    if (self=[super init]) {
        gTunnelInfo = [[NSMutableDictionary alloc] init];
        [self setBinary:@"gogoc"];
        [self setConfigFile:@"gogoc.conf"];
        [self setName:@"Freenet6.net"];
        gTunnelList = @{@"-":@STR_V6ANYV4,@(TUNTYPE_V6V4):@STR_V6V4,@(TUNTYPE_V6UDPV4):@STR_V6UDPV4
#ifdef V4V6_SUPPORT
                            ,@(TUNTYPE_V4V6):@STR_V4V6
#endif
                            };
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
        gpConfig->Set_AlwaysUseLastSrv("yes");
        //gpConfig->Set_gogocDir(str_buf = [[[NSBundle mainBundle] resourcePath] UTF8String]);
        gpConfig->Set_Log("file","3");
        gpConfig->Set_LogFileName("/tmp/gogoc.log");

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

- (NSDictionary*)tunnelInfo {
    return gTunnelInfo;
}

- (oneway void) print:(NSDictionary*)message {
    NSLog(@"print %@",message);
}

- (oneway void) statusUpdate:(gogocStatusInfo*)pStatusInfo {
    gTunnelInfo[@"eStatus"] = @(pStatusInfo->eStatus);
    gTunnelInfo[@"nStatus"] = cstons(get_mui_string(pStatusInfo->nStatus));
    NSLog(@"%@",gTunnelInfo);
}

- (oneway void) tunnelUpdate:(gogocTunnelInfo*)pTunnelInfo {
    gTunnelInfo[@"id"] = cstons(pTunnelInfo->szBrokerName);
    gTunnelInfo[@"ipv4_local"] = cstons(pTunnelInfo->szIPV4AddrLocalEndpoint);
    gTunnelInfo[@"ipv6_local"] = cstons(pTunnelInfo->szIPV6AddrLocalEndpoint);
    gTunnelInfo[@"ipv4_pop"] = cstons(pTunnelInfo->szIPV4AddrRemoteEndpoint);
    gTunnelInfo[@"ipv6_pop"] = cstons(pTunnelInfo->szIPV6AddrRemoteEndpoint);
    gTunnelInfo[@"type"] = gTunnelList[@(pTunnelInfo->eTunnelType)];
    gTunnelInfo[@"ipv6_delegatedprefix"] = cstons(pTunnelInfo->szDelegatedPrefix);
    gTunnelInfo[@"addr_dns"] = cstons(pTunnelInfo->szIPV6AddrDns);
    gTunnelInfo[@"user_domain"] = cstons(pTunnelInfo->szUserDomain);
}

- (oneway void) brokerUpdate:(gogocBrokerList*)gBrokerList {
    while (gBrokerList) {
        NSLog(@"%s %d",gBrokerList->szAddress,gBrokerList->nDistance);
        gBrokerList = gBrokerList->next;
    }
}

@end

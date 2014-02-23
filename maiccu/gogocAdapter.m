//
//  gogocAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "gogocAdapter.h"

#include <gogocconfig/gogocconfig.h>
#include <gogocconfig/gogocuistrings.h>
#include <gogocconfig/gogocvalidation.h>

@implementation gogocAdapter

- (id)init
{
    if (self=[super init]) {
        [self setName:@"gogoc"];
        [self setConfigfile:@"gogoc.conf"];
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
        str_buf = [[self config:@"username"] UTF8String];

        if (str_buf.empty()) {
            gpConfig->Set_AuthMethod(STR_ANONYMOUS);
            gpConfig->Set_BrokerLstFile("tsp-anonymous-list.txt");
        }
        else {
            gpConfig->Set_UserID(str_buf);
            gpConfig->Set_Passwd(str_buf = [[self config:@"password"] UTF8String]);
            gpConfig->Set_AuthMethod(STR_ANY);
            gpConfig->Set_BrokerLstFile("tsp-broker-list.txt");
        }
        gpConfig->Set_Server(str_buf = [[self config:@"server"] UTF8String]);
        gpConfig->Set_TunnelMode(str_buf = [[self config:@"tunnel_id"] UTF8String]);
        gpConfig->Set_Template("darwin");
        gpConfig->Set_IfTunV6V4( "gif0" );
        gpConfig->Set_IfTunV6UDPV4( "tun0" );
        //gpConfig->Set_gogocDir(str_buf = [[[NSBundle mainBundle] resourcePath] UTF8String]);
        //gpConfig->Set_Log("stderr","0");

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

- (BOOL)startFrom:(NSString *)path withConfigDir:(NSString *)configPath
{
    NSLog(@"startFrom %@ %@", path,configPath);
    NSString *config = [NSString stringWithFormat:@"%@/%@",configPath, [self configfile]];
    if ([self saveConfig:config]) {
        NSLog(@"save config error");
        return NO;
    };
    return [self startFrom:path withConfigDir:configPath withArgs:@[@"-y",@"-n"]];

}

- (NSArray *)tunnelList
{
    NSLog(@"tunnelList");
    return @[@STR_V6ANYV4, @STR_V6V4,@STR_V6UDPV4,@STR_V4V6];
}

- (NSArray *)serverList
{
    if ([[self config:@"username"] length] == 0 ) {
        return @[@"anonymous.freenet6.net"];
    }
    else {
        return @[@"authenticated.freenet6.net", @"broker.freenet6.net"];
    }
}

@end

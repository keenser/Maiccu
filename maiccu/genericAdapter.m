//
//  genericAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "genericAdapter.h"

@implementation genericAdapter

- (id)init
{
    if (self=[super init]) {
    }
    return self;
}

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path {
    return YES;
}

- (NSDictionary *)loadConfigFile:(NSString *)path {
    NSDictionary *config = @{};
    return config;
}

- (void)startStopFrom:(NSString *)path withConfigFile:(NSString *)configPath
{
}

- (NSInteger) loginToTicServer:(NSString *)server withUsername:(NSString *)username andPassword:(NSString *)password
{
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

- (NSArray *)requestTunnelList
{
    NSLog(@"Request tunnel list");
    
    NSDictionary *tunnelInfo1 =  @{@"id": @"T12345",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"heartbeat",
                                   @"popid": @"pop01"};
    NSDictionary *tunnelInfo2 =  @{@"id": @"T67890",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"ayiya",
                                   @"popid": @"pop02"};
    
    return @[tunnelInfo1, tunnelInfo2];
    //return [NSArray array];
	
}

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

@end

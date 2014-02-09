//
//  genericAdapter.h
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface genericAdapter : NSObject

@property (strong) NSString *name;
@property (strong) NSString *config;
@property (strong) NSMenuItem *view;

- (NSInteger) loginToTicServer:(NSString *)server withUsername:(NSString *)username andPassword:(NSString *)password;
- (void) logoutFromTicServerWithMessage:(NSString *)message;
- (NSArray *)requestTunnelList;
- (NSDictionary *)requestTunnelInfoForTunnel:(NSString *)tunnel;
- (NSArray *)requestServerList;

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path;
- (NSDictionary *)loadConfigFile:(NSString *)path;

- (BOOL)startFrom:(NSString *)path withConfigFile:(NSString *)configPath;
- (void)stopFrom;

@end

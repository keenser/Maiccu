//
//  genericAdapter.h
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface genericAdapter : NSObject

- (NSInteger) loginToTicServer:(NSString *)server withUsername:(NSString *)username andPassword:(NSString *)password;
- (void) logoutFromTicServerWithMessage:(NSString *)message;
- (NSArray *)requestTunnelList;
- (NSDictionary *)requestTunnelInfoForTunnel:(NSString *)tunnel;

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path;
- (NSDictionary *)loadConfigFile:(NSString *)path;

- (BOOL)startStopFrom:(NSString *)path withConfigFile:(NSString *)configPath;

@end

//
//  genericAdapter.h
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TKZSheetController.h"

@interface genericAdapter : NSObject

@property (strong) NSString *name;
@property (strong) NSString *configfile;
@property (strong) NSMenuItem *view;

- (NSArray *)requestTunnelList;
- (NSDictionary *)requestTunnelInfoForTunnel:(NSString *)tunnel;
- (NSArray *)requestServerList;
- (void)showSheet:(NSWindow*)window;

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path;
- (NSDictionary *)loadConfigFile:(NSString *)path;

- (BOOL)startFrom:(NSString *)path withConfigFile:(NSString *)configPath;
- (void)stopFrom;

- (void)setConfig:(NSString*)value toKey:(NSString*)key;
- (NSString *)config:(NSString*)key;
- (NSDictionary *)config;

@end

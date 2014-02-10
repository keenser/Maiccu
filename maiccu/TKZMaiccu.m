//
//  TKZMaiccu.m
//  maiccu
//
//  Created by Kristof Hannemann on 20.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import "TKZMaiccu.h"
#import "TKZAiccuAdapter.h"
#import "genericAdapter.h"
#import "gogocAdapter.h"

static TKZMaiccu *defaultMaiccu = nil;

@interface TKZMaiccu () {
    NSFileManager *_fileManager;
    TKZAiccuAdapter *_aiccu;
    gogocAdapter *_gogoc;
    genericAdapter *_adapter;
    BOOL _isAiccuRunning;
}

@end

@implementation TKZMaiccu


- (id)init
{
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];

        _aiccu = [[TKZAiccuAdapter alloc] init];
        _gogoc = [[gogocAdapter alloc] init];
        NSString *adapter = [[NSUserDefaults standardUserDefaults] stringForKey:@"adapter"];
        
        if ([adapter isEqualToString:[_aiccu name]] || adapter == nil) {
            _adapter = _aiccu;
        }
        else if ([adapter isEqualToString:[_gogoc name]]) {
            _adapter = _gogoc;
        }

        _isAiccuRunning = NO;
    }
    return self;
}

+ (id) defaultMaiccu {
    if (!defaultMaiccu) {
        defaultMaiccu = [[TKZMaiccu alloc] init];
    }
    return defaultMaiccu;
}

- (void) setAiccuView:(NSMenuItem *)View {
    [_aiccu setView:View];
}

- (void) setGogocView:(NSMenuItem *)View {
    [_gogoc setView:View];
}

- (NSURL *) appSupportURL {
    NSURL *appSupportURL = [[_fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"Maiccu"];
}

- (NSString *)aiccuPath {
    return [[NSBundle mainBundle] pathForResource:[_adapter name] ofType:@""];
}


- (NSString *)maiccuLogPath {
    NSURL *url = [[_fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [[url URLByAppendingPathComponent:@"Logs/Maiccu.log"] path];
}

- (BOOL) maiccuLogExists {
    return [_fileManager fileExistsAtPath:[self maiccuLogPath]];
}


- (BOOL) aiccuConfigExists {    
    return [_fileManager fileExistsAtPath:[self aiccuConfigPath]];
}

- (NSString *) aiccuConfigPath {
    return [[[self appSupportURL] URLByAppendingPathComponent:[_adapter config]] path];
}

- (void)writeLogMessage:(NSString *)logMessage {    
    if (![self maiccuLogExists] ) {
        [_fileManager createFileAtPath:[self maiccuLogPath] contents:[NSData data] attributes:nil];
    }
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:[self maiccuLogPath]];
    [fileHandle seekToEndOfFile];
    
    NSString *timeStamp = [[NSDate date] descriptionWithLocale:[NSLocale systemLocale]];
    
    NSArray *messages = [logMessage componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n\r"]];
    
    for (NSString *message in messages) {
        if (![message isEqualToString:@""]) {
            NSString *formatedMessage = [NSString stringWithFormat:@"[%@] %@\n", timeStamp, message];
            [fileHandle writeData:[formatedMessage dataUsingEncoding:NSUTF8StringEncoding]];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TKZMaiccuLog" object:formatedMessage];
        }
    }
    
    [fileHandle closeFile];
}

- (BOOL)startStopAdapter {
    if (_isAiccuRunning) {
        [self stopAdapter];
    }
    else {
        [self startAdapter];
    }
    return _isAiccuRunning;
}

- (void)startAdapter {
    if ([self aiccuConfigExists]) {
        _isAiccuRunning = [_adapter startFrom:[self aiccuPath] withConfigFile:[self aiccuConfigPath]];
    }
}

- (void)stopAdapter {
    [self writeLogMessage:@"Adapter will terminate"];
    [_adapter stopFrom];
}

- (NSString *)launchAgentPlistPath {
    NSURL *libUrl = [[_fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [[libUrl URLByAppendingPathComponent:[NSString stringWithFormat:@"LaunchAgents/%@.plist", [[NSBundle mainBundle] bundleIdentifier]]] path];
}


- (NSDictionary *)makeLaunchAgentPList {
    return @{@"Label": [[NSBundle mainBundle] bundleIdentifier],
             @"ProgramArguments": @[[[NSBundle mainBundle] executablePath], @"--start"],
             @"RunAtLoad": @NO};
}

- (BOOL) setToLaunchAgent:(BOOL)value {
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithDictionary:[self makeLaunchAgentPList]];
    plist[@"RunAtLoad"] = @(value);
    return [plist writeToFile:[self launchAgentPlistPath] atomically:YES];
}

- (BOOL)isLaunchAgent {
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:[self launchAgentPlistPath]];
    if (!plist)
        return NO;
    return [plist[@"RunAtLoad"] boolValue];
}

- (void)setAdapterView:(NSMenuItem *)adapterView {
    NSLog(@"setAdapterView %@",adapterView);
    if ([adapterView isEqual:[_aiccu view]] ) {
        _adapter = _aiccu;
    }
    else if ([adapterView isEqual:[_gogoc view]] ) {
        _adapter = _gogoc;
    }
    [[NSUserDefaults standardUserDefaults] setObject:[_adapter name] forKey:@"adapter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSMenuItem *)adapterView {
    return [_adapter view];
}

- (NSString *)getAdapterConfig:(NSString*)key {
    NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:[_adapter name]][key];
    if (value) {
        NSLog(@"getAdapterConfig %@ %@", key,value);
        return value;
    }
    return @"";
}

- (void)setAdapterConfig:(NSString*)value toKey:(NSString*)key {
    NSLog(@"setAdapterConfig %@ %@", value, key);
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[_adapter name]]];
    config[key] = value;
    [[NSUserDefaults standardUserDefaults] setObject:config forKey:[_adapter name]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray*)serverList {
    return [_adapter requestServerList];
}
@end

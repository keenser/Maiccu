//
//  TKZMaiccu.m
//  maiccu
//
//  Created by Kristof Hannemann on 20.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import <Growl/Growl.h>
#import "TKZMaiccu.h"

static TKZMaiccu *defaultMaiccu = nil;

@implementation TKZMaiccu

- (id)init
{
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];

        _aiccu = [[TKZAiccuAdapter alloc] initWithHomeDir:[[self appSupportURL] path]];
        _gogoc = [[gogocAdapter alloc] initWithHomeDir:[[self appSupportURL] path]];

        _adapterList = [[NSMutableDictionary alloc] init];
        _adapterList[[_aiccu name]] = _aiccu;
        _adapterList[[_gogoc name]] = _gogoc;

        NSString *adapter = [[NSUserDefaults standardUserDefaults] stringForKey:@"adapter"];
        
        [self setAdapter:_adapterList[adapter]];
        if([self adapter] == nil) {
            [self setAdapter:_aiccu];
        };
        [self setRunningAdapter:_adapter];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuNotification:) name:TKZAiccuStatus object:nil];
        [NSThread detachNewThreadSelector:@selector(distributiveObjectManager) toTarget:self withObject:nil];        
    }
    return self;
}

+ (id) defaultMaiccu {
    if (!defaultMaiccu) {
        defaultMaiccu = [[TKZMaiccu alloc] init];
    }
    return defaultMaiccu;
}

- (NSURL *) appSupportURL {
    NSURL *appSupportURL = [[_fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"Maiccu"];
}

- (NSString *)aiccuPath {
    return [[NSBundle mainBundle] pathForResource:[_adapter binary] ofType:@""];
}

- (NSString *)maiccuLogPath {
    NSURL *url = [[_fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [[url URLByAppendingPathComponent:@"Logs/Maiccu.log"] path];
}

- (BOOL) maiccuLogExists {
    return [_fileManager fileExistsAtPath:[self maiccuLogPath]];
}

- (BOOL) aiccuConfigExists {
    return [_fileManager fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",[_adapter configPath],[_adapter configFile]]];
}

- (void)writeLogMessage:(NSString *)logMessage {
    NSDictionary *attributes;
    if (_logTextView) {
        attributes = [NSDictionary dictionaryWithObject:[_logTextView font] forKey:NSFontAttributeName];
    }

    if (![self maiccuLogExists] ) {
        [_fileManager createFileAtPath:[self maiccuLogPath] contents:[NSData data] attributes:nil];
    }
    
    NSString *timeStamp = [[NSDate date] descriptionWithLocale:[NSLocale systemLocale]];
    
    NSArray *messages = [logMessage componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    @synchronized(_logTextView) {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:[self maiccuLogPath]];
    [fileHandle seekToEndOfFile];
    
    for (NSString *message in messages) {
        if (![message isEqualToString:@""]) {
            NSString *formatedMessage = [NSString stringWithFormat:@"[%@] %@\n", timeStamp, message];
            [fileHandle writeData:[formatedMessage dataUsingEncoding:NSUTF8StringEncoding]];
            if (_logTextView) {
                NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:formatedMessage attributes:attributes];
                [[_logTextView textStorage] appendAttributedString:attrString];
            }
        }
    }
    if (_logTextView) {
        [_logTextView scrollRangeToVisible: NSMakeRange([[_logTextView string] length], 0)];
    }
    [fileHandle closeFile];
    }
}

- (void)postNotification:(NSString *) message{
    [self writeLogMessage:message];

    NSString *appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    [GrowlApplicationBridge notifyWithTitle:appName
                                description:message
                           notificationName:@"status"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
}

- (void)aiccuNotification:(NSNotification *)aNotification {
    [self postNotification:[aNotification object]];
}

- (BOOL)startStopAdapter {
    if ([_runningAdapter isRunning]) {
        [self stopAdapter];
    }
    else {
        [self startAdapter];
    }
    return [_runningAdapter isRunning];
}

- (void)startAdapter {
    [self setRunningAdapter:_adapter];
    [_runningAdapter startFrom:[self aiccuPath]];
}

- (void)stopAdapter {
    [_runningAdapter stopFrom];
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

- (void)setAdapterView:(NSString *)adapterView {
    [self setAdapter:_adapterList[adapterView]];
    [[NSUserDefaults standardUserDefaults] setObject:[_adapter name] forKey:@"adapter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray*)adapterList {
    return [_adapterList allKeys];
}

- (void)distributiveObjectManager {
    NSConnection *theConnection;
    
    theConnection = [NSConnection connectionWithReceivePort:[NSPort port] sendPort:nil];
    [theConnection setRootObject:_runningAdapter];
    [theConnection registerName:[[NSBundle mainBundle] bundleIdentifier]];
    [[NSRunLoop currentRunLoop] run];
}

@end

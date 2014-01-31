//
//  TKZAppDelegate.m
//  maiccu
//
//  Created by Kristof Hannemann on 04.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import "TKZAppDelegate.h"
#import "TKZAiccuAdapter.h"
#import "genericAdapter.h"
#import "gogocAdapter.h"
#import "TKZDetailsController.h"
#import "TKZMaiccu.h"
#import <Growl/Growl.h>

@interface TKZAppDelegate () {
    NSStatusItem *_statusItem;
    TKZAiccuAdapter *_aiccu;
    gogocAdapter *_gogoc;
    genericAdapter *_adapter;
    TKZMaiccu *_maiccu;
    TKZDetailsController *_detailsController;
    BOOL _isAiccuRunning;
}

@end

@implementation TKZAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //
    NSFileManager *fileManager = [NSFileManager defaultManager];
       
    NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:[_maiccu aiccuPath] error:nil];
    NSString *oktalPermissions = [NSString stringWithFormat:@"%lo", [fileAttributes[NSFilePosixPermissions] integerValue]];
    
    if (![oktalPermissions isEqualToString:@"6755"] ||
        [fileAttributes[NSFileOwnerAccountID] integerValue] ||
        [fileAttributes[NSFileGroupOwnerAccountID] integerValue]
        ) {
        
        NSDictionary *error = [NSDictionary new];
        NSString *shellCmd = [NSString stringWithFormat:@"chmod 6755 \'%@\'; chown root:wheel \'%@\'", [_maiccu aiccuPath], [_maiccu aiccuPath]];
        NSString *script =  [NSString  stringWithFormat:@"do shell script \"%@\" with administrator privileges", shellCmd];;
        NSAppleScript *appleScript = [[NSAppleScript new] initWithSource:script];
        if ([appleScript executeAndReturnError:&error]) {
            //NSLog(@"successfully changed file permissions");
            
        } else {
            [_maiccu writeLogMessage:@"Unable to set file permissions"];
            [[NSApplication sharedApplication] terminate:nil];
            return;
        }
    }
    
    if (![fileManager fileExistsAtPath:@"/dev/tun0"]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:@"Please install the latest TUN/TAP driver"];
        [alert addButtonWithTitle:@"Go to website"];
        [alert runModal];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://tuntaposx.sourceforge.net/download.xhtml"]];
        [[NSApplication sharedApplication] terminate:nil];
        return;
    }

    if(![_maiccu aiccuConfigExists])
        [self clickedDetails:nil];
    
    
    [_maiccu writeLogMessage:@"Maiccu did finish launching"];
    
    for (NSString *arg in [[NSProcessInfo processInfo] arguments]) {
        if ([arg isEqualToString:@"--start"]) {
            [self startstopWasClicked:nil];
            break;
        }
    }
}


- (void)applicationWillTerminate:(NSNotification *)notification {
    [_maiccu writeLogMessage:@"Maiccu will terminate"];
    if (_isAiccuRunning)
        [self startstopWasClicked:nil];
}

- (id)init
{
    self = [super init];
    if (self) {
        //NSLog(@"Init");
        _aiccu = [[TKZAiccuAdapter alloc] init];
        _gogoc = [[gogocAdapter alloc] init];
        _adapter = _aiccu;
        _detailsController = [[TKZDetailsController alloc] init];
        
        [_detailsController setAiccu:_aiccu];
        [_detailsController setGogoc:_gogoc];
        [_detailsController setAdapter:_adapter];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuDidTerminate:) name:TKZAiccuDidTerminate object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuNotification:) name:TKZAiccuStatus object:nil];
        
        _isAiccuRunning = NO;
        
        _maiccu = [TKZMaiccu defaultMaiccu];
        
    }
    return self;
}

- (void)aiccuDidTerminate:(NSNotification *)aNotification {
    [_maiccu writeLogMessage:[NSString stringWithFormat:@"aiccu terminated with status %li", [[aNotification object] integerValue]]];
    [self postNotification:[NSString stringWithFormat:@"aiccu terminated with status %li", [[aNotification object] integerValue]]];
    _isAiccuRunning = NO;
    [_startstopItem setTitle:@"Start"];
}

- (void)aiccuNotification:(NSNotification *)aNotification {
    [_maiccu writeLogMessage:[aNotification object]];
    [self postNotification:[aNotification object]];
}

- (void)postNotification:(NSString *) message{
    NSString *appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    [GrowlApplicationBridge notifyWithTitle:appName
                                description:message
                           notificationName:@"status"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
}

- (void)awakeFromNib {
    _statusItem =[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [_statusItem setMenu:_menu];
    [_statusItem setTitle:@"IPv6"];
    [_statusItem setHighlightMode:YES];
}


- (IBAction)clickedDetails:(id)sender {
    [_detailsController showWindow:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)clickedQuit:(id)sender {
    [[NSApplication sharedApplication] terminate:sender];
}

- (IBAction)startstopWasClicked:(id)sender {
    if (![_maiccu aiccuConfigExists] && !_isAiccuRunning)
        return;
    _isAiccuRunning = YES;
    [_startstopItem setTitle:@"Stop"];
    [_adapter startStopFrom:[_maiccu aiccuPath] withConfigFile:[_maiccu aiccuConfigPath]];
}
@end

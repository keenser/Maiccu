//
//  TKZAppDelegate.m
//  maiccu
//
//  Created by Kristof Hannemann on 04.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import "TKZAppDelegate.h"
#import "TKZDetailsController.h"
#import "TKZMaiccu.h"
#import <Growl/Growl.h>
#import <sys/sysctl.h>
#import <sys/socket.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <net/route.h>
#import <net/if_mib.h>

@interface TKZAppDelegate () {
@private
    NSStatusItem *_statusItem;
    TKZMaiccu *_maiccu;
    TKZDetailsController *_detailsController;
	NSTimer *updateTimer;
    BOOL menuActive;
	NSMutableDictionary		*lastData;
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
    [_maiccu stopAdapter];
}

- (id)init
{
    self = [super init];
    if (self) {
        _detailsController = [[TKZDetailsController alloc] init];
        
        lastData = [[NSMutableDictionary alloc] init];
        _maiccu = [TKZMaiccu defaultMaiccu];
        menuActive = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuDidTerminate:) name:TKZAiccuDidTerminate object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuNotification:) name:TKZAiccuStatus object:nil];
        
        [NSThread detachNewThreadSelector:@selector(distributiveObjectManager) toTarget:self withObject:nil];
        
    }
    return self;
}

- (void)aiccuDidTerminate:(NSNotification *)aNotification {
    [_maiccu writeLogMessage:[NSString stringWithFormat:@"aiccu terminated with status %li", [[aNotification object] integerValue]]];
    [self postNotification:[NSString stringWithFormat:@"aiccu terminated with status %li", [[aNotification object] integerValue]]];
    [_startstopItem setTitle:@"Start"];

    [_bandwidthItem setHidden:YES];
    [updateTimer invalidate];
	updateTimer = nil;
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
    [_menu setDelegate:self];
    [_statusItem setMenu:_menu];
    [_statusItem setTitle:@"IPv6"];
    [_statusItem setHighlightMode:YES];
}

-(void) menuWillOpen:(NSMenu *) theMenu {
    menuActive = YES;
}

-(void) menuDidClose:(NSMenu *) theMenu {
    menuActive = NO;
    [lastData removeAllObjects];
}

- (IBAction)clickedDetails:(id)sender {
    [_detailsController showWindow:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)clickedQuit:(id)sender {
    [[NSApplication sharedApplication] terminate:sender];
}

- (IBAction)startstopWasClicked:(id)sender {
    if ([_maiccu startStopAdapter]) {
        [_startstopItem setTitle:@"Stop"];
        [_bandwidthItem setHidden:NO];
        // Restart the timer
        [updateTimer invalidate];  // Runloop releases and retains the next one
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(updateNetActivityDisplay:)
                                                     userInfo:nil
                                                      repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:updateTimer
                                     forMode:NSEventTrackingRunLoopMode];

    }
}

- (void)updateNetActivityDisplay:(NSTimer *)timer {
    char *ifname=[[_maiccu adapter] device];
    if (menuActive)
    {
        struct ifmibdata ifmd;
        size_t len = sizeof(ifmd);
        int			name[6];
        name[0] = CTL_NET;
        name[1] = PF_LINK;
        name[2] = NETLINK_GENERIC;
        name[3] = IFMIB_IFDATA;
        name[4] = if_nametoindex(ifname);
        name[5] = IFDATA_GENERAL;
        if (sysctl(name, 6, &ifmd, &len, (void*)0, 0) < 0) {
            return;
        }
        
        double floatIn = 0;
        double floatOut = 0;
        NSString *prefix = @"bit/s";
        
        if (ifmd.ifmd_flags & IFF_UP) {
            uint64_t lastifIn = [lastData[@"ifin"] unsignedLongLongValue];
            uint64_t lastifOut = [lastData[@"ifout"] unsignedLongLongValue];
            lastData[@"ifin"] = [NSNumber numberWithUnsignedLongLong:ifmd.ifmd_data.ifi_ibytes];
            lastData[@"ifout"] = [NSNumber numberWithUnsignedLongLong:ifmd.ifmd_data.ifi_obytes];

            if (lastifIn == 0) lastifIn = ifmd.ifmd_data.ifi_ibytes;
            if (lastifOut == 0) lastifOut = ifmd.ifmd_data.ifi_obytes;

            uint64_t deltaIn = ifmd.ifmd_data.ifi_ibytes - lastifIn;
            uint64_t deltaOut = ifmd.ifmd_data.ifi_obytes - lastifOut;

            uint64_t deltaMax = (deltaIn >= deltaOut)? deltaIn:deltaOut;

            if (deltaMax / (1024 * 1024 / 8) ) {
                floatIn = (double)deltaIn / (1024.0 * 1024.0 / 8.0);
                floatOut = (double)deltaOut / (1024.0 * 1024.0 / 8.0);
                prefix = @"Mbit/s";
            }
            else if (deltaMax / (1024 / 8) ) {
                floatIn = (double)deltaIn / (1024.0 / 8.0);
                floatOut = (double)deltaOut / (1024.0 / 8.0);
                prefix = @"Kbit/s";
            }
            else {
                floatIn = (double)deltaIn * 8;
                floatOut = (double)deltaOut * 8;
            }
        }
        NSString *string = [NSString stringWithFormat:@"%0.1f/%0.1f %@ Rx/Tx",floatIn,floatOut,prefix];
        [_bandwidthItem setTitle:string];
    }
}

- (void)distributiveObjectManager {
    genericAdapter *serverObject = [_maiccu adapter];
    NSConnection *theConnection;
    
    theConnection = [NSConnection connectionWithReceivePort:[NSPort port] sendPort:nil];
    [theConnection setRootObject:serverObject];
    [theConnection registerName:@"com.twikz.Maiccu"];
    [[NSRunLoop currentRunLoop] run];
}

@end

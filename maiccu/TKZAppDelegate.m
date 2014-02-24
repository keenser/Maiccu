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

@interface TKZAppDelegate () {
@private
    NSStatusItem *_statusItem;
    TKZMaiccu *_maiccu;
    TKZDetailsController *_detailsController;
	NSTimer *updateTimer;
    BOOL menuActive;
	size_t sysctlBufferSize;
	uint8_t *sysctlBuffer;
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuDidTerminate:) name:TKZAiccuDidTerminate object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aiccuNotification:) name:TKZAiccuStatus object:nil];
        
        _maiccu = [TKZMaiccu defaultMaiccu];
        menuActive = NO;
        
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
    if (sysctlBuffer) free(sysctlBuffer);

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
//    [updateTimer invalidate];  // Runloop releases and retains the next one
    float sampleInterval = 1.0;
    if (menuActive)
    {
        // Get sizing info from sysctl and resize as needed.
        int	mib[] = { CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0 };
        size_t currentSize = 0;
        if (sysctl(mib, 6, NULL, &currentSize, NULL, 0) != 0) return;
        if (!sysctlBuffer || (currentSize > sysctlBufferSize)) {
            if (sysctlBuffer) free(sysctlBuffer);
            sysctlBufferSize = 0;
            sysctlBuffer = malloc(currentSize);
            if (!sysctlBuffer) return;
            sysctlBufferSize = currentSize;
        }
        
        // Read in new data
        if (sysctl(mib, 6, sysctlBuffer, &currentSize, NULL, 0) != 0) return;
        
        // Walk through the reply
        uint8_t *currentData = sysctlBuffer;
        uint8_t *currentDataEnd = sysctlBuffer + currentSize;
        NSMutableDictionary	*newStats = [NSMutableDictionary dictionary];
        while (currentData < currentDataEnd) {
            // Expecting interface data
            struct if_msghdr2 *ifmsg = (struct if_msghdr2 *)currentData;
            if (ifmsg->ifm_type != RTM_IFINFO2) {
                currentData += ifmsg->ifm_msglen;
                continue;
            }
            // Must not be loopback
            if (ifmsg->ifm_flags & IFF_LOOPBACK) {
                currentData += ifmsg->ifm_msglen;
                continue;
            }
            // Only look at link layer items
            struct sockaddr_dl *sdl = (struct sockaddr_dl *)(ifmsg + 1);
            if (sdl->sdl_family != AF_LINK) {
                currentData += ifmsg->ifm_msglen;
                continue;
            }
            // Build the interface name to string so we can key off it
            // (using NSData here because initWithBytes is 10.3 and later)
            NSString *interfaceName = [[NSString alloc]
										initWithData:[NSData dataWithBytes:sdl->sdl_data length:sdl->sdl_nlen]
                                        encoding:NSASCIIStringEncoding];
            if (!interfaceName) {
                currentData += ifmsg->ifm_msglen;
                continue;
            }
            // Load in old statistics for this interface
            NSDictionary *oldStats = [lastData objectForKey:interfaceName];
            
            if ([interfaceName hasPrefix:@"ppp"]) {
            } else {
                // Not a PPP connection
                if (oldStats && (ifmsg->ifm_flags & IFF_UP)) {
                    // Non-PPP data is sized at u_long, which means we need to deal
                    // with 32-bit and 64-bit differently
                    uint64_t lastTotalIn = [[oldStats objectForKey:@"totalin"] unsignedLongLongValue];
                    uint64_t lastTotalOut = [[oldStats objectForKey:@"totalout"] unsignedLongLongValue];
                    // New totals
                    uint64_t totalIn = 0, totalOut = 0;
                    // Values are always 32 bit and can overflow
                    uint32_t lastifIn = [[oldStats objectForKey:@"ifin"] unsignedIntValue];
                    uint32_t lastifOut = [[oldStats objectForKey:@"ifout"] unsignedIntValue];
                    if (lastifIn > ifmsg->ifm_data.ifi_ibytes) {
                        totalIn = lastTotalIn + ifmsg->ifm_data.ifi_ibytes + UINT_MAX - lastifIn + 1;
                    } else {
                        totalIn = lastTotalIn + (ifmsg->ifm_data.ifi_ibytes - lastifIn);
                    }
                    if (lastifOut > ifmsg->ifm_data.ifi_obytes) {
                        totalOut = lastTotalOut + ifmsg->ifm_data.ifi_obytes + UINT_MAX - lastifOut + 1;
                    } else {
                        totalOut = lastTotalOut + (ifmsg->ifm_data.ifi_obytes - lastifOut);
                    }
                    // New deltas (64-bit overflow guard, full paranoia)
                    uint64_t deltaIn = (totalIn > lastTotalIn) ? (totalIn - lastTotalIn) : 0;
                    uint64_t deltaOut = (totalOut > lastTotalOut) ? (totalOut - lastTotalOut) : 0;
                    // Peak
                    double peak = [[oldStats objectForKey:@"peak"] doubleValue];
                    if (sampleInterval > 0) {
                        if (peak < (deltaIn / sampleInterval)) peak = deltaIn / sampleInterval;
                        if (peak < (deltaOut / sampleInterval)) peak = deltaOut / sampleInterval;
                    }
                    [newStats setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithUnsignedLong:ifmsg->ifm_data.ifi_ibytes],
                                         @"ifin",
                                         [NSNumber numberWithUnsignedLong:ifmsg->ifm_data.ifi_obytes],
                                         @"ifout",
                                         [NSNumber numberWithUnsignedLongLong:deltaIn],
                                         @"deltain",
                                         [NSNumber numberWithUnsignedLongLong:deltaOut],
                                         @"deltaout",
                                         [NSNumber numberWithUnsignedLongLong:totalIn],
                                         @"totalin",
                                         [NSNumber numberWithUnsignedLongLong:totalOut],
                                         @"totalout",
                                         [NSNumber numberWithDouble:peak],
                                         @"peak",
                                         nil]
                                 forKey:interfaceName];
                } else {
                    [newStats setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                         // Paranoia, is this where the neg numbers came from?
                                         [NSNumber numberWithUnsignedLong:ifmsg->ifm_data.ifi_ibytes],
                                         @"ifin",
                                         [NSNumber numberWithUnsignedLong:ifmsg->ifm_data.ifi_obytes],
                                         @"ifout",
                                         [NSNumber numberWithUnsignedLongLong:ifmsg->ifm_data.ifi_ibytes],
                                         @"totalin",
                                         [NSNumber numberWithUnsignedLongLong:ifmsg->ifm_data.ifi_obytes],
                                         @"totalout",
                                         [NSNumber numberWithDouble:0],
                                         @"peak",
                                         nil]
                                 forKey:interfaceName];
                }
            }
            
            // Continue on
            currentData += ifmsg->ifm_msglen;
        }
        
        // Store and return
        lastData = newStats;

        NSString *string = [NSString stringWithFormat:@"%@/%@ B/S RX/TX",newStats[@"tun0"][@"deltain"],newStats[@"tun0"][@"deltaout"]];
        NSLog(@"%@",newStats[@"tun0"]);
        [_bandwidthItem setTitle:string];
    }
}

@end

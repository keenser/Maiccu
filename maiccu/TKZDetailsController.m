//
//  TKZDetailsController.m
//  maiccu
//
//  Created by Kristof Hannemann on 17.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import "TKZDetailsController.h"
#import "TKZAiccuAdapter.h"
#import "TKZSheetController.h"
#import "TKZMaiccu.h"


@interface TKZDetailsController () {
    NSMutableDictionary *_config;
    TKZMaiccu *_maiccu;
}
-(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;

@end

@implementation TKZDetailsController

- (id)init
{
    self = [super initWithWindowNibName:@"TKZDetailsController"];
    if (self) {
        _config = [[NSMutableDictionary alloc] init];
        _maiccu = [TKZMaiccu defaultMaiccu];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sheetNotification:) name:sheetControllerStatus object:nil];
    }
    return self;
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [_maiccu setAiccuView:_aiccuView];
    [_maiccu setGogocView:_gogocView];
    
    [self awakeFromNib];

    if ([[_maiccu adapter]config:@"username"]) {
        [[_maiccu adapter] showSheet:[self window]];
    }
    
}

-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    NSLog(@"controlTextDidEndEditing");
    [[_maiccu adapter]setConfig:[_usernameField stringValue] toKey:@"username"];
    [[_maiccu adapter]setConfig:[_passwordField stringValue] toKey:@"password"];

    [self awakeFromNib];
    
    // See if it was due to a return
    if ( [[notification userInfo][@"NSTextMovement"] intValue] == NSReturnTextMovement )
    {
        [[_maiccu adapter] showSheet:[self window]];
    }
}

-(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:
     NSUnderlineStyleAttributeName value:@(NSSingleUnderlineStyle) range:range];
    
    [attrString endEditing];
    
    return attrString;
}

- (void)awakeFromNib {
    [_signupLabel setAllowsEditingTextAttributes:YES];
    [_signupLabel setSelectable:YES];
    [_signupLabel setAttributedStringValue:[self hyperlinkFromString:@"No account yet? Sign up on sixXS.net" withURL:[NSURL URLWithString:@"http://www.sixxs.net"]]];
    
    [_brokerPopUp selectItem:[[_maiccu adapter]view]];
    
    [_usernameField setStringValue:[[_maiccu adapter]config:@"username"]];
    [_passwordField setStringValue:[[_maiccu adapter]config:@"password"]];
    
    [[_logTextView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[_logTextView textContainer] setWidthTracksTextView:NO];
    [_logTextView setHorizontallyResizable:YES];
    
    
    NSString *log = [NSString stringWithContentsOfFile:[_maiccu maiccuLogPath] encoding:NSUTF8StringEncoding error:nil];
    
    if (log) {
        [_logTextView setString:log];
    }
    
    [_startupCheckbox setState:[_maiccu isLaunchAgent]];
    
    [_serverField removeAllItems];
    [_serverField addItemsWithObjectValues:[[_maiccu adapter] serverList]];
    [_serverField setStringValue:[[_maiccu adapter]config:@"server"]];
    
    [self sheetNotification:nil];
}

- (void)sheetNotification:(NSNotification *)aNotification {
    if ([[_maiccu adapter] isValid]) {
        [_usernameMarker setHidden:YES];
        [_passwordMarker setHidden:YES];

        [_tunnelPopUp removeAllItems];
        if ([[[_maiccu adapter] tunnelList] count]) {
            [_tunnelPopUp addItemsWithTitles:[[_maiccu adapter] tunnelList]];
            [_tunnelPopUp selectItemWithTitle:[[_maiccu adapter]config:@"tunnel_id"]];
            [_tunnelPopUp setEnabled:YES];

            [_infoButton setEnabled:YES];
            [_natDetectButton setEnabled:YES];
            [_exportButton setEnabled:YES];
        }
        else {
            [_tunnelPopUp addItemWithTitle:@"--no tunnels--"];
            [_tunnelPopUp setEnabled:NO];

            [_infoButton setEnabled:NO];
            [_natDetectButton setEnabled:NO];
            [_exportButton setEnabled:NO];
        }
    }
    else {
        [_passwordField becomeFirstResponder];
        
        [_tunnelPopUp setEnabled:NO];
        [_infoButton setEnabled:NO];
        [_natDetectButton setEnabled:NO];
        [_exportButton setEnabled:NO];
        
        [_usernameMarker setHidden:NO];
        [_passwordMarker setHidden:NO];
    }
}

- (void)doNATDetection:(TKZSheetController *)sheet {
    
    //TKZSheetController *sheet = [[TKZSheetController alloc] init];
    
    //[NSApp beginSheet:[sheet window] modalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
    
    //[NSApp beginSheetModalForWindow:[sheet window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
    
    [[sheet window] makeKeyAndOrderFront:nil];
    [[sheet window] display];
    
    [[sheet statusLabel] setTextColor:[NSColor blackColor]];
    [[sheet progressIndicator] setIndeterminate:YES];
    
    [[sheet statusLabel] setStringValue:@"Checking network enviroment..."];
    [NSThread sleepForTimeInterval:0.5f];
    
    NSError *error = nil;
    NSString *extAddress = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://ipecho.net/plain"] encoding:NSASCIIStringEncoding error:&error];
    
    if (!error) {
        
        BOOL behindNAT = YES;
        for (NSString *address in [[NSHost currentHost] addresses]) {
            if ([extAddress isEqualToString:address]) {
                //->>no nat
                behindNAT = NO;
                break;
            }
        }
        
        if (!behindNAT || [[_maiccu adapter] forNat]) {
            [[sheet statusLabel] setStringValue:@"Everthing seems to be fine."];
            //[NSThread sleepForTimeInterval:2.0f];
        }
        else {
            [[sheet statusLabel] setTextColor:[NSColor orangeColor]];
            [[sheet statusLabel] setStringValue:@"A NAT was detected. Please use a tunnel of type ayiya."];
            
        }
        [NSThread sleepForTimeInterval:2.0f];
    }
    else {
        [[sheet statusLabel] setTextColor:[NSColor redColor]];
        [[sheet statusLabel] setStringValue:@"Error testing tunnel configuration"];
        [NSThread sleepForTimeInterval:2.0f];
    }
    

    [NSApp endSheet:[sheet window]];
    [[sheet window] orderOut:nil];
}

- (IBAction)logButtonWasClicked:(id)sender {
    NSWindow *window = [self window];
    NSView *newView = nil;

    if ([sender state]) {
        newView = _logView;
    }
    else {
        newView = _accountView;
    }

    NSSize currentSize = [[window contentView] frame].size;
    NSSize newSize = [newView frame].size;
	
    float deltaHeight = newSize.height - currentSize.height;
    float deltaWidth = newSize.width - currentSize.width;
    
    NSRect windowFrame = [window frame];
    
    [window setContentView:newView];
    NSRect viewScreenFrame;
    viewScreenFrame.origin.x = windowFrame.origin.x - deltaWidth/2;
    viewScreenFrame.origin.y = windowFrame.origin.y - deltaHeight;
    viewScreenFrame.size.height = newSize.height;
    viewScreenFrame.size.width = newSize.width;
    windowFrame = [window frameRectForContentRect:viewScreenFrame];
    [window setFrame:windowFrame display:YES animate:YES];
}

- (IBAction)clearWasClicked:(id)sender {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager removeItemAtPath:[_maiccu maiccuLogPath] error:nil];
    [fileManager createFileAtPath:[_maiccu maiccuLogPath] contents:[NSData data] attributes:nil];
    [self reloadWasClicked:sender];
}

- (IBAction)reloadWasClicked:(id)sender {
    [_logTextView setString:[NSString stringWithContentsOfFile:[_maiccu maiccuLogPath] encoding:NSUTF8StringEncoding error:nil]];
}

- (IBAction)infoWasClicked:(id)sender {
    if ([sender state]) {
        NSDictionary *tunnelInfo = [[_maiccu adapter] tunnelInfo];
        
        //set text in popup view
        [_tunnelHeadField setStringValue:[NSString stringWithFormat:@"Tunnel %@", tunnelInfo[@"id"]]];
        [_tunnelInfoField setStringValue:[NSString stringWithFormat:
                                          @"Popid     : %@\n"
                                          @"Type      : %@\n\n"
                                          @"IPv4 local: %@\n"
                                          @"IPv4 pop  : %@\n\n"
                                          @"IPv6 local: %@/%@\n"
                                          @"IPv6 pop  : %@/%@\n\n"
                                          @"MTU       : %@"
                                          ,
                                          tunnelInfo[@"pop_id"],
                                          tunnelInfo[@"type"],
                                          tunnelInfo[@"ipv4_local"],
                                          tunnelInfo[@"ipv4_pop"],
                                          tunnelInfo[@"ipv6_local"], [tunnelInfo[@"ipv6_prefixlength"] stringValue],
                                          tunnelInfo[@"ipv6_pop"], [tunnelInfo[@"ipv6_prefixlength"] stringValue],
                                          [tunnelInfo[@"mtu"] stringValue]
                                          ]];

        [_tunnelPopOver showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxYEdge];
    }
    else {
        [_tunnelPopOver close];
    }
}

- (void)popoverWillClose:(NSNotification *)notification {
    [_infoButton setState:0];
}

- (IBAction)tunnelPopUpHasChanged:(id)sender {
    [[_maiccu adapter]setConfig:[_tunnelPopUp titleOfSelectedItem] toKey:@"tunnel_id"];
}

- (IBAction)brokerPopUpHasChanged:(id)sender {
    [_maiccu setAdapterView:[_brokerPopUp selectedItem]];
    [self awakeFromNib];
}

- (IBAction)autoDetectWasClicked:(id)sender {
    //[NSThread detachNewThreadSelector:@selector(doNATDetection) toTarget:self withObject:nil];
    TKZSheetController *sheet = [[TKZSheetController alloc] init];
    
    [NSApp beginSheet:[sheet window] modalForWindow:[self window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
    [NSThread detachNewThreadSelector:@selector(doNATDetection:) toTarget:self withObject:sheet];
}

- (IBAction)exportWasClicked:(id)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    
    [savePanel setTitle:@"Export"];
    [savePanel setPrompt:@"Export"];
    [savePanel setNameFieldStringValue:@"aiccu.conf"];
    [savePanel setAllowedFileTypes:@[@"conf"]];
    [savePanel setExtensionHidden:NO];
    [savePanel beginSheetModalForWindow:[self window] completionHandler:nil];
    //if ([savePanel runModal] == NSOKButton) {
        //[_adapter saveConfig:_config toFile:[[savePanel URL] path]];
    //}
}
- (IBAction)startupHasChanged:(id)sender {
    [_maiccu setToLaunchAgent:[_startupCheckbox state]];
}

- (IBAction)serverHasChanged:(id)sender {
    [[_maiccu adapter]setConfig:[_serverField stringValue] toKey:@"server"];
}
@end

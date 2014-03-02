//
//  TKZDetailsController.h
//  maiccu
//
//  Created by Kristof Hannemann on 17.05.13.
//  Copyright (c) 2013 Kristof Hannemann. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "genericAdapter.h"
#import "TKZAiccuAdapter.h"
#import "gogocAdapter.h"

@interface TKZDetailsController : NSWindowController <NSTextFieldDelegate, NSPopoverDelegate, NSWindowDelegate>

//views
@property (strong) IBOutlet NSView *accountView;
@property (strong) IBOutlet NSView *logView;


//toolbar
@property (weak) IBOutlet NSButton *logButton;

- (IBAction)logButtonWasClicked:(id)sender;


//account view
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSSecureTextField *passwordField;
@property (weak) IBOutlet NSTextField *signupLabel;
@property (weak) IBOutlet NSImageView *usernameMarker;
@property (weak) IBOutlet NSImageView *passwordMarker;
@property (weak) IBOutlet NSPopUpButton *brokerPopUp;
@property (weak) IBOutlet NSComboBox *serverField;

- (IBAction)serverHasChanged:(id)sender;

- (IBAction)brokerPopUpHasChanged:(id)sender;


//setup view
@property (weak) IBOutlet NSPopUpButton *tunnelPopUp;
@property (weak) IBOutlet NSButton *infoButton;
@property (weak) IBOutlet NSButton *natDetectButton;
@property (weak) IBOutlet NSButton *exportButton;

@property (weak) IBOutlet NSTextField *tunnelHeadField;
@property (weak) IBOutlet NSTextField *tunnelInfoField;
@property (strong) IBOutlet NSPopover *tunnelPopOver;
@property (weak) IBOutlet NSButton *startupCheckbox;
- (IBAction)startupHasChanged:(id)sender;

- (IBAction)infoWasClicked:(id)sender;
- (IBAction)tunnelPopUpHasChanged:(id)sender;
- (IBAction)autoDetectWasClicked:(id)sender;
- (IBAction)exportWasClicked:(id)sender;





@property (unsafe_unretained) IBOutlet NSTextView *logTextView;
- (IBAction)clearWasClicked:(id)sender;
- (IBAction)reloadWasClicked:(id)sender;





@end

//
//  ViewController.h
//  SphereBot Sender
//
//  Copyright 2011 Eberhard Rensch, http://pleasantsoftware.com/developer/3d
//
//  This code is based on ArduinoSerial (see below)
//
//  ArduinoSerial
//
//  Created by Pat O'Keefe on 4/30/09.
//  Copyright 2009 POP - Pat OKeefe Productions. All rights reserved.
//
//	Portions of this code were derived from Andreas Mayer's work on AMSerialPort. 
//	AMSerialPort was absolutely necessary for the success of this project, and for
//	this, I thanks Andreas. This is just a glorified adaptation to present an interface
//	for the ambitious programmer and work well with Arduino serial messages.
//  
//	AMSerialPort is Copyright 2006 Andreas Mayer.
//


#import <Cocoa/Cocoa.h>
#import "AMSerialPort.h"

@interface ViewController : NSObject {

	AMSerialPort *port;
	
	IBOutlet NSPopUpButton	*serialSelectMenu;
	IBOutlet NSTextField	*textField;
	IBOutlet NSButton		*connectButton, *sendButton;
	IBOutlet NSTextField	*serialScreenMessage;
	IBOutlet NSTextField	*sendFileMessage;
	IBOutlet NSWindow	*window;

	NSArray* gcode;
	NSInteger lineIndex;
	BOOL sendingFile;
}

@property (retain) NSArray* gcode;
@property (assign) BOOL sendingFile;

// Interface Methods
- (IBAction)attemptConnect:(id)sender;
- (IBAction)send:(id)sender;
- (IBAction)sendFile:(id)sender;
- (IBAction)sendAgain:(id)sender;
- (IBAction)abortSendFile:(id)sender;

// Serial Port Methods
- (AMSerialPort *)port;
- (void)setPort:(AMSerialPort *)newPort;
- (void)listDevices;
- (void)initPort;

- (void)sendNextLine:(NSString*)response;
@end
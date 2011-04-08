//
//  ViewController.m
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
//	this, I thank Andreas. This is just a glorified adaptation to present an interface
//	for the ambitious programmer and work well with Arduino serial messages.
//  
//	AMSerialPort is Copyright 2006 Andreas Mayer.
//



#import "ViewController.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"


@implementation ViewController

@synthesize gcode, sendingFile;

- (void)awakeFromNib
{
	
	[sendButton setEnabled:NO];
	
	/// set up notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
	
	/// initialize port list to arm notifications
	[AMSerialPortList sharedPortList];
	[self listDevices];
	
}

- (void) dealloc
{
	[gcode release];
	[super dealloc];
}


- (IBAction)attemptConnect:(id)sender {
	
	[serialScreenMessage setStringValue:@"Attempting to Connect..."];
	[self initPort];
	
}


# pragma mark Serial Port Stuff

- (void)initPort
{
	NSString *deviceName = [serialSelectMenu titleOfSelectedItem];
	if (![deviceName isEqualToString:[port bsdPath]]) {
		[port close];
		
		[self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
		[port setDelegate:self];
		
		if ([port open]) {
			
			//Then I suppose we connected!
			NSLog(@"successfully connected");
			
			[connectButton setEnabled:NO];
			[sendButton setEnabled:YES];
			[serialScreenMessage setStringValue:@"Connection Successful!"];
			
			//TODO: Set appropriate baud rate here. 
			
			//The standard speeds defined in termios.h are listed near
			//the top of AMSerialPort.h. Those can be preceeded with a 'B' as below. However, I've had success
			//with non standard rates (such as the one for the MIDI protocol). Just omit the 'B' for those.
			
			[port setSpeed:B115200]; 
			
			
			// listen for data in a separate thread
			[port readDataInBackground];
			
			
		} else { // an error occured while creating port
			
			NSLog(@"error connecting");
			[serialScreenMessage setStringValue:@"Error Trying to Connect..."];
			[self setPort:nil];
			
		}
	}
}




- (void)serialPortReadData:(NSDictionary *)dataDictionary
{
	
	AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
	NSData *data = [dataDictionary objectForKey:@"data"];
	
	if ([data length] > 0) {
		
		NSString *receivedText = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
		//NSLog(@"Serial Port Data Received: %@",receivedText);
		
		if(sendingFile && gcode)
			[self performSelector:@selector(sendNextLine:) withObject:receivedText afterDelay:0.];
		
        [receivedText release];
        
		// continue listening
		[sendPort readDataInBackground];
		
	} else { 
		// port closed
		NSLog(@"Port was closed on a readData operation...not good!");
	}
	
}

- (void)listDevices
{
	// get an port enumerator
	NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
	AMSerialPort *aPort;
	[serialSelectMenu removeAllItems];
	
	while ((aPort = [enumerator nextObject])) {
		[serialSelectMenu addItemWithTitle:[aPort bsdPath]];
	}
}

- (IBAction)send:(id)sender
{
	
	NSString *sendString = [[textField stringValue] stringByAppendingString:@"\r"];
	
	if(!port) {
		[self initPort];
	}
	
	if([port isOpen]) {
		[port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
	}
}

- (void)sendNextLine:(NSString*)response
{
	if([response hasPrefix:@"ok:"])
	{
		if([port isOpen]) {
			NSString* line=nil;
			do
			{
				line = [gcode objectAtIndex:lineIndex++];
			} while(line.length==0 && lineIndex<gcode.count);
			if(line.length>0 && sendingFile)
			{
				[sendFileMessage setStringValue:[NSString stringWithFormat:@"Sending Line %d: %@", lineIndex-1, line]];
				NSString *sendString = [line stringByAppendingString:@"\n"];
				[port writeString:sendString usingEncoding:NSUTF8StringEncoding error:NULL];
			}
			if(lineIndex>=gcode.count)
			{
				[sendFileMessage setStringValue:@"File sent complete"];
				self.sendingFile = NO;
			}
			else if(!sendingFile)
			{
				[sendFileMessage setStringValue:@"File sent abort"];
				[port writeString:@"M18\n" usingEncoding:NSUTF8StringEncoding error:NULL];
			}
		}
	}
	else
	{
		self.sendingFile = NO;
		[sendFileMessage setStringValue:[NSString stringWithFormat:@"Error at line %d: %@", lineIndex-1, response]];
	}
}

- (IBAction)abortSendFile:(id)sender
{
	self.sendingFile = NO;
}

- (IBAction)sendFile:(id)sender
{
	if(!sendingFile)
	{
		NSOpenPanel* openPanel = [NSOpenPanel openPanel];
		openPanel.allowsMultipleSelection = NO;
        openPanel.allowedFileTypes = [NSArray arrayWithObject:@"gcode"];
        
		[openPanel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
			if(result == NSFileHandlingPanelOKButton)
			{
				NSURL* url = [[openPanel URLs] lastObject];
				NSString* gcodeString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
				if(gcodeString)
				{
					if(!port) {
						[self initPort];
					}
					
					self.gcode = [gcodeString componentsSeparatedByString:@"\n"];
					lineIndex = 0;
					self.sendingFile = YES;
					[self sendNextLine:@"ok:"];
					
				}
			}
		}];
	}
}

- (IBAction)sendAgain:(id)sender
{
	if(!sendingFile && gcode)
	{
		lineIndex = 0;
		self.sendingFile = YES;
		[self sendNextLine:@"ok:"];
	}
}

- (AMSerialPort *)port
{
	return port;
}

- (void)setPort:(AMSerialPort *)newPort
{
	id old = nil;
	
	if (newPort != port) {
		old = port;
		port = [newPort retain];
		[old release];
	}
}


# pragma mark Notifications

- (void)didAddPorts:(NSNotification *)theNotification
{
	NSLog(@"A port was added");
	[self listDevices];
}

- (void)didRemovePorts:(NSNotification *)theNotification
{
	NSLog(@"A port was removed");
	[self listDevices];
}


@end

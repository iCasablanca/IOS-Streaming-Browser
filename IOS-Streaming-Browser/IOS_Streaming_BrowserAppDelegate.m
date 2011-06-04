//
//  IOS_Streaming_BrowserAppDelegate.m
//  IOS-Streaming-Browser
//
//  Created by Will Rubel on 5/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "IOS_Streaming_BrowserAppDelegate.h"
#import "IOS_Streaming_BrowserViewController.h"
#import "HTTPConnection.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"


/** 
    Log levels: off, error, warn, info, verbose
**/
static const int ddLogLevel = LOG_LEVEL_VERBOSE;




@implementation IOS_Streaming_BrowserAppDelegate


@synthesize window;
@synthesize viewController;

/**
    Whether the application did finith launching
    param UIApplication
    param NSDictionary
    returns BOOL
**/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
 
    // Configure our logging framework.
	// To keep things simple and fast, we're just going to log to the Xcode console.
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    [DDLog addLogger:fileLogger];
    
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
    
	
    // Add the view controller's view to the window and display.
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
    
    return YES;
}

/**
    Standard Deconstructor
**/ 
- (void)dealloc
{  
	[viewController release];
	[window release];
	[super dealloc];
}


@end

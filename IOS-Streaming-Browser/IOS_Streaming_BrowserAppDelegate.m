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




@implementation IOS_Streaming_BrowserAppDelegate


@synthesize window;
@synthesize viewController;

/*
 
*/
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
 
    
	
    // Add the view controller's view to the window and display.
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
    
    return YES;
}

/*
    Deconstructor
*/ 
- (void)dealloc
{  
	[viewController release];
	[window release];
	[super dealloc];
}


@end

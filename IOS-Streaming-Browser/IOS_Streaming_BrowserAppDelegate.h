//
//  IOS_Streaming_BrowserAppDelegate.h
//  IOS-Streaming-Browser
//
//  Created by Will Rubel on 5/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@class IOS_Streaming_BrowserViewController;
@class HTTPServer;

@interface IOS_Streaming_BrowserAppDelegate : NSObject <UIApplicationDelegate> {
    

    /**
        @brief The window in the application
    **/
	UIWindow *window;
    
    /**
        @brief The view controller for the views
    **/
	IOS_Streaming_BrowserViewController *viewController;


}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet IOS_Streaming_BrowserViewController *viewController;

@end

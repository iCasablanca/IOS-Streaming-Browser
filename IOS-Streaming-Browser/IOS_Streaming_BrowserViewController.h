//
//  IOS_Streaming_BrowserViewController.h
//  IOS-Streaming-Browser
//
//  Created by Will Rubel on 5/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class HTTPServer;


// The UIWebViewDelegate is telling the app that this class will be 
// the delegate for our UIWebview.  
@interface IOS_Streaming_BrowserViewController : UIViewController <UIWebViewDelegate> {
    
  
    /**
        @brief Creates timer objects
    **/
    NSTimer *clockTimer;
    
    /**
        @brief Creates the assetWrite timer
    **/
	NSTimer *assetWriterTimer;
    
    /**
        @brief Mutable data from mutiple files
    **/
	AVMutableComposition *mutableComposition;
    
    /**
        @brief Object to write media data to a new file
    **/
	AVAssetWriter *assetWriter;
    
    /**
        @brief Used to append media samples packaged as CMSampleBuffer objects, or collections of metadata, to a single track of the output file of an AVAssetWriter object.
    **/
	AVAssetWriterInput *assetWriterInput;
    
    /**
        @brief Used to append video samples packaged as CVPixelBuffer objects to a single AVAssetWriterInput object.
    **/
	AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
    
    
    /**
        @brief Used to represent a specific point in time relative to the absolute reference date of 1 Jan 2001 00:00:00 GMT.
    **/
	CFAbsoluteTime firstFrameWallClockTime;
    
    /**
        @brief The web view on the xib file
    **/
    IBOutlet UIWebView *webView;

    /**
        @brief The address bar in the xib file
    **/
    IBOutlet UITextField *addressBar;
    
    /**
        @brief Indicator is a “gear” that is animated to spin.
    **/
    IBOutlet UIActivityIndicatorView *activityIndicator;
    
    /**
        @brief The ip address and port of the http server which is displayed on the view of the xib file
    **/
    IBOutlet UILabel *displayInfo;
    
    /**
        @brief Dictionary containing the search addresses
    **/
    NSDictionary *addresses;
    
    /**
        @brief The HTTP server
    **/
    HTTPServer *httpServer;
    


}

@property (nonatomic, retain) IBOutlet UIButton *startStopButton;
@property(nonatomic,retain) UIWebView *webView;
@property(nonatomic,retain) UITextField *addressBar;
@property(nonatomic,retain) UIActivityIndicatorView *activityIndicator;


/**
    @param NSNotification
    @return void
**/
- (void)displayInfoUpdate:(NSNotification *) notification;

/**
    @param id
    @return IBAction
**/
-(IBAction) handleStartStopTapped: (id) sender;

/**
    @param id
    @return IBAction
**/
-(IBAction) gotoAddress:(id)sender;

/**
    @param id
    @return IBAction
**/
-(IBAction) goBack:(id)sender;

/**
    @param id
    @return IBAction
**/
-(IBAction) goForward:(id)sender;

/**
    @param id
    @return IBAction
**/
-(IBAction) goHome:(id)sender;

/**
    @param id
    @return IBAction
**/
-(IBAction) reloadPage:(id)sender;

/**
    @param id
    @return IBAction
**/
-(IBAction) stopLoading:(id)sender;

/**
    @param id
    @returns IBAction
**/
-(IBAction) configureButton:(id)sender;

@end

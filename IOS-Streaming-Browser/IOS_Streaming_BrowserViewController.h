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
    
  
    
    // Creates timer objects
    NSTimer *clockTimer;
	NSTimer *assetWriterTimer;
    
    // Mutable data from mutiple files
	AVMutableComposition *mutableComposition;
    
    // Object to write media data to a new file
	AVAssetWriter *assetWriter;
    
	// Used to append media samples packaged as CMSampleBuffer 
    // objects, or collections of metadata, to a single track 
    // of the output file of an AVAssetWriter object.
	AVAssetWriterInput *assetWriterInput;
    
	// Used to append video samples packaged as CVPixelBuffer objects 
    // to a single AVAssetWriterInput object.
	AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferAdaptor;
    
    // used to represent a specific point in time relative to the 
    // absolute reference date of 1 Jan 2001 00:00:00 GMT.
	CFAbsoluteTime firstFrameWallClockTime;
    
    // The web view on the xib file
    IBOutlet UIWebView *webView;

    
    // the address bar in the xib file
    IBOutlet UITextField *addressBar;
    
    // Indicator is a “gear” that is animated to spin.
    IBOutlet UIActivityIndicatorView *activityIndicator;
    

    
    // The ip address and port of the http server which is
    // displayed on the view of the xib file
    IBOutlet UILabel *displayInfo;
    
    // Dictionary containing the search addresses
    NSDictionary *addresses;
    
    HTTPServer *httpServer;
    


}

@property (nonatomic, retain) IBOutlet UIButton *startStopButton;
@property(nonatomic,retain) UIWebView *webView;
@property(nonatomic,retain) UITextField *addressBar;
@property(nonatomic,retain) UIActivityIndicatorView *activityIndicator;



- (void)displayInfoUpdate:(NSNotification *) notification;


-(IBAction) handleStartStopTapped: (id) sender;
-(IBAction) gotoAddress:(id)sender;
-(IBAction) goBack:(id)sender;
-(IBAction) goForward:(id)sender;
-(IBAction) goHome:(id)sender;
-(IBAction) configureButton:(id)sender;

@end

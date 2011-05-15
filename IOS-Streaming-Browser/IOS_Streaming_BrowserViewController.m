//
//  IOS_Streaming_BrowserViewController.m
//  IOS-Streaming-Browser
//
//  Created by Will Rubel on 5/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "IOS_Streaming_BrowserViewController.h"
#import "HTTPServer.h"
#import "HTTPConnection.h"
#import "localhostAddresses.h"




@interface IOS_Streaming_BrowserViewController()
-(void) startRecording;
-(void) stopRecording;
-(UIImage*) screenshot;
@end



@implementation IOS_Streaming_BrowserViewController

@synthesize startStopButton;
@synthesize webView;
@synthesize addressBar;
@synthesize activityIndicator;


/*
 Deallocate the object
 */
- (void)dealloc
{
    [httpServer release];
    [clockTimer invalidate]; clockTimer = nil;
	[assetWriterTimer invalidate]; assetWriterTimer = nil;
	[assetWriter release]; assetWriter = nil;
	[assetWriterInput release]; assetWriterInput = nil;
	[assetWriterPixelBufferAdaptor release]; assetWriterPixelBufferAdaptor = nil;
    [super dealloc];
    
}

/*
 Executed upon the receipt of a memory warning
 */
- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark screenshot

// copied from http://developer.apple.com/library/ios/#qa/qa1703/_index.html ,
// with new imageScale to take Retina-to-320x480 scaling into account
- (UIImage*)screenshot 
{
    
    
    // Create a graphics context with the target size
    // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
    // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
    
    
    // Gets the image size of the main screen
    CGSize imageSize = [[UIScreen mainScreen] bounds].size;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{  
        
        // Set the image scale
        CGFloat imageScale = imageSize.width / 760;
        if (NULL != UIGraphicsBeginImageContextWithOptions)
        {
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, imageScale);
        }else{
            UIGraphicsBeginImageContext(imageSize);
        }
        
    }else
    {
        // Set the image scale
        CGFloat imageScale = imageSize.width / 200;
        if (NULL != UIGraphicsBeginImageContextWithOptions)
        {
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, imageScale);
        }else{
            UIGraphicsBeginImageContext(imageSize);
        }
    }
    
    
    
    
    CGContextRef context = UIGraphicsGetCurrentContext();
	
    // Iterate over every window from back to front
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) 
    {
        if (![window respondsToSelector:@selector(screen)] || [window screen] == [UIScreen mainScreen])
        {
            // -renderInContext: renders in the coordinate space of the layer,
            // so we must first apply the layer's geometry to the graphics context
            CGContextSaveGState(context);
            // Center the context around the window's anchor point
            CGContextTranslateCTM(context, [window center].x, [window center].y);
            // Apply the window's transform about the anchor point
            CGContextConcatCTM(context, [window transform]);
            // Offset by the portion of the bounds left of and above the anchor point
            CGContextTranslateCTM(context,
                                  -[window bounds].size.width * [[window layer] anchorPoint].x,
                                  -[window bounds].size.height * [[window layer] anchorPoint].y);
			
            // Render the layer hierarchy to the current context
            [[window layer] renderInContext:context];
			
            // Restore the context
            CGContextRestoreGState(context);
        }
    }
	
    // Retrieve the screenshot image
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	
    UIGraphicsEndImageContext();
	
    return image;
}


#pragma mark helpers

/*
 Gets the path to the document directory
 */
-(NSString*) pathToDocumentsDirectory {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	return documentsDirectory;
}

/*
 Write the image
 */
-(void) writeImage: (NSTimer*) _timer {
    
    
    NSString *imageName = [NSString stringWithFormat:@"1.png"];
    
	NSString *imagePath = [[self pathToDocumentsDirectory] stringByAppendingPathComponent:imageName];
    
    //NSLog(@"Image Name is: %@",imagePath);
    
    // Check if a file already exists, and if so, remove it
	if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
		[[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
	}
	
    
    // get screenshot image!
    
    [UIImagePNGRepresentation([self screenshot]) writeToFile:imagePath atomically:YES];
    
    //NSLog (@"made screenshot");
    
}


/*
 Start the HTTP server
 */
-(void) startHttpServer
{
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];

    
    // Create server using our custom MyHTTPServer class
	httpServer = [[HTTPServer alloc] init];
	
	// Tell the server to broadcast its presence via Bonjour.
	// This allows browsers such as Safari to automatically discover our service.
	[httpServer setType:@"_http._tcp."];
	
	// Normally there's no need to run our server on any specific port.
	// Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	// However, for easy testing you may want force a certain port so you can just hit the refresh button.
	[httpServer setPort:12345];
	
	// Serve files from our embedded Web folder
	//NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    //	DDLogInfo(@"Setting document root: %@", webPath);
    
    [httpServer setConnectionClass:[HTTPConnection class]];
    
    // Serve files from our embedded Web folder
	//NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Web"];
    //[httpServer setDocumentRoot:webPath];
    
	//NSLog(@"Setting document root: %@", webPath);
    //NSLog(@"root is: %@",root);
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:root]];
	[httpServer setDocumentRoot:root];
    
    //NSLog(@"Setting document root: %@", [NSURL fileURLWithPath:root]);

	// Start the server (and check for problems)
    NSError *error;
    
    // Try and start the http server
    if(![httpServer start:&error])
    {
        NSLog(@"Error starting HTTP Server: %@", error);
    }
    
    // Set the display information for the main browser view to nil because this will be updated with the actual IP address and port once it is obtained from the wireless router
    [self displayInfoUpdate:nil];
    
    
}

/*
 Stop the HTTP server
 */
-(void) stopHttpServer
{
    [httpServer stop];
    [self displayInfoUpdate:nil];
}



/*
 Starts Recording images
 */
-(void) startRecording 
{ 
    [self startHttpServer];
	// start writing images to it every tenth of a second
	[assetWriterTimer release];
	assetWriterTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
														target:self
													  selector:@selector (writeImage:)
													  userInfo:nil
													   repeats:YES] ;
}

/*
 Stop recording images
 */
-(void) stopRecording {

    [httpServer stop];
	[assetWriterTimer invalidate]; // invalidate the timer
	assetWriterTimer = nil;
	[assetWriter finishWriting]; // Completes the writing of the output file.
	NSLog (@"finished writing");
    
    // Clear images from directory
    // Check if a file already exists, and if so, remove it
    
    NSString *imageName = [NSString stringWithFormat:@"1.png"];
    NSString *imagePath = [[self pathToDocumentsDirectory] stringByAppendingPathComponent:imageName];
    
	
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
        // NSLog(@"File removed");
    }
}


#pragma mark - View lifecycle

- (void) viewWillAppear:(BOOL)animated {
    //[self refresh];
    //[self fixupAdView:[UIDevice currentDevice].orientation];
}


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{

    
    [super viewDidLoad];

 
    
    
   
    
    // Adds an observer to the local notification center to call the
    // displayInfoUpdate method once the local host is resolved
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
    
    
	[localhostAddresses performSelectorInBackground:@selector(list) withObject:nil];
    
    // Set the defaults web address to load by creating a 
    // string, then converting the string to a URL.  The URL is
    // then put inside a URL request
    NSString *urlAddress = @"http://google.com";
	
	NSURL *url = [NSURL URLWithString:urlAddress];
	NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
	
	[webView loadRequest:requestObj];
	[addressBar setText:urlAddress];
    
    
    //displayInfo.text = @"None";
    
    // Create a view of the standard size at the bottom of the screen.
    
 

    
}

/*
 Executed upon the view unloading
 */
- (void)viewDidUnload
{
  
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [self stopHttpServer];
}


/*
 Whether the screen should autorotate
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return NO;
}


#pragma mark event handlers

/*
 Upon the start/stop button being pressed
 */
-(IBAction) handleStartStopTapped: (id) sender {
	if (self.startStopButton.selected) { // stop recording and deselect
		[self stopRecording];

		self.startStopButton.selected = NO;
        
        
        [startStopButton setTitle:@"Start Broadcasting" forState:UIControlStateNormal];
	} else { // start recording and set the button as selected
		[self startRecording];

		self.startStopButton.selected = YES;
        
          
        
        [startStopButton setTitle:@"Stop Broadcasting" forState:UIControlStateSelected];
	}
}

/*
 Gets the address from the address bar, and updates
 the webview with the requested URL
 */
-(IBAction)gotoAddress:(id) sender {
    
    // Gets the text from the address bar
	NSURL *url = [NSURL URLWithString:[addressBar text]];
    
    // Creates a request for the URL in the address bar
	NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
	
	//Load the request in the UIWebView.
	[webView loadRequest:requestObj];
    
    // Set the address bar as the first responder
	[addressBar resignFirstResponder];
}

/*
 Upon the back button being pressed on the webview
 */
-(IBAction) goBack:(id)sender {
	[webView goBack];
}

/*
 Upon the configure button being pressed
 */
-(IBAction) configureButton:(id)sender {
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Note"
                                                    message:@"Feature not available in free version"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];	
    [alert show];
    [alert release];
}


/*
 Upon the forward button being pressed on the webview
 */
-(IBAction) goForward:(id)sender {
	[webView goForward];
}


/*
 Upon the Home button being pressed on the webview
 */
-(IBAction) goHome:(id)sender {
    // Set the defaults web address to load
    NSString *urlAddress = @"http://google.com";
	
	NSURL *url = [NSURL URLWithString:urlAddress];
	NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
	
	[webView loadRequest:requestObj];
	[addressBar setText:urlAddress];
}


/*
 Starts webview with a specific page
 */
- (BOOL)webView:(UIWebView*)webView shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)navigationType {
    
	//CAPTURE USER LINK-CLICK.
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        
		NSURL *URL = [request URL];	
        
		if ([[URL scheme] isEqualToString:@"http"]) {
			[addressBar setText:[URL absoluteString]];
			[self gotoAddress:nil];
		}	 
		return NO;
	}	
	return YES;   
}


/*
 Start the activity indicator when the webview
 starts loading a webpage
 */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    
	[activityIndicator startAnimating];
}


/*
 Stop the activity indicator when the webview
 finishes loading the webpage
 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    
	[activityIndicator stopAnimating];
}


/*
 Update the broadcast ip/port label on the view
 */
- (void)displayInfoUpdate:(NSNotification *) notification
{
	NSLog(@"displayInfoUpdate:");
    
	if(notification)
	{
		[addresses release];
		addresses = [[notification object] copy];
		NSLog(@"addresses: %@", addresses);
	}
    
    // Return if the notification doesn't contain an address
	if(addresses == nil)
	{
		return;
	}
	
    
	NSString *info;
	UInt16 port = [httpServer port]; // get http server port
	
	NSString *localIP = nil;
	
	localIP = [addresses objectForKey:@"en0"];
	
    
	if (!localIP)
	{
		localIP = [addresses objectForKey:@"en1"];
	}
    
	if (!localIP)
    {
		info = @"Wifi: No Connection!\n";
	}else{
		info = [NSString stringWithFormat:@"		http://%@:%d\n",localIP, port];
    }
    
    
	displayInfo.text = info;
}





@end

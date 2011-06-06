//
//  main.m
//  IOS-Streaming-Browser
//
//  Created by Will Rubel on 5/12/11.
//  Copyright 2011 Will Rubel. All rights reserved.
//

/*! \mainpage IOS Steaming Browser Index Page
 *
 * \section intro_sec Introduction
 *
 * This is the documentation for the IOS Steaming Browser.
 */


#import <UIKit/UIKit.h>

/**
    @brief Kernel entrypoint
    @param int
    @param char
    @return int
**/
int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    // Calls the UIApplication with the arguements
    int retVal = UIApplicationMain(argc, argv, nil, nil);
    
    [pool release];
    
    return retVal;
}

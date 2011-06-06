/** Software License Agreement (BSD License)
 
 Copyright (c) 2011, Deusty, LLC
 All rights reserved.
 
 Redistribution and use of this software in source and binary forms,
 with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above
 copyright notice, this list of conditions and the
 following disclaimer.
 
 * Neither the name of Deusty nor the names of its
 contributors may be used to endorse or promote products
 derived from this software without specific prior
 written permission of Deusty, LLC.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
**/

#import "localhostAddresses.h"

#import <ifaddrs.h>
#import <netinet/in.h>
#import <sys/socket.h>


@implementation localhostAddresses


/**
    @return void
**/
+ (void)list
{
    // An autorelease pool stores objects that are sent a release 
    // message when the pool itself is drained.
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
    
	NSMutableDictionary* result = [NSMutableDictionary dictionary];
    
    // Creates an ifaddrs structure
	struct ifaddrs*	addrs;
    
    //function creates a linked list of structures describing the
    // network interfaces of the local system, and stores the address 
    // of the first item of the list in *ifap.
	BOOL success = (getifaddrs(&addrs) == 0);
    
    // If successful in getting the addresses
	if (success) 
	{
        // Create a constant read only local attribute
		const struct ifaddrs* cursor = addrs;
        
        // Loop through the struct while not NULL 
		while (cursor != NULL) 
		{
            // Creates a local attribute
			NSMutableString* ip;
            
            // AF_INET is the address family for an internet socket
			if (cursor->ifa_addr->sa_family == AF_INET) 
			{
                // Create a constant read only local attribute
				const struct sockaddr_in* dlAddr = (const struct sockaddr_in*)cursor->ifa_addr;
                
                // Create a constant read only local attribute
				const uint8_t* base = (const uint8_t*)&dlAddr->sin_addr;
                
                // Initializes and allocates memory for the new ip
				ip = [[NSMutableString new] autorelease];
                
                // Loops through the address and adds a period
				for (int i = 0; i < 4; i++) 
				{
					if (i != 0) 
                    {
						[ip appendFormat:@"."];
                    }
                    
					[ip appendFormat:@"%d", base[i]];
				}
                
                
				[result setObject:(NSString*)ip forKey:[NSString stringWithFormat:@"%s", cursor->ifa_name]];
			}
			cursor = cursor->ifa_next;
		}
        // frees the address
		freeifaddrs(addrs);
	}
    
    // Post a notification to the default notification center that the local host address has been resolved
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LocalhostAdressesResolved" object:result];

	[pool release];
}




@end

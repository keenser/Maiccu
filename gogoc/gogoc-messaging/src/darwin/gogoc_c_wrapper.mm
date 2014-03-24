// **************************************************************************
// $Id: gogoc_c_wrapper.cc,v 1.1 2009/11/20 16:34:55 jasminko Exp $
//
// Copyright (c) 2007 gogo6 Inc. All rights reserved.
//
//   For license information refer to CLIENT-LICENSE.TXT
//
// Description:
//   Implementation of the C function wrappers.
//
// Author: German Skalauhov
//
// Creation Date: Feb 2014
// __________________________________________________________________________
// **************************************************************************
#import <Foundation/Foundation.h>
#include <gogocmessaging/gogoc_c_wrapper.h>
#include <gogocmessaging/clientmsgdataretriever.h>
#include "platform.h"
#import "gogocAdapter.h"


// The unique instance of the gogoCLIENT Messenger implementation object.
NSDistantObject *distantObject;


// --------------------------------------------------------------------------
// Function : initialize_messaging
//
// Description:
//   Will instantiate the gogoCLIENT Messenger Impl object, thus providing
//   Messenger capabilities to this process.
//   This implementation ensures that only one messenger object exists at a
//   time.
//
// Arguments: (none)
//
// Return values:
//   GOGOCM_UIS__NOERROR: Successful completion.
//   GOGOCM_UIS_CWRAPALRDYINIT: Initialization procedure previously called.
//
// --------------------------------------------------------------------------
extern "C" error_t initialize_messaging( void )
{
    @autoreleasepool {
        @try {
            if (distantObject == nil) {
                distantObject = [NSConnection rootProxyForConnectionWithRegisteredName:@"com.twikz.Maiccu" host:nil];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"initialize_messaging %@",exception);
        }
        return GOGOCM_UIS__NOERROR;
    }
}


// --------------------------------------------------------------------------
// Function : uninitialize_messaging
//
// Description:
//   Will destroy the gogoCLIENT Messenger Impl object, thus stopping
//   Messenger capabilities to this process.
//
// Arguments: (none)
//
// Return values:
//   GOGOCM_UIS__NOERROR: Successful completion.
//   GOGOCM_UIS_CWRAPNOTINIT: Messenger object had not been initialized.
//
// --------------------------------------------------------------------------
extern "C" error_t uninitialize_messaging( void )
{
    @autoreleasepool {
        if( distantObject == nil )
            return GOGOCM_UIS_CWRAPNOTINIT;
        distantObject = nil;
        return GOGOCM_UIS__NOERROR;
    }
}


// --------------------------------------------------------------------------
// Function : send_status_info
//
// Description:
//   Sends status info to the GUI (or whichever client that's connected).
//
// Arguments: (none)
//
// Return values:
//   GOGOCM_UIS__NOERROR: Successful completion.
//   GOGOCM_UIS_CWRAPNOTINIT: Messenger not initialized.
//
// --------------------------------------------------------------------------
extern "C" error_t send_status_info( void )
{
    @autoreleasepool {
        gogocStatusInfo* pStatusInfo = NULL;
        error_t retCode = GOGOCM_UIS__NOERROR;
        
        
        // Verify if messenger object has been initialized.
        if( distantObject == nil )
            return GOGOCM_UIS_CWRAPNOTINIT;
        
        // Callback to the gogoCLIENT process, to gather required information.
        retCode = RetrieveStatusInfo( &pStatusInfo );
        if( retCode == GOGOCM_UIS__NOERROR )
        {
            @try {
                gogocAdapter *pMessenger = (id)[distantObject self];
                [pMessenger statusUpdate:pStatusInfo];
            }
            @catch (NSException *exception) {
                NSLog(@"send_status_info %@",exception);
            }
            
            // Frees the memory used by the StatusInfo object.
            FreeStatusInfo( &pStatusInfo );
        }
        
        return retCode;
    }
}


// --------------------------------------------------------------------------
// Function : send_tunnel_info
//
// Description:
//   Sends tunnel info to the GUI (or whichever client that's connected).
//
// Arguments: (none)
//
// Return values:
//   GOGOCM_UIS__NOERROR: Successful completion.
//   GOGOCM_UIS_CWRAPNOTINIT: Messenger not initialized.
//
// --------------------------------------------------------------------------
extern "C" error_t send_tunnel_info( void )
{
    @autoreleasepool {
        gogocTunnelInfo* pTunnelInfo = NULL;
        error_t retCode = GOGOCM_UIS__NOERROR;
        
        
        // Verify if messenger object has been initialized.
        if( distantObject == nil )
            return GOGOCM_UIS_CWRAPNOTINIT;
        
        // Callback to the gogoCLIENT process, to gather required information.
        retCode = RetrieveTunnelInfo( &pTunnelInfo );
        if( retCode == GOGOCM_UIS__NOERROR )
        {
            @try {
                gogocAdapter *pMessenger = (id)[distantObject self];
                [pMessenger tunnelUpdate:pTunnelInfo];
            }
            @catch (NSException *exception) {
                NSLog(@"send_tunnel_info %@",exception);
            }
            
            // Frees the memory used by the TunnelInfo object.
            FreeTunnelInfo( &pTunnelInfo );
        }
        
        return retCode;
    }
}


// --------------------------------------------------------------------------
// Function : send_broker_list
//
// Description:
//   Sends broker list to the GUI (or whichever client that's connected).
//
// Arguments: (none)
//
// Return values:
//   GOGOCM_UIS__NOERROR: Successful completion.
//   GOGOCM_UIS_CWRAPNOTINIT: Messenger not initialized.
//
// --------------------------------------------------------------------------
extern "C" error_t send_broker_list( void )
{
    @autoreleasepool {
        gogocBrokerList* pBrokerList = NULL;
        error_t retCode = GOGOCM_UIS__NOERROR;
        
        
        // Verify if messenger object has been initialized.
        if( distantObject == nil )
            return GOGOCM_UIS_CWRAPNOTINIT;
        
        // Callback to the gogoCLIENT process, to gather required information.
        retCode = RetrieveBrokerList( &pBrokerList );
        if( retCode == GOGOCM_UIS__NOERROR )
        {
            @try {
                gogocAdapter *pMessenger = (id)[distantObject self];
                [pMessenger brokerUpdate:pBrokerList];
            }
            @catch (NSException *exception) {
                NSLog(@"send_broker_list %@",exception);
            }
            
            // Frees the memory used by the BrokerList object.
            FreeBrokerList( &pBrokerList );
        }
        
        return retCode;
    }
}


// --------------------------------------------------------------------------
// Function : send_haccess_status_info
//
// Description:
//   Sends HACCESS status info to the GUI (or whichever client that's connected).
//
// Arguments: (none)
//
// Return values:
//   GOGOCM_UIS__NOERROR: Successful completion.
//   GOGOCM_UIS_CWRAPNOTINIT: Messenger not initialized.
//
// --------------------------------------------------------------------------
extern "C" error_t send_haccess_status_info( void )
{
    return GOGOCM_UIS__NOERROR;
}


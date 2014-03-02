//
//  mesager.m
//  maiccu
//
//  Created by German Skalauhov on 28/02/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "message_wrapper.h"
#include <gogocmessaging/gogoc_c_wrapper.h>
#include "platform.h"
#include "log.h"          // Display()

//@implementation message_wrapper

//@end

#if 1
NSString * const TKZAiccuStatus = @"AiccuStatus";

error_t send_status_info( void ) {
    @autoreleasepool {
        genericAdapter *remoteObject;
        id theObject = (id)[NSConnection rootProxyForConnectionWithRegisteredName:@"com.twikz.Maiccu" host:nil];

        remoteObject = theObject;
        [remoteObject print];
    }
    return GOGOCM_UIS__NOERROR;
}

error_t send_tunnel_info( void ) {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_tunnel_info" userInfo:nil deliverImmediately:YES];
    return GOGOCM_UIS__NOERROR;
}

error_t send_broker_list( void ) {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_broker_list" userInfo:nil deliverImmediately:YES];
    return GOGOCM_UIS__NOERROR;
}

error_t send_haccess_status_info( void ) {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_haccess_status_info" userInfo:nil deliverImmediately:YES];
    return GOGOCM_UIS__NOERROR;
}

#else
#include <CoreFoundation/CoreFoundation.h>

error_t send_status_info( void ) {
    CFStringRef observedObject = CFSTR("send_status_info");
    CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(center, CFSTR("AiccuStatus"),
                                         observedObject, NULL /* no dictionary */, TRUE);
    return GOGOCM_UIS__NOERROR;
}

error_t send_tunnel_info( void ) {
    CFStringRef observedObject = CFSTR("send_tunnel_info");
    CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(center, CFSTR("AiccuStatus"),
                                         observedObject, NULL /* no dictionary */, TRUE);
    return GOGOCM_UIS__NOERROR;
}

error_t send_broker_list( void ) {
    CFStringRef observedObject = CFSTR("send_broker_list");
    CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(center, CFSTR("AiccuStatus"),
                                         observedObject, NULL /* no dictionary */, TRUE);
    return GOGOCM_UIS__NOERROR;
}

error_t send_haccess_status_info( void ) {
    CFStringRef observedObject = CFSTR("send_haccess_status_info");
    CFNotificationCenterRef center =
    CFNotificationCenterGetDistributedCenter();
    CFNotificationCenterPostNotification(center, CFSTR("AiccuStatus"),
                                         observedObject, NULL /* no dictionary */, TRUE);
    return GOGOCM_UIS__NOERROR;
}
#endif

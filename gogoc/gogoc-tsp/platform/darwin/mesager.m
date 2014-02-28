//
//  mesager.m
//  maiccu
//
//  Created by German Skalauhov on 28/02/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "mesager.h"

//@implementation mesager

//@end

#include <gogocmessaging/gogocuistrings.h>
// Dummy implementation for non-win32 targets
// (Library gogocmessaging is not linked in non-win32 targets).
NSString * const TKZAiccuStatus = @"AiccuStatus";

error_t send_status_info( void ) {
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_status_info"];
    return GOGOCM_UIS__NOERROR;
}
error_t send_tunnel_info( void ) {
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_tunnel_info"];
    return GOGOCM_UIS__NOERROR;
}
error_t send_broker_list( void ) {
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_broker_list"];
    return GOGOCM_UIS__NOERROR;
}
error_t send_haccess_status_info( void ) {
    [[NSNotificationCenter defaultCenter] postNotificationName:TKZAiccuStatus object:@"send_haccess_status_info"];
    return GOGOCM_UIS__NOERROR;
}


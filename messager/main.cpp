//
//  main.cpp
//  messager
//
//  Created by German Skalauhov on 26/02/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#include <iostream>
//#include <CoreFoundation/CoreFoundation.h>
#include <gogocmessaging/gogoc_c_wrapper.h>

//using namespace gogocmessaging;

//error_t         StatusInfo       ( const gogocStatusInfo* aStatusInfo ) {
    
//}
//error_t         TunnelInfo       ( const gogocTunnelInfo* aTunnelInfo );
//error_t         BrokerList       ( const gogocBrokerList* aBrokerList );

int main(int argc, const char * argv[])
{
    send_status_info();
//    CFStringRef observedObject = CFSTR("com.twikz.Maiccu2");
//    CFNotificationCenterRef center =
//    CFNotificationCenterGetDistributedCenter();
//    CFNotificationCenterPostNotification(center, CFSTR("AiccuStatus"),
//                                         observedObject, NULL /* no dictionary */, TRUE);
    return 0;
}


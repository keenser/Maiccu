//
//  main.cpp
//  messager
//
//  Created by German Skalauhov on 26/02/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

//#include <iostream>
#include <stdio.h>
//#include "pal.h"
//#include "log.h"
//#include <CoreFoundation/CoreFoundation.h>
#include <gogocmessaging/gogoc_c_wrapper.h>
//#include "platform.h"

gogocStatusInfo gStatusInfo;
gogocTunnelInfo gTunnelInfo;
HACCESSStatusInfo gHACCESSStatusInfo;

int main(int argc, const char * argv[])
{
    initialize_messaging();
    send_status_info();
    send_tunnel_info();
    send_broker_list();
    return 0;
}


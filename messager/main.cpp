//
//  main.cpp
//  messager
//
//  Created by German Skalauhov on 26/02/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#include <iostream>
#include <stdio.h>
#include "pal.h"
#include "log.h"
//#include <CoreFoundation/CoreFoundation.h>
//#include <gogocmessaging/gogoc_c_wrapper.h>
//#include "platform.h"

//using namespace gogocmessaging;

//error_t         StatusInfo       ( const gogocStatusInfo* aStatusInfo ) {
    
//}
//error_t         TunnelInfo       ( const gogocTunnelInfo* aTunnelInfo );
//error_t         BrokerList       ( const gogocBrokerList* aBrokerList );

extern "C" const char* get_pal_version( void );
extern "C" char *routepr(void);
extern pal_cs_t logMutex;

// --------------------------------------------------------------------------
/* Send a message to the console (stdout) or stderr */
static int LogToLocal(FILE *location, char *buffer)
{
    /* location should be stdout or stderr. Print to that. */
    if (fprintf(location, "%s\n", buffer) < 0) {
        return 1;
    }
    
    return 0;
}

void Display(int VerboseLevel, enum tSeverityLevel SeverityLvl, const char *func, char *format, ...)
{
    va_list argp;
    char fmt[MAX_LOG_LINE_LENGTH];
    char *clean = fmt;
    
#if !defined(_DEBUG) && !defined(DEBUG)
    // This is a RELEASE build. Remove debug messages.
    if( SeverityLvl == ELDebug )
    {
        return;
    }
#endif
    
//    if( LogConfiguration == NULL )
//    {
//        return;
//    }
    
    pal_enter_cs(&logMutex);
    
    va_start(argp, format);
    pal_vsnprintf(fmt, sizeof(fmt), format, argp);
    va_end(argp);
    
    /* Change CRLF to LF for log output */
    for(int i = 0; i < sizeof(fmt); i++ )
    {
        if( fmt[i] == '\r' )
        {
            continue;
        }
        
        *clean++ = fmt[i];
        if( fmt[i] == '\0' )
        {
            break;
        }
    }
    
        /* Log to the console. */
        LogToLocal( stdout, fmt );
        /* Log to stderr. */
        LogToLocal( stderr, fmt );
        /* Log to file. */
//        LogToFile( LogConfiguration->buffer, SeverityLvl, func, clean );
        /* Log to syslog. */
//        LogToSyslog( VerboseLevel, SeverityLvl, func, clean );
    pal_leave_cs(&logMutex);
}


int main(int argc, const char * argv[])
{
    char *route = routepr();
    Display(LOG_LEVEL_1, ELError, "buffer_put_bignum", "%s\r\n",route);
    return 0;
}


//
//  gogocAdapter.m
//  maiccu
//
//  Created by German Skalauhov on 30/01/2014.
//  Copyright (c) 2014 Kristof Hannemann. All rights reserved.
//

#import "gogocAdapter.h"

#include "platform.h"
#include "gogoc_status.h"

#include "tsp_client.h"

#include "net_udp.h"
#include "net_rudp.h"
#include "net_rudp6.h"
#include "net_tcp.h"
#include "net_tcp6.h"

#include "net.h"
#include "config.h"
#include "tsp_cap.h"
#include "tsp_auth.h"
#include "tsp_net.h"
#include "xml_tun.h"
#include "xml_req.h"
#include "tsp_redirect.h"

#include "version.h"
#include "log.h"
#include "hex_strings.h"


// The gogoCLIENT Messaging subsystem.
#include <gogocmessaging/clientmsgdataretriever.h>
#include <gogocmessaging/clientmsgnotifier.h>
#include <gogocmessaging/gogoc_c_wrapper.h>

#ifdef HACCESS
#include "haccess.h"
#endif

#define CONSEC_RETRY_TO_DOUBLE_WAIT   3   // Consecutive failed connection retries before doubling wait time.
#define TSP_VERSION_FALLBACK_DELAY    5

gogoc_status         tspSetupTunnel        ( tConf *, net_tools_t *,
                                            sint32_t version_index,
                                            tBrokerList **broker_list );

// --------------------------------------------------------------------------
// Retrieves OS information and puts it nicely in a string ready for display.
//
// Defined in tsp_client.h
//
#define OS_UNAME_INFO "Darwin mb.lan 11.4.2 Darwin Kernel Version 11.4.2: Thu Aug 23 16:26:45 PDT 2012; root:xnu-1699.32.7~1/RELEASE_I386 i386"
void tspGetOSInfo( const size_t len, char* buf )
{
    if( len > 0  &&  buf != NULL )
    {
#ifdef OS_UNAME_INFO
        snprintf( buf, len, "Built on ///%s///", OS_UNAME_INFO );
#else
        snprintf( buf, len, "Built on ///unknown UNIX/BSD/Linux version///" );
#endif
    }
}

@implementation gogocAdapter

- (id)init
{
    if (self=[super init]) {
        _task = nil;
        _postTimer = nil;
        
        [self setName:@"gogoc"];
        [self setConfig:@"gogoc.conf"];
    }
    return self;
}

- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    
    return YES;
}

- (NSDictionary *)loadConfigFile:(NSString *)path {
    NSLog(@"Loading gogoc config file");
    
    NSDictionary *config = @{@"username": @"testuser",
                             @"password": @"testpass",
                             @"tunnel_id": @""};
    
    return config;
}

- (BOOL)startFrom:(NSString *)path withConfigFile:(NSString *)configPath
{
    // Is the task running?
    if (_task) {
//        [_task interrupt];
    } else {
        
        _statusNotificationCount = 0;
        _statusQueue = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", nil];
        [_postTimer invalidate];
        
        //_status = [[NSMutableString alloc] init];
        _task = [[NSTask alloc] init];
        [_task setLaunchPath:path];
        NSArray *args = @[@"start", configPath];
		[_task setArguments:args];
		
		// Create a new pipe
		_pipe = [[NSPipe alloc] init];
		[_task setStandardOutput:_pipe];
		[_task setStandardError:_pipe];
        
		NSFileHandle *fh = [_pipe fileHandleForReading];
		
		NSNotificationCenter *nc;
		nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver:self];
		
		[nc addObserver:self
			   selector:@selector(dataReady:)
				   name:NSFileHandleReadCompletionNotification
				 object:fh];
		
		[nc addObserver:self
			   selector:@selector(taskTerminated:)
				   name:NSTaskDidTerminateNotification
				 object:_task];
		
		[_task launch];
        
		[fh readInBackgroundAndNotify];
	}
    return TRUE;
}

- (void)stopFrom {
    // Is the task running?
    if (_task) {
        [_task interrupt];
    }
}

- (NSArray *)requestTunnelList
{
    NSLog(@"Request tunnel list");
    
    NSDictionary *tunnelInfo1 =  @{@"id": @"amsterdam.freenet6.net",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"heartbeat",
                                   @"popid": @"pop01"};
    NSDictionary *tunnelInfo2 =  @{@"id": @"anon-amsterdam.freenet6.net",
                                   @"ipv6": @"2a01::2",
                                   @"ipv4": @"ayiya",
                                   @"popid": @"pop02"};
    
    return @[tunnelInfo1, tunnelInfo2];
    //return [NSArray array];
	
}

- (NSArray *)requestServerList
{
    sint32_t argc = 3;
    char *argv[] = {"","-f","/usr/local/gogoc/bin/gogoc.conf"};
    tConf c;
    sint32_t log_display_ok = 0;        // Don't use 'Display()'.
    tBrokerList *broker_list = NULL;
    sint32_t trying_original_server = 0;
    sint32_t read_last_server = 0;
    char original_server[MAX_REDIRECT_ADDRESS_LENGTH];
    char last_server[MAX_REDIRECT_ADDRESS_LENGTH];
    tRedirectStatus last_server_status = TSP_REDIRECT_OK;
    gogoc_status status;
    sint32_t loop_delay;
    
    // Initialize status info.
    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDIDLE;
    gStatusInfo.nStatus = GOGOCM_UIS__NOERROR;
    
    // ------------------------------------------------------------------------
    // Zero-memory the configuration object, because tspInitialize requires
    // it initialized. Then call the tspInitialize function.
    // ------------------------------------------------------------------------
    memset( &c, 0, sizeof(c) );

    status = tspInitialize(argc, argv, &c);
    if( status_number(status) != SUCCESS )
    {
        gStatusInfo.nStatus = GOGOCM_UIS_ERRCFGDATA;
        goto endtspc;
    }
    
    // Initialize the logging system.
    if( InitLogSystem( &c ) != 0 )
    {
        // Failed to allocate memory for the log configuration, or an error
        // happened.
        status = make_status(CTX_CFGVALIDATION, ERR_FAIL_LOG_INIT);
        
        gStatusInfo.nStatus = GOGOCM_UIS_ERRCFGDATA;
        goto endtspc;
    }
    log_display_ok = 1;
    
    // Log the OS information through the log system.
    tspLogOSInfo();
    
    // Keep track of the broker list.
//    gszBrokerListFile = c.broker_list_file; // For BROKER_LIST gogocmessaging message.
    
    // Save the original server value.
    strcpy(original_server, c.server);
    
    
    // If always_use_same_server is enabled.
    if( (c.always_use_same_server == TRUE) && (pal_strlen(c.last_server_file) > 0) )
    {
        // Try to get the last server from the last_server file.
        last_server_status = tspReadLastServerFromFile(c.last_server_file, last_server);
        
        switch( last_server_status )
        {
            case TSP_REDIRECT_OK:
                // Replace the configuration file's server value with the last server.
                pal_free(c.server);
                c.server = pal_strdup(last_server);
                // We found the last server.
                read_last_server = 1;
                // We're not trying the original server.
                trying_original_server = 0;
                Display(LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_TRYING_LAST_SERVER, last_server);
                break;
                
            case TSP_REDIRECT_NO_LAST_SERVER:
                // Try the original server instead.
                trying_original_server = 1;
                Display(LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_NO_LAST_SERVER_FOUND, c.last_server_file, original_server);
                break;
                
            case TSP_REDIRECT_CANT_OPEN_FILE:
                // Try the original server instead.
                trying_original_server = 1;
                Display(LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_CANT_OPEN_LAST_SERVER, c.last_server_file, original_server);
                break;
                
            default:
                Display(LOG_LEVEL_1, ELError, "tspMain", GOGO_STR_RDR_ERROR_READING_LAST_SERVER, c.last_server_file);
                status = make_status(CTX_CFGVALIDATION, ERR_FAIL_LAST_SERVER);
                
                gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                goto endtspc;
        }
    }
    else
    {
        // If always_use_same_server is disabled, try the original server.
        trying_original_server = 1;
    }
    
    loop_delay = c.retry_delay;
    
    do {
        net_tools_t nt[NET_TOOLS_T_SIZE];
        sint32_t version_index = CLIENT_VERSION_INDEX_CURRENT;
        sint32_t connected = 1;             // try servers as long as connected is true */
        sint32_t cycle = 0;                 // reconnect and fallback cycle */
        sint32_t tsp_version_fallback = 0;  // true if the TSP protocol version needs to fall back for the next retry */
        sint32_t quick_cycle = 0;
        tBrokerList *current_broker_in_list = NULL;
        sint32_t trying_broker_list = 0;
        tRedirectStatus broker_list_status = TSP_REDIRECT_OK;
        uint16_t effective_retry_delay;
        uint8_t  consec_retry = 0;
        
        // Initialize the net tools array.
        memset( nt, 0, sizeof(nt) );
        InitNetToolsArray( nt );
        
        
        
        // ------------------------------------------------------------------------
        // Connection loop.
        //   Perform loop until we give up (i.e.: an error is indicated), or user
        //   requested a stop in the service (HUP signal or service stop).
        //
        while( connected )
        {
            if (tspCheckForStopOrWait(0) != 0)
                goto endtspc;
            
            // While we loop in this while(), keep everything updated on our status.
            //
            if( gStatusInfo.eStatus != GOGOC_CLISTAT__DISCONNECTEDIDLE &&
               gStatusInfo.nStatus != GOGOCM_UIS__NOERROR )
            {
                // Status has been changed.
                send_status_info();
            }
            
            // Choose the transport or cycle thru the list
            switch( c.tunnel_mode )
            {
                case V6UDPV4:
                    switch( cycle )
                {
                    default:
                        cycle = 0;  // Catch an overflow of the variable.
                        // *** FALLTHROUGH ***
                        
                    case 0:
                        if( tsp_version_fallback )
                        {
                            if( version_index < CLIENT_VERSION_INDEX_V6UDPV4_START &&
                               version_index < CLIENT_VERSION_INDEX_OLDEST )
                            {
                                version_index++;
                            }
                            else
                            {
                                connected = 0;
                                continue;
                            }
                            tsp_version_fallback = 0;
                        }
                        else
                        {
                            version_index = CLIENT_VERSION_INDEX_CURRENT;
                        }
                        c.transport = NET_TOOLS_T_RUDP;
                        break;
                }
                    break;
                    
                case V6ANYV4:
                case V6V4:
                    switch( cycle )
                {
                    default:
                        cycle = 0;  // Catch an overflow of the variable.
                        // *** FALLTHROUGH ***
                        
                    case 0:
                        if( tsp_version_fallback )
                        {
                            if( version_index < CLIENT_VERSION_INDEX_OLDEST )
                            {
                                version_index++;
                            }
                            else
                            {
                                connected = 0;
                                continue;
                            }
                            tsp_version_fallback = 0;
                        }
                        else
                        {
                            version_index = CLIENT_VERSION_INDEX_CURRENT;
                        }
                        c.transport = NET_TOOLS_T_RUDP;
                        break;
                        
                    case 1:
                        if( tsp_version_fallback )
                        {
                            if( version_index < CLIENT_VERSION_INDEX_OLDEST )
                            {
                                version_index++;
                            }
                            else
                            {
                                connected = 0;
                                continue;
                            }
                            tsp_version_fallback = 0;
                        }
                        else
                        {
                            version_index = CLIENT_VERSION_INDEX_CURRENT;
                        }
                        c.transport = NET_TOOLS_T_TCP;
                        break;
                }
                    break;
                    
                case V4V6:
#ifdef V4V6_SUPPORT
#ifdef DSLITE_SUPPORT
                case DSLITE:
#endif
                    switch( cycle )
                {
                    default:
                        cycle = 0;  // Catch an overflow of the variable.
                        // *** FALLTHROUGH ***
                        
                    case 0:
                        if( tsp_version_fallback )
                        {
                            if( version_index < CLIENT_VERSION_INDEX_V4V6_START &&
                               version_index < CLIENT_VERSION_INDEX_OLDEST )
                            {
                                version_index++;
                            }
                            else
                            {
                                connected = 0;
                                continue;
                            }
                            tsp_version_fallback = 0;
                        }
                        else
                        {
                            version_index = CLIENT_VERSION_INDEX_CURRENT;
                        }
                        c.transport = NET_TOOLS_T_RUDP6;
                        break;
                        
                    case 1:
                        if( tsp_version_fallback )
                        {
                            if( version_index < CLIENT_VERSION_INDEX_V4V6_START &&
                               version_index < CLIENT_VERSION_INDEX_OLDEST )
                            {
                                version_index++;
                            }
                            else
                            {
                                connected = 0;
                                continue;
                            }
                            tsp_version_fallback = 0;
                        }
                        else
                        {
                            version_index = CLIENT_VERSION_INDEX_CURRENT;
                        }
#ifdef DSLITE_SUPPORT
                        c.transport = c.tunnel_mode == DSLITE ? NET_TOOLS_T_RUDP6 : NET_TOOLS_T_TCP6;
#else
                        c.transport = NET_TOOLS_T_TCP6;
#endif
                        break;
                }
#endif
                    break;
            } // switch(c.tunnel_mode)
            
            
            // Determine if we need to sleep between connection attempts.
            quick_cycle = 0;
            if( ( (c.tunnel_mode == V6ANYV4) || (c.tunnel_mode == V6V4) ) && (c.transport == NET_TOOLS_T_RUDP) )
            {
                quick_cycle = 1;
            }
#ifdef V4V6_SUPPORT
            if( (c.tunnel_mode == V4V6) && (c.transport == NET_TOOLS_T_RUDP6) )
            {
                quick_cycle = 1;
            }
#endif
#ifdef DSLITE_SUPPORT
            if( (c.tunnel_mode == DSLITE) && (c.transport == NET_TOOLS_T_RUDP6) )
            {
                quick_cycle = 1;
            }
#endif
            
            
            // -----------------------------------------------
            // *** Attempt to negotiate tunnel with broker ***
            // -----------------------------------------------
            status = tspSetupTunnel(&c, &nt[c.transport], version_index, &broker_list);
            
            switch( status_number(status) )
            {
                case SUCCESS:
                    // If we are here with no error, we can assume we are finished.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDIDLE;
                    gStatusInfo.nStatus = GOGOCM_UIS__NOERROR;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_KEEPALIVE_TIMEOUT:
                    // A keepalive timeout has occurred.
                {
                    Display(LOG_LEVEL_1, ELError, "tspMain", STR_KA_GENERAL_TIMEOUT);
                    
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRKEEPALIVETIMEOUT;
                    
                    consec_retry = 0;
                    if( c.auto_retry_connect == FALSE )
                    {
                        gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDNORETRY;
                        connected = 0;
                        continue;
                    }
                }
                    break;
                    
                case ERR_AUTHENTICATION_FAILURE:
                    // There's nothing more to do if the authentication has failed.
                    // The user needs to change its username/password. Abort.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRAUTHENTICATIONFAILURE;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_NO_COMMON_AUTHENTICATION:
                    // Configured authentication method is not supported by server.
                    // User needs to change configuration. Abort.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRNOCOMMONAUTHENTICATION;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_INTERFACE_SETUP_FAILED:
                    // The tunnel interface configuration script failed. Abort.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRINTERFACESETUPFAILED;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_TUN_LEASE_EXPIRED:
                    // The tunnel lease has expired. Reconnect.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDIDLE;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRTUNLEASEEXPIRED;
                    
                    Display(LOG_LEVEL_1, ELWarning, "tspMain", STR_TSP_TUNNEL_LEASE_EXPIRED);
                    continue;
                }
                    
                case ERR_INVAL_TSP_VERSION:
                    // Invalid TSP version used.  Will change version on next connect.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRTSPVERSIONERROR;
                    
                    tsp_version_fallback = 1;
                    if( version_index == CLIENT_VERSION_INDEX_2_0_0 )
                    {
                        cycle = 1;
                    }
                    
                    // Wait a little to prevent the TSP version fallback problem with UDP
                    // connections that have the same source port. See Bugzilla bug #3539
                    if ((version_index != CLIENT_VERSION_INDEX_2_0_0) && (c.transport == NET_TOOLS_T_RUDP
#ifdef V4V6_SUPPORT
                                                                          || c.transport == NET_TOOLS_T_RUDP6
#endif
                                                                          ))
                    {
                        pal_sleep(TSP_VERSION_FALLBACK_DELAY);
                    }
                    Display (LOG_LEVEL_1, ELInfo, "tspMain", STR_GEN_DISCONNECTED_RETRY_NOW);
                    continue;
                }
                    break;
                    
                case ERR_SOCKET_IO:
                    // Socket error. Reconnect, don't change transport.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRSOCKETIO;
                    
                    consec_retry = 0;
                    if( quick_cycle != 0 )
                    {
                        Display(LOG_LEVEL_1, ELInfo, "tspMain", STR_GEN_DISCONNECTED_RETRY_NOW);
                        continue;
                    }
                }
                    break;
                    
                case ERR_TSP_SERVER_TOO_BUSY:
                    // The server is currently too busy to process the TSP request.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRTSPSERVERTOOBUSY;
                    
                    // Force a wait.
                    effective_retry_delay = c.retry_delay;
                    consec_retry = 1;
                }
                    break;
                    
                case ERR_TSP_GENERIC_ERROR:
                    // Unexpected TSP status in TSP session. Abort.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRTSPGENERICERROR;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_FAIL_SOCKET_CONNECT:
                    // This means we could not connect to a server.
                    // We'll try a different transport to the same server.
                    // If that fails too, we'll go through the broker list (if any).
                {
                    // Don't retry to avoid blocking the boot
                    if (c.boot_mode)
                    {
                        connected = 0;
                        continue;
                    }
                    
                    if( quick_cycle == 1 )
                    {
                        // We haven't tried all transports for this broker, there are more to try.
                        cycle++;
                        Display(LOG_LEVEL_1, ELInfo, "tspMain", STR_GEN_DISCONNECTED_RETRY_NOW);
                        continue;
                    }
                    
                    // If we have the last server, we always need to connect to this one.
                    if( read_last_server == 1 )
                    {
                        // Just cycle transports, try again with the last server.
                        cycle++;
                        break;
                    }
                    
                    // Do the following only if we have tried all transports(and failed to connect)
                    effective_retry_delay = c.retry_delay;
                    consec_retry = 1;
                    // Status update.
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRFAILSOCKETCONNECT;
                    
                    // If we're trying to connect to the original server.
                    if( trying_original_server == 1 )
                    {
                        // Clear the broker list.
                        tspFreeBrokerList(broker_list);
                        broker_list = NULL;
                        
                        // If a broker_list file is specified, try to create the list
                        if( pal_strlen(c.broker_list_file) > 0 )
                        {
                            Display (LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_READING_BROKER_LIST, c.broker_list_file);
                            
                            broker_list_status = tspReadBrokerListFromFile(c.broker_list_file, &broker_list);
                            switch( broker_list_status )
                            {
                                case TSP_REDIRECT_OK:
                                    // If the broker list is empty.
                                    if( broker_list == NULL )
                                    {
                                        Display (LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_READ_BROKER_LIST_EMPTY);
                                        // Just cycle transports, we'll try the original server again.
                                        cycle++;
                                    }
                                    // If the broker list is not empty.
                                    else
                                    {
                                        Display (LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_READ_BROKER_LIST_CREATED);
                                        
                                        tspLogRedirectionList(broker_list, 0);
                                        
                                        // We're going through a broker list.
                                        trying_broker_list = 1;
                                        // We're not trying the original server anymore.
                                        trying_original_server = 0;
                                        // Start with the first broker in the list.
                                        current_broker_in_list = broker_list;
                                        // Copy the brokerList address to configuration server.
                                        if( FormatBrokerListAddr( current_broker_in_list, &(c.server) ) != 0 )
                                        {
                                            tspFreeBrokerList(broker_list);
                                            broker_list = NULL;
                                            status = make_status( status_context(status), ERR_BROKER_REDIRECTION );
                                            gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                                            connected = 0;
                                            goto endtspc;
                                        }
                                        // Adjust the transport cycle to start from the first one.
                                        cycle = 0;
                                        // Try the first broker in the list right now.
                                        continue;
                                    }
                                    break;
                                    
                                case TSP_REDIRECT_CANT_OPEN_FILE:
                                    // If we can't open the file, maybe it's just not there.
                                    // This is normal if it hasn't been created.
                                    Display (LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_CANT_OPEN_BROKER_LIST, c.broker_list_file);
                                    cycle++;
                                    tspFreeBrokerList(broker_list);
                                    broker_list = NULL;
                                    break;
                                    
                                case TSP_REDIRECT_TOO_MANY_BROKERS:
                                    // If there were more brokers in the list than the allowed limit.
                                    Display (LOG_LEVEL_1, ELError, "tspMain", GOGO_STR_RDR_TOO_MANY_BROKERS, MAX_REDIRECT_BROKERS_IN_LIST);
                                    cycle++;
                                    tspFreeBrokerList(broker_list);
                                    broker_list = NULL;
                                    break;
                                    
                                default:
                                    // There was a problem creating the list from the broker_list file
                                    Display (LOG_LEVEL_1, ELError, "tspMain", GOGO_STR_RDR_ERROR_READING_BROKER_LIST, c.broker_list_file);
                                    cycle++;
                                    tspFreeBrokerList(broker_list);
                                    broker_list = NULL;
                                    break;
                            }
                        }
                        else
                        {
                            // Nothing specified in broker_list. Cycle transports, but
                            // try same server again.
                            cycle++;
                        }
                    }
                    // If we're not trying to connect to the original server.
                    // and we're going through a broker list.
                    else if( trying_broker_list == 1 )
                    {
                        // If the pointers aren't safe.
                        if( (broker_list == NULL) || (current_broker_in_list == NULL) )
                        {
                            Display(LOG_LEVEL_1, ELError, "tspMain", GOGO_STR_RDR_BROKER_LIST_INTERNAL_ERROR, current_broker_in_list->address);
                            gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                            status = make_status( status_context(status), ERR_BROKER_REDIRECTION );
                            
                            tspFreeBrokerList(broker_list);
                            broker_list = NULL;
                            connected = 0;
                            continue;
                        }
                        
                        // If this is the last broker in the list.
                        if( current_broker_in_list->next == NULL )
                        {
                            Display (LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_BROKER_LIST_END);
                            
                            // Prepare to retry the original server after the retry delay.
                            pal_free(c.server);
                            c.server = pal_strdup(original_server);
                            cycle = 0;
                            trying_original_server = 1;
                            break;
                        }
                        
                        // Prepare to try the next broker in the list.
                        current_broker_in_list = current_broker_in_list->next;
                        
                        // Copy the brokerList address to configuration server.
                        if( FormatBrokerListAddr( current_broker_in_list, &(c.server) ) != 0 )
                        {
                            tspFreeBrokerList(broker_list);
                            broker_list = NULL;
                            status = make_status( status_context(status), ERR_BROKER_REDIRECTION );
                            gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                            connected = 0;
                            goto endtspc;
                        }
                        
                        Display(LOG_LEVEL_2, ELInfo, "tspMain", GOGO_STR_RDR_NEXT_IN_BROKER_LIST, current_broker_in_list->address);
                        
                        // Try the next broker now, don't wait for the retry delay.
                        cycle = 0;
                        continue;
                    }
                }
                    break;
                    
                case EVNT_BROKER_REDIRECTION:
                    // This means we got a broker redirection message. The handling
                    // function that sent us this signal has created the broker list.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDIDLE;
                    gStatusInfo.nStatus = GOGOCM_UIS_EVNTBROKERREDIRECTION;
                    
                    // Check that the broker list has been created.
                    if( broker_list != NULL )
                    {
                        // We're going through a broker list.
                        trying_broker_list = 1;
                        // We're not trying to connect to the original server.
                        trying_original_server = 0;
                        // Prepare to try the first broker in the list.
                        current_broker_in_list = broker_list;
                        // Try the first broker in the list without waiting for the retry delay.
                        cycle = 0;
                        // Copy the brokerList address to configuration server.
                        if( FormatBrokerListAddr( current_broker_in_list, &(c.server) ) != 0 )
                        {
                            // Error: Failed to format the address. Abort.
                            gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                            gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                            status = make_status(status_context(status), ERR_BROKER_REDIRECTION);
                            connected = 0;
                        }
                    }
                    else
                    {
                        // Error: Empty or invalid broker list. Abort.
                        gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                        status = make_status(status_context(status), ERR_BROKER_REDIRECTION);
                        connected = 0;
                    }
                    continue;
                }
                    break;
                    
                case ERR_BROKER_REDIRECTION:
                    // This means we got a broker redirection message, but there were
                    // errors in handling it.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRBROKERREDIRECTION;
                    Display(LOG_LEVEL_1, ELError, "tspMain", GOGO_STR_RDR_ERROR_PROCESSING_REDIRECTION, c.server);
                    
                    tspFreeBrokerList(broker_list);
                    broker_list = NULL;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_MEMORY_STARVATION:
                    // This is a fatal error.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRMEMORYSTARVATION;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_TUNMODE_NOT_AVAILABLE:
                    // Configured tunnel mode is not available on the server.
                    // User needs to change configuration. Abort.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRTUNMODENOTAVAILABLE;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_TUNNEL_IO:
                    // Occurs if there is a problem during the tunneling with a TUN interface.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRTUNNELIO;
                    
                    consec_retry = 0;
                }
                    break;
                    
                case ERR_KEEPALIVE_ERROR:
                    // A keepalive error occured. Probably a network error.
                    // Since the keepalive error occurs after the TSP session, it is safe
                    //   to assume that we can reconnect and try again.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRKEEPALIVEERROR;
                    
                    consec_retry = 0;
                }
                    break;
                    
                case ERR_BAD_TUNNEL_PARAM:
                    // The tunnel information that the server provided was bad.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRBADTUNNELPARAM;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
#ifdef HACCESS
                case ERR_HACCESS_SETUP:
                {
                    Display(LOG_LEVEL_1, ELError, "tspMain", HACCESS_LOG_PREFIX_ERROR GOGO_STR_HACCESS_ERR_FAILED_TO_SETUP_HACCESS_FEATURES);
                    
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDHACCESSSETUPERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRHACCESSSETUP;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_HACCESS_EXPOSE_DEVICES:
                    // Home access error: Failed to make the devices available. Abort.
                {
                    Display(LOG_LEVEL_1, ELError, "tspMain", HACCESS_LOG_PREFIX_ERROR GOGO_STR_HACCESS_ERR_FAILED_TO_EXPOSE_DEVICES);
                    
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDHACCESSEXPOSEDEVICESERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRHACCESSEXPOSEDEVICES;
                    
                    connected = 0;
                    continue;
                }
                    break;
#endif
                    
                case ERR_INVAL_GOGOC_ADDRESS:
                case ERR_FAIL_RESOLV_ADDR:
                    // Failed to parse server Address or resolve it.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRINVALSERVERADDR;
                    
                    connected = 0;
                    continue;
                }
                    break;
                    
                case ERR_INVAL_CFG_FILE:
                case ERR_INVAL_CLIENT_ADDR:
                default:
                    // Any other error, quit immediatly.
                {
                    gStatusInfo.eStatus = GOGOC_CLISTAT__DISCONNECTEDERROR;
                    gStatusInfo.nStatus = GOGOCM_UIS_ERRUNKNOWN;
                    
                    connected = 0;
                    continue;
                }
                    break;
            } // status switch
            
            
            // Send status info about the current connection failure.
            //
            send_status_info();
            
            // Do not wait if it is the first reconnection attempt.
            // The delay to wait SHALL be doubled at every 3 consecutive failed
            //   connection attempts. It MUST NOT exceed configured retry_delay_max.
            //
            if( consec_retry > 0 )
            {
                sint32_t sleepTime = c.retry_delay;
                if( consec_retry % CONSEC_RETRY_TO_DOUBLE_WAIT == 0 )
                {
                    // Double the effective wait time.
                    effective_retry_delay *= 2;
                    if( effective_retry_delay > c.retry_delay_max )
                        effective_retry_delay = c.retry_delay_max;
                }
                consec_retry++;
                sleepTime = effective_retry_delay;
                
                // Log connection failure & sleep before retrying.
                Display( LOG_LEVEL_1, ELInfo, "tspMain", STR_GEN_DISCONNECTED_RETRY_SEC, effective_retry_delay );
                
                // Check for stop at each second.
                while( sleepTime-- > 0  &&  tspCheckForStopOrWait(1000) == 0 );
            }
            else
            {
                consec_retry++;
                effective_retry_delay = c.retry_delay;
                
                // Log connection failure. Reconnect now.
                Display( LOG_LEVEL_1, ELInfo, "tspMain", STR_GEN_DISCONNECTED_RETRY_NOW );
            }
            
        }  // Profanely big connection while()
        
        {
            uint32_t sleepTime = loop_delay;
            while( sleepTime-- > 0  &&  tspCheckForStopOrWait(1000) == 0 );
        }
        loop_delay *= 2;
        if (loop_delay > c.retry_delay_max) loop_delay = c.retry_delay_max;
        
    } while (!c.boot_mode);
    
endtspc:
    // Send final status to GUI.
    send_status_info();
    
    // Free the broker list.
    tspFreeBrokerList(broker_list);
    
    // Display the last status context, if the status number is not SUCCESS.
    if( status_number(status) != SUCCESS )
    {
        if( log_display_ok == 0 )
            DirectErrorMessage(STR_GEN_LAST_STATUS_CONTEXT, GOGOCStatusContext[status_context(status)]);
        else
            Display(LOG_LEVEL_1, ELWarning, "tspMain", STR_GEN_LAST_STATUS_CONTEXT, GOGOCStatusContext[status_context(status)]);
    }
    
    // Log end of program.
    if( log_display_ok == 0 )
        DirectErrorMessage(STR_GEN_FINISHED);
    else
        Display(LOG_LEVEL_1, ELInfo, "tspMain", STR_GEN_FINISHED);
    
    // Close the log system
    LogClose();
    
    
//    return( status_number(status) );

    return @[@"server 1", @"server 2"];
}
@end

//
//  darwin_route.c
//  maiccu
//
//  Created by German Skalauhov on 23.02.14.
//

#include <net/if_types.h>
#include <net/route.h>
#include <sys/sysctl.h>
#include <netdb.h>
#include <stdlib.h>
#include <spawn.h>
#include "platform.h"
#include "gogoc_status.h"       // Error codes

#include "tsp_setup.h"
#include "tsp_client.h"

#include "config.h"       // tConf
#include "xml_tun.h"      // tTunnel
#include "log.h"          // Display()
#include "hex_strings.h"  // Strings for Display()
#include "lib.h"          // IsAll, IPv4Addr, IPv6Addr, IPAddrAny, Numeric.

// gogoCLIENT Messaging Subsystem.
#include <gogocmessaging/gogoc_c_wrapper.h>

#define TSP_OPERATION_CREATETUNNEL    "TSP_TUNNEL_CREATION"
#define TSP_OPERATION_TEARDOWNTUNNEL  "TSP_TUNNEL_TEARDOWN"


/*  Should be defined in platform.h  */
#ifndef SCRIPT_TMP_FILE
#error "SCRIPT_TMP_FILE is not defined in platform.h"
#endif

// original source code functions routepr, get_rtaddrs, np_rtentry see at
// http://www.opensource.apple.com/source/network_cmds/network_cmds-433/netstat.tproj/route.c
//

/* alignment constraint for routing socket */
#define ROUNDUP(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(uint32_t) - 1))) : sizeof(uint32_t))

static char *np_rtentry __P((struct rt_msghdr2 *));

/*
 * Print routing tables.
 */
char*
routepr(void)
{
	size_t needed;
	int mib[6];
	char *buf, *next, *lim;
	struct rt_msghdr2 *rtm;
    char *gate = NULL;
    
	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = PF_INET6;
	mib[4] = NET_RT_FLAGS;
	mib[5] = RTF_GATEWAY;
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0) {
        return NULL;
	}
    
	if ( (buf = malloc(needed)) ) {
        if (sysctl(mib, 6, buf, &needed, NULL, 0) >= 0) {
            lim  = buf + needed;
            for (next = buf; next < lim; next += rtm->rtm_msglen) {
                rtm = (struct rt_msghdr2 *)next;
                if ( (gate = np_rtentry(rtm)) ) {
                    break;
                }
            }
        }
        free(buf);
	}
    return gate;
}

static void
get_rtaddrs(int addrs, struct sockaddr *sa, struct sockaddr **rti_info)
{
    int i;
    
    for (i = 0; i < RTAX_MAX; i++) {
        if (addrs & (1 << i)) {
            rti_info[i] = sa;
            sa = (struct sockaddr *)(ROUNDUP(sa->sa_len) + (char *)sa);
		} else {
            rti_info[i] = NULL;
        }
    }
}


static char*
np_rtentry(struct rt_msghdr2 *rtm)
{
	struct sockaddr *sa = (struct sockaddr *)(rtm + 1);
	struct sockaddr *rti_info[RTAX_MAX];
	struct sockaddr_in6 *addr, *mask;
    struct sockaddr *gate;
    
	if ((rtm->rtm_flags & RTF_WASCLONED) ) return NULL;
    
	get_rtaddrs(rtm->rtm_addrs, sa, rti_info);
    
    if (rti_info[RTAX_DST]->sa_family != AF_INET6) return NULL;
    
    addr = (struct sockaddr_in6*)rti_info[RTAX_DST];
    mask = (struct sockaddr_in6*)rti_info[RTAX_NETMASK];
    gate = (struct sockaddr*)rti_info[RTAX_GATEWAY];
    
    if (mask && mask->sin6_len == 0 && IN6_IS_ADDR_UNSPECIFIED(&addr->sin6_addr)) {
        static char line[MAXHOSTNAMELEN];
        int flag = NI_WITHSCOPEID | NI_NUMERICHOST;
        
        getnameinfo(gate, gate->sa_len,
                    line, sizeof(line), NULL, 0, flag);
        return line;
    }
    else
        return NULL;
}

/* Execute cmd and send output to log subsystem */
sint32_t execCmd( const char *cmd[] )
{
    char buf[1024];
    FILE* f_log;
    sint32_t retVal;
    int in[2];
    pid_t pid;
    posix_spawn_file_actions_t action;
    int status;
    
    int i=0;
    while (cmd[i] != NULL)
    {
        Display( LOG_LEVEL_MAX, ELInfo, "execScript", "%s", cmd[i] );
//        printf("%s ",cmd[i]);
        i++;
    }
//    puts("\n");
    
    if ( (retVal = pipe(in)) ) {
        Display( LOG_LEVEL_1, ELError, "execScript", "Failed to open pipe for command: %s. %s (%d).", cmd[0], strerror(errno), errno);
    }
    else
    {
        if ( (retVal=posix_spawn_file_actions_init(&action)) )
        {
            Display( LOG_LEVEL_1, ELError, "execScript", "Failed to init file actions for command: %s. %s (%d).", cmd[0], strerror(retVal), retVal);
            close(in[1]);
        }
        else
        {
            posix_spawn_file_actions_adddup2(&action, in[1], 1);
            posix_spawn_file_actions_adddup2(&action, in[1], 2);
            posix_spawn_file_actions_addclose(&action, in[0]);
            
            retVal = posix_spawnp(&pid, cmd[0], &action, NULL, (char*const*)cmd, NULL);
            close(in[1]);
            
            if (retVal) {
                Display( LOG_LEVEL_1, ELError, "execScript", "Failed to spawn for command: %s.", cmd[0]);
            }
            else
            {
                waitpid(pid, &status, 0);
                if (!WIFEXITED(status)) {
                    Display( LOG_LEVEL_1, ELError, "execScript", "Failed to waitpid for command: %s. status 0x%08X %s (%d).", cmd[0], status, strerror(errno), errno);
                }
                
                if ( (f_log = fdopen(in[0], "r")) )
                {
                    while( !feof( f_log ) )
                    {
                        if( fgets( buf, sizeof(buf), f_log ) != NULL )
                        {
                            Display( LOG_LEVEL_MAX, ELInfo, "execScript", "%s", buf );
                        }
                    }
                    fclose(f_log);
                }
                else
                {
                    Display( LOG_LEVEL_1, ELError, "execScript", "Failed to fdopen for command: %s. %s (%d)", cmd[0], strerror(errno), errno);
                }
            }
            posix_spawn_file_actions_destroy(&action);
        }
        close(in[0]);
    }
    
    return retVal;
}

#define sh(...) {const char *arg[] = {__VA_ARGS__,NULL} ; execCmd(arg);}
static const char route[] = "/sbin/route";
static const char ifconfig[] = "/sbin/ifconfig";

sint32_t execScript( const char * cmd)
{
    char *TSP_TUNNEL_INTERFACE = getenv("TSP_TUNNEL_INTERFACE");
    char *TSP_CLIENT_ADDRESS_IPV6 = getenv("TSP_CLIENT_ADDRESS_IPV6");
    char *TSP_ORIGINAL_GATEWAY = getenv("TSP_ORIGINAL_GATEWAY");
    
    if (!strcmp(getenv("TSP_OPERATION"),"TSP_TUNNEL_TEARDOWN"))
    {
        if ( TSP_ORIGINAL_GATEWAY ) {
            sh(route,"change","-inet6","default",TSP_ORIGINAL_GATEWAY);
            sh(route,"add","-inet6","default",TSP_ORIGINAL_GATEWAY);
        }
        else {
            sh(route,"delete","-inet6","default");
        }
        //sh(route,"delete","-inet6",TSP_CLIENT_ADDRESS_IPV6);
        sh(ifconfig,TSP_TUNNEL_INTERFACE,"deletetunnel");
    }
    else if(!strcmp(getenv("TSP_HOST_TYPE"),"host"))
    {
        char *TSP_CLIENT_ADDRESS_IPV4 = getenv("TSP_CLIENT_ADDRESS_IPV4");
        char *TSP_SERVER_ADDRESS_IPV4 = getenv("TSP_SERVER_ADDRESS_IPV4");
        char *TSP_SERVER_ADDRESS_IPV6 = getenv("TSP_SERVER_ADDRESS_IPV6");
        char *TSP_TUNNEL_PREFIXLEN = getenv("TSP_TUNNEL_PREFIXLEN");
        
        sh(ifconfig,TSP_TUNNEL_INTERFACE,"deletetunnel");
        sh(ifconfig,TSP_TUNNEL_INTERFACE,"tunnel",TSP_CLIENT_ADDRESS_IPV4,TSP_SERVER_ADDRESS_IPV4);
        sh(ifconfig,TSP_TUNNEL_INTERFACE,"inet6",TSP_CLIENT_ADDRESS_IPV6,TSP_SERVER_ADDRESS_IPV6,"prefixlen",TSP_TUNNEL_PREFIXLEN,"alias");
        
        sh(ifconfig,TSP_TUNNEL_INTERFACE,"mtu","1280");
        
        if ( TSP_ORIGINAL_GATEWAY ) {
            Display( LOG_LEVEL_MAX, ELInfo, "execScript", "Change current default gateway %s", TSP_ORIGINAL_GATEWAY );
            sh(route,"change","-inet6","default",TSP_SERVER_ADDRESS_IPV6);
        }
        else {
            sh(route,"add","-inet6","default",TSP_SERVER_ADDRESS_IPV6);
        }
    }
    return 0;
}

/*
 -----------------------------------------------------------------------------
 $Id: tsp_setup.c,v 1.2 2010/03/07 20:14:32 carl Exp $
 -----------------------------------------------------------------------------
 Copyright (c) 2001-2007 gogo6 Inc. All rights reserved.
 
 For license information refer to CLIENT-LICENSE.TXT
 -----------------------------------------------------------------------------
 */

// --------------------------------------------------------------------------
// This function validates the information found in the tunnel information
// structure.
// Returns number of errors found. 0 is successful validation.
//
sint32_t validate_tunnel_info( const tTunnel* pTunnelInfo )
{
    sint32_t err_num = 0;
    
    
    if( !IsAll(IPv4Addr, pTunnelInfo->client_address_ipv4) )
    {
        Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_CLIENT_IPV4_RECVD);
        err_num++;
    }
    
    if( !IsAll(IPv6Addr, pTunnelInfo->client_address_ipv6) )
    {
        Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_CLIENT_IPV6_RECVD);
        err_num++;
    }
    
    if( pTunnelInfo->client_dns_server_address_ipv6 != NULL )
    {
        if( !IsAll(IPv6Addr, pTunnelInfo->client_dns_server_address_ipv6) )
        {
            Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_CLIENT_DNS_IPV6_RECVD);
            err_num++;
        }
    }
    
    if( !IsAll(IPv4Addr, pTunnelInfo->server_address_ipv4) )
    {
        Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_SERVER_IPV4_RECVD);
        err_num++;
    }
    
    if( !IsAll(IPv6Addr, pTunnelInfo->server_address_ipv6) )
    {
        Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_SERVER_IPV6_RECVD);
        err_num++;
    }
    
    // If prefix information is found, validate it.
    if( pTunnelInfo->prefix != NULL )
    {
        if( !IsAll(IPAddrAny, pTunnelInfo->prefix) )
        {
            Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_SERVER_PREFIX_RECVD);
            err_num++;
        }
        
        if( !IsAll(Numeric, pTunnelInfo->prefix_length) )
        {
            Display(LOG_LEVEL_1, ELError, "validate_tunnel_info", GOGO_STR_BAD_PREFIX_LEN_RECVD);
            err_num++;
        }
    }
    
    return err_num;
}


// --------------------------------------------------------------------------

void set_tsp_env_variables( const tConf* pConfig, const tTunnel* pTunnelInfo )
{
    char buffer[8];
    
    // Specify log verbosity (MAXIMAL).
    pal_snprintf( buffer, sizeof buffer, "%d", LOG_LEVEL_MAX );
    tspSetEnv("TSP_VERBOSE", buffer, 1);
    
    // Specify gogoCLIENT installation directory.
    tspSetEnv("TSP_HOME_DIR", TspHomeDir, 1);
    
    // Specify the tunnel mode.
    tspSetEnv("TSP_TUNNEL_MODE", pTunnelInfo->type, 1);
    
    // Specify host type {router, host}
    tspSetEnv("TSP_HOST_TYPE", pConfig->host_type, 1);
    
    // Specify tunnel interface, for setup.
    if (pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V6V4) == 0 )
    {
        tspSetEnv("TSP_TUNNEL_INTERFACE", pConfig->if_tunnel_v6v4, 1);
        gTunnelInfo.eTunnelType = TUNTYPE_V6V4;
    }
    else if (pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V6UDPV4) == 0 )
    {
        tspSetEnv("TSP_TUNNEL_INTERFACE", pConfig->if_tunnel_v6udpv4, 1);
        gTunnelInfo.eTunnelType = TUNTYPE_V6UDPV4;
    }
#ifdef V4V6_SUPPORT
    else if (pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V4V6) == 0 )
    {
        tspSetEnv("TSP_TUNNEL_INTERFACE", pConfig->if_tunnel_v4v6, 1);
        gTunnelInfo.eTunnelType = TUNTYPE_V4V6;
    }
#endif /* V4V6_SUPPORT */
    
    // Specify what interface will be used for routing advertizement,
    // if enabled.
    tspSetEnv("TSP_HOME_INTERFACE", pConfig->if_prefix, 1);
    
    // Specify local endpoint IPv4 address
    tspSetEnv("TSP_CLIENT_ADDRESS_IPV4", pTunnelInfo->client_address_ipv4, 1);
    gTunnelInfo.szIPV4AddrLocalEndpoint = pTunnelInfo->client_address_ipv4;
    
    // Specify local endpoint IPv6 address
    tspSetEnv("TSP_CLIENT_ADDRESS_IPV6", pTunnelInfo->client_address_ipv6, 1);
    gTunnelInfo.szIPV6AddrLocalEndpoint = pTunnelInfo->client_address_ipv6;
    
    // Specify client dns IPv6 address
    tspSetEnv("TSP_CLIENT_DNS_ADDRESS_IPV6", pTunnelInfo->client_dns_server_address_ipv6, 1);
    gTunnelInfo.szIPV6AddrDns = pTunnelInfo->client_dns_server_address_ipv6;
    
    // Specify local endpoint domain name
    if( pTunnelInfo->client_dns_name != NULL)
    {
        tspSetEnv("TSP_CLIENT_DNS_NAME", pTunnelInfo->client_dns_name, 1);
        gTunnelInfo.szUserDomain = pTunnelInfo->client_dns_name;
    }
    
    // Specify remote endpoint IPv4 address.
    tspSetEnv("TSP_SERVER_ADDRESS_IPV4", pTunnelInfo->server_address_ipv4, 1);
    gTunnelInfo.szIPV4AddrRemoteEndpoint = pTunnelInfo->server_address_ipv4;
    
    // Specify remote endpoint IPv6 address.
    tspSetEnv("TSP_SERVER_ADDRESS_IPV6", pTunnelInfo->server_address_ipv6, 1);
    gTunnelInfo.szIPV6AddrRemoteEndpoint = pTunnelInfo->server_address_ipv6;
    
    // Specify prefix for tunnel endpoint.
    if ((pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V6V4) == 0) ||
        (pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V6UDPV4) == 0))
        tspSetEnv("TSP_TUNNEL_PREFIXLEN", "128", 1);
#ifdef V4V6_SUPPORT
    else
        tspSetEnv("TSP_TUNNEL_PREFIXLEN", "32", 1);
#endif /* V4V6_SUPPORT */
    
    
    // Free and clear delegated prefix from tunnel info.
    if( gTunnelInfo.szDelegatedPrefix != NULL )
    {
        pal_free( gTunnelInfo.szDelegatedPrefix );
        gTunnelInfo.szDelegatedPrefix = NULL;
    }
    
    // Have we been allocated a prefix for routing advertizement..?
    if( pTunnelInfo->prefix != NULL )
    {
        char chPrefix[128];
        size_t len, sep;
        
        /* Compute the number of characters that are significant out of the prefix. */
        /* This is meaningful only for IPv6 prefixes; no contraction is possible for IPv4. */
        if ((pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V6V4) == 0) ||
            (pal_strcasecmp(pTunnelInfo->type, STR_XML_TUNNELMODE_V6UDPV4) == 0))
        {
            len = (atoi(pTunnelInfo->prefix_length) % 16) ? (atoi(pTunnelInfo->prefix_length) / 16 + 1) * 4 : atoi(pTunnelInfo->prefix_length) / 16 * 4;
            sep = (atoi(pTunnelInfo->prefix_length) % 16) ? (atoi(pTunnelInfo->prefix_length) / 16) : (atoi(pTunnelInfo->prefix_length) / 16) -1;
        }
        else
        {
            len = pal_strlen( pTunnelInfo->prefix );
            sep = 0;
        }
        
        memset(chPrefix, 0, 128);
        memcpy(chPrefix, pTunnelInfo->prefix, len+sep);
        
        // Specify delegated prefix for routing advertizement, if enabled.
        tspSetEnv("TSP_PREFIX", chPrefix, 1);
        gTunnelInfo.szDelegatedPrefix = (char*) pal_malloc( pal_strlen(chPrefix) + 10/*To append prefix_length*/ );
        strcpy( gTunnelInfo.szDelegatedPrefix, chPrefix );
        
        // Specify prefix length for routing advertizement, if enabled.
        tspSetEnv("TSP_PREFIXLEN", pTunnelInfo->prefix_length, 1);
        strcat( gTunnelInfo.szDelegatedPrefix, "/" );
        strcat( gTunnelInfo.szDelegatedPrefix, pTunnelInfo->prefix_length );
    }
    
    if(pTunnelInfo->originalgateway) {
        tspSetEnv("TSP_ORIGINAL_GATEWAY", pTunnelInfo->originalgateway, 1);
    }
}


// --------------------------------------------------------------------------
// This function will set the required environment variables that will later
// be used when invoking the template script to actually create the tunnel.
//
gogoc_status tspSetupInterface(tConf *c, tTunnel *t)
{
    gogoc_status status = STATUS_SUCCESS_INIT;
    char* template_script = c->template;
    
    
    // Perform validation on tunnel information provided by server.
    if( validate_tunnel_info(t) != 0 )
    {
        // Errors occured during verification of tunnel parameters.
        Display( LOG_LEVEL_1, ELError, "tspSetupInterface", STR_TSP_ERRS_TUN_PARAM_FROM_SERVER );
        return make_status(CTX_TUNINTERFACESETUP, ERR_BAD_TUNNEL_PARAM);
    }
    
    
    // Specify TSP Operation: Tunnel Creation.
    tspSetEnv("TSP_OPERATION", TSP_OPERATION_CREATETUNNEL, 1 );
    
    // Set environment variable for script execution.
    set_tsp_env_variables( c, t );
    
    
    // Do some platform-specific stuff before tunnel setup script is launched.
    // The "tspSetupInterfaceLocal" is defined in tsp_local.c in every platform.
    if( tspSetupInterfaceLocal( c, t ) != 0 )
    {
        // Errors occured during setup of interface.
        return make_status(CTX_TUNINTERFACESETUP, ERR_INTERFACE_SETUP_FAILED);
    }
    
    
    // ---------------------------------------------------------------
    // Run the interface configuration script to bring the tunnel up.
    // ---------------------------------------------------------------
    Display( LOG_LEVEL_2, ELInfo, "tspSetupInterface", STR_GEN_EXEC_CFG_SCRIPT, template_script );
    if( execScript( template_script ) != 0 )
    {
        // Error executing script.
        Display(LOG_LEVEL_1, ELError, "tspSetupInterface", STR_GEN_SCRIPT_EXEC_FAILED);
        return make_status(CTX_TUNINTERFACESETUP, ERR_INTERFACE_SETUP_FAILED);
    }
    Display(LOG_LEVEL_2, ELInfo, "tspSetupInterface", STR_GEN_SCRIPT_EXEC_SUCCESS);
    
    
    // Display a resume of the configured settings.
    Display(LOG_LEVEL_2, ELInfo, "tspSetupInterface", GOGO_STR_SETUP_HOST_TYPE, c->host_type);
    Display(LOG_LEVEL_2, ELInfo, "tspSetupInterface", GOGO_STR_SETUP_TUNNEL_TYPE, t->type);
    Display(LOG_LEVEL_3, ELInfo, "tspSetupInterface", GOGO_STR_SETUP_PROXY, c->proxy_client == TRUE ? STR_LIT_ENABLED : STR_LIT_DISABLED);
    
    if( (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V6V4) == 0) ||
       (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V6UDPV4) == 0))
    {
        Display(LOG_LEVEL_1, ELInfo, "tspSetupInterface", GOGO_STR_YOUR_IPV6_IP_IS, t->client_address_ipv6);
        if( (t->prefix != NULL) && (t->prefix_length != NULL) )
            Display(LOG_LEVEL_1, ELInfo, "tspSetupInterface", GOGO_STR_YOUR_IPV6_PREFIX_IS, t->prefix, t->prefix_length);
        if (t->client_dns_server_address_ipv6 != NULL)
            Display(LOG_LEVEL_1, ELInfo, "tspSetupInterface", GOGO_STR_YOUR_IPV6_DNS_IS, t->client_dns_server_address_ipv6);
    }
#ifdef V4V6_SUPPORT
    else
    {
        Display(LOG_LEVEL_1, ELInfo, "tspSetupInterface", GOGO_STR_YOUR_IPV4_IP_IS, t->client_address_ipv4);
        if( (t->prefix != NULL) && (t->prefix_length != NULL) )
            Display(LOG_LEVEL_1, ELInfo, "tspSetupInterface", GOGO_STR_YOUR_IPV4_PREFIX_IS, t->prefix, t->prefix_length);
    }
#endif /* V4V6_SUPPORT */
    
    
    // Set the broker used for connection & the current time(now) for tunnel
    //   start. Then send the tunnel info through the messaging subsystem.
    gTunnelInfo.szBrokerName = c->server;
    gTunnelInfo.tunnelUpTime = pal_time(NULL);
    send_tunnel_info();
    
    return status;
}


// --------------------------------------------------------------------------
// This function will set the required environment variables that will later
// be used when invoking the template script to tear down the existing
// tunnel.
//
gogoc_status tspTearDownTunnel( tConf* pConf, tTunnel* pTunInfo )
{
    char* scriptName = pConf->template;
    
    
    // Specify TSP Operation: Tunnel Teardown.
    tspSetEnv( "TSP_OPERATION", TSP_OPERATION_TEARDOWNTUNNEL, 1 );
    
    // Set environment variables (They may be not set).
    set_tsp_env_variables( pConf, pTunInfo );
    
    // Run the template script to tear the tunnel down.
    Display(LOG_LEVEL_2, ELInfo, "tspTearDownTunnel", STR_GEN_EXEC_CFG_SCRIPT, scriptName );
    if( execScript( scriptName ) != 0 )
    {
        // Error executing script.
        Display(LOG_LEVEL_1, ELError, "tspTearDownTunnel", STR_GEN_SCRIPT_EXEC_FAILED );
        return make_status(CTX_GOGOCTEARDOWN, ERR_INTERFACE_SETUP_FAILED);
    }
    Display(LOG_LEVEL_2, ELInfo, "tspTearDownTunnel", STR_GEN_SCRIPT_EXEC_SUCCESS );
    
    
    // Return script execution return code.
    return STATUS_SUCCESS_INIT;
}

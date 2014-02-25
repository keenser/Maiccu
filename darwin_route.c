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
    
    strncpy(buf,cmd[0], sizeof(buf)-1);
    int i=1;
    while (cmd[i] != NULL)
    {
        strncat(buf, " ", sizeof(buf)-1);
        strncat(buf, cmd[i], sizeof(buf)-1);
        i++;
    }
    Display( LOG_LEVEL_MAX, ELInfo, "execScript", "%s", buf );
    
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
// This function will set the required environment variables that will later
// be used when invoking the template script to actually create the tunnel.
//
gogoc_status tspSetupInterface(tConf *c, tTunnel *t)
{
    gogoc_status status = STATUS_SUCCESS_INIT;
    char *tunnel_interface = NULL;
    char *tunnel_prefixlen = NULL;
    gogocTunnelType tunnelType;
    
    // Perform validation on tunnel information provided by server.
    if( validate_tunnel_info(t) != 0 )
    {
        // Errors occured during verification of tunnel parameters.
        Display( LOG_LEVEL_1, ELError, "tspSetupInterface", STR_TSP_ERRS_TUN_PARAM_FROM_SERVER );
        return make_status(CTX_TUNINTERFACESETUP, ERR_BAD_TUNNEL_PARAM);
    }
    
    // Specify tunnel interface, for setup.
    if (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V6V4) == 0 )
    {
        tunnel_interface = c->if_tunnel_v6v4;
        tunnel_prefixlen = "128";
        tunnelType = TUNTYPE_V6V4;
    }
#ifdef V4V6_SUPPORT
    else if (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V4V6) == 0 )
    {
        tunnel_interface = c->if_tunnel_v4v6;
        tunnel_prefixlen = "32";
        tunnelType = TUNTYPE_V4V6;
    }
#endif /* V4V6_SUPPORT */
    else //if (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V6UDPV4) == 0 )
    {
        tunnel_interface = c->if_tunnel_v6udpv4;
        tunnel_prefixlen = "128";
        tunnelType = TUNTYPE_V6UDPV4;
    }
    
    gTunnelInfo.eTunnelType = tunnelType;
    gTunnelInfo.szIPV4AddrLocalEndpoint = t->client_address_ipv4;
    gTunnelInfo.szIPV6AddrLocalEndpoint = t->client_address_ipv6;
    gTunnelInfo.szIPV6AddrDns = t->client_dns_server_address_ipv6;
    if( t->client_dns_name != NULL)
    {
        gTunnelInfo.szUserDomain = t->client_dns_name;
    }
    gTunnelInfo.szIPV4AddrRemoteEndpoint = t->server_address_ipv4;
    gTunnelInfo.szIPV6AddrRemoteEndpoint = t->server_address_ipv6;
    
    
    // Free and clear delegated prefix from tunnel info.
    if( gTunnelInfo.szDelegatedPrefix != NULL )
    {
        pal_free( gTunnelInfo.szDelegatedPrefix );
        gTunnelInfo.szDelegatedPrefix = NULL;
    }
    
    // Have we been allocated a prefix for routing advertizement..?
    if( t->prefix != NULL )
    {
        // Specify delegated prefix for routing advertizement, if enabled.
        gTunnelInfo.szDelegatedPrefix = (char*) pal_malloc( pal_strlen(t->prefix) + 10/*To append prefix_length*/ );
        strcpy( gTunnelInfo.szDelegatedPrefix, t->prefix );
        
        // Specify prefix length for routing advertizement, if enabled.
        strcat( gTunnelInfo.szDelegatedPrefix, "/" );
        strcat( gTunnelInfo.szDelegatedPrefix, t->prefix_length );
    }    
    
    // Do some platform-specific stuff before tunnel setup script is launched.
    // The "tspSetupInterfaceLocal" is defined in tsp_local.c in every platform.
    if( tspSetupInterfaceLocal( c, t ) != 0 )
    {
        // Errors occured during setup of interface.
        return make_status(CTX_TUNINTERFACESETUP, ERR_INTERFACE_SETUP_FAILED);
    }
    
    
    // -------------------------------------------------------------
    // Run the interface configuration script to bring the tunnel up.
    // ---------------------------------------------------------------
    if (tunnelType == TUNTYPE_V6V4) {
        // Delete first any previous tunnel.
        sh(ifconfig,tunnel_interface,"deletetunnel");
        sh(ifconfig,tunnel_interface,"tunnel",t->client_address_ipv4,t->server_address_ipv4);
        
        //Check if the interface already has an IPv6 configuration
        //list=`$ifconfig $TSP_TUNNEL_INTERFACE | grep inet6 | awk '{print $2}' | grep -v '^fe80'`
        //for ipv6address in $list
        //do
        //    Exec $ifconfig $TSP_TUNNEL_INTERFACE inet6 $ipv6address delete
        //done
    }
    
    sh(ifconfig,tunnel_interface,"inet6",t->client_address_ipv6,t->server_address_ipv6,"prefixlen",tunnel_prefixlen,"alias");
    sh(ifconfig,tunnel_interface,"mtu","1280");
    
    if ( t->originalgateway ) {
        Display( LOG_LEVEL_MAX, ELInfo, "execScript", "Change current default gateway %s", t->originalgateway );
        sh(route,"change","-inet6","default",t->server_address_ipv6);
    }
    else {
        sh(route,"add","-inet6","default",t->server_address_ipv6);
    }
    
    // Router configuration if host_type=router
    if ( pal_strcasecmp(c->host_type, "router") == 0 ) {
        sh("/usr/sbin/sysctl","-w","net.inet6.ip6.forwarding=1"); // ipv6_forwarding enabled
        sh("/usr/sbin/sysctl","-w","net.inet6.ip6.accept_rtadv=0"); // routed must disable any router advertisement incoming

        // Add the IPv6 PREFIX::1 address to advertising interface.
        sh(ifconfig, c->if_prefix,"inet6","$TSP_PREFIX::1","prefixlen","64");
        
        // If prefix length is not 64 bits, then blackhole the remaining part.
        // Because we're only advertising the first /64 part of the prefix.
        if ( pal_strcasecmp(t->prefix_length, "64") ){
            sh(route,"add","-inet6",t->prefix,"-prefixlen",t->prefix_length,"::1");
        }
    
        // Stop and start router advertisement daemon.
        sh("/usr/bin/killall","rtadvd");
        sh("/usr/sbin/rtadvd",c->if_prefix);
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
gogoc_status tspTearDownTunnel( tConf* c, tTunnel* t )
{
    char *tunnel_interface = NULL;
    gogocTunnelType tunnelType;

    // Specify tunnel interface, for setup.
    if (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V6V4) == 0 )
    {
        tunnel_interface = c->if_tunnel_v6v4;
        tunnelType = TUNTYPE_V6V4;
    }
#ifdef V4V6_SUPPORT
    else if (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V4V6) == 0 )
    {
        tunnel_interface = c->if_tunnel_v4v6;
        tunnelType = TUNTYPE_V4V6;
    }
#endif /* V4V6_SUPPORT */
    else //if (pal_strcasecmp(t->type, STR_XML_TUNNELMODE_V6UDPV4) == 0 )
    {
        tunnel_interface = c->if_tunnel_v6udpv4;
        tunnelType = TUNTYPE_V6UDPV4;
    }
    
    // Have we been allocated a prefix for routing advertizement..?
    if( t->prefix != NULL )
    {
        // Specify delegated prefix for routing advertizement, if enabled.
        gTunnelInfo.szDelegatedPrefix = (char*) pal_malloc( pal_strlen(t->prefix) + 10/*To append prefix_length*/ );
        strcpy( gTunnelInfo.szDelegatedPrefix, t->prefix );
        
        // Specify prefix length for routing advertizement, if enabled.
        strcat( gTunnelInfo.szDelegatedPrefix, "/" );
        strcat( gTunnelInfo.szDelegatedPrefix, t->prefix_length );
    }

    // Router deconfiguration
    if ( pal_strcasecmp(c->host_type, "router") == 0 && t->prefix) {
        // Remove prefix routing on TSP_HOME_INTERFACE
        sh(route,"delete","-inet6", t->prefix);
        
        // Remove blackhole.
        if ( pal_strcasecmp(t->prefix_length,"64") ) {
            sh(route,"delete","-inet6",t->prefix,"-prefixlen",t->prefix_length,"::1");
        }
        // Remove static IPv6 address
        //sh(ifconfig,c->if_prefix,"inet6","$TSP_PREFIX::1","delete");

        // Kill router advertisement daemon
        sh("/usr/bin/killall","rtadvd");
    }
    
    //Delete default IPv6 route
    if ( t->originalgateway ) {
        sh(route,"change","-inet6","default",t->originalgateway);
        sh(route,"add","-inet6","default",t->originalgateway);
    }
    else {
        sh(route,"delete","-inet6","default");
    }

    if (tunnelType == TUNTYPE_V6V4) {
        // Delete the interface IPv6 configuration
        sh(ifconfig,tunnel_interface,"inet6",t->client_address_ipv6,"delete");
        // Delete tunnel
        sh(ifconfig,tunnel_interface,"deletetunnel");
    }
    
    Display(LOG_LEVEL_2, ELInfo, "tspTearDownTunnel", STR_GEN_SCRIPT_EXEC_SUCCESS );
    
    // Return script execution return code.
    return STATUS_SUCCESS_INIT;
}

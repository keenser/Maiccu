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
#include "log.h"          // Display()
#include "hex_strings.h"  // Strings for Display()


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
	mib[5] = RTF_STATIC;
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
    
    if (!(rtm->rtm_flags & ( RTF_GATEWAY | RTF_STATIC | RTF_PRCLONING))) return NULL;
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
        printf("%s ",cmd[i]);
        i++;
    }
    puts("\n");
    
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
static const char deletetunnel[] = "deletetunnel";
static const char dfault[] = "default";
static const char sinet6[] = "-inet6";
static const char inet6[] = "inet6";
static const char tsp_tun_if[] = "TSP_TUNNEL_INTERFACE";
static char *originalroute = NULL;

sint32_t execScript( const char * cmd)
{
    char *env_tun_if = getenv(tsp_tun_if);
    
    if (!strcmp(getenv("TSP_OPERATION"),"TSP_TUNNEL_TEARDOWN"))
    {
        sh(route,"delete",sinet6,dfault);
        sh(route,"delete",sinet6,getenv("TSP_CLIENT_ADDRESS_IPV6"));
        sh(ifconfig,env_tun_if,deletetunnel);
    }
    else if(!strcmp(getenv("TSP_HOST_TYPE"),"host"))
    {
        sh(ifconfig,env_tun_if,deletetunnel);
        sh(ifconfig,env_tun_if,"tunnel",getenv("TSP_CLIENT_ADDRESS_IPV4"),getenv("TSP_SERVER_ADDRESS_IPV4"));
        sh(ifconfig,env_tun_if,inet6,getenv("TSP_CLIENT_ADDRESS_IPV6"),getenv("TSP_SERVER_ADDRESS_IPV6"),"prefixlen",getenv("TSP_TUNNEL_PREFIXLEN"),"alias");
        
        sh(ifconfig,env_tun_if,"mtu","1280");
        
        //Delete any default IPv6 route, and add ours.
        sh(route,"delete",sinet6,dfault);
        sh(route,"add",sinet6,dfault,getenv("TSP_SERVER_ADDRESS_IPV6"));
    }
    return 0;
}
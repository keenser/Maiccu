/*
 -----------------------------------------------------------------------------
 $Id: tsp_setup.c,v 1.2 2010/03/07 20:14:32 carl Exp $
 -----------------------------------------------------------------------------
 Copyright (c) 2001-2007 gogo6 Inc. All rights reserved.
 
 For license information refer to CLIENT-LICENSE.TXT
 -----------------------------------------------------------------------------
 */

#include <spawn.h>
#include "platform.h"
#include "log.h"          // Display()
#include "hex_strings.h"  // Strings for Display()

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
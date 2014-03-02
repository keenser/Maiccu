/*
-----------------------------------------------------------------------------
 $Id: net_tcp.h,v 1.1 2009/11/20 16:53:16 jasminko Exp $
-----------------------------------------------------------------------------
  Copyright (c) 2007 gogo6 Inc. All rights reserved.

  For license information refer to CLIENT-LICENSE.TXT.
-----------------------------------------------------------------------------
*/

#ifndef _NET_TCP_H_
#define _NET_TCP_H_

extern sint32_t     NetTCPConnect         (pal_socket_t *, char *, uint16_t );
extern sint32_t     NetTCPClose           (pal_socket_t);

extern ssize_t     NetTCPReadWrite       (pal_socket_t, char *, size_t, char *, size_t);

extern ssize_t     NetTCPWrite           (pal_socket_t, char *, size_t);
extern ssize_t     NetTCPPrintf          (pal_socket_t, char *, size_t, char *, ...);

extern ssize_t     NetTCPRead            (pal_socket_t, char *, size_t);

#endif

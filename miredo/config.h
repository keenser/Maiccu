/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.ac by autoheader.  */

/* Define if building universal (internal helper macro) */
/* #undef AC_APPLE_UNIVERSAL_BUILD */

/* Include pthread support for binary relocation? */
/* #undef BR_PTHREAD */

/* Use binary relocation? */
/* #undef ENABLE_BINRELOC */

/* Define to 1 if translation of program messages to the user's native
   language is requested. */
/* #unded ENABLE_NLS */

/* Define to 1 if you have the MacOS X function CFLocaleCopyCurrent in the
   CoreFoundation framework. */
#define HAVE_CFLOCALECOPYCURRENT 1

/* Define to 1 if you have the MacOS X function CFPreferencesCopyAppValue in
   the CoreFoundation framework. */
#define HAVE_CFPREFERENCESCOPYAPPVALUE 1

/* Define to 1 if you have the `clearenv' function. */
/* #undef HAVE_CLEARENV */

/* Define to 1 if you have the `clock_gettime' function. */
/* #undef HAVE_CLOCK_GETTIME */

/* Define to 1 if you have the `clock_nanosleep' function. */
/* #undef HAVE_CLOCK_NANOSLEEP */

/* Define to 1 if you have the `closefrom' function. */
/* #undef HAVE_CLOSEFROM */

/* Define to 1 if Apple's CoreFoundation framework is available. */
#define HAVE_COREFOUNDATION_FRAMEWORK 1

/* Define if the GNU dcgettext() function is already present or preinstalled.
   */
#define HAVE_DCGETTEXT 1

/* Define to 1 if you have the `devname_r' function. */
#define HAVE_DEVNAME_R 1

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you have the `fdatasync' function. */
#define HAVE_FDATASYNC 1

/* Define to 1 if you have the <getopt.h> header file. */
#define HAVE_GETOPT_H 1

/* Define to 1 if you have the `getopt_long' function. */
#define HAVE_GETOPT_LONG 1

/* Define if the GNU gettext() function is already present or preinstalled. */
#define HAVE_GETTEXT 1

/* Define if you have the iconv() function and it works. */
#define HAVE_ICONV 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the <Judy.h> header file. */
//#define HAVE_JUDY_H 1

/* Define to 1 if you have the `kldload' function. */
/* #undef HAVE_KLDLOAD */

/* Define to 1 if you have the `cap' library (-lcap). */
/* #undef HAVE_LIBCAP */

/* Define to 1 if you have the <libintl.h> header file. */
#define HAVE_LIBINTL_H 1

/* Define to 1 if you the `Judy' library (-lJudy). */
//#define HAVE_LIBJUDY 1

/* Define to 1 if you have the `pthread' library (-lpthread). */
#define HAVE_LIBPTHREAD 1

/* Define to 1 if you have the `resolv' library (-lresolv). */
#define HAVE_LIBRESOLV 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the <net/if_tun.h> header file. */
/* #undef HAVE_NET_IF_TUN_H */

/* Define to 1 if you have the <net/if_var.h> header file. */
#define HAVE_NET_IF_VAR_H 1

/* Define to 1 if you have the <net/tun/if_tun.h> header file. */
/* #undef HAVE_NET_TUN_IF_TUN_H */

/* Define to 1 if you have the `pthread_condattr_setclock' function. */
/* #undef HAVE_PTHREAD_CONDATTR_SETCLOCK */

/* Define to 1 if `struct sockaddr' has a `sa_len' member. */
#define HAVE_SA_LEN 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the `strlcpy' function. */
#define HAVE_STRLCPY 1

/* Define to 1 if Apple's SystemConfiguration framework is available. */
#define HAVE_SYSTEMCONFIGURATION_FRAMEWORK 1

/* Define to 1 if you have the <sys/capability.h> header file. */
/* #undef HAVE_SYS_CAPABILITY_H */

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the `timer_create' function. */
/* #undef HAVE_TIMER_CREATE */

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#define LT_OBJDIR ".libs/"

/* Define to the default system username to be used. */
//#define MIREDO_DEFAULT_USERNAME "nobody"

/* Define to 1 if the Teredo client support must be compiled. */
#define MIREDO_TEREDO_CLIENT 1

/* Define to 1 if assertions should be disabled. */
/* #undef NDEBUG */

/* Name of package */
#define PACKAGE "miredo"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "miredo-devel_no_bulk_mail@remlab.net"

/* Define to the canonical build-system name */
#define PACKAGE_BUILD "x86_64-apple-darwin11.4.2"

/* Define to the hostname of the host who builds the package. */
#define PACKAGE_BUILD_HOSTNAME "mb.lan"

/* Define to the command line used to invoke the configure script. */
#define PACKAGE_CONFIGURE_INVOCATION "./configure  'LDFLAGS=-L/opt/local/lib' 'CPPFLAGS=-I/opt/local/include'"

/* Define to the canonical host-system name */
#define PACKAGE_HOST "x86_64-apple-darwin11.4.2"

/* Define to the full name of this package. */
#define PACKAGE_NAME "miredo"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "miredo 1.2.6"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "miredo"

/* Define to the home page for this package. */
#define PACKAGE_URL ""

/* Define to the version of this package. */
#define PACKAGE_VERSION "1.2.6"

#define LOCALSTATEDIR "."
#define LOCALEDIR "."
#define SYSCONFDIR "/opt/local/etc"
#define PKGLIBEXECDIR "/opt/local/lib/miredo"

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Enable extensions on AIX 3, Interix.  */
#ifndef _ALL_SOURCE
# define _ALL_SOURCE 1
#endif
/* Enable GNU extensions on systems that have them.  */
#ifndef _GNU_SOURCE
# define _GNU_SOURCE 1
#endif
/* Enable threading extensions on Solaris.  */
#ifndef _POSIX_PTHREAD_SEMANTICS
# define _POSIX_PTHREAD_SEMANTICS 1
#endif
/* Enable extensions on HP NonStop.  */
#ifndef _TANDEM_SOURCE
# define _TANDEM_SOURCE 1
#endif
/* Enable general extensions on Solaris.  */
#ifndef __EXTENSIONS__
# define __EXTENSIONS__ 1
#endif


/* Version number of package */
#define VERSION "1.2.6"

/* Define WORDS_BIGENDIAN to 1 if your processor stores words with the most
   significant byte first (like Motorola and SPARC, unlike Intel). */
#if defined AC_APPLE_UNIVERSAL_BUILD
# if defined __BIG_ENDIAN__
#  define WORDS_BIGENDIAN 1
# endif
#else
# ifndef WORDS_BIGENDIAN
/* #  undef WORDS_BIGENDIAN */
# endif
#endif

/* Define to fix pthread_cancel() on Mac OS X. */
#define _APPLE_C_SOURCE 1

/* Define to 1 if on MINIX. */
/* #undef _MINIX */

/* Define to 2 if the system does not provide POSIX.1 features except with
   this defined. */
/* #undef _POSIX_1_SOURCE */

/* Define to 1 if you need to in order for `stat' and other things to work. */
/* #undef _POSIX_SOURCE */

/* Define to int if clockid_t is not supported. */
#define clockid_t int

/* Fallback replacement for GNU `getopt_long' */
#ifndef HAVE_GETOPT_LONG
# define getopt_long( argc, argv, optstring, longopts, longindex ) \
	getopt (argc, argv, optstring)
# if !GETOPT_STRUCT_OPTION && !HAVE_GETOPT_H
 struct option { const char *name; int has_arg; int *flag; int val; };
#  define GETOPT_STRUCT_OPTION 1
# endif
# ifndef required_argument
#  define no_argument 0
#  define required_argument 1
#  define optional_argument 2
# endif
#endif

#include <compat/fixups.h>

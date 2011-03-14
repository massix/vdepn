AC_INIT([VDE PN Manager], [0.7.0], [gengarel@cs.unibo.it], [vdepn])
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADERS([config.h])
AM_MAINTAINER_MODE
AM_INIT_AUTOMAKE

VALA_REQUIRED=0.7.0
GLIB_REQUIRED=2.12.0
GTK_REQUIRED=2.14.0
LIBXML_REQUIRED=2.7.0
LIBNOTIFY_REQUIRED=0.5.0

AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_LIBTOOL
AC_PROG_INTLTOOL
AM_PROG_VALAC($VALA_REQUIRED)
AC_SUBST(VALAC)

dnl -------------------------------------
dnl check for programs that will be used
dnl -------------------------------------

AC_PATH_PROG(PKEXEC, pkexec, no)
if test "x$PKEXEC" = "xno"; then
   AC_MSG_ERROR([Can't find pkexec in your path!])
fi
AC_DEFINE_UNQUOTED(PKEXEC_CMD, "$PKEXEC", [pkexec command path])


AC_PATH_PROG(VDE_SWITCH, vde_switch, no)
if test "x$VDE_SWITCH" = "xno"; then
   AC_MSG_ERROR([Can't find vde_switch in your path!])
fi
AC_DEFINE_UNQUOTED(VDE_SWITCH_CMD, "$VDE_SWITCH", [vde_switch command path])


AC_PATH_PROG(VDE_PLUG, vde_plug, no)
if test "x$VDE_PLUG" = "xno"; then
   AC_MSG_ERROR([Can't find vde_plug in your path!])
fi
AC_DEFINE_UNQUOTED(VDE_PLUG_CMD, "$VDE_PLUG", [vde_plug command path])


AC_PATH_PROG(VDE_PLUG2TAP, vde_plug2tap, no)
if test "x$VDE_PLUG2TAP" = "xno"; then
   AC_MSG_ERROR([Can't find vde_plug2tap in your path!])
fi
AC_DEFINE_UNQUOTED(VDE_PLUG2TAP_CMD, "$VDE_PLUG2TAP", [vde_plug2tap command path])


AC_PATH_PROG(IFCONFIG, ifconfig, no)
if test "x$IFCONFIG" = "xno"; then
   AC_MSG_ERROR([Can't find ifconfig in your path!])
fi
AC_DEFINE_UNQUOTED(IFCONFIG_CMD, "$IFCONFIG", [ifconfig command path])


AC_PATH_PROG(SSH, ssh, no)
if test "x$SSH" = "xno"; then
   AC_MSG_ERROR([Can't find ssh in your path!])
fi
AC_DEFINE_UNQUOTED(SSH_CMD, "$SSH", [ssh command path])


AC_PATH_PROG(PGREP, pgrep, no)
if test "x$PGREP" = "xno"; then
   AC_MSG_ERROR([Can't find pgrep in your path!])
fi
AC_DEFINE_UNQUOTED(PGREP_CMD, "$PGREP", [pgrep command path])


AC_PATH_PROG(DPIPE, dpipe, no)
if test "x$DPIPE" = "xno"; then
   AC_MSG_ERROR([Can't find dpipe in your path!])
fi
AC_DEFINE_UNQUOTED(DPIPE_CMD, "$DPIPE", [dpipe command path])


dnl -------------------
dnl check for libraries
dnl -------------------

GETTEXT_PACKAGE=vde_manager
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE", [gettext package])
AM_GLIB_GNU_GETTEXT

PKG_CHECK_MODULES(GLIB, glib-2.0 >= $GLIB_REQUIRED
						gobject-2.0 >= $GLIB_REQUIRED
						gio-2.0 >= $GLIB_REQUIRED)

PKG_CHECK_MODULES(GTK, gdk-2.0 >= $GTK_REQUIRED
					   gtk+-2.0 >= $GTK_REQUIRED)

PKG_CHECK_MODULES(LIBXML, libxml-2.0 >= $LIBXML_REQUIRED)

PKG_CHECK_MODULES(LIBNOTIFY, libnotify >= $LIBNOTIFY_REQUIRED)

OS_CFLAGS="-DPKGDATADIR='\"\$(prefix)\"'"

AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)
AC_SUBST(GTK_CFLAGS)
AC_SUBST(GTK_LIBS)
AC_SUBST(LIBXML_CFLAGS)
AC_SUBST(LIBXML_LIBS)
AC_SUBST(LIBNOTIFY_CFLAGS)
AC_SUBST(LIBNOTIFY_LIBS)
AC_SUBST(OS_CFLAGS)

AC_CONFIG_FILES([
	Makefile
	src/Makefile
	share/Makefile
	vapi/Makefile
	po/Makefile.in])

AC_OUTPUT

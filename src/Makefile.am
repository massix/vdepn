AM_CPPFLAGS = \
			-DGETTEXT_PACKAGE='"$(GETTEXT_PACKAGE)"' \
			-DGTK_DISABLE_DEPRECATED \
			-DGDK_DISABLE_DEPRECATED \
			-DLOCALEDIR='"$(localedir)"' \
			-DVERSION='"$(VERSION)"' \
			-DPACKAGE='"$(PACKAGE)"' \
			$(OS_CFLAGS) \
			$(GLIB_CFLAGS) \
			$(GTK_CFLAGS) \
			$(LIBNOTIFY_CFLAGS) \
			$(LIBXML_CFLAGS)

AM_VALAFLAGS = \
			--disable-assert \
			--disable-warnings \
			--pkg libxml-2.0 \
			--pkg gtk+-2.0 \
			--pkg config \
			--pkg libnotify \
			--vapidir "$(abs_top_srcdir)/vapi"

bin_PROGRAMS = vde_manager

vde_manager_SOURCES = \
			configuration_list.vala \
			conf_parser.vala \
			helper.vala \
			main.vala \
			configuration_property.vala \
			configuration_page.vala \
			tray_icon.vala \
			vde_connector.vala \
			preferences.vala

vde_manager_LDFLAGS = \
			$(GLIB_LIBS) \
			$(GTK_LIBS) \
			$(LIBNOTIFY_LIBS) \
			$(LIBXML_LIBS)
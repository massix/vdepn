AM_CPPFLAGS = \
			$(OS_CFLAGS) \
			$(GLIB_CFLAGS) \
			$(GTK_CFLAGS) \
			$(LIBXML_CFLAGS)

AM_VALAFLAGS = \
			--pkg libxml-2.0 \
			--pkg gtk+-2.0 \
			--pkg config \
			--vapidir "$(abs_top_srcdir)/vapi"

bin_PROGRAMS = vde_manager

vde_manager_SOURCES = \
			mainwindow.vala \
			conf_parser.vala \
			helpers.vala \
			main.vala \
			vde_connector.vala

vde_manager_LDFLAGS = \
			$(GLIB_LIBS) \
			$(GTK_LIBS) \
			$(LIBXML_LIBS)
imagedir=$(prefix)/share/icons/hicolor/scalable/apps

image_DATA = \
	vdepn.svg \
	vdepn_big.svg

applicationdir=$(prefix)/share/applications
application_in_files = vdepn.desktop.in
application_DATA = $(application_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = vdepn.desktop vdepn.svg vdepn_big.svg


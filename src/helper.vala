/* VDE PN Manager -- VDE Private Network Manager
 * Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 */

using GLib.Environment;

namespace VDEPN {
	public class Helper : GLib.Object {
		/* This will be used both in the VDEConnector and in the PreferencesPane */
		public enum RootGainer {
			PKEXEC,
			SU,
			SUDO
		}

		public const string TAG_DEBUG = "DEBUG";
		public const string TAG_ERROR = "ERROR";
		public const string TAG_WARNING = "WARNING";
		public const string PROG_DATA_DIR = "/vdepn";
		public const string NOTIFY_ACTIVE = "Connection activated";
		public const string NOTIFY_DEACTIVE = "Connection deactivated";
		public const string ICON_PATH = Config.PKGDATADIR + "/share/icons/hicolor/scalable/apps/vdepn.svg";
		public const string LOGO_PATH = Config.PKGDATADIR + "/share/icons/hicolor/scalable/apps/vdepn_big.svg";
		public const string XML_FILE = PROG_DATA_DIR + "/connections.xml";
		public const string XML_PREF_FILE = PROG_DATA_DIR + "/preferences.xml";
		public const string SSH_ARGS = "-o PasswordAuthentication=no -o StrictHostKeyChecking=no -o ServerAliveInterval=30";
		public const string SSH_PRIV_KEY = PROG_DATA_DIR + "/vdepn-key";
		public const string SSH_PUB_KEY = PROG_DATA_DIR + "/vdepn-key.pub";
		public const int TIMEOUT = 10000;
		public const string LICENSE = """VDE PN Manager -- VDE Private Network Manager
Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>
                   - Vincenzo Ferrari <ferrari@cs.unibo.it>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
""";

		public static void debug(string tag, string message) {
			stdout.printf("[%s] %s\n", tag, message);
		}
	}
}

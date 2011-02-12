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
		public const string TAG_DEBUG = "DEBUG";
		public const string TAG_ERROR = "ERROR";
		public const string TAG_WARNING = "WARNING";
		public const string PROG_DATA_DIR = "/vdepn";
		public const string NOTIFY_ACTIVE = "Connection activated";
		public const string NOTIFY_DEACTIVE = "Connection deactivated";
		public const string ICON_PATH = Config.PKGDATADIR + "/share/v2.png";

		public const string XML_FILE = PROG_DATA_DIR + "/connections.xml";

		public static void debug(string tag, string message)
		{
			stdout.printf("[%s] %s\n", tag, message);
		}
	}
}
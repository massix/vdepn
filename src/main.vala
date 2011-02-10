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
	public class Application
	{
		public static void main(string[] args)
			{
				Gtk.init(ref args);
				debug(Helper.TAG_DEBUG, get_user_data_dir());
				debug(Helper.TAG_DEBUG, get_user_config_dir());
				set_application_name("VDE PN Manager");
				set_prgname("VDE PN Manager");
				string title = get_user_name() + "@" + get_host_name();
				ConfigurationsList mainWindow = new ConfigurationsList(title + " VDE PN Manager");
				Gtk.main();
			}
	}
}

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

namespace VDEPN.Preferences {
	/* This class is a Singleton, which means that there could be only
	 * one active instance at a time */
	public class CustomPreferences : GLib.Object {
		private static CustomPreferences instance;

		/* Various preferences */
		public Helper.RootGainer root_method { get; private set; }

		/* Empty constructor */
		private CustomPreferences () { }

		public static CustomPreferences get_instance () {
			if (instance == null)
				instance = new CustomPreferences ();

			return instance;
		}

		public void show_pane () {
			PreferencesPane pane = new PreferencesPane (instance);

			pane.run ();
		}

	}

	/* This is the actual window which shows up the preferences and let the user modify'em */
	private class PreferencesPane : Gtk.Window {
		public PreferencesPane (CustomPreferences initial_preferences) {
			resize (200, 200);
		}

		public void run () {
			show_all ();
		}
	}
}

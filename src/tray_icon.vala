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

using Gtk;

namespace VDEPN {
	// creates a new icon in the system tray, linked to the parent
	public class VDETrayIcon : Gtk.StatusIcon {
		private Manager.VDEConnector connector;

		/* Signals for the topmost widgets */
		public signal void manage_connection (VDETrayIcon self, string conn_id);
		public signal void disconnect_connection (VDETrayIcon self, string conn_id);
		public signal void show_connection_page (VDETrayIcon self, string conn_id);
		public signal void quit_application (VDETrayIcon self);

		public VDETrayIcon () {
			/* Chain up to the default constructor */
			GLib.Object ();
			set_from_file (Helper.ICON_PATH);
			has_tooltip = false;
			title = "VDE PN Manager";

			connector = Manager.VDEConnector.get_instance ();

			/* Builds a Menu showing currently active connections or
			   "No active connections" if none are active */
			popup_menu.connect ((but, acttime) => {
					Menu inner_menu = new Menu ();
					MenuItem act_conn = new MenuItem.with_label (_("Active Connections"));
					MenuItem quit_item = new MenuItem.with_label (_("Quit VDE PN Manager"));
					SeparatorMenuItem sep = new SeparatorMenuItem ();
					sep.show ();
					act_conn.show ();
					quit_item.show ();
					act_conn.sensitive = false;
					inner_menu.append (act_conn);
					inner_menu.append (sep);

					quit_item.activate.connect (() => {
							this.quit_application (this);
						});

					if (connector.count_active_connections () <= 0) {
						MenuItem no_act_conn = new MenuItem.with_label (_("No active Connections"));
						no_act_conn.show ();
						inner_menu.append (no_act_conn);
					}

					else {
						for (int i = 0; i < connector.count_active_connections (); i++) {
							Manager.VDEConnection temp = connector.get_connection (i);
							MenuItem conn = new MenuItem.with_label (temp.conn_id);
							Menu inner_conn_menu = new Menu ();
							MenuItem manage = new MenuItem.with_label (_("Manage"));
							MenuItem show_page = new MenuItem.with_label (_("Show page"));
							MenuItem disconnect = new MenuItem.with_label (_("Disconnect"));
							conn.show ();
							manage.show ();
							show_page.show ();
							disconnect.show ();
							inner_menu.append (conn);
							conn.submenu = inner_conn_menu;
							inner_conn_menu.append (manage);
							inner_conn_menu.append (show_page);
							inner_conn_menu.append (disconnect);

							/* Link signals */
							manage.activate.connect (() => this.manage_connection (this, temp.conn_id));
							show_page.activate.connect (() => this.show_connection_page (this, temp.conn_id));
							disconnect.activate.connect (() => this.disconnect_connection (this, temp.conn_id));
						}
					}

					inner_menu.append (sep);
					inner_menu.append (quit_item);
					inner_menu.popup (null, null, null, but, acttime);
				});

			show ();
		}

		public void show () {
			visible = true;
		}

		public void hide () {
			visible = false;
		}

	}
}
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
	public class TrayIcon : Gtk.StatusIcon {
		private ConfigurationsList parent;
		private Manager.VDEConnector parent_connector;

		public TrayIcon (ConfigurationsList linked) {
			/* Chain up to the default constructor */
			GLib.Object ();
			set_from_file (Helper.ICON_PATH);
			has_tooltip = false;
			title = "VDE PN Manager";
			parent = linked;

			parent_connector = parent.connections_manager;

			activate.connect (() => {
					parent.visible = !parent.visible;
				});

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
							linked.quit_application ();
						});

					if (parent_connector.count_active_connections () <= 0) {
						MenuItem no_act_conn = new MenuItem.with_label (_("No active Connections"));
						no_act_conn.show ();
						inner_menu.append (no_act_conn);
					}

					else {
						for (int i = 0; i < parent_connector.count_active_connections (); i++) {
							Manager.VDEConnection temp = parent_connector.get_connection (i);
							MenuItem conn = new MenuItem.with_label (temp.conn_id);
							conn.show ();
							inner_menu.append (conn);
							conn.activate.connect (() => {
									if (!parent.visible)
										parent.visible = true;
									parent.present ();
									parent.switch_page (temp.conn_id);
									inner_menu.hide ();
								});
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
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
using GLib.Environment;

namespace VDEPN
{
	public class ConfigurationsList : Gtk.Window
	{
		private VBox main_vbox;
		private Notebook conf_pages;
		private VdeParser conf_holder;
		private List<VdeConfiguration> conf_list;
		private MenuBar main_menu;
		private string prg_files = get_user_config_dir() + "/vdepn";

		public ConfigurationsList(string caption)
		{
			build_menubar();
			try {
				set_icon_from_file(Config.PKGDATADIR + "/share/v2.png");
			}

			catch (Error e) {
				Helper.debug(Helper.TAG_ERROR, "Can't find v2.png image in " + Config.PKGDATADIR + "/share/");
			}

			main_vbox = new VBox(false, 2);
			conf_pages = new Notebook();
			title = caption;
			resize(200,200);
			this.delete_event.connect(
				(a) => {
					Gtk.main_quit();
					return true;
				});

			try {
				conf_holder = new VdeParser(prg_files + "/connections.xml");
			}
			catch (Error e)
			{
				Helper.debug(Helper.TAG_ERROR, "Error while parsing XML file");
			}

			conf_list = conf_holder.get_configurations();

			foreach (VdeConfiguration v in conf_list) {
				// build a notebook page for each configuration
				bool button_status = false;
				Table conf_table = new Table(7, 2, true);
				string conn_name = v.connection_name;
				string conn_machine = v.machine;
				string conn_user = v.user;
				string conn_socket = v.socket_path;

				Label conn_name_label = new Label("Connection name: ");
				Entry conn_name_entry = new Entry();

				Label machine_label = new Label("VDE Machine: ");
				Entry machine_entry = new Entry();

				Label user_label = new Label("VDE User: ");
				Entry user_entry = new Entry();

				Label socket_label = new Label("Socket path: ");
				Entry socket_entry = new Entry();

				CheckButton button_ssh = new CheckButton.with_label("Use SSH keys");
				CheckButton button_root = new CheckButton.with_label("Needs root");

				button_ssh.active = v.use_keys;
				button_root.active = v.root_required;

				Button activate_connection = get_button(v, out button_status);

				activate_connection.clicked.connect(
					(ev) => {
						if (button_status == false) {
							// Activate Connection
							activate_connection.label = "Deactivate";
							Helper.debug(Helper.TAG_DEBUG, "Activated Connection " + conn_name);
							button_status = true;
						}
						else {
							// Deactivate Connection
							activate_connection.label = "Activate";
							Helper.debug(Helper.TAG_DEBUG, "Deactivated Connection " + conn_name);
							button_status = false;
						}
					});

				machine_entry.editable = false;
				machine_entry.text = conn_machine;

				conn_name_entry.editable = false;
				conn_name_entry.text = conn_name;

				user_entry.editable = false;
				user_entry.text = conn_user;

				socket_entry.editable = false;
				socket_entry.text = conn_socket;

				conf_table.attach_defaults(conn_name_label, 0, 1, 0, 1);
				conf_table.attach_defaults(conn_name_entry, 1, 2, 0, 1);

				conf_table.attach_defaults(machine_label, 0, 1, 1, 2);
				conf_table.attach_defaults(machine_entry, 1, 2, 1, 2);

				conf_table.attach_defaults(user_label, 0, 1, 2, 3);
				conf_table.attach_defaults(user_entry, 1, 2, 2, 3);

				conf_table.attach_defaults(socket_label, 0, 1, 3, 4);
				conf_table.attach_defaults(socket_entry, 1, 2, 3, 4);

				conf_table.attach_defaults(button_ssh, 0, 1, 4, 5);
				conf_table.attach_defaults(button_root, 1, 2, 4, 5);

				conf_table.attach_defaults(activate_connection, 0, 2, 6, 7);

				conf_pages.append_page(conf_table, new Label(conn_name));
			}

			main_vbox.pack_start(main_menu);
			main_vbox.pack_end(conf_pages);
			add(main_vbox);
			show_all();
		}

		private void build_menubar()
		{
			main_menu = new MenuBar();

			// file
			Menu file_menu = new Menu();
			MenuItem file_item = new MenuItem.with_label("File");
			MenuItem new_conn_item = new MenuItem.with_label("New connection");
			MenuItem exit_item = new MenuItem.with_label("Exit");
			file_menu.append(new_conn_item);
			file_menu.append(exit_item);

			new_conn_item.activate.connect(
				(ev) => {
					Helper.debug(Helper.TAG_DEBUG, "New connection");
				});

			exit_item.activate.connect(
				(ev) => {
					Gtk.main_quit();
				});

			file_item.submenu = file_menu;

			main_menu.append(file_item);
		}

		private Button get_button(VdeConfiguration c, out bool status)
		{
			status = false;
			return new Button.with_label("Activate");
		}
	}
}

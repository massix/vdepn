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
using Notify;
using GLib.Environment;

namespace VDEPN {
	private class ConfigurationPage : Gtk.Table {
		private ConfigurationsList father;
		private VDEConfiguration config		{ get; private set; }

		public Table conf_table				{ get; private set; }
		public Entry conn_name_entry		{ get; private set; }
		public Entry machine_entry			{ get; private set; }
		public Entry user_entry				{ get; private set; }
		public Entry socket_entry			{ get; private set; }
		public Entry ipaddr_entry			{ get; private set; }
		public CheckButton button_ssh		{ get; private set; }
		public CheckButton button_checkhost { get; private set; }
		public bool button_status			{ get; private set; }
		public int index					{ get; private set; }

		/* Builds a new Notebook Page */
		public ConfigurationPage (VDEConfiguration v, ConfigurationsList father) {
			this.config = v;
			this.father = father;

			resize(9, 2);

			string conn_name = config.connection_name;
			string conn_machine = config.machine;
			string conn_user = config.user;
			string conn_socket = config.socket_path;
			string conn_ipaddr = config.ip_address;

			index = father.conf_list.index (config);
			button_status = false;
			conf_table = new Table (8, 2, true);

			Label conn_name_label = new Label ("<b>Connection</b> name:");
			conn_name_entry = new Entry ();
			conn_name_label.use_markup = true;

			Label machine_label = new Label ("VDE <b>Machine</b>:");
			machine_entry = new Entry ();
			machine_label.use_markup = true;
			machine_entry.changed.connect(() => {
					machine_entry.text = machine_entry.text.replace (" ", "-");
				});

			Label user_label = new Label ("VDE <b>User</b>:");
			user_entry = new Entry ();
			user_label.use_markup = true;
			user_entry.changed.connect(() => {
					user_entry.text = user_entry.text.replace (" ", "-");
				});


			Label socket_label = new Label ("<b>Socket</b> path:");
			socket_entry = new Entry ();
			socket_label.use_markup = true;
			socket_entry.changed.connect(() => {
					socket_entry.text = socket_entry.text.replace (" ", "-");
				});


			Label ipaddr_label = new Label ("TUN Interface <b>IPv4</b>:");
			ipaddr_entry = new Entry ();
			ipaddr_label.use_markup = true;
			ipaddr_entry.changed.connect(() => {
					ipaddr_entry.text = ipaddr_entry.text.replace (" ", "-");
				});

			button_ssh = new CheckButton.with_label ("Use SSH keys");
			button_checkhost = new CheckButton.with_label ("Check Host");

			button_ssh.active = config.use_keys;
			button_checkhost.active = config.checkhost;

			Button activate_connection = get_button ();
			Button save_configuration = new Button.with_label ("Save");

			machine_entry.editable = true;
			machine_entry.set_text (conn_machine);

			conn_name_entry.editable = false;
			conn_name_entry.set_text (conn_name);

			user_entry.editable = true;
			user_entry.set_text (conn_user);

			socket_entry.editable = true;
			socket_entry.set_text (conn_socket);

			ipaddr_entry.editable = true;
			ipaddr_entry.set_text (conn_ipaddr);

			attach_defaults (conn_name_label, 0, 1, 0, 1);
			attach_defaults (conn_name_entry, 1, 2, 0, 1);

			attach_defaults (machine_label, 0, 1, 1, 2);
			attach_defaults (machine_entry, 1, 2, 1, 2);

			attach_defaults (user_label, 0, 1, 2, 3);
			attach_defaults (user_entry, 1, 2, 2, 3);

			attach_defaults (socket_label, 0, 1, 3, 4);
			attach_defaults (socket_entry, 1, 2, 3, 4);

			attach_defaults (ipaddr_label, 0, 1, 4, 5);
			attach_defaults (ipaddr_entry, 1, 2, 4, 5);

			attach_defaults (button_ssh, 0, 1, 5, 6);
			attach_defaults (button_checkhost, 1, 2, 5, 6);

			attach_defaults (save_configuration, 0, 1, 7, 8);
			attach_defaults (activate_connection, 1, 2, 7, 8);

			ipaddr_label.xalign = (float) 0;
			socket_label.xalign = (float) 0;
			user_label.xalign = (float) 0;
			machine_label.xalign = (float) 0;
			conn_name_label.xalign = (float) 0;

			//father.conf_pages.append_page (conf_table, new Label(conn_name));

			save_configuration.clicked.connect ((ev) => {
					config.update_configuration (socket_entry.text, machine_entry.text,
											  user_entry.text, ipaddr_entry.text,
											  button_checkhost.active, button_ssh.active);
					config.store_configuration (father.conf_holder);
				});

			/* tries to activate the connection, showing a fancy
			 * spinner while the Application works in background */
			activate_connection.clicked.connect ((ev) => {
					Spinner conn_spinner = new Spinner ();

					/* the empty line between the checkbuttons and the buttons */
					attach_defaults (conn_spinner, 0, 2, 6, 7);

					conn_spinner.start ();
					show_all ();

					/* check if we can do multithreading (not implemented yet) */
					if (Thread.supported ()) {
						Helper.debug (Helper.TAG_DEBUG, "Threads are supported");
						/* TODO: multithreaded activation/deactivation of the connection */
					}

					/* this actually activates the connection */
					if (button_status == false) {
						try {
							config.update_configuration (socket_entry.get_text (), machine_entry.get_text (),
														 user_entry.get_text (), ipaddr_entry.get_text (),
														 button_checkhost.active, button_ssh.active);

							/* this may throws exceptions */
							father.connections_manager.new_connection (config);
							button_status = true;
							activate_connection.label = "Deactivate";
						}

						/* woah.. something bad happened :( */
						catch (Manager.ConnectorError e) {
							Dialog error_dialog = new Dialog.with_buttons ("Error", father, DialogFlags.MODAL);
							Label err_label = new Label ("<b>" + e.message + "</b>");
							err_label.use_markup = true;
							error_dialog.vbox.add (new Label ("Error while activating connection"));
							error_dialog.vbox.add (err_label);
							error_dialog.add_button ("Close", 0);
							error_dialog.vbox.show_all ();
							error_dialog.close.connect ((ev) => {
									error_dialog.destroy ();
								});
							error_dialog.response.connect ((ev, resp) => {
									error_dialog.destroy();
								});
							//Helper.debug(Helper.TAG_ERROR, e.message);
							error_dialog.run();
						}
					}

					/* Deactivate the connection */
					else {
						activate_connection.label = "Activate";
						father.connections_manager.rm_connection (conn_name);
						button_status = false;
					}

					/* it's enough, I hate spinners. BURN'EM WITH FIRE */
					conn_spinner.stop ();
					conf_table.remove (conn_spinner);
					conn_spinner.destroy ();
				});
		}

		private Button get_button () {
			File pidfile = File.new_for_path ("/tmp/vdepn-" + config.connection_name + ".pid");
			if (pidfile.query_exists (null)) {
				father.connections_manager.new_connection_from_pid (config);
				button_status = true;
				return new Button.with_label ("Deactivate");
			}
			else {
				button_status = false;
				return new Button.with_label ("Activate");
			}
		}
	}
}

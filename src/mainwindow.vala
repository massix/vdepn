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
	public class ConfigurationsList : Gtk.Window {
		private VBox main_vbox;
		private Notebook conf_pages;
		private VDEParser conf_holder;
		private List<VDEConfiguration> conf_list;
		private MenuBar main_menu;
		private string prg_files = get_user_config_dir () + "/vdepn";
		public Manager.VDEConnector connections_manager { get; private set; }
		private Notification conn_notify_active;
		private Notification conn_notify_deactivated;

		public ConfigurationsList (string caption) {
			connections_manager = new Manager.VDEConnector ();
			build_menubar ();
			try {
				set_icon_from_file (Helper.ICON_PATH);
			}

			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, "Can't find " + Helper.ICON_PATH);
			}

			main_vbox = new VBox (false, 2);
			conf_pages = new Notebook ();
			conn_notify_active = new Notification (Config.PACKAGE_NAME,
												   Helper.NOTIFY_ACTIVE,
												   Helper.ICON_PATH);
			conn_notify_deactivated = new Notification (Config.PACKAGE_NAME,
														Helper.NOTIFY_DEACTIVE,
														Helper.ICON_PATH);
			conf_pages.scrollable = true;
			title = caption;
			resize (200,200);
			resizable = false;
			this.delete_event.connect((ev) => {
					visible = false;;
					return true;
				});

			try {
				conf_holder = new VDEParser (prg_files + "/connections.xml");
			}
			catch (Error e)
			{
				Helper.debug (Helper.TAG_ERROR, "Error while parsing XML file");
			}

			conf_list = conf_holder.get_configurations ();
			build_notebook ();
			main_vbox.pack_start (main_menu, false, true, 0);
			main_vbox.pack_end (conf_pages, true, true, 0);
			add (main_vbox);
			show_all ();
		}

		private void add_notebook_page (VDEConfiguration v) {
			// build a notebook page for each configuration
			int index = conf_list.index (v);
			bool button_status = false;
			Table conf_table = new Table (8, 2, true);

			string conn_name = v.connection_name;
			string conn_machine = v.machine;
			string conn_user = v.user;
			string conn_socket = v.socket_path;
			string conn_ipaddr = v.ip_address;

			Label conn_name_label = new Label ("<b>Connection</b> name:");
			Entry conn_name_entry = new Entry ();
			conn_name_label.use_markup = true;

			Label machine_label = new Label ("VDE <b>Machine</b>:");
			Entry machine_entry = new Entry ();
			machine_label.use_markup = true;

			Label user_label = new Label ("VDE <b>User</b>:");
			Entry user_entry = new Entry ();
			user_label.use_markup = true;

			Label socket_label = new Label ("<b>Socket</b> path:");
			Entry socket_entry = new Entry ();
			socket_label.use_markup = true;

			Label ipaddr_label = new Label ("TUN Interface <b>IPv4</b>:");
			Entry ipaddr_entry = new Entry ();
			ipaddr_label.use_markup = true;

			CheckButton button_ssh = new CheckButton.with_label ("Use SSH keys");
			CheckButton button_checkhost = new CheckButton.with_label ("Check Host");

			button_ssh.active = v.use_keys;
			button_checkhost.active = v.checkhost;

			Button activate_connection = get_button (v, out button_status);
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

			conf_table.attach_defaults (conn_name_label, 0, 1, 0, 1);
			conf_table.attach_defaults (conn_name_entry, 1, 2, 0, 1);

			conf_table.attach_defaults (machine_label, 0, 1, 1, 2);
			conf_table.attach_defaults (machine_entry, 1, 2, 1, 2);

			conf_table.attach_defaults (user_label, 0, 1, 2, 3);
			conf_table.attach_defaults (user_entry, 1, 2, 2, 3);

			conf_table.attach_defaults (socket_label, 0, 1, 3, 4);
			conf_table.attach_defaults (socket_entry, 1, 2, 3, 4);

			conf_table.attach_defaults (ipaddr_label, 0, 1, 4, 5);
			conf_table.attach_defaults (ipaddr_entry, 1, 2, 4, 5);

			conf_table.attach_defaults (button_ssh, 0, 1, 5, 6);
			conf_table.attach_defaults (button_checkhost, 1, 2, 5, 6);

			conf_table.attach_defaults (save_configuration, 0, 1, 7, 8);
			conf_table.attach_defaults (activate_connection, 1, 2, 7, 8);

			ipaddr_label.xalign = (float) 0;
			socket_label.xalign = (float) 0;
			user_label.xalign = (float) 0;
			machine_label.xalign = (float) 0;
			conn_name_label.xalign = (float) 0;

			conf_pages.append_page (conf_table, new Label(conn_name));

			save_configuration.clicked.connect ((ev) => {
					VDEConfiguration tmp = conf_list.nth_data (index);
					tmp.update_configuration (socket_entry.text, machine_entry.text,
											  user_entry.text, ipaddr_entry.text,
											  button_checkhost.active, button_ssh.active);
					tmp.store_configuration (conf_holder);
				});

			/* tries to activate the connection, showing a fancy
			 * spinner while the Application works in background */
			activate_connection.clicked.connect ((ev) => {
					Spinner conn_spinner = new Spinner ();

					/* the empty line between the checkbuttons and the buttons */
					conf_table.attach_defaults (conn_spinner, 0, 2, 6, 7);

					conn_spinner.start ();
					conf_table.show_all ();

					/* check if we can do multithreading (not implemented yet) */
					if (Thread.supported ()) {
						Helper.debug (Helper.TAG_DEBUG, "Threads are supported");
						/* TODO: multithreaded activation/deactivation of the connection */
					}

					/* this actually activates the connection */
					if (button_status == false) {
						try {
							VDEConfiguration new_conn = conf_list.nth_data (index);
							new_conn.update_configuration (socket_entry.get_text (), machine_entry.get_text (),
														   user_entry.get_text (), ipaddr_entry.get_text (),
														   button_checkhost.active, button_ssh.active);

							/* this may throws exceptions */
							connections_manager.new_connection (new_conn);
							button_status = true;
							activate_connection.label = "Deactivate";

							try {
								conn_notify_active.update(Config.PACKAGE_NAME, Helper.NOTIFY_ACTIVE +
														  " (" + new_conn.connection_name + ")",
														  Helper.ICON_PATH);
								conn_notify_active.show();
							}

							catch (GLib.Error e) {
								Helper.debug(Helper.TAG_ERROR, "Error while showing notification");
							}

						}

						/* woah.. something bad happened :( */
						catch (Manager.ConnectorError e) {
							Dialog error_dialog = new Dialog.with_buttons ("Error", this, DialogFlags.MODAL);
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
						connections_manager.rm_connection (conn_name);
						try {
							conn_notify_deactivated.update (Config.PACKAGE_NAME, Helper.NOTIFY_DEACTIVE +
															" (" + conn_name + ")",
															Helper.ICON_PATH);
							conn_notify_deactivated.show ();
						} catch (Error e) {
							Helper.debug (Helper.TAG_ERROR, "Error while showing notification");
						}

						button_status = false;
					}

					/* it's enough, I hate spinners. BURN'EM WITH FIRE */
					conn_spinner.stop ();
					conf_table.remove (conn_spinner);
					conn_spinner.destroy ();
				});

			conf_pages.show_all ();
		}

		private void build_notebook () {
			foreach (VDEConfiguration v in conf_list) {
				add_notebook_page (v);
			}

			conf_pages.show_all ();
			main_vbox.pack_end (conf_pages, true, true, 0);
		}

		private void build_menubar() {
			main_menu = new MenuBar ();

			// file
			Menu file_menu = new Menu ();
			MenuItem file_item = new MenuItem.with_label ("File");
			MenuItem new_conn_item = new MenuItem.with_label ("New connection");
			MenuItem rm_conn_item = new MenuItem.with_label ("Remove connection");
			MenuItem exit_item = new MenuItem.with_label ("Exit");
			file_menu.append (new_conn_item);
			file_menu.append (rm_conn_item);
			file_menu.append (new SeparatorMenuItem());
			file_menu.append (exit_item);

			rm_conn_item.activate.connect ((ev) => {
					int conn_id = conf_pages.get_current_page ();
					if (conn_id < 0) {
						Helper.debug (Helper.TAG_ERROR, "No active page");
						return;
					}
					else {
						Dialog confirm = new Dialog.with_buttons ("Connection removal", this, DialogFlags.MODAL);
						confirm.vbox.add (new Label ("This cannot be undone!"));
						confirm.add_button ("Yes, I'm sure", 0);
						confirm.add_button ("Abort", 1);
						confirm.vbox.show_all ();
						confirm.close.connect ((ev) => { confirm.destroy(); });
						confirm.response.connect ((ev, resp) => {
								if (resp == 1)
									confirm.destroy ();
								else {
									VDEConfiguration rem = conf_list.nth_data (conn_id);
									conf_holder.update_file (null, rem, true);
									conf_list.remove (rem);
									conf_pages.next_page ();
									conf_pages.remove_page (conn_id);
									confirm.destroy ();
								}
							});
						confirm.run ();
					}
				});


			new_conn_item.activate.connect ((ev) => {
					/* show a confirmation dialog when the user asks to create a new connection */
					Dialog new_conf_dialog = new Dialog.with_buttons ("New Configuration", this, DialogFlags.MODAL);
					Entry new_conf_entry = new Entry ();
					new_conf_entry.text = "change";
					new_conf_dialog.vbox.add (new Label ("New configuration ID"));
					new_conf_dialog.vbox.add (new_conf_entry);
					new_conf_dialog.add_button ("Create", 0);
					new_conf_dialog.add_button ("Abort", 1);
					new_conf_dialog.vbox.show_all ();
					new_conf_dialog.close.connect ((ev) => { new_conf_dialog.destroy(); });
					new_conf_dialog.response.connect ((ev, resp) => {
							if (resp == 0) {
								VDEConfiguration new_conf = new VDEConfiguration.with_defaults (new_conf_entry.text);
								conf_list.append (new_conf);
								add_notebook_page (new_conf);
								new_conf_dialog.destroy ();
							}
							else
								new_conf_dialog.destroy ();
						});
					new_conf_dialog.run ();
				});

			exit_item.activate.connect ((ev) => { Gtk.main_quit (); });
			file_item.submenu = file_menu;

			/* building help menu */
			Menu help_menu = new Menu ();
			MenuItem help_item = new MenuItem.with_label ("Help");
			MenuItem about_item = new MenuItem.with_label ("About");
			help_menu.append (about_item);

			about_item.activate.connect ((ev) => {
					AboutDialog about = new AboutDialog ();
					about.authors = {"Massimo Gengarelli"};
					about.copyright = "(C) 2011 Massimo Gengarelli";
					about.license = """VDE PN Manager -- VDE Private Network Manager
Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>

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
					about.program_name = Config.PACKAGE_NAME;
					about.version = Config.PACKAGE_VERSION;
					about.website = "http://git.casafamelica.info/vdepn.git";
					try {
						about.logo = new Gdk.Pixbuf.from_file (Helper.LOGO_PATH);
					}
					catch (Error e) {
						Helper.debug (Helper.TAG_ERROR, "Error while retrieving logo image");
					}
					about.close.connect ((ev) => { about.destroy(); });
					about.response.connect ((ev) => { about.destroy(); });
					about.run ();
				});

			help_item.submenu = help_menu;

			main_menu.append (file_item);
			main_menu.append (help_item);
		}

		private Button get_button(VDEConfiguration c, out bool status) {
			File pidfile = File.new_for_path ("/tmp/vdepn-" + c.connection_name + ".pid");
			if (pidfile.query_exists (null)) {
				connections_manager.new_connection_from_pid (c);
				status = true;
				return new Button.with_label ("Deactivate");
			}
			else {
				status = false;
				return new Button.with_label ("Activate");
			}
		}
	}


	// creates a new icon in the system tray, linked to the parent
	public class TrayIcon : Gtk.StatusIcon {
		private ConfigurationsList parent;
		private Manager.VDEConnector parent_connector;

		public TrayIcon (ConfigurationsList linked) {
			set_from_file (Helper.ICON_PATH);
			title = "VDE PN Manager";
			set_tooltip_text("VDE PN Manager");
			parent = linked;
			parent_connector = parent.connections_manager;
			activate.connect (() => {
					parent.visible = !parent.visible;
				});
		}

		public void show () {
			visible = true;
		}

		public void hide () {
			visible = false;
		}
	}
}

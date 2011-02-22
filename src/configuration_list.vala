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

namespace VDEPN {
	public class ConfigurationsList : Gtk.Window {
		private VBox main_vbox;
		private Notebook conf_pages;
		private MenuBar main_menu;
		private string prg_files = get_user_config_dir () + "/vdepn";
		private List<ConfigurationPage> pages_list;
		private AccelGroup accel_group;

		public Manager.VDEConnector connections_manager { get; private set; }
		public VDEParser conf_holder					{ get; private set; }
		public List<VDEConfiguration> conf_list;

		/* builds a new Gtk Window with caption as title */
		public ConfigurationsList (string caption) {
			accel_group = new AccelGroup ();
			build_menubar ();
			accel_group.lock ();

			add_accel_group (accel_group);

			main_vbox = new VBox (false, 2);
			conf_pages = new Notebook ();
			pages_list = new List<ConfigurationPage> ();

			connections_manager = new Manager.VDEConnector ();
			try {
				set_icon_from_file (Helper.ICON_PATH);
			}

			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, "Can't find " + Helper.ICON_PATH);
			}

			conf_pages.scrollable = true;
			title = caption;
			resize (200,200);
			this.delete_event.connect((ev) => {
					visible = false;;
					return true;
				});

			try {
				conf_holder = new VDEParser (prg_files + "/connections.xml");
			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, "Error while parsing XML file");
			}

			conf_list = conf_holder.get_configurations ();

			foreach (VDEConfiguration v in conf_list) {
				ConfigurationPage p = new ConfigurationPage (v, this);
				pages_list.append (p);
				conf_pages.append_page (p, new Label (v.connection_name));
			}

			main_vbox.pack_start (main_menu, false, true, 0);
			main_vbox.pack_end (conf_pages, true, true, 0);
			add (main_vbox);
			show_all ();
		}

		private void build_menubar () {
			main_menu = new MenuBar ();

			// file
			Menu file_menu = new Menu ();
			ImageMenuItem file_item = new ImageMenuItem.with_mnemonic (_("_File"));
			ImageMenuItem new_conn_item = new ImageMenuItem.from_stock (Gtk.STOCK_NEW, accel_group);
			ImageMenuItem save_conn_item = new ImageMenuItem.from_stock (Gtk.STOCK_SAVE, accel_group);
			ImageMenuItem rm_conn_item = new ImageMenuItem.from_stock (Gtk.STOCK_DELETE, accel_group);
			ImageMenuItem exit_item = new ImageMenuItem.from_stock (Gtk.STOCK_QUIT, accel_group);

			new_conn_item.add_accelerator ("activate", accel_group, (uint) 'n', Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
			save_conn_item.add_accelerator ("activate", accel_group, (uint) 's', Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
			rm_conn_item.add_accelerator ("activate", accel_group, (uint) 'd', Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
			exit_item.add_accelerator ("activate", accel_group, (uint) 'q', Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);

			file_item.set_accel_group (accel_group);
			new_conn_item.set_accel_group (accel_group);
			save_conn_item.set_accel_group (accel_group);
			rm_conn_item.set_accel_group (accel_group);
			exit_item.set_accel_group (accel_group);

			file_menu.append (new_conn_item);
			file_menu.append (save_conn_item);
			file_menu.append (rm_conn_item);
			file_menu.append (new SeparatorMenuItem ());
			file_menu.append (exit_item);

			save_conn_item.activate.connect ((ev) => {
					int conn_id = conf_pages.get_current_page ();
					if (conn_id < 0) {
						Helper.debug (Helper.TAG_ERROR, "No active page");
						return;
					}
					else {
						ConfigurationPage page = pages_list.nth_data (conn_id);
						page.config.update_configuration (page.socket_property.get_value (), page.remote_socket_property.get_value (),
														  page.machine_property.get_value (), page.machine_port_property.get_value (),
														  page.user_property.get_value (), page.ipaddr_property.get_value (),
														  page.pre_conn_cmds.get_value (), page.post_conn_cmds.get_value (),
														  page.button_checkhost.active, page.button_ssh.active);
						page.config.store_configuration (conf_holder);
					}
				});

			rm_conn_item.activate.connect ((ev) => {
					int conn_id = conf_pages.get_current_page ();
					if (conn_id < 0) {
						Helper.debug (Helper.TAG_ERROR, "No active page");
						return;
					}
					else {
						Dialog confirm = new Dialog.with_buttons (_("Connection removal"), this, DialogFlags.MODAL);
						confirm.vbox.add (new Label (_("This cannot be undone!")));
						confirm.add_button (_("Yes, I'm sure"), 0);
						confirm.add_button (_("Abort"), 1);
						confirm.vbox.show_all ();
						confirm.close.connect ((ev) => { confirm.destroy (); });
						confirm.response.connect ((ev, resp) => {
								if (resp == 1)
									confirm.destroy ();
								else {
									VDEConfiguration rem = conf_list.nth_data (conn_id);

									/* remove the configuration page too */
									foreach (ConfigurationPage page in pages_list) {
										if (page.config.connection_name == rem.connection_name)
											pages_list.remove (page);
									}

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
					Dialog new_conf_dialog = new Dialog.with_buttons (_("New Configuration"), this, DialogFlags.MODAL);
					Entry new_conf_entry = new Entry ();
					new_conf_entry.text = "change";

					/* no whitespaces allowed */
					new_conf_entry.changed.connect (() => {
							new_conf_entry.text = new_conf_entry.text.replace (" ", "-");
						});

					new_conf_dialog.vbox.add (new Label (_("New configuration ID")));
					new_conf_dialog.vbox.add (new_conf_entry);
					new_conf_dialog.add_button (_("Create"), 0);
					new_conf_dialog.add_button (_("Abort"), 1);
					new_conf_dialog.vbox.show_all ();
					new_conf_dialog.close.connect ((ev) => { new_conf_dialog.destroy(); });
					new_conf_dialog.response.connect ((ev, resp) => {
							if (resp == 0) {
								VDEConfiguration new_conf = new VDEConfiguration.with_defaults (new_conf_entry.text);
								ConfigurationPage p = new ConfigurationPage (new_conf, this);
								conf_list.append (new_conf);
								new_conf.store_configuration (conf_holder);
								conf_pages.append_page (p, new Label (new_conf.connection_name));
								conf_pages.show_all ();
								pages_list.append (p);
								new_conf_dialog.destroy ();
							}
							else
								new_conf_dialog.destroy ();
						});
					new_conf_dialog.run ();
				});

			exit_item.activate.connect ((ev) => {
					quit_application ();
				});
			file_item.submenu = file_menu;

			/* building help menu */
			Menu help_menu = new Menu ();
			ImageMenuItem help_item = new ImageMenuItem.with_mnemonic (_("_Help"));
			ImageMenuItem about_item = new ImageMenuItem.from_stock (Gtk.STOCK_ABOUT, accel_group);
			help_menu.append (about_item);

			about_item.add_accelerator ("activate", accel_group, (uint) 'h', Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
			about_item.set_accel_group (accel_group);

			about_item.activate.connect ((ev) => {
					AboutDialog about = new AboutDialog ();
					about.authors = {"Massimo Gengarelli <gengarel@cs.unibo.it>"};
					about.copyright = "(C) 2011 Massimo Gengarelli";
					about.license = Helper.LICENSE;
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


		public void switch_page (string conn_id) {
			foreach (VDEConfiguration v in conf_list) {
				if (v.connection_name == conn_id) {
					int index = conf_list.index (v);
					conf_pages.set_current_page (index);
				}
			}
		}

		/* If there are active connections, show a dialog warning the user */
		public void quit_application () {
			if (connections_manager.count_active_connections () > 0) {
				Dialog confirm = new Dialog.with_buttons (_("Active Connections"), this, DialogFlags.MODAL);
				confirm.vbox.add (new Label (_("There are active connections!")));
				confirm.add_button (_("Quit anyway"), 0);
				confirm.add_button (_("Cancel"), 1);
				confirm.vbox.show_all ();
				confirm.close.connect ((ev) => { confirm.destroy (); });
				confirm.response.connect ((ev, resp) => {
						if (resp == 1)
							confirm.destroy ();
						else {
							Gtk.main_quit ();
						}
					});

				confirm.run ();
			}
			else
				Gtk.main_quit ();
		}
	}


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

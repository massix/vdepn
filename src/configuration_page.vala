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
	/* Bubble notifications class */
	private class VNotification : Notify.Notification {
		private string conn_name;

		public VNotification (string conn_name) {
			/* chain up to the default Notification constructor */
			GLib.Object (summary: "VDE Private Network Manager",
						 body: "Body",
						 icon_name: Helper.ICON_PATH);
			this.conn_name = conn_name;
		}

		public void conn_active () {
			body = _("Connection ") + conn_name + _(" is now active");
			try {
				show ();
			}
			catch (GLib.Error e) {
				Helper.debug (Helper.TAG_ERROR, "Error while showing notifications: " + e.message);
			}
		}

		public void conn_inactive () {
			body = _("Connection ") + conn_name + _(" is now inactive");
			try {
				show ();
			}
			catch (GLib.Error e) {
				Helper.debug (Helper.TAG_ERROR, "Error while showing notifications: " + e.message);
			}
		}
	}

	/* ConfigurationPage, holds an HPaned formed by two VBoxes
	 * containing all the fields that are necessary to build up a new
	 * configuration */
	private class ConfigurationPage : Gtk.HPaned {
		private ConfigurationsList father;
		private VNotification notificator;
		private HBox checkbuttons_box;
		private HBox inner_buttons_box;
		private VBox left_pane;
		private VBox right_pane;
		private Spinner conn_spinner;
		private Button hide_right_pane_button;
		private Button activate_button;

		/* read-only properties (left part of the pane) */
		public ConfigurationProperty conn_name_property		{ get; private set; }
		public ConfigurationProperty machine_property		{ get; private set; }
		public ConfigurationProperty user_property			{ get; private set; }
		public ConfigurationProperty socket_property		{ get; private set; }
		public ConfigurationProperty remote_socket_property { get; private set; }
		public ConfigurationProperty ipaddr_property		{ get; private set; }
		public ConfigurationProperty machine_port_property	{ get; private set; }


		/* advanced properties (right part of the pane) */
		public ConfigurationProperty pre_conn_cmds			{ get; private set; }
		public ConfigurationProperty post_conn_cmds			{ get; private set; }

		public CheckButton button_ssh		{ get; private set; }
		public CheckButton button_checkhost { get; private set; }

		public VDEConfiguration config		{ get; private set; }
		public bool button_status			{ get; private set; }
		public int index					{ get; private set; }

		/* Builds a new Notebook Page */
		public ConfigurationPage (VDEConfiguration v, ConfigurationsList father) {
			/* chain up to the hpaned constructor */
			GLib.Object ();

			left_pane = new VBox (true, 0);
			right_pane = new VBox (false, 30);

			this.config = v;
			this.father = father;
			button_status = false;

			notificator = new VNotification (config.connection_name);

			index = father.conf_list.index (config);

			conn_name_property = new EntryProperty (_("Connection <b>name</b>:"), config.connection_name);
			conn_name_property.set_editable (false);

			machine_property = new EntryProperty (_("VDE <b>Machine</b>:"), config.machine);
			machine_port_property = new EntryProperty (_("VDE Machine <b>Port</b>:") , config.port);
			user_property = new EntryProperty (_("VDE <b>User</b>:") , config.user);
			socket_property = new EntryProperty (_("<b>Local</b> Socket Path:"), config.socket_path);
			remote_socket_property = new EntryProperty (_("<b>Remote</b> Socket Path:"), config.remote_socket_path);
			ipaddr_property = new EntryProperty (_("TUN/TAP <b>IPv4 Address</b>:"), config.ip_address);

			string value = (config.pre_conn_cmds != null) ? config.pre_conn_cmds : "whoami";
			pre_conn_cmds = new TextViewProperty (_("<b>Pre-connection</b> commands"), value);
			value = (config.post_conn_cmds != null) ? config.post_conn_cmds : "whoami";
			post_conn_cmds = new TextViewProperty (_("<b>Post-connection</b> commands"), value);

			checkbuttons_box = new HBox (true, 2);
			button_ssh = new CheckButton.with_label (_("Use SSH keys"));
			button_checkhost = new CheckButton.with_label (_("Check Host"));

			conn_spinner = new Spinner ();

			checkbuttons_box.pack_start (button_ssh, true, true, 0);
			checkbuttons_box.pack_start (button_checkhost, true, true, 0);

			button_ssh.active = config.use_keys;
			button_checkhost.active = config.checkhost;

			inner_buttons_box = new HBox (true, 4);
			hide_right_pane_button = new Button.with_label (_("Hide Advanced"));

			activate_button = get_button ();

			inner_buttons_box.pack_start (activate_button, true, true, 0);
			inner_buttons_box.pack_start (hide_right_pane_button, true, true, 0);

			/* left part of the pane */
			left_pane.pack_start ((Widget) conn_name_property, false, false, 0);
		 	left_pane.pack_start ((Widget) machine_property, false, false, 0);
			left_pane.pack_start ((Widget) machine_port_property, false, false, 0);
			left_pane.pack_start ((Widget) user_property, false, false, 0);
			left_pane.pack_start ((Widget) socket_property, false, false, 0);
			left_pane.pack_start ((Widget) remote_socket_property, false, false, 0);
			left_pane.pack_start ((Widget) ipaddr_property, false, false, 0);
			left_pane.pack_start (checkbuttons_box, false, false, 0);
			left_pane.pack_start (inner_buttons_box, false, false, 0);

			pack1 (left_pane, false, false);

			/* right part of the pane */
			right_pane.pack_start ((Widget) pre_conn_cmds, true, true, 0);
			right_pane.pack_start ((Widget) post_conn_cmds, true, true, 0);

			pack2 (right_pane, true, true);

			/* Signals */

			/* Hide and shows the right part of the paned */
			hide_right_pane_button.clicked.connect (() => {
					get_child2 ().visible = !get_child2 ().visible;
					hide_right_pane_button.label = get_child2 ().visible ? _("Hide Advanced") : _("Show Advanced");
				});


			/* tries to activate the connection, showing a fancy
			 * spinner while the Application works in background */
			activate_button.clicked.connect ((ev) => {
					left_pane.remove (inner_buttons_box);
					left_pane.pack_start (conn_spinner, true, true, 0);
					left_pane.show_all ();
					conn_spinner.start ();

					/* Avoid starting multiple threads accidentally */
					activate_button.sensitive = false;

					Thread.create<void*> (() => {
							config.update_configuration (socket_property.get_value (), remote_socket_property.get_value (),
														 machine_property.get_value (), machine_port_property.get_value (),
														 user_property.get_value (), ipaddr_property.get_value (),
														 pre_conn_cmds.get_value (), post_conn_cmds.get_value (),
														 button_checkhost.active, button_ssh.active);

							/* this actually activates the connection */
							if (button_status == false) {
								try {
									/* this may throws exceptions */
									father.connections_manager.new_connection (config);
									button_status = true;
									activate_button.label = _("Deactivate");
									notificator.conn_active ();

									Gdk.threads_enter ();
									/* Add a thread that checks if the given connection is still alive every 10 seconds */
									Timeout.add (Helper.TIMEOUT, () => { return check_if_alive (); });

									Gdk.threads_leave ();
								}

								/* woah.. something bad happened :( */
								catch (Manager.ConnectorError e) {
									Gdk.threads_enter ();
									Dialog error_dialog = new Dialog.with_buttons ("Error", father, DialogFlags.MODAL);
									Label err_label = new Label ("<b>" + e.message + "</b>");
									err_label.use_markup = true;
									error_dialog.vbox.add (new Label (_("Error while activating connection")));
									error_dialog.vbox.add (err_label);
									error_dialog.add_button (_("Close"), 0);
									error_dialog.vbox.show_all ();
									error_dialog.close.connect ((ev) => {
											error_dialog.destroy ();
										});
									error_dialog.response.connect ((ev, resp) => {
											error_dialog.destroy ();
										});

									error_dialog.run ();
									Gdk.threads_leave ();
								}
							}

							/* Deactivate the connection */
							else {
								button_status = false;
								activate_button.label = _("Activate");
								father.connections_manager.rm_connection (config.connection_name);
								notificator.conn_inactive ();
							}

							/* it's enough, I hate spinners. BURN'EM WITH FIRE */
							conn_spinner.stop ();
							Gdk.threads_enter ();
							left_pane.remove (conn_spinner);
							left_pane.pack_start (inner_buttons_box, false, false, 0);
							left_pane.show_all ();
							Gdk.threads_leave ();
							return null;
						}, false);

					/* Make the button sensible to signals again */
					activate_button.sensitive = true;
				});

			show_all ();
		}

		/* get the activate/deactivate button checking if the current
		 * connection is already active */
		private Button get_button () {
			File pidfile = File.new_for_path ("/tmp/vdepn-" + config.connection_name + ".pid");
			if (pidfile.query_exists (null)) {
				father.connections_manager.new_connection_from_pid (config);
				button_status = true;
				Timeout.add (Helper.TIMEOUT, () => { return check_if_alive (); });
				return new Button.with_label (_("Deactivate"));
			}
			else {
				button_status = false;
				return new Button.with_label (_("Activate"));
			}
		}

		/* A simple function that checks if a connection is still
		 * alive and, if the connection is no longer alive, it
		 * deactivates it */
		private bool check_if_alive () {
			Manager.VDEConnection to_be_checked = father.connections_manager.get_connection_from_name (config.connection_name);
			try {
				if (to_be_checked.is_alive () && button_status)
					return true;

				else {
					button_status = false;
					activate_button.label = _("Activate");
					father.connections_manager.rm_connection (config.connection_name);
					notificator.conn_inactive ();
					return false;
				}
			}

			/* The only exception  which may be thrown is  the one that tells us
			 * that the connection isn't found in the active connections pool,
			 * which means that the user has manually deactivated it */
			catch (Error e) {
				return false;
			}

		}
	}
}

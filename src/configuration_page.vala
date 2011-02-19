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
			body = "Connection " + conn_name + " is now active";
			try {
				show ();
			}
			catch (GLib.Error e) {
				Helper.debug (Helper.TAG_ERROR, "Error while showing notifications: " + e.message);
			}
		}

		public void conn_inactive () {
			body = "Connection " + conn_name + " is now inactive";
			try {
				show ();
			}
			catch (GLib.Error e) {
				Helper.debug (Helper.TAG_ERROR, "Error while showing notifications: " + e.message);
			}
		}
	}

	private class ConfigurationProperty : Gtk.HBox {
		private Entry entry_value;
		private Label label_value;
		public string curr_value {
			get {
				return entry_value.text;
			}

			private set {
				entry_value.text = value;
			}
		}

		public bool editable {
			get {
				return entry_value.editable;
			}

			set {
				entry_value.editable = value;
			}
		}

		public bool use_markup {
			get {
				return label_value.use_markup;
			}
			set {
				label_value.use_markup = value;
			}
		}

		public ConfigurationProperty (string label, string start_value) {
			GLib.Object (homogeneous: true, spacing: 10);

			entry_value = new Entry ();
			label_value = new Label (label);
			label_value.xalign = (float) 0;
			use_markup = true;

			curr_value = start_value;
			entry_value.changed.connect(() => {
					entry_value.text = entry_value.text.replace (" ", "-");
				});

			pack_start (label_value, true, true, 0);
			pack_start (entry_value, true, true, 16);
			show_all ();
		}
	}

	private class ConfigurationPage : Gtk.VBox {
		private ConfigurationsList father;
		private VNotification notificator;
		private HBox checkbuttons_box;
		private Spinner conn_spinner;

		/* read-only properties */
		public ConfigurationProperty conn_name_property		{ get; private set; }
		public ConfigurationProperty machine_property		{ get; private set; }
		public ConfigurationProperty user_property			{ get; private set; }
		public ConfigurationProperty socket_property		{ get; private set; }
		public ConfigurationProperty remote_socket_property { get; private set; }
		public ConfigurationProperty ipaddr_property		{ get; private set; }
		public CheckButton button_ssh		{ get; private set; }
		public CheckButton button_checkhost { get; private set; }

		public VDEConfiguration config		{ get; private set; }
		public bool button_status			{ get; private set; }
		public int index					{ get; private set; }

		/* Builds a new Notebook Page */
		public ConfigurationPage (VDEConfiguration v, ConfigurationsList father) {
			/* chain up to the vbox constructor */
			GLib.Object (homogeneous: true, spacing: 2);

			this.config = v;
			this.father = father;
			button_status = false;

			notificator = new VNotification (config.connection_name);

			index = father.conf_list.index (config);

			conn_name_property = new ConfigurationProperty ("Connection <b>name</b>:", config.connection_name);
			conn_name_property.editable = false;

			machine_property = new ConfigurationProperty ("VDE <b>Machine</b>:", config.machine);
			user_property = new ConfigurationProperty ("VDE <b>User</b>:" , config.user);
			socket_property = new ConfigurationProperty ("<b>Local</b> Socket Path:", config.socket_path);
			remote_socket_property = new ConfigurationProperty ("<b>Remote</b> Socket Path:", config.remote_socket_path);
			ipaddr_property = new ConfigurationProperty ("TUN/TAP <b>IPv4 Address</b>:", config.ip_address);

			checkbuttons_box = new HBox (true, 2);
			button_ssh = new CheckButton.with_label ("Use SSH keys");
			button_checkhost = new CheckButton.with_label ("Check Host");

			conn_spinner = new Spinner ();

			checkbuttons_box.pack_start (button_ssh);
			checkbuttons_box.pack_start (button_checkhost);

			button_ssh.active = config.use_keys;
			button_checkhost.active = config.checkhost;

			Button activate_connection = get_button ();

			pack_start (conn_name_property, false, false, 0);
			pack_start (machine_property, false, false, 0);
			pack_start (user_property, false, false, 0);
			pack_start (socket_property, false, false, 0);
			pack_start (remote_socket_property, false, false, 0);
			pack_start (ipaddr_property, false, false, 0);
			pack_start (checkbuttons_box);
			pack_start (conn_spinner);
			pack_start (activate_connection);

			/* tries to activate the connection, showing a fancy
			 * spinner while the Application works in background */
			activate_connection.clicked.connect ((ev) => {
					conn_spinner.start ();

					/* Avoid starting multiple threads accidentally */
					activate_connection.sensitive = false;

					Thread.create<void> (() => {
							/* this actually activates the connection */
							if (button_status == false) {
								try {
									config.update_configuration (socket_property.curr_value, remote_socket_property.curr_value,
																 machine_property.curr_value,
																 user_property.curr_value, ipaddr_property.curr_value,
																 button_checkhost.active, button_ssh.active);

									/* this may throws exceptions */
									father.connections_manager.new_connection (config);
									button_status = true;
									activate_connection.label = "Deactivate";
									notificator.conn_active ();
								}

								/* woah.. something bad happened :( */
								catch (Manager.ConnectorError e) {
									Gdk.threads_enter ();
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
											error_dialog.destroy ();
										});

									error_dialog.run ();
									Gdk.threads_leave ();
								}
							}

							/* Deactivate the connection */
							else {
								activate_connection.label = "Activate";
								father.connections_manager.rm_connection (config.connection_name);
								button_status = false;
								notificator.conn_inactive ();
							}

							/* it's enough, I hate spinners. BURN'EM WITH FIRE */
							conn_spinner.stop ();
						}, false);

					/* Make the button sensible to signals again */
					activate_connection.sensitive = true;
				});
		}

		/* get the activate/deactivate button checking if the current
		 * connection is already active */
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

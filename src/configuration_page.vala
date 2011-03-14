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
	/* ConfigurationPage, holds an HPaned formed by two VBoxes
	 * containing all the fields that are necessary to build up a new
	 * configuration */
	private class ConfigurationPage : Gtk.HBox {
		private Manager.VDEConnector connector;
		private HBox checkbuttons_box;
		private HBox inner_buttons_box;
		private VBox left_pane;
		private VBox right_pane;
		private Button manage_button;
		private Button activate_button;
		private ProgressBar progress_bar;

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

		/* Emitted signals */
		public signal void connection_start (Widget self, string conn_name);
		public signal void connection_successful (Widget self, string conn_name);
		public signal void connection_failed (Widget self, string conn_name, string message);
		public signal void connection_deactivated (Widget self, string conn_name);

		/* Builds a new Notebook Page */
		public ConfigurationPage (VDEConfiguration v, int index) {
			/* chain up to the hpaned constructor */
			GLib.Object (homogeneous: false, spacing: 15);

			left_pane = new VBox (false, 5);
			right_pane = new VBox (false, 30);
			progress_bar = new ProgressBar ();
			progress_bar.bar_style = Gtk.ProgressBarStyle.CONTINUOUS;
			progress_bar.ellipsize = Pango.EllipsizeMode.MIDDLE;

			this.config = v;
			this.connector = Manager.VDEConnector.get_instance ();
			button_status = false;

			this.index = index;

			conn_name_property = new EntryProperty (_("Connection <b>name</b>"), config.connection_name);
			conn_name_property.set_editable (false);

			machine_property = new EntryProperty (_("VDE <b>Machine</b>"), config.machine);
			machine_port_property = new EntryProperty (_("VDE Machine <b>Port</b>") , config.port);
			user_property = new EntryProperty (_("VDE <b>User</b>") , config.user);
			socket_property = new EntryProperty (_("<b>Local</b> Socket Path"), config.socket_path);
			remote_socket_property = new EntryProperty (_("<b>Remote</b> Socket Path"), config.remote_socket_path);
			ipaddr_property = new EntryProperty (_("TUN/TAP <b>IPv4 Address</b>"), config.ip_address);

			string value = (config.pre_conn_cmds != null) ? config.pre_conn_cmds : "whoami";
			pre_conn_cmds = new TextViewProperty (_("<b>Pre-connection</b> commands"), value);
			value = (config.post_conn_cmds != null) ? config.post_conn_cmds : "whoami";
			post_conn_cmds = new TextViewProperty (_("<b>Post-connection</b> commands"), value);

			checkbuttons_box = new HBox (true, 2);
			button_ssh = new CheckButton.with_label (_("Use SSH keys"));
			button_checkhost = new CheckButton.with_label (_("Check Host"));

			checkbuttons_box.pack_start (button_ssh, true, true, 0);
			checkbuttons_box.pack_start (button_checkhost, true, true, 0);

			button_ssh.active = config.use_keys;
			button_checkhost.active = config.checkhost;

			inner_buttons_box = new HBox (true, 4);
			manage_button = new Button.with_label (_("Manage Switch"));
			manage_button.sensitive = false;

			activate_button = get_button ();

			inner_buttons_box.pack_start (activate_button, true, true, 0);
			inner_buttons_box.pack_start (manage_button, true, true, 0);

			/* left part of the pane */
			left_pane.pack_start ((Widget) conn_name_property, false, false, 0);
		 	left_pane.pack_start ((Widget) machine_property, false, false, 0);
			left_pane.pack_start ((Widget) machine_port_property, false, false, 0);
			left_pane.pack_start ((Widget) user_property, false, false, 0);
			left_pane.pack_start ((Widget) socket_property, false, false, 0);
			left_pane.pack_start ((Widget) remote_socket_property, false, false, 0);
			left_pane.pack_start ((Widget) ipaddr_property, false, false, 0);
			left_pane.pack_start (checkbuttons_box, false, false, 0);
			/* This is used as an invisble widget to fill the empty space between the labels and the buttons */
			left_pane.pack_start (new Alignment (0, 0, 0, 0), true, false, 0);
			left_pane.pack_start (progress_bar, false, false, 0);
			left_pane.pack_start (inner_buttons_box, false, false, 0);

			pack_start (left_pane, false, false, 0);

			/* right part of the pane */
			right_pane.pack_start ((Widget) pre_conn_cmds, true, true, 0);
			right_pane.pack_start ((Widget) post_conn_cmds, true, true, 0);

			pack_start (right_pane, true, true, 0);

			/* tries to activate the connection, showing a fancy
			 * spinner while the Application works in background */
			activate_button.clicked.connect ((ev) => {
					/* Emit the first signal */
					this.connection_start (this, config.connection_name);

					/* Attach connector events to spin the progress_bar */
					connector.connection_step.connect (progress_bar_event_handler);


					/* Start the Connector instance in background */
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
									connector.new_connection (config);
									button_status = true;
									activate_button.label = _("Deactivate");
									/* Everything was fine, emit the successful signal */
									Gdk.threads_enter ();
									this.connection_successful (this, config.connection_name);
									manage_button.sensitive = Preferences.CustomPreferences.get_instance ().management_mode;
									connector.connection_step.disconnect (progress_bar_event_handler);
									Gdk.threads_leave ();
								}

								/* woah.. something bad happened :( */
								catch (Manager.ConnectorError e) {
									Gdk.threads_enter ();
									this.connection_failed (this, config.connection_name, e.message);
									Gdk.threads_leave ();
								}
							}

							/* Deactivate the connection */
							else {
								button_status = false;
								activate_button.label = _("Activate");
								connector.rm_connection (config.connection_name);
								Gdk.threads_enter ();
								this.connection_deactivated (this, config.connection_name);
								connector.connection_step.disconnect (progress_bar_event_handler);
								manage_button.sensitive = false;
								Gdk.threads_leave ();
							}

							return null;
						}, false);
				});

			/* Open up a terminal showing the unixterm for the switch */
			manage_button.clicked.connect (() => manage_connection ());

			show_all ();
		}

		/* Close the connection in a clean way */
		public void close_connection () {
			button_status = false;
			activate_button.label = _("Activate");
			connector.rm_connection (config.connection_name);
			this.connection_deactivated (this, config.connection_name);
			progress_bar_event_handler (null, 0, null);
			connector.connection_step.disconnect (progress_bar_event_handler);
			manage_button.sensitive = false;
		}

		/* Open up a terminal showing the unixterm for that switch */
		public void manage_connection () {
			string terminal = Preferences.CustomPreferences.get_instance ().terminal;
			Process.spawn_command_line_async (terminal + " -e 'unixterm " + socket_property.get_value () + ".mgmt'");
		}

		/* This is necessary to attach and detach connector signals */
		private void progress_bar_event_handler (Manager.VDEConnector sender, double step, string caption) {
			progress_bar.set_fraction (step);
			progress_bar.text = caption;
		}


		/* get the activate/deactivate button checking if the current
		 * connection is already active */
		private Button get_button () {
			File pidfile = File.new_for_path ("/tmp/vdepn-" + config.connection_name + ".pid");
			if (pidfile.query_exists (null)) {
				connector.new_connection_from_pid (config);
				button_status = true;
				this.connection_successful (this, config.connection_name);
				progress_bar_event_handler (null, 1, _("Done!"));
				manage_button.sensitive = Preferences.CustomPreferences.get_instance ().management_mode;
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
		public bool check_if_alive () {
			try {
				Manager.VDEConnection to_be_checked = connector.get_connection_from_name (config.connection_name);
				if (to_be_checked.is_alive () && button_status)
					return true;

				else {
					button_status = false;
					activate_button.label = _("Activate");
					connector.rm_connection (config.connection_name);
					this.connection_deactivated (this, config.connection_name);
					this.manage_button.sensitive = false;
					progress_bar_event_handler (null, 0, null);
					return false;
				}
			}

			/* The only exception  which may be thrown is  the one that tells us
			 * that the connection isn't found in the active connections pool,
			 * which means that the user has manually deactivated it */
			catch (Manager.ConnectorError e) {
				return false;
			}

		}
	}
}

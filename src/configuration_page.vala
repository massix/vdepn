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

	/* Common interface used by both the EntryProperty and the TextViewProperty */
	public interface ConfigurationProperty : GLib.Object {
		public abstract string get_value ();
		public abstract void set_editable (bool value);
		public abstract void set_markup (bool value);
	}

	/* A simple widget made of an Entry and a Label */
	private class EntryProperty : Gtk.HBox, ConfigurationProperty {
		private Entry entry_value;
		private Label label_value;

		/* Interface methods */
		public string get_value () {
			return entry_value.text;
		}

		public void set_editable (bool value) {
			entry_value.editable = value;
		}

		public void set_markup (bool value) {
			label_value.use_markup = value;
		}


		public EntryProperty (string label, string start_value) {
			GLib.Object (homogeneous: true, spacing: 0);

			entry_value = new Entry ();
			label_value = new Label (label);
			label_value.xalign = (float) 0;
			label_value.use_markup = true;

			entry_value.text = start_value;
			entry_value.changed.connect(() => {
					entry_value.text = entry_value.text.replace (" ", "-");
				});

			pack_start (label_value, true, true, 0);
			pack_start (entry_value, true, true, 0);
			show_all ();
		}
	}

	/* A simple widget made of a TextView and a Label */
	private class TextViewProperty : Gtk.VBox, ConfigurationProperty {
		private TextView text_view_entry;
		private Label description_label;
		private ScrolledWindow container;

		public TextViewProperty (string label, string initial_value) {
			GLib.Object (homogeneous: false, spacing: 0);

			/* Build up the objects */
			container = new ScrolledWindow (null, null);
			text_view_entry = new TextView ();
			TextBuffer tb = text_view_entry.get_buffer ();

			if ((initial_value != null) && (initial_value.chomp () != "")) {
				tb.set_text (initial_value, (int) initial_value.length);
				text_view_entry.set_buffer (tb);
			}
			else {
				tb.set_text ("", (int) 1);
				text_view_entry.set_buffer (tb);
			}

			description_label = new Label (label);
			description_label.use_markup = true;

			/* Pack them together */
			pack_start (description_label, false, false, 0);
			container.add (text_view_entry);

			container.hscrollbar_policy = PolicyType.AUTOMATIC;
			container.vscrollbar_policy = PolicyType.AUTOMATIC;

			text_view_entry.wrap_mode = Gtk.WrapMode.NONE;

			pack_start (container, true, true, 0);

			show_all ();
		}

		/* Interface methods */
		public string get_value () {
			TextBuffer tb;
			TextIter iter_start;
			TextIter iter_end;

			/* Obtain the text buffer */
			tb = text_view_entry.get_buffer ();

			tb.get_start_iter (out iter_start);
			tb.get_end_iter (out iter_end);

			return tb.get_text (iter_start, iter_end, false);
		}

		public void set_editable (bool value) {
			text_view_entry.editable = value;
		}

		public void set_markup (bool value) {
			description_label.use_markup = value;
		}

	}

	private class ConfigurationPage : Gtk.HPaned {
		private ConfigurationsList father;
		private VNotification notificator;
		private HBox checkbuttons_box;
		private VBox left_pane;
		private VBox right_pane;
		private Spinner conn_spinner;

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
			right_pane = new VBox (false, 0);

			this.config = v;
			this.father = father;
			button_status = false;

			notificator = new VNotification (config.connection_name);

			index = father.conf_list.index (config);

			conn_name_property = new EntryProperty ("Connection <b>name</b>:", config.connection_name);
			conn_name_property.set_editable (false);

			machine_property = new EntryProperty ("VDE <b>Machine</b>:", config.machine);
			machine_port_property = new EntryProperty ("VDE Machine <b>Port</b>:" , config.port);
			user_property = new EntryProperty ("VDE <b>User</b>:" , config.user);
			socket_property = new EntryProperty ("<b>Local</b> Socket Path:", config.socket_path);
			remote_socket_property = new EntryProperty ("<b>Remote</b> Socket Path:", config.remote_socket_path);
			ipaddr_property = new EntryProperty ("TUN/TAP <b>IPv4 Address</b>:", config.ip_address);

			string value = (config.pre_conn_cmds != null) ? config.pre_conn_cmds : "whoami";
			pre_conn_cmds = new TextViewProperty ("<b>Pre-connection</b> commands", value);
			value = (config.post_conn_cmds != null) ? config.post_conn_cmds : "whoami";
			post_conn_cmds = new TextViewProperty ("<b>Post-connection</b> commands", value);

			checkbuttons_box = new HBox (true, 2);
			button_ssh = new CheckButton.with_label ("Use SSH keys");
			button_checkhost = new CheckButton.with_label ("Check Host");

			conn_spinner = new Spinner ();

			checkbuttons_box.pack_start (button_ssh, true, true, 0);
			checkbuttons_box.pack_start (button_checkhost, true, true, 0);

			button_ssh.active = config.use_keys;
			button_checkhost.active = config.checkhost;

			Button activate_connection = get_button ();

			/* left part of the pane */
			left_pane.pack_start ((Widget) conn_name_property, false, false, 0);
		 	left_pane.pack_start ((Widget) machine_property, false, false, 0);
			left_pane.pack_start ((Widget) machine_port_property, false, false, 0);
			left_pane.pack_start ((Widget) user_property, false, false, 0);
			left_pane.pack_start ((Widget) socket_property, false, false, 0);
			left_pane.pack_start ((Widget) remote_socket_property, false, false, 0);
			left_pane.pack_start ((Widget) ipaddr_property, false, false, 0);
			left_pane.pack_start (checkbuttons_box, false, false, 0);
			left_pane.pack_start (activate_connection, false, false, 0);

			pack1 (left_pane, false, false);

			/* right part of the pane */
			right_pane.pack_start ((Widget) pre_conn_cmds, true, true, 0);
			right_pane.pack_start ((Widget) post_conn_cmds, true, true, 0);

			pack2 (right_pane, true, true);

			/* tries to activate the connection, showing a fancy
			 * spinner while the Application works in background */
			activate_connection.clicked.connect ((ev) => {
					left_pane.remove (activate_connection);
					left_pane.pack_start (conn_spinner, true, true, 0);
					show_all ();
					conn_spinner.start ();

					/* Avoid starting multiple threads accidentally */
					activate_connection.sensitive = false;

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
							left_pane.remove (conn_spinner);
							left_pane.pack_start (activate_connection, false, false, 0);
							show_all ();
							return null;
						}, false);

					/* Make the button sensible to signals again */
					activate_connection.sensitive = true;
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
				return new Button.with_label ("Deactivate");
			}
			else {
				button_status = false;
				return new Button.with_label ("Activate");
			}
		}
	}
}

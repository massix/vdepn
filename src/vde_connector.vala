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

namespace VDEPN.Manager
{
	public errordomain ConnectorError {
		COMMAND_NOT_FOUND,
		CONNECTION_FAILED
	}

	public class VDEConnector : GLib.Object {
		private List<VDEConnection> active_connections;

		public VDEConnector () {
			active_connections = new List<VDEConnection> ();
		}

		public bool new_connection_from_pid (VDEConfiguration conf) {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == conf.connection_name) {
					Helper.debug (Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			active_connections.append (new VDEConnection.from_pid_file (conf.connection_name));
			return true;
		}

		public bool new_connection (VDEConfiguration conf) throws ConnectorError {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == conf.connection_name) {
					Helper.debug (Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			VDEConnection new_one = new VDEConnection.with_path (conf);
			active_connections.append (new_one);
			return true;
		}

		public bool rm_connection (string id) {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == id) {
					if (c.destroy_connection ()) {
						active_connections.remove (c);
						return true;
					}
				}
			}

			Helper.debug (Helper.TAG_ERROR, "Connection not found in active connections list");
			return false;
		}

		public uint count_active_connections () {
			return active_connections.length ();
		}

		public VDEConnection get_connection (uint index) {
			return active_connections.nth_data (index);
		}
	}

	public class VDEConnection : GLib.Object {
		private VDEConfiguration configuration;
		public string conn_id { get; private set; }

		/* used while checking ssh host */
		private string check_host_stderr;
		private int ex_status;

		/* used internally */
		int vde_switch_pid;
		string vde_switch_cmd;
		string vde_plug_cmd;
		string dpipe_cmd;
		string pkexec_cmd;
		string pgrep_cmd;
		string ifconfig_cmd;

		public VDEConnection.from_pid_file(string conn_id) {
			try {
				string pidtmp;
				this.conn_id = conn_id;
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + conn_id + ".pid", out pidtmp);
				vde_switch_pid = pidtmp.to_int ();
			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
			}
		}

		/* creates a new connection at the given arguments, throwing
		 * an exception if it fails for some reason */
		public VDEConnection.with_path (VDEConfiguration conf) throws ConnectorError {
			configuration = conf;
			conn_id = conf.connection_name;

			try {
				string script;
				string temp_file;
				string result;

				GLib.FileUtils.open_tmp ("vdepn-XXXXXX.sh", out temp_file);
				GLib.FileUtils.chmod (temp_file, 0700);

				get_paths ();

				if ((vde_switch_cmd == null) ||
					(vde_plug_cmd == null) ||
					(dpipe_cmd == null))
					throw new ConnectorError.COMMAND_NOT_FOUND ("VDE not fully installed");

				if (pkexec_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND ("pkexec not found, root unavailable");

				if (pgrep_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND ("pgrep not found, can't kill the switches");

				if (ifconfig_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND ("ifconfig not found, can't set up interface");

				/* check wether the SSH host accepts us */
				if (configuration.checkhost && check_ssh_host ()) {
					if (ex_status > 0 || ex_status < 0)
						throw new ConnectorError.CONNECTION_FAILED (check_host_stderr);
				}

				string iface = "vdepn-" + conn_id;
				string remote_vde_plug_cmd = "vde_plug";
				if (configuration.remote_socket_path.chomp () != "")
					remote_vde_plug_cmd += " " + configuration.remote_socket_path.chomp ();


				script = "#!/bin/sh\n\n" +
					vde_switch_cmd + " -d -t " + iface + " -s " + configuration.socket_path + " || (echo VDEPNError && exit 255)\n" +
					pgrep_cmd + " -n vde_switch > /tmp/vdepn-" + conn_id + ".pid\n" +
					dpipe_cmd + " ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no " + configuration.user + "@"
					+ configuration.machine + " \"" + remote_vde_plug_cmd + "\" " +
					"= " + vde_plug_cmd + " " + configuration.socket_path + " &\n" +
					ifconfig_cmd + " " + iface + " " + configuration.ip_address + " up\n";

				GLib.FileUtils.set_contents (temp_file, script, -1);
				GLib.FileUtils.chmod (temp_file, 0700);
				string command = pkexec_cmd + " " + temp_file;
				Process.spawn_command_line_sync (command, out result, null, null);

				if (result != "")
					throw new ConnectorError.CONNECTION_FAILED ("Failed to activate connection");


				GLib.FileUtils.unlink (temp_file);
				string pidtmp;
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + conn_id + ".pid", out pidtmp, null);
				vde_switch_pid = pidtmp.to_int ();
			}

			/* throw the exception to the window who raised it so that
			 * a nice error dialog may be shown */
			catch (ConnectorError e) {
				throw e;
			}
			catch (GLib.Error e) {
				throw new ConnectorError.CONNECTION_FAILED (e.message);
			}
		}

		/* checks the exit status of a simple ssh connection to the
		 * given host */
		private bool check_ssh_host () throws GLib.Error {
			string command = "ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no -l " +
							 configuration.user + " " + configuration.machine + " exit";

			try {
				Process.spawn_command_line_sync (command, null, out check_host_stderr, out ex_status);
				return true;
			}

			catch (Error e) {
				return false;
			}
		}

		/* get the paths for the command i'll be using into the generated script */
		private void get_paths () {
			string command;
			string cmd_result;
			string[] tmp_split;

			try {
				command = "whereis vde_switch";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				vde_switch_cmd = tmp_split[1].chomp ();

				command = "whereis vde_plug";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				vde_plug_cmd = tmp_split[1].chomp ();

				command = "whereis dpipe";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				dpipe_cmd = tmp_split[1].chomp ();

				command = "whereis pkexec";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				pkexec_cmd = tmp_split[1].chomp ();

				command = "whereis pgrep";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				pgrep_cmd = tmp_split[1].chomp ();

				command = "whereis ifconfig";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				ifconfig_cmd = tmp_split[1].chomp ();
			}

			catch (GLib.SpawnError e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
			}
		}

		public bool destroy_connection () {
			try {
				string script;
				string temp_file;
				get_paths ();

				GLib.FileUtils.open_tmp ("kill-vdepn-XXXXXX.sh", out temp_file);

				script = "#!/bin/sh\n\n";
				script += "kill -9 " + vde_switch_pid.to_string () + "\n";
				script += "rm -f /tmp/vdepn-" + conn_id + ".pid\n";
				script += "rm -rf " + configuration.socket_path + "\n";

				GLib.FileUtils.set_contents (temp_file, script, -1);

				GLib.FileUtils.chmod (temp_file, 0700);

				Process.spawn_command_line_sync (pkexec_cmd + " " + temp_file, null, null, null);

				GLib.FileUtils.unlink (temp_file);

				return true;
			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
				return false;
			}
		}
	}
}

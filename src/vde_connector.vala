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

	public class VDEConnector : GLib.Object
	{
		private List<VDEConnection> active_connections;

		public VDEConnector() {
			active_connections = new List<VDEConnection>();
		}

		public bool new_connection_from_pid(VDEConfiguration conf) {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == conf.connection_name) {
					Helper.debug(Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			active_connections.append(new VDEConnection.from_pid_file(conf.connection_name));
			return true;
		}

		public bool new_connection(VDEConfiguration conf) throws ConnectorError {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == conf.connection_name) {
					Helper.debug(Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			try {
				VDEConnection new_one = new VDEConnection.with_path(conf.socket_path,
																	conf.connection_name,
																	conf.user,
																	conf.machine,
																	conf.ip_address);
				active_connections.append(new_one);
				return true;
			}
			catch (ConnectorError e) {
				throw e;
			}
		}

		public bool rm_connection(string id) {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == id) {
					if (c.destroy_connection()) {
						active_connections.remove(c);
						return true;
					}
				}
			}

			Helper.debug(Helper.TAG_ERROR, "Connection not found in active connections list");
			return false;
		}
	}

	public class VDEConnection : GLib.Object
	{
		public string conn_id { get; private set; }
		private string vde_switch_cmd;
		private string vde_switch_path;
		private string vde_plug_cmd;
		private string pgrep_cmd;
		private string pkexec_cmd;
		private string dpipe_cmd;
		private string ifconfig_cmd;
		private string iface;
		private string ip_addr;
		private int vde_switch_pid;

		public VDEConnection.from_pid_file(string conn_id) {
			try {
				string pidtmp;
				this.conn_id = conn_id;
				GLib.FileUtils.get_contents("/tmp/vdepn-" + conn_id + ".pid", out pidtmp);
				vde_switch_pid = pidtmp.to_int();
			}
			catch (Error e) {
				Helper.debug(Helper.TAG_ERROR, e.message);
			}
		}

		public VDEConnection.with_path(string path, string conn_id,
									   string user, string machine,
									   string ipaddr) throws ConnectorError {
			try {
				string script;
				string temp_file;

				GLib.FileUtils.open_tmp("vdepn-XXXXXX.sh", out temp_file);

				get_paths();

				if (
					(vde_switch_cmd == null) ||
					(vde_plug_cmd == null) ||
					(dpipe_cmd == null))
					throw new ConnectorError.COMMAND_NOT_FOUND("VDE not fully installed");

				if (pkexec_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND("pkexec not found, root unavailable");

				if (pgrep_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND("pgrep not found, can't kill the switches");

				if (ifconfig_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND("ifconfig not found, can't set up interface");

				vde_switch_path = path;
				this.conn_id = conn_id;
				this.ip_addr = ipaddr;
				iface = "vdepn-" + conn_id;

				script = "#!/bin/sh\n\n" +
					vde_switch_cmd + " -d -t " + iface + " -s " + path + "\n" +
					pgrep_cmd + " -n vde_switch > /tmp/vdepn-" + conn_id + ".pid\n" +
					dpipe_cmd + " ssh -o StrictHostKeyChecking=no " + user + "@" + machine + " vde_plug " +
					"= " + vde_plug_cmd + " " + path + " &\n" +
					ifconfig_cmd + " " + iface + " " + ipaddr + " up\n";

				GLib.FileUtils.set_contents(temp_file, script, -1);
				GLib.FileUtils.chmod(temp_file, 0700);
				string command = pkexec_cmd + " " + temp_file;
				Process.spawn_command_line_sync(command, null, null, null);

				GLib.FileUtils.unlink(temp_file);
				string pidtmp;
				GLib.FileUtils.get_contents("/tmp/vdepn-" + conn_id + ".pid", out pidtmp, null);
				vde_switch_pid = pidtmp.to_int();
			}
			catch (Error e) {
				Helper.debug(Helper.TAG_ERROR, e.message);
			}
		}

		private void get_paths() {
			string command;
			string cmd_result;
			string[] tmp_split;

			try {
				command = "whereis vde_switch";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(" ", 0);
				vde_switch_cmd = tmp_split[1].chomp();

				command = "whereis vde_plug";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(" ", 0);
				vde_plug_cmd = tmp_split[1].chomp();

				command = "whereis dpipe";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(" ", 0);
				dpipe_cmd = tmp_split[1].chomp();

				command = "whereis pkexec";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(" ", 0);
				pkexec_cmd = tmp_split[1].chomp();

				command = "whereis pgrep";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(" ", 0);
				pgrep_cmd = tmp_split[1].chomp();

				command = "whereis ifconfig";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(" ", 0);
				ifconfig_cmd = tmp_split[1].chomp();
			}

			catch (GLib.SpawnError e) {
				Helper.debug(Helper.TAG_ERROR, e.message);
			}
		}

		public bool destroy_connection() {
			try {
				string script;
				string temp_file;
				get_paths();

				GLib.FileUtils.open_tmp("kill-vdepn-XXXXXX.sh", out temp_file);

				script = "#!/bin/sh\n\n";
				script += "kill -9 " + vde_switch_pid.to_string() + "\n";
				script += "rm -f /tmp/vdepn-" + conn_id + ".pid\n";

				GLib.FileUtils.set_contents(temp_file, script, -1);

				GLib.FileUtils.chmod(temp_file, 0700);

				Process.spawn_command_line_sync(pkexec_cmd + " " + temp_file, null, null, null);

				GLib.FileUtils.unlink(temp_file);

				return true;
			}
			catch (Error e) {
				Helper.debug(Helper.TAG_ERROR, e.message);
				return false;
			}
		}
	}
}

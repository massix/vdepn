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

	public class VDEConnector
	{
		private List<VDEConnection> active_connections;

		public VDEConnector() {
			active_connections = new List<VDEConnection>();
		}

		public bool new_connection(string socket_path, string id) throws ConnectorError {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == id) {
					Helper.debug(Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			try {
				VDEConnection new_one = new VDEConnection.with_path(socket_path, id);
				Helper.debug(Helper.TAG_DEBUG, "Creating new connection");
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
					Helper.debug(Helper.TAG_DEBUG, "Removing Connection");
					c.destroy_connection();
					active_connections.remove(c);
					return true;
				}
			}

			Helper.debug(Helper.TAG_ERROR, "Connection wasn't alive");
			return false;
		}
	}

	public class VDEConnection
	{
		public string conn_id { get; private set; }
		private string vde_switch_cmd;
		private string vde_switch_path;
		private string vde_plug_cmd;
		private string dpipe_cmd;
		private string pidfile_path;
		private string iface;
		private string ip_addr;
		private int vde_switch_pid;

		public VDEConnection(string conn_id) throws ConnectorError {
			try {
				this.with_path("/tmp/unnamed", conn_id);
			}
			catch (ConnectorError e) {
				throw e;
			}
		}

		public VDEConnection.with_path(string path, string conn_id) throws ConnectorError {
			get_paths();
			if (
				(vde_switch_cmd == null) ||
				(vde_plug_cmd == null) ||
				(dpipe_cmd == null))
				throw new ConnectorError.COMMAND_NOT_FOUND("VDE not fully installed");

			vde_switch_path = path;
			this.conn_id = conn_id;
			iface = "vdepn-" + conn_id;
		}

		private void get_paths() {
			string command;
			string cmd_result;
			string[] tmp_split;

			try {
				command = "whereis vde_switch";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(": ", 0);
				vde_switch_cmd = tmp_split[1].chomp();

				command = "whereis vde_plug";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(": ", 0);
				vde_plug_cmd = tmp_split[1].chomp();

				command = "whereis dpipe";
				Process.spawn_command_line_sync(command, out cmd_result, null, null);
				tmp_split = cmd_result.split(": ", 0);
				dpipe_cmd = tmp_split[1].chomp();

				Helper.debug(Helper.TAG_DEBUG, "vde_switch is at " + vde_switch_cmd);
				Helper.debug(Helper.TAG_DEBUG, "vde_plug   is at " + vde_plug_cmd);
				Helper.debug(Helper.TAG_DEBUG, "dpipe      is at " + dpipe_cmd);
			}
			catch (GLib.SpawnError e) {
				Helper.debug(Helper.TAG_ERROR, e.message);
			}
		}

		public void destroy_connection() {
			Helper.debug(Helper.TAG_DEBUG, "Will do it soon..");
		}
	}
}

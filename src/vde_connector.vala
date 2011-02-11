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
	public class VDEConnector
	{
		private List<VDEConnection> active_connections;

		public VDEConnector() {
			 active_connections = new List<VDEConnection>();
		}

		public bool new_connection(string socket_path, string id) {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == id) {
					Helper.debug(Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			VDEConnection new_one = new VDEConnection.with_path(socket_path, id);
			Helper.debug(Helper.TAG_DEBUG, "Creating new connection");
			active_connections.append(new_one);
			return true;
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
		private int vde_switch_pid;

		public VDEConnection(string conn_id) {
			this.with_path("/tmp/unnamed", conn_id);
		}

		public VDEConnection.with_path(string path, string conn_id) {
			string command;
			string cmd_result;
			vde_switch_path = path;
			this.conn_id = conn_id;

			command = "whereis vde_switch";
			Process.spawn_command_line_sync(command, out cmd_result, null, null);
			string[] tmp_split = cmd_result.split(": ", 0);
			vde_switch_cmd = tmp_split[1].chomp();

			Helper.debug(Helper.TAG_DEBUG, vde_switch_cmd);
		}


		public void destroy_connection() {
			Helper.debug(Helper.TAG_DEBUG, "Will do it soon..");
		}
	}
}

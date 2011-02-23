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

namespace VDEPN.Manager {
	public errordomain ConnectorError {
		COMMAND_NOT_FOUND,
		CONNECTION_FAILED,
		CONNECTION_NOT_FOUND,
		DUPLICATE_CONNECTION
	}

	/* Main class, keeps track of all the active connections, creating
	 * and destroying them if necessary */
	public class VDEConnector : GLib.Object {
		private List<VDEConnection> active_connections;

		public VDEConnector () {
			active_connections = new List<VDEConnection> ();
		}

		/* Builds up a new connection using an existing PID file */
		public bool new_connection_from_pid (VDEConfiguration conf) {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == conf.connection_name) {
					Helper.debug (Helper.TAG_ERROR, "Connection is still alive");
					return false;
				}
			}

			active_connections.append (new VDEConnection.from_pid_file (conf));
			return true;
		}

		/* Builds up a new connection starting with an existing configuration */
		public void new_connection (VDEConfiguration conf) throws ConnectorError {
			try {
				VDEConnection should_not_exist = get_connection_from_name (conf.connection_name);
				/* If we arrive here, the connection already exists so we throw an exception */
				throw new ConnectorError.DUPLICATE_CONNECTION (_("Duplicate connection found in the pool of active connections"));
			}

			/* While if we are here, everything is right, since the connection isn't already in the pool */
			catch (ConnectorError e) {
				VDEConnection new_one = new VDEConnection (conf);
				active_connections.append (new_one);
			}
		}

		/* Removes an existing connection */
		public void rm_connection (string id) {
			VDEConnection to_be_removed = get_connection_from_name (id);
			to_be_removed.destroy_connection ();
			active_connections.remove (to_be_removed);

			/* The exception that may be thrown will be catched from
			 * the caller */
		}

		/* Returns the number of currently active connections */
		public uint count_active_connections () {
			return active_connections.length ();
		}

		/* Get the connection identified by its position into the list */
		public VDEConnection get_connection (uint index) {
			return active_connections.nth_data (index);
		}

		/* Get the connection identified by its name or throw an
		 * exception if the connection doesn't exist in the pool */
		public VDEConnection get_connection_from_name (string connection_id) throws ConnectorError {
			foreach (VDEConnection c in active_connections) {
				if (c.conn_id == connection_id)
					return c;
			}

			throw new ConnectorError.CONNECTION_NOT_FOUND (_("Connection not found in the active connections pool"));
		}
	}

	/* This is the class which executes the scripts used to connect,
	 * every VDEConnection keeps track of its name and its PID file
	 * (if everything went fine) */
	public class VDEConnection : GLib.Object {
		private VDEConfiguration configuration;
		public string conn_id {
			get {
				return configuration.connection_name;
			}

			private set {
				/* Do nothing */
			}
		}

		/* used while checking ssh host */
		private string check_host_stderr;
		private int ex_status;

		/* used internally */
		private int vde_switch_pid;
		private int ssh_pid;
		private string vde_switch_cmd;
		private string vde_plug2tap_cmd;
		private string vde_plug_cmd;
		private string dpipe_cmd;
		private string pkexec_cmd;
		private string pgrep_cmd;
		private string ifconfig_cmd;
		private string temp_file;

		/* The connection was already active, just take out the PIDs and create a new checker script */
		public VDEConnection.from_pid_file(VDEConfiguration conf) {
			try {
				string pidtmp;
				string checker_script;
				configuration = conf;
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + configuration.connection_name + ".pid", out pidtmp);
				vde_switch_pid = pidtmp.to_int ();
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + configuration.connection_name + "-ssh.pid", out pidtmp);
				ssh_pid = pidtmp.to_int ();

				/* Create the checker script */
				GLib.FileUtils.open_tmp ("vdepn-XXXXXX.sh", out temp_file);
				checker_script = "#!/bin/sh\n\n";
				checker_script += "[ $(ps aux | grep -c $(cat /tmp/vdepn-" + configuration.connection_name
								+ "-ssh.pid)) -gt 1 ] && echo alive || echo dead\n";
				GLib.FileUtils.set_contents (temp_file, checker_script, -1);
				GLib.FileUtils.chmod (temp_file, 0700);

			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
			}
		}

		/* creates a new connection with the given configuration,
		 * throwing an exception if it fails for some reason */
		public VDEConnection (VDEConfiguration conf) throws ConnectorError {
			configuration = conf;
			conn_id = conf.connection_name;

			try {
				string user_script;
				string root_script;
				string checker_script;
				string result;
				string pre_conn_cmds = replace_variables (conf.pre_conn_cmds);
				string post_conn_cmds = replace_variables (conf.post_conn_cmds);

				GLib.FileUtils.open_tmp ("vdepn-XXXXXX.sh", out temp_file);
				GLib.FileUtils.chmod (temp_file, 0700);

				get_paths ();

				if ((vde_switch_cmd == null) ||
					(vde_plug_cmd == null) ||
					(dpipe_cmd == null) ||
					(vde_plug2tap_cmd == null))
					throw new ConnectorError.COMMAND_NOT_FOUND (_("VDE not fully installed"));

				if (pkexec_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND (_("pkexec not found, root unavailable"));

				if (pgrep_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND (_("pgrep not found, can't kill the switches"));

				if (ifconfig_cmd == null)
					throw new ConnectorError.COMMAND_NOT_FOUND (_("ifconfig not found, can't set up interface"));

				/* check wether the SSH host accepts us */
				if (configuration.checkhost && check_ssh_host ()) {
					if (ex_status > 0 || ex_status < 0)
						throw new ConnectorError.CONNECTION_FAILED (check_host_stderr);
				}

				/* Build up the two vde_plug cmds (local and remote) */
				string remote_vde_plug_cmd = "vde_plug";
				if (configuration.remote_socket_path.chomp () != "")
					remote_vde_plug_cmd += " " + configuration.remote_socket_path.chomp ();

				string local_vde_plug_cmd = vde_plug_cmd + " " + configuration.socket_path;

				/* User part of the script */
				user_script = "#!/bin/sh\n\n";

				/* vde_switch creation */
				user_script += vde_switch_cmd + " -d -s " + configuration.socket_path + " || (echo VDESWITCHERROR && exit 255)\n";

				/* vde_switch pid acquiring */
				user_script += pgrep_cmd + " -n vde_switch > /tmp/vdepn-" + configuration.connection_name + ".pid\n";

				/* dpipe ssh connection (ssh args user@machine "vde_plug remote_sock_path" = vde_plug local_sock_path */
				string ssh_args = Helper.SSH_ARGS + " -p " + configuration.port;
				user_script += dpipe_cmd + " ssh " + ssh_args + " " + configuration.user + "@" + configuration.machine + " ";
				user_script += "\"" + remote_vde_plug_cmd + "\" ";
				user_script += "= " + local_vde_plug_cmd + " &\n";

				/* sleep 5 seconds after the connection to see if it fails or not */
				user_script += "sleep 5\n\n";

				/* ssh connection pid acquiring */
				user_script += pgrep_cmd + " -fn \"ssh " + ssh_args + " " + configuration.user +
					"@" + configuration.machine + "\" > /tmp/vdepn-" + configuration.connection_name + "-ssh.pid\n\n";

				/* vde_plug pid acquiring (or script failure) */
				user_script += pgrep_cmd + " -fn \"" +  local_vde_plug_cmd + "\" > /dev/null || echo VDEPLUGERROR\n\n";

				/* execute pre connection commands */
				user_script += pre_conn_cmds + "\n\n";


				/* Privileged (root) part of the script */
				root_script = "#!/bin/sh\n\n";

				/* vde_plug2tap */
				root_script += vde_plug2tap_cmd + " -s " + configuration.socket_path + " " + configuration.connection_name + " & \n";

				/* sleep for a while */
				root_script += "sleep 3\n\n";

				/* ifconfig up */
				root_script += ifconfig_cmd + " " + configuration.connection_name + " " + configuration.ip_address + " up\n";

				/* execute post connection commands */
				root_script += post_conn_cmds + "\n\n";

				/* Execute user script */
				GLib.FileUtils.set_contents (temp_file, user_script, -1);
				GLib.FileUtils.chmod (temp_file, 0700);
				Process.spawn_command_line_sync (temp_file, out result, null, null);

				/* Grab the vde_switch PID */
				string pidtmp;
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + configuration.connection_name + ".pid", out pidtmp, null);
				vde_switch_pid = pidtmp.to_int ();

				/* Grab the ssh PID */
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + configuration.connection_name + "-ssh.pid", out pidtmp, null);
				ssh_pid = pidtmp.to_int ();

				/* An error occured while creating the switch, there's no need to cleanup */
				if (result.chomp () == "VDESWITCHERROR") {
					GLib.FileUtils.remove (temp_file);
					throw new ConnectorError.CONNECTION_FAILED (_("Failure while creating the local switch"));
				}

				/* Error occured while plugging to the remote machine,
				 * clean the filesystem and return an error */
				else if (result.chomp () == "VDEPLUGERROR") {
					destroy_connection ();
					GLib.FileUtils.remove (temp_file);
					throw new ConnectorError.CONNECTION_FAILED (_("Failure, remote socket closed connection"));
				}

				/* Error occured while executing the user provided script, cleanup */
				else if (result.chomp () == "PCMDERROR") {
					destroy_connection ();
					GLib.FileUtils.remove (temp_file);
					throw new ConnectorError.CONNECTION_FAILED (_("Failure while executing the pre-connection commands"));
				}

				else {
					/* Everything went fine: execute root script */
					GLib.FileUtils.set_contents (temp_file, root_script, -1);
					GLib.FileUtils.chmod (temp_file, 0700);
					Process.spawn_command_line_sync (pkexec_cmd + " " + temp_file, null, null, null);
				}

				/* Create the checker script */
				checker_script = "#!/bin/sh\n\n";
				checker_script += "[ $(ps aux | grep -c $(cat /tmp/vdepn-" + configuration.connection_name
								+ "-ssh.pid)) -gt 1 ] && echo alive || echo dead\n";
				GLib.FileUtils.set_contents (temp_file, checker_script, -1);
				GLib.FileUtils.chmod (temp_file, 0700);

			}

			catch (GLib.Error e) {
				throw new ConnectorError.CONNECTION_FAILED (e.message);
			}
		}

		/* build up the pre_conn and post_conn cmds by substituting
		 * the default variables found with actual values:
		 * valid variables are:
		 *		- $IFACE	-> TUN/TAP Interface
		 *		- $LOCAL	-> Local Socket Path
		 *		- $REMOTE	-> Remote Socket Path
		 *		- $MACHINE	-> Remote Machine
		 *		- $USER		-> Connection User
		 * There are even two special variable which are
		 *		- $CHECK	-> Controls if the command is being executed
		 *		- $AND		-> Appends '&' to the command (which won't be possible due to XML entities)
		 */
		private string replace_variables (string initial_string) {
			return initial_string.replace ("$IFACE", configuration.connection_name)
				.replace ("$LOCAL", configuration.socket_path)
				.replace ("$REMOTE", configuration.remote_socket_path)
				.replace ("$MACHINE", configuration.machine)
				.replace ("$PORT", configuration.port)
				.replace ("$USER", configuration.user)
				.replace ("$IPADDR", configuration.ip_address)
				.replace ("$AND", "&")
				.replace ("$CHECK", "|| (echo PCMDERROR && exit 255)");
		}

		/* checks the exit status of a simple ssh connection to the
		 * given host */
		private bool check_ssh_host () throws GLib.Error {
			string ssh_args = Helper.SSH_ARGS + " -p " + configuration.port;
			string command = "ssh " + ssh_args + " " +
							 configuration.user + "@" + configuration.machine + " exit";

			try {
				Process.spawn_command_line_sync (command, null, out check_host_stderr, out ex_status);
				return true;
			}

			catch (Error e) {
				return false;
			}
		}

		/* get the paths for the command that will be used into the generated script */
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

				command = "whereis vde_plug2tap";
				Process.spawn_command_line_sync (command, out cmd_result, null, null);
				tmp_split = cmd_result.split (" ", 0);
				vde_plug2tap_cmd = tmp_split[1].chomp ();

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

		/* Destroy an existing connection, cleaning up the filesystem */
		/* FIXME: there's a probable race condition between this function and the
		 * timeout function that checks if a connection is still alive */
		public bool destroy_connection () {
			try {
				string script;

				script = "#!/bin/sh\n\n";
				/* Killing the vde_switch brings down every other process */
				script += "kill -9 " + vde_switch_pid.to_string () + "\n";

				/* Wait for the automatic cleaning to finish */
				script += "sleep 3\n";

				/* Remove PID file and socket (if retrieved) */
				script += "rm -f /tmp/vdepn-" + conn_id + "*.pid\n";
				if (configuration.socket_path != null && configuration.socket_path.chomp () != "")
					script += "rm -rf " + configuration.socket_path + "\n";

				GLib.FileUtils.set_contents (temp_file, script, -1);

				GLib.FileUtils.chmod (temp_file, 0700);

				Process.spawn_command_line_sync (temp_file, null, null, null);

				GLib.FileUtils.remove (temp_file);

				return true;
			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
				return false;
			}
		}

		/* Check if a connection is still alive by checking its ssh connection
		 * This can be done because after every successfully construction of a new object, a script
		 * is created in /tmp, and its only purpose is to check if the ssh connection is still alive */
		public bool is_alive () {
			string result;

			Process.spawn_command_line_sync (temp_file, out result, null, null);

			if (result.contains ("alive"))
				return true;
			else
				return false;
		}
	}
}

/* VDE PN Manager -- VDE Private Network Manager
 * Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>
 *                    - Vincenzo Ferrari   <ferrari@cs.unibo.it>
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

	/* Private set of Exceptions used by the try_root_execution () */
	private errordomain RootConnector {
		CONNECTION_SUCCESS,
		CONNECTION_FAILED
	}

	/* Main class, keeps track of all the active connections, creating
	 * and destroying them if necessary, this is a Singleton */
	public class VDEConnector : GLib.Object {
		private List<VDEConnection> active_connections;
		private static VDEConnector instance;

		/* Signals */
		public signal void connection_step (double step, string caption);

		private VDEConnector () {
			active_connections = new List<VDEConnection> ();
		}

		/* Get the active instance of the Connector */
		public static VDEConnector get_instance () {
			if (instance == null)
				instance = new VDEConnector ();

			return instance;
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

		/* Removes all existing connections */
		/* TODO:Check the exception */
		public void rm_all_connections () {
			foreach (VDEConnection to_be_removed in active_connections) {
				to_be_removed.destroy_connection ();
				active_connections.remove (to_be_removed);
			}
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
		private string vde_switch_cmd = Config.VDE_SWITCH_CMD;
		private string vde_plug2tap_cmd = Config.VDE_PLUG2TAP_CMD;
		private string vde_plug_cmd = Config.VDE_PLUG_CMD;
		private string dpipe_cmd = Config.DPIPE_CMD;
		private string pkexec_cmd = Config.PKEXEC_CMD;
		private string pgrep_cmd = Config.PGREP_CMD;
		private string ifconfig_cmd = Config.IFCONFIG_CMD;
		private string temp_file;

		/* Preferences instance */
		private Preferences.CustomPreferences preferences;

		/* The connection was already active, just take out the PIDs and create a new checker script */
		public VDEConnection.from_pid_file(VDEConfiguration conf) {
			preferences = Preferences.CustomPreferences.get_instance ();
			try {
				string pidtmp;
				string checker_script;
				configuration = conf;
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + configuration.connection_name + ".pid", out pidtmp);
				vde_switch_pid = pidtmp.to_int ();
				GLib.FileUtils.get_contents ("/tmp/vdepn-" + configuration.connection_name + "-ssh.pid", out pidtmp);
				ssh_pid = pidtmp.to_int ();
			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
			}
		}

		/* creates a new connection with the given configuration,
		 * throwing an exception if it fails for some reason */
		public VDEConnection (VDEConfiguration conf) throws ConnectorError {
			/* Used only to send signals */
			VDEConnector connector = VDEConnector.get_instance ();

			connector.connection_step (0.1, null);

			configuration = conf;
			conn_id = conf.connection_name;
			preferences = Preferences.CustomPreferences.get_instance ();

			try {
				string user_script;
				string root_script;
				string checker_script;
				string result;
				string vde_switch_pars;
				string pre_conn_cmds = replace_variables (conf.pre_conn_cmds);
				string post_conn_cmds = replace_variables (conf.post_conn_cmds);

				GLib.FileUtils.open_tmp ("vdepn-XXXXXX.sh", out temp_file);
				GLib.FileUtils.chmod (temp_file, 0700);


				/* check wether the SSH host accepts us */
				if (configuration.checkhost)
					connector.connection_step (0.3, _("Checking ssh host"));
				if (configuration.checkhost && check_ssh_host ()) {
					if (ex_status > 0 || ex_status < 0)
						throw new ConnectorError.CONNECTION_FAILED (check_host_stderr);
					connector.connection_step (0.4, _("Host accepted us!"));
				}

				connector.connection_step (0.5, _("Creating user script"));

				/* Build up the two vde_plug cmds (local and remote) */
				string remote_vde_plug_cmd = "vde_plug";
				if (configuration.remote_socket_path.chomp () != "")
					remote_vde_plug_cmd += " " + configuration.remote_socket_path.chomp ();

				string local_vde_plug_cmd = vde_plug_cmd + " " + configuration.socket_path;

				/* User part of the script */
				user_script = "#!/bin/sh\n\n";

				/* Options for vde_switch */
				vde_switch_pars = " -d -s " + configuration.socket_path;
				if (preferences.management_mode)
					vde_switch_pars +=  " -M " + configuration.socket_path + ".mgmt";

				vde_switch_pars += " ";

				/* vde_switch creation */
				user_script += vde_switch_cmd + vde_switch_pars + " || (echo VDESWITCHERROR && exit 255)\n";

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

				connector.connection_step (0.6, _("Creating root script"));

				/* Privileged (root) part of the script */
				root_script = "#!/bin/sh\n\n";

				/* vde_plug2tap */
				root_script += vde_plug2tap_cmd + " -s " + configuration.socket_path + " " + configuration.connection_name + " & \n";

				/* sleep for a while */
				root_script += "sleep 3\n\n";

				/* ifconfig up */
				root_script += ifconfig_cmd + " " + configuration.connection_name + " " + configuration.ip_address + " up\n";

				/* execute post connection commands */
				root_script += post_conn_cmds + "\n";

				/* safely exit from the subshell */
				root_script += "exit 0\n";

				connector.connection_step (0.7, _("Executing user script"));

				/* Execute user script */
				GLib.FileUtils.set_contents (temp_file, user_script, -1);
				GLib.FileUtils.chmod (temp_file, 0700);
				Process.spawn_command_line_sync (temp_file, out result, null, null);

				connector.connection_step (0.8, null);

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
					connector.connection_step (0.9, _("Executing root script"));
					GLib.FileUtils.set_contents (temp_file, root_script, -1);
					GLib.FileUtils.chmod (temp_file, 0700);
					try {
						try_root_execution (temp_file, preferences.root_method);
					}

					/* Connection successfull */
					catch (RootConnector.CONNECTION_SUCCESS e) {
						connector.connection_step (1, _("Done!"));
						return;
					}

					/* If we are here, something went wrong */
					catch (RootConnector.CONNECTION_FAILED e) {
						destroy_connection ();
						GLib.FileUtils.remove (temp_file);
						throw new ConnectorError.CONNECTION_FAILED (e.message);
					}
				}

				/* Hopefully, we should never get here.. */
				throw new ConnectorError.CONNECTION_FAILED (_("Something went wrong during execution of the scripts ") +
															_("close VDEPN and restart"));

			}

			catch (GLib.Error e) {
				throw new ConnectorError.CONNECTION_FAILED (e.message);
			}
		}


		/* This is a small helper function that tries to execute a
		 * script using the method provided as argument */
		private void try_root_execution (string file_path, Helper.RootGainer method) throws RootConnector {
			int exit_status = 127;
			switch (method) {
			case Helper.RootGainer.PKEXEC:
				string command;
				/* Get pkexec version */
				string version_cmd;
				string[] version;

				/* This will return something like 'pkexec version 0.96 */
				Process.spawn_command_line_sync (pkexec_cmd + " --version", out version_cmd, null, null);
				version = version_cmd.split (" ", 0);
				if ((float) version[2].to_double () > (float) 0.10)
					command = pkexec_cmd + " ";
				else
					command = pkexec_cmd + " --disable-internal-agent ";

				Helper.debug (Helper.TAG_DEBUG, "Trying pkexec with " + command);
				Process.spawn_command_line_sync (command + file_path, null, null, out exit_status);
				break;
			case Helper.RootGainer.SU:
				string root_pass_file = GLib.Environment.get_user_config_dir ()
					+ Helper.PROG_DATA_DIR + "/.rootpass";
				string command = "su -c '" + file_path + "' < " + root_pass_file;

				if (!File.new_for_path (root_pass_file).query_exists (null)) {
					/* Find a clean way to ask user for the root password */
				}
				else {
					string new_temp_file;
					Helper.debug (Helper.TAG_DEBUG, "Trying su with " + command);
					GLib.FileUtils.open_tmp ("vdepn-XXXXXX.sh", out new_temp_file);
					GLib.FileUtils.set_contents (new_temp_file, "#!/bin/sh\n" + command + "\n", -1);
					GLib.FileUtils.chmod (new_temp_file, 0700);
					Process.spawn_command_line_sync (new_temp_file, null, null, out exit_status);
					GLib.FileUtils.remove (new_temp_file);
				}

				break;
			case Helper.RootGainer.SUDO:
				throw new RootConnector.CONNECTION_FAILED (_("Authentication method not implemented yet"));
				break;
			default:
				break;
			}

			if (exit_status == 0)
				throw new RootConnector.CONNECTION_SUCCESS ("Connection successfull");
			else
				throw new RootConnector.CONNECTION_FAILED (_("Authentication failed"));
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


		/* Destroy an existing connection, cleaning up the filesystem */
		/* FIXME: there's a probable race condition between this function and the
		 * timeout function that checks if a connection is still alive */
		public bool destroy_connection () {
			/* Used to send signals */
			VDEConnector connector = VDEConnector.get_instance ();

			try {
				string script;

				connector.connection_step (0.7, _("Disconnecting"));

				/* if temporary file doesn't exist (we were invoked by the pid file) create a new one */
				if (!File.new_for_path (temp_file).query_exists (null))
					GLib.FileUtils.open_tmp ("vdepn-killer-XXXXXX.sh", out temp_file);

				script = "#!/bin/sh\n\n";

				/* Check if the vde_switch is still alive before killing it */
				if (File.new_for_path ("/proc/" + vde_switch_pid.to_string ()).query_exists (null)) {
					script += "kill -9 " + vde_switch_pid.to_string () + "\n";
				}

				/* Wait for the automatic cleaning to finish */
				script += "sleep 3\n";

				/* Remove PID file and socket (if retrieved) */
				script += "rm -f /tmp/vdepn-" + conn_id + "*.pid\n";
				if (configuration.socket_path != null && configuration.socket_path.chomp () != "")
					script += "rm -rf " + configuration.socket_path + "\n";

				/* Remove management socket */
				if (preferences.management_mode)
					script += "rm -rf " + configuration.socket_path + ".mgmt\n";

				GLib.FileUtils.set_contents (temp_file, script, -1);

				GLib.FileUtils.chmod (temp_file, 0700);

				connector.connection_step (0.3, _("Cleaning"));
				Process.spawn_command_line_sync (temp_file, null, null, null);

				GLib.FileUtils.remove (temp_file);

				connector.connection_step (0, null);

				return true;
			}
			catch (Error e) {
				Helper.debug (Helper.TAG_ERROR, e.message);
				return false;
			}
		}

		/* Check if a connection is still alive by checking its pid in /proc */
		public bool is_alive () {
			File pid_dir = File.new_for_path ("/proc/" + ssh_pid.to_string ());

			if (pid_dir.query_exists (null))
				return true;
			else
				return false;
		}
	}
}

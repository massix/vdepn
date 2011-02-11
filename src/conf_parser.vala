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

using Xml;
using Gtk;

namespace VDEPN
{
	public errordomain XMLError
	{
		FILE_NOT_FOUND,
		XML_PARSING_ERROR
	}

	public errordomain VDEConfigurationError
	{
		NULL_ID,
		NOT_ENOUGH_PARAMETERS,
		UNRECOGNIZED_OPTION,
		EMPTY_PASSWORD
	}

	public enum sock_type
	{
		PRIVATE, PUBLIC
	}

	protected class VDEConfiguration : GLib.Object
	{
		/* Read only properties */
		public string	connection_name { get; private set; }
		public string	socket_path { get; private set; }
		public string	user { get; private set; }
		public string	machine { get; private set; }
		public string	password { get; private set; }
		public string	iface { get; private set; }
		public string	ip_address { get; private set; }
		public bool		use_dhcp { get; private set; }
		public bool		use_keys { get; private set; }
		public bool		root_required { get; private set; }

		public VDEConfiguration.with_defaults(string conf_name) {
			connection_name = conf_name;
			socket_path = "/tmp/change-me";
			user = "change-me";
			machine = "change-me";
			password = "change-me";
			iface = "change-me";
			ip_address = "127.0.0.1";
			use_dhcp = false;
			use_keys = false;
			root_required = false;
		}

		protected VDEConfiguration(Xml.Node *conf_root) throws VDEConfigurationError {
			socket_path = null;
			Xml.Attr* id;
			/* parse node and create a configuration */
			//stdout.printf("Parsing configuration..\n");
			Helper.debug(Helper.TAG_DEBUG, "Parsing configuration");

			/* unique name for the connection */
			id = conf_root->has_prop("id");
			if (id != null)
				connection_name = id->children->get_content();
			else
				throw new VDEConfigurationError.NULL_ID("Connection ID can't be omitted");

			/* wether if requires root or not */
			if ((conf_root->has_prop("root")->children->get_content() == "true"))
				root_required = true;

			else
				root_required = false;

			while (conf_root->child_element_count() > 0) {
				Xml.Node *conf_node = conf_root->first_element_child();
				conf_node->unlink();
				switch (conf_node->name) {
				case "sockpath":
					socket_path = conf_node->get_content();
					break;
				case "ipaddress":
					Xml.Attr *dhcp;
					dhcp = conf_node->has_prop("dhcp");
					if ((dhcp != null) && (dhcp->children->get_content() == "true")) {
						ip_address = null;
						use_dhcp = true;
					}
					else {
						ip_address = conf_node->get_content();
						use_dhcp = false;
					}
					break;
				case "user":
					user = conf_node->get_content();
					break;
				case "machine":
					machine = conf_node->get_content();
					break;
				case "password":
					Xml.Attr *required;
					Xml.Attr *usekeys;
					required = conf_node->has_prop("required");
					usekeys = conf_node->has_prop("usekeys");
					if ((required != null) && (required->children->get_content() == "false")) {
						if ((usekeys != null) && (usekeys->children->get_content() == "true"))
							use_keys = true;

						else
							use_keys = false;

					}
					else
						password = conf_node->get_content();

					break;
				default:
					throw new VDEConfigurationError.UNRECOGNIZED_OPTION("Option not known");
				}

			}

			if (socket_path == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("field sockpath is missing");
			if (machine == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("field machine is missing");
			if (user == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("field user is missing");
			if (ip_address == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("ip address is missing");
			if ((password == null) && (use_keys == false))
				Helper.debug(Helper.TAG_WARNING, "configuration with empty password set");

			Helper.debug(Helper.TAG_DEBUG, "Configuration for " + connection_name + " saved");
		}

		public void update_configuration(string new_sock, string new_machine, string new_user,
										 string new_ip_address, bool new_root_required,
										 bool new_ssh_keys) {
			socket_path = new_sock;
			machine = new_machine;
			user = new_user;
			ip_address = new_ip_address;
			root_required = new_root_required;
			use_keys = new_ssh_keys;
		}

		/* Since in Vala there's no methods overloading, this function
		 * may look strange. It is responsible of converting an
		 * existing VDEConfiguration into an Xml NodeList and return
		 * it if was the VDEParser to ask it, or invoke the VDEParser
		 * returning null (in this way, the UI will call this function
		 * to start the updating of the configuration file, and then
		 * the Parser just takes the NodeList of each configuration it
		 * has)
		 */
		public Xml.Node* store_configuration(VDEParser? p) {
			Xml.Node *root_node = new Xml.Node(null, "connection");
			root_node->set_prop("id", connection_name);
			root_node->set_prop("root", root_required.to_string());

			Xml.Node *sock_path_node = new Xml.Node(null, "sockpath");
			sock_path_node->set_content(socket_path);

			Xml.Node *ipaddress_node = new Xml.Node(null, "ipaddress");
			ipaddress_node->set_prop("dhcp", "false");
			ipaddress_node->set_content(ip_address);

			Xml.Node *user_node = new Xml.Node(null, "user");
			user_node->set_content(user);

			Xml.Node *machine_node = new Xml.Node(null, "machine");
			machine_node->set_content(machine);

			Xml.Node *password_node = new Xml.Node(null, "password");
			password_node->set_prop("required", "false");
			password_node->set_prop("usekeys", "false");

			root_node->add_child(sock_path_node);
			root_node->add_child(ipaddress_node);
			root_node->add_child(user_node);
			root_node->add_child(machine_node);
			root_node->add_child(password_node);

			if (p != null) {
				p.update_file(root_node, this, false);
				return null;
			}
			else
				return root_node;

			Helper.debug(Helper.TAG_DEBUG, "Storing configuration");
		}
	}


	public class VDEParser : GLib.Object
	{
		private List<VDEConfiguration> configurations;
		private Doc *configuration_file;

		public VDEParser(string path) throws XMLError
		{
			Xml.Node *root_node;
			Xml.Node *connection_node;
			List<Xml.Node*> connection_node_list = new List<Xml.Node*>();
			configurations = new List<VDEConfiguration>();

			/* init XML parser */
			Parser.init();
			configuration_file = Parser.parse_file(path);
			root_node = configuration_file->get_root_element();

			while((connection_node = root_node->first_element_child()) != null) {
				connection_node = root_node->first_element_child();
				connection_node->unlink();
				connection_node_list.append(connection_node);
			}

			/* read it */
			/* foreach <connection> node */
			foreach (Xml.Node* n in connection_node_list) {
				try {
					configurations.append(new VDEConfiguration(n));
				}
				catch (GLib.Error e) {
					Helper.debug(Helper.TAG_ERROR, e.message);
				}
			}
		}

		public void update_file(Xml.Node *new_conn_root_node, VDEConfiguration v, bool rem_conf) {
			Doc new_conf = new Doc();
			int index = configurations.index(v);
			string conf_id;
			if (new_conn_root_node != null)
				conf_id = new_conn_root_node->has_prop("id")->children->content;
			else
				conf_id = "NONEXISTANTCONFIGURATION";

			Xml.Node *root_elem = new Xml.Node(null, "vdemanager");

			new_conf.set_root_element(root_elem);

			/* segfaults */
			if (new_conn_root_node != null)
				root_elem->add_child(new_conn_root_node);

			if (index < 0) {
				if (!rem_conf) {
					Helper.debug(Helper.TAG_DEBUG, "Appending new configuration to configurations list");
					configurations.append(v);
				}
				else
					Helper.debug(Helper.TAG_WARNING, "Configuration to be removed wasn't in the configurations list");
			}

			else {
				if (!rem_conf)
					Helper.debug(Helper.TAG_WARNING, "Configuration was already in the configurations list");
				else {
					Helper.debug(Helper.TAG_DEBUG, "Removing the configuration");
					configurations.remove(v);
				}
			}

			Helper.debug(Helper.TAG_DEBUG, "updating file");
			foreach (VDEConfiguration v_conf in configurations) {
				Xml.Node *conf_node = v_conf.store_configuration(null);
				if (!(conf_node->has_prop("id")->children->content == conf_id))
					root_elem->add_child(conf_node);
			}

			Helper.debug(Helper.TAG_DEBUG, "Creating new configuration");
			Helper.debug(Helper.TAG_DEBUG, "Storing " + Environment.get_user_config_dir() + Helper.XML_FILE);
			new_conf.save_file(Environment.get_user_config_dir() + Helper.XML_FILE);
		}

		public List<VDEConfiguration> get_configurations()
		{
			return configurations.copy();
		}
	}
}

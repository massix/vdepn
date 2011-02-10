/* vdepn - vde vpn manager
 *
 * Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>
 *
 * Classes for parsing the configuration file
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

	protected class VdeConfiguration : GLib.Object
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

		protected VdeConfiguration(Xml.Node *conf_root) throws VDEConfigurationError
		{
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
			if ((conf_root->has_prop("root")->children->get_content() == "yes"))
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
					if ((dhcp != null) && (dhcp->children->get_content() == "yes")) {
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
					if ((required != null) && (required->children->get_content() == "no")) {
						if ((usekeys != null) && (usekeys->children->get_content() == "yes")) 
							use_keys = true;
						
						else 
							use_keys = false;
						
					}
					else 
						password = conf_node->get_content();
					
					break;
				default:
					throw new VDEConfigurationError.UNRECOGNIZED_OPTION("Option not known");
					break;
				}

			}
			
			if (socket_path == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("field sockpath is missing");
			if (machine == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("field machine is missing");
			if (user == null)
				throw new VDEConfigurationError.NOT_ENOUGH_PARAMETERS("field user is missing");
			if ((password == null) && (use_keys == false))
				Helper.debug(Helper.TAG_WARNING, "configuration with empty password set");

			Helper.debug(Helper.TAG_DEBUG, "Configuration for " + connection_name + " saved");
		}
	}


	public class VdeParser : GLib.Object
	{
		private List<VdeConfiguration> configurations;
		private Doc *configuration_file;

		public VdeParser(string path) throws XMLError
		{
			Xml.Node *root_node;
			Xml.Node *connection_node;
			List<Xml.Node*> connection_node_list = new List<Xml.Node*>();
			configurations = new List<VdeConfiguration>();

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
					configurations.append(new VdeConfiguration(n));
				}
				catch (GLib.Error e) {
					Helper.debug(Helper.TAG_ERROR, e.message);
				}
			}
		}

		public List<VdeConfiguration> get_configurations()
		{
			return configurations.copy();
		}
	}
}

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

namespace VDEPN.Preferences {
	/* This class is a Singleton, which means that there could be only one active instance at a time */
	public class CustomPreferences : GLib.Object {
		private static CustomPreferences instance;

		/* Various preferences */
		public Helper.RootGainer root_method { get; set; }

		/* Parse the preferences for the first time */
		private CustomPreferences () {
			Doc xml_file_doc = new Doc ();
			string xml_file_path = GLib.Environment.get_user_config_dir () + Helper.XML_PREF_FILE;
			Xml.Node *root_node;
			Xml.Node *pref_node;

			/* Load the file */
			xml_file_doc = Parser.parse_file (xml_file_path);
			root_node = xml_file_doc.get_root_element ();

			while((pref_node = root_node->first_element_child ()) != null) {
				pref_node = root_node->first_element_child ();
				pref_node->unlink ();
				switch (pref_node->name) {
				case "rootmethod":
					Helper.debug (Helper.TAG_DEBUG, "[Preferences] Root Method: " + pref_node->get_content ());

					/* Can't use switch-case in non-constant variables :( */
					if (pref_node->get_content () == Helper.RootGainer.PKEXEC.to_string ())
						root_method = Helper.RootGainer.PKEXEC;
					else if (pref_node->get_content () == Helper.RootGainer.SU.to_string ())
						root_method = Helper.RootGainer.SU;
					else if (pref_node->get_content () == Helper.RootGainer.SUDO.to_string ())
						root_method = Helper.RootGainer.SUDO;
					/* Defaults to PKEXEC */
					else
						root_method = Helper.RootGainer.PKEXEC;

					break;
				default:
					Helper.debug (Helper.TAG_ERROR, "[Preferences] Unrecognized element " + pref_node->name);
					break;
				}
			}
		}

		/* Get the Singleton instance of the object or create a new one if it doesn't exist */
		public static CustomPreferences get_instance () {
			if (instance == null)
				instance = new CustomPreferences ();

			return instance;
		}

		/* Show the preferences pane */
		public void show_pane (Gtk.Window father) {
			PreferencesPane pane = new PreferencesPane (instance, father);

			pane.run ();
			pane.destroy ();
		}

		/* Stores ~/.config/vdepn/preferences.xml with the new preferences */
		public void save_file () {
			Doc new_preferences = new Doc ();
			Xml.Node *root_node = new Xml.Node (null, "vdepreferences");
			new_preferences.set_root_element (root_node);

			/* Root method */
			Xml.Node *root_method_node = new Xml.Node (null, "rootmethod");
			root_method_node->set_content (root_method.to_string ());

			/* Create the DOM */
			root_node->add_child (root_method_node);

			/* Store it */
			new_preferences.save_file (Environment.get_user_config_dir () + Helper.XML_PREF_FILE);
		}
	}

	/* This is the actual dialog which shows up the preferences and let the user modify'em */
	private class PreferencesPane : Gtk.Dialog {
		private Frame root_method_container;
		private unowned SList<RadioButton> root_method_list;
		private VBox radio_buttons_container;
		private RadioButton radio_pkexec;
		private RadioButton radio_su;
		private RadioButton radio_sudo;

		private enum Response {
			SAVE,
			CLOSE_NO_SAVE,
			SESSION_ONLY
		}

		public PreferencesPane (CustomPreferences instance, Gtk.Window father) {
			set_title (_("Preferences"));
			set_modal (true);
			set_transient_for (father);

			/* Instanciate the GUI objects we'll be using */
			root_method_container = new Frame (_("Preferred method to gain root"));
			radio_buttons_container = new VBox (false, 2);

			/* Create the radio buttons */
			radio_pkexec = new RadioButton.with_label (null, _("Use pkexec to authenticate"));
			radio_sudo = new RadioButton.with_label_from_widget (radio_pkexec, _("Use sudo to authenticate"));
			radio_su = new RadioButton.with_label_from_widget (radio_sudo, _("Use su to authenticate"));

			/* Set the loaded root method as active */
			switch (instance.root_method) {
				case Helper.RootGainer.PKEXEC:
					radio_pkexec.set_active (true);
				break;
				case Helper.RootGainer.SUDO:
					radio_sudo.set_active (true);
				break;
				case Helper.RootGainer.SU:
					radio_su.set_active (true);
				break;
			}

			/* Pack the buttons in a fancy vertical way */
			radio_buttons_container.pack_start (radio_pkexec, true, true, 0);
			radio_buttons_container.pack_end (radio_sudo, true, true, 0);
			radio_buttons_container.pack_end (radio_su, true, true, 0);

			/* Pack the VBOX inside the frame */
			root_method_container.add (radio_buttons_container);

			/* Pack the Frame into the Dialog's vbox */
			vbox.add (root_method_container);

			/* Add three action buttons to the dialog */
			add_buttons (_("Save preferences"), Response.SAVE,
						 _("Save for this session"), Response.SESSION_ONLY,
						 _("Close without saving"), Response.CLOSE_NO_SAVE);

			/* Attach response signal */
			response.connect ((resp) => {
					switch (resp) {
						case Response.SAVE:
							instance.root_method = get_method_from_list (radio_pkexec.get_group ());
							instance.save_file ();
						break;
						case Response.CLOSE_NO_SAVE:
							/* Do nothing */
						break;
						case Response.SESSION_ONLY:
							instance.root_method = get_method_from_list (radio_pkexec.get_group ());
						break;
						default:
							/* Do nothing */
						break;
					}
				});

			show_all ();
		}

		/* Get the RootGainer method selected from the user in the RadioButtons */
		private Helper.RootGainer get_method_from_list (SList<RadioButton> rb_list) {
			foreach (RadioButton b in rb_list) {
				if (b.active) {
					if (b == radio_pkexec)
						return Helper.RootGainer.PKEXEC;
					else if (b == radio_sudo)
						return Helper.RootGainer.SUDO;
					else if (b == radio_su)
						return Helper.RootGainer.SU;
					/* Defaults to PKEXEC */
					else
						return Helper.RootGainer.PKEXEC;
				}
			}

			return Helper.RootGainer.PKEXEC;
		}
	}
}

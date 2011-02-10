/* vdepn - vde vpn manager
 *
 * Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>
 *
 * MainWindow class
 */

using Gtk;

namespace VDEPN
{
	public class ConfigurationsList : Gtk.Window
	{
		private VBox conf_box;
		private VdeParser conf_holder;
		private List<VdeConfiguration> conf_list;

		
		public ConfigurationsList(string caption)
		{
			conf_box = new VBox(true, 2);
			title = caption;
			resize(200,200);
			this.delete_event.connect(
				(a) => {
					Gtk.main_quit();
					stdout.printf("delete event");
					return true;
				});

			conf_holder = new VdeParser("./vdepn.xml");
			conf_list = conf_holder.get_configurations();

			foreach (VdeConfiguration v in conf_list) {
				HBox conf_hbox = new HBox(true, 4);
				Label conf_label = new Label(v.connection_name);
				conf_hbox.pack_start(new Label("Configuration"));
				conf_hbox.pack_end(conf_label);
				conf_box.pack_end(conf_hbox);
			}

			add(conf_box);
			show_all();
		}

		public static void main(string[] args) {
			Gtk.init(ref args);		
			ConfigurationsList mainWindow = new ConfigurationsList("This is a test");			
			Gtk.main();
		}
	}
}
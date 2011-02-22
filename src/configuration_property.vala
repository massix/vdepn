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

using Gtk;
using Notify;
using GLib.Environment;

namespace VDEPN {
	/* Common interface used by both the EntryProperty and the TextViewProperty */
	public interface ConfigurationProperty : GLib.Object {
		public abstract string get_value ();
		public abstract void set_editable (bool value);
		public abstract void set_markup (bool value);
	}

	/* A simple widget made of an Entry and a Label */
	private class EntryProperty : Gtk.HBox, ConfigurationProperty {
		private Entry entry_value;
		private Label label_value;

		/* Interface methods */
		public string get_value () {
			return entry_value.text;
		}

		public void set_editable (bool value) {
			entry_value.editable = value;
		}

		public void set_markup (bool value) {
			label_value.use_markup = value;
		}


		public EntryProperty (string label, string start_value) {
			GLib.Object (homogeneous: true, spacing: 0);

			entry_value = new Entry ();
			label_value = new Label (label);
			label_value.xalign = (float) 0;
			label_value.use_markup = true;

			entry_value.text = start_value;
			entry_value.changed.connect(() => {
					entry_value.text = entry_value.text.replace (" ", "-");
				});

			pack_start (label_value, true, true, 0);
			pack_start (entry_value, true, true, 0);
			show_all ();
		}
	}

	/* A simple widget made of a TextView and a Label */
	private class TextViewProperty : Gtk.VBox, ConfigurationProperty {
		private TextView text_view_entry;
		private Label description_label;
		private ScrolledWindow container;

		public TextViewProperty (string label, string initial_value) {
			GLib.Object (homogeneous: false, spacing: 0);

			/* Build up the objects */
			container = new ScrolledWindow (null, null);
			text_view_entry = new TextView ();
			TextBuffer tb = text_view_entry.get_buffer ();

			if ((initial_value != null) && (initial_value.chomp () != "")) {
				tb.set_text (initial_value, (int) initial_value.length);
				text_view_entry.set_buffer (tb);
			}
			else {
				tb.set_text ("", (int) 1);
				text_view_entry.set_buffer (tb);
			}

			description_label = new Label (label);
			description_label.use_markup = true;

			/* Pack them together */
			pack_start (description_label, false, false, 0);
			container.add (text_view_entry);

			/* Graphical changes */
			container.hscrollbar_policy = PolicyType.AUTOMATIC;
			container.vscrollbar_policy = PolicyType.AUTOMATIC;
			container.set_shadow_type (Gtk.ShadowType.ETCHED_OUT);
			text_view_entry.left_margin = text_view_entry.right_margin = 4;

			text_view_entry.wrap_mode = Gtk.WrapMode.NONE;

			pack_start (container, true, true, 0);

			show_all ();
		}

		/* Interface methods */
		public string get_value () {
			TextBuffer tb;
			TextIter iter_start;
			TextIter iter_end;

			/* Obtain the text buffer */
			tb = text_view_entry.get_buffer ();

			tb.get_start_iter (out iter_start);
			tb.get_end_iter (out iter_end);

			return tb.get_text (iter_start, iter_end, false);
		}

		public void set_editable (bool value) {
			text_view_entry.editable = value;
		}

		public void set_markup (bool value) {
			description_label.use_markup = value;
		}

	}
}

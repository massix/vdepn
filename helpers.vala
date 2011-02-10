/* vdepn - vde vpn manager
 *
 * Copyright (C) 2011 - Massimo Gengarelli <gengarel@cs.unibo.it>
 *
 * Helper class
 */

namespace VDEPN {
	public class Helper : GLib.Object
	{
		public const string TAG_DEBUG = "DEBUG";
		public const string TAG_ERROR = "ERROR";
		public const string TAG_WARNING = "WARNING";
		
		public static void debug(string tag, string message)
		{
			stdout.printf("[%s] %s\n", tag, message);
		}
	}
}
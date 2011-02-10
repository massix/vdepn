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

namespace VDEPN.Connector
{
	public static bool create_vde_switch(string path) {
		// testing out processes
		string[] test = {"/bin/echo", path, null};
		Pid test_pid;
		Helper.debug(Helper.TAG_DEBUG, "Spawning a test process");
		Process.spawn_async(null, test, null, SpawnFlags.DO_NOT_REAP_CHILD, null, out test_pid);
		return true;
	}
}

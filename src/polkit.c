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

#include <glib.h>
#include <stdlib.h>
#include <string.h>
#include <gio/gio.h>
#include <gtk/gtk.h>
#include <polkit/polkit.h>
#include <polkitgtk/polkitgtk.h>
#include <config.h>

static PolkitAuthority *vdepn_authority;
static PolkitSubject *vdepn_subject;
static gint vdepn_application_pid;

/* we'll be using the default pkexec */
static const gchar* action = "org.freedesktop.policykit.exec";

static void vdepn_polkit_wrapper_exec_command();

static void *vdepn_polkit_wrapper_g_callback(GObject *o, GAsyncResult *r, gpointer u_data)
{
  PolkitAuthorizationResult *result;
  GError *error = NULL;
  const gchar *auth_result;
  GString *cmd_result;

  result = polkit_authority_check_authorization_finish(o, r, &error);

  if (error != NULL) {
	g_print("[WRAPPER_ERROR] %s\n", error->message);
	return;
  }
  else {
	if (polkit_authorization_result_get_is_authorized(result)) {
	  auth_result = "Authorized";
	}
	else
	  auth_result = "Unauthorized";
  }

  vdepn_polkit_wrapper_exec_command();
}

static void vdepn_polkit_wrapper_exec_command()
{
  gchar *cmd_result;
  g_spawn_command_line_sync("id", &cmd_result, NULL, NULL, NULL);
  g_print("[WRAPPER_LOG] %s\n", cmd_result);
}

static gboolean vdepn_polkit_wrapper_init_subject()
{
  GError **errno;
  vdepn_subject = polkit_unix_process_new(vdepn_application_pid);
  return !(vdepn_subject == NULL);
}

GtkFrame *vdepn_polkit_wrapper_get_new_frame(const gchar *label)
{
  struct {
	GtkFrame *container;
	GtkVBox *vbox;
	GtkLabel *label;
	PolkitLockButton *pk_lock;
  } _my_frame;

  _my_frame.container = gtk_frame_new(label);
  _my_frame.pk_lock = polkit_lock_button_new(action);
  _my_frame.vbox = gtk_vbox_new(1, FALSE);
  _my_frame.label = gtk_label_new("Click down here to <b>unlock</b> buttons");
  _my_frame.label->use_markup = TRUE;

  gtk_container_add((GtkContainer *) _my_frame.vbox, (GtkWidget *) _my_frame.label);
  gtk_container_add((GtkContainer *) _my_frame.vbox, (GtkWidget *) _my_frame.pk_lock);

  gtk_container_add((GtkContainer *) _my_frame.container, (GtkWidget *) _my_frame.vbox);

  gtk_widget_show_all((GtkWidget *) _my_frame.container);

  // the inner objects are already referenced
  g_object_ref_sink(_my_frame.container);

  return ((GtkFrame *) _my_frame.container);
}

gint vdepn_polkit_wrapper_get_pid_from_subject()
{
  if (vdepn_subject != NULL)
	return (polkit_unix_process_get_pid(vdepn_subject));
  else
	return -1;
}

gboolean vdepn_polkit_wrapper_init_wrapper()
{
  vdepn_application_pid = getpid();

  if (vdepn_application_pid <= 1)
	return FALSE;
  if (vdepn_polkit_wrapper_init_subject())
	vdepn_authority = polkit_authority_get_sync(NULL, NULL);
  else
	return FALSE;

  return !(vdepn_authority == NULL);
}

gboolean vdepn_polkit_wrapper_get_authorization(const gchar *local_action)
{
  PolkitDetails *command_details;
  command_details = polkit_details_new();
  polkit_details_insert(command_details, "path", local_action);

  gchar *command = g_strconcat(action, " ", local_action, NULL);
  g_print("[WRAPPER_DEBUG] Requested action: %s\n", command);

  polkit_authority_check_authorization(vdepn_authority,
									   vdepn_subject,
									   action,
									   command_details, /* command details */
									   POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
									   NULL,
									   (GAsyncReadyCallback) vdepn_polkit_wrapper_g_callback,
									   NULL);

  return TRUE;
}

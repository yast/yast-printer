# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:        include/printer/overview.ycp
# Package:     Configuration of printer
# Summary:     Overview dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>

require "shellwords"
require "yast2/system_time"

module Yast
  module PrinterOverviewInclude
    def initialize_printer_overview(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Printerlib"
      Yast.import "Printer"
      Yast.import "Wizard"

      Yast.include include_target, "printer/helps.rb"

      @widgetOverview = VBox(
        Left(
          HBox(
            Label(_("Show")), # Label for CheckBoxes to select local and/or remote print queues to be listed:
            HSpacing(2),
            CheckBox(
              Id(:local_content_checkbox),
              Opt(:notify),
              # CheckBox to select local print queues to be listed:
              _("&Local")
            ),
            HSpacing(2),
            CheckBox(
              Id(:remote_content_checkbox),
              Opt(:notify),
              # CheckBox to select remote print queues to be listed:
              _("&Remote")
            ),
            HSpacing(1),
            Label(
              Id(:client_only_server_name),
              # This spaces string is a workaround for a bug in the UI
              # to preallocate space on the screen when the spaces string
              # is replaced by a real string if it is a client-only config.
              # Otherwise the real string is cut to less than one character
              # (at least with openSUSE 11.0 and Qt):
              "                                        "
            )
          )
        ),
        VWeight(
          2,
          Table(
            Id(:overview_table),
            Opt(:notify, :immediate, :keepSorting),
            Header(
              # Where the queue configuration exists (local or remote):
              _("Configuration"),
              # Header of a Table column with a list of print queues.
              # Print queue name:
              _("Name"),
              # Header of a Table column with a list of print queues.
              # Print queue description (e.g. model or driver):
              _("Description"),
              # Header of a Table column with a list of print queues.
              # Location of the printer (e.g. second floor, room 2.3):
              _("Location"),
              # Header of a Table column with a list of print queues.
              # Whether or not is is the default queue:
              _("Default"),
              # Header of a Table column with a list of print queues.
              # Queue status (accepting/rejecting and enabled/disabled):
              _("Status")
            ) # Header of a Table column with a list of print queues.
          )
        ),
        HBox(
          PushButton(Id(:add), Label.AddButton),
          PushButton(Id(:edit), Label.EditButton),
          PushButton(Id(:delete), Label.DeleteButton),
          HStretch(),
          PushButton(
            Id(:refresh),
            # PushButton label to refresh the list of print queues:
            _("Re&fresh List")
          ),
          PushButton(
            Id(:test),
            # PushButton label to print a test page:
            _("Print &Test Page")
          )
        )
      )
    end

    def initOverview(key)
      Builtins.y2milestone("entering initOverview with key '%1'", key)
      # First of all the multi-line string because such strings cannot be indented:
      required_cupsd_not_accessible =
        # Message of a Popup::ErrorDetails
        # when a local cupsd is required but it is not accessible.
        # YaST did already run 'lpstat -h localhost -r'
        # to check whether or not a local cupsd is accessible.
        # The command is shown here to the user (even if it is a bit technical)
        # to have him informed what goes on here and what he can do on his own.
        _(
          "A locally running CUPS daemon is required, but it seems to be not accessible.\n" +
            "Check with 'lpstat -h localhost -r' whether a local cupsd is accessible.\n" +
            "A non-accessible cupsd leads to an endless sequence of further failures.\n"
        )
      cupsd_not_on_official_port =
        # Message of a Popup::ErrorDetails
        # when the local cupsd does not use the official IPP port (631).
        # A rather technical text because this does not happen on normal systems
        # By default the cupsd uses the official IPP port (631).
        # If not, the user must have intentionally and manually changed
        # the port setting for the cupsd in /etc/cups/cupsd.conf
        _(
          "The CUPS daemon seems not to listen on the official IANA IPP port (631).\n" +
            "Check with 'netstat -nap | grep cupsd' where the cupsd actually listens.\n" +
            "This happens when there is a 'Listen ...:1234' or 'Port 1234' setting\n" +
            "(where 1234 means any port number which is not the official port 631)\n" +
            "in /etc/cups/cupsd.conf (check also if there is 'BrowsePort 1234').\n" +
            "The YaST printer module does not support a non-official port.\n" +
            "A non-official port leads to an endless sequence of further failures.\n" +
            "If you really must use a non-official port, you cannot use\n" +
            "the YaST printer module to configure your printers.\n"
        )
      Wizard.SetDesktopIcon("org.openSUSE.YaST.Printer")
      # The button with "back/cancel" functionality is removed here
      # only because here it happens faster than only in the handleOverview function
      # to avoid that the button is visible for some time until it is actually removed.
      # See the handleOverview function for details why this button is removed.
      Wizard.HideBackButton
      local_content_selected = Printer.queue_filter_show_local
      remote_content_selected = Printer.queue_filter_show_remote
      local_cupsd_required = true
      feedback_popup_exists = false
      # Determine whether or not it is currently a real client-only config
      # (i.e. a ServerName != "localhost/127.0.0.1" in /etc/cups/client.conf)
      # and ignore when it fails (i.e. use the fallback value silently):
      time_before = Yast2::SystemTime.uptime
      Printerlib.DetermineClientOnly
      if Printerlib.client_only
        if (Yast2::SystemTime.uptime - time_before) > 10
          Builtins.y2milestone(
            "DetermineClientOnly took longer than 10 seconds. CUPS server is '%1'",
            Printerlib.client_conf_server_name
          )
          # When Printerlib::DetermineClientOnly took longer than 10 seconds
          # something is fishy regarding CUPS server access.
          # In this case show feedback what goes on because for example
          # when a CUPS server is unknown by the DNS there can be longer DNS timeouts
          # which would also delay Printer::TestClientOnlyServer for up to a few minutes
          # so that the user must be informed what goes on while he is wainting:
          Popup.ShowFeedback(
            "",
            # Busy message:
            # Body of a Popup::ShowFeedback
            _(
              "Running several tests regarding CUPS server accessibility...\n(this might take some time)"
            )
          )
          feedback_popup_exists = true
          # Sleep one second to let the feedback popup stay for at least one second
          # to avoid a flickering popup which appears and disappears at the same time:
          Builtins.sleep(1000)
        end
        # A non-accessible client-only server leads to an endless sequence of weird further behaviour
        # of the module so that a non-accessible server is only accepted after insistent warning popups:
        if !Printer.TestClientOnlyServer(Printerlib.client_conf_server_name)
          if feedback_popup_exists
            Popup.ClearFeedback
            feedback_popup_exists = false
          end
          if Popup.YesNoHeadline(
              # where %1 will be replaced by the server name:
              Builtins.sformat(
                _("Do no longer use the inaccessible CUPS server '%1'?"),
                Printerlib.client_conf_server_name
              ),
              # Popup::YesNoHeadline body recommendation how to answer the headline question
              # where %1 will be replaced by the server name:
              Builtins.sformat(
                _(
                  "To proceed, you should agree that '%1' will be no longer used."
                ),
                Printerlib.client_conf_server_name
              )
            )
            if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "cups_client_only none")
              Popup.ErrorDetails(
                _(
                  "Failed to remove the 'ServerName' entry in /etc/cups/client.conf"
                ),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
              Popup.Warning(
                _(
                  "A non-accessible server leads to an endless sequence of delays and failures."
                )
              )
            end
            # The 'ServerName' entry in /etc/cups/client.conf was removed
            # so that it is now no longer a real client-only config and
            # therefore the Printerlib::client_* values must be determined anew:
            Printerlib.DetermineClientOnly
          else
            Popup.Warning(
              _(
                "A non-accessible server leads to an endless sequence of delays and failures."
              )
            )
          end
        end
        # The 'ServerName' entry in /etc/cups/client.conf may have been removed above
        # when the client-only server was non-accessible so that it might be now
        # no longer a real client-only config and therefore it is tested again
        # whether or not it is still a real client-only config:
        if Printerlib.client_only
          local_cupsd_required = false
          local_content_selected = false
          remote_content_selected = true
          UI.ChangeWidget(
            :client_only_server_name,
            :Value,
            Builtins.sformat(
              # where %1 will be replaced by the CUPS server name.
              _("CUPS Server %1"),
              Printerlib.client_conf_server_name
            ) # Show the CUPS server name if it is a client-only config
          )
          # In case of a client-only config it does not work to show local queues:
          UI.ChangeWidget(:local_content_checkbox, :Enabled, false)
        end
      end
      # Determine whether or not a local cupsd is accessible:
      time_before = Yast2::SystemTime.uptime
      if local_cupsd_required && !Printerlib.GetAndSetCupsdStatus("")
        if (Yast2::SystemTime.uptime - time_before) > 10
          Builtins.y2milestone(
            "GetAndSetCupsdStatus('') took longer than 10 seconds."
          )
          # When Printerlib::GetAndSetCupsdStatus took longer than 10 seconds
          # something is fishy regarding CUPS server access.
          # In this case show feedback what goes on because subsequent
          # Printerlib::GetAndSetCupsdStatus calls would be also delayed
          # so that the user must be informed what goes on while he is wainting:
          Popup.ShowFeedback(
            "",
            # Busy message:
            # Body of a Popup::ShowFeedback:
            _("Testing if CUPS server is accessible...")
          )
          feedback_popup_exists = true
          # Sleep one second to let the feedback popup stay for at least one second
          # to avoid a flickering popup which appears and disappears at the same time:
          Builtins.sleep(1000)
        end
        # Printerlib::GetAndSetCupsdStatus results also false when
        # a local running cupsd does not listen on the official IPP port.
        # Therefore, to be on the safe side, do a restart here.
        # Printerlib::GetAndSetCupsdStatus already shows a confirmation popup:
        Printerlib.GetAndSetCupsdStatus("restart")
        # Check again whether a required local cupsd is actually accessible
        # because the user may have rejected to start it in the above call or
        # the user may have aborted the Popup::TimedMessage from the above call
        # which would wait until a started cupsd becomes actually accessible.
        if !Printerlib.GetAndSetCupsdStatus("")
          if feedback_popup_exists
            Popup.ClearFeedback
            feedback_popup_exists = false
          end
          Popup.ErrorDetails(
            required_cupsd_not_accessible,
            Ops.add(
              Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
              Ops.get_string(Printerlib.result, "stdout", "")
            )
          )
          # A special case is when the cupsd does not listen on the official IANA IPP port (631).
          # Then "lpstat -h localhost -r" also fails ("-h localhost:port" would have to be used).
          # When there is a process which runs the command "cupsd"
          # check if something is accessible on port 631.
          # Do this test only here (and not in Printerlib::GetAndSetCupsdStatus)
          # because the Overview is the initial dialog which is shown to the user
          # when the YaST printer module started and if the cupsd does not listen
          # on the official IPP port, a single error popup when the Overview dialog
          # is launched is sufficient.
          # The YaST printer module does not support when the cupsd listens
          # on a non-official port e.g. via "Listen *:1234" and/or "Port 1234"
          # and/or "BrowsePort 1234" settings in /etc/cups/cupsd.conf.
          # Skip this test (and hope for the best) when netcat is not available
          # because in yast2-printer.spec there can be only "Recommends: netcat".
          # There have been user complaints who insist not to have netcat installed
          # because they insist that "netcat is a hacker intrusion tool" and thorough
          # explanations of the difference between netcat and e.g. nmap did not help.
          if Printerlib.ExecuteBashCommand("ps -C cupsd") &&
              Printerlib.ExecuteBashCommand("type -P netcat")
            if !Printerlib.ExecuteBashCommand("netcat -v -w 1 -z localhost 631")
              Popup.ErrorDetails(
                cupsd_not_on_official_port,
                Ops.add(
                  Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                  Ops.get_string(Printerlib.result, "stdout", "")
                )
              )
            end
          end
        end
      end
      if feedback_popup_exists
        Popup.ClearFeedback
        feedback_popup_exists = false
      end
      if Printer.printer_auto_dialogs
        # (by calling in printer_auto.ycp the "Change" function)
        # it does not make sense to let the user show local queues:
        UI.ChangeWidget(:local_content_checkbox, :Enabled, false)
        # Disable also the [Add] Button.
        # It stays disabled as long as the dialog runs because
        # it is nowhere again re-enabled below.
        UI.ChangeWidget(:add, :Enabled, false)
      end
      UI.ChangeWidget(:local_content_checkbox, :Value, local_content_selected)
      UI.ChangeWidget(:remote_content_checkbox, :Value, remote_content_selected)
      UI.ChangeWidget(
        :overview_table,
        :Items,
        Printer.QueueItems(
          Printer.queue_filter_show_local,
          Printer.queue_filter_show_remote
        )
      )
      # Try to preselect the current_queue_name if it exists in the overview_table:
      if Ops.greater_or_equal(Printer.selected_queues_index, 0)
        # because the Printer::QueueItems function sets Printer::selected_queues_index != -1
        # only if such an item exists in the overview_table so that this item can be preselected:
        Builtins.y2milestone(
          "Preselected queue: '%1'",
          Ops.get(Printer.queues, Printer.selected_queues_index, {})
        )
        UI.ChangeWidget(
          :overview_table,
          :CurrentItem,
          Id(Printer.selected_queues_index)
        )
      end
      Builtins.y2milestone("leaving initOverview")

      nil
    end

    # handle function
    # for add, edit and delete buttons,
    # local and remote checkboxes,
    # test button and refresh overview
    def handleOverview(key, event)
      event = deep_copy(event)
      Builtins.y2milestone(
        "entering handleOverview with key '%1'\nand event '%2'",
        key,
        event
      )
      # In the Overview dialog it does not make sense to have a button with "back" functionality
      # which is named "Cancel" according to the YaST Style Guide (dated Thu, 06 Nov 2008)
      # because there is nothing to "cancel" in the Overview dialog because it
      # only shows information about the current state of the configuration
      # but the Overview dialog itself does not do any change of the configuration.
      # The Overview dialog has actually the same meaning for the user
      # as a plain notification popup which has only a "OK" button.
      # If the user does not agree to what is shown in the Overview dialog
      # he must launch a configuration sub-dialog to change the configuration.
      # If the user accepted in such a configuration sub-dialog what he changed
      # via the "OK" button there, the change is applied and the Overview dialog
      # shows the new current state of the configuration, see
      # http://en.opensuse.org/Archive:YaST_Printer_redesign#Basic_Implementation_Principles:
      # so that it is not possible to "cancel" the change in the Overview dialog.
      # Any change of the configuration is done in sub-dialogs which are called
      # from the Overview dialog (even the "Confirm Deletion" popup is such a sub-dialog)
      # and in all those sub-dialogs there is a button with "cancel" functionality.
      # Note that all the different dialogs in the DialogTree (see dialogs.ycp) are
      # for the Wizard only different tabs of one same dialog (see "overview" in wizards.ycp)
      # so that the button with "back/cancel" functionality must be carefully re-enabled
      # whenever the Overview dialog is replaced by another dialog tab in the DialogTree
      # so that the other dialogs in the DialogTree have a button with "cancel" functionality.
      # In graphical mode:
      # When the Overview dialog is to be replaced by another dialog tab in the DialogTree
      # the event has the form e.g.: $["EventSerialNo":2, "EventType":"MenuEvent", "ID":"network"]
      # i.e. the EventType is "MenuEvent" so that testing only this general condition
      # (without a specific match if "ID" is one of "network","sharing","policies","autoconfig")
      # should be sufficiently safe to get the button with "back/cancel" functionality restored.
      # In ncurses mode:
      # When the Overview dialog is to be replaced by another dialog tab in the DialogTree
      # the event has the form e.g.: $["EventReason":"Activated", "EventSerialNo":0, "EventType":"WidgetEvent",
      #                                "ID":`wizardTree, "WidgetClass":`Tree, "WidgetID":`wizardTree]
      # The EventType "WidgetEvent" cannot be used here because it is too unspecific
      # because "WidgetEvent" type events are all kind of clicked buttons so that
      # for ncurses mode the ID is used as test if the Overview dialog is to be
      # replaced by another dialog tab in the DialogTree.
      # This strange testing method works at least for openSUSE 11.0 and openSUSE 11.1.
      Wizard.HideBackButton
      if "MenuEvent" == Ops.get_string(event, "EventType", "") ||
          :wizardTree == Ops.get(event, "ID")
        Wizard.RestoreBackButton
        # The above RestoreBackButton restores also its label to the default "Back"
        # but according to the YaST Style Guide (dated Thu, 06 Nov 2008)
        # this button is now named "Cancel":
        Wizard.SetBackButton(:back, Label.CancelButton)
      end

      if (:remote_content_checkbox == Ops.get(event, "ID") ||
          :local_content_checkbox == Ops.get(event, "ID")) &&
          "ValueChanged" == Ops.get_string(event, "EventReason", "")
        Builtins.y2milestone("Refreshing overview items")
        Printer.queue_filter_show_local = Convert.to_boolean(
          UI.QueryWidget(:local_content_checkbox, :Value)
        )
        Printer.queue_filter_show_remote = Convert.to_boolean(
          UI.QueryWidget(:remote_content_checkbox, :Value)
        )
        UI.ChangeWidget(
          :overview_table,
          :Items,
          Printer.QueueItems(
            Printer.queue_filter_show_local,
            Printer.queue_filter_show_remote
          )
        )
        # Try to preselect again the current_queue_name if it still exists in the overview_table:
        if Ops.greater_or_equal(Printer.selected_queues_index, 0)
          # because the Printer::QueueItems function sets Printer::selected_queues_index != -1
          # only if such an item exists in the overview_table so that this item can be preselected:
          Builtins.y2milestone(
            "Preselected queue: '%1'",
            Ops.get(Printer.queues, Printer.selected_queues_index, {})
          )
          UI.ChangeWidget(
            :overview_table,
            :CurrentItem,
            Id(Printer.selected_queues_index)
          )
        end
      end

      if :refresh == Ops.get(event, "ID") &&
          "Activated" == Ops.get_string(event, "EventReason", "")
        # For example when a client-only config is switched to a "get Browsing info" config
        # the BrowseInterval in cupsd.conf on remote CUPS servers is by default 30 seconds
        # so that it takes by default up to 31 seconds before the Overview dialog can show
        # all remote queues or any time longer depending on the BrowseInterval setting
        # on the remote CUPS servers which necessitates an explicite [Refresh] button.
        # Or the other way round when a "Get browsing info" config with a local cupsd
        # was switched to a "No browsing info" config with a local running cupsd.
        # The default BrowseTimeout value for the local cupsd is 5 minutes.
        # Therefore it takes by default 5 minutes until printer information
        # that was previously received by Browsing is removed (via timeout)
        # from the local cupsd's list so that such kind of outdated remote queues
        # are no longer shown in the Overview dialog.
        UI.ChangeWidget(
          :overview_table,
          :Items,
          Printer.QueueItems(
            Printer.queue_filter_show_local,
            Printer.queue_filter_show_remote
          )
        )
        # Try to preselect again the current_queue_name if it still exists in the overview_table:
        if Ops.greater_or_equal(Printer.selected_queues_index, 0)
          # because the Printer::QueueItems function sets Printer::selected_queues_index != -1
          # only if such an item exists in the overview_table so that this item can be preselected:
          Builtins.y2milestone(
            "Preselected queue: '%1'",
            Ops.get(Printer.queues, Printer.selected_queues_index, {})
          )
          UI.ChangeWidget(
            :overview_table,
            :CurrentItem,
            Id(Printer.selected_queues_index)
          )
        end
      end

      # After the above changes of the list of queues, determine which queue is currently selected
      # (because this might change via automated preselection when the table was made anew
      # in particular if the Printer::QueueItems function invalidated Printer::selected_queues_index)
      # and enable or disable the "Edit", "Delete", and "Test" buttons accordingly.
      # "Edit" and "Delete" are only possible for local queues, "Test" is also possible for remote queues.
      # "Test" is disabled when there is no queue selected or no queue in the table
      # and when the queue state is not "ready" (i.e. when jobs are rejected and/or when printing is disabled).
      selected_queue_index = Convert.to_integer(
        UI.QueryWidget(Id(:overview_table), :CurrentItem)
      )
      # To be safe invalidate Printer::selected_connections_index, Printer::current_device_uri,
      # Printer::selected_queues_index, and Printer::current_queue_name in any case by default and as fallback.
      # In particular invalidate Printer::selected_connections_index and Printer::selected_queues_index
      # to let the getCurrentDeviceURI function in connectionwizard.ycp fail to avoid that
      # the URI of a different previously preselected queue becomes preselected in the Connection Wizard.
      # The index of the currently selected queue is stored in selected_queue_index
      # which is used to re-enable those values later if appropriate conditions are met:
      Printer.selected_connections_index = -1
      Printer.current_device_uri = ""
      Printer.selected_queues_index = -1
      Printer.current_queue_name = ""
      if selected_queue_index == nil || Ops.less_than(selected_queue_index, 0)
        UI.ChangeWidget(:test, :Enabled, false)
        UI.ChangeWidget(:edit, :Enabled, false)
        UI.ChangeWidget(:delete, :Enabled, false)
      else
        if "local" ==
            Ops.get(Printer.queues, [selected_queue_index, "config"], "remote") ||
            "class" ==
              Ops.get(
                Printer.queues,
                [selected_queue_index, "config"],
                "remote"
              )
          # Printer::current_queue_name, and Printer::current_device_uri are re-enabled:
          Printer.selected_queues_index = selected_queue_index
          Printer.current_queue_name = Ops.get(
            Printer.queues,
            [selected_queue_index, "name"],
            ""
          )
          Printer.current_device_uri = Ops.get(
            Printer.queues,
            [selected_queue_index, "uri"],
            ""
          )
          # Only local queues or local classes can be deleted:
          UI.ChangeWidget(:delete, :Enabled, true)
          # But only a local queue can be edited:
          if "local" ==
              Ops.get(
                Printer.queues,
                [selected_queue_index, "config"],
                "remote"
              )
            UI.ChangeWidget(:edit, :Enabled, true)
          else
            UI.ChangeWidget(:edit, :Enabled, false)
          end
        else
          UI.ChangeWidget(:edit, :Enabled, false)
          UI.ChangeWidget(:delete, :Enabled, false)
        end
        # Any queue or class can be tested if it is in "ready" state:
        if "yes" ==
            Ops.get(Printer.queues, [selected_queue_index, "rejecting"], "") ||
            "yes" ==
              Ops.get(Printer.queues, [selected_queue_index, "disabled"], "")
          UI.ChangeWidget(:test, :Enabled, false)
        else
          UI.ChangeWidget(:test, :Enabled, true)
        end
      end

      if :delete == Ops.get(event, "ID") &&
          "Activated" == Ops.get_string(event, "EventReason", "")
        queue_name = Builtins.deletechars(
          Ops.get(Printer.queues, [selected_queue_index, "name"], ""),
          "'"
        )
        if "" == queue_name
          Popup.AnyMessage(
            _("Nothing Selected"),
            # Body of a Popup::AnyMessage when no queue was selected from the list:
            _("Select an entry.")
          )
          return nil
        end
        if "local" !=
            Ops.get(Printer.queues, [selected_queue_index, "config"], "remote") &&
            "class" !=
              Ops.get(
                Printer.queues,
                [selected_queue_index, "config"],
                "remote"
              )
          Popup.AnyMessage(
            _("Cannot Delete"),
            # Body of a Popup::AnyMessage when a remote queue was selected to be deleted:
            _(
              "This is a remote configuration. Only local configurations can be deleted."
            )
          )
          return nil
        end
        if !Popup.AnyQuestion(
            _("Confirm Deletion"),
            # Body of a confirmation popup before a queue will be deleted:
            _(
              "The selected configuration would be deleted immediately and cannot be restored."
            ),
            # 'Yes' button label of a confirmation popup before a queue will be deleted:
            Builtins.sformat(_("Delete configuration %1"), queue_name),
            # 'No' button label of a confirmation popup before a queue will be deleted:
            _("Do not delete it"),
            :focus_no
          )
          return nil
        end
        if "class" ==
            Ops.get(Printer.queues, [selected_queue_index, "config"], "remote")
          # because a class cannot be re-created with the YaST printer module because
          # the YaST printer module has no support to add or edit classes
          # because classes are only useful in bigger printing environments
          # which is out of the scope of the use cases of the YaST printer module.
          # Nevertheless it is possible to delete a class with the YaST printer module
          # so that the user can get rid of a class which may have been created by accident
          # with whatever other setup tool:
          if !Popup.ContinueCancelHeadline(
              _("Confirm Deletion of a Class"),
              # Body of a confirmation popup before a class will be deleted:
              _("A deleted class cannot be re-created with this tool.")
            )
            return nil
          end
        end
        # To be safe invalidate Printer::selected_queues_index in any case:
        Printer.selected_queues_index = -1
        Builtins.y2milestone(
          "Queue '%1' to be deleted: '%2'",
          queue_name,
          Ops.get(Printer.queues, selected_queue_index, {})
        )
        # No error messages here because Printer::DeleteQueue already shows them:
        Printer.DeleteQueue(queue_name)
        # Re-run the OverviewDialog (with a re-created list of queues) via the sequencer:
        return :delete
      end

      if :test == Ops.get(event, "ID") &&
          "Activated" == Ops.get_string(event, "EventReason", "")
        Builtins.y2milestone("printing test page")
        # Delete ' characters because they are used for quoting in the bash commandlines below:
        queue_name = Builtins.deletechars(
          Ops.get(Printer.queues, [selected_queue_index, "name"], ""),
          "'"
        )
        # The URI scheme is the first word up to the ':' character in the URI:
        uri_scheme = Ops.get(
          Builtins.splitstring(
            Ops.get(Printer.queues, [selected_queue_index, "uri"], ""),
            ":"
          ),
          0,
          ""
        )
        if "" == queue_name
          Popup.AnyMessage(
            _("Nothing Selected"),
            # Body of a Popup::AnyMessage when no queue was selected from the list:
            _("Select an entry.")
          )
          return nil
        end
        if "yes" ==
            Ops.get(Printer.queues, [selected_queue_index, "rejecting"], "no")
          Popup.AnyMessage(
            _("Rejecting Print Jobs"),
            # Body of a Popup::AnyMessage when the queue rejects print jobs:
            _("The testpage cannot be printed because print jobs are rejected.")
          )
          # Do a refresh of the overview content to be on the safe side.
          # Perhaps the actual current queue state is no longer "rejecting".
          # Re-run the OverviewDialog (with re-created queue status) via the sequencer:
          return :refresh
        end
        if "yes" ==
            Ops.get(Printer.queues, [selected_queue_index, "disabled"], "no")
          Popup.AnyMessage(
            _("Printout Disabled"),
            # Body of a Popup::AnyMessage when printing is disabled for the queue:
            _("The testpage cannot be printed because printout is disabled.")
          )
          # Do that a refresh of the overview content to be on the safe side.
          # Perhaps the actual current queue state is no longer "disabled".
          # Re-run the OverviewDialog (with re-created queue status) via the sequencer:
          return :refresh
        end
        if "local" ==
            Ops.get(Printer.queues, [selected_queue_index, "config"], "remote")
          # so that the user can just click the button with "modify" functionality
          # if he likes to change the configuration when the testprint is not o.k.
          Printer.selected_queues_index = selected_queue_index
          # Test whether there are already pending jobs in a local queue.
          # If yes, the queue is usually currently actively printing because
          # the test above makes sure that the queue has printing enabled.
          # When this command fails for whatever reason, it is a safe fallback
          # to assume that there are no pending jobs in the queue:
          if Printerlib.ExecuteBashCommand(
               "/usr/bin/lpstat -h localhost" +
               " -o " + queue_name.shellescape +
               " | egrep -q '^'" + queue_name.shellescape + "'-[0-9]+'"
            )
            pending_job_info = _(
              "There are pending print jobs which might be deleted before the testpage is printed."
            )
            if Printerlib.ExecuteBashCommand(
                 "/usr/bin/lpstat -h localhost" +
                 " -o " + queue_name.shellescape +
                 " -p " + queue_name.shellescape
              )
              pending_job_info = Ops.get_string(Printerlib.result, "stdout", "")
            end
            if Popup.AnyQuestionRichText(
                # where %1 will be replaced by the queue name.
                Builtins.sformat(
                  _("Delete Pending Print Jobs For %1"),
                  queue_name
                ),
                Ops.add(Ops.add("<pre>", pending_job_info), "</pre>"),
                70,
                20,
                # 'Yes' button label of a confirmation popup
                # before all pending jobs in a queue will be deleted:
                _("Delete them before printing testpage"),
                # 'No' button label of a confirmation popup
                # before all pending jobs in a queue will be deleted:
                _("Print testpage after the other jobs"),
                :focus_no
              )
              if !Printerlib.ExecuteBashCommand("/usr/bin/cancel -a -h localhost " + queue_name.shellescape)
                Popup.ErrorDetails(
                  Builtins.sformat(
                    # where %1 will be replaced by the queue name.
                    # Only a simple message because this error does not happen on a normal system.
                    _("Failed to delete all pending jobs for %1."),
                    queue_name
                  ), # Message of a Popup::ErrorDetails
                  Ops.get_string(Printerlib.result, "stderr", "")
                )
              end
            end
          end
        end
        testprint_job_title = Ops.add("YaST2testprint_", queue_name)
        # Since CUPS 1.4 there is no longer a readymade PostScript testpage in CUPS, see
        # https://bugzilla.novell.com/show_bug.cgi?id=520617
        # Therefore a slightly modified CUPS 1.3.10 testprint.ps was added
        # to yast2-printer as /usr/share/YaST2/data/testprint.ps
        # The following modifications
        #   --- cups-1.3.10/data/testprint.ps  2009-01-13 18:27:16.000000000 +0100
        #   +++ data/testprint.ps              2009-07-09 15:25:26.000000000 +0200
        #   @@ -564 +564 @@
        #   -  (Printer Test Page) CENTER           % Show text centered
        #   +  (CUPS Printer Test Page) CENTER      % Show text centered
        #   @@ -570 +570 @@
        #   -  (Printed with CUPS v1.3.x) show
        #   +  (Printed with CUPS) show
        # make it obvious that it is not a YaST testpage but a CUPS testpage
        # and it is now independent of the CUPS version.
        testprint_file_name = "/usr/share/YaST2/data/testprint.ps"
        if !Popup.AnyQuestion(
            _("Test printout"),
            # Popup::AnyQuestion message:
            _("Print one or two pages e.g. to test duplex printing"),
            # Popup::AnyQuestion so called 'yes' (default) button label:
            _("Single test page"),
            # Popup::AnyQuestion so called 'no' button label:
            _("Two test pages"),
            # The so called 'yes' button is the default choice:
            :focus_yes
          )
          testprint_file_name = "/usr/share/YaST2/data/testprint.2pages.ps"
        end
        # Do not enforce to talk to the cupsd on localhost when submiting the testpage
        # because testpage printing must also work for a "client-only" config.
        if !Printerlib.ExecuteBashCommand(
             "/usr/bin/lp -d " + queue_name.shellescape +
             " -t " + testprint_job_title.shellescape +
             " -o page-label=" + queue_name.shellescape +
             "\":YaST2testprint@$(hostname)\" " +
             testprint_file_name.shellescape
           )
          Popup.ErrorDetails(
            Builtins.sformat(
              # where %1 will be replaced by the queue name.
              # Only a simple message because this error does not happen on a normal system.
              _("Failed to print testpage for %1."),
              queue_name
            ), # Message of a Popup::ErrorDetails
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          # When submitting the testpage to the queue failed (also for non-local queues)
          # there might be whatever reason (e.g. a remote queue might have been deleted in the meantime)
          # so that a refresh of the overview content is needed to be on the safe side.
          # Re-run the OverviewDialog (with re-created queue status) via the sequencer:
          return :refresh
        end
        test_print_command_stdout = Ops.get_string(
          Printerlib.result,
          "stdout",
          ""
        )
        test_print_success = Popup.AnyQuestion(
          _("Wait Until Testpage Printing Finished"),
          # Popup::AnyQuestion message regarding testpage printout result
          # where %1 will be replaced by the queue name.
          Builtins.sformat(
            _("Sent testpage to %1. Printing should start soon."),
            queue_name
          ),
          # Popup::AnyQuestion 'Yes' button label
          # regarding a positive testpage printout result:
          _("Testpage printout was successful"),
          # Popup::AnyQuestion 'No' button label
          # regarding a negative testpage printout result:
          _("Testpage printing failed"),
          :focus_yes
        )
        if "local" ==
            Ops.get(Printer.queues, [selected_queue_index, "config"], "remote")
          # it seems something went wrong with the testpage printing
          # so that the user can delete all pending jobs now.
          # Via the "cancel" command the cupsd sends termination signals
          # to running filter processes for the queue so that the filters
          # (in particular the printer driver) could do whatever is needed
          # to switch an actively printing printer device into a clean state
          # (e.g. exit its graphics printing mode and switch back to normal mode).
          # The backend process terminates when the filters have finished.
          # This helps in usual cases (in particular when a good driver is used)
          # if something had messed up for an actively printing job but
          # unfortunately there is no option for the "cancel" command
          # which lets the cupsd kill the backend process as emergency brake
          # when something is really wrong e.g. a wrong driver lets the printer
          # spit out zillions of sheets with nonsense characters.
          # When this command fails for whatever reason, it is a safe fallback
          # to assume that there are no pending jobs in the queue:
          if Printerlib.ExecuteBashCommand(
               "/usr/bin/lpstat -h localhost" +
               " -o " + queue_name.shellescape +
               " | egrep -q '^'" + queue_name.shellescape + "'-[0-9]+'"
             )
            pending_job_info = _(
              "There are pending print jobs which might be deleted now."
            )
            if Printerlib.ExecuteBashCommand(
                 "/usr/bin/lpstat -h localhost" +
                 " -o " + queue_name.shellescape +
                 " -p " + queue_name.shellescape
               )
              pending_job_info = Ops.get_string(Printerlib.result, "stdout", "")
            end
            if Popup.AnyQuestionRichText(
                # where %1 will be replaced by the queue name.
                Builtins.sformat(
                  _("Delete Pending Print Jobs For %1"),
                  queue_name
                ),
                Ops.add(Ops.add("<pre>", pending_job_info), "</pre>"),
                70,
                20,
                # 'Yes' button label of a confirmation popup
                # before all pending jobs in a queue will be deleted:
                _("Delete all pending jobs"),
                # 'No' button label of a confirmation popup
                # before all pending jobs in a queue will be deleted:
                _("Do not delete them"),
                :focus_no
              )
              if !Printerlib.ExecuteBashCommand("/usr/bin/cancel -a -h localhost " + queue_name.shellescape)
                Popup.ErrorDetails(
                  Builtins.sformat(
                    # where %1 will be replaced by the queue name.
                    # Only a simple message because this error does not happen on a normal system.
                    _("Failed to delete all pending jobs for %1."),
                    queue_name
                  ), # Message of a Popup::ErrorDetails
                  Ops.get_string(Printerlib.result, "stderr", "")
                )
              end
              # Deal with the backend process regardless whether or not
              # the above cancel command was successful because
              # killing the backend process is an emergency brake
              # when something is really wrong.
              # Sleep 1 second in any case to let the backend process terminate orderly:
              Builtins.sleep(1000)
              backend_is_running_commandline = "ps -C " + uri_scheme.shellescape + " -o pid=,args="
              backend_is_running_commandline += " | grep " + testprint_job_title.shellescape
              # Do nothing to be on the safe side if the next command fails for whatever reason:
              if Printerlib.ExecuteBashCommand(backend_is_running_commandline)
                # Sleep 10 seconds to give the backend process more time to terminate orderly
                # which may still wait for the filters to finish because of the above cancel command.
                # There is no user feedback while waiting here because I assume that
                # the user expects that it takes a bit of time to delete all pending jobs.
                Builtins.sleep(10000)
                if Printerlib.ExecuteBashCommand(backend_is_running_commandline)
                  Builtins.y2milestone(
                    "Still running backend process to be killed: '%1'",
                    Ops.get_string(Printerlib.result, "stdout", "")
                  )
                  # Kill the backend process:
                  Printerlib.ExecuteBashCommand(
                    backend_is_running_commandline +
                    " | cut -s -d ' ' -f1 | head -n 1 | tr -d -c '[:digit:]'"
                  )
                  backend_pid = Ops.get_string(Printerlib.result, "stdout", "")
                  if "" != backend_pid
                    Printerlib.ExecuteBashCommand("kill -9 " + backend_pid.shellescape)
                  end
                end
              end
            end
          end
          if !test_print_success
            # and when it is a local queue, extract logging information about the test print job
            # from /var/log/cups/error_log and show them to the user:
            test_print_command_stdout = Builtins.deletechars(
              test_print_command_stdout,
              "'"
            )
            Printerlib.ExecuteBashCommand(
              #   echo funprinter-1000-123 | sed -e 's/.*-//'
              # so that it works even if there is a '-' in the queue name
              # which is not allowed but may happen nevertheless, see
              # http://bugzilla.novell.com/show_bug.cgi?id=556819#c12
              # and the final tr removes in particular spaces and newline:
              "echo " + test_print_command_stdout.shellescape +
              " | grep -o " + queue_name.shellescape + "'-[0-9]* '" +
              " | sed -e 's/.*-//' | tr -d -c '[:digit:]'"
              # sed is greedy and cuts all up to the last '-' for example
              )
            test_print_job_number = Ops.get_string(
              Printerlib.result,
              "stdout",
              ""
            )
            test_print_cups_error_log = ""
            if "" != test_print_job_number
              Printerlib.ExecuteBashCommand(
                "grep '\\[Job '" + test_print_job_number.shellescape +
                "'\\]' /var/log/cups/error_log | grep -v '^[dD]' | tail -n 20"
              )
              test_print_cups_error_log = Ops.add(
                "...\n",
                Ops.get_string(Printerlib.result, "stdout", "")
              )
            end
            # Ignore an effectively empty test_print_cups_error_log:
            if "" !=
                Builtins.filterchars(
                  test_print_cups_error_log,
                  Printer.alnum_chars
                )
              where_full_log = _(
                "For the full log, see the /var/log/cups/error_log file."
              )
              Popup.AnyMessage(
                Builtins.sformat(
                  _(
                    "CUPS log information while processing the testpage for %1 (English only)"
                  ),
                  queue_name
                ), # Header of a Popup::AnyMessage where %1 will be replaced by the queue name:
                Ops.add(
                  Ops.add(
                    test_print_cups_error_log,
                    "\n----------------------------------------------------------------------\n"
                  ),
                  where_full_log
                )
              )
            else
              Popup.Notify(
                # but the test_print_cups_error_log was effectively empty,
                # show a very generic info to the user to show at least something:
                _(
                  "For CUPS log information, see the /var/log/cups/error_log file."
                )
              )
            end
          end
        else
          if !test_print_success
            Popup.Notify(
              # show a very generic info to the user to show at least something:
              _(
                "When printing via a remote system fails, you may ask an admin of the remote system."
              )
            )
          end
        end
        # While testpage printing the backend may have failed (also for non-local queues)
        # e.g. exited with exit code 1 (CUPS_BACKEND_FAILED) or 4 (CUPS_BACKEND_STOP)
        # which disables the queue so that a refresh of the overview content is needed.
        # Re-run the OverviewDialog (with re-created queue status) via the sequencer:
        return :refresh
      end

      if :add == Ops.get(event, "ID") &&
          "Activated" == Ops.get_string(event, "EventReason", "")
        # (i.e. a ServerName != "localhost/127.0.0.1" in /etc/cups/client.conf).
        # There is no new Printerlib::DetermineClientOnly() here because
        # it was run in initOverview() and the client_only state cannot be
        # changed in YaST while the Overview dialog runs:
        if Printerlib.client_only
          if !Popup.YesNoHeadline(
              # where %1 will be replaced by the server name:
              Builtins.sformat(
                _("Disable Remote CUPS Server '%1'"),
                Printerlib.client_conf_server_name
              ),
              # PopupYesNoHeadline body:
              _(
                "A remote CUPS server setting conflicts with adding a configuration."
              )
            )
            return nil
          end
          # Remove the 'ServerName' entry in /etc/cups/client.conf:
          if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "cups_client_only none")
            Popup.ErrorDetails(
              # Only a simple message because this error does not happen on a normal system
              # (i.e. a system which is not totally broken or totally messed up).
              _(
                "Failed to remove the 'ServerName' entry in /etc/cups/client.conf"
              ),
              Ops.get_string(Printerlib.result, "stderr", "")
            )
            return nil
          end
        end
        if !Printerlib.GetAndSetCupsdStatus("")
          # Do a restart to be safe.
          # Printerlib::GetAndSetCupsdStatus already shows a confirmation popup:
          return nil if !Printerlib.GetAndSetCupsdStatus("restart")
        end
        # To be safe autodetect the queues again.
        # When there was a switch from "client only" to a local running cupsd
        # existing local queues are not yet know so that the NewQueueName function
        # may not notice when a queue name proposal for a new (i.e. added) queue
        # already exists as local queue:
        Printer.AutodetectQueues
        # Invalidate Printer::current_device_uri so that the Printer::ConnectionItems function
        # does not set a valid Printer::selected_connections_index so that the BasicAddDialog
        # does not preselect a connection so that the first connection in the list is preselected
        # (via Table widget fallback) which is still better than an arbitrary preselected entry:
        Printer.current_device_uri = ""
        return :add
      end

      if :edit == Ops.get(event, "ID") &&
          Ops.get_string(event, "EventReason", "") == "Activated"
        queue_name = Builtins.deletechars(
          Ops.get(Printer.queues, [selected_queue_index, "name"], ""),
          "'"
        )
        if "" == queue_name
          Popup.AnyMessage(
            _("Nothing Selected"),
            # Body of a Popup::AnyMessage when no queue was selected from the list:
            _("Select an entry.")
          )
          return nil
        end
        if "local" !=
            Ops.get(Printer.queues, [selected_queue_index, "config"], "remote")
          Popup.AnyMessage(
            _("Cannot Modify"),
            # Body of a Popup::AnyMessage when a remote queue was selected to be modified:
            _(
              "This is a remote configuration. Only local configurations can be modified."
            )
          )
          return nil
        end
        Printer.selected_queues_index = selected_queue_index
        # Invalidate Printer::current_device_uri so that the Printer::ConnectionItems function
        # does not set a valid Printer::selected_connections_index so that the BasicAddDialog
        # does not preselect a connection so that the first connection in the list is preselected
        # (via Table widget fallback) which is correct because this is the current connection:
        Printer.current_device_uri = ""
        Builtins.y2milestone(
          "Queue '%1' to be modified: '%2'",
          queue_name,
          Ops.get(Printer.queues, selected_queue_index, {})
        )
        return :modify
      end

      # Default and fallback return value:
      nil
    end
  end
end

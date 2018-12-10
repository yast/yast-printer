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

# File:        include/printer/sharing.ycp
# Package:     Configuration of printer
# Summary:     Print queue sharing and publishing dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>

module Yast
  module PrinterSharingInclude
    def initialize_printer_sharing(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Popup"

      Yast.include include_target, "printer/helps.rb"

      @share_printers_dialog_is_useless = false
      @interface_table_items = []
      @available_interfaces = []
      @sharing_has_changed = false
      @initial_deny_remote_access = true
      @initial_allow_remote_access = false
      @initial_allow_local_network_access = false
      @initial_publish_to_local_network = false
      @initial_interface_table_items = []
      @initial_allow_input_value = ""
      @initial_browse_address_input_value = ""
      @share_printers_firewall_popup_was_shown = false

      @widgetSharing = VBox(
        RadioButtonGroup(
          Id(:deny_or_allow_remote_access),
          VBox(
            Left(
              RadioButton(
                Id(:deny_remote_access_radio_button),
                Opt(:notify),
                # A RadioButton label to deny remote access to local print queues:
                _("&Deny Remote Access"),
                @initial_deny_remote_access
              )
            ),
            Left(
              RadioButton(
                Id(:allow_remote_access_radio_button),
                Opt(:notify),
                # A RadioButton label to allow remote access to local print queues:
                _("&Allow Remote Access"),
                @initial_allow_remote_access
              )
            ),
            Left(
              HBox(
                HSpacing(2),
                Label(
                  Id(:allow_remote_access_label),
                  # A label which explains how the subsequent choices can be used:
                  _(
                    "There are various ways how to specify which remote hosts are allowed:"
                  )
                )
              )
            )
          )
        ),
        HBox(
          HSpacing(4),
          VBox(
            Left(
              CheckBox(
                Id(:allow_local_network_access_check_box),
                Opt(:notify),
                # A CheckBox label to allow remote access to local print queues
                # for computers within the local network:
                _("For computers within the &local network"),
                @initial_allow_local_network_access
              )
            ),
            Left(
              HBox(
                HSpacing(2),
                CheckBox(
                  Id(:publish_to_local_network_check_box),
                  Opt(:notify),
                  # A CheckBox label to publish local print queues by default within the local network:
                  _("&Publish printers within the local network"),
                  @initial_publish_to_local_network
                )
              )
            ),
            Left(
              Label(
                Id(:interface_table_label),
                # A caption for a table to allow remote access to local print queues
                # via network interfaces specified in the table below:
                _("Via network interfaces")
              )
            ),
            HBox(
              HSpacing(2),
              VSquash(
                MinHeight(
                  5,
                  Table(
                    Id(:interface_table),
                    Opt(:keepSorting),
                    Header(
                      _("Interface"),
                      # A table column header where the column shows whether or not
                      # local print queues are published by default
                      # via the network interface in the other table column:
                      _("Publish printers via this interface")
                    ), # A table column header where the column lists network interfaces:
                    @initial_interface_table_items
                  )
                )
              ),
              VBox(
                PushButton(
                  Id(:add_interface),
                  # A PushButton label to add a network interface to the table which shows
                  # the network interfaces to allow remote access to local print queues:
                  _("&Add")
                ),
                PushButton(
                  Id(:edit_interface),
                  # A PushButton label to change a network interface in the table which shows
                  # the network interfaces to allow remote access to local print queues:
                  _("&Edit")
                ),
                PushButton(
                  Id(:delete_interface),
                  # A PushButton label to delete a network interface from the table which shows
                  # the network interfaces to allow remote access to local print queues:
                  _("&Delete")
                )
              )
            ),
            Left(
              Label(
                Id(:specific_addresses_label),
                # A caption to allow remote access to local print queues
                # for hosts and/or networks specified in two TextEntries below:
                _("For Specific IP Addresses or Networks")
              )
            ),
            HBox(
              HSpacing(2),
              VBox(
                Left(
                  TextEntry(
                    Id(:allow_input),
                    # TextEntry to allow remote access to local print queues
                    # for hosts and/or networks:
                    _(
                      "Allow access from those IP addresses or &network/netmask (separated by space)"
                    )
                  )
                ),
                Left(
                  HBox(
                    HSpacing(2),
                    TextEntry(
                      Id(:browse_address_input),
                      # TextEntry to publish local print queues
                      # to IP addresses and/or network broadcast addresses:
                      _(
                        "Publish to these IP addresses or network &broadcast addresses (separated by space)"
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    end

    def showInterfacePopup(interface_name, is_published)
      interface_map = {}

      UI.OpenDialog(
        VBox(
          CheckBox(
            Id(:publish_check_box),
            # A CheckBox label to publish local print queues by default
            # via a partivular network interface which is shown below.
            _("&Publish printers by default via the network interface below."),
            is_published
          ),
          ComboBox(
            Id(:interfaces_combo_box),
            Opt(:editable),
            # A header for a ComboBox which lists network interfaces:
            _("Available Network &Interfaces:"),
            @available_interfaces
          ),
          VSpacing(),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      if "" != interface_name
        UI.ChangeWidget(:interfaces_combo_box, :Value, interface_name)
      end
      while true
        ret = UI.UserInput
        if :cancel == ret
          interface_map = nil
          break
        end
        if :ok == ret
          interface_name = Convert.to_string(
            UI.QueryWidget(:interfaces_combo_box, :Value)
          )
          is_published = Convert.to_boolean(
            UI.QueryWidget(:publish_check_box, :Value)
          )
          Ops.set(interface_map, "interface_name", interface_name)
          Ops.set(interface_map, "is_published", is_published ? "yes" : "no")
          break
        end
      end
      UI.CloseDialog
      deep_copy(interface_map)
    end

    def ShowSharePrintersFirewallPopup
      if Printerlib.FirewallSeemsToBeActive
        Popup.AnyMessage(
          # Use the exact same wording "remote access"
          # as in the matching RadioButton label to allow remote access to local print queues:
          _("A firewall may prevent remote access"),
          # Popup::AnyMessage message:
          _("Regarding firewall setup see the help text of this dialog.")
        )
        return true
      end
      false
    end

    def ApplySharingSettings
      @sharing_has_changed = false
      # Get the actual settings and values from the dialog.
      # It does not work well to query the RadioButtonGroup with something like
      # UI::QueryWidget(`deny_or_allow_remote_access,`CurrentButton))
      # Reason: At least with openSUSE 11.0 and Qt
      # it is possible to un-check all buttons in a RadioButtonGroup
      # by clicking on the currently checked button which un-checks it
      # so that there might be no CurrentButton which leads to unexpected results.
      # Therefore the individual buttons are tested directly to be on the safe side:
      deny_remote_access = Convert.to_boolean(
        UI.QueryWidget(:deny_remote_access_radio_button, :Value)
      )
      Builtins.y2milestone(
        "deny_remote_access_radio_button value: '%1'",
        deny_remote_access
      )
      allow_remote_access = Convert.to_boolean(
        UI.QueryWidget(:allow_remote_access_radio_button, :Value)
      )
      Builtins.y2milestone(
        "allow_remote_access_radio_button value: '%1'",
        allow_remote_access
      )
      allow_local_network_access = Convert.to_boolean(
        UI.QueryWidget(:allow_local_network_access_check_box, :Value)
      )
      Builtins.y2milestone(
        "allow_local_network_access_check_box value: '%1'",
        allow_local_network_access
      )
      publish_to_local_network = Convert.to_boolean(
        UI.QueryWidget(:publish_to_local_network_check_box, :Value)
      )
      Builtins.y2milestone(
        "publish_to_local_network_check_box value: '%1'",
        publish_to_local_network
      )
      @interface_table_items = Convert.convert(
        UI.QueryWidget(:interface_table, :Items),
        :from => "any",
        :to   => "list <term>"
      )
      Builtins.y2milestone(
        "interface_table_items: '%1'",
        @interface_table_items
      )
      current_allow_input_value = Convert.to_string(
        UI.QueryWidget(Id(:allow_input), :Value)
      )
      Builtins.y2milestone(
        "current_allow_input_value: '%1'",
        current_allow_input_value
      )
      current_browse_address_input_value = Convert.to_string(
        UI.QueryWidget(Id(:browse_address_input), :Value)
      )
      Builtins.y2milestone(
        "current_browse_address_input_value: '%1'",
        current_browse_address_input_value
      )
      allow_values = current_allow_input_value
      browse_address_values = current_browse_address_input_value
      Builtins.foreach(@interface_table_items) do |interface_table_item|
        interface_name = Ops.get_string(interface_table_item, 1, "")
        is_published = Ops.get_string(interface_table_item, 2, "")
        if "" != interface_name
          allow_values = Ops.add(
            Ops.add(Ops.add("@IF(", interface_name), ") "),
            allow_values
          )
          # Add the inferface nameto browse_address_values
          # only if remote access is allowed for this interface:
          if "yes" == is_published
            browse_address_values = Ops.add(
              Ops.add(Ops.add("@IF(", interface_name), ") "),
              browse_address_values
            )
          end
        end
      end 

      if allow_local_network_access
        allow_values = Ops.add("@LOCAL ", allow_values)
        # Add "@LOCAL" to browse_address_values
        # only if remote access is allowed for "@LOCAL":
        if publish_to_local_network
          browse_address_values = Ops.add("@LOCAL ", browse_address_values)
        end
      end
      Builtins.y2milestone("allow_values: %1", allow_values)
      Builtins.y2milestone("browse_address_values: %1", browse_address_values)
      # Any kind of deny_remote_access:
      # Ignore if other settings may have been changed too
      # because whatever Allow and BrowseAddress stuff is meaningless
      # if remote access is denied at all:
      # When both the deny_remote_access_radio_button and the allow_remote_access_radio_button
      # are un-checked, assume the user wants deny_remote_access (via '! allow_remote_access')
      # because this is the safe setting (even when allow_values is not empty):
      if deny_remote_access || !allow_remote_access ||
          "" ==
            Builtins.filterchars(
              allow_values,
              Ops.add(Printer.alnum_chars, "*")
            ) ||
          Builtins.contains(
            Builtins.splitstring(
              Builtins.tolower(current_allow_input_value),
              " "
            ),
            "none"
          )
        return true if @initial_deny_remote_access
        @sharing_has_changed = true
        # It leads to inconsistencies if only Only set 'Listen localhost' would be set
        # but Allow and BrowseAddress enties would be kept because when there are
        # BrowseAddress enties, it must listen on matching remote interfaces
        # and then also matching Allow enties should be there.
        if !Printerlib.ExecuteBashCommand(
            Ops.add(
              Printerlib.yast_bin_dir,
              "modify_cupsd_conf Listen localhost"
            )
          )
          Popup.ErrorDetails(
            # Do not change or translate "Listen localhost", it is a system settings name.
            _("Failed to set only 'Listen localhost' in /etc/cups/cupsd.conf."),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        if !Printerlib.ExecuteBashCommand(
            Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Allow none")
          )
          Popup.ErrorDetails(
            # Do not change or translate "Allow", it is a system settings name.
            _("Failed to remove 'Allow' entries from /etc/cups/cupsd.conf."),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        # Do not change the global "Browsing On/Off" entry in cupsd.conf
        # because "Browsing Off" disables also receiving
        # of remote queue information from remote CUPS servers
        # which might be needed by the "Print Via Network" dialog.
        # Instead remove only the "BrowseAddress" entries in cupsd.conf:
        if !Printerlib.ExecuteBashCommand(
            Ops.add(
              Printerlib.yast_bin_dir,
              "modify_cupsd_conf BrowseAddress none"
            )
          )
          Popup.ErrorDetails(
            # Do not change or translate "BrowseAddress", it is a system settings name.
            _(
              "Failed to remove 'BrowseAddress' entries from /etc/cups/cupsd.conf."
            ),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        # If a local cupsd is accessible, restart it,
        # otherwise do nothing (i.e. do not start it now):
        if Printerlib.GetAndSetCupsdStatus("")
          return false if !Printerlib.GetAndSetCupsdStatus("restart")
        end
        return true
      end
      # Any kind of allow_remote_access:
      # Check if there are real changes:
      if allow_remote_access && @initial_deny_remote_access
        # and the user changed it to "allow remote access"
        # but nothing else changed, then sharing_has_changed is true
        # if there is at least one real allow value set.
        # The last condition is true here because when allow_values is empty,
        # it is a deny_remote_access case, see above.
        @sharing_has_changed = true
      end
      # Check if there are real changes regarding the "@LOCAL" settings:
      if allow_local_network_access != @initial_allow_local_network_access ||
          publish_to_local_network != @initial_publish_to_local_network
        @sharing_has_changed = true
      end
      # Check if there are real changes in the table of interfaces.
      # Ignore ordering and ignore duplicates (toset)
      # but do not ignore case because network interface names are case sensitive:
      initial_interface_table_entries = []
      Builtins.foreach(@initial_interface_table_items) do |initial_interface_table_item|
        initial_interface_table_entries = Builtins.add(
          initial_interface_table_entries,
          Ops.add(
            Ops.get_string(initial_interface_table_item, 1, ""),
            Ops.get_string(initial_interface_table_item, 2, "")
          )
        )
      end 

      initial_interface_table_entries = Builtins.toset(
        initial_interface_table_entries
      )
      interface_table_entries = []
      Builtins.foreach(@interface_table_items) do |interface_table_item|
        interface_table_entries = Builtins.add(
          interface_table_entries,
          Ops.add(
            Ops.get_string(interface_table_item, 1, ""),
            Ops.get_string(interface_table_item, 2, "")
          )
        )
      end 

      interface_table_entries = Builtins.toset(interface_table_entries)
      if Builtins.mergestring(interface_table_entries, "") !=
          Builtins.mergestring(initial_interface_table_entries, "")
        @sharing_has_changed = true
      end
      # Check if there are real changes in the values in allow_input and in browse_address_input.
      # Do not ignore changes in the case (e.g. from 'host.domain.com' to 'Host.Domain.com')
      # because the user may like to have it exactly in cupsd.conf (even if actually case may not matter):
      initial_allow_input_set = Builtins.toset(
        Builtins.splitstring(@initial_allow_input_value, " ")
      )
      current_allow_input_set = Builtins.toset(
        Builtins.splitstring(current_allow_input_value, " ")
      )
      if Builtins.mergestring(current_allow_input_set, "") !=
          Builtins.mergestring(initial_allow_input_set, "")
        @sharing_has_changed = true
      end
      initial_browse_address_input_set = Builtins.toset(
        Builtins.splitstring(@initial_browse_address_input_value, " ")
      )
      current_browse_address_input_set = Builtins.toset(
        Builtins.splitstring(current_browse_address_input_value, " ")
      )
      if Builtins.mergestring(current_browse_address_input_set, "") !=
          Builtins.mergestring(initial_browse_address_input_set, "")
        @sharing_has_changed = true
      end
      # Exit if no real change was detected above to avoid useless changes of cupsd.conf
      # and subsequent useless restarts of the cupsd:
      return true if !@sharing_has_changed
      # When allow_values is empty, it is a deny_remote_access case, see above.
      # Therefore allow_values is non-empty here:
      if !Builtins.issubstring(Builtins.tolower(allow_values), "none")
        # test whether or not a firewall seems to be active and
        # if yes show a popup regarding firewall if it was not yet shown:
        if !@share_printers_firewall_popup_was_shown
          if ShowSharePrintersFirewallPopup()
            @share_printers_firewall_popup_was_shown = true
          end
        end
      end
      if !Printerlib.ExecuteBashCommand(
          Ops.add(
            Ops.add(
              Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Allow '"),
              allow_values
            ),
            "'"
          )
        )
        Popup.ErrorDetails(
          Builtins.sformat(
            # where %1 will be replaced by one or more system settings values.
            # Do not change or translate "Allow", it is a system settings name.
            _("Failed to set 'Allow' entries '%1' in /etc/cups/cupsd.conf."),
            allow_values
          ), # Popup::ErrorDetails message
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      if "" != browse_address_values
        if !Printerlib.ExecuteBashCommand(
            Ops.add(
              Ops.add(
                Ops.add(
                  Printerlib.yast_bin_dir,
                  "modify_cupsd_conf BrowseAddress '"
                ),
                browse_address_values
              ),
              "'"
            )
          )
          Popup.ErrorDetails(
            Builtins.sformat(
              # where %1 will be replaced by one or more system settings values.
              # Do not change or translate "BrowseAddress", it is a system settings name.
              _(
                "Failed to set 'BrowseAddress' entries '%1' in /etc/cups/cupsd.conf."
              ),
              browse_address_values
            ), # Popup::ErrorDetails message
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        # Having "BrowseAddress" entries requires "Browsing On",
        # otherwise browsing information would not be sent at all:
        if !Printerlib.ExecuteBashCommand(
            Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Browsing On")
          )
          Popup.ErrorDetails(
            _("Failed to set 'Browsing On' in /etc/cups/cupsd.conf."),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
      else
        # do not change the global "Browsing On/Off" entry in cupsd.conf
        # because "Browsing Off" disables also receiving
        # of remote queue information from remote CUPS servers
        # which might be needed by the "Print Via Network" dialog.
        # Instead remove only the "BrowseAddress" entries in cupsd.conf:
        if !Printerlib.ExecuteBashCommand(
            Ops.add(
              Printerlib.yast_bin_dir,
              "modify_cupsd_conf BrowseAddress none"
            )
          )
          Popup.ErrorDetails(
            # Do not change or translate "BrowseAddress", it is a system settings name.
            _(
              "Failed to remove 'BrowseAddress' entries from /etc/cups/cupsd.conf."
            ),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
      end
      # Only if all the above was successfully set, Listen is set too:
      # Currently 'Listen *:631' is simply set for any kind of remote access
      # because the Listen directive supports only network addresses as value.
      # Neither 'Listen @LOCAL' nor 'Listen @IF(name)' is supported.
      # TODO: Determine the matching network address for @LOCAL and @IF(name)
      #       and use the matching network address for the Listen directive.
      if !Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Listen all")
        )
        Popup.ErrorDetails(
          # Do not change or translate "Listen *:631", it is a system settings name.
          _("Failed to set 'Listen *:631' in /etc/cups/cupsd.conf."),
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      # If a local cupsd is accessible, restart it,
      # otherwise do nothing (i.e. do not start it now):
      if Printerlib.GetAndSetCupsdStatus("")
        return false if !Printerlib.GetAndSetCupsdStatus("restart")
      end
      # Exit successfully by default and as fallback:
      true
    end

    def initSharing(key)
      Builtins.y2milestone("entering initSharing with key '%1'", key)
      @share_printers_dialog_is_useless = false
      @sharing_has_changed = false
      # Determine whether or not it is currently a real client-only config
      # (i.e. a ServerName != "localhost/127.0.0.1" in /etc/cups/client.conf)
      # and ignore when it fails (i.e. use the fallback value silently):
      Printerlib.DetermineClientOnly
      if Printerlib.client_only
        if !Popup.YesNoHeadline(
            Builtins.sformat(
              # where %1 will be replaced by the server name:
              _("Disable Remote CUPS Server '%1'"),
              Printerlib.client_conf_server_name
            ), # PopupYesNoHeadline headline
            # PopupYesNoHeadline body:
            _(
              "A remote CUPS server setting conflicts with sharing local printer configurations."
            )
          )
          @share_printers_dialog_is_useless = true
          Builtins.y2milestone(
            "share_printers_dialog_is_useless because user decided not to disable client-only CUPS server '%1'",
            Printerlib.client_conf_server_name
          )
        else
          if !Printerlib.ExecuteBashCommand(
              Ops.add(Printerlib.yast_bin_dir, "cups_client_only none")
            )
            Popup.ErrorDetails(
              _(
                "Failed to remove the 'ServerName' entry in /etc/cups/client.conf"
              ),
              Ops.add(
                Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                Ops.get_string(Printerlib.result, "stdout", "")
              )
            )
            @share_printers_dialog_is_useless = true
            Builtins.y2milestone(
              "share_printers_dialog_is_useless because it failed to disable client-only CUPS server '%1'",
              Printerlib.client_conf_server_name
            )
          end
        end
      end
      # When it is no "client-only" config,
      # determine whether or not a local cupsd is accessible:
      if !@share_printers_dialog_is_useless
        if !Printerlib.GetAndSetCupsdStatus("")
          if !Printerlib.GetAndSetCupsdStatus("start")
            @share_printers_dialog_is_useless = true
            Builtins.y2milestone(
              "share_printers_dialog_is_useless because 'rccups start' failed."
            )
          end
        end
      end
      # Note that the "Share Printers" dialog is not useless when there is no local queue.
      # For example the user may like to configure "Share Printers" (e.g. allow remote access)
      # before he set up the first local queue or he may like to delete all local queues
      # and then change the "Share Printers" stuff accordingly (e.g. deny remote access).
      if @share_printers_dialog_is_useless
        # Therefore disable all widgets except the deny_remote_access_radio_button
        # because the user may like to set deny remote access in /etc/cups/cupsd.conf
        # to be on the safe side before he changes a client-only config into a config
        # with a local running cupsd (e.g. before he set up the first local queue:
        # Also the basic buttons "Help", "Cancel", "OK" are enabled.
        UI.ChangeWidget(:allow_remote_access_radio_button, :Enabled, false)
        UI.ChangeWidget(:allow_remote_access_label, :Enabled, false)
        UI.ChangeWidget(:allow_local_network_access_check_box, :Enabled, false)
        UI.ChangeWidget(:publish_to_local_network_check_box, :Enabled, false)
        UI.ChangeWidget(:interface_table_label, :Enabled, false)
        UI.ChangeWidget(:interface_table, :Enabled, false)
        UI.ChangeWidget(:add_interface, :Enabled, false)
        UI.ChangeWidget(:edit_interface, :Enabled, false)
        UI.ChangeWidget(:delete_interface, :Enabled, false)
        UI.ChangeWidget(:specific_addresses_label, :Enabled, false)
        UI.ChangeWidget(:allow_input, :Enabled, false)
        UI.ChangeWidget(:browse_address_input, :Enabled, false)
      end
      # Regardless whether or not the "Share Printers" dialog is useless,
      # fill in the values of the current settings in the system:
      @interface_table_items = []
      # Determine the 'Listen' values in /etc/cups/cupsd.conf:
      # By default there is 'Listen localhost:631' and 'Listen /var/run/cups/cups.sock'.
      # 'Listen localhost' is mandatory (i.e. it is a broken config when it is missing).
      # '/var/run/cups/cups.sock' is only an optional default (i.e. not really of interest).
      # Therefore "modify_cupsd_conf Listen" reports 'localhost' but ignores '/var/run/cups/cups.sock'
      # so that ["localhost"] is the right fallback value here:
      listen_values = [""]
      if Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Listen")
        )
        # but possible duplicate Listen values are not removed in the command output:
        listen_values = Builtins.toset(
          Builtins.splitstring(
            Ops.get_string(Printerlib.result, "stdout", ""),
            " "
          )
        )
      else
        listen_values = ["localhost"]
      end
      Builtins.y2milestone("Initial listen_values: %1", listen_values)
      # Determine if it listens at least to "localhost" and/or only to "localhost":
      listen_local = false
      listen_remote = false
      Builtins.foreach(listen_values) do |listen_value|
        if "" != listen_value
          if "all" == listen_value
            listen_local = true
            listen_remote = true
            raise Break
          end
          if "localhost" == listen_value
            listen_local = true
          else
            listen_remote = true
          end
        end
      end 

      if !listen_local
        # (e.g. listen only on /var/run/cups/cups.sock is a broken config)
        # but this does not mean that there must be a line "Listen localhost:631"
        # in cupsd.conf because listening on all interfaces via "Listen *:631"
        # lets it also listen on the localhost interface
        # (see above how listen_local is set to true).
        # Try to do a simple fix for the broken config but ignore possible failures.
        # Set only 'Listen localhost:631' in /etc/cups/cupsd.conf which means
        # that all possibly existing non-'localhost' Listen entries are removed.
        # but this should be no big problem because appropriate Listen values
        # (depending on the settings in this dialog) would be added when this dialog finishes.
        # Only while this dialog is open, the non-'localhost' Listen entries are removed
        # which means that there is no remote access while this dialog is open
        # which is no big issue for a broken config without any local access ;-)
        Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Listen localhost")
        )
        Printerlib.GetAndSetCupsdStatus("restart")
      end
      # Determine the 'Allow' values for the root location '<Location />' in /etc/cups/cupsd.conf:
      # By default there is only 'Allow 127.0.0.2' but this value is suppressed in the output
      # of 'modify_cupsd_conf Allow' so that the empty sting is the right fallback value here:
      allow_values = [""]
      if Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Allow")
        )
        # but possible duplicate Allow values are not removed in the command output:
        allow_values = Builtins.toset(
          Builtins.splitstring(
            Ops.get_string(Printerlib.result, "stdout", ""),
            " "
          )
        )
      else
        allow_values = [""]
      end
      Builtins.y2milestone("Initial allow_values: %1", allow_values)
      # Determine the 'BrowseAddress' values in /etc/cups/cupsd.conf:
      # By default there is no BrowseAddress value so that the empty sting is the right fallback:
      browse_address_values = [""]
      if Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf BrowseAddress")
        )
        # but possible duplicate BrowseAddress values are not removed in the command output:
        browse_address_values = Builtins.toset(
          Builtins.splitstring(
            Ops.get_string(Printerlib.result, "stdout", ""),
            " "
          )
        )
      else
        browse_address_values = [""]
      end
      Builtins.y2milestone(
        "Initial browse_address_values: %1",
        browse_address_values
      )
      # Reset the different values for the different widgets in the dialog to defaults:
      @initial_deny_remote_access = true
      UI.ChangeWidget(:deny_remote_access_radio_button, :Value, true)
      @initial_allow_remote_access = false
      UI.ChangeWidget(:allow_remote_access_radio_button, :Value, false)
      @initial_allow_local_network_access = false
      UI.ChangeWidget(:allow_local_network_access_check_box, :Value, false)
      @initial_publish_to_local_network = false
      UI.ChangeWidget(:publish_to_local_network_check_box, :Value, false)
      @initial_interface_table_items = []
      @initial_allow_input_value = ""
      @initial_browse_address_input_value = ""
      # Split the allow_values list together with the browse_address_values list
      # into the different values for the different widgets in the dialog.
      # By default no remote access is allowed (see the defaults in widgetSharing)
      # but if there is at least one none-empty allow_value, remote access should be allowed
      # except when there is no remote Listen entry:
      none_empty_allow_values = false
      allow_none = false
      Builtins.foreach(allow_values) do |allow_value|
        next if "" == Builtins.filterchars(allow_value, Printer.alnum_chars)
        none_empty_allow_values = true
        allow_none = true if "none" == Builtins.tolower(allow_value)
        # To be safe against any unexpected locale mess, I use tolower for both strings so that
        # equal strings result true regardless of what tolower/toupper results in which locale
        # instead of an asymmetric comparison like "@LOCAL" == toupper(allow_value):
        if Builtins.tolower("@LOCAL") == Builtins.tolower(allow_value)
          UI.ChangeWidget(:allow_local_network_access_check_box, :Value, true)
          @initial_allow_local_network_access = true
          # Check if this value appears also in the browse_address_values:
          if Builtins.contains(browse_address_values, allow_value)
            UI.ChangeWidget(:publish_to_local_network_check_box, :Value, true)
            @initial_publish_to_local_network = true
          end
          next
        end
        if Builtins.issubstring(
            Builtins.tolower(allow_value),
            Builtins.tolower("@IF")
          )
          # Check if this value appears also in the browse_address_values:
          publish_via_this_interface = "no"
          if Builtins.contains(browse_address_values, allow_value)
            publish_via_this_interface = "yes"
          end
          # Extract only the interface-name from the allow_value:
          start = Builtins.findfirstof(allow_value, "(")
          _end = Builtins.findfirstof(allow_value, ")")
          if nil != start && nil != _end &&
              Ops.greater_than(Ops.subtract(Ops.subtract(_end, start), 1), 0)
            interface_name = Builtins.substring(
              allow_value,
              Ops.add(start, 1),
              Ops.subtract(Ops.subtract(_end, start), 1)
            )
            @interface_table_items = Builtins.add(
              @interface_table_items,
              Item(
                Id(Builtins.size(@interface_table_items)),
                interface_name,
                publish_via_this_interface
              )
            )
          end
          next
        end
        # When the allow_value is neither "@LOCAL" nor "@IF(...)"
        # it is for the allow_input TextEntry (intentionally also if it is "none").
        # Have a trailing space character so that the user can easily add something:
        @initial_allow_input_value = Ops.add(
          Ops.add(@initial_allow_input_value, allow_value),
          " "
        )
      end 

      # By default initial_deny_remote_access is true
      # and initial_allow_remote_access is false (see above)
      # and this is correct (i.e. it must not be changed)
      # when the cupsd does not listen on a remote interface
      # or when the allow_values are effectively empty
      # or when one of the the allow_values is "none":
      if listen_remote && none_empty_allow_values && !allow_none
        UI.ChangeWidget(:deny_remote_access_radio_button, :Value, false)
        @initial_deny_remote_access = false
        UI.ChangeWidget(:allow_remote_access_radio_button, :Value, true)
        @initial_allow_remote_access = true
        # When something (except 'none') regarding "Allow remote access" is set
        # test whether or not a firewall seems to be active and
        # if yes show a popup regarding firewall if it was not yet shown:
        if !@share_printers_firewall_popup_was_shown
          if ShowSharePrintersFirewallPopup()
            @share_printers_firewall_popup_was_shown = true
          end
        end
      else
        # whole yast2-printer module runs so that the user could launch this dialog
        # several times in one module run and switch between "Deny remote access"
        # and "Allow remote access" several times in one run of the yast2-printer module.
        # When in the previous run of this dialog "Deny remote access" has become true
        # but in the current run of this dialog it was switched back to "Allow remote access"
        # make sure to show in the current run of this dialog the popup regarding firewall again:
        @share_printers_firewall_popup_was_shown = false
      end
      Builtins.foreach(browse_address_values) do |browse_address_value|
        if "" == Builtins.filterchars(browse_address_value, Printer.alnum_chars)
          next
        end
        if Builtins.tolower("@LOCAL") == Builtins.tolower(browse_address_value)
          # because this case is handled in the foreach for allow_values above:
          next
        end
        if Builtins.issubstring(
            Builtins.tolower(browse_address_value),
            Builtins.tolower("@IF")
          )
          # because this case is handled in the foreach for allow_values above:
          next
        end
        # When the browse_address_value is neither "@LOCAL" nor "@IF(...)"
        # it is for the browse_address_input TextEntry.
        # Have a trailing space character so that the user can easily add something:
        @initial_browse_address_input_value = Ops.add(
          Ops.add(@initial_browse_address_input_value, browse_address_value),
          " "
        )
      end 

      Builtins.y2milestone(
        "Initial interface_table_items: %1",
        @interface_table_items
      )
      UI.ChangeWidget(:interface_table, :Items, @interface_table_items)
      @initial_interface_table_items = deep_copy(@interface_table_items)
      UI.ChangeWidget(:interface_table, :CurrentItem, -1)
      # Determine the currently available IPv4 (-family inet) network interfaces in the system.
      # Omit all non-eth* interfaces because loopback interfaces do not make sense here
      # and ppp* interfaces are usually used for DSL and analog modems to access the
      # untrusted Internet from which no remote access should be allowed by accident
      # (the user can enter any interface manually if he knows what he does):
      @available_interfaces = []
      if Printerlib.ExecuteBashCommand(
          "ip -family inet -oneline link show | grep 'eth[0-9]' | cut -s -d ':' -f 2 | tr -s '[:space:]' ' '"
        )
        # Remove empty or effectively empty entries (otherwise it would be something like ["", "eth0", "eth1"]):
        @available_interfaces = Builtins.filter(
          Builtins.toset(
            Builtins.splitstring(
              Ops.get_string(Printerlib.result, "stdout", ""),
              " "
            )
          )
        ) do |interface_name|
          "" != Builtins.filterchars(interface_name, Printer.alnum_chars)
        end
      else
        @available_interfaces = []
      end
      Builtins.y2milestone("available_interfaces: %1", @available_interfaces)
      Builtins.y2milestone(
        "Initial initial_allow_input_value: %1",
        @initial_allow_input_value
      )
      UI.ChangeWidget(Id(:allow_input), :Value, @initial_allow_input_value)
      Builtins.y2milestone(
        "Initial initial_browse_address_input_value: %1",
        @initial_browse_address_input_value
      )
      UI.ChangeWidget(
        Id(:browse_address_input),
        :Value,
        @initial_browse_address_input_value
      )
      Builtins.y2milestone(
        "Initial browse_address_values: %1",
        browse_address_values
      )
      Builtins.y2milestone("leaving initSharing")

      nil
    end

    def handleSharing(key, event)
      event = deep_copy(event)
      Builtins.y2milestone(
        "entering handleSharing with key '%1'\nand event '%2'",
        key,
        event
      )
      if "ValueChanged" == Ops.get_string(event, "EventReason", "")
        case Ops.get_symbol(event, "WidgetID", :nil)
          when :allow_local_network_access_check_box
            if !Convert.to_boolean(
                UI.QueryWidget(:allow_local_network_access_check_box, :Value)
              )
              # if the allow_local_network_access_check_box is set to false
              # because it makes no sense to publish to the local network
              # but not to allow access from the local network:
              UI.ChangeWidget(
                :publish_to_local_network_check_box,
                :Value,
                false
              )
            end
          when :publish_to_local_network_check_box
            if Convert.to_boolean(
                UI.QueryWidget(:publish_to_local_network_check_box, :Value)
              )
              # if the publish_to_local_network_check_box is set to true
              # because it makes no sense to publish to the local network
              # but not to allow access from the local network:
              UI.ChangeWidget(
                :allow_local_network_access_check_box,
                :Value,
                true
              )
            end
        end
      end
      if "Activated" == Ops.get_string(event, "EventReason", "")
        if :abort == Ops.get(event, "ID") || :cancel == Ops.get(event, "ID") ||
            :back == Ops.get(event, "ID")
          # There is only a "Cancel" functionality (via the "back" button) which goes back one step
          # and the button with the "abort" functionality is not shown at all (see dialogs.ycp).
          # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
          # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
          # so that this case is mapped to the "Cancel" functionality:
          return :sharing_back
        end
        if :next == Ops.get(event, "ID")
          if !ApplySharingSettings()
            Popup.Error(_("Failed to apply the settings to the system."))
          end
          if !@sharing_has_changed
            Builtins.y2milestone("Nothing changed in 'Share Printers' dialog.")
          end
          return :sharing_next
        end
        case Ops.get_symbol(event, "WidgetID", :nil)
          when :add_interface
            @current_item = Convert.to_integer(
              UI.QueryWidget(:interface_table, :CurrentItem)
            )
            @interface_map = showInterfacePopup("", false)
            @is_in_table = false
            if @interface_map != nil
              @interface_table_items = []
              Builtins.foreach(
                Convert.convert(
                  UI.QueryWidget(:interface_table, :Items),
                  :from => "any",
                  :to   => "list <term>"
                )
              ) do |interface_table_item|
                if Ops.get(@interface_map, "interface_name", "new") !=
                    Ops.get_string(interface_table_item, 1, "old")
                  @interface_table_items = Builtins.add(
                    @interface_table_items,
                    Item(
                      Id(Builtins.size(@interface_table_items)),
                      Ops.get_string(interface_table_item, 1, ""),
                      Ops.get_string(interface_table_item, 2, "")
                    )
                  )
                else
                  @is_in_table = true
                  Builtins.y2milestone(
                    "Changing interface_table_item %1 with interface_map %2",
                    interface_table_item,
                    @interface_map
                  )
                  @interface_table_items = Builtins.add(
                    @interface_table_items,
                    Item(
                      Id(Builtins.size(@interface_table_items)),
                      Ops.get(@interface_map, "interface_name", ""),
                      Ops.get(@interface_map, "is_published", "")
                    )
                  )
                end
              end 

              if !@is_in_table
                Builtins.y2milestone("Adding interface_map %1", @interface_map)
                @interface_table_items = Builtins.add(
                  @interface_table_items,
                  Item(
                    Id(Builtins.size(@interface_table_items)),
                    Ops.get(@interface_map, "interface_name", ""),
                    Ops.get(@interface_map, "is_published", "")
                  )
                )
                @current_item = Ops.subtract(
                  Builtins.size(@interface_table_items),
                  1
                )
              end
              UI.ChangeWidget(:interface_table, :Items, @interface_table_items)
              UI.ChangeWidget(:interface_table, :CurrentItem, @current_item)
            end
          when :edit_interface
            @current_item = Convert.to_integer(
              UI.QueryWidget(:interface_table, :CurrentItem)
            )
            @interface_item = Convert.to_term(
              UI.QueryWidget(:interface_table, term(:Item, @current_item))
            )
            @interface_map = showInterfacePopup(
              Ops.get_string(@interface_item, 1, ""),
              Ops.get_string(@interface_item, 2, "no") == "yes"
            )
            if @interface_map != nil
              @interface_table_items = []
              Builtins.foreach(
                Convert.convert(
                  UI.QueryWidget(:interface_table, :Items),
                  :from => "any",
                  :to   => "list <term>"
                )
              ) do |interface_table_item|
                if @current_item !=
                    Ops.get_integer(interface_table_item, [0, 0], -1)
                  @interface_table_items = Builtins.add(
                    @interface_table_items,
                    Item(
                      Id(Builtins.size(@interface_table_items)),
                      Ops.get_string(interface_table_item, 1, ""),
                      Ops.get_string(interface_table_item, 2, "")
                    )
                  )
                else
                  Builtins.y2milestone(
                    "Changing interface_table_item %1 with interface_map %2",
                    interface_table_item,
                    @interface_map
                  )
                  @interface_table_items = Builtins.add(
                    @interface_table_items,
                    Item(
                      Id(Builtins.size(@interface_table_items)),
                      Ops.get(@interface_map, "interface_name", ""),
                      Ops.get(@interface_map, "is_published", "")
                    )
                  )
                end
              end 

              UI.ChangeWidget(:interface_table, :Items, @interface_table_items)
              UI.ChangeWidget(:interface_table, :CurrentItem, @current_item)
            end
          when :delete_interface
            @current_item = Convert.to_integer(
              UI.QueryWidget(:interface_table, :CurrentItem)
            )
            if @current_item != nil && Ops.greater_than(@current_item, -1)
              @interface_table_items = []
              Builtins.foreach(
                Convert.convert(
                  UI.QueryWidget(:interface_table, :Items),
                  :from => "any",
                  :to   => "list <term>"
                )
              ) do |interface_table_item|
                if @current_item !=
                    Ops.get_integer(interface_table_item, [0, 0], -1)
                  @interface_table_items = Builtins.add(
                    @interface_table_items,
                    Item(
                      Id(Builtins.size(@interface_table_items)),
                      Ops.get_string(interface_table_item, 1, ""),
                      Ops.get_string(interface_table_item, 2, "")
                    )
                  )
                else
                  Builtins.y2milestone(
                    "Deleting interface_table_item %1",
                    interface_table_item
                  )
                end
              end 

              UI.ChangeWidget(:interface_table, :Items, @interface_table_items)
            else
              Builtins.y2error(
                "Unproper index for current interface table item: %1",
                @current_item
              )
            end
        end
      end
      if !@share_printers_dialog_is_useless
        # boolean remote_access=(`allow_remote_access_radio_button==UI::QueryWidget(`deny_or_allow_remote_access,`CurrentButton));
        # Reason: At least with openSUSE 11.0 and Qt
        # it is possible to un-check all buttons in a RadioButtonGroup
        # by clicking on the currently checked button which un-checks it
        # so that there might be no CurrentButton which leads to unexpected results.
        # Therefore the actual button is tested directly to be on the safe side.
        # But even this does not work really well.
        # The reason is that un-checking the currently checked button
        # does not trigger any event even not with "`opt(`notify, `immediate)"
        # so that this special action is unnoticed.
        remote_access = Convert.to_boolean(
          UI.QueryWidget(:allow_remote_access_radio_button, :Value)
        )
        UI.ChangeWidget(:allow_remote_access_label, :Enabled, remote_access)
        UI.ChangeWidget(
          :allow_local_network_access_check_box,
          :Enabled,
          remote_access
        )
        UI.ChangeWidget(
          :publish_to_local_network_check_box,
          :Enabled,
          remote_access
        )
        UI.ChangeWidget(:interface_table_label, :Enabled, remote_access)
        UI.ChangeWidget(:interface_table, :Enabled, remote_access)
        UI.ChangeWidget(:add_interface, :Enabled, remote_access)
        UI.ChangeWidget(:edit_interface, :Enabled, remote_access)
        UI.ChangeWidget(:delete_interface, :Enabled, remote_access)
        UI.ChangeWidget(:specific_addresses_label, :Enabled, remote_access)
        UI.ChangeWidget(:allow_input, :Enabled, remote_access)
        UI.ChangeWidget(:browse_address_input, :Enabled, remote_access)
        if remote_access
          interface_modify_buttons = true
          if 0 ==
              Builtins.size(
                Convert.to_list(UI.QueryWidget(:interface_table, :Items))
              )
            interface_modify_buttons = false
          end
          UI.ChangeWidget(:edit_interface, :Enabled, interface_modify_buttons)
          UI.ChangeWidget(:delete_interface, :Enabled, interface_modify_buttons)
        end
      end
      nil
    end
  end
end

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

# File:        include/printer/printingvianetwork.ycp
# Package:     Configuration of printer
# Summary:     Printing via network dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>

require "shellwords"

module Yast
  module PrinterPrintingvianetworkInclude
    def initialize_printer_printingvianetwork(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Popup"

      Yast.include include_target, "printer/helps.rb"

      @printing_via_network_has_changed = false
      @initial_browsing = false
      @initial_browse_allow = nil
      @initial_browse_allow_input_value = ""
      @initial_browse_poll = false
      @initial_browse_poll_input_value = ""
      @initial_client_only = false
      @initial_client_conf_input_value = ""
      @browsing_firewall_popup_was_shown = false
      # An entry for a ComboBox from which the user can select
      # that printer information is not accepted from any remote CUPS servers:
      @browse_allow_none_string = _("do not accept any printer announcement")
      # An entry for a ComboBox from which the user can select
      # that printer information is accepted from
      # all remote CUPS servers:
      @browse_allow_all_string = _("accept all announcements from anywhere")
      # An entry for a ComboBox from which the user can select
      # that printer information is accepted from
      # remote CUPS servers in the local network:
      @browse_allow_local_string = _(
        "accept from all hosts in the local network"
      )
      # An entry for a ComboBox from which the user can select
      # that printer information is accepted only from
      # remote CUPS servers with specific addresses
      # where the specific addresses are specified in a TextEntry below:
      @browse_allow_specific_string = _(
        "accept only from the specific addresses below"
      )

      @widgetNetworkPrinting = VBox(
        VStretch(),
        Frame(
          _("Use CUPS to Print Via Network"),
          VBox(
            Left(
              CheckBox(
                Id(:browsing_check_box),
                Opt(:notify),
                # A CheckBox to accept printer information from remote CUPS servers:
                _("&Accept Printer Announcements from CUPS Servers"),
                true
              )
            ),
            Left(
              HBox(
                HSpacing(4),
                VBox(
                  Left(
                    ComboBox(
                      Id(:browse_allow_combo_box),
                      Opt(:notify),
                      # A header for a ComboBox from which the user can select
                      # a usual general setting from which remote CUPS servers
                      # printer information is accepted:
                      _("&General Setting"),
                      [
                        Item(
                          Id(:browse_allow_none),
                          @browse_allow_none_string,
                          true
                        ),
                        Item(Id(:browse_allow_all), @browse_allow_all_string),
                        Item(
                          Id(:browse_allow_local),
                          @browse_allow_local_string
                        ),
                        Item(
                          Id(:browse_allow_specific),
                          @browse_allow_specific_string
                        )
                      ]
                    )
                  ),
                  Left(
                    TextEntry(
                      Id(:browse_allow_input),
                      # A header for a TextEntry where the user can additionally
                      # enter specific IP addresses and/or network/netmask
                      # from where remote printer information is accepted:
                      _(
                        "Additional IP Addresses or &Network/Netmask (separated by space)"
                      )
                    )
                  )
                )
              )
            ),
            Left(
              CheckBox(
                Id(:browse_poll_check_box),
                Opt(:notify),
                # A CheckBox to poll printer information from remote CUPS servers:
                _("&Request Printer Information from CUPS Servers"),
                false
              )
            ),
            Left(
              HBox(
                HSpacing(4),
                TextEntry(
                  Id(:browse_poll_input),
                  # A header for a TextEntry where the user can enter
                  # CUPS server names and/or IP addresses
                  # from where remote printer information is polled:
                  _(
                    "Polled CUPS server names or &IP Addresses (separated by space)"
                  )
                )
              )
            ),
            Left(
              CheckBox(
                Id(:client_only_check_box),
                Opt(:notify),
                # A CheckBox to do all printing tasks directly
                # only via one single remote CUPS server:
                _("&Do All Printing Directly via One Single CUPS Server"),
                false
              )
            ),
            Left(
              HBox(
                HSpacing(4),
                TextEntry(
                  Id(:client_conf_input),
                  # A header for a TextEntry where the user can enter
                  # the one single remote CUPS server which is used
                  # to do all his printing tasks:
                  _("&One single CUPS server name or IP Address")
                ),
                VBox(
                  Label(""),
                  PushButton(
                    Id(:test_client_conf_server),
                    # A PushButton to test whether or not the one single remote CUPS server
                    # which is used to do all printing tasks is accessible:
                    _("&Test Server")
                  )
                ),
                HStretch()
              )
            )
          )
        ), # A caption for a Frame to set up to use CUPS to print via network:
        VStretch(),
        Frame(
          # or to set up to use a network printer directly:
          _("Use Another Print Server or Use a Network Printer Directly"),
          Left(
            PushButton(
              Id(:connection_wizard),
              # Label of a PushButton to go to the "Connection Wizard"
              # to specify the printer connection individually:
              _("Connection &Wizard")
            )
          )
        ), # A caption for a Frame to set up to use another (i.e. non-CUPS) print server
        VStretch()
      )
    end

    def ShowBrowsingFirewallPopup
      if Printerlib.FirewallSeemsToBeActive
        Popup.AnyMessage(
          # Use the exact same wording "printer announcements from CUPS servers"
          # as in the matching CheckBox to accept printer information from remote CUPS servers:
          _("A firewall may reject printer announcements from CUPS servers"),
          # Popup::AnyMessage message:
          _("Regarding firewall setup see the help text of this dialog.")
        )
        return true
      end
      false
    end

    def ApplyNetworkPrintingSettings
      current_browsing = Convert.to_boolean(
        UI.QueryWidget(Id(:browsing_check_box), :Value)
      )
      current_browse_allow = UI.QueryWidget(Id(:browse_allow_combo_box), :Value)
      current_browse_allow_input_value = Convert.to_string(
        UI.QueryWidget(Id(:browse_allow_input), :Value)
      )
      current_browse_poll = Convert.to_boolean(
        UI.QueryWidget(Id(:browse_poll_check_box), :Value)
      )
      current_browse_poll_input_value = Convert.to_string(
        UI.QueryWidget(Id(:browse_poll_input), :Value)
      )
      current_client_only = Convert.to_boolean(
        UI.QueryWidget(Id(:client_only_check_box), :Value)
      )
      current_client_conf_input_value = Convert.to_string(
        UI.QueryWidget(Id(:client_conf_input), :Value)
      )
      Builtins.y2milestone(
        "ApplyNetworkPrintingSettings with\n" +
          "current_browsing = '%1'\n" +
          "current_browse_allow = '%2'\n" +
          "current_browse_allow_input_value = '%3'\n" +
          "current_browse_poll = '%4'\n" +
          "current_browse_poll_input_value = '%5'\n" +
          "current_client_only = '%6'\n" +
          "current_client_conf_input_value = '%7'",
        current_browsing,
        current_browse_allow,
        current_browse_allow_input_value,
        current_browse_poll,
        current_browse_poll_input_value,
        current_client_only,
        current_client_conf_input_value
      )
      # Sanitise the BrowseAllow and BrowsePoll values.
      # Changes in the ordering (e.g. from 'host2 host1' to 'host1 host2')
      # are ignored because toset() sorts the list and removes duplicates.
      # Changes in the case (e.g. from 'host' to 'Host') are not ignored because
      # the user may like to have it exactly in cupsd.conf (even if actually case may not matter):
      initial_browse_allow_value = Builtins.mergestring(
        Builtins.toset(
          Builtins.splitstring(@initial_browse_allow_input_value, " ")
        ),
        " "
      )
      current_browse_allow_value = Builtins.mergestring(
        Builtins.toset(
          Builtins.splitstring(current_browse_allow_input_value, " ")
        ),
        " "
      )
      initial_browse_poll_value = Builtins.mergestring(
        Builtins.toset(
          Builtins.splitstring(@initial_browse_poll_input_value, " ")
        ),
        " "
      )
      current_browse_poll_value = Builtins.mergestring(
        Builtins.toset(
          Builtins.splitstring(current_browse_poll_input_value, " ")
        ),
        " "
      )
      # Sanitise the "client only" value.
      # Keep only the first server name if there is more than one server name:
      initial_client_conf_value = Ops.get(
        Builtins.toset(
          Builtins.splitstring(@initial_client_conf_input_value, " ")
        ),
        0,
        ""
      )
      current_client_conf_value = Ops.get(
        Builtins.toset(
          Builtins.splitstring(current_client_conf_input_value, " ")
        ),
        0,
        ""
      )
      Builtins.y2milestone(
        "ApplyNetworkPrintingSettings with sanitised values:\n" +
          "initial_browse_allow_value = '%1'\n" +
          "current_browse_allow_value = '%2'\n" +
          "initial_browse_poll_value = '%3'\n" +
          "current_browse_poll_value = '%4'\n" +
          "initial_client_conf_value = '%5'\n" +
          "current_client_conf_value = '%6'",
        initial_browse_allow_value,
        current_browse_allow_value,
        initial_browse_poll_value,
        current_browse_poll_value,
        initial_client_conf_value,
        current_client_conf_value
      )
      # Test if something meaningful has changed.
      # It is meaningful if an item (BrowseAllow, BrowsePoll or "client only")
      # was activated which was initially deactivated or vice versa.
      # It is meaningful if a value for an activated item was changed.
      # But it is meaningless if a value for a deactivated item was changed.
      # I.e. if a value for BrowseAllow, BrowsePoll or the client only server name was changed
      # but then the whole item was deactivated via its check box
      # the change of the value is meaningless and the changed value will not be written.
      if current_browsing != @initial_browsing ||
          current_browse_poll != @initial_browse_poll ||
          current_client_only != @initial_client_only ||
          current_browsing && current_browse_allow != @initial_browse_allow ||
          current_browsing &&
            current_browse_allow_value != initial_browse_allow_value ||
          current_browse_poll &&
            current_browse_poll_value != initial_browse_poll_value ||
          current_client_only &&
            current_client_conf_value != initial_client_conf_value
        @printing_via_network_has_changed = true
      else
        @printing_via_network_has_changed = false
        # Nothing has changed:
        return true
      end
      # First of all handle the client-only config
      # when the client-only item is enabled and exit this function
      # when there is an effectively non-empty server name value
      # because anything else (BrowseAllow, BrowsePoll) is meningless because
      # those items are automatically disabled when client-only is enabled.
      # When a real client-only config (when the server name is not "localhost" or "127.0.0.1")
      # is set up, the local cupsd is stopped so that any BrowseAllow and BrowsePoll stuff
      # becomes effectively disabled (during shutdown cupsd also stops cups-polld processes).
      # Is is not posible to change BrowseAllow and/or BrowsePoll values
      # in the dialog first and then switch to a client-only config but
      # get the changed BrowseAllow and/or BrowsePoll values written nevertheless.
      # A switch to a client-only config leaves the existing BrowseAllow
      # and/or BrowsePoll values in /etc/cups/cupsd.conf unchanged.
      # This behaviour is more reasonable than the other one
      # because the other behaviour seems oversophisticated because
      # a switch to client-only grays out the BrowseAllow and/or BrowsePoll widgets
      # which should have the meaning that the matching values are now out of scope.
      if current_client_only && !@initial_client_only ||
          current_client_only &&
            current_client_conf_value != initial_client_conf_value
        # or it was initially a client-only config but its server name value changed:
        if "" == current_client_conf_value ||
            "none" == Builtins.tolower(current_client_conf_value)
          if !@initial_client_only
            # to a client-only config but with an effectively empty server name.
            # Such a client-only config does not make sense:
            Popup.Error(_("A valid CUPS server name must be entered."))
            return false
          end
          # It was initially a client-only config but the user has
          # changed the server name value to be effectively empty.
          # This is the same as to turn off the client-only config
          # so that the "turn off client-only" case below is triggered here:
          @initial_client_only = true
          current_client_only = false
        else
          enforce_client_only_server_setting = false
          # A non-accessible client-only server leads to an endless sequence of weird further behaviour
          # of the module so that a non-accessible server is not accepted.
          # This means that it is not possible to set up a client-only config first
          # and then make the client-only server accessible (e.g. boot the client-only server,
          # open ports in firewall, set up the network connection, whatever else).
          # This would be a problem when a workstation is set up by an admin in the IP department
          # for a client-only config but the workstation is currently not connected to the network
          # where the client-only server is (e.g. in the department for which the workstation is set up).
          # Therefore the admin can force YaST to proceed here.
          # Do not show additional error messages here because Printer::TestClientOnlyServer()
          # shows sufficient popups to the user:
          if !Printer.TestClientOnlyServer(current_client_conf_value)
            if !Popup.ContinueCancelHeadline(
                Builtins.sformat(
                  # when a client-only server is not accessible
                  # where %1 will be replaced by the server name:
                  _("Continue regardless that '%1' is not accessible?"),
                  current_client_conf_value
                ), # Header of a Popup::ContinueCancelHeadline
                # Body of a Popup::ContinueCancelHeadline
                # when a client-only server is not accessible:
                _(
                  "A non-accessible server leads to an endless sequence of failures."
                )
              )
              return false
            end
            # The user has decided to continue regardless that the client-only server is not accessible:
            enforce_client_only_server_setting = true
          end
          if !@initial_client_only
            # but now the user has switched to "client-only".
            # If the server name is not "localhost" and not "127.0.0.1"
            # a real client-only config is to be set up and then
            # a possibly running local cupsd will be stopped.
            if "localhost" != Builtins.tolower(current_client_conf_value) &&
                "127.0" != Builtins.substring(current_client_conf_value, 0, 5)
              if Printerlib.GetAndSetCupsdStatus("")
                return false if !Printerlib.GetAndSetCupsdStatus("stop")
              end
            end
          end
          if !Printerlib.ExecuteBashCommand(
               Printerlib.yast_bin_dir + "cups_client_only " + current_client_conf_value.shellescape
            )
            if enforce_client_only_server_setting
              # In this case the cups_client_only tool fails in any case because it also tests accessibility.
              # But the cups_client_only tool might have failed for whatever other reason.
              # Therefore a Popup::MessageDetails is shown to inform about the actual result:
              Popup.MessageDetails(
                # where %1 will be replaced by the server name.
                Builtins.sformat(
                  _("Tried to set 'ServerName %1' in /etc/cups/client.conf."),
                  current_client_conf_value
                ),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
              # Exit successfully in this special case regardless of whatever failures:
              return true
            end
            Popup.ErrorDetails(
              # where %1 will be replaced by the server name.
              Builtins.sformat(
                _("Failed to set 'ServerName %1' in /etc/cups/client.conf."),
                current_client_conf_value
              ),
              Ops.get_string(Printerlib.result, "stderr", "")
            )
            return false
          end
          # Exit successfully by default and as fallback:
          return true
        end
        # A client-only config with effectively empty server name value continues here
        # and triggers the following "turn off client-only" case:
      end
      # Before handling BrowseAllow and/or BrowsePoll
      # turn off the client-only config
      # if the user had disabled the client-only item:
      if @initial_client_only && !current_client_only
        # but now the user has deactivated it
        # so that the client-only config should be disabled:
        if !Popup.YesNoHeadline(
            # where %1 will be replaced by the server name:
            Builtins.sformat(
              _("Disable Remote CUPS Server '%1'"),
              Printerlib.client_conf_server_name
            ),
            # PopupYesNoHeadline body:
            _(
              "The checkbox to do all printing via one CUPS server was disabled."
            )
          )
          return false
        end
        # Remove the 'ServerName' entry in /etc/cups/client.conf:
        if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "cups_client_only none")
          Popup.ErrorDetails(
            _(
              "Failed to remove the 'ServerName' entry in /etc/cups/client.conf"
            ),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        # The local cupsd is not started here because it is not clear at this point
        # if a local running cupsd is really needed. E.g. when both Browsing and BrowsePoll
        # are also disabled, there is no need to start the local cupsd in this dialog.
        # Other dialogs are on their own to start the local cupsd if needed,
        # see the "Different Workflow What Actually Happens" section at
        # http://en.opensuse.org/Archive:YaST_Printer_redesign#Basic_Implementation_Principles:
      end
      # When handling both BrowseAllow and BrowsePoll
      # the cupsd may need to be started or restarted in both cases.
      # But actually the cupsd should be at most once started or restarted
      # for both BrowseAllow and BrowsePoll at the very end:
      printing_via_network_restart_running_cupsd = false
      printing_via_network_needs_running_cupsd = false
      # Handle BrowseAllow:
      if current_browsing && !@initial_browsing ||
          current_browsing && current_browse_allow != @initial_browse_allow ||
          current_browsing &&
            current_browse_allow_value != initial_browse_allow_value
        # or it was initially a BrowseAllow config but its values changed:
        if :browse_allow_none == current_browse_allow
          # This is the same as to disable the BrowseAllow config
          # so that the "BrowseAllow config should be disabled" case below is triggered here:
          @initial_browsing = true
          current_browsing = false
        else
          if :browse_allow_all == current_browse_allow
            current_browse_allow_value = "all"
          end
          if :browse_allow_local == current_browse_allow
            if "" !=
                Builtins.filterchars(
                  current_browse_allow_value,
                  Printer.alnum_chars
                )
              current_browse_allow_value = Ops.add(
                current_browse_allow_value,
                " @LOCAL"
              )
            else
              current_browse_allow_value = "@LOCAL"
            end
          end
          # Write to cupsd.conf only if the current_browse_allow_value is effectively non-empty:
          if "" !=
              Builtins.filterchars(
                current_browse_allow_value,
                Printer.alnum_chars
              )
            # test whether or not a firewall seems to be active and
            # if yes show a popup regarding firewall if it was not yet shown:
            if !@browsing_firewall_popup_was_shown
              if ShowBrowsingFirewallPopup()
                @browsing_firewall_popup_was_shown = true
              end
            end
            # An effectively non-empty current_browse_allow_value requires "Browsing On" in cupsd.conf:
            if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "modify_cupsd_conf Browsing On")
              Popup.ErrorDetails(
                _("Failed to set 'Browsing On' in /etc/cups/cupsd.conf."),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
              return false
            end
            # Write the BrowseAllow values to cupsd.conf:
            if !Printerlib.ExecuteBashCommand(
                 Printerlib.yast_bin_dir + "modify_cupsd_conf BrowseAllow " + current_browse_allow_value.shellescape
              )
              Popup.ErrorDetails(
                # where %1 will be replaced by the values for BrowseAllow.
                Builtins.sformat(
                  _(
                    "Failed to set BrowseAllow value(s) '%1' in /etc/cups/cupsd.conf."
                  ),
                  current_browse_allow_value
                ),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
              return false
            end
            # An effectively non-empty current_browse_allow_value requires a local running cupsd:
            printing_via_network_needs_running_cupsd = true
          end
        end
      end
      if @initial_browsing && !current_browsing
        # but now the user has deactivated it
        # so that the BrowseAllow config should be disabled.
        # Do not change the global "Browsing On/Off" entry in cupsd.conf
        # because "Browsing Off" disables also sharing of local printers
        # which might be needed by the "Share Printers" dialog.
        # Instead set only "BrowseAllow none" in cupsd.conf:
        if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "modify_cupsd_conf BrowseAllow none")
          Popup.ErrorDetails(
            _("Failed to set 'BrowseAllow none' in /etc/cups/cupsd.conf."),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        printing_via_network_restart_running_cupsd = true
      end
      # Handle BrowsePoll:
      if current_browse_poll && !@initial_browse_poll ||
          current_browse_poll &&
            current_browse_poll_value != initial_browse_poll_value
        # or it was initially a BrowsePoll config but its server name values changed:
        if "" == current_browse_poll_value ||
            "none" == Builtins.tolower(current_browse_poll_value)
          if !@initial_browse_poll
            # a BrowsePoll config but with effectively empty server names.
            # Such a BrowsePoll config does not make sense:
            Popup.Error(
              _("At least one valid CUPS server name must be entered.")
            )
            return false
          end
          # It was initially a BrowsePoll config but the user has
          # changed the server name values to be effectively empty.
          # This is the same as to turn off the BrowsePoll config so that
          # the "BrowsePoll config should be disabled" case below is triggered here:
          @initial_browse_poll = true
          current_browse_poll = false
        else
          if "" !=
              Builtins.filterchars(
                current_browse_poll_value,
                Printer.alnum_chars
              )
            if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "modify_cupsd_conf Browsing On")
              Popup.ErrorDetails(
                _("Failed to set 'Browsing On' in /etc/cups/cupsd.conf."),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
              return false
            end
            # Write the BrowsePoll values to cupsd.conf:
            if !Printerlib.ExecuteBashCommand(
                 Printerlib.yast_bin_dir + "modify_cupsd_conf BrowsePoll " + current_browse_poll_value.shellescape
               )
              Popup.ErrorDetails(
                # where %1 will be replaced by the values for BrowsePoll.
                Builtins.sformat(
                  _(
                    "Failed to set BrowsePoll value(s) '%1' in /etc/cups/cupsd.conf"
                  ),
                  current_browse_poll_value
                ),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
              return false
            end
            # An effectively non-empty current_browse_poll_value requires a local running cupsd:
            printing_via_network_needs_running_cupsd = true
          end
        end
      end
      if @initial_browse_poll && !current_browse_poll
        # but now the user has deactivated it
        # so that the BrowsePoll config should be disabled:
        # Set only "BrowsePoll none" in cupsd.conf:
        if !Printerlib.ExecuteBashCommand(Printerlib.yast_bin_dir + "modify_cupsd_conf BrowsePoll none")
          Popup.ErrorDetails(
            _("Failed to set 'BrowsePoll none' in /etc/cups/cupsd.conf"),
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          return false
        end
        printing_via_network_restart_running_cupsd = true
      end
      # Make sure cupsd is running:
      if printing_via_network_needs_running_cupsd
        if Printerlib.GetAndSetCupsdStatus("")
          return false if !Printerlib.GetAndSetCupsdStatus("restart")
        else
          return false if !Printerlib.GetAndSetCupsdStatus("start")
        end
        # Exit successfully by default and as fallback:
        return true
      end
      # Restart cupsd only when it is already running:
      if printing_via_network_restart_running_cupsd
        # otherwise do nothing (i.e. leave it stopped) because
        # disabling of a BrowseAllow or BrowsePoll config
        # does not require a running cupsd.
        # Other dialogs are on their own to start the local cupsd if needed,
        # see the "Different Workflow What Actually Happens" section at
        # http://en.opensuse.org/Archive:YaST_Printer_redesign#Basic_Implementation_Principles:
        if Printerlib.GetAndSetCupsdStatus("")
          return false if !Printerlib.GetAndSetCupsdStatus("restart")
          # A "accept browsing info" config with a local running cupsd
          # was switched to a "not accept browsing info" config or
          # a BrowsePoll config with a local running cupsd was disabled.
          # A cups-polld polls remote servers for a list of available printer queues.
          # Those information is then broadcast to the localhost interface (127.0.0.1)
          # on the specified browse port for reception by the local cupsd.
          # Theerfore for the cupsd BrowsePoll information is the same
          # as the usual Browsing information via BrowseAllow.
          # The default BrowseTimeout value for the local cupsd is 5 minutes.
          # Therefore it takes by default 5 minutes until printer information
          # that was previously received by Browsing is removed (via timeout)
          # from the local cupsd's list.
          # I assume most users do not like to wait 5 minutes which is no problem
          # because they can just click the [OK] button to continue but then
          # they are at least informend why there may be still remote queues:
          Popup.TimedMessage(
            _(
              "When switching from 'accept printer announcements' to 'not accept announcements'\n" +
                "or after 'request printer information from CUPS servers' was disabled\n" +
                "it takes usually 5 minutes until already received information faded away..."
            ),
            300
          )
        end
      end
      # Exit successfully by default and as fallback:
      true
    end

    def initNetworkPrinting(key)
      Builtins.y2milestone("entering initNetworkPrinting with key '%1'", key)
      # Determine the 'Browsing [ On | Off ]' value in /etc/cups/cupsd.conf
      # and ignore when it fails (i.e. use the fallback value silently):
      Printerlib.DetermineBrowsing
      # Determine the 'BrowseAllow [ all | none | @LOCAL | IP-address[/netmask] ]'
      # values in /etc/cups/cupsd.conf and ignore when it fails (i.e. use the fallback value silently):
      Printerlib.DetermineBrowseAllow
      # Determine the 'BrowsePoll [IP-address]' values in /etc/cups/cupsd.conf
      # and ignore when it fails (i.e. use the fallback value silently):
      Printerlib.DetermineBrowsePoll
      # Determine the 'ServerName' value in /etc/cups/client.conf
      # and ignore when it fails (i.e. use the fallback value silently):
      Printerlib.DetermineClientOnly
      Builtins.y2milestone(
        "system values in initNetworkPrinting:\n" +
          "cupsd_conf_browsing_on = '%1'\n" +
          "cupsd_conf_browse_allow = '%2'\n" +
          "cupsd_conf_browse_poll = '%3'\n" +
          "client_only = '%4'\n" +
          "client_conf_server_name = '%5'",
        Printerlib.cupsd_conf_browsing_on,
        Printerlib.cupsd_conf_browse_allow,
        Printerlib.cupsd_conf_browse_poll,
        Printerlib.client_only,
        Printerlib.client_conf_server_name
      )
      # Have all widgets disabled initially and preset them with fallback values here
      # but nevertheless fill in the values of the current settings in the system later
      # regardless if a widget is disabled or not, see "Make the actual ... settings" below:
      UI.ChangeWidget(Id(:browsing_check_box), :Value, false)
      @initial_browsing = false
      UI.ChangeWidget(Id(:browse_allow_combo_box), :Enabled, false)
      UI.ChangeWidget(
        Id(:browse_allow_combo_box),
        :Value,
        Id(:browse_allow_specific)
      )
      @initial_browse_allow = :browse_allow_specific
      UI.ChangeWidget(Id(:browse_allow_input), :Enabled, false)
      UI.ChangeWidget(Id(:browse_allow_input), :Value, "")
      @initial_browse_allow_input_value = ""
      UI.ChangeWidget(Id(:browse_poll_check_box), :Value, false)
      @initial_browse_poll = false
      UI.ChangeWidget(Id(:browse_poll_input), :Enabled, false)
      UI.ChangeWidget(Id(:browse_poll_input), :Value, "")
      @initial_browse_poll_input_value = ""
      UI.ChangeWidget(Id(:client_only_check_box), :Value, false)
      @initial_client_only = false
      UI.ChangeWidget(Id(:client_conf_input), :Enabled, false)
      UI.ChangeWidget(Id(:client_conf_input), :Value, "")
      @initial_client_conf_input_value = ""
      UI.ChangeWidget(Id(:test_client_conf_server), :Enabled, false)
      # Only the "Connection Wizard" button is enabled by default
      # and disabled in case of "client_only" (see "Client only settings" below)
      # and also disabled in case of Printer::printer_auto_dialogs.
      UI.ChangeWidget(Id(:connection_wizard), :Enabled, true)
      # Make the actual Browsing settings:
      # If "none" is present as a BrowseAllow value it is actually no Browsing config.
      # If the BrowseAllow values are effectively empty it is also no Browsing config.
      # If  there is an active ServerName (!="localhost") in /etc/cups/client.conf
      # it is actually a client-only config and therefore also actually no Browsing config:
      if Printerlib.cupsd_conf_browsing_on &&
          !Builtins.contains(Printerlib.cupsd_conf_browse_allow, "none") &&
          "" !=
            Builtins.filterchars(
              Builtins.mergestring(Printerlib.cupsd_conf_browse_allow, ""),
              Printer.alnum_chars
            ) &&
          !Printerlib.client_only
        UI.ChangeWidget(Id(:browsing_check_box), :Value, true)
        @initial_browsing = true
        UI.ChangeWidget(Id(:browse_allow_combo_box), :Enabled, true)
        # When it is actually a Browsing config
        # test whether or not a firewall seems to be active and
        # if yes show a popup regarding firewall if it was not yet shown:
        if !@browsing_firewall_popup_was_shown
          if ShowBrowsingFirewallPopup()
            @browsing_firewall_popup_was_shown = true
          end
        end
      else
        # for the browse_allow_combo_box so that the user can easily switch
        # only via the browsing_check_box to a reasonable Browsing config
        # without the need for further adjustments in the browse_allow_combo_box:
        UI.ChangeWidget(
          Id(:browse_allow_combo_box),
          :Value,
          Id(:browse_allow_local)
        )
        @initial_browse_allow = :browse_allow_local
        # The value of browsing_firewall_popup_was_shown is kept as long as the
        # whole yast2-printer module runs so that the user could launch this dialog
        # several times in one module run and switch between a Browsing config
        # and no Browsing config several times in one run of the yast2-printer module.
        # When in the previous run of this dialog a no Browsing config was set up
        # but in the current run of this dialog it was switched back to a Browsing config
        # make sure in the current run of this dialog the popup regarding firewall
        # is shown again during ApplyNetworkPrintingSettings():
        @browsing_firewall_popup_was_shown = false
      end
      # Fill in the Browsing values of the current settings in the system
      # regardless if it is actually a Browsing config or not (see above).
      # When by accident "all" and "@LOCAL" were set as BrowseAllow values,
      # the "@LOCAL" entry is preselected in browse_allow_combo_box
      # because this is the more secure setting.
      # When "none" is one of the BrowseAllow values,
      # the "none" entry is preselected in browse_allow_combo_box
      # because this is the most secure setting.
      if Builtins.contains(Printerlib.cupsd_conf_browse_allow, "all")
        UI.ChangeWidget(
          Id(:browse_allow_combo_box),
          :Value,
          Id(:browse_allow_all)
        )
        @initial_browse_allow = :browse_allow_all
        # If browsing info is accepted from "all" hosts
        # it would be useless to additionally accept it from specific IPs or networks.
      end
      if Builtins.contains(Printerlib.cupsd_conf_browse_allow, "@LOCAL")
        UI.ChangeWidget(
          Id(:browse_allow_combo_box),
          :Value,
          Id(:browse_allow_local)
        )
        @initial_browse_allow = :browse_allow_local
        UI.ChangeWidget(Id(:browse_allow_input), :Enabled, true)
      end
      if Builtins.contains(Printerlib.cupsd_conf_browse_allow, "none")
        UI.ChangeWidget(
          Id(:browse_allow_combo_box),
          :Value,
          Id(:browse_allow_none)
        )
        @initial_browse_allow = :browse_allow_none
        # If browsing info is accepted from "none" hosts
        # it would be contradicting to additionally accept it from specific IPs or networks.
      end
      # The preset entry in the browse_allow_input field
      # should not contain "all" or "@LOCAL" or "none"
      # because those are selectable via browse_allow_combo_box:
      browse_allow_input_value = Builtins.mergestring(
        Builtins.filter(Printerlib.cupsd_conf_browse_allow) do |value|
          value = Builtins.tolower(value)
          "all" != value && "@local" != value && "none" != value
        end,
        " "
      )
      if "" !=
          Builtins.filterchars(browse_allow_input_value, Printer.alnum_chars)
        browse_allow_input_value = Ops.add(browse_allow_input_value, " ")
        UI.ChangeWidget(Id(:browse_allow_input), :Enabled, true)
        UI.ChangeWidget(
          Id(:browse_allow_input),
          :Value,
          browse_allow_input_value
        )
        @initial_browse_allow_input_value = browse_allow_input_value
        if @initial_browse_allow != :browse_allow_none &&
            @initial_browse_allow != :browse_allow_all
          # it would be contradicting to accept it from specific IPs or networks
          # and if browsing info is accepted from all hosts,
          # it is useless to additionally accept it from specific IPs or networks:
          UI.ChangeWidget(Id(:browse_allow_input), :Enabled, true)
        end
      end
      # Make the actual BrowsePoll settings:
      browse_poll_input_value = Builtins.mergestring(
        Printerlib.cupsd_conf_browse_poll,
        " "
      )
      if "" !=
          Builtins.filterchars(browse_poll_input_value, Printer.alnum_chars)
        if !Printerlib.client_only
          # it is actually a client-only config and therefore also actually no Browsing config.
          UI.ChangeWidget(Id(:browse_poll_check_box), :Value, true)
          @initial_browse_poll = true
          UI.ChangeWidget(Id(:browse_poll_input), :Enabled, true)
        end
        # Have a trailing space character so that the user can easily add something:
        browse_poll_input_value = Ops.add(browse_poll_input_value, " ")
        # Fill in the BrowsePoll values of the current settings in the system
        # regardless if it is actually a BrowsePoll config or not (see above):
        UI.ChangeWidget(Id(:browse_poll_input), :Value, browse_poll_input_value)
        @initial_browse_poll_input_value = browse_poll_input_value
      end
      # Make the actual client-only settings:
      if Printerlib.client_only
        UI.ChangeWidget(Id(:client_only_check_box), :Value, true)
        @initial_client_only = true
        UI.ChangeWidget(Id(:client_conf_input), :Enabled, true)
        UI.ChangeWidget(Id(:test_client_conf_server), :Enabled, true)
        # The "Connection Wizard" button is disabled in case of "client_only".
        # In this case it is never again enabled as long as the dialog runs
        # because  the user can select one of the radio buttons
        # to receive or not receive printer information via CUPS Browsing
        # which would switch from "client_only" to a local running cupsd
        # but only when finishing the dialog via ApplyNetworkPrintingSettings().
        # Therefore in case of "client_only" to use a network printer directly
        # the user must first switch from "client_only" to a local running cupsd
        # (e.g. by changing the client-only server to the empty string or to 'none')
        # and close the dialog to apply this change and re-launch the dialog afterwards.
        UI.ChangeWidget(Id(:connection_wizard), :Enabled, false)
      end
      # Fill in the client-only values of the current settings in the system
      # regardless if it is actually a client-only config or not (see above):
      UI.ChangeWidget(
        Id(:client_conf_input),
        :Value,
        Printerlib.client_conf_server_name
      )
      if Printer.printer_auto_dialogs
        # (by calling in printer_auto.ycp the "Change" function)
        # it does not make sense to let the user set up a local queue
        # for a network printer via the "Connection Wizard":
        UI.ChangeWidget(Id(:connection_wizard), :Enabled, false)
      end
      @initial_client_conf_input_value = Printerlib.client_conf_server_name
      Builtins.y2milestone(
        "leaving initNetworkPrinting with\n" +
          "initial_browsing = '%1'\n" +
          "initial_browse_allow = '%2'\n" +
          "initial_browse_allow_input_value = '%3'\n" +
          "initial_browse_poll = '%4'\n" +
          "initial_browse_poll_input_value = '%5'\n" +
          "initial_client_only = '%6'\n" +
          "initial_client_conf_input_value = '%7'",
        @initial_browsing,
        @initial_browse_allow,
        @initial_browse_allow_input_value,
        @initial_browse_poll,
        @initial_browse_poll_input_value,
        @initial_client_only,
        @initial_client_conf_input_value
      )

      nil
    end

    def handleNetworkPrinting(key, event)
      event = deep_copy(event)
      Builtins.y2milestone(
        "entering handleNetworkPrinting with key '%1'\nand event '%2'",
        key,
        event
      )
      if "ValueChanged" == Ops.get_string(event, "EventReason", "")
        if :browsing_check_box == Ops.get(event, "ID")
          if Convert.to_boolean(UI.QueryWidget(:browsing_check_box, :Value))
            UI.ChangeWidget(Id(:browse_allow_combo_box), :Enabled, true)
            if :browse_allow_none ==
                UI.QueryWidget(Id(:browse_allow_combo_box), :Value) ||
                :browse_allow_all ==
                  UI.QueryWidget(Id(:browse_allow_combo_box), :Value)
              # it would be contradicting to accept it from specific IPs or networks
              # or if browsing info is accepted from all hosts,
              # it is useless to additionally accept it from specific IPs or networks:
              UI.ChangeWidget(Id(:browse_allow_input), :Enabled, false)
            else
              UI.ChangeWidget(Id(:browse_allow_input), :Enabled, true)
            end
            if !Printerlib.client_only && !Printer.printer_auto_dialogs
              # and disabled if currently a "client_only" config is active.
              # In this case it is never again enabled as long as the dialog runs, see above.
              # It is also disabled in case of Printer::printer_auto_dialogs
              # and then it must stay disabled as long as the dialog runs.
              UI.ChangeWidget(Id(:connection_wizard), :Enabled, true)
            end
            UI.ChangeWidget(Id(:client_only_check_box), :Value, false)
            UI.ChangeWidget(Id(:client_conf_input), :Enabled, false)
            UI.ChangeWidget(Id(:test_client_conf_server), :Enabled, false)
          else
            UI.ChangeWidget(Id(:browse_allow_combo_box), :Enabled, false)
            UI.ChangeWidget(Id(:browse_allow_input), :Enabled, false)
          end
        end
        if :browse_poll_check_box == Ops.get(event, "ID")
          if Convert.to_boolean(UI.QueryWidget(:browse_poll_check_box, :Value))
            UI.ChangeWidget(Id(:browse_poll_input), :Enabled, true)
            if !Printerlib.client_only && !Printer.printer_auto_dialogs
              # and disabled if currently a "client_only" config is active.
              # In this case it is never again enabled as long as the dialog runs, see above.
              # It is also disabled in case of Printer::printer_auto_dialogs
              # and then it must stay disabled as long as the dialog runs.
              UI.ChangeWidget(Id(:connection_wizard), :Enabled, true)
            end
            UI.ChangeWidget(Id(:client_only_check_box), :Value, false)
            UI.ChangeWidget(Id(:client_conf_input), :Enabled, false)
            UI.ChangeWidget(Id(:test_client_conf_server), :Enabled, false)
          else
            UI.ChangeWidget(Id(:browse_poll_input), :Enabled, false)
          end
        end
        if :client_only_check_box == Ops.get(event, "ID")
          if Convert.to_boolean(UI.QueryWidget(:client_only_check_box, :Value))
            UI.ChangeWidget(Id(:browsing_check_box), :Value, false)
            UI.ChangeWidget(Id(:browse_allow_combo_box), :Enabled, false)
            UI.ChangeWidget(Id(:browse_allow_input), :Enabled, false)
            UI.ChangeWidget(Id(:browse_poll_check_box), :Value, false)
            UI.ChangeWidget(Id(:browse_poll_input), :Enabled, false)
            UI.ChangeWidget(Id(:client_conf_input), :Enabled, true)
            UI.ChangeWidget(Id(:test_client_conf_server), :Enabled, true)
            UI.ChangeWidget(Id(:connection_wizard), :Enabled, false)
          else
            if Convert.to_boolean(UI.QueryWidget(:browsing_check_box, :Value))
              UI.ChangeWidget(Id(:browse_allow_combo_box), :Enabled, true)
              UI.ChangeWidget(Id(:browse_allow_input), :Enabled, true)
            end
            if Convert.to_boolean(
                UI.QueryWidget(:browse_poll_check_box, :Value)
              )
              UI.ChangeWidget(Id(:browse_poll_input), :Enabled, true)
            end
            if !Printerlib.client_only && !Printer.printer_auto_dialogs
              # and disabled if currently a "client_only" config is active.
              # In this case it is never again enabled as long as the dialog runs, see above.
              # It is also disabled in case of Printer::printer_auto_dialogs
              # and then it must stay disabled as long as the dialog runs.
              UI.ChangeWidget(Id(:connection_wizard), :Enabled, true)
            end
            UI.ChangeWidget(Id(:client_conf_input), :Enabled, false)
            UI.ChangeWidget(Id(:test_client_conf_server), :Enabled, false)
          end
        end
        if :browse_allow_combo_box == Ops.get(event, "ID")
          current_browse_allow = UI.QueryWidget(
            Id(:browse_allow_combo_box),
            :Value
          )
          if :browse_allow_none == current_browse_allow
            # it would be contradicting to accept it from specific IPs or networks:
            UI.ChangeWidget(Id(:browse_allow_input), :Enabled, false)
            # Furthermore the check box to accept printer information is un-checked:
            UI.ChangeWidget(Id(:browsing_check_box), :Value, false)
          end
          if :browse_allow_all == current_browse_allow
            # it is useless to additionally accept it from specific IPs or networks:
            UI.ChangeWidget(Id(:browse_allow_input), :Enabled, false)
            # Furthermore the check box to accept printer information is checked:
            UI.ChangeWidget(Id(:browsing_check_box), :Value, true)
          end
          if :browse_allow_local == current_browse_allow ||
              :browse_allow_specific == current_browse_allow
            # to additionally accept from specific IPs or networks:
            UI.ChangeWidget(Id(:browse_allow_input), :Enabled, true)
            # Furthermore the check box to accept printer information is checked:
            UI.ChangeWidget(Id(:browsing_check_box), :Value, true)
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
          return :printing_via_network_back
        end
        if :next == Ops.get(event, "ID")
          if !ApplyNetworkPrintingSettings()
            Popup.Error(_("Failed to apply the settings to the system."))
            # In case of an error stay on the "Print via Network" dialog
            # so that the user can either change his settings until it works
            # or he can use the [Cancel] button to return to the Overview dialog:
            #Does not work:
            #return nil;
          end
          if !@printing_via_network_has_changed
            Builtins.y2milestone(
              "Nothing changed in 'Printing via Network' dialog."
            )
          else
            # when something was to be changed,
            # enforce to show also remote queues in the "Overview"
            # in particular when no local queues were shown before:
            Printer.queue_filter_show_remote = true
          end
          return :printing_via_network_next
        end
        if :connection_wizard == Ops.get(event, "ID")
          # so that the getCurrentDeviceURI function in connectionwizard.ycp fails
          # to avoid that the URI of whatever preselected queue in the Overview dialog
          # becomes preselected in the Connection Wizard which should actually
          # start without any preselection because a new queue is to be set up
          # when the Connection Wizard is called from the Print via Network dialog:
          Printer.selected_connections_index = -1
          Printer.selected_queues_index = -1
          return :printing_via_network_connection_wizard
        end
        if :test_client_conf_server == Ops.get(event, "ID")
          current_client_conf_input_value = Convert.to_string(
            UI.QueryWidget(Id(:client_conf_input), :Value)
          )
          server_name = Builtins.deletechars(
            Builtins.tolower(current_client_conf_input_value),
            " "
          )
          # No need for error popups because TestClientOnlyServer shows sufficient error popups:
          if Printer.TestClientOnlyServer(server_name)
            Popup.Message(
              Builtins.sformat(
                # where %1 will be replaced by the server name.
                _("The server '%1' is accessible via port 631 (IPP/CUPS)."),
                server_name
              ) # Popup message
            )
          end
        end
      end
      nil
    end
  end
end

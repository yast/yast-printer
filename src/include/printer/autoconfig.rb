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

# File:        include/printer/dialogs.ycp
# Package:     Configuration of printer
# Summary:     Automatic Configuration dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>
#
# $Id: autoconfig.ycp 27914 2006-02-13 14:32:08Z locilka $
module Yast
  module PrinterAutoconfigInclude
    def initialize_printer_autoconfig(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Printerlib"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "printer/helps.rb"

      @widgetAutoconfig = VBox(
        VStretch(),
        Left(
          CheckBox(
            Id("printer_proposal_check_box"),
            Opt(:notify),
            # CheckBox to trigger an automatic configuration of local connected printers
            # by calling the YaST printer module autoconfig functionality right now.
            _("&Do an automatic configuration of local connected printers now"),
            # This trigger CheckBox is initially off in any case:
            false
          ) # CheckBox to let YaST configure local connected printers automatically:
        ),
        # Have space between the two parts of of the dialog:
        VStretch(),
        Left(
          Label(
            Id("autoconfig_label"),
            # Header for a dialog section where the user can
            # specify if USB printers are configured automatically:
            _(
              "Specify if automatic USB printer configuration should happen when plug in"
            )
          )
        ),
        Left(
          CheckBox(
            # Since openSUSE 11.2 cups-autoconfig is no longer available,
            # see https://bugzilla.novell.com/show_bug.cgi?id=526657
            Id("udev_configure_printer_check_box"),
            Opt(:notify),
            # CheckBox for automatic configuration of USB printers
            # by installing or removing the RPM package udev-configure-printer.
            # Do not change or translate "udev-configure-printer", it is a RPM package name.
            _(
              "&Use the package udev-configure-printer for automatic USB printer configuration"
            )
          ) # CheckBox to install or remove udev-configure-printer.
        ),
        # Have space between the content and the bottom of the dialog:
        VStretch()
      ) # Have space between the top of the dialog and the content:
    end

    def initAutoconfig(key)
      Builtins.y2milestone("entering initAutoconfig with key '%1'", key)
      autoconfig_dialog_is_useless = false
      # The whole Automatic Configuration dialog is useless if it is a "client-only" config.
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
              "A remote CUPS server setting conflicts with automatic configuration of printers for the local system."
            )
          )
          autoconfig_dialog_is_useless = true
          Builtins.y2milestone(
            "autoconfig_dialog_is_useless because user decided not to disable client-only CUPS server '%1'",
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
            autoconfig_dialog_is_useless = true
            Builtins.y2milestone(
              "autoconfig_dialog_is_useless because it failed to disable client-only CUPS server '%1'",
              Printerlib.client_conf_server_name
            )
          end
        end
      end
      # When it is no "client-only" config,
      # determine whether or not a local cupsd is accessible:
      if !autoconfig_dialog_is_useless
        if !Printerlib.GetAndSetCupsdStatus("")
          if !Printerlib.GetAndSetCupsdStatus("start")
            autoconfig_dialog_is_useless = true
            Builtins.y2milestone(
              "autoconfig_dialog_is_useless because 'rccups start' failed."
            )
          end
        end
      end
      # The CheckBox to trigger an automatic configuration of local connected printers
      # is initially off in any case:
      UI.ChangeWidget(Id("printer_proposal_check_box"), :Value, false)
      # Determine if udev-configure-printer is installed.
      udev_configure_printer_installed = Printerlib.TestAndInstallPackage(
        "udev-configure-printer",
        "installed"
      )
      # Avoid a flickering change of the udev_configure_printer_check_box value
      # by explicite if...else statements which do only one single UI::ChangeWidget
      # instead of a blind default setting which is changed afterwards:
      if udev_configure_printer_installed
        UI.ChangeWidget(Id("udev_configure_printer_check_box"), :Value, true)
      else
        UI.ChangeWidget(Id("udev_configure_printer_check_box"), :Value, false)
      end
      # Disable all widgets in the whole dialog if autoconfig_dialog_is_useless:
      if autoconfig_dialog_is_useless
        UI.ChangeWidget(Id("printer_proposal_check_box"), :Enabled, false)
        UI.ChangeWidget(Id("autoconfig_label"), :Enabled, false)
        UI.ChangeWidget(Id("udev_configure_printer_check_box"), :Enabled, false)
      end
      Builtins.y2milestone(
        "leaving initAutoconfig with udev_configure_printer_installed = '%1'",
        udev_configure_printer_installed
      )

      nil
    end

    def ApplyAutoconfigSettings
      package_name = "udev-configure-printer"
      if Convert.to_boolean(
          UI.QueryWidget(Id("udev_configure_printer_check_box"), :Value)
        )
        if !Printerlib.TestAndInstallPackage(package_name, "installed")
          Printerlib.TestAndInstallPackage(package_name, "install")
          # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
          # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
          # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
          # so that this leftover "abort" button must be explicitly hidden here:
          Wizard.HideAbortButton
        end
        if !Printerlib.TestAndInstallPackage(package_name, "installed")
          UI.ChangeWidget(Id("udev_configure_printer_check_box"), :Value, false)
          Popup.Error(_("Failed to install udev-configure-printer."))
          Builtins.y2milestone(
            "ApplyAutoconfigSettings failed to install '%1'",
            package_name
          )
          return false
        end
      else
        if Printerlib.TestAndInstallPackage(package_name, "installed")
          Printerlib.TestAndInstallPackage(package_name, "remove")
        end
        if Printerlib.TestAndInstallPackage(package_name, "installed")
          UI.ChangeWidget(Id("udev_configure_printer_check_box"), :Value, true)
          Popup.Error(_("Failed to remove udev-configure-printer."))
          Builtins.y2milestone(
            "ApplyAutoconfigSettings failed to remove '%1'",
            package_name
          )
          return false
        end
      end
      Builtins.y2milestone("leaving ApplyAutoconfigSettings successfully")
      true
    end

    def handleAutoconfig(key, event)
      event = deep_copy(event)
      Builtins.y2milestone(
        "entering handleAutoconfig with key '%1'\nand event '%2'",
        key,
        event
      )
      if "ValueChanged" == Ops.get_string(event, "EventReason", "")
        if "printer_proposal_check_box" == Ops.get_string(event, "WidgetID", "")
          queues_and_descriptions = ""
          # Call the YaST printer module autoconfig functionality:
          printer_proposal_result = Convert.to_map(
            WFM.CallFunction("printer_proposal", ["MakeProposal"])
          )
          Builtins.y2milestone(
            "handleAutoconfig printer_proposal_result = '%1'",
            printer_proposal_result
          )
          if printer_proposal_result != nil
            queues_and_descriptions_list = Convert.convert(
              Ops.get(printer_proposal_result, "raw_proposal") { [""] },
              :from => "any",
              :to   => "list <string>"
            )
            Builtins.foreach(queues_and_descriptions_list) do |queue_and_description|
              if "" != queue_and_description
                queues_and_descriptions = Ops.add(
                  Ops.add(queues_and_descriptions, "\n"),
                  queue_and_description
                )
              end
            end
          end
          if "" == queues_and_descriptions
            queues_and_descriptions = _(
              "The automated printer configuration was in vain."
            )
          end
          Popup.AnyMessage(
            _("Automated printer configuration results"),
            # Popup::AnyMessage message:
            queues_and_descriptions
          )
          # Re-set the CheckBox to trigger automatic configuration back to its initial state 'off':
          UI.ChangeWidget(Id("printer_proposal_check_box"), :Value, false)
        end
        if "udev_configure_printer_check_box" ==
            Ops.get_string(event, "WidgetID", "")
          ApplyAutoconfigSettings()
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
          return :autoconfig_back
        end
        return :autoconfig_next if :next == Ops.get(event, "ID")
      end
      nil
    end
  end
end

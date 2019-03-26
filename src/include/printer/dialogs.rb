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
# Summary:     DialogTree definition
# Authors:     Michal Zugec <mzugec@suse.de>

module Yast
  module PrinterDialogsInclude
    def initialize_printer_dialogs(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "DialogTree"

      Yast.include include_target, "printer/helps.rb"
      Yast.include include_target, "printer/overview.rb"
      Yast.include include_target, "printer/printingvianetwork.rb"
      Yast.include include_target, "printer/sharing.rb"
      Yast.include include_target, "printer/policies.rb"
      Yast.include include_target, "printer/autoconfig.rb"

      @widgets_handling = {
        "OVERVIEW"        => {
          "widget"        => :custom,
          "custom_widget" => @widgetOverview,
          "init"          => fun_ref(method(:initOverview), "void (string)"),
          "handle"        => fun_ref(
            method(:handleOverview),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "overview", "")
        },
        "NETWORKPRINTING" => {
          "widget"        => :custom,
          "custom_widget" => @widgetNetworkPrinting,
          "init"          => fun_ref(
            method(:initNetworkPrinting),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:handleNetworkPrinting),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(
            @HELPS,
            "printing_via_network_dialog",
            ""
          )
        },
        "SHARING"         => {
          "widget"        => :custom,
          "custom_widget" => @widgetSharing,
          "init"          => fun_ref(method(:initSharing), "void (string)"),
          "handle"        => fun_ref(
            method(:handleSharing),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "sharing_dialog", "")
        },
        "POLICIES"        => {
          "widget"        => :custom,
          "custom_widget" => @widgetPolicies,
          "init"          => fun_ref(method(:initPolicies), "void (string)"),
          "handle"        => fun_ref(
            method(:handlePolicies),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "policies", "")
        },
        "AUTOCONFIG"      => {
          "widget"        => :custom,
          "custom_widget" => @widgetAutoconfig,
          "init"          => fun_ref(method(:initAutoconfig), "void (string)"),
          "handle"        => fun_ref(
            method(:handleAutoconfig),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "autoconfig", "")
        }
      }

      @tabs_description = {
        "overview"   => {
          "header"          => _("Printer Configurations"),
          "tree_item_label" => _("Printer Configurations"),
          "caption"         => _("Printer Configurations"),
          "contents"        => VBox("OVERVIEW"),
          "widget_names"    => ["OVERVIEW"]
        },
        "network"    => {
          "header"          => _("Print via Network"),
          "tree_item_label" => _("Print via Network"),
          "caption"         => _("Print via Network"),
          "contents"        => VBox("NETWORKPRINTING"),
          "widget_names"    => ["NETWORKPRINTING"]
        },
        "sharing"    => {
          "header"          => _("Share Printers"),
          "tree_item_label" => _("Share Printers"),
          "caption"         => _("Share Printers"),
          "contents"        => VBox("SHARING"),
          "widget_names"    => ["SHARING"]
        },
        "policies"   => {
          "header"          => _("Policies"),
          "tree_item_label" => _("Policies"),
          "caption"         => _("Policies"),
          "contents"        => VBox("POLICIES"),
          "widget_names"    => ["POLICIES"]
        },
        "autoconfig" => {
          "header"          => _("Automatic Configuration"),
          "tree_item_label" => _("Automatic Configuration"),
          "caption"         => _("Automatic Configuration"),
          "contents"        => VBox("AUTOCONFIG"),
          "widget_names"    => ["AUTOCONFIG"]
        }
      }

      @AutoDialog_widgets_handling = {
        "OVERVIEW"        => {
          "widget"        => :custom,
          "custom_widget" => @widgetOverview,
          "init"          => fun_ref(method(:initOverview), "void (string)"),
          "handle"        => fun_ref(
            method(:handleOverview),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(@HELPS, "AutoYaSToverview", "")
        },
        "NETWORKPRINTING" => {
          "widget"        => :custom,
          "custom_widget" => @widgetNetworkPrinting,
          "init"          => fun_ref(
            method(:initNetworkPrinting),
            "void (string)"
          ),
          "handle"        => fun_ref(
            method(:handleNetworkPrinting),
            "symbol (string, map)"
          ),
          "help"          => Ops.get_string(
            @HELPS,
            "printing_via_network_dialog",
            ""
          )
        }
      }

      @AutoDialog_tabs_description = {
        "overview" => {
          "header"          => _("AutoYaST Printer Configurations"),
          "tree_item_label" => _("Printer Configurations"),
          "caption"         => _("AutoYaST Printer Configurations"),
          "contents"        => VBox("OVERVIEW"),
          "widget_names"    => ["OVERVIEW"]
        },
        "network"  => {
          "header"          => _("AutoYaST Print via Network Settings"),
          "tree_item_label" => _("Print via Network"),
          "caption"         => _("AutoYaST Print via Network Settings"),
          "contents"        => VBox("NETWORKPRINTING"),
          "widget_names"    => ["NETWORKPRINTING"]
        }
      }
    end

    def runMainDialog
      caption = _("Detected Printers")
      ret = DialogTree.ShowAndRun(
        {
          "ids_order"      => [
            "overview",
            "network",
            "sharing",
            "policies",
            "autoconfig"
          ],
          "initial_screen" => "overview",
          "screens"        => @tabs_description,
          "widget_descr"   => @widgets_handling,
          # All the dialogs in "ids_order" are single (step) configuration dialogs
          # and according to the YaST Style Guide (dated Thu, 06 Nov 2008)
          # there is no longer a "abort" functionality which exits the whole module.
          # Instead this button is now named "Cancel" and its functionality is
          # to go back to the Overview dialog (i.e. what the "back" button would do)
          # because it reads "Cancel - Closes the window and returns to the overview."
          # Therefore the button with the "abort" functionality is not shown at all
          # and the button with the "back" functionality is named "Cancel".
          "abort_button"   => nil,
          "back_button"    => Label.CancelButton,
          "next_button"    => Label.OKButton
        }
      )
      ret
    end

    def runAutoDialog
      caption = _("AutoYaST Settings for Printing with CUPS via Network")
      ret = DialogTree.ShowAndRun(
        {
          "ids_order"      => ["overview", "network"],
          "initial_screen" => "overview",
          "screens"        => @AutoDialog_tabs_description,
          "widget_descr"   => @AutoDialog_widgets_handling,
          # All the dialogs in "ids_order" are single (step) configuration dialogs
          # and according to the YaST Style Guide (dated Thu, 06 Nov 2008)
          # there is no longer a "abort" functionality which exits the whole module.
          # Instead this button is now named "Cancel" and its functionality is
          # to go back to the Overview dialog (i.e. what the "back" button would do)
          # because it reads "Cancel - Closes the window and returns to the overview."
          # Therefore the button with the "abort" functionality is not shown at all
          # and the button with the "back" functionality is named "Cancel".
          "abort_button"   => nil,
          "back_button"    => Label.CancelButton,
          "next_button"    => Label.OKButton
        }
      )
      ret
    end
  end
end

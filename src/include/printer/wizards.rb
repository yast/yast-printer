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

# File:        include/printer/wizards.ycp
# Package:     Configuration of printer
# Summary:     Wizards definitions
# Authors:     Johannes Meixner <jsmeix@suse.de>

module Yast
  module PrinterWizardsInclude
    def initialize_printer_wizards(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "printer/readwrite.rb"
      Yast.include include_target, "printer/basicadd.rb"
      Yast.include include_target, "printer/basicmodify.rb"
      Yast.include include_target, "printer/connectionwizard.rb"
      Yast.include include_target, "printer/printingvianetwork.rb"
      Yast.include include_target, "printer/driveroptions.rb"
      Yast.include include_target, "printer/driveradd.rb"
      Yast.include include_target, "printer/dialogs.rb"
    end

    # Workflow of the printer configuration
    # @return sequence result
    def MainSequence
      aliases = {
        "overview"                               => lambda { runMainDialog },
        "add"                                    => lambda { BasicAddDialog() },
        "add_connection_wizard"                  => lambda do
          ConnectionWizardDialog()
        end,
        "add_driver_add"                         => lambda { AddDriverDialog() },
        "modify"                                 => lambda do
          BasicModifyDialog()
        end,
        "modify_connection_wizard"               => lambda do
          ConnectionWizardDialog()
        end,
        "modify_driver_add"                      => lambda { AddDriverDialog() },
        "modify_driver_options"                  => lambda do
          DriverOptionsDialog()
        end,
        "printing_via_network_connection_wizard" => lambda do
          ConnectionWizardDialog()
        end
      }
      sequence = {
        "ws_start"                               => "overview",
        "overview"                               => {
          :abort                                  => :abort,
          :back                                   => :abort,
          :next                                   => :next,
          :add                                    => "add",
          :modify                                 => "modify",
          :delete                                 => "overview",
          :refresh                                => "overview",
          :printing_via_network_back              => "overview",
          :printing_via_network_next              => "overview",
          :printing_via_network_connection_wizard => "printing_via_network_connection_wizard",
          :sharing_back                           => "overview",
          :sharing_next                           => "overview",
          :policies_back                          => "overview",
          :policies_next                          => "overview",
          :autoconfig_back                        => "overview",
          :autoconfig_next                        => "overview"
        },
        "add"                                    => {
          :abort             => :abort,
          :back              => "overview",
          :next              => "overview",
          :connection_wizard => "add_connection_wizard",
          :add_driver        => "add_driver_add",
          :run_hpsetup       => "overview"
        },
        "add_connection_wizard"                  => {
          :abort => :abort,
          :back  => "add",
          :next  => "add"
        },
        "add_driver_add"                         => {
          :abort => :abort,
          :back  => "add",
          :next  => "add"
        },
        "modify"                                 => {
          :abort             => :abort,
          :back              => "overview",
          :next              => "overview",
          :connection_wizard => "modify_connection_wizard",
          :add_driver        => "modify_driver_add",
          :driver_options    => "modify_driver_options"
        },
        "modify_connection_wizard"               => {
          :abort => :abort,
          :back  => "modify",
          :next  => "modify"
        },
        "modify_driver_add"                      => {
          :abort => :abort,
          :back  => "modify",
          :next  => "modify"
        },
        "modify_driver_options"                  => {
          :abort => :abort,
          :back  => "modify",
          :next  => "modify"
        },
        "printing_via_network_connection_wizard" => {
          :abort => :abort,
          :back  => "overview",
          :next  => "add"
        }
      }
      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of printer
    # @return sequence result
    def PrinterSequence
      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }
      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.Printer")
      ret = Sequencer.Run(aliases, sequence)
      UI.CloseDialog
      deep_copy(ret)
    end

    # Workflow of the printer configuration for AutoYaST
    # @return sequence result
    def AutoSequence
      aliases = { "overview" => lambda { runAutoDialog } }
      sequence = {
        "ws_start" => "overview",
        "overview" => {
          :abort                                  => :abort,
          :back                                   => "overview",
          :next                                   => :next,
          :add                                    => "overview",
          :modify                                 => "overview",
          :delete                                 => "overview",
          :refresh                                => "overview",
          :printing_via_network_back              => "overview",
          :printing_via_network_next              => "overview",
          :printing_via_network_connection_wizard => "overview",
          :sharing_back                           => "overview",
          :sharing_next                           => "overview",
          :policies_back                          => "overview",
          :policies_next                          => "overview",
          :autoconfig_back                        => "overview",
          :autoconfig_next                        => "overview"
        }
      }
      Sequencer.Run(aliases, sequence)
    end

    # Only "Printing via Network" configuration of printer.
    # For use with autoinstallation.
    # @return sequence result
    def PrinterAutoSequence
      caption = _("Printer Configuration")
      # Initialization dialog contents
      contents = Label(_("Initializing..."))
      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )
      ret = AutoSequence()
      UI.CloseDialog
      deep_copy(ret)
    end

    # Whole configuration of printer but without reading and writing.
    # For use with proposal at the end of the system installation.
    # @return sequence result
    def PrinterProposalSequence
      caption = _("Printer Configuration")
      # Initialization dialog contents
      contents = Label(_("Initializing..."))
      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )
      ret = MainSequence()
      UI.CloseDialog
      deep_copy(ret)
    end
  end
end

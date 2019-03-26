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

# File:        include/printer/driveroptions.ycp
# Package:     Configuration of printer
# Summary:     Driver options dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>

require "shellwords"

module Yast
  module PrinterDriveroptionsInclude
    def initialize_printer_driveroptions(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Popup"

      Yast.include include_target, "printer/helps.rb"
    end

    # DriverOptionsDialog dialog
    # @return dialog result
    def DriverOptionsDialog
      name = Ops.get(
        Printer.queues,
        [Printer.selected_queues_index, "name"],
        ""
      )
      Builtins.y2milestone("entering DriverOptionsDialog for queue '%1'", name)
      # Title of the Driver Options Dialog where %1 will be replaced by the queue name.
      # The actual queue name is a system value which cannot be translated:
      caption = Builtins.sformat(_("Driver Options for Queue %1"), name)
      contents = Tree(
        Id(:driver_options_tree),
        # The `notify option makes UI::UserInput() return immediately
        # as soon as the user selects a tree item rather than the default behaviour
        # which waits for the user to activate a button:
        Opt(:notify),
        # Header of a Tree which shows driver options:
        # _("Driver Options"),
        # No duplicate header because the dialog header is already "Driver Options":
        "",
        # Initially the parameter selected_keyword is the empty string
        # to have all values lists closed by default in the tree
        # and the parameter selected_value is also the empty string
        # because no value is initially selected:
        Printer.DriverOptionItems("", "")
      )
      # According to the YaST Style Guide (dated Thu, 06 Nov 2008)
      # there is no longer a "abort" functionality which exits the whole module.
      # Instead this button is now named "Cancel" and its functionality is
      # to go back to the Overview dialog (i.e. what the "back" button would do)
      # because it reads "Cancel - Closes the window and returns to the overview."
      # In this case the "overview" is not the actual Overview dialog but the dialog
      # from which this DriverOptionsDialog was called i.e. BasicModifyDialog.
      # Therefore the button with the "abort" functionality is not shown at all
      # and the button with the "back" functionality is named "Cancel".
      # According to the YaST Style Guide (dated Thu, 06 Nov 2008)
      # the "finish" button in a single (step) configuration dialog must now be named "OK".
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "driver_options_dialog", ""),
        # Set a new label for the "back" button, see the comment above:
        Label.CancelButton,
        # Set a new label for the "next" button, see the comment above:
        Label.OKButton
      )
      Wizard.HideAbortButton
      ret = nil
      while true
        ret = UI.UserInput
        break if ret == :abort || ret == :cancel || ret == :back
        if ret == :next
          Builtins.y2milestone("Driver options: %1", Printer.driver_options)
          commandline = "/usr/sbin/lpadmin -h localhost -p " + name.shellescape
          something_has_changed = false
          Builtins.foreach(Printer.driver_options) do |driver_option|
            keyword = Ops.get_string(driver_option, "keyword", "")
            selected_value = Ops.get_string(driver_option, "selected", "")
            if "" != keyword && "" != selected_value
              really_changed = true
              Builtins.foreach(Ops.get_list(driver_option, "values", [])) do |value|
                really_changed = false if value == Ops.add("*", selected_value)
              end

              if really_changed
                commandline += " -o " + keyword.shellescape + "=" + selected_value.shellescape
                something_has_changed = true
              end
            end
          end

          if something_has_changed
            Wizard.DisableBackButton
            Wizard.DisableNextButton
            if !Printerlib.ExecuteBashCommand(commandline)
              Popup.Error(
                # where %1 will be replaced by the queue name.
                # Only a simple message because this error does not happen on a normal system
                # (i.e. a system which is not totally broken or totally messed up).
                Builtins.sformat(
                  _("Failed to set driver options for queue %1."),
                  name
                )
              )
            end
            Wizard.EnableBackButton
            Wizard.EnableNextButton
          end
          # Exit this dialog in any case:
          break
        end
        if ret == :driver_options_tree
          selected_branch = Convert.to_list(
            UI.QueryWidget(:driver_options_tree, :CurrentBranch)
          )
          Builtins.y2milestone(
            "Selected driver options tree branch: %1",
            selected_branch
          )
          # The selected branch list has
          # either one elemet which is the main keyword when an option is selected e.g. ["PageSize"]
          # or it has two elements: main keyword and option value e.g. ["PageSize", "A4 (currently selected)"]
          # where only the first word in the option value string is the option value keyword
          # (spaces in main keywords or option keywords violate the PPD specification).
          selected_main_keyword = Ops.get_string(selected_branch, 0, "")
          selected_option_value_keyword = Ops.get(
            Builtins.splitstring(Ops.get_string(selected_branch, 1, ""), " "),
            0,
            ""
          )
          if 2 == Builtins.size(selected_branch)
            if "" != selected_main_keyword &&
                "" != selected_option_value_keyword
              # before the tree is re-built via the UI::ChangeWidget below:
              Builtins.sleep(100)
              # The Printer::DriverOptionItems call stores the current setting
              # in Printer::driver_options so that it is known later
              # (in particular when the changes are committed when the dialog finishes):
              UI.ChangeWidget(
                :driver_options_tree,
                :Items,
                Printer.DriverOptionItems(
                  selected_main_keyword,
                  selected_option_value_keyword
                )
              )
            end
          else
            # before the tree is re-built via the UI::ChangeWidget below:
            Builtins.sleep(100)
            # Open the matching values list in the tree when the option is selected:
            UI.ChangeWidget(
              :driver_options_tree,
              :Items,
              Printer.DriverOptionItems(selected_main_keyword, "")
            )
          end
          next
        end
        Builtins.y2milestone(
          "Ignoring unexpected returncode in DriverOptionsDialog: %1",
          ret
        )
        next
      end
      Builtins.y2milestone("leaving DriverOptionsDialog")
      deep_copy(ret)
    end
  end
end

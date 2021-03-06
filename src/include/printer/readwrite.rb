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

# File:        include/printer/readwrite.ycp
# Package:     Configuration of printer
# Summary:     Read and write dialogs definitions
# Authors:     Johannes Meixner <jsmeix@suse.de>

module Yast
  module PrinterReadwriteInclude
    def initialize_printer_readwrite(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Confirm"
      Yast.import "Printer"

      Yast.include include_target, "printer/helps.rb"
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Printer.Modified
    end

    # Ask for user confirmation if necessary before aborting.
    # At present full transaction semantics (with roll-back) is not implemented.
    # What is implemented is that it does not leave the system in an inconsistent state.
    # It does one setup completely or not at all (i.e. all or nothing semantics regarding one setup.)
    # "One setup" means the smallest amount of setup actions
    # which lead from one consistent state to another consistent state.
    # "Consistent state" is meant from the user's point of view
    # (i.e. set up one print queue completely or set up printing via network completely)
    # and not from a low-level (e.g. filesystem or kernel) point of view.
    # If the user does malicious stuff (e.g. killing YaST)
    # or if the user ignores warning messages then it is possible (and it is accepted)
    # that the user can force to set up even an inconsistent state
    # (e.g. set up share print queues but don't re-start the cupsd).
    # At present all what is needed for one setup is committed to the system instantly.
    # For background information and details see
    # http://en.opensuse.org/Archive:YaST_Printer_redesign
    # @return true if nothing was committed or if user confirms to abort
    def ReallyAbort
      !Printer.Modified || Popup.ReallyAbort(false)
    end

    def PollAbort
      UI.PollInput == :abort
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      # Otherwise the user is asked for confirmation whether he want's to continue
      # despite the fact that the module might not work correctly.
      return :abort if !Confirm.MustBeRoot
      # According to the YaST Style Guide (dated Thu, 06 Nov 2008)
      # the "abort" button in a single configuration dialog must now be named "cancel":
      Wizard.SetAbortButton(:abort, Label.CancelButton)
      # No "back" or "next" button at all makes any sense here
      # because there is no dialog where to go "back"
      # and the "next" dialog (i.e. the Overview dialog) is launced automatically
      Wizard.HideBackButton
      Wizard.HideNextButton
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "read", ""))
      # Printer::AbortFunction = PollAbort;
      ret = Printer.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.HideAbortButton
      Wizard.HideBackButton
      Wizard.HideNextButton
      Wizard.RestoreHelp(Ops.get_string(@HELPS, "write", ""))
      ret = Printer.Write
      ret ? :next : :abort
    end
  end
end

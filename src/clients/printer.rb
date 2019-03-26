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

# File:	clients/printer.ycp
# Package:	Configuration of printer
# Summary:	Main file
# Authors:	Johannes Meixner <jsmeix@suse.de>
#
# Main file for printer configuration. Uses all other files.

module Yast
  class PrinterClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of printer</h3>

      textdomain "printer"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Printer module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"

      Yast.import "CommandLine"
      Yast.include self, "printer/wizards.rb"

      @cmdline_description = {
        "id"         => "printer",
        # Command line help text for the printer module
        "help"       => _(
          "Configuration of printer"
        ),
        "guihandler" => fun_ref(method(:PrinterSequence), "any ()"),
        "initialize" => fun_ref(Printer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Printer.method(:Write), "boolean ()"),
        "actions" =>
          # FIXME TODO: fill the functionality description here
          {},
        "options" =>
          # FIXME TODO: fill the option descriptions here
          {},
        "mappings" =>
          # FIXME TODO: fill the mappings of actions and options here
          {}
      }

      # is this proposal or not?
      @propose = false
      @args = WFM.Args
      if Ops.greater_than(Builtins.size(@args), 0)
        if Ops.is_path?(WFM.Args(0)) && WFM.Args(0) == path(".propose")
          Builtins.y2milestone("Using PROPOSE mode")
          @propose = true
        end
      end

      # main ui function
      @ret = nil

      if @propose
        @ret = PrinterProposalSequence()
      else
        @ret = CommandLine.Run(@cmdline_description)
      end
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Printer module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::PrinterClient.new.main

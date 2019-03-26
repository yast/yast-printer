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

# File:	clients/printer_auto.ycp
# Package:	Configuration of printer
# Summary:	Client for autoinstallation
# Authors:	Michal Zugec <mzugec@suse.cz>
#              Johannes Meixner <jsmeix@suse.de>
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.

# It is perfectly correct and sufficient that the
# AutoYaST printer profile contains only the content
# of /etc/cups/client.conf and /etc/cups/cupsd.conf
# because:
# The current AutoYaST printer documentation
# in Suse/Novell Bugzilla attachment #269970 in
# https://bugzilla.novell.com/show_bug.cgi?id=464364#c22
# describes why there cannot be support for
# local print queues for USB printers
# which is a reason that there is only support
# for printing with CUPS via network,
# and
# https://bugzilla.novell.com/show_bug.cgi?id=464364#c25
# describes that AutoYaST support regarding whether or not
# the cupsd should run belongs to the runlevel module.
# @param function to execute
# @param map/list of printer settings
# @return [Hash] edited settings, Summary or boolean on success depending on called function
# @example map mm = $[ "FAIL_DELAY" : "77" ];
# @example map ret = WFM::CallFunction ("printer_auto", [ "Summary", mm ]);

require "shellwords"

module Yast
  class PrinterAutoClient < Client
    def main
      Yast.import "UI"

      textdomain "printer"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Printer auto started")

      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Progress"
      Yast.include self, "printer/wizards.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments:
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end
      Builtins.y2milestone("Printer auto func='%1'", @func)
      Builtins.y2milestone("Printer auto param='%1'", @param)

      # Create a summary string
      if @func == "Summary"
        @ret = Printer.printer_auto_summary
      # Reset the AutoYaST related printer settings to system defaults
      # which means /etc/cups/cupsd.conf is overwritten by /etc/cups/cupsd.conf.default
      # (/etc/cups/cupsd.conf.default is provided by our cups RPM for such cases)
      # and all entries in /etc/cups/client.conf are commented out.
      # Then read the content form those system config files
      # (exactly the same way as it is done in the Export function)
      # and store it in the Printer::autoyast_printer_settings map
      # (exactly the same is done in the Import function)
      # so that a subsequent call of the Export function by AutoYaST
      # would export the system default values to AutoYaST
      # and a subsequent call of the Write function by AutoYaST would
      # write the same system default values again to /etc/cups/client.conf
      # and to /etc/cups/cupsd.conf (regardless that their content
      # is already reset to system defaults).
      # Accordingly return the Printer::autoyast_printer_settings map
      # to AutoYaST so that also the printer related settings inside AutoYaST
      # are reset to system defaults so that a subsequent call of the Import
      # function by AutoYaST would provide the correct system default values.
      elsif @func == "Reset"
        # because then /etc/cups/cupsd.conf and/or /etc/cups/client.conf
        # were (hopefully) not changed at all which is the right fallback
        # so that there is no change of system config files in case of errors.
        CreateBackupFile("/etc/cups/cupsd.conf")
        Printerlib.ExecuteBashCommand(
          "cp /etc/cups/cupsd.conf.default /etc/cups/cupsd.conf"
        )
        CreateBackupFile("/etc/cups/client.conf")
        Printerlib.ExecuteBashCommand(
          "sed -i -e '/^[^#]/s/^/#/' /etc/cups/client.conf"
        )
        # After /etc/cups/cupsd.conf and/or /etc/cups/client.conf were changed
        # a restart of the local cupsd is needed if it is currently accessible
        # so that a possible subsequent AutoYaST call of the "Change" function
        # uses a local cupsd with the changed system default config which results
        # the right system default settings in the "Printing via Network" dialog.
        # To avoid that the user confirmation yes/no-popup in
        # Printerlib::GetAndSetCupsdStatus("restart") could block autoinstallation
        # only Printer::printer_auto_requires_cupsd_restart is set to true here
        # which postpones and triggers the actual cupsd restart to be done later
        # in the "Change" function which is meant to run interactive dialogs.
        if Printerlib.GetAndSetCupsdStatus("")
          Printer.printer_auto_requires_cupsd_restart = true
        end
        # Ignore read failures and reset to even empty content because
        # to what else could it be reset instead in case of errors:
        Printer.autoyast_printer_settings = {
          "cupsd_conf_content"  => {
            "file_contents" => ReadFileContent("/etc/cups/cupsd.conf")
          },
          "client_conf_content" => {
            "file_contents" => ReadFileContent("/etc/cups/client.conf")
          }
        }
        @ret = deep_copy(Printer.autoyast_printer_settings)
      # Called appropriately by the AutoYaST framework
      elsif @func == "SetModified"
        Printer.printer_auto_modified = true
        @ret = true
      # Provide to AutoYaST what it did set before (or the default "false")
      elsif @func == "GetModified"
        @ret = Printer.printer_auto_modified
      # Change configuration (run the wizards AutoSequence dialogs)
      elsif @func == "Change"
        # to make sure that when the printer module dialogs are launched
        # it asks the user to install the packages cups-client and cups:
        @progress_orig = Progress.set(false)
        Printer.Read
        Progress.set(@progress_orig)
        if Printer.printer_auto_requires_cupsd_restart
          if Printerlib.GetAndSetCupsdStatus("restart")
            Printer.printer_auto_requires_cupsd_restart = false
          end
        end
        # Let the Overview dialog disable the checkbox to show local queues
        # which disables as a consequence in particular the [Delete] button.
        # Let the "Printing via Network" dialog disable the button to
        # run the "Connection Wizard" (to set up a local queue for a network printer).
        Printer.printer_auto_dialogs = true
        # Let the Overview dialog only show remote queues:
        Printer.queue_filter_show_remote = true
        Printer.queue_filter_show_local = false
        # PrinterAutoSequence in wizards.ycp runs only the AutoSequence
        # which is only the "Printing via Network" and the "Overview" dialogs
        # but without running before ReadDialog (which calls only Printer::Read)
        # and running afterwards WriteDialog (which calls only Printer::Write)
        # which is the reason that Printer::Read is called explicitly above.
        @ret = PrinterAutoSequence()
      # Import the AutoYaST related printer settings map from AutoYaST
      # and store it to be used later when the Write function is called.
      elsif @func == "Import"
        Printer.autoyast_printer_settings = deep_copy(@param)
        @ret = true
      # Read AutoYaST related printer configuration from this system's config files
      # and export them to AutoYaST as a single map so that it can be imported later
      # on another system from AutoYaST when AutoYaST on the other system
      # calls the above Import function.
      elsif @func == "Export"
        # what else could be exported instead in case of errors:
        @ret = {
          "cupsd_conf_content"  => {
            "file_contents" => ReadFileContent("/etc/cups/cupsd.conf")
          },
          "client_conf_content" => {
            "file_contents" => ReadFileContent("/etc/cups/client.conf")
          }
        }
      # Return packages needed to be installed and removed during
      # Autoinstallation to ensure it has all needed software installed.
      # @return map with 2 lists of strings $["install":[],"remove":[]]
      elsif @func == "Packages"
        @to_be_installed_packages = []
        if Printerlib.TestAndInstallPackage("cups-client", "installed")
          @to_be_installed_packages = Builtins.add(
            @to_be_installed_packages,
            "cups-client"
          )
        end
        if Printerlib.TestAndInstallPackage("cups", "installed")
          @to_be_installed_packages = Builtins.add(
            @to_be_installed_packages,
            "cups"
          )
        end
        @ret = { "install" => @to_be_installed_packages, "remove" => [] }
      # Dummy to provide a Read function for the AutoYaST framework
      elsif @func == "Read"
        # avoid that the AutoYaST printer client asks the user
        # to install the packages cups-client and cups, see
        # https://bugzilla.novell.com/show_bug.cgi?id=445719#c13
        Builtins.y2milestone(
          "Not calling Printer::Read() to avoid that printer_auto asks to install cups-client and cups."
        )
        @ret = true
      # Write the AutoYaST related printer settings to the system
      # according to the Printer::autoyast_printer_settings_import map
      # which was stored by a previous call of the Import function by AutoYaST
      # or reset to an empty map by a previous call of the Reset function.
      elsif @func == "Write"
        Builtins.y2milestone(
          "Writing to system '%1'",
          Printer.autoyast_printer_settings
        )
        CreateBackupFile("/etc/cups/cupsd.conf")
        if !SCR.Write(
            path(".target.string"),
            "/etc/cups/cupsd.conf",
            Ops.get_string(
              Printer.autoyast_printer_settings,
              ["cupsd_conf_content", "file_contents"],
              ""
            )
          )
          Builtins.y2milestone("Error: Failed to write /etc/cups/cupsd.conf")
          Printer.printer_auto_summary = Ops.add(
            Ops.add(
              Ops.add(Printer.printer_auto_summary, "<p>"),
              _("Error: Failed to write /etc/cups/cupsd.conf")
            ),
            "</p>"
          )
        end
        CreateBackupFile("/etc/cups/client.conf")
        if !SCR.Write(
            path(".target.string"),
            "/etc/cups/client.conf",
            Ops.get_string(
              Printer.autoyast_printer_settings,
              ["client_conf_content", "file_contents"],
              ""
            )
          )
          Builtins.y2milestone("Error: Failed to write /etc/cups/client.conf")
          Printer.printer_auto_summary = Ops.add(
            Ops.add(
              Ops.add(Printer.printer_auto_summary, "<p>"),
              _("Error: Failed to write /etc/cups/client.conf")
            ),
            "</p>"
          )
        end
        return true
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false
      end

      Builtins.y2milestone("Printer auto ret='%1'", @ret)
      Builtins.y2milestone("Printer auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)

      # EOF
    end

    def ReadFileContent(file_name)
      if -1 == SCR.Read(path(".target.size"), file_name)
        # It is no error when /etc/cups/cupsd.conf or /etc/cups/client.conf
        # cannot be read when those files just do not exist because
        # it is perfectly o.k. to have a system without the package "cups"
        # (e.g. a client-only setup without the "cups" RPM which provides /etc/cups/cupsd.conf)
        # or even without a /etc/cups/client.conf file which is provided by the cups-libs RPM
        # (e.g. a CUPS default setup where CUPS browsing is used and /etc/cups/client.conf was deleted)
        Builtins.y2milestone(
          "Warning: Cannot read %1 (file may not exist).",
          file_name
        )
        Printer.printer_auto_summary = Ops.add(
          Ops.add(
            Ops.add(Printer.printer_auto_summary, "<p>"),
            Builtins.sformat(
              # which is added to its "Summary" text for AutoYaST
              # where %1 is replaced by the file name which cannot be read.
              _("Warning: Cannot read %1 (file may not exist)."),
              file_name
            ) # Warning message in the AutoYaST printer client
          ),
          "</p>"
        )
        return ""
      end
      # The file content will appear as CDATA section in the AutoYaST XML control file.
      # The content in a XML CDATA section cannot contain the string "]]>" because
      # this exact string (without spaces in between) marks the end of the CDATA section.
      # Therefore "]]>" in the file content is changed to "] ]>" to be on the safe side.
      # This change is not reverted in the "Write" function below
      # (which writes the CDATA section content back to a file)
      # because "] ]>" should also work (hoping that the particular file format
      # is not sensitive regarding a space between subsequent closing brackets).
      # In particular in /etc/cups/cupsd.conf and /etc/cups/client.conf
      # there is no string "]]>" (except perhaps in a comment).
      # It is o.k. to ignore when the sed command fails because then
      # the file content was (hopefully) not changed at all which is the right fallback:
      Printerlib.ExecuteBashCommand("sed -i -e 's/]]>/] ]>/g' " + file_name.shellescape)
      content = Convert.to_string(SCR.Read(path(".target.string"), file_name))
      if "" == Builtins.filterchars(content, Printer.alnum_chars)
        # It is an error when /etc/cups/cupsd.conf or /etc/cups/client.conf exist
        # but are effectively empty because this indicates a broken CUPS config.
        Builtins.y2milestone(
          "Error: Failed to read %1 (possibly empty file).",
          file_name
        )
        Printer.printer_auto_summary = Ops.add(
          Ops.add(
            Ops.add(Printer.printer_auto_summary, "<p>"),
            Builtins.sformat(
              # which is added to its "Summary" text for AutoYaST
              # where %1 is replaced by the file name which cannot be read.
              _("Error: Failed to read %1 (possibly empty file)."),
              file_name
            ) # Error message in the AutoYaST printer client
          ),
          "</p>"
        )
        return ""
      end
      content
    end

    def CreateBackupFile(file_name)
      if "" == file_name ||
          !Printerlib.ExecuteBashCommand("test -f " + file_name.shellescape)
        return true
      end
      # See "Make a backup" in tools/modify_cupsd_conf how to create a backup file.
      # Intentionally not escaping file_name in the "grep" call:
      # If there are weird characters in file_name, we might simply make one backup
      # of it too many which won't hurt.
      if Printerlib.ExecuteBashCommand("rpm -V -f " + file_name.shellescape + " | grep -q '^..5.*'" + file_name.shellescape + "'$'")
        if Printerlib.ExecuteBashCommand("cp -p " + file_name.shellescape + " " + file_name.shellescape + ".yast2save")
          return true
        end
        # No user information popup because this would block autoinstallation.
        Builtins.y2milestone(
          "Warning: Failed to backup %1 as %1.yast2save",
          file_name
        )
        Printer.printer_auto_summary = Ops.add(
          Ops.add(
            Ops.add(Printer.printer_auto_summary, "<p>"),
            Builtins.sformat(
              # which is added to its "Summary" text for AutoYaST
              # where %1 is replaced by the file name.
              _("Warning: Failed to backup %1 as %1.yast2save"),
              file_name
            ) # Warning message in the AutoYaST printer client
          ),
          "</p>"
        )
        return false
      end
      # The file is the original from the RPM package or the file is not owned by any package:
      if Printerlib.ExecuteBashCommand("cp -p " + file_name.shellescape + " " + file_name.shellescape + ".yast2orig")
        return true
      end
      # No user information popup because this would block autoinstallation.
      Builtins.y2milestone(
        "Warning: Failed to backup %1 as %1.yast2orig",
        file_name
      )
      Printer.printer_auto_summary = Ops.add(
        Ops.add(
          Ops.add(Printer.printer_auto_summary, "<p>"),
          Builtins.sformat(
            # which is added to its "Summary" text for AutoYaST
            # where %1 is replaced by the file name.
            _("Warning: Failed to backup %1 as %1.yast2orig"),
            file_name
          ) # Warning message in the AutoYaST printer client
        ),
        "</p>"
      )
      false
    end
  end
end

Yast::PrinterAutoClient.new.main

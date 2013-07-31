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

# File:        modules/Printer.ycp
# Package:     Configuration of printer
# Summary:     Printer settings, input and output functions
# Authors:     Johannes Meixner <jsmeix@suse.de>
#
# $Id: Printer.ycp 27914 2006-02-13 14:32:08Z locilka $
#
# Representation of the configuration of printer.
# Input and output routines.
require "yast"

module Yast
  class PrinterClass < Module
    def main
      Yast.import "UI"
      textdomain "printer"

      Yast.import "Progress"
      Yast.import "Summary"
      Yast.import "Popup"
      Yast.import "Printerlib"
      Yast.import "Wizard"

      # Data was modified?
      @modified = false

      # Abort function
      # return boolean return true if abort
      @AbortFunction = fun_ref(method(:Modified), "boolean ()")

      # Settings:
      # Define all variables needed for configuration of a printer:

      # Global variables:

      # Used by AutoYaST by calling in printer_auto.ycp the "Summary" function.
      @printer_auto_summary = _(
        "<p>\n" +
          "AutoYaST settings for printing with CUPS via network.<br>\n" +
          "There is no AutoYaST support for local print queues.\n" +
          "</p>"
      )

      # Set to 'true' by AutoYaST by calling in printer_auto.ycp the "SetModified" function.
      # Read by AutoYaST by calling in printer_auto.ycp the "GetModified" function.
      # Preset to false which is the right default for AutoYast.
      @printer_auto_modified = false

      # Filled in by AutoYaST by calling in printer_auto.ycp the "Import" function.
      # Reset to the empty map by AutoYaST by calling in printer_auto.ycp the "Reset" function.
      # Preset to the empty map.
      @autoyast_printer_settings = {}

      # Set to 'true' by AutoYaST by calling in printer_auto.ycp the "Change" function.
      # Lets the Overview dialog disable the checkbox to show local queues
      # which disables as a consequence in particular the [Delete] button.
      # Lets the Printing via Network dialog disable the button to
      # run the Connection Wizard (to set up a local queue for a network printer).
      # Preset to false which is the right default for all dialogs.
      @printer_auto_dialogs = false

      # Set to 'true' by AutoYaST when in printer_auto.ycp the "Reset" function
      # resets /etc/cups/cupsd.conf and /etc/cups/client.conf to system defaults.
      # When it is 'true', the "Change" function in printer_auto.ycp does a cupsd restart.
      # Preset to false.
      @printer_auto_requires_cupsd_restart = false

      # Explicite listing of all alphanumeric ASCII characters.
      # The reason is that in certain special locales for example [a-z] is not equivalent
      # to "abcdefghijklmnopqrstuvwxyz" because in certain special languages the 'z' is
      # not the last character in the alphabet, e.g. the Estonian alphabet ends
      # with ... s ... z ... t u v w ... x y (non-ASCII characters omitted here)
      # so that [a-z] would exclude t u v w x y in an Estonian locale.
      # Therefore uppercase and lowercase characters are both explicitly listed
      # to avoid any unexpected result e.g. of "tolower(uppercase_characters)".
      @number_chars = "0123456789"
      @upper_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      @lower_chars = "abcdefghijklmnopqrstuvwxyz"
      @letter_chars = Ops.add(@upper_chars, @lower_chars)
      @alnum_chars = Ops.add(@number_chars, @letter_chars)
      @lower_alnum_chars = Ops.add(@number_chars, @lower_chars)

      # Explicite listing of all known manufacturers in a standard installation
      # which one gets as output from the command
      # lpinfo -l -m | grep make-and-model | cut -s -d '=' -f 2 | cut -s -d ' ' -f 2 | sort -f -u
      # and then a bit changing it (in particular removing duplicates and nonsense entries).
      # The current list was made on openSUSE 11.0.
      @known_manufacturers = [
        "Generic",
        "Alps",
        "Anitech",
        "Apollo",
        "Apple",
        "Brother",
        "Canon",
        "Citizen",
        "CItoh",
        "Compaq",
        "DEC",
        "Dell",
        "Dymo",
        "Epson",
        "Fujifilm",
        "Fujitsu",
        "Gestetner",
        "Heidelberg",
        "Hitachi",
        "HP",
        "IBM",
        "Infotec",
        "Kodak",
        "KS",
        "Kyocera",
        "Lanier",
        "Lexmark",
        "Minolta",
        "Mitsubishi",
        "NEC",
        "NRG",
        "Oce",
        "Oki",
        "Olivetti",
        "Olympus",
        "Panasonic",
        "PCPI",
        "QMS",
        "Raven",
        "Ricoh",
        "Samsung",
        "Savin",
        "Seiko",
        "Sharp",
        "Shinko",
        "Sony",
        "Star",
        "Tally",
        "Tektronix",
        "Toshiba",
        "Xerox",
        "Zebra"
      ]

      # PPD database:
      # the database is created anew in CreateDatabase() which calls
      # the bash script "/usr/lib/YaST2/bin/create_ppd_database"
      # which outputs on stdout a YCP list of {#printer_ppd_map}
      # where the last list entry is an emtpy map.
      # CreateDatabase() leaves manufacturer and modelname empty because
      # it would take several minutes (instead of a few seconds) to fill them up
      # (see the comments in create_ppd_database). Both fields can be filled up
      # during runtime for particular PPDs (e.g. for a more detailed PPD selection
      # among several PPDs which match to a particular model or manufacturer
      # but not for all the thousands of PPDs which are installed in the system).
      #
      # **Structure:**
      #
      #     printer_ppd_map
      #      $[ "ppd":"the PPD file name with path below /usr/share/cups/model/ (required)",
      #         "nickname":"the NickName entry in the PPD (required)",
      #         "deviceID":"the 1284DeviceID entry in the PPD (may be the empty string)",
      #         "language":"the language of the PPD, usually "en" (may be the empty string)",
      #         "manufacturer":"the Manufacturer entry in the PPD (initially the empty string)",
      #         "modelname":"the ModelName entry in the PPD (initially the empty string)"
      #       ]
      @ppds = []

      # Selected PPD database index:
      # The index in the PPD database list (of PPD maps)
      # for the PPD which was selected by the user.
      # Preset to -1 which indicates that no PPD is selected.
      @selected_ppds_index = -1

      # Autodetected printers:
      # Determined at runtime via AutodetectPrinters() which calls the bash script
      # "/usr/lib/YaST2/bin/autodetect_printers"
      # which outputs on stdout a YCP list of {#autodetected_printer_map}
      # where the last list entry is an emtpy map.
      #
      # **Structure:**
      #
      #     autodetected_printer_map
      #      $[ "uri":"the full CUPS DeviceURI (required)",
      #         "model":"the manufacturer and model, often 'Unknown' (may be the empty string)",
      #         "deviceID":"what the printer reported as its device ID (often the empty string)",
      #         "info":"arbitrary info regarding this connection (may be the empty string)",
      #         "class":"one of 'direct','network','file','serial' or 'ConnectionWizardDialog' (may be the empty string)"
      #       ]
      @connections = []

      # Selected autodetected printer index:
      # The index in the autodetected printers list (of connection maps)
      # for the connection which was selected by the user.
      # Preset to -1 which indicates that no connection is selected.
      @selected_connections_index = -1

      # Current device uri:
      # The device uri (i.e. the connection) which is currently in use
      # so that the BasicAddDialog and BasicModifyDialog could preselect it.
      # Note that selected_connections_index cannot be used for this
      # because the ConnectionItems function which generates
      # the list of connections for BasicAddDialog and BasicModifyDialog
      # invalidates selected_connections_index because it autodetects
      # the currently available connections in the system anew because
      # those would change e.g. after a printer was connected or disconnected
      # Preset to "" which indicates that no device uri is currently in use.
      @current_device_uri = ""

      # Autodetected queues:
      # Determined at runtime via AutodetectQueues() which calls the bash script
      # "/usr/lib/YaST2/bin/autodetect_print_queues"
      # which outputs on stdout a YCP list of {#autodetected_queue_map}
      # where the last list entry is an emtpy map.
      #
      # **Structure:**
      #
      #     autodetected_queue_map
      #      $[ "name":"the queue name (required)",
      #         "uri":"the full CUPS DeviceURI (required)",
      #         "description":"(may be the empty string)",
      #         "location":"(may be the empty string)",
      #         "ppd":"/etc/cups/ppd/<queue-name>.ppd (may be the empty string)",
      #         "default":"'yes' if it is a DefaultPrinter in /etc/cups/printers.conf, otherwise the empty string",
      #         "disabled":"'yes' if printing is disabled, otherwise 'no'",
      #         "rejecting":"'yes' if print job are rejected, otherwise 'no'",
      #         "config":"'local' if the queue exists in /etc/cups/printers.conf, 'class' if the class exists in /etc/cups/classes.conf, otherwise 'remote' (required)"
      #       ]
      @queues = []

      # Selected queue index:
      # The index in the queues list (of queue maps)
      # for the queue which was selected by the user.
      # Preset to -1 which indicates that no queue is selected.
      @selected_queues_index = -1

      # Queue filter string:
      # Both boolean variables queue_filter_show_local and queue_filter_show_remote
      # can be either 'true' or 'false' depending on which kind of queues
      # from the queues list (of queue maps) the user wants to see in the overview dialog.
      # Both are preset to 'true' which indicates that all queues are shown.
      @queue_filter_show_local = true
      @queue_filter_show_remote = true

      # Current queue name:
      # The name of the queue which is currently in use
      # so that the Overview dialog could preselect it.
      # Note that selected_queues_index cannot be used for this
      # because the QueueItems function which generates
      # the list of queues for the Overview dialog
      # invalidates selected_queues_index because it autodetects
      # the current actual queues in the system anew because
      # the list of queues in the system would have changed
      # e.g. after a new queue was added or after a queue was removed.
      # Preset to "" which indicates that no queue is currently in use.
      @current_queue_name = ""

      # Driver options (options in the PPD for one specific existing queue):
      # Determined at runtime via DetermineDriverOptions( "queue_name")
      # which calls the bash script "/usr/lib/YaST2/bin/determine_printer_driver_options"
      # which outputs on stdout a YCP list of {#driver_option_map}
      # where the last list entry is an emtpy map.
      #
      # **Structure:**
      #
      #     driver_option_map
      #      $[ "keyword":"the main keyword of the option in the PPD (required)",
      #         "translation":"the translation string of the main keyword (may be the empty string)",
      #         "values":["a list of the option keywords in the PPD (at least one non-empty entry is required)
      #                    i.e. the values for the main keyword (i.e. the values for this option)
      #                    where the currently set option value of the queue is marked by a leading '*'
      #                    and where the last list entry is an emtpy string"],
      #         "selected":"the curently selected value in the DriverOptionsDialog (may be the empty string)"
      #       ]
      @driver_options = []

      # Local variables:
      @create_database_progress_filename = "/var/lib/YaST2/create_printer_ppd_database.progress"
      @database_filename = "/var/lib/YaST2/printer_ppd_database.ycp"
      @create_database_commandline = Ops.add(
        "/usr/lib/YaST2/bin/create_printer_ppd_database >",
        @database_filename
      )
      @autodetect_printers_progress_filename = "/var/lib/YaST2/autodetect_printers.progress"
      @autodetected_printers_filename = "/var/lib/YaST2/autodetected_printers.ycp"
      @autodetect_printers_commandline = Ops.add(
        Ops.add(
          Ops.add("export PROGRESS=", @autodetect_printers_progress_filename),
          " ; /usr/lib/YaST2/bin/autodetect_printers >"
        ),
        @autodetected_printers_filename
      )
      @autodetected_queues_filename = "/var/lib/YaST2/autodetected_print_queues.ycp"
      @autodetect_queues_commandline = Ops.add(
        "/usr/lib/YaST2/bin/autodetect_print_queues >",
        @autodetected_queues_filename
      )
      @driver_options_filename = "/var/lib/YaST2/printer_driver_options.ycp"
      @determine_printer_driver_options_commandline = Ops.add(
        Ops.add(
          "/usr/lib/YaST2/bin/determine_printer_driver_options >",
          @driver_options_filename
        ),
        " "
      )
    end

    # Abort function
    # @return [Boolean] return true if abort
    def Abort
      return @AbortFunction.call == true if @AbortFunction != nil
      false
    end

    # Data was modified?
    # @return true if modified
    def Modified
      Builtins.y2debug("modified=%1", @modified)
      @modified
    end

    # Global functions which are called by the local functions below:


    # Local functions which are called by the global functions below:

    # Create the PPD database by calling a bash script
    # which calls "lpinfo -l -m" and processes its output
    # and stores the results as YCP list in a temporary file
    # and then read the temporary file (SCR::Read)
    # to get the YCP list of {#printer_ppd_map}
    # @return true on success
    def CreateDatabase
      progress_feedback = UI.HasSpecialWidget(:DownloadProgress)
      if progress_feedback
        # Empty an existing progress file so that the DownloadProgress starts at the beginning.
        # Don't care if this command is successful. All what matters is if CreateDatabase() works.
        Printerlib.ExecuteBashCommand(
          Ops.add("cat /dev/null >", @create_database_progress_filename)
        )
        UI.OpenDialog(
          MinSize(
            60,
            3,
            ReplacePoint(
              Id(:create_database_progress_replace_point),
              DownloadProgress(
                _("Retrieving printer driver information..."),
                @create_database_progress_filename,
                # On my openSUSE 11.4 the size is about 80000 bytes.
                # The number 102400 results exactly "100.0 KB" in the
                # YaST Gtk user inteface for a DownloadProgress:
                102400
              ) # Header of a DownloadProgress indicator:
            )
          )
        )
      else
        Popup.ShowFeedback(
          "",
          # Busy message:
          # Body of a Popup::ShowFeedback:
          _(
            "Retrieving printer driver information...\n(this could take more than a minute)"
          )
        )
      end
      if !Printerlib.ExecuteBashCommand(@create_database_commandline)
        if progress_feedback
          UI.CloseDialog
        else
          Popup.ClearFeedback
        end
        Popup.ErrorDetails(
          # Only a simple message because this error does not happen on a normal system
          # (i.e. a system which is not totally broken or totally messed up).
          _("Failed to create PPD database."),
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      if -1 == SCR.Read(path(".target.size"), @database_filename)
        if progress_feedback
          UI.CloseDialog
        else
          Popup.ClearFeedback
        end
        Builtins.y2milestone(
          "Error: %1: file does not exist.",
          @database_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("File %1 does not exist."),
            @database_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        return false
      end
      @ppds = Convert.convert(
        SCR.Read(path(".target.ycp"), @database_filename),
        :from => "any",
        :to   => "list <map <string, string>>"
      )
      if nil == @ppds
        if progress_feedback
          UI.CloseDialog
        else
          Popup.ClearFeedback
        end
        Builtins.y2milestone("Error: Failed to read %1", @database_filename)
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("Failed to read %1."),
            @database_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        @ppds = []
        return false
      end
      if progress_feedback
        # ExpectedSize to 1 (setting it to 0 results wrong output) by calling
        # UI::ChangeWidget( `id(`create_database_progress), `ExpectedSize, 1 )
        # results bad looking output because the DownloadProgress widget is visible re-drawn
        # first with a small 1% initially starting progress bar which then jumps up to 100%
        # but what is intended is that the current progress bar jumps directly up to 100%.
        # Therefore DownloadProgress is not used at all but replaced by a 100% ProgressBar.
        # Because ProgressBar has a different default width than DownloadProgress,
        # a MinWidth which is sufficient for both is set above.
        # The size is measured in units roughly equivalent to the size of a character
        # in the respective UI (1/80 of the full screen width horizontally,
        # 1/25 of the full screen width vertically) where full screen size
        # is 640x480 pixels (y2qt) or 80x25 characters (y2ncurses).
        UI.ReplaceWidget(
          Id(:create_database_progress_replace_point),
          ProgressBar(_("Retrieved Printer Driver Information"), 100, 100) # Header for a finished ProgressBar:
        )
        # Sleep half a second to let the user notice that the progress is finished:
        Builtins.sleep(500)
        UI.CloseDialog
      else
        Popup.ClearFeedback
      end
      true
    end

    # Try to autodetect printers by calling a bash script
    # which calls "lpinfo -l -v" and processes its output
    # and stores the results as YCP list in a temporary file
    # and then read the temporary file (SCR::Read)
    # to get the YCP list of {#autodetected_printer_map}
    # @return true on success
    def AutodetectPrinters
      progress_feedback = UI.HasSpecialWidget(:DownloadProgress)
      if progress_feedback
        # Empty an existing progress file so that the DownloadProgress starts at the beginning.
        # Don't care if this command is successful.
        Printerlib.ExecuteBashCommand(
          Ops.add("cat /dev/null >", @autodetect_printers_progress_filename)
        )
        UI.OpenDialog(
          MinSize(
            60,
            3,
            ReplacePoint(
              Id(:autodetect_printers_progress_replace_point),
              DownloadProgress(
                _("Detecting printers..."),
                @autodetect_printers_progress_filename,
                # The progress file can grow up to about 3600 bytes
                # if the MAXIMUM_WAIT="60" in tools/autodetect_printers
                # is really needed.
                # The number 4096 results exactly "4.0 KB" in the
                # YaST Gtk user inteface for a DownloadProgress:
                4096
              ) # Header of a DownloadProgress indicator:
            )
          )
        )
      else
        Popup.ShowFeedback(
          "",
          # Busy message:
          # Body of a Popup::ShowFeedback:
          _("Detecting printers...")
        )
      end
      if !Printerlib.ExecuteBashCommand(@autodetect_printers_commandline)
        if progress_feedback
          UI.CloseDialog
        else
          Popup.ClearFeedback
        end
        Popup.ErrorDetails(
          # Only a simple message because this error does not happen on a normal system
          # (i.e. a system which is not totally broken or totally messed up).
          # Do not confuse this error with the case when no printer was autodetected.
          # The latter results no error.
          _("Failed to detect printers automatically."),
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      if -1 == SCR.Read(path(".target.size"), @autodetected_printers_filename)
        if progress_feedback
          UI.CloseDialog
        else
          Popup.ClearFeedback
        end
        Builtins.y2milestone(
          "Error: %1: file does not exist.",
          @autodetected_printers_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("File %1 does not exist."),
            @autodetected_printers_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        return false
      end
      @connections = Convert.convert(
        SCR.Read(path(".target.ycp"), @autodetected_printers_filename),
        :from => "any",
        :to   => "list <map <string, string>>"
      )
      if nil == @connections
        if progress_feedback
          UI.CloseDialog
        else
          Popup.ClearFeedback
        end
        Builtins.y2milestone(
          "Error: Failed to read %1",
          @autodetected_printers_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("Failed to read %1."),
            @autodetected_printers_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        @connections = []
        return false
      end
      if progress_feedback
        # ExpectedSize to 1 results bad looking output (see above).
        # Therefore DownloadProgress is not used at all but replaced by a 100% ProgressBar
        # which requires a MinWidth with sufficient size (see above).
        UI.ReplaceWidget(
          Id(:autodetect_printers_progress_replace_point),
          ProgressBar(_("Printer detection finished"), 100, 100) # Header for a finished ProgressBar:
        )
        # Sleep half a second to let the user notice that the progress is finished:
        Builtins.sleep(500)
        UI.CloseDialog
      else
        Popup.ClearFeedback
      end
      Builtins.y2milestone("Autodetected printers: %1", @connections)
      true
    end

    # Global functions:

    # Autodetect queues by calling a bash script
    # which calls "lpstat -v" and processes its output
    # and stores the results as YCP list in a temporary file
    # and then read the temporary file (SCR::Read)
    # to get the YCP list of {#autodetected_queue_map}
    # @return true on success
    def AutodetectQueues
      @selected_queues_index = -1
      if !Printerlib.ExecuteBashCommand(@autodetect_queues_commandline)
        Popup.ErrorDetails(
          # Only a simple message because this error does not happen on a normal system
          # (i.e. a system which is not totally broken or totally messed up).
          # Do not confuse this error with the case when no queue was detected
          # (e.g. simply because there is no queue). This results no error.
          _("Failed to detect print queues."),
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      if -1 == SCR.Read(path(".target.size"), @autodetected_queues_filename)
        Builtins.y2milestone(
          "Error: %1: file does not exist.",
          @autodetected_queues_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("File %1 does not exist."),
            @autodetected_queues_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        return false
      end
      @queues = Convert.convert(
        SCR.Read(path(".target.ycp"), @autodetected_queues_filename),
        :from => "any",
        :to   => "list <map <string, string>>"
      )
      if nil == @queues
        Builtins.y2milestone(
          "Error: Failed to read %1",
          @autodetected_queues_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("Failed to read %1."),
            @autodetected_queues_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        @queues = []
        return false
      end
      Builtins.y2milestone("Autodetected queues: %1", @queues)
      true
    end

    # Determine driver options by calling a bash script
    # which calls "lpoptions -l" and processes its output
    # and stores the results as YCP list in a temporary file
    # and then read the temporary file (SCR::Read)
    # to get the YCP list of {#autodetected_queue_map}
    # @return true on success
    def DetermineDriverOptions(queue_name)
      if "" == queue_name
        queue_name = Ops.get(@queues, [@selected_queues_index, "name"], "")
        if "local" !=
            Ops.get(@queues, [@selected_queues_index, "config"], "remote")
          return false
        end
      end
      return false if "" == queue_name
      commandline = Ops.add(
        @determine_printer_driver_options_commandline,
        queue_name
      )
      if !Printerlib.ExecuteBashCommand(commandline)
        Popup.ErrorDetails(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            # Do not confuse this error with the case when no queue was detected
            # (e.g. simply because there is no queue). This results no error.
            _("Failed to determine driver options for queue %1."),
            queue_name
          ), # Popup::ErrorDetails message where %1 will be replaced by the queue name.
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      if -1 == SCR.Read(path(".target.size"), @driver_options_filename)
        Builtins.y2milestone(
          "Error: %1: file does not exist.",
          @driver_options_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("File %1 does not exist."),
            @driver_options_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        return false
      end
      @driver_options = Convert.convert(
        SCR.Read(path(".target.ycp"), @driver_options_filename),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      if nil == @driver_options
        Builtins.y2milestone(
          "Error: Failed to read %1",
          @driver_options_filename
        )
        Popup.Error(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("Failed to read %1."),
            @driver_options_filename
          ) # Message of a Popup::Error where %1 will be replaced by the file name.
        )
        @driver_options = []
        return false
      end
      Builtins.y2milestone(
        "Driver options for queue %1: %2",
        queue_name,
        @driver_options
      )
      true
    end

    # Initialize printer configuration (checks only the installed packages) see
    # http://en.opensuse.org/Archive:YaST_Printer_redesign#Basic_Implementation_Principles:
    # for background information
    # @return true on success
    def Read
      Progress.New(
        _("Initializing Printer Configuration"),
        " ",
        1,
        [_("Check installed packages")], # 1. progress stage name of a Progress::New:
        [
          _("Checking installed packages..."),
          # Last progress step progress bar title of a Progress::New:
          _("Finished")
        ], # 1. progress step progress bar title of a Progress::New:
        ""
      )
      # Progress 1. stage (Check installed packages):
      return false if Abort()
      # The cups-client RPM is the minimum requirement
      # for accessing remote CUPS servers via a "client-only" config.
      # Therefore abort (return false) if cups-client is not installed:
      if !Printerlib.TestAndInstallPackage("cups-client", "install")
        # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
        # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
        # so that this leftover "abort" button must be explicitly hidden here:
        Wizard.HideAbortButton
        return false
      end
      # The cups RPM ist the default requirement
      # for accessing remote CUPS servers via CUPS Browsing
      # and it is the minimum requirement for local print queues.
      # Therefore try to install cups but because for a "client-only" config
      # only cups-client is required, proceed even if cups is not installed:
      Printerlib.TestAndInstallPackage("cups", "install")
      # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
      # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
      # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
      # so that this leftover "abort" button must be explicitly hidden here:
      Wizard.HideAbortButton
      # Progress last stage (progress finished):
      return false if Abort()
      Progress.NextStage
      # Sleep half a second to let the user notice that the progress is finished:
      Builtins.sleep(500)
      return false if Abort()
      Progress.Finish
      true
    end

    # Finish printer configuration (does actually nothing except to exit verbosely) see
    # http://en.opensuse.org/Archive:YaST_Printer_redesign#Basic_Implementation_Principles:
    # for background information
    # @return true in any case (because it only exits)
    def Write
      Progress.New(
        _("Finishing Printer Configuration"),
        " ",
        1,
        [_("Finish printer configuration")], # 1. progress stage name of a Progress::New:
        [
          _("Finishing printer configuration..."),
          # Last progress step progress bar title of a Progress::New:
          _("Finished")
        ], # 1. progress step progress bar title of a Progress::New:
        ""
      )
      # Progress first stage (Finish printer configuration):
      Progress.NextStage
      # Sleep half a second to let the user notice the progress:
      Builtins.sleep(500)
      # Progress last stage (progress finished):
      Progress.Finish
      # Sleep half a second to let the user notice that the progress is finished:
      Builtins.sleep(500)
      true
    end

    # Derive a reasonable model info from an arbitrary description string.
    # @param string from which a model info is derived.
    # @param integer how many words the model info can contain.
    # @return [String] (possibly the empty string)
    def DeriveModelName(description, max_words)
      model_info = ""
      words = Builtins.splitstring(description, " ")
      # Remove empty words because a sequence of spaces results empty words in the list of words
      # for example "ACME  Funprinter" (two spaces!) results ["ACME","","Funprinter"].
      # In Printer.ycp and basicmodify.ycp there are lines like
      #  description = model + " with driver " + description;
      #  new_description = model + " with driver " + new_description;
      # Avoid having "with" and/or "driver" in the model_info.
      words = Builtins.filter(words) do |word|
        "" != word && "with" != word && "driver" != word
      end
      if Ops.greater_than(Builtins.size(words), 0)
        words_start_with_known_manufacturer = false
        Builtins.foreach(
          # The specifically added manufacturer "Raw" is needed for a smooth setup of a "Raw Queue":
          Builtins.add(@known_manufacturers, "Raw")
        ) do |known_manufacturer|
          if Builtins.tolower(Ops.get(words, 0, "")) ==
              Builtins.tolower(known_manufacturer)
            words_start_with_known_manufacturer = true
            raise Break
          end
        end 

        if 1 == max_words || 2 == max_words
          if words_start_with_known_manufacturer
            model_info = Ops.get(words, 0, "")
            if 2 == max_words
              # This is usually the first word which contains a number.
              Builtins.foreach(words) do |word|
                if "" != Builtins.filterchars(word, @number_chars)
                  model_info = Ops.add(Ops.add(model_info, " "), word)
                  raise Break
                end
              end
            end
          else
            # This is usually the first word which contains a number.
            Builtins.foreach(words) do |word|
              if "" != Builtins.filterchars(word, @number_chars)
                model_info = word
                raise Break
              end
            end
          end
        else
          if words_start_with_known_manufacturer
            # there are none or up to two words which contain only letters and hyphens (the model name)
            # and then there is a word which contains at least one number (the model series).
            # Therefore the manufacturer and model sub-string can be assumed to be:
            #   One word which contains the manufacturer name,
            #   followed by at most two words which contain only letters and perhaps hyphens
            #   finished by one word which may start with letters and hyphens
            #   but it must contain at least one number followed by whatever characters.
            # It is crucial to take whatever (trailing) character in the model series into account
            # to be on the safe side to distinguish different models
            # (e.g. "HP LaserJet 4" versus "HP LaserJet 4/4M" or "Kyocera FS-1000" versus "Kyocera FS-1000+").
            # For example as egrep regular expression:
            #   lpinfo -m | cut -d' ' -f2-
            #   | egrep -o '^[[:alpha:]]+[[:space:]]+([[:alpha:]-]+[[:space:]]+){0,2}[[:alpha:]-]*[[:digit:]][^[:space:]]*'
            # Of course this best-guess is not 100% correct because it would result for example
            # that "ACME FunPrinter 1000" and "ACME FunPrinter 1000 XL"
            # are considered to be the same model "ACME FunPrinter 1000"
            # but "ACME FunPrinter 1000XL" and "ACME FunPrinter 1000 XL"
            # are considered to be different models "ACME FunPrinter 1000XL" and "ACME FunPrinter 1000":
            skip_the_rest = false
            index = -1
            words = Builtins.maplist(words) do |word|
              if !skip_the_rest
                index = Ops.add(index, 1)
                next word if 0 == index
                if 1 == index || 2 == index
                  if "" ==
                      Builtins.deletechars(word, Ops.add(@letter_chars, "-"))
                    next word
                  end
                end
                if 1 == index || 2 == index || 3 == index
                  if "" != Builtins.filterchars(word, @number_chars)
                    skip_the_rest = true
                    # Return the model series:
                    next word
                  end
                end
              end
            end
            model_info = Builtins.mergestring(words, " ")
          end
        end
      end
      Builtins.y2milestone(
        "DeriveModelName: derived '%1' from '%2' (max_words=%3)",
        model_info,
        description,
        max_words
      )
      model_info
    end

    # Derive a reasonable driver_filter_string from an arbitrary driver_filter_input_text.
    # @param string from which a driver_filter_string is derived.
    # @return [String] (possibly the empty string)
    def DeriveDriverFilterString(driver_filter_input_text)
      driver_filter_string = ""
      words = Builtins.splitstring(driver_filter_input_text, " ")
      # Remove empty words because a sequence of spaces results empty words in the list of words
      # for example "ACME  Funprinter" (two spaces!) results ["ACME","","Funprinter"]
      # and remove effectively empty words like "-", "/" as a result of e.g. "ACME Funprinter / XL"
      # i.e. remove words which do not contain at least one alphanumeric character or '+'
      # because '+' is also a meaningful character in model names.
      # For example the '+' at the end of a Kyocera model name
      # indicates that this model has a built-in PostScript interpreter
      # while the model without the '+' understands only PCL.
      # Avoid having meaningless words like "series" or "Serie"
      # or addons to the manufacturer name like "Corp." and "Inc."
      # and "Mita" (from "Kyocera Mita") in the driver_filter_string
      # (the driver_filter_string "kyocera.*FS-1000" finds the "Kyocera Mita FS-1000+")
      # and remove "Packard" from "Hewlett Packard" (without the '-') as precondition
      # to change "Hewlett-Packard", "Hewlett - Packard" and "Hewlett Packard" to "HP".
      # The '*Manufacturer' entries in our PPDs contain even more confusing stuff like
      # "KONICA MINOLTA", "Minolta", "Minolta QMS", "QMS"
      # where no good automated solution is possible.
      words = Builtins.filter(words) do |word|
        "" != Builtins.filterchars(word, Ops.add(@alnum_chars, "+")) &&
          "serie" !=
            Builtins.substring(
              Builtins.tolower(word),
              0,
              Builtins.size("serie")
            ) &&
          "inc" !=
            Builtins.substring(Builtins.tolower(word), 0, Builtins.size("inc")) &&
          "corp" !=
            Builtins.substring(Builtins.tolower(word), 0, Builtins.size("corp")) &&
          "mita" != Builtins.tolower(word) &&
          "packard" != Builtins.tolower(word)
      end
      if Ops.greater_than(Builtins.size(words), 0)
        if "hewlett" ==
            Builtins.substring(
              Builtins.tolower(Ops.get(words, 0, "")),
              0,
              Builtins.size("hewlett")
            )
          # ("Hewlett - Packard" and "Hewlett Packard" were
          #  already changed to "Hewlett" via the above filter.)
          Ops.set(words, 0, "HP")
        end
        if "oki" ==
            Builtins.substring(
              Builtins.tolower(Ops.get(words, 0, "")),
              0,
              Builtins.size("oki")
            )
          Ops.set(words, 0, "Oki")
        end
        # Match at the beginning only if the first word
        # is actually a known manufacturer name:
        words_start_with_known_manufacturer = false
        Builtins.foreach(
          # The specifically added manufacturer "Raw" is needed for a smooth setup of a "Raw Queue":
          Builtins.add(@known_manufacturers, "Raw")
        ) do |known_manufacturer|
          if Builtins.tolower(Ops.get(words, 0, "")) ==
              Builtins.tolower(known_manufacturer)
            words_start_with_known_manufacturer = true
            Ops.set(words, 0, Ops.add("^", Ops.get(words, 0, "")))
            raise Break
          end
        end 

        # Concatenate the words by the regular expression '.*' so that the search result
        # could hopefully fit better to what the user actually expects to get,
        # for example searching with "ACME 1000" should work to also
        # find "ACME FunPrinter 1000" and "ACME Fancy Printer 1000 XL":
        driver_filter_string = Builtins.mergestring(words, ".*")
        # Besides lower alphanumeric characters
        # and the characters '.*' and '^' for regular expressions
        # only the special character '+' is also taken into account
        # because this is also a meaningful character in model names.
        driver_filter_string = Builtins.filterchars(
          Builtins.tolower(driver_filter_string),
          Ops.add(@lower_alnum_chars, ".*^+")
        )
        # Replace '+' by '\\+' which evaluates to '\+' (because of YCP quoting with '\\')
        # to get a '+' character in a word quoted as '\+' because otherwise
        # a '+' character would be interpreded as a special regular expression character
        # when the driver_filter_string is used as pattern for regexpmatch in DriverItems().
        driver_filter_string = Builtins.mergestring(
          Builtins.splitstring(driver_filter_string, "+"),
          "\\+"
        )
      end
      Builtins.y2milestone(
        "DeriveDriverFilterString: derived '%1' from '%2'",
        driver_filter_string,
        driver_filter_input_text
      )
      driver_filter_string
    end

    # Create a valid new queue name.
    # @param [String] proposal string from which a valid new queue name is derived.
    # @return [String]
    def NewQueueName(proposal)
      # what is actually allowed in CUPS but such queue names are
      # safe to work in whatever mixed printing system environment:
      proposal = Builtins.filterchars(proposal, Ops.add(@alnum_chars, "_"))
      # Use a fallback queue name "printer_1" if the proposal is empty
      # (or has become empty because of the above filterchars)
      # or if the proposal consists only of '_':
      if "" == proposal || "" == Builtins.deletechars(proposal, "_")
        proposal = "printer_1"
      end
      # Remove leading '_' characters from the proposal.
      # For example if the proposal was initially something like "_foo"
      # or if it has become a leading '_' because of the above filterchars:
      if "_" == Builtins.substring(proposal, 0, 1)
        proposal = Builtins.substring(
          proposal,
          Builtins.findfirstnotof(proposal, "_")
        )
      end
      # Make sure that the queue name starts with a letter,
      # otherwise add a "printer_" prefix:
      if "" !=
          Builtins.deletechars(
            Builtins.substring(proposal, 0, 1),
            @letter_chars
          )
        proposal = Ops.add("printer_", proposal)
      end
      # Make sure that no queue with the name of the proposal already exists.
      # Otherwise add a sufficient high number at the end:
      queue_name = proposal
      trailing_number = 0
      try_again = true
      while try_again
        try_again = false
        Builtins.foreach(@queues) do |queue|
          if Builtins.tolower(Ops.get(queue, "name", "")) ==
              Builtins.tolower(queue_name)
            if Builtins.issubstring(proposal, "_")
              # to avoid that multiple trailing numbers or multiple '_' are added
              # like "funprinter_1_1" or "printer__1":
              position = Builtins.findlastof(proposal, "_")
              if "" ==
                  Builtins.deletechars(
                    Builtins.substring(proposal, position),
                    Ops.add(@number_chars, "_")
                  )
                # up to the last '_' but excluding the last '-'.
                # For example in "fun_printer_1" the string position of the last '-' is 11
                # and the first 11 characters in "fun_printer_1" are "fun_printer".
                proposal = Builtins.substring(proposal, 0, position)
              end
            end
            trailing_number = Ops.add(trailing_number, 1)
            queue_name = Ops.add(
              Ops.add(proposal, "_"),
              Builtins.tostring(trailing_number)
            )
            try_again = true
            raise Break
          end
        end 

        # Avoid an endless loop:
        if Ops.greater_than(trailing_number, 10000)
          queue_name = ""
          break
        end
      end
      queue_name
    end

    # Create the list of queues for the Table in the OverviewDialog
    # @return table items
    def QueueItems(local, remote)
      @selected_queues_index = -1
      if !AutodetectQueues()
        Popup.Error(
          # Only a simple message because this error does not happen on a normal system
          # (i.e. a system which is not totally broken or totally messed up).
          # Do not confuse this error with the case when no queue was detected
          # (e.g. simply because there is no queue). This results no error.
          _("Cannot show print queues (failed to detect print queues).")
        )
        # Return an empty list:
        return []
      end
      queues_index = -1
      queue_items = []
      Builtins.foreach(@queues) do |queue|
        queues_index = Ops.add(queues_index, 1)
        # Use local variables to have shorter variable names:
        name = Ops.get(queue, "name", "")
        uri = Ops.get(queue, "uri", "")
        description = Ops.get(queue, "description", "")
        location = Ops.get(queue, "location", "")
        config = Ops.get(queue, "config", "remote")
        is_default = Ops.get(queue, "default", "")
        is_disabled = Ops.get(queue, "disabled", "yes")
        is_rejecting = Ops.get(queue, "rejecting", "yes")
        if name != "" && uri != ""
          if config == "local" && local || config == "class" && local ||
              config == "remote" && remote
            config = _("Local") if "local" == config
            config = _("Class") if "class" == config
            config = _("Remote") if "remote" == config
            is_default = _("Yes") if "yes" == is_default
            # When the queue accepts print jobs and printing is enabled:
            queue_state = _("Ready")
            queue_state = _("Printout disabled") if "yes" == is_disabled
            if "yes" == is_rejecting
              if "yes" == is_disabled
                queue_state = _("Rejecting print jobs, printout disabled")
              else
                queue_state = _("Rejecting print jobs")
              end
            end
            # Add trailing spaces because the current YaST UI
            # has almost no additional space between table columns
            # in partitcular not where the widest entry in a column is:
            queue_items = Builtins.add(
              queue_items,
              Item(
                Id(queues_index),
                Ops.add(config, " "),
                Ops.add(name, " "),
                Ops.add(description, " "),
                Ops.add(location, " "),
                Ops.add(is_default, " "),
                queue_state
              )
            )
            # Set selected_queues_index when the current_queue_name is in the list
            # so that the OverviewDialog can preselect the currently used queue
            # via its id in the list which is the selected_queues_index.
            # This is correct for any kind of queue ("local", "class", "remote") here
            # because any queue in the list can be selected in the OverviewDialog:
            @selected_queues_index = queues_index if @current_queue_name == name
          end
        end
      end 

      # Show a fallback text if there are no queues:
      if Ops.less_than(Builtins.size(queue_items), 1)
        queue_items = Builtins.add(
          queue_items,
          Item(
            Id(-1),
            "",
            "",
            # Show a fallback text if there are no queues:
            _("There is no print queue."),
            "",
            "",
            ""
          )
        )
      end
      # Sort the lists according to the queue_string which means sort according to the queue name:
      # queue_item[0] is `id(queues_index), queue_item[1] is the config, queue_item[2] is the queue name:
      Builtins.sort(queue_items) do |one_item, another_item|
        Ops.less_than(
          Builtins.tolower(Ops.get_string(one_item, 2, "")),
          Builtins.tolower(Ops.get_string(another_item, 2, ""))
        )
      end
    end

    # Create a list of items from the autodetected connections
    # which is used for the SelectionBox in the BasicAddDialog and BasicModifyDialog.
    # This function is also called in connectionwizard.ycp and in printer_proposal.ycp.
    # @param [String] connection_filter_string string of a search string to return only matching connections
    #        (return all connections if connection_filter_string is the empty string)
    # @return [Array] of connections (i.e. DeviceURI, model, and info of the "lpinfo -l -v" output)
    def ConnectionItems(connection_filter_string)
      @selected_connections_index = -1
      @selected_ppds_index = -1
      # Autodetect printers if the connections list is empty:
      if Ops.less_than(Builtins.size(@connections), 1) ||
          "MoreConnections" == connection_filter_string
        connection_wizard_connections = []
        # Save existing connections which have been manually added by the connection wizard:
        Builtins.foreach(@connections) do |connection|
          if "ConnectionWizardDialog" == Ops.get(connection, "class", "")
            connection_wizard_connections = Builtins.add(
              connection_wizard_connections,
              connection
            )
          end
        end 

        # AutodetectPrinters overwrites the existing connections list:
        if !AutodetectPrinters()
          Popup.Error(
            # Only a simple message because before the function AutodetectPrinters
            # was called and this function would have shown more specific messages.
            _("Failed to autodetect printers.")
          )
        end
        # The connection wizard prepends its manually added connections to the connections list.
        # Therefore the connection_wizard_connections are also prepended to the connections list.
        # There is an error in the YaST documentation regarding "merge" for lists:
        # It reads "Interprets two lists as sets" which would
        # remove duplicates in each list before the merge.
        # Actually merge([1,2,2,3],[2,3,3,4]) results [1,2,2,3,2,3,3,4]
        # which is needed here to preserve any entry to be on the safe side:
        @connections = Convert.convert(
          Builtins.merge(connection_wizard_connections, @connections),
          :from => "list",
          :to   => "list <map <string, string>>"
        )
      end
      # Determine if there is at least one "hp:/usb/" DeviceURI
      # and if there is at least one "parallel:/" DeviceURI
      hp_usb_uri_exists = false
      parallel_uri_exists = false
      Builtins.foreach(@connections) do |connection_entry|
        if "hp:/usb/" ==
            Builtins.substring(Ops.get(connection_entry, "uri", ""), 0, 8)
          hp_usb_uri_exists = true
        end
        if "parallel:/" ==
            Builtins.substring(Ops.get(connection_entry, "uri", ""), 0, 10)
          parallel_uri_exists = true
        end
      end 

      # Make a list of uri, model, and info entries of the connections
      # and take the connection_filter_string into account (if it is not the empty string).
      connection_items = []
      sorted_connection_items = []
      already_added_uris = []
      an_item_was_added = false
      connections_index = -1
      uri = ""
      model = ""
      info = ""
      _class = ""
      Builtins.foreach(@connections) do |connection_entry|
        an_item_was_added = false
        # Set the connections_index to the index number of the current connection_entry:
        connections_index = Ops.add(connections_index, 1)
        # Use local variables to have shorter variable names:
        uri = Ops.get(connection_entry, "uri", "")
        model = Ops.get(connection_entry, "model", "")
        info = Ops.get(connection_entry, "info", "")
        _class = Ops.get(connection_entry, "class", "")
        # Skip effectively empty (i.e. useless) entries:
        next if "" == uri
        # Skip duplicate URIs because it does not make sense
        # to show more than one connection with the same URI because
        # for CUPS only different URIs distinguish different devices.
        # For example two same USB printer models without different serial numbers
        # are indistinguishable for CUPS so that any printout would be sent only
        # to one of both devices, usually the first one which is autodetected
        # by the CUPS backend (which is usually the first one in the USB device list).
        # Accordingly the first one in the connections list is shown to the user
        # (the ordering in the connections list is what "lpinfo -v" results)
        # and subsequent entries in the connections list with duplicate URIs
        # are hidden from what is shown to the user:
        if Builtins.contains(already_added_uris, uri)
          Builtins.y2milestone(
            "skipped connection_entry with duplicate DeviceURI: '%1'",
            connection_entry
          )
          next
        end
        # Take the filter_string into account:
        if "" == connection_filter_string
          # has almost no additional space between table columns
          # in partitcular not where the widest entry in a column is:
          connection_items = Builtins.add(
            connection_items,
            Item(
              Id(connections_index),
              Ops.add(model, " "),
              Ops.add(uri, " "),
              info
            )
          )
          an_item_was_added = true
        else
          # do a special filtering for those connections which are suitable
          # for the BasicAddDialog (i.e. only parallel, usb, and hp connections):
          if "BasicAddDialog" == connection_filter_string
            if "parallel:/" == Builtins.substring(uri, 0, 10) ||
                "usb:/" == Builtins.substring(uri, 0, 5) ||
                "hp:/" == Builtins.substring(uri, 0, 4) ||
                "ConnectionWizardDialog" == _class
              # and if there is at least one "hp:/usb/" DeviceURI
              # so that the "hp:/usb/" DeviceURI is used with preference.
              # The "usb://HP/" DeviceURI is still available via "MoreConnections".
              # It can happen that a "usb://HP/" DeviceURI is skipped
              # without a matching "hp:/usb/" DeviceURI because
              # the "hp" backend lists only devices which are known as supported by HPLIP.
              # If there are two HP printers connected but only one is supported by HPLIP,
              # there exists one "hp:/usb/" DeviceURI and therefore all "usb://HP/" DeviceURIs
              # are skipped even the one for the HP printer which is unknown to HPLIP.
              # But this is no real problem because all "usb://HP/" DeviceURIs are still
              # available via "MoreConnections".
              # Actually it is even good that HP printers which are unknown to HPLIP
              # are skipped by default because usually we do not provide a driver
              # for such printers so that the extra-cklick on "MoreConnections" may
              # make the user aware that something is fishy with this particular model
              # so that the user hopefully pays more attention which driver he selects.
              # If a HP printer is unknown to HPLIP it does not mean that it is unsupported
              # (it does also not mean that it is unsupported by HPLIP) because
              # it could be simply a new model which is not yet known to HPLIP
              # but compatible to a known model. In this case the user must pay attention
              # which exact driver he selects manually for his particular model.
              if "usb://hp/" == Builtins.tolower(Builtins.substring(uri, 0, 9)) && hp_usb_uri_exists &&
                  _class != "ConnectionWizardDialog"
                Builtins.y2milestone("skipped 'usb://HP/' DeviceURI '%1'", uri)
              else
                # and if there is at least one "parallel:/" DeviceURI
                # so that the "parallel:/" DeviceURI is used with preference.
                # The reason for this preference is that for my LaserJet 1220
                # which is accessible via "parallel:/dev/lp0" and
                # via "hp:/par/HP_LaserJet_1220?device=/dev/parport0"
                # it does not work for the "hp:/par/" DeviceURI and in /var/log/messages there is
                # ... parport0: io/hpmud/pp.c 517: compat_write_data transfer stalled
                # ... parport0: io/hpmud/musb.c 1339: unable to write data
                #     hp:/par/HP_LaserJet_1220?device=/dev/parport0: Resource temporarily unavailable
                # so that the generic "parallel:/" DeviceURI seems to be the better fail-safe default.
                # It should not happen that a "hp:/par/" DeviceURI is skipped without
                # having a matching  generic "parallel:/" DeviceURI available.
                # The "hp:/par/" DeviceURI is still available via "MoreConnections".
                if "hp:/par/" == Builtins.tolower(Builtins.substring(uri, 0, 8)) && parallel_uri_exists &&
                    _class != "ConnectionWizardDialog"
                  Builtins.y2milestone("skipped 'hp:/par/' DeviceURI '%1'", uri)
                else
                  # has almost no additional space between table columns
                  # in partitcular not where the widest entry in a column is:
                  connection_items = Builtins.add(
                    connection_items,
                    Item(
                      Id(connections_index),
                      Ops.add(model, " "),
                      Ops.add(uri, " "),
                      info
                    )
                  )
                  an_item_was_added = true
                end
              end
            end
          else
            # do a special filtering for those connections which are supposed to work
            # i.e. where the uri seems to be a complete DeviceURI e.g. "socket://192.168.1.2:9100"
            # and not just an URI scheme like a plain "socket".
            # It doesn't matter if backends (i.e. schemes) with non alphanumeric characters
            # are skipped here because for unusual backends there is the "Connection Wizard":
            if "MoreConnections" == connection_filter_string
              if Builtins.regexpmatch(
                  uri,
                  Ops.add(Ops.add("^[", @alnum_chars), "]+:/")
                ) ||
                  "ConnectionWizardDialog" == _class
                # has almost no additional space between table columns
                # in partitcular not where the widest entry in a column is:
                connection_items = Builtins.add(
                  connection_items,
                  Item(
                    Id(connections_index),
                    Ops.add(model, " "),
                    Ops.add(uri, " "),
                    info
                  )
                )
                an_item_was_added = true
              end
            else
              # test whether the model matches to the connection_filter_string:
              if Builtins.regexpmatch(
                  Builtins.tolower(model),
                  Builtins.tolower(connection_filter_string)
                )
                # has almost no additional space between table columns
                # in partitcular not where the widest entry in a column is:
                connection_items = Builtins.add(
                  connection_items,
                  Item(
                    Id(connections_index),
                    Ops.add(model, " "),
                    Ops.add(uri, " "),
                    info
                  )
                )
                an_item_was_added = true
              end
            end
          end
        end
        if an_item_was_added
          already_added_uris = Builtins.add(already_added_uris, uri)
          if @current_device_uri == uri
            # BasicAddDialog and BasicModifyDialog can preselect the currently used connection
            # via its id in the list which is the selected_connections_index.
            @selected_connections_index = connections_index
          end
        end
      end 

      # Sort the list according to the model:
      # connection_item[0] is `id(connections_index)
      # connection_item[1] is the model
      # connection_item[2] is the uri
      # connection_item[3] is the info
      # The comparison expression must evaluate to a boolean value and
      # it must be irreflexive (e.g. "<" instead of "<=") which results conditions like
      # 'a condition for one item' and 'not the same condition for the other item'
      sorted_connection_items = Builtins.sort(connection_items) do |one_item, another_item|
        # or "modified by the connection wizard" topmost:
        # Have short local variable names for shorter comparison expression
        # and avoid multiple complicated accesses of same elements in an list:
        this = Ops.get_string(one_item, 3, "")
        that = Ops.get_string(another_item, 3, "")
        connection_wizard_match = "by the connection wizard"
        # This is an entry where the info is "created/modified by the connection wizard"
        # and that is no such entry:
        if Builtins.issubstring(this, connection_wizard_match) &&
            !Builtins.issubstring(that, connection_wizard_match)
          next true
        end
        # This is an entry where the info is not "created/modified by the connection wizard"
        # but that is such an entry:
        if !Builtins.issubstring(this, connection_wizard_match) &&
            Builtins.issubstring(that, connection_wizard_match)
          next false
        end
        # If both are "created/modified by the connection wizard"
        # or if both are not "created/modified by the connection wizard"
        # have entries with a valid model name topmost:
        # Have short local variable names for shorter comparison expression
        # and avoid multiple complicated accesses of same elements in an list:
        this = Ops.get_string(one_item, 1, "")
        that = Ops.get_string(another_item, 1, "")
        # This is an entry where the model is neither empty nor "Unknown"
        # and that is no such entry:
        if this != "" && Builtins.tolower(this) != "unknown" &&
            (that == "" || Builtins.tolower(that) == "unknown")
          next true
        end
        # This is an entry where the model is empty or "Unknown"
        # and that is no such entry:
        if (this == "" || Builtins.tolower(this) == "unknown") &&
            that != "" && Builtins.tolower(that) != "unknown"
          next false
        end
        # Fall back to alphabetical sorting of the model name:
        Ops.less_than(Builtins.tolower(this), Builtins.tolower(that))
      end
      if Ops.less_than(Builtins.size(sorted_connection_items), 1)
        sorted_connection_items = [
          Item(
            Id(-1),
            "",
            # Show a fallback text if there are no connections.
            _("No connections."),
            # A hint what to do if there are no connections.
            # 'Detect More' and 'Connection Wizard' are
            # button lables and must be translated accordingly:
            _("Try 'Detect More' or use the 'Connection Wizard'.")
          )
        ]
      end
      deep_copy(sorted_connection_items)
    end

    # Create a list of items from the PPD database entries
    # which is used for the SelectionBox in the BasicAddDialog and SelectDriverDialog
    # @param [String] driver_filter_string string of a search string to return only matching PPDs
    #        (return all PPDs if driver_filter_string is the empty string)
    # @return [Array] of drivers (i.e. the NickName entries of the PPDs)
    def DriverItems(driver_filter_string, preselection)
      if Ops.less_than(Builtins.size(@ppds), 1)
        if !CreateDatabase()
          Popup.Error(
            # Only a simple message because before the function CreateDatabase
            # was called and this function would have shown more specific messages.
            _("Failed to create the printer driver database.")
          )
          # Return an empty list:
          return []
        end
      end
      driver_items = []
      sorted_driver_items = []
      driver_string = ""
      # If the driver_filter_string is the special string "BasicAddDialog",
      # produce a special fast output which is suitable to be shown
      # initially when the BasicAddDialog is launched:
      if "BasicAddDialog" == driver_filter_string
        if preselection && Ops.greater_or_equal(@selected_ppds_index, 0)
          # if preselection should be done at all:
          driver_string = Ops.add(
            Ops.add(
              Ops.add(
                Ops.get(@ppds, [@selected_ppds_index, "nickname"], ""),
                " ["
              ),
              Ops.get(@ppds, [@selected_ppds_index, "ppd"], "")
            ),
            "]"
          )
          driver_items = [Item(Id(@selected_ppds_index), driver_string, true)]
        else
          # fallback entry for a SelectionBox when no connection is selected.
          # It will be replaced by real content, when a connection is selected.
          driver_string = _(
            "Select a connection, then matching drivers show up here."
          )
          driver_items = [Item(Id(-1), driver_string)]
          # Invalidate selected_ppds_index to be on the safe side.
          # Otherwise it is possible to set up a queue with a previously selected driver
          # even if the current dialog does not show it.
          @selected_ppds_index = -1
        end
        return deep_copy(driver_items)
      end
      # Make a list of the NickName entries of the PPDs according to the PPD database
      # and take the driver_filter_string into account (if it is not the empty string)
      # and try to preselect an entry according to a selected autodetected printer:
      Popup.ShowFeedback(
        "",
        # Busy message:
        # Body of a Popup::ShowFeedback:
        _("Determining matching printer drivers...")
      )
      Builtins.y2milestone(
        "The driver_filter_string is: '%1'",
        driver_filter_string
      )
      ppds_index = -1
      Builtins.foreach(@ppds) do |ppd_entry|
        ppds_index = Ops.add(ppds_index, 1)
        # Use local variables to have shorter variable names:
        ppd = Ops.get(ppd_entry, "ppd", "")
        nickname = Ops.get(ppd_entry, "nickname", "")
        deviceID = Ops.get(ppd_entry, "deviceID", "")
        language = Ops.get(ppd_entry, "language", "")
        # Skip effectively empty (i.e. useless) entries:
        next if "" == ppd || "" == nickname
        # Build the entry:
        driver_string = Ops.add(Ops.add(Ops.add(nickname, " ["), ppd), "]")
        # Take the filter_string into account:
        if "" == driver_filter_string
          driver_items = Builtins.add(
            driver_items,
            Item(Id(ppds_index), driver_string)
          )
        else
          # test whether nickname or deviceID matches to the driver_filter_string.
          # Only the special character '+' is also taken into account because
          # this is also a meaningful character in the model name.
          # For example the '+' at the end of a Kyocera model name
          # indicates that this model has a built-in PostScript interpreter
          # while the model without the '+' understands only PCL.
          unified_nickname = Builtins.filterchars(
            Builtins.tolower(nickname),
            Ops.add(@lower_alnum_chars, "+")
          )
          unified_deviceID = Builtins.filterchars(
            Builtins.tolower(deviceID),
            Ops.add(@lower_alnum_chars, "+")
          )
          if Builtins.regexpmatch(unified_nickname, driver_filter_string) ||
              Builtins.regexpmatch(unified_deviceID, driver_filter_string)
            driver_items = Builtins.add(
              driver_items,
              Item(Id(ppds_index), driver_string)
            )
          end
        end
      end 

      if Builtins.size(driver_items) == 0
        # show a meaningful text as fallback entry ('Find More' is a button label).
        driver_string = _(
          "No matching driver found. Change the search string or try 'Find More'."
        )
        driver_items = [Item(Id(-1), driver_string)]
        # Invalidate selected_ppds_index to be on the safe side.
        # Otherwise it is possible to set up a queue with a previously selected driver
        # even if the current dialog does not show it.
        @selected_ppds_index = -1
        Popup.ClearFeedback
        return deep_copy(driver_items)
      end
      # More feedback to stay in contact with the user
      # if the list of driver_items is very long
      # e.g. when all PPDs are shown (several thousand)
      # or when all PPDs for "HP" are shown (more than 1000)
      # or when all PPDs for "Epson" are shown (more than 500).
      # Then it takes some time to determine if a PPD can be preselected
      # and to sort the list.
      # Actually it is the sorting which takes most of the time but for the user
      # a feedback message like "sorting list of drivers" is meaningless.
      if Ops.greater_than(Builtins.size(driver_items), 500)
        Popup.ShowFeedback(
          "",
          # Busy message:
          # Body of a Popup::ShowFeedback:
          _("Processing many printer drivers. Please wait...")
        )
        # Sleep half a second to let the user notice the feedback in any case:
        Builtins.sleep(500)
      end
      # Preselect the entry in the driver_items list which matches
      # to the current value of selected_ppds_index
      # if such an entry exists in driver_items (e.g. because of the
      # driver_filter_string there may be no such entry in driver_items) and
      # if preselection should be done at all:
      driver_items_index = -1
      selected_driver_items_index = -1
      # Determine if such an entry exists:
      Builtins.foreach(driver_items) do |driver_item|
        driver_items_index = Ops.add(driver_items_index, 1)
        # driver_item[0] is the term `id(ppds_index) and id[0] is the ppds_index
        # so that driver_item[0,0] is the ppds_index:
        if @selected_ppds_index == Ops.get_integer(driver_item, [0, 0], -1)
          selected_driver_items_index = driver_items_index
          raise Break
        end
      end 

      if preselection && Ops.greater_or_equal(selected_driver_items_index, 0)
        # driver_items[selected_driver_items_index] is a driver_item and
        # driver_item[1] is the driver_string and
        # driver_item[0] is the term `id(ppds_index) and id[0] is the ppds_index
        # so that driver_item[0,0] is the ppds_index so that
        # driver_items[selected_driver_items_index,0,0] is the ppds_index:
        @selected_ppds_index = Ops.get_integer(
          driver_items,
          [selected_driver_items_index, 0, 0],
          -1
        )
        driver_string = Ops.get_string(
          driver_items,
          [selected_driver_items_index, 1],
          ""
        )
        Ops.set(
          driver_items,
          selected_driver_items_index,
          Item(Id(@selected_ppds_index), driver_string, true)
        )
        Builtins.y2milestone("Already preselected driver: '%1'", driver_string)
      else
        # Otherwise it is possible to set up a queue with a previously selected driver
        # even if the current dialog does not show it.
        @selected_ppds_index = -1
      end
      # Sort the driver_items list.
      # There are two kind of sorting the driver_items list.
      # By default, the list is sorted according to the driver_string
      # which is basically sorting according to NickName (first part of driver_string)
      # which is basically sorting according to Manufacturer and ModelName (first parts of NickName).
      # But when all elements in the driver_items list belong to the same model,
      # it would be nicer to sort according to which PPD looks most suitable for the model
      # (i.e. according to the above step-by-step approach to preselect a PPD).
      # The real problem is that the NickName is a plain sequence of words which describe
      # manufacturer, model, driver, and optionally whether the driver is recommended
      # but there are no delimiters which mark where the model info begins and ends.
      # Some NickName examples (note the one missing ')' after recommended):
      #   Brother HL-10h Foomatic/lj4dith
      #   Canon BJC-600 Foomatic/bjc610a0.upp
      #   Canon S600 Foomatic/bj8pa06n.upp (recommended)
      #   DesignJet 5000PS (recommended)
      #   designjet 5500ps (recommended)
      #   EPSON AL-2600 PS3 v3016.103
      #   Epson E 100 - CUPS+Gutenprint v5.0.0 Simplified
      #   Epson Stylus Color 8 3 - CUPS+Gutenprint v5.0.0
      #   Epson Stylus Color PRO Foomatic/stcolor (recommended)
      #   EPSON Stylus Color Series CUPS v1.2
      #   Epson Stylus Photo EX - CUPS+Gutenprint v5.0.0 Simplified
      #   Epson Stylus Photo EX3 - CUPS+Gutenprint v5.0.0
      #   Generic IBM-Compatible Dot Matrix Printer Foomatic/ibmpro (recommended)
      #   Generic PCL 4 Printer - CUPS+Gutenprint v5.0.0 Simplified
      #   Gestetner MP1100/DSm7110 PS plain PostScript
      #   Gestetner P7026n PS PostScript+Foomatic (recommended)
      #   HP 2500CM Foomatic/hpijs
      #   HP Color LaserJet 2500 - CUPS+Gutenprint v5.0.0 black and white only
      #   HP Color LaserJet Series PCL 6 CUPS
      #   HP DesignJet 2500CP PS3 v3010.103 (recommended
      #   HP DeskJet 2500CM - CUPS+Gutenprint v5.0.0
      #   HP e-printer e20 Foomatic/hpijs (recommended)
      #   HP LaserJet 4 Foomatic/ljet4 (recommended)
      #   HP LaserJet 4 Plus v2013.111 Postscript (recommended)
      #   HP LaserJet 4/4M 600DPI Postscript (recommended)
      #   HP PSC 2500 Foomatic/hpijs (recommended)
      #   Kyocera FS-1000 Foomatic/ljet4
      #   Kyocera FS-1000+ Foomatic/Postscript
      #   Kyocera KM-3530 Foomatic/Postscript (recommended)
      #   Kyocera Mita KM-3530
      #   Kyocera Mita KM-4230/5230
      #   NRG 10515/10518/10512 Foomatic/pxlmono (recommended)
      #   NRG 10515/10518/10512 PXL Foomatic/pxlmono (recommended)
      #   OKI C5450 PS
      #   OKI C5700(PS)
      #   OKIPAGE 14i
      #   Oki Okipage 14ex Foomatic/ljet4
      #   Okidata Okipage 14ex - CUPS+Gutenprint v5.0.0
      #   TOSHIBA e-STUDIO3510c Series PS
      #   Toshiba e-Studio 3511 Foomatic/Postscript (recommended)
      #   Toshiba e-Studio 351c Foomatic/Postscript (recommended)
      # It is not possible to extract manufacturer and model reliable from the NickName.
      # Only a best-guess which is as fail-safe as possible can be done.
      # An usual full qualified model description looks like:
      #   ACME FunPrinter 1000
      #   ACME Fun Printer 1000
      #   ACME FunPrinter 1000XL
      #   ACME Fun Printer 1000 XL
      #   ACME Fun Printer 1000-XL
      #   ACME 1000XL
      #   ACME FunPrinter Pro 1000XL
      #   ACME Pro-1000-XL
      #   ACME Ltd. Fun Printer Pro 1000 XL
      # After at least one words which contains only letters (the manufacturer name)
      # there are none or up to two words which contain only letters and hyphens (the model name)
      # and then there is a word which contains at least one number (the model series).
      # Therefore the manufacturer and model sub-string can be assumed to be:
      #   One word which contains only letters,
      #   followed by at most two words which contain only letters and perhaps hyphens
      #   finished by one word which may start with letters and hyphens
      #   but it must contain at least one number followed by whatever characters.
      # It is crucial to take whatever (trailing) character in the model series into account
      # to be on the safe side to distinguish different models
      # (e.g. "HP LaserJet 4" versus "HP LaserJet 4/4M" or "Kyocera FS-1000" versus "Kyocera FS-1000+").
      # For example as egrep regular expression:
      #   lpinfo -m | cut -d' ' -f2-
      #   | egrep -o '^[[:alpha:]]+[[:space:]]+([[:alpha:]-]+[[:space:]]+){0,2}[[:alpha:]-]*[[:digit:]][^[:space:]]*'
      # Of course this best-guess is not 100% correct because it would result for example
      # that "ACME FunPrinter 1000" and "ACME FunPrinter 1000 XL" are considered to be the same model
      # but "ACME FunPrinter 1000XL" and "ACME FunPrinter 1000 XL" are considered to be different models.
      # The latter results no problem because the special sorting is only done
      # when all entries in the driver_items list seem to belong to the same model.
      # But the former results a small problem because the special sorting is done here
      # for different models with similar names.
      # To mitigate such problems, the special sorting is only done
      # when the driver_items list is short so that the user can easily survey the whole list.
      # For example the PPDs in openSUSE 10.2
      #   lpinfo -m | cut -d' ' -f2-
      #   | egrep -o '^[[:alpha:]]+[[:space:]]+([[:alpha:]-]+[[:space:]]+){0,2}[[:alpha:]-]*[[:digit:]][^[:space:]]*'
      #   | sort -f | uniq -i -c | sort -n
      # results that the maximum lenght of the driver_items list for the same model is 13
      # (in openSUSE 10.2 the 13 entries are for the "Kyocera FS-600").
      # In openSUSE 10.2 there are only 4 models (HP LaserJet 4, 4100, 9000 and the Kyocera FS-600)
      # for which more than 9 entries exist (11 for LaserJet 4100 and 12 for LaserJet 4 and 9000)
      # but there are 23 models with 9 entries (there is no no model with 10 entries).
      # Since there is /usr/lib/cups/driver/gutenprint.* the Gutenprint entries are listed twice:
      # Once for the readymade PPDs in /usr/share/cups/model/gutenprint/
      # and additionally a second entry from /usr/lib/cups/driver/gutenprint.*
      # which increases the maximum lenght of the driver_items list for the same model
      # in openSUSE 11.0 up to 17 for the Kyocera FS-600 and 16 for the HP LaserJet 4
      # and several other HP LaserJet and Kyocera models with more than 10 entries
      # so that a maximum of 20 entries for the special sorting should be o.k.:
      if Ops.less_or_equal(Builtins.size(driver_items), 20)
        position = []
        manufacturer_and_model = ""
        driver_items_index = -1
        Builtins.foreach(driver_items) do |driver_item|
          driver_items_index = Ops.add(driver_items_index, 1)
          if 0 == driver_items_index
            # (driver_item[0] is `id(ppds_index) and driver_item[1] is the driver_string):
            position = Builtins.regexppos(
              Ops.get_string(driver_item, 1, ""),
              "^[[:alpha:]]+[[:space:]]+([[:alpha:]-]+[[:space:]]+){0,2}[[:alpha:]-]*[[:digit:]][^[:space:]]*"
            )
            # driver_item[1] is the driver_string which is nickname + ppd:
            manufacturer_and_model = Builtins.substring(
              Ops.get_string(driver_item, 1, ""),
              Ops.get(position, 0, 0),
              Ops.get(position, 1, 0)
            )
            # Break if manufacturer_and_model is empty or seems too short to be really meaningful
            # (shortest manufacturer and model strings are e.g. "HP PSC 500", "Epson E 100", "Star LC 90"):
            if "" == manufacturer_and_model ||
                Ops.less_than(Builtins.size(manufacturer_and_model), 10)
              driver_items_index = -1
              raise Break
            end
          else
            other_manufacturer_and_model = Builtins.substring(
              Ops.get_string(driver_item, 1, ""),
              Ops.get(position, 0, 0),
              Ops.get(position, 1, 0)
            )
            other_manufacturer_and_model = Builtins.filterchars(
              Builtins.tolower(other_manufacturer_and_model),
              @lower_alnum_chars
            )
            if other_manufacturer_and_model !=
                Builtins.filterchars(
                  Builtins.tolower(manufacturer_and_model),
                  @lower_alnum_chars
                )
              driver_items_index = -1
              raise Break
            end
          end
        end 

        if Ops.greater_or_equal(driver_items_index, 0)
          Builtins.y2milestone(
            "All entries in the driver_items list seem to belong to the same model: '%1'",
            manufacturer_and_model
          )
          # Return a list which is sorted according to which PPD looks most suitable for the model.
          # Define the regular expression strings for comparisons which are
          # used for the special sorting of the drivers list.
          # Define also the matching weights for the special sorting of the drivers list.
          # The weight values are of the form 2^n so that the sum of all weights up to n-1
          # is less than the weight for the layer n comparison.
          # The smallest weight is 1 for the fallback alphabetical comparison.
          # Therefore the special comparisons here start with 2 up to whatever layer is needed.
          # The double \\ in YCP results a single \ in the actual string value
          # so that in the end there is \( and \) and \[ in the regular expression.
          # This is a PPD which was downloaded by the user:
          downloaded = "\\[downloaded/"
          downloaded_weight = 32
          # This is an original PPD from a manufacturer:
          manufacturerPPD = "\\[manufacturer-PPDs/"
          manufacturerPPD_weight = 16
          # This is a recommended PPD:
          recommended = "\\(recommended\\)"
          recommended_weight = 8
          # This is a PPD from the HPLIP project (HP Linux Imaging and Printing):
          hplip = "/hplip/"
          hplip_weight = 4
          # This is a PPD for a ESC/P2 driver from Gutenprint (formerly Gimp-Print)
          gutenprint_escp2 = "\\[gutenprint/stp-escp2-"
          gutenprint_escp2_weight = 2
          # This is a PPD for the ljet4 driver from OpenPrinting (formerly LinuxPrinting):
          foomatic_ljet4 = "Foomatic/ljet4"
          foomatic_ljet4_weight = 2
          # The comparison expression must evaluate to a boolean value and
          # it must be irreflexive (e.g. "<" instead of "<=").
          # Therefore the comparison expression calculates weights for both items
          # so that at the end a simple numerical comparison of the weights is sufficient.
          # (driver_item[0] is `id(ppds_index) and driver_item[1] is the driver_string):
          sorted_driver_items = Builtins.sort(driver_items) do |one_item, another_item|
            # and avoid multiple complicated accesses of same elements in a list:
            this = Ops.get_string(one_item, 1, "")
            that = Ops.get_string(another_item, 1, "")
            this_weight = 0
            that_weight = 0
            # Sum up the weights:
            # Add the weight if it is a PPD which was downloaded by the user:
            if Builtins.regexpmatch(this, downloaded)
              this_weight = Ops.add(this_weight, downloaded_weight)
            end
            if Builtins.regexpmatch(that, downloaded)
              that_weight = Ops.add(that_weight, downloaded_weight)
            end
            # Add the weight if it is a recommended PPD:
            if Builtins.regexpmatch(this, recommended)
              this_weight = Ops.add(this_weight, recommended_weight)
            end
            if Builtins.regexpmatch(that, recommended)
              that_weight = Ops.add(that_weight, recommended_weight)
            end
            # Add the weight if it is an original PPD from a manufacturer:
            if Builtins.regexpmatch(this, manufacturerPPD)
              this_weight = Ops.add(this_weight, manufacturerPPD_weight)
            end
            if Builtins.regexpmatch(that, manufacturerPPD)
              that_weight = Ops.add(that_weight, manufacturerPPD_weight)
            end
            # Add the weight if it is a PPD from the HPLIP project:
            if Builtins.regexpmatch(this, hplip)
              this_weight = Ops.add(this_weight, hplip_weight)
            end
            if Builtins.regexpmatch(that, hplip)
              that_weight = Ops.add(that_weight, hplip_weight)
            end
            # Add the weight if it is a PPD for a ESC/P2 driver from Gutenprint:
            if Builtins.regexpmatch(this, gutenprint_escp2)
              this_weight = Ops.add(this_weight, gutenprint_escp2_weight)
            end
            if Builtins.regexpmatch(that, gutenprint_escp2)
              that_weight = Ops.add(that_weight, gutenprint_escp2_weight)
            end
            # Add the weight if it is a PPD for the ljet4 driver from OpenPrinting:
            if Builtins.regexpmatch(this, foomatic_ljet4)
              this_weight = Ops.add(this_weight, foomatic_ljet4_weight)
            end
            if Builtins.regexpmatch(that, foomatic_ljet4)
              that_weight = Ops.add(that_weight, foomatic_ljet4_weight)
            end
            # Add the weight 1 for the fallback alphabetical comparison:
            if Ops.less_than(Builtins.tolower(this), Builtins.tolower(that))
              this_weight = Ops.add(this_weight, 1)
            end
            if Ops.less_than(Builtins.tolower(that), Builtins.tolower(this))
              that_weight = Ops.add(that_weight, 1)
            end
            # Return the result of the numerical comparison of the weights.
            # Return true to get this alphabetically sorted before that:
            Ops.greater_than(this_weight, that_weight)
          end
          # If neither a downloaded PPD nor a recommended PPD nor a manufacturer PPD exists,
          # do not preselect any PPD because in this case there is nothing which indicates
          # that a particular PPD is known to work - i.e. it looks really problematic
          # so that now it is only the user who can make a decission in this case
          # (even if all he can do is guessing but then he knows at least what he did).
          # Because of the above sorting it is sufficient to test only the first entry in sorted_driver_items.
          # sorted_driver_items[0] is the first entry in sorted_driver_items and
          # sorted_driver_item[1] is the driver_string and
          # sorted_driver_item[0] is the term `id(ppds_index) and id[0] is the ppds_index
          # so that sorted_driver_item[0,0] is the ppds_index so that
          # sorted_driver_items[0,0,0] is the ppds_index:
          driver_string = Ops.get_string(sorted_driver_items, [0, 1], "")
          # Preselect the first entry in sorted_driver_items
          # if preselection should be done at all and
          # if there is not alredy an entry preselected and if a preselectable PPD exists:
          if preselection && -1 == @selected_ppds_index &&
              (Builtins.regexpmatch(driver_string, downloaded) ||
                Builtins.regexpmatch(driver_string, recommended) ||
                Builtins.regexpmatch(driver_string, manufacturerPPD))
            @selected_ppds_index = Ops.get_integer(
              sorted_driver_items,
              [0, 0, 0],
              -1
            )
            # The first entry in a SelectionBox is always preselected in the GUI
            # (it does not help to have all items in a SelectionBox with 'false' as third argument).
            # Do not have this entry preselected (i.e. no 'true' as a third argument)
            # because in the BasicModifyDialog the currently used driver is additionally prepended
            # and then the currently used driver must be preselected by default because
            # the currently used driver is then the very first entry in the SelectionBox.
            Builtins.y2milestone("Preselected driver: '%1'", driver_string)
          end
          # The specially sorted_driver_items list has a maximum of 20 entries which is o.k. for the log:
          Builtins.y2milestone("sorted_driver_items: %1", sorted_driver_items)
          if Ops.less_than(@selected_ppds_index, 0)
            # because the first entry in a SelectionBox is always preselected in the GUI
            # (it does not help to have all items in a SelectionBox with 'false' as third argument).
            # Do not have this dummy entry preselected (i.e. no 'true' as a third argument)
            # because in the BasicModifyDialog the currently used driver is additionally prepended
            # and then the currently used driver must be preselected by default because
            # the currently used driver is then the very first entry in the SelectionBox.
            sorted_driver_items = Builtins.prepend(
              sorted_driver_items,
              Item(Id(-1), _("Select a driver."))
            )
            Builtins.y2milestone("No driver preselected.")
          end
          Popup.ClearFeedback
          return deep_copy(sorted_driver_items)
        end
      end
      # Return a list which is sorted according to the driver_string which is basically
      # sorting according to Nickname which is the first part of the driver_string
      # (driver_item[0] is `id(ppds_index) and driver_item[1] is the driver_string).
      sorted_driver_items = Builtins.sort(driver_items) do |one_item, another_item|
        Ops.less_than(
          Builtins.tolower(Ops.get_string(one_item, 1, "")),
          Builtins.tolower(Ops.get_string(another_item, 1, ""))
        )
      end
      if Ops.less_than(@selected_ppds_index, 0)
        # because the first entry in a SelectionBox is always preselected in the GUI
        # (it does not help to have all items in a SelectionBox with 'false' as third argument).
        # Do not have this dummy entry preselected (i.e. no 'true' as a third argument)
        # because in the BasicModifyDialog the currently used driver is additionally prepended
        # and then the currently used driver must be preselected by default because
        # the currently used driver is then the very first entry in the SelectionBox.
        sorted_driver_items = Builtins.prepend(
          sorted_driver_items,
          Item(Id(-1), _("Select a driver."))
        )
        Builtins.y2milestone("No driver preselected.")
      end
      Popup.ClearFeedback
      deep_copy(sorted_driver_items)
    end

    # Add new queue or overwrite existing queue
    # @return true on success
    def AddQueue(queue_name, is_default_queue, default_paper_size)
      queue_name = Builtins.deletechars(queue_name, "'")
      default_paper_size = Builtins.deletechars(default_paper_size, "'")
      uri = Builtins.deletechars(
        Ops.get(@connections, [@selected_connections_index, "uri"], ""),
        "'"
      )
      ppd = Builtins.deletechars(
        Ops.get(@ppds, [@selected_ppds_index, "ppd"], ""),
        "'"
      )
      model = Builtins.deletechars(
        Ops.get(@connections, [@selected_connections_index, "model"], ""),
        "'"
      )
      description = Builtins.deletechars(
        Ops.get(@ppds, [@selected_ppds_index, "nickname"], ""),
        "'"
      )
      if "" != description && "" != model &&
          "unknown" != Builtins.tolower(model) &&
          !Builtins.issubstring(
            Builtins.filterchars(
              Builtins.tolower(description),
              @lower_alnum_chars
            ),
            Builtins.filterchars(Builtins.tolower(model), @lower_alnum_chars)
          )
        description = Ops.add(Ops.add(model, " with driver "), description)
      end
      if "" == uri || "" == ppd || "" == queue_name
        Builtins.y2milestone(
          "Cannot set up queue because of empty mandatory parameter: queue_name = '%1', uri = '%2', ppd = '%3'",
          queue_name,
          uri,
          ppd
        )
        @current_queue_name = ""
        @current_device_uri = ""
        return false
      end
      # Note the bash quotings of the parameters with ' characters:
      commandline = Ops.add(
        Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add("/usr/sbin/lpadmin -h localhost -p '", queue_name),
                    "' -v '"
                  ),
                  uri
                ),
                "' -m '"
              ),
              ppd
            ),
            "' -D '"
          ),
          description
        ),
        "' -E"
      )
      if !Printerlib.ExecuteBashCommand(commandline)
        Popup.ErrorDetails(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("Failed to add queue %1."),
            queue_name
          ), # Popup::ErrorDetails message where %1 will be replaced by the queue name.
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        # When the PPD file is totally broken, it will not be accepted by the cupsd.
        # In this case lpadmin shows an error message and exits with non-zero exit code
        # but nevertherless the queue is created without a PPD file, i.e. as a raw queue.
        # It seems that first of all lpadmin creates the queue and then
        # in a second step it is modified to assign the PPD file,
        # see http://www.cups.org/newsgroups.php?gcups.bugs+T+Q"STR+%232949"
        # Because this AddQueue function is only used to add a not-yet-existing queue,
        # it is safe to try to remove the queue in any case if the setup had failed
        # but ignore any possible errors here (e.g. when the queue does not exist).
        Printerlib.ExecuteBashCommand(
          Ops.add(
            Ops.add("/usr/sbin/lpadmin -h localhost -x '", queue_name),
            "'"
          )
        )
        @current_queue_name = ""
        @current_device_uri = ""
        return false
      end
      # If the new queue was created successfully, make it the default queue if this is requested:
      if is_default_queue
        # with other option settings so that a separate lpadmin command is called:
        commandline = Ops.add(
          Ops.add("/usr/sbin/lpadmin -h localhost -d '", queue_name),
          "'"
        )
        # Do not care if it fails to make it the default queue (i.e. show no error message to the user)
        # because the default queue setting is nice to have but not mandatoty for a working queue:
        Printerlib.ExecuteBashCommand(commandline)
      end
      # Try to set the requested default_paper_size if it is an available choice for this queue.
      # If no default_paper_size is requested, the CUPS default is used.
      # For the CUPS 1.3 default see http://www.cups.org/str.php?L2846
      # For CUPS 1.4 the default depends on the "DefaultPaperSize" setting in cupsd.conf
      # see https://bugzilla.novell.com/show_bug.cgi?id=395760
      # and http://www.cups.org/str.php?L2848
      if "" != default_paper_size
        # after the defaults have been changed directly after a new queue was set up
        # see https://bugzilla.novell.com/show_bug.cgi?id=520642
        # and http://www.cups.org/str.php?L3264
        # Regardless of the DirtyCleanInterval setting it works when there is one second delay
        # between a new queue was set up and before its defaults were changed:
        Builtins.sleep(1000)
        # The following command fails intentionally if the queue has no PPD file - i.e. when it is a "raw" queue
        # (a queue with a "System V style interface script" cannot be set up with YaST).
        # '\>' is used to find an available choice also when it is the last value on the line.
        # Note the YCP quoting: \\< becomes \< and \\> becomes \> in the commandline.
        commandline = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add("lpoptions -h localhost -p '", queue_name),
              "' -l | grep '^PageSize.*\\<"
            ),
            default_paper_size
          ),
          "\\>'"
        )
        if Printerlib.ExecuteBashCommand(commandline)
          commandline = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add("/usr/sbin/lpadmin -h localhost -p '", queue_name),
                "' -o 'PageSize="
              ),
              default_paper_size
            ),
            "'"
          )
          # Do not care if it fails to set the default_paper_size (i.e. show no error message to the user)
          # because the default_paper_size setting is nice to have but not mandatoty for a working queue:
          Printerlib.ExecuteBashCommand(commandline)
        end
      end
      @current_queue_name = queue_name
      @current_device_uri = uri
      true
    end

    # Delete queue
    # @return true on success
    def DeleteQueue(queue_name)
      @selected_queues_index = -1
      @current_queue_name = ""
      @current_device_uri = ""
      if "" == queue_name
        queue_name = Ops.get(@queues, [@selected_queues_index, "name"], "")
        if "local" !=
            Ops.get(@queues, [@selected_queues_index, "config"], "remote") &&
            "class" !=
              Ops.get(@queues, [@selected_queues_index, "config"], "remote")
          Builtins.y2milestone(
            "Cannot delete '%1' because it is no local configuration",
            queue_name
          )
          return false
        end
      end
      # Delete ' characters because they are used for quoting in the bash commandline below:
      queue_name = Builtins.deletechars(queue_name, "'")
      if "" == queue_name
        Builtins.y2milestone(
          "Cannot delete queue because queue_name is the empty string"
        )
        return false
      end
      # Note the bash quoting of the queue_name string with ' characters:
      commandline = Ops.add(
        Ops.add("/usr/sbin/lpadmin -h localhost -x '", queue_name),
        "'"
      )
      if !Printerlib.ExecuteBashCommand(commandline)
        Popup.ErrorDetails(
          Builtins.sformat(
            # Only a simple message because this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            _("Failed to delete configuration %1."),
            queue_name
          ), # Popup::ErrorDetails message where %1 will be replaced by the queue name.
          Ops.get_string(Printerlib.result, "stderr", "")
        )
        return false
      end
      true
    end

    # Create a list of tree widget items from the driver_options
    # which is used for the tree widget in the DriverOptionsDialog
    # @param [String] selected_keyword string of an already selected keyword
    #        to have the matching values list opened by default in the tree
    # @param [String] selected_value string of a selected value which matches to the selected_keyword string
    #        to show this value in the tree (which might be different than the value of the queue)
    # @return [Array] of driver options items for a tree widget
    def DriverOptionItems(selected_keyword, selected_value)
      if Ops.less_than(Builtins.size(@driver_options), 1)
        if !DetermineDriverOptions("")
          Popup.Error(
            # Only a simple message because this is only a fallback case
            # which should not happen at all:
            _("Failed to determine the driver options.")
          )
          # Return at least a list with only a fallback string so that the user is informed:
          return [_("No driver options available")]
        end
      end
      # Info for a currently selected item which is to be set as new value in the system:
      currently_selected_info = _("new value")
      # Info for a current setting which is the currently still saved value in the system:
      current_setting_info = _("saved value")
      # It seems to be impossible to preselect the currently selected item in a Tree widget.
      # In particular `item( value, true) does not preselect it.
      # Therefore an info string is appended to the option value string to mark the currently selected item.
      # This addendum is separated by a space and removed in driveroptions.ycp
      # because spaces in main keywords or option keywords violate the PPD specification
      # so that the first word in such a string can be split as the option value keyword.
      driver_options_tree_items_list = []
      driver_options_index = -1
      pagesize_option_index = -1
      Builtins.foreach(@driver_options) do |driver_option|
        driver_options_index = Ops.add(driver_options_index, 1)
        opened = false
        keyword = Ops.get_string(driver_option, "keyword", "")
        # Show only options with at least one real value.
        # Even if there is no choice when there is only one value,
        # the user should at least see what the setting is.
        # Test for '>1' because last entry in the "values" list is always an emtpy string.
        # Additionally do not show the PageRegion option because
        # the media size should usually only be set via the PageSize option
        # and the PageRegion has a special purpose (see the Adobe PPD spec.)
        # so that from the user's point of view PageRegion looks like
        # a confusing duplicate of PageSize:
        if "" != keyword &&
            Ops.greater_than(
              Builtins.size(Ops.get_list(driver_option, "values", [])),
              1
            ) &&
            "PageRegion" != keyword
          pagesize_option_index = driver_options_index if "PageSize" == keyword
          # Have the value list opened for the currently selected keyword:
          if selected_keyword == keyword
            opened = true
            # If the user had selected a value for this keyword
            # store it so that if is know for subsequent DriverOptionItems calls:
            if "" != selected_value
              Ops.set(
                @driver_options,
                driver_options_index,
                Builtins.add(
                  Ops.get(@driver_options, driver_options_index, {}),
                  "selected",
                  selected_value
                )
              )
            end
          end
          currently_selected_value = Ops.get_string(
            @driver_options,
            [driver_options_index, "selected"],
            ""
          )
          option_name = keyword
          if "" != Ops.get_string(driver_option, "translation", "")
            option_name = Ops.add(
              Ops.add(option_name, " / "),
              Ops.get_string(driver_option, "translation", "")
            )
          end
          # Provide the values as list of items i.e. specified as `item("string"):
          value_items_list = []
          current_value_setting = ""
          Builtins.foreach(Ops.get_list(driver_option, "values", [])) do |value|
            # Do not show an emtpy string as possible choice to the user:
            if "" != value
              if "*" == Builtins.substring(value, 0, 1)
                # Do not show the leading '*' to the user:
                value = Builtins.substring(value, 1)
                current_value_setting = value
                value = Ops.add(
                  Ops.add(Ops.add(value, "    ("), current_setting_info),
                  ")"
                )
              else
                if currently_selected_value == value
                  value = Ops.add(
                    Ops.add(Ops.add(value, "    ("), currently_selected_info),
                    ")"
                  )
                end
              end
              value_items_list = Builtins.add(value_items_list, Item(value))
            end
          end 


          if "" != currently_selected_value
            # so that the user can see it even when the respective tree item is not opened.
            # By default the option items are not opened to provide a concise overview:
            option_name = Ops.add(
              Ops.add(option_name, " : "),
              currently_selected_value
            )
          else
            if "" != current_value_setting
              option_name = Ops.add(
                Ops.add(option_name, " : "),
                current_value_setting
              )
            end
          end
          driver_options_tree_items_list = Builtins.add(
            driver_options_tree_items_list,
            Item(Id(keyword), option_name, opened, value_items_list)
          )
        end
      end 

      # Have the PageSize option topmost:
      if Ops.greater_or_equal(pagesize_option_index, 0)
        pagesize_option_tree_item = Ops.get_term(
          driver_options_tree_items_list,
          pagesize_option_index
        ) { Item("no PageSize option") }
        driver_options_tree_items_list = Builtins.remove(
          driver_options_tree_items_list,
          pagesize_option_index
        )
        driver_options_tree_items_list = Builtins.prepend(
          driver_options_tree_items_list,
          pagesize_option_tree_item
        )
      end
      if Ops.less_than(Builtins.size(driver_options_tree_items_list), 1)
        return [_("No driver options available")]
      end
      deep_copy(driver_options_tree_items_list)
    end

    # Test whether or not a "client-only" server is accessible.
    # @param [String] server_name string of the "client-only" server name
    # @param [Boolean] fail_if_executable_is_missing boolean which lets this function fail
    #        if netcat, ping, or host are not executable (e.g. because of not installed packages)
    # @return false if the "client-only" server is not accessible.
    def TestClientOnlyServer(server_name, fail_if_executable_is_missing)
      # because a local cupsd is needed if the server name is "localhost" or "127.0.0.1":
      if "localhost" == Builtins.tolower(server_name) ||
          "127.0" == Builtins.substring(server_name, 0, 5)
        # which makes it effectively a config with a local running cupsd.
        # If a local cupsd is already accessible, exit successfully, otherwise start it:
        return true if Printerlib.GetAndSetCupsdStatus("")
        return Printerlib.GetAndSetCupsdStatus("start")
      end
      # The tests here are the same (except verbosity) as in the cups_client_only tool.
      # First do the most meaningful test and only if this works return true.
      # The subsequent tests are only there to provide more info for the user
      # what might be the reason why the server is not accessible via port 631.
      netcat_test_fail_message = Builtins.sformat(
        # where %1 will be replaced by the server name.
        _("The server '%1' is not accessible via port 631 (IPP/CUPS)."),
        server_name
      ) # Popup message
      ping_test_good_message = Builtins.sformat(
        # where %1 will be replaced by the server name.
        _("The server '%1' responds to a 'ping' in the network."),
        server_name
      ) # Popup message
      ping_test_fail_message = Builtins.sformat(
        # where %1 will be replaced by the server name.
        _("The server '%1' does not respond to a 'ping' in the network."),
        server_name
      ) # Popup message
      host_test_good_message = Builtins.sformat(
        # where %1 will be replaced by the server name.
        _("The server name '%1' is known in the network."),
        server_name
      ) # Popup message
      host_test_fail_message = Builtins.sformat(
        # where %1 will be replaced by the server name.
        _("The server name '%1' is not known in the network."),
        server_name
      ) # Popup message
      separator = "\n===========================================================\n"
      error_messages = ""
      result_details = ""
      netcat_test_failed = false
      ping_test_failed = false
      host_test_failed = false
      # Only the netcat test provides a really meaningful result
      # so that only this test returns immediately true if it was successful.
      if !Printerlib.ExecuteBashCommand("type -P netcat")
        # but in most cases TestClientOnlyServer is called
        # indirectly without a button click by the user
        # so that even the netcat test is silently skipped
        # and no negative feedback is shown when netcat is not executable:
        if fail_if_executable_is_missing
          Popup.ErrorDetails(
            _("Cannot execute the program 'netcat'."),
            Ops.add(
              Ops.add(
                Ops.add(
                  # Popup::ErrorDetails details:
                  _(
                    "The RPM package 'netcat' is required for a meaningful test."
                  ) + "\n",
                  Ops.get_string(Printerlib.result, "stderr", "")
                ),
                "\n"
              ),
              Ops.get_string(Printerlib.result, "stdout", "")
            )
          )
          return false
        end
      else
        # Make netcat verbose, otherwise there would be no output at all
        # but some output is needed for the Popup::ErrorDetails below:
        if Printerlib.ExecuteBashCommand(
            Ops.add(Ops.add("netcat -v -w 1 -z ", server_name), " 631")
          )
          # because in most cases TestClientOnlyServer is called indirectly without a button click.
          return true
        end
        # The netcat-test failed:
        netcat_test_failed = true
        error_messages = netcat_test_fail_message
        result_details = Ops.add(
          Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
          Ops.get_string(Printerlib.result, "stdout", "")
        )
      end
      # When the netcat-test failed or when netcat is not executable, do a less meaningful test:
      if !Printerlib.ExecuteBashCommand("type -P ping")
        # but it the less meaningful test is not really important
        # so that the less meaningful test is silently skipped
        # and no negative feedback is shown when ping is not executable:
        if fail_if_executable_is_missing
          Popup.ErrorDetails(
            _("Cannot execute the program 'ping'."),
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          # Popup::ErrorDetails details:
                          _(
                            "The RPM package 'iputils' is required for a meaningful test."
                          ) + "\n",
                          Ops.get_string(Printerlib.result, "stderr", "")
                        ),
                        "\n"
                      ),
                      Ops.get_string(Printerlib.result, "stdout", "")
                    ),
                    separator
                  ),
                  error_messages
                ),
                "\n"
              ),
              result_details
            )
          )
          return false
        end
      else
        if Printerlib.ExecuteBashCommand(
            Ops.add("ping -w 1 -c 1 ", server_name)
          )
          if netcat_test_failed
            # Show negative feedback:
            Popup.ErrorDetails(
              Builtins.sformat(
                # where %1 will be replaced by the server name.
                _("The server '%1' is not accessible."),
                server_name
              ), # Popup::ErrorDetails message
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          Ops.add(
                            Ops.add(
                              # Popup::ErrorDetails details:
                              error_messages,
                              "\n"
                            ),
                            ping_test_good_message
                          ),
                          separator
                        ),
                        result_details
                      ),
                      "\n"
                    ),
                    Ops.get_string(Printerlib.result, "stderr", "")
                  ),
                  "\n"
                ),
                Ops.get_string(Printerlib.result, "stdout", "")
              )
            )
            return false
          end
          # netcat was not executable but at least the ping-test was successful.
          # Don't show positive feedback because this would be annoying popups for the user
          # because in most cases TestClientOnlyServer is called indirectly without a button click.
          return true
        end
        # The ping-test failed:
        ping_test_failed = true
        error_messages = Ops.add(
          Ops.add(error_messages, "\n"),
          ping_test_fail_message
        )
        result_details = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(result_details, "\n"),
              Ops.get_string(Printerlib.result, "stderr", "")
            ),
            "\n"
          ),
          Ops.get_string(Printerlib.result, "stdout", "")
        )
      end
      # When the netcat-test failed or when netcat is not executable
      # and when the ping-test failed or when ping is not executable
      # do a last test:
      if !Printerlib.ExecuteBashCommand("type -P host")
        # but it the last test is not really important
        # so that the last test is silently skipped
        # and no negative feedback is shown when host is not executable:
        if fail_if_executable_is_missing
          Popup.ErrorDetails(
            _("Cannot execute the program 'host'."),
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          # Popup::ErrorDetails details:
                          _(
                            "The RPM package 'bind-utils' is required for a meaningful test."
                          ) + "\n",
                          Ops.get_string(Printerlib.result, "stderr", "")
                        ),
                        "\n"
                      ),
                      Ops.get_string(Printerlib.result, "stdout", "")
                    ),
                    separator
                  ),
                  error_messages
                ),
                "\n"
              ),
              result_details
            )
          )
          return false
        end
      else
        if Printerlib.ExecuteBashCommand(Ops.add("host -W 1 ", server_name))
          if netcat_test_failed || ping_test_failed
            # Show negative feedback:
            Popup.ErrorDetails(
              Builtins.sformat(
                # where %1 will be replaced by the server name.
                _("The server '%1' does not respond in the network."),
                server_name
              ), # Popup::ErrorDetails message
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        Ops.add(
                          Ops.add(
                            Ops.add(
                              # Popup::ErrorDetails details:
                              error_messages,
                              "\n"
                            ),
                            host_test_good_message
                          ),
                          separator
                        ),
                        result_details
                      ),
                      "\n"
                    ),
                    Ops.get_string(Printerlib.result, "stderr", "")
                  ),
                  "\n"
                ),
                Ops.get_string(Printerlib.result, "stdout", "")
              )
            )
            return false
          end
          # ping was not executable but at least the host-test was successful.
          # Don't show positive feedback because this would be annoying popups for the user
          # because in most cases TestClientOnlyServer is called indirectly without a button click.
          return true
        end
        # The host-test failed:
        host_test_failed = true
        error_messages = Ops.add(
          Ops.add(error_messages, "\n"),
          host_test_fail_message
        )
        result_details = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(result_details, "\n"),
              Ops.get_string(Printerlib.result, "stderr", "")
            ),
            "\n"
          ),
          Ops.get_string(Printerlib.result, "stdout", "")
        )
      end
      # When the netcat-test failed or when netcat is not executable
      # and when the ping-test failed or when ping is not executable
      # and when the host-test failed or when host is not executable:
      if netcat_test_failed || ping_test_failed || host_test_failed
        # Show negative feedback:
        Popup.ErrorDetails(
          Builtins.sformat(
            # where %1 will be replaced by the server name.
            _("The server '%1' is unknown."),
            server_name
          ), # Popup::ErrorDetails message
          Ops.add(
            Ops.add(
              # Popup::ErrorDetails details:
              error_messages,
              separator
            ),
            result_details
          )
        )
        return false
      end
      # Neither netcat nor ping nor host were executable.
      # Don't show any kind of feedback because this would be annoying popups for the user
      # because in most cases TestClientOnlyServer is called indirectly without a button click
      # so that nothing else could be done in this case except a "hope-for-the-best" successful return:
      true
    end

    # Run hp-setup:
    # @return false if hp-setup cannot be run and return true in any other case
    # because there is no usable exit code of hp-setup (always zero even in case of error).
    def RunHpsetup
      basicadd_displaytest_failed_message =
        # Message of a Popup::Error when hp-setup should be run.
        # Do not change or translate "hp-setup", it is a program name.
        # Do not change or translate "DISPLAY", it is an environment variable name.
        _(
          "Cannot run hp-setup because no graphical display can be opened.\n" +
            "This happens in particular when YaST runs in text-only mode,\n" +
            "or when the user who runs YaST has no DISPLAY environment variable set,\n" +
            "or when the YaST process is not allowed to access the graphical display.\n" +
            "In this case you should run hp-setup manually directly as user 'root'.\n"
        )
      hpsetup_not_executable_message =
        # Message of a Popup::Error when hp-setup should be run.
        # Do not change or translate "hp-setup", it is a program name:
        _(
          "Cannot run hp-setup because\n" +
            "/usr/bin/hp-setup is not executable\n" +
            "or does not exist.\n"
        )
      hpsetup_busy_message =
        # Body of a Popup::ShowFeedback.
        # Do not change or translate "hp-setup", it is a program name:
        _(
          "Launched hp-setup.\nYou must finish hp-setup before you can proceed with the printer configuration.\n"
        )
      if !Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "basicadd_displaytest")
        )
        # because it would run without any contact to the user "in the background"
        # while in the foreground YaST waits for hp-setup to be finished
        # which is imposible for the user so that the result is a deadlock.
        # All the user could do is to kill the hp-setup process.
        # It does not matter if basicadd_displaytest fails orderly because XOpenDisplay fails
        # or if it crashes because of missing libX11.so on a minimal installation without X
        # because any non-zero exit code indicates that no graphical window can be opened.
        Builtins.y2milestone(
          "RunHpsetup failed: %1basicadd_displaytest failed.",
          Printerlib.yast_bin_dir
        )
        Popup.Error(basicadd_displaytest_failed_message)
        return false
      end
      if !Printerlib.TestAndInstallPackage("hplip", "installed")
        Builtins.y2milestone("RunHpsetup failed: hplip not installed.")
        # Only a notification but no installation of HPLIP here.
        # Installing the package hplip can pull in tons of required packages
        # because the hplip package does not only provide the 'hp' backend but is a
        # full featured multifunction solution with GUI for HP printers and all-in-one devices.
        # HPLIP supports printing, scanning, faxing, photo card access, and device management.
        # Additionally installing hplip can become very complicated (see driveradd.ycp).
        # Therefore the RunHpsetup function is not bloated with installing HPLIP.
        Popup.Error(
          # from the BasicAdd dialog but the RPM package hplip is not installed:
          # Do not change or translate "hp-setup", it is a program name.
          # Do not change or translate "hplip", it is a package name.
          # Translate 'Driver Packages' the same as the PushButton name to go to the "Add Driver" dialog:
          _(
            "To run hp-setup, the RPM package hplip must be installed.\nUse 'Driver Packages' to install it."
          )
        )
        return false
      end
      if !Printerlib.ExecuteBashCommand("test -x /usr/bin/hp-setup")
        Builtins.y2milestone(
          "RunHpsetup failed: /usr/bin/hp-setup not executable or does not exist."
        )
        Popup.Error(hpsetup_not_executable_message)
        return false
      end
      Popup.ShowFeedback(
        "",
        # Busy message:
        hpsetup_busy_message
      )
      Printerlib.ExecuteBashCommand("/usr/bin/hp-setup")
      Popup.ClearFeedback
      true
    end

    publish :function => :Modified, :type => "boolean ()"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :AbortFunction, :type => "boolean ()"
    publish :function => :Abort, :type => "boolean ()"
    publish :variable => :printer_auto_summary, :type => "string"
    publish :variable => :printer_auto_modified, :type => "boolean"
    publish :variable => :autoyast_printer_settings, :type => "map"
    publish :variable => :printer_auto_dialogs, :type => "boolean"
    publish :variable => :printer_auto_requires_cupsd_restart, :type => "boolean"
    publish :variable => :number_chars, :type => "string"
    publish :variable => :upper_chars, :type => "string"
    publish :variable => :lower_chars, :type => "string"
    publish :variable => :letter_chars, :type => "string"
    publish :variable => :alnum_chars, :type => "string"
    publish :variable => :lower_alnum_chars, :type => "string"
    publish :variable => :known_manufacturers, :type => "list <string>"
    publish :variable => :ppds, :type => "list <map <string, string>>"
    publish :variable => :selected_ppds_index, :type => "integer"
    publish :variable => :connections, :type => "list <map <string, string>>"
    publish :variable => :selected_connections_index, :type => "integer"
    publish :variable => :current_device_uri, :type => "string"
    publish :variable => :queues, :type => "list <map <string, string>>"
    publish :variable => :selected_queues_index, :type => "integer"
    publish :variable => :queue_filter_show_local, :type => "boolean"
    publish :variable => :queue_filter_show_remote, :type => "boolean"
    publish :variable => :current_queue_name, :type => "string"
    publish :variable => :driver_options, :type => "list <map <string, any>>"
    publish :function => :AutodetectQueues, :type => "boolean ()"
    publish :function => :DetermineDriverOptions, :type => "boolean (string)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :DeriveModelName, :type => "string (string, integer)"
    publish :function => :DeriveDriverFilterString, :type => "string (string)"
    publish :function => :NewQueueName, :type => "string (string)"
    publish :function => :QueueItems, :type => "list (boolean, boolean)"
    publish :function => :ConnectionItems, :type => "list (string)"
    publish :function => :DriverItems, :type => "list (string, boolean)"
    publish :function => :AddQueue, :type => "boolean (string, boolean, string)"
    publish :function => :DeleteQueue, :type => "boolean (string)"
    publish :function => :DriverOptionItems, :type => "list (string, string)"
    publish :function => :TestClientOnlyServer, :type => "boolean (string, boolean)"
    publish :function => :RunHpsetup, :type => "boolean ()"
  end

  Printer = PrinterClass.new
  Printer.main
end

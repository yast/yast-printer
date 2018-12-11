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

# File:        include/printer/connectionwizard.ycp
# Package:     Configuration of printer
# Summary:     Connection Wizard
# Authors:     Michal Zugec <mzugec@suse.de>
#              Johannes Meixner <jsmeix@suse.de>

require "shellwords"

module Yast
  module PrinterConnectionwizardInclude
    def initialize_printer_connectionwizard(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "printer/helps.rb"

      @connection_uri = ""
      @connection_model = ""

      # List of reserved URI characters ! # $ % & ' ( ) * + , / : ; = ? @ [ ]
      # (the % character is separated as percentage_percent_encoding)
      # plus the space character and their matching percent encodings
      # where each percent encoding must be exactly three characters
      # and uppercase letters, otherwise URIpercentDecoding would not work.
      # It is crucial to have "%":"%25" first so that URIpercentEncoding works correctly
      # because "%" must be replaced by "%25" first of all otherwise
      # a duplicate encoding would happen "Foo Bar" -> "Foo%20Bar" -> "Foo%2520Bar"
      # but only "Foo Bar" -> "Foo%20Bar" would be the correct encoding.
      # It is crucial to have "%":"%25" last so that URIpercentDecoding works correctly
      # because "%25" must be replaced by "%" last otherwise
      # a duplicate decoding would happen: "Foo%2520Bar" -> "Foo%20Bar" -> "Foo Bar".
      # but only "Foo%2520Bar" -> "Foo%20Bar" would be the correct decoding.
      # Therefore "%":"%25" cannot be at all in this list but is
      # separated as percentage_percent_encoding which is
      # prepended to this list so that URIpercentEncoding works correctly and
      # appended to this list so that URIpercentDecoding works correctly.
      # Unfortunately a simple map like $[ "%":"%25", " ":"%20", ... ]
      # does not work because in a map the ordering is not kept
      # even when there is no operation which changes the map
      # the internal ordering in a map is different
      # from how it was specified here.
      # It seems the internal ordering in a map is alphabetically sorted
      # so that $[ "%":"%25", " ":"%20", ... ] -> $[ " ":"%20", ... "%":"%25", ... ]
      # Therefore a list is used which keeps the initial ordering.
      @uri_percent_encodings = [
        { "character" => " ", "encoding" => "%20" },
        { "character" => "!", "encoding" => "%21" },
        { "character" => "#", "encoding" => "%23" },
        { "character" => "$", "encoding" => "%24" },
        { "character" => "&", "encoding" => "%26" },
        { "character" => "'", "encoding" => "%27" },
        { "character" => "(", "encoding" => "%28" },
        { "character" => ")", "encoding" => "%29" },
        { "character" => "*", "encoding" => "%2A" },
        { "character" => "+", "encoding" => "%2B" },
        { "character" => ",", "encoding" => "%2C" },
        { "character" => "/", "encoding" => "%2F" },
        { "character" => ":", "encoding" => "%3A" },
        { "character" => ";", "encoding" => "%3B" },
        { "character" => "=", "encoding" => "%3D" },
        { "character" => "?", "encoding" => "%3F" },
        { "character" => "@", "encoding" => "%40" },
        { "character" => "[", "encoding" => "%5B" },
        { "character" => "]", "encoding" => "%5D" }
      ]
      @percentage_percent_encoding = { "character" => "%", "encoding" => "%25" }
    end

    def URIpercentEncoding(input)
      # cannot be used because URL::transform_map_passwd is insufficient because
      # the characters ! # ' ( ) * [ ] are missing in URL::transform_map_passwd.
      # URIpercentEncoding replaces the space character and
      # each reserved character ! # $ % & ' ( ) * + , / : ; = ? @ [ ]
      # in a value (component) of an URI with its matching percent encoding,
      # see https://bugzilla.novell.com/show_bug.cgi?id=512549
      # This function can only be used for percent encoding of the value
      # of a single URI component where no character in the input
      # is already percent encoded, otherwise e.g. "Foo%20Bar" results "Foo%2520Bar".
      # In particular this function cannot be used when the user can enter a whole URI
      # or the whole set of URI options (e.g. option1=value1&option2=value2).
      output = input
      Builtins.foreach(
        Builtins.prepend(@uri_percent_encodings, @percentage_percent_encoding)
      ) do |current_encoding|
        character = Ops.get(current_encoding, "character", "")
        encoding = Ops.get(current_encoding, "encoding", "")
        next if "" == character || "" == encoding
        output = Builtins.mergestring(
          Builtins.splitstring(output, character),
          encoding
        )
      end 

      Builtins.y2milestone(
        "URIpercentEncoding from '%1' to '%2'",
        input,
        output
      )
      output
    end

    def URIpercentDecoding(input)
      # cannot be used because URL::transform_map_passwd is insufficient because
      # the characters ! # ' ( ) * [ ] are missing in URL::transform_map_passwd
      # and URL::UnEscapeString("Foo%2525Bar") results "Foo%Bar" which is wrong
      # because URIpercentDecoding("Foo%2525Bar") results "Foo%25Bar".
      # URIpercentDecoding is the opposite of the URIpercentEncoding function
      # so that URIpercentDecoding(URIpercentEncoding(input)) == input
      output = input
      # Assume the input is "First%3aSecond%3AThird%2525Rest"
      # Character positions: 0123456789012345678901234567890
      Builtins.foreach(
        Builtins.add(@uri_percent_encodings, @percentage_percent_encoding)
      ) do |current_encoding|
        character = Ops.get(current_encoding, "character", "")
        encoding = Ops.get(current_encoding, "encoding", "")
        next if "" == character || "" == encoding
        # Process the output of the previous foreach loop as rest_of_input
        # and clear the output for the current foreach loop:
        rest_of_input = output
        output = ""
        position = Builtins.search(rest_of_input, encoding)
        # For character = "%" and encoding = "%25"
        #   position = 22 = search( "First%3aSecond%3AThird%2525Rest", "%25" )
        # For character = ":" and encoding = "%3A"
        #   position = 14 = search( "First%3aSecond%3AThird%25Rest", "%3A" )
        position_lowercase = Builtins.search(
          rest_of_input,
          Builtins.tolower(encoding)
        )
        # For character = "%" and encoding = "%25"
        #   position_lowercase = 22 = search( "First%3aSecond%3AThird%2525Rest", "%25" )
        # For character = ":" and actual percent encoding = "%3a"
        #   position = 5 = search( "First%3aSecond%3AThird%25Rest", "%3a" )
        if position != nil && position_lowercase != nil &&
            Ops.less_than(position_lowercase, position) ||
            position == nil && position_lowercase != nil
          position = position_lowercase 
          # For character = ":" and actual percent encoding = "%3a"
          #   position = 5
        end
        # For character = "%" and encoding = "%25"
        #   position = 22
        while position != nil
          # the first position characters are those up to the current percent encoding
          # and at position + 3 the rest after the current percent encoding starts:
          characters_up_to_current_encoding = Builtins.substring(
            rest_of_input,
            0,
            position
          )
          output = Ops.add(
            Ops.add(output, characters_up_to_current_encoding),
            character
          )
          # For character = "%" and encoding = "%25"
          #   output = "First%3aSecond%3AThird%" = "" + "First%3aSecond%3AThird" + "%"
          # For character = ":" and actual percent encoding = "%3a"
          #   output = "First:" = "" + "First" + ":"
          # For character = ":" and encoding = "%3A"
          #   output = "First:Second:" = "First:" + "Second" + ":"
          rest_of_input = Builtins.substring(
            rest_of_input,
            Ops.add(position, 3)
          )
          # For character = "%" and encoding = "%25"
          #   rest_of_input = "25Rest"
          # For character = ":" and actual percent encoding = "%3a"
          #   rest_of_input = "Second%3AThird%25Rest"
          # For character = ":" and encoding = "%3A"
          #   rest_of_input = "Third%25Rest"
          position = Builtins.search(rest_of_input, encoding)
          # For character = "%" and encoding = "%25"
          #   position = nil = search( "25Rest", "%25" )
          # For character = ":" and encoding = "%3A"
          #   position = 6 = search( "Second%3AThird%25Rest", "%3A" )
          # For second while loop for character = ":" and encoding = "%3A"
          #   position = nil = search( "Third%25Rest", "%3A" )
          position_lowercase = Builtins.search(
            rest_of_input,
            Builtins.tolower(encoding)
          )
          # For character = "%" and encoding = "%25"
          #   position_lowercase = nil = search( "25Rest", "%25" )
          # For character = ":" and actual percent encoding = "%3a"
          #   position = nil = search( "Second%3AThird%25Rest", "%3a" )
          # For second while loop for character = ":" and actual percent encoding = "%3a"
          #   position = nil = search( "Third%25Rest", "%3a" )
          if position != nil && position_lowercase != nil &&
              Ops.less_than(position_lowercase, position) ||
              position == nil && position_lowercase != nil
            position = position_lowercase
          end 
          # For character = "%" and encoding = "%25"
          #   position = nil
          # For character = ":" and encoding = "%3A"
          #   position = 6
          # For second while loop for character = ":" and encoding = "%3A"
          #   position = nil
        end
        # After replacing all occurrences of the current percent encoding
        # by its character append what is left as rest of the input:
        output = Ops.add(output, rest_of_input) # For character = "%" and encoding = "%25"
        #   output = "First%3aSecond%3AThird%25Rest"
        # For character = ":" and encoding = "%3A"
        #   output = "First:Second:Third%25Rest"
      end 

      # output = "First:Second:Third%25Rest"
      Builtins.y2milestone(
        "URIpercentDecoding from '%1' to '%2'",
        input,
        output
      )
      output
    end

    def getCurrentDeviceURI
      if "" !=
          Ops.get(
            Printer.connections,
            [Printer.selected_connections_index, "uri"],
            ""
          )
        return Ops.get(
          Printer.connections,
          [Printer.selected_connections_index, "uri"],
          ""
        )
      end
      Ops.get(Printer.queues, [Printer.selected_queues_index, "uri"], "")
    end

    def getUriWithUsernameAndPassword(uri, scheme)
      # so that I may have to retrieve it directly form /etc/cups/printers.conf
      # but only in this special case (and not in general via tools/autodetect_print_queues)
      # because I also do not want to show the password needlessly in any dialog
      # (and/or needlessly in /var/log/YaST2/y2log via "Autodetected queues").
      # But the URI may be not in /etc/cups/printers.conf
      # because there was no queue set up with this device URI
      # (e.g. because the URI is right now created by the connection wizard)
      # or several queues in /etc/cups/printers.conf may match
      # or the URI may already contain a "username:password@" part
      # because it was created by a previous run of the connection wizard dialog
      # and now "username:password@" in the URI should be changed.
      # Therefore I do nothing if the URI already contains a '@'
      # in its second part parts[1] (note that parts[0] = "<scheme>:")
      # which indicates that a "username:password@" part already exists:
      parts = Builtins.splitstring(uri, "/")
      # Remove empty parts (e.g. <scheme>://server results ["<scheme>:","","server"]):
      parts = Builtins.filter(parts) { |part| "" != part }
      if !Builtins.issubstring(Ops.get(parts, 1, ""), "@")
        special_chars = "'\"\\()[]{}|^$?*+"
        part1 = Builtins.mergestring(
          Builtins.splitstring(Ops.get(parts, 1, ""), special_chars),
          "."
        )
        part2 = Builtins.mergestring(
          Builtins.splitstring(Ops.get(parts, 2, ""), special_chars),
          "."
        )
        # Let the whole pipe fail if any of its commands fail (requires bash):
        grepcommand = "set -o pipefail ; egrep '^DeviceURI " + scheme + "://[^:]+:[^@]+@" + part1 + "/" + part2
        if "lpd" == scheme
          # to describe who requested a print job in the form lpd://username@ip-address-or-hostname/...
          # (i.e. grep only for "username@" instead of the usual "username:password@"):
          grepcommand = "set -o pipefail ; egrep '^DeviceURI " + scheme + "://[^@]+@" + part1 + "/" + part2
        end
        if "" != Ops.get(parts, 3, "")
          part3 = Builtins.mergestring(
            Builtins.splitstring(Ops.get(parts, 3, ""), special_chars),
            "."
          )
          grepcommand += "/" + part3
        end
        grepcommand += "$' /etc/cups/printers.conf"
        grepcommand += " | sort -u | wc -l | tr -d '[:space:]'"
        Printerlib.ExecuteBashCommand(grepcommand)
        if "1" == Ops.get_string(Printerlib.result, "stdout", "")
          # are unambiguous (exactly one or several exactly same such DeviceURIs)
          # so that I can actually get it form /etc/cups/printers.conf:
          grepcommand += " | head -n 1 | cut -s -d ' ' -f 2 | tr -d '[:space:]'"
          if Printerlib.ExecuteBashCommand(grepcommand)
            return Ops.get_string(Printerlib.result, "stdout", "")
          end
        end
      end
      # By default and as fallback return the unchanged URI:
      uri
    end

    def getContentFromCurrentModel(no_default_raw_queue)
      content = nil
      current_model_info = Ops.get(
        Printer.connections,
        [Printer.selected_connections_index, "model"],
        ""
      )
      if "" == current_model_info ||
          "unknown" == Builtins.tolower(current_model_info)
        if Ops.greater_or_equal(Printer.selected_queues_index, 0)
          if "local" ==
              Ops.get(
                Printer.queues,
                [Printer.selected_queues_index, "config"],
                ""
              )
            ppd = Ops.get(
              Printer.queues,
              [Printer.selected_queues_index, "ppd"],
              ""
            )
            # For a local raw queue ppd is the empty string.
            # For a local queue with a System V style interface script ppd is "/etc/cups/interfaces/<name-of-the-script>".
            # For a local queue with URI "ipp://server/printers/queue" ppd is "ipp://server/printers/queue.ppd".
            # For a normal local queue with URI "ipp://server/resource" ppd is "/etc/cups/ppd/<queue-name>.ppd".
            # For a normal local queue ppd is "/etc/cups/ppd/<queue-name>.ppd".
            # The leading part "/etc/" may vary depending on how the local cupsd
            # is installed or configured, see "/usr/bin/cups-config --serverroot".
            if "" == ppd
              no_default_raw_queue = false
            else
              no_default_raw_queue = true
            end
            if Builtins.issubstring(ppd, "/cups/ppd/")
              # which suppresses it in certain "lpinfo -m" output.
              # Note the YCP quoting: \" becomes " and \\n becomes \n in the commandline.
              commandline = "grep '^*NickName' " + ppd.shellescape
              commandline += " | cut -s -d '\"' -f2"
              commandline += " | sed -e 's/(recommended)//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'"
              commandline += " | tr -s ' ' | tr -d '\\n'"
              if Printerlib.ExecuteBashCommand(commandline)
                current_model_info = Ops.get_string(
                  Printerlib.result,
                  "stdout",
                  ""
                )
              end
            end
          end
          if "" == current_model_info ||
              "unknown" == Builtins.tolower(current_model_info)
            current_model_info = Ops.get(
              Printer.queues,
              [Printer.selected_queues_index, "description"],
              ""
            )
          end
        end
      end
      if "" != current_model_info &&
          "unknown" != Builtins.tolower(current_model_info)
        current_model_info = Printer.DeriveModelName(current_model_info, 0)
        if no_default_raw_queue
          content = Left(
            ComboBox(
              Id("manufacturers_combo_box"),
              Opt(:editable),
              # Header for a ComboBox to keep the printer model or select another manufacturer:
              _("Keep the printer model or select another &manufacturer"),
              Builtins.prepend(
                Builtins.add(Printer.known_manufacturers, "Raw Queue"),
                current_model_info
              )
            )
          )
        else
          content = Left(
            ComboBox(
              Id("manufacturers_combo_box"),
              Opt(:editable),
              # Header for a ComboBox to optionally
              # keep the printer model or select a printer manufacturer.
              # Do not change or translate "raw", it is a technical term
              # when no driver is used for a print queue.
              _(
                "Keep the model or select a &manufacturer if no 'raw queue' should be set up"
              ),
              Builtins.prepend(
                Builtins.prepend(
                  Printer.known_manufacturers,
                  current_model_info
                ),
                "Raw Queue"
              )
            )
          )
        end
      else
        if no_default_raw_queue
          content = Left(
            ComboBox(
              Id("manufacturers_combo_box"),
              Opt(:editable),
              # Header for a ComboBox to select the printer manufacturer:
              _("Select the printer &manufacturer"),
              Builtins.prepend(
                Builtins.add(Printer.known_manufacturers, "Raw Queue"),
                ""
              )
            )
          )
        else
          content = Left(
            ComboBox(
              Id("manufacturers_combo_box"),
              Opt(:editable),
              # Header for a ComboBox to optionally select the printer manufacturer.
              # Do not change or translate "raw", it is a technical term
              # when no driver is used for a print queue.
              _(
                "Select a printer &manufacturer if no 'raw queue' should be set up."
              ),
              Builtins.prepend(Printer.known_manufacturers, "Raw Queue")
            )
          )
        end
      end
      deep_copy(content)
    end

    def getContentFromBackend(backend)
      connection_items = []
      backend = Ops.add(backend, ":/")
      current_device_uri = getCurrentDeviceURI
      current_device_uri_found = false
      current_connection_item = nil
      Builtins.foreach(
        Convert.convert(
          Printer.ConnectionItems(""),
          :from => "list",
          :to   => "list <term>"
        )
      ) do |connection_item|
        # but Printer::ConnectionItems adds a trailing space character to model and uri
        # (because the current YaST UI has almost no additional space between table columns)
        # so that the last character must be removed to get the correct device URI value:
        uri = Ops.get_string(connection_item, 2, "")
        uri = Builtins.substring(uri, 0, Ops.subtract(Builtins.size(uri), 1))
        if backend == Builtins.substring(uri, 0, Builtins.size(backend))
          if current_device_uri == uri
            current_device_uri_found = true
            current_connection_item = deep_copy(connection_item)
          else
            connection_items = Builtins.add(connection_items, connection_item)
          end
        end
      end 

      if backend ==
          Builtins.substring(current_device_uri, 0, Builtins.size(backend))
        if !current_device_uri_found
          # Nevertheless the current connection must be topmost to be preselected because
          # anything else which might be topmost and preselected (even an empty value)
          # would silently change the current connection to the preselected one
          # when the user clicks [OK]:
          connection_items = Builtins.prepend(
            connection_items,
            # Add trailing spaces because the current YaST UI
            # has almost no additional space between table columns
            # in partitcular not where the widest entry in a column is:
            Item(
              Id(-1),
              "Unknown" + " ",
              Ops.add(current_device_uri, " "),
              "No longer valid (printer not connected?)"
            )
          )
        else
          # via the default Table widget preselection:
          connection_items = Builtins.prepend(
            connection_items,
            current_connection_item
          )
        end
      end
      content = VBox(
        Table(
          Id(:connection_selection),
          # By default there is no UserInput()
          # if only something was selected in the Table
          # (without clicking additionally a button)
          # but the notify and immediate options
          # forces UserInput() in this case:
          Opt(:notify, :immediate, :keepSorting),
          # Headers of a Table with a list of printer connections:
          Header(
            # Printer model name:
            _("Model"),
            # Header of a Table column with a list of printer connections.
            # Connection of the printer (e.g. via USB or via parallel port):
            _("Connection"),
            # Header of a Table column with a list of printer connections.
            # Additional description of the printer or its particular connection:
            _("Description")
          ), # Header of a Table column with a list of printer connections.
          connection_items
        )
      )
      deep_copy(content)
    end

    def getNetworkContent(hostname, scan_hosts_label, port_or_queue_label, port_or_queue, uri_options)
      hostname_label = _("&IP Address or Host Name")
      # No URIpercentDecoding/Encondin(hostname) is done
      # when it contains a '@' because a lpd URI can be of the form
      #   lpd://username@ip-address-or-hostname/...
      # and a ipp/http URI can be of the form
      #   ipp://username:password@ip-address-or-hostname/...
      #   http://username:password@ip-address-or-hostname/...
      # see https://bugzilla.novell.com/show_bug.cgi?id=512549
      if Builtins.issubstring(hostname, "@")
        hostname_label = _("&IP Address or Host Name [percent-encoded]")
      end
      content = VBox(
        Left(
          HBox(
            Bottom(
              ComboBox(Id(:hostname), Opt(:editable), hostname_label, [hostname])
            ),
            Bottom(
              MenuButton(
                _("Look up"),
                [
                  Item(Id(:scan), scan_hosts_label),
                  # TRANSLATORS: Button to search for remote servers
                  Item(Id(:scan_all), _("Look up for All Hosts"))
                ]
              ) # TRANSLATORS: Label for menu to search for remote servers
            )
          )
        ),
        Left(InputField(Id(:port_or_queue), port_or_queue_label, port_or_queue)),
        Left(
          InputField(
            Id(:uri_options),
            # Show it as wide as possible because it may have to contain
            # longer stuff like 'option1=value1&option2=value2':
            Opt(:hstretch),
            # TRANSLATORS: InputField for optional Device URI parameters:
            _(
              "Optional 'option=value' parameter (usually empty) [percent-encoded]"
            ),
            uri_options
          )
        ),
        Left(PushButton(Id(:test), _("&Test Connection"))) # TRANSLATORS: Button to test remote printer machine
      )
      deep_copy(content)
    end

    def changeSettingsDialog(selected)
      content = nil
      connection_content = nil
      model_content = nil
      current_device_uri = ""
      uri_parts = []
      hostname = ""
      port_or_queue = ""
      uri_options = ""
      uri = ""
      queue = ""
      domain = ""
      printer = ""
      user = ""
      pass = ""
      active_directory_support = false
      beh_do_not_disable = true
      beh_attempts = "0"
      beh_delay = "30"
      case selected
        when :parallel
          content = getContentFromBackend("parallel")
        when :usb
          content = getContentFromBackend("usb")
        when :hplip
          if !Printerlib.TestAndInstallPackage("hplip", "installed")
            # Only a notification but no installation of HPLIP in the Connection Wizard.
            # Installing the package hplip can pull in tons of required packages
            # because the hplip package does not only provide the 'hp' backend but is a
            # full featured multifunction solution with GUI for HP printers and all-in-one devices.
            # HPLIP supports printing, scanning, faxing, photo card access, and device management.
            # Additionally installing hplip can become very complicated (see driveradd.ycp).
            # Therefore the Connection Wizard is not bloated with installing HPLIP.
            Popup.Message(
              # in the Connection Wizard but the RPM package hplip is not installed:
              _(
                "To access a HP device via the 'hp' backend,\nthe RPM package hplip must be installed."
              )
            )
            content = VBox(
              Left(Label(_("The RPM package hplip is not installed.")))
            )
          else
            content = getContentFromBackend("hp")
          end
        when :serial
          current_device_uri = getCurrentDeviceURI
          @current_serial_device_node = ""
          @serial_device_node_items = []
          if "serial:/" ==
              Builtins.substring(
                current_device_uri,
                0,
                Builtins.size("serial:/")
              )
            # serial:/dev/ttyS6?baud=115200+bits=7+parity=space+flow=hard+stop=1
            # remove the scheme 'serial:' so that only '/dev/ttyS6' is left:
            @current_serial_device_node = Builtins.mergestring(
              Builtins.sublist(
                Builtins.splitstring(current_device_uri, ":?"),
                1,
                1
              ),
              ""
            )
          end
          @current_serial_device_node_found = false
          Builtins.foreach(
            [
              "/dev/ttyS0",
              "/dev/ttyS1",
              "/dev/ttyS2",
              "/dev/ttyS3",
              "/dev/ttyS4",
              "/dev/ttyS5",
              "/dev/ttyS6",
              "/dev/ttyS7"
            ]
          ) do |device_node|
            if @current_serial_device_node == device_node
              @current_serial_device_node_found = true
              # Have the current serial device node preselected:
              @serial_device_node_items = Builtins.add(
                @serial_device_node_items,
                Item(Id(device_node), device_node, true)
              )
            else
              @serial_device_node_items = Builtins.add(
                @serial_device_node_items,
                Item(Id(device_node), device_node)
              )
            end
          end 

          if !@current_serial_device_node_found
            if "" == @current_serial_device_node
              # the CUPS serial backend may blindly write to any device:
              @serial_device_node_items = Builtins.prepend(
                @serial_device_node_items,
                Item(Id(""), "", true)
              )
            else
              @serial_device_node_items = Builtins.prepend(
                @serial_device_node_items,
                Item(
                  Id(@current_serial_device_node),
                  @current_serial_device_node,
                  true
                )
              )
            end
          end
          @serial_baud_rate_items = []
          @serial_data_bits_items = []
          @serial_parity_items = []
          @serial_flow_control_items = []
          @serial_stop_bits_items = []
          if "serial:/" ==
              Builtins.substring(
                current_device_uri,
                0,
                Builtins.size("serial:/")
              )
            Builtins.foreach(
              # The Device URI has the form like:
              # serial:/dev/ttyS6?baud=115200+bits=7+parity=space+flow=hard+stop=1
              # remove all before the '?' so that only the parameters 'baud=115200+bits=7...' are left
              # as strings in a list like ["baud=115200","bits=7","parity=space","flow=hard","stop=1"]:
              Builtins.sublist(
                Builtins.splitstring(current_device_uri, "?+"),
                1
              )
            ) do |parameter|
              keyword_value = Builtins.splitstring(parameter, "=")
              keyword = Ops.get(keyword_value, 0, "")
              value = Ops.get(keyword_value, 1, "")
              value_found = false
              if "baud" == keyword
                Builtins.foreach(
                  # The preset values are from backend/serial.c in the CUPS 1.3.9 sources:
                  [
                    "1200",
                    "2400",
                    "4800",
                    "9600",
                    "19200",
                    "38400",
                    "57600",
                    "115200",
                    "230400"
                  ]
                ) do |item_value|
                  if value == item_value
                    value_found = true
                    # Have the current value preselected:
                    @serial_baud_rate_items = Builtins.add(
                      @serial_baud_rate_items,
                      Item(Id(item_value), item_value, true)
                    )
                  else
                    @serial_baud_rate_items = Builtins.add(
                      @serial_baud_rate_items,
                      Item(Id(item_value), item_value)
                    )
                  end
                end 

                if !value_found
                  if "" == value
                    # the baud rate may have to be exactly what is set in the printer (e.g. via DIP switches):
                    @serial_baud_rate_items = Builtins.prepend(
                      @serial_baud_rate_items,
                      Item(Id(""), "", true)
                    )
                  else
                    # If the current value is none of them, it might be invalid or a typo.
                    # Therefore the current value is added with an appropriate hint.
                    # Nevertheless the current value must be topmost and preselected because
                    # anything else which might be preselected (even an empty value)
                    # would silently change the current value to the preselected one
                    # when the user clicks [OK]:
                    @serial_baud_rate_items = Builtins.prepend(
                      @serial_baud_rate_items,
                      Item(
                        Id(value),
                        Ops.add(value, " (might be invalid or a typo)"),
                        true
                      )
                    )
                  end
                end
              end
              if "bits" == keyword
                Builtins.foreach(
                  # The preset values are from backend/serial.c in the CUPS 1.3.9 sources:
                  ["7", "8"]
                ) do |item_value|
                  if value == item_value
                    value_found = true
                    # Have the current value preselected:
                    @serial_data_bits_items = Builtins.add(
                      @serial_data_bits_items,
                      Item(Id(item_value), item_value, true)
                    )
                  else
                    @serial_data_bits_items = Builtins.add(
                      @serial_data_bits_items,
                      Item(Id(item_value), item_value)
                    )
                  end
                end 

                if !value_found
                  if "" == value
                    # the data bits may have to be exactly what is set in the printer (e.g. via DIP switches):
                    @serial_data_bits_items = Builtins.prepend(
                      @serial_data_bits_items,
                      Item(Id(""), "", true)
                    )
                  else
                    # If the current value is none of them, it might be invalid or a typo.
                    # Therefore the current value is added with an appropriate hint.
                    # Nevertheless the current value must be topmost and preselected because
                    # anything else which might be preselected (even an empty value)
                    # would silently change the current value to the preselected one
                    # when the user clicks [OK]:
                    @serial_data_bits_items = Builtins.prepend(
                      @serial_data_bits_items,
                      Item(
                        Id(value),
                        Ops.add(value, " (might be invalid or a typo)"),
                        true
                      )
                    )
                  end
                end
              end
              if "parity" == keyword
                Builtins.foreach(
                  # The preset values are from backend/serial.c in the CUPS 1.3.9 sources:
                  ["even", "odd", "none", "space", "mark"]
                ) do |item_value|
                  if value == item_value
                    value_found = true
                    # Have the current value preselected:
                    @serial_parity_items = Builtins.add(
                      @serial_parity_items,
                      Item(Id(item_value), item_value, true)
                    )
                  else
                    @serial_parity_items = Builtins.add(
                      @serial_parity_items,
                      Item(Id(item_value), item_value)
                    )
                  end
                end 

                if !value_found
                  if "" == value
                    # the parity may have to be exactly what is set in the printer (e.g. via DIP switches):
                    @serial_parity_items = Builtins.prepend(
                      @serial_parity_items,
                      Item(Id(""), "", true)
                    )
                  else
                    # If the current value is none of them, it might be invalid or a typo.
                    # Therefore the current value is added with an appropriate hint.
                    # Nevertheless the current value must be topmost and preselected because
                    # anything else which might be preselected (even an empty value)
                    # would silently change the current value to the preselected one
                    # when the user clicks [OK]:
                    @serial_parity_items = Builtins.prepend(
                      @serial_parity_items,
                      Item(
                        Id(value),
                        Ops.add(value, " (might be invalid or a typo)"),
                        true
                      )
                    )
                  end
                end
              end
              if "flow" == keyword
                Builtins.foreach(
                  # The preset values are from backend/serial.c in the CUPS 1.3.9 sources:
                  ["none", "soft", "hard", "dtrdsr"]
                ) do |item_value|
                  item_text = item_value
                  item_text = "XON/XOFF (software)" if "soft" == item_value
                  item_text = "RTS/CTS (hardware)" if "hard" == item_value
                  item_text = "DTR/DSR (hardware)" if "dtrdsr" == item_value
                  if value == item_value
                    value_found = true
                    # Have the current value preselected:
                    @serial_flow_control_items = Builtins.add(
                      @serial_flow_control_items,
                      Item(Id(item_value), item_text, true)
                    )
                  else
                    @serial_flow_control_items = Builtins.add(
                      @serial_flow_control_items,
                      Item(Id(item_value), item_text)
                    )
                  end
                end 

                if !value_found
                  if "" == value
                    # flow control may have to be exactly what is set in the printer (e.g. via DIP switches):
                    @serial_flow_control_items = Builtins.prepend(
                      @serial_flow_control_items,
                      Item(Id(""), "", true)
                    )
                  else
                    # If the current value is none of them, it might be invalid or a typo.
                    # Therefore the current value is added with an appropriate hint.
                    # Nevertheless the current value must be topmost and preselected because
                    # anything else which might be preselected (even an empty value)
                    # would silently change the current value to the preselected one
                    # when the user clicks [OK]:
                    @serial_flow_control_items = Builtins.prepend(
                      @serial_flow_control_items,
                      Item(
                        Id(value),
                        Ops.add(value, " (might be invalid or a typo)"),
                        true
                      )
                    )
                  end
                end
              end
              if "stop" == keyword
                Builtins.foreach(
                  # The preset values are from backend/serial.c in the CUPS 1.3.9 sources:
                  ["1", "2"]
                ) do |item_value|
                  if value == item_value
                    value_found = true
                    # Have the current value preselected:
                    @serial_stop_bits_items = Builtins.add(
                      @serial_stop_bits_items,
                      Item(Id(item_value), item_value, true)
                    )
                  else
                    @serial_stop_bits_items = Builtins.add(
                      @serial_stop_bits_items,
                      Item(Id(item_value), item_value)
                    )
                  end
                end 

                if !value_found
                  if "" == value
                    # stop bits may have to be exactly what is set in the printer (e.g. via DIP switches):
                    @serial_stop_bits_items = Builtins.prepend(
                      @serial_stop_bits_items,
                      Item(Id(""), "", true)
                    )
                  else
                    # If the current value is none of them, it might be invalid or a typo.
                    # Therefore the current value is added with an appropriate hint.
                    # Nevertheless the current value must be topmost and preselected because
                    # anything else which might be preselected (even an empty value)
                    # would silently change the current value to the preselected one
                    # when the user clicks [OK]:
                    @serial_stop_bits_items = Builtins.prepend(
                      @serial_stop_bits_items,
                      Item(
                        Id(value),
                        Ops.add(value, " (might be invalid or a typo)"),
                        true
                      )
                    )
                  end
                end
              end
            end
          end
          model_content = getContentFromCurrentModel(true)
          content = VBox(
            Left(
              ComboBox(
                Id(:serial_device_node),
                # This ComboBox is editable because there could be
                # any kind of serial device node name "/dev/whatever":
                Opt(:editable),
                # Label for an editable ComboBox where
                # a serial device node (e.g. /dev/ttyS0 or /dev/ttyS1)
                # can be selected or entered:
                _("&Serial device"),
                @serial_device_node_items
              )
            ),
            Left(
              ComboBox(
                Id(:serial_baud_rate),
                # The backend/serial.c in the CUPS 1.3.9 sources
                # supports only the preset values below.
                # Nevertheless this ComboBox is editable to be future-proof:
                Opt(:editable),
                # Label for an editable ComboBox where
                # the baud rate for a serial device
                # can be selected or entered:
                _("&Baud rate"),
                @serial_baud_rate_items
              )
            ),
            Left(
              ComboBox(
                Id(:serial_data_bits),
                # The backend/serial.c in the CUPS 1.3.9 sources
                # supports only the preset values below (7 and 8).
                # Nevertheless this ComboBox is editable to be future-proof
                # because according to http://en.wikipedia.org/wiki/Serial_port
                # a serial port might also have 5, 6, or 9 data bits.
                Opt(:editable),
                # Label for an editable ComboBox where
                # the number of data bits for a serial device
                # can be selected or entered:
                _("&Data bits"),
                @serial_data_bits_items
              )
            ),
            Left(
              ComboBox(
                Id(:serial_parity),
                # The backend/serial.c in the CUPS 1.3.9 sources
                # supports only the preset values below.
                # Nevertheless this ComboBox is editable to be future-proof:
                Opt(:editable),
                # Label for an editable ComboBox where
                # the parity checking for a serial device
                # can be selected or entered:
                _("&Parity checking"),
                @serial_parity_items
              )
            ),
            Left(
              ComboBox(
                Id(:serial_flow_control),
                # The backend/serial.c in the CUPS 1.3.9 sources
                # supports only the preset values below.
                # Nevertheless this ComboBox is editable to be future-proof
                # because according to http://en.wikipedia.org/wiki/Flow_control
                # a serial port might also have another kind of flow control.
                Opt(:editable),
                # Label for an editable ComboBox where
                # the flow control for a serial device
                # can be selected or entered:
                _("&Flow control"),
                @serial_flow_control_items
              )
            ),
            Left(
              ComboBox(
                Id(:serial_stop_bits),
                # The backend/serial.c in the CUPS 1.3.9 sources
                # supports only the preset values below.
                # Nevertheless this ComboBox is editable to be future-proof:
                Opt(:editable),
                # Label for an editable ComboBox where
                # the number of stop bits for a serial device
                # can be selected or entered:
                _("S&top bits"),
                @serial_stop_bits_items
              )
            ),
            model_content
          )
        when :bluetooth
          if !Printerlib.TestAndInstallPackage("bluez-cups", "installed")
            if Popup.ContinueCancel(
                _(
                  "To access a bluetooth printer, the RPM package bluez-cups must be installed."
                )
              )
              Printerlib.TestAndInstallPackage("bluez-cups", "install")
              # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
              # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
              # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
              # so that this leftover "abort" button must be explicitly hidden here:
              Wizard.HideAbortButton
            end
            # The user can also decide during the actual installation not to install it
            # or the installation may have failed for whatever reason
            # so that we test again whether or not it is now actually installed:
            if !Printerlib.TestAndInstallPackage("bluez-cups", "installed")
              content = VBox(
                Left(Label(_("The RPM package bluez-cups is not installed.")))
              )
            end
          else
            # Fallback message what the user may run manually when it fails
            # to generate a valid list of bluetooth device IDs:
            bluetooth_device_list = _(
              "It seems there are no bluetooth device IDs.\n" +
                "Run 'hcitool scan' to get the bluetooth device IDs.\n" +
                "Enter the ID without colons like '1A2B3C4D5E6F'."
            )
            Popup.ShowFeedback(
              "",
              # Busy message:
              # Body of a Popup::ShowFeedback:
              _("Retrieving bluetooth device IDs...")
            )
            # The command "hcitool scan" might need very much time or hang up.
            # To kill exactly hcitool there is the workaround via the temporary file because
            # hcitool scan | grep '...' & sleep 10 ; kill -9 $!
            # would kill only grep and
            # ( hcitool scan | grep '...' ) & sleep 10 ; kill -9 $!
            # would kill only the sub shell.
            if !Printerlib.ExecuteBashCommand(
                "hcitool scan >/tmp/hcitool_scan.out & sleep 10 ; kill -9 $! ; grep '..:..:..:..:..:..' /tmp/hcitool_scan.out | tr -s ' ' ; rm -f /tmp/hcitool_scan.out"
              )
              Popup.ErrorDetails(
                _("Failed to get a list of bluetooth device IDs."),
                Ops.add(
                  "hcitool scan" + "\n",
                  Ops.get_string(Printerlib.result, "stderr", "")
                )
              )
            else
              if "" != Ops.get_string(Printerlib.result, "stdout", "")
                bluetooth_device_list = Ops.get_string(
                  Printerlib.result,
                  "stdout",
                  ""
                )
              end
            end
            Popup.ClearFeedback
            Builtins.y2milestone(
              "bluetooth_device_list '%1'",
              bluetooth_device_list
            )
            current_device_uri = getCurrentDeviceURI
            current_bluetooth_device_id = ""
            bluetooth_device_id_items = []
            if "bluetooth:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("bluetooth:/")
                )
              # bluetooth://deviceID
              uri_parts = Builtins.splitstring(current_device_uri, "/")
              # Remove empty parts (e.g. bluetooth://deviceID results ["bluetooth:","","deviceID"]):
              uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
              Builtins.y2milestone(
                "ConnectionWizardDialog uri_parts = '%1'",
                uri_parts
              )
              # Note that uri_parts[0] = "bluetooth:".
              if "" != Ops.get(uri_parts, 1, "")
                current_bluetooth_device_id = Ops.get(uri_parts, 1, "")
              end
            end
            current_bluetooth_device_id_found = false
            Builtins.foreach(Builtins.splitstring(bluetooth_device_list, " ")) do |word|
              if Builtins.regexpmatch(word, "..:..:..:..:..:..")
                # but the bluetooth backend needs it without the colons ':'
                # in its DeviceURI which has the form bluetooth://1A2B3C4D5E6F
                hexnumber = Builtins.filterchars(word, "0123456789ABCDEFabcdef")
                if "" != hexnumber
                  if current_bluetooth_device_id == hexnumber
                    current_bluetooth_device_id_found = true
                    # Have the current bluetooth device id preselected:
                    bluetooth_device_id_items = Builtins.add(
                      bluetooth_device_id_items,
                      Item(Id(hexnumber), hexnumber, true)
                    )
                  else
                    bluetooth_device_id_items = Builtins.add(
                      bluetooth_device_id_items,
                      Item(Id(hexnumber), hexnumber)
                    )
                  end
                end
              end
            end 

            if !current_bluetooth_device_id_found
              if "" == current_bluetooth_device_id
                # the bluetooth backend may blindly write to any bluetooth device:
                bluetooth_device_id_items = Builtins.prepend(
                  bluetooth_device_id_items,
                  Item(Id(""), "", true)
                )
              else
                bluetooth_device_id_items = Builtins.prepend(
                  bluetooth_device_id_items,
                  Item(
                    Id(current_bluetooth_device_id),
                    current_bluetooth_device_id,
                    true
                  )
                )
              end
            end
            model_content = getContentFromCurrentModel(true)
            content = VBox(
              Left(
                ComboBox(
                  Id(:bluetooth_device_id),
                  Opt(:editable),
                  # Label for an editable ComboBox where
                  # a bluetooth device ID
                  # can be selected or entered:
                  _("&Bluetooth device ID"),
                  bluetooth_device_id_items
                )
              ),
              Left(
                Frame(
                  _("Currently available bluetooth device IDs"),
                  # The RichText widget is required here to get scroll bars if needed
                  # (a Label cuts the content because it does not provide scroll bars):
                  RichText(
                    Ops.add(Ops.add("<pre>", bluetooth_device_list), "</pre>")
                  )
                ) # TRANSLATORS: Frame label for a list of bluetooth device IDs:
              ),
              model_content
            )
          end
        when :tcp
          hostname = ""
          port_or_queue = "9100"
          uri_options = ""
          current_device_uri = getCurrentDeviceURI
          if "socket:/" ==
              Builtins.substring(
                current_device_uri,
                0,
                Builtins.size("socket:/")
              )
            # socket://ip-address-or-hostname[:port-number][?waiteof=false]
            uri_parts = Builtins.splitstring(current_device_uri, ":/?")
            # Remove empty parts (e.g. socket://server results ["socket","","","server"]):
            uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
            Builtins.y2milestone(
              "ConnectionWizardDialog uri_parts = '%1'",
              uri_parts
            )
            # Note that uri_parts[0] = "socket".
            if "" != Ops.get(uri_parts, 1, "")
              hostname = Ops.get(uri_parts, 1, "")
              if "" != Ops.get(uri_parts, 2, "")
                if Builtins.issubstring(Ops.get(uri_parts, 2, ""), "=")
                  uri_options = Ops.get(uri_parts, 2, "")
                else
                  port_or_queue = Ops.get(uri_parts, 2, "")
                  if Builtins.issubstring(Ops.get(uri_parts, 3, ""), "=")
                    uri_options = Ops.get(uri_parts, 3, "")
                  end
                end
              end
            end
          end
          connection_content = getNetworkContent(
            URIpercentDecoding(hostname),
            # TRANSLATORS: List of input field labels,
            # first for network scan button,
            # second for the TCP port number:
            _("Scan for Direct Socket Servers"),
            _("TCP Port Number"),
            URIpercentDecoding(port_or_queue),
            uri_options
          )
          model_content = getContentFromCurrentModel(true)
          content = VBox(connection_content, model_content)
        when :lpd
          hostname = ""
          port_or_queue = "LPT1"
          uri_options = ""
          current_device_uri = getCurrentDeviceURI
          if "lpd:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("lpd:/"))
            # (there is no authentication via LPD protocol)
            # to describe who requested a print job in the form
            #   lpd://username@ip-address-or-hostname/...
            # but usage of this is really really not encouraged, see
            # https://bugzilla.novell.com/show_bug.cgi?id=512549
            # so that its setup not supported here but when
            # such an URI already exists, it should be shown correctly:
            # CUPS' "lpstat -v" suppresses "username:password@" (if it exists)
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "lpd"
            )
            # The Device URI has the form ([...[...]...] are optional parts):
            # lpd://ip-address-or-hostname/queue[?option1=value1[&option2=value2...[&optionN=valueN]...]]
            uri_parts = Builtins.splitstring(current_device_uri, ":/?")
            # Remove empty parts (e.g. lpd://server results ["lpd","","","server"]):
            uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
            Builtins.y2milestone(
              "ConnectionWizardDialog uri_parts = '%1'",
              uri_parts
            )
            # Note that uri_parts[0] = "lpd".
            if "" != Ops.get(uri_parts, 1, "")
              hostname = Ops.get(uri_parts, 1, "")
              if "" != Ops.get(uri_parts, 2, "")
                port_or_queue = Ops.get(uri_parts, 2, "")
                if "" != Ops.get(uri_parts, 3, "")
                  uri_options = Ops.get(uri_parts, 3, "")
                end
              end
            end
          end
          if !Builtins.issubstring(hostname, "@")
            # when it contains a '@' because a lpd URI can be of the form
            #   lpd://username@ip-address-or-hostname/...
            # see https://bugzilla.novell.com/show_bug.cgi?id=512549
            hostname = URIpercentDecoding(hostname)
          end
          connection_content = getNetworkContent(
            hostname,
            # TRANSLATORS: List of input field labels,
            # first for network scan button,
            # second for name of printer queue
            _("Scan for LPD Servers"),
            _("Queue Name (see the printer's manual)"),
            URIpercentDecoding(port_or_queue),
            uri_options
          )
          model_content = getContentFromCurrentModel(true)
          content = VBox(connection_content, model_content)
        when :ipp
          uri = ""
          current_device_uri = getCurrentDeviceURI
          if "ipp:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("ipp:/")) ||
              "http:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("http:/")
                )
            # fixed username and password for authentication in the form
            #   ipp://username:password@ip-address-or-hostname/...
            #   http://username:password@ip-address-or-hostname/...
            # but usage of this is really really not encouraged, see
            # https://bugzilla.novell.com/show_bug.cgi?id=512549
            # so that its setup not supported here but when
            # such an URI already exists, it should be shown correctly:
            if "ipp:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("ipp:/")
                )
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "ipp"
              )
            end
            if "http:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("http:/")
                )
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "http"
              )
            end
            # A Device URI to print via CUPS server has the form "ipp://server/printers/queue"
            # while a Device URI to access a network printer via IPP
            # does probably not contain "/printers/" so that this is used here
            # as a best effort attempt to distinguish both cases:
            if !Builtins.issubstring(current_device_uri, "/printers/")
              # {ipp|http}://ip-address-or-hostname[:port-number]/resource[?option1=value1...[&optionN=valueN]...]
              uri = current_device_uri
            end
          end
          model_content = getContentFromCurrentModel(true)
          content = VBox(
            Left(
              InputField(
                Id(:uri),
                # Show it as wide as possible because it may have to contain
                # longer stuff like 'ipp://ip-address:port-number/resource':
                Opt(:hstretch),
                # TRANSLATORS: Input field label
                _("URI (see the printer's manual) [percent-encoded]"),
                uri
              )
            ),
            model_content
          )
        when :smb
          if !Printerlib.TestAndInstallPackage("samba-client", "installed")
            if Popup.ContinueCancel(
                _(
                  "To access a SMB printer share, the RPM package samba-client must be installed."
                )
              )
              Printerlib.TestAndInstallPackage("samba-client", "install")
              # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
              # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
              # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
              # so that this leftover "abort" button must be explicitly hidden here:
              Wizard.HideAbortButton
            end
            # The user can also decide during the actual installation not to install it
            # or the installation may have failed for whatever reason
            # so that we test again whether or not it is now actually installed:
            if !Printerlib.TestAndInstallPackage("samba-client", "installed")
              content = VBox(
                Left(Label(_("The RPM package samba-client is not installed.")))
              )
            end
          else
            hostname = ""
            domain = ""
            printer = ""
            user = ""
            pass = ""
            current_device_uri = getCurrentDeviceURI
            if "smb:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("smb:/")
                )
              # smb://server[:port]/share
              # smb://workgroup/server[:port]/share
              # smb://username:password@server[:port]/share
              # smb://username:password@workgroup/server[:port]/share
              # CUPS' "lpstat -v" suppresses "username:password@" (if it exists)
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "smb"
              )
              # Here '/' is the only delimiter (so that username:password and server:port is one part):
              uri_parts = Builtins.splitstring(current_device_uri, "/")
              # Remove empty parts (e.g. smb://server results ["smb:","","server"]):
              uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
              Builtins.y2milestone(
                "ConnectionWizardDialog uri_parts = '%1'",
                uri_parts
              )
              if "" != Ops.get(uri_parts, 1, "") &&
                  "" != Ops.get(uri_parts, 2, "")
                if Builtins.issubstring(Ops.get(uri_parts, 1, ""), "@")
                  # or
                  # smb://username:password@workgroup/server[:port]/share
                  if "" != Ops.get(uri_parts, 3, "")
                    user_pass_domain = Builtins.splitstring(
                      Ops.get(uri_parts, 1, ""),
                      ":@"
                    )
                    user = Ops.get(user_pass_domain, 0, "")
                    pass = Ops.get(user_pass_domain, 1, "")
                    domain = Ops.get(user_pass_domain, 2, "")
                    hostname = Ops.get(uri_parts, 2, "")
                    printer = Ops.get(uri_parts, 3, "")
                  else
                    user_pass_hostname = Builtins.splitstring(
                      Ops.get(uri_parts, 1, ""),
                      ":@"
                    )
                    user = Ops.get(user_pass_hostname, 0, "")
                    pass = Ops.get(user_pass_hostname, 1, "")
                    hostname = Ops.get(user_pass_hostname, 2, "")
                    printer = Ops.get(uri_parts, 2, "")
                  end
                else
                  # or
                  # smb://workgroup/server[:port]/share
                  if "" != Ops.get(uri_parts, 3, "")
                    domain = Ops.get(uri_parts, 1, "")
                    hostname = Ops.get(uri_parts, 2, "")
                    printer = Ops.get(uri_parts, 3, "")
                  else
                    hostname = Ops.get(uri_parts, 1, "")
                    printer = Ops.get(uri_parts, 2, "")
                  end
                end
              end
            end
            # Be backward compatible for openSUSE < 11.3 and be prepared for /usr/lib64/cups/
            Printerlib.ExecuteBashCommand(
              "ls -1 /usr/lib*/cups/backend/smb | head -n1 | tr -d '[:space:]'"
            )
            # readlink is in the coreutils RPM so that it is available in any case.
            Printerlib.ExecuteBashCommand("readlink " + Ops.get_string(Printerlib.result, "stdout", "") + " | tr -d '[:space:]'")
            # Only if /usr/lib[64]/cups/backend/smb -> /usr/bin/get_printing_ticket
            # there is support for Active Directory (R):
            if "/usr/bin/get_printing_ticket" ==
                Ops.get_string(Printerlib.result, "stdout", "")
              active_directory_support = true
            end
            model_content = getContentFromCurrentModel(true)
            content = VBox(
              Left(
                HBox(
                  ComboBox(
                    Id(:hostname), #),
                    #`MenuButton
                    #( // TRANSLATORS: Label for menu to search for remote servers
                    #  _("Look up"),
                    #  [ `item( `id(`scan), _("Scan for samba printers") ),
                    #    // TRANSLATORS: Button to search for remote servers
                    #    `item( `id(`scan_all), _("Look up for All Hosts") )
                    #  ]
                    Opt(:editable),
                    # TRANSLATORS: Text entry for remote server name
                    _("&Server (NetBIOS Host Name)"),
                    [URIpercentDecoding(hostname)]
                  )
                )
              ),
              Left(
                InputField(
                  Id(:printer),
                  # TRANSLATORS: Text entry for printer name
                  _("&Printer (Share Name)"),
                  URIpercentDecoding(printer)
                )
              ),
              Left(
                HBox(
                  ComboBox(
                    Id(:domain),
                    Opt(:editable),
                    # TRANSLATORS: Text entry for samba domain
                    _("&Workgroup (Domain Name)"),
                    [URIpercentDecoding(domain)]
                  )
                )
              ),
              Left(
                Frame(
                  _("Authentication (if needed)"),
                  VBox(
                    Left(
                      Label(_("Use fixed username and password")) # A Label for authentication via fixed username and password:
                    ),
                    Left(
                      HBox(
                        HSpacing(2),
                        VBox(
                          Left(
                            InputField(
                              Id(:user),
                              # TRANSLATORS: Text entry for username (authentication)
                              _("&User"),
                              URIpercentDecoding(user)
                            )
                          ),
                          Left(
                            Password(
                              Id(:pass),
                              # TRANSLATORS: Text entry for password (authentication)
                              _("Pass&word"),
                              URIpercentDecoding(pass)
                            )
                          )
                        )
                      )
                    ),
                    Left(
                      CheckBox(
                        Id(:active_directory_check_box),
                        Opt(:notify),
                        # A CheckBox to support Active Directory (R):
                        _("Support for &Active Directory (R)"),
                        active_directory_support
                      )
                    )
                  )
                ) # TRANSLATORS: Frame label for authentication
              ),
              Left(
                PushButton(
                  Id(:test),
                  # TRANSLATORS: Button to test remote printer machine
                  _("&Test Connection")
                )
              ),
              model_content
            )
          end
        when :lpr
          hostname = ""
          port_or_queue = ""
          uri_options = ""
          current_device_uri = getCurrentDeviceURI
          if "lpd:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("lpd:/"))
            # (there is no authentication via LPD protocol)
            # to describe who requested a print job in the form
            #   lpd://username@ip-address-or-hostname/...
            # but usage of this is really really not encouraged, see
            # https://bugzilla.novell.com/show_bug.cgi?id=512549
            # so that its setup not supported here but when
            # such an URI already exists, it should be shown correctly:
            # CUPS' "lpstat -v" suppresses "username:password@" (if it exists)
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "lpd"
            )
            # The Device URI has the form ([...[...]...] are optional parts):
            # lpd://ip-address-or-hostname/queue[?option1=value1[&option2=value2...[&optionN=valueN]...]]
            uri_parts = Builtins.splitstring(current_device_uri, ":/?")
            # Remove empty parts (e.g. lpd://server results ["lpd","","","server"]):
            uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
            Builtins.y2milestone(
              "ConnectionWizardDialog uri_parts = '%1'",
              uri_parts
            )
            # Note that uri_parts[0] = "lpd".
            if "" != Ops.get(uri_parts, 1, "")
              hostname = Ops.get(uri_parts, 1, "")
              if "" != Ops.get(uri_parts, 2, "")
                port_or_queue = Ops.get(uri_parts, 2, "")
                if "" != Ops.get(uri_parts, 3, "")
                  uri_options = Ops.get(uri_parts, 3, "")
                end
              end
            end
          end
          if !Builtins.issubstring(hostname, "@")
            # when it contains a '@' because a lpd URI can be of the form
            #   lpd://username@ip-address-or-hostname/...
            # see https://bugzilla.novell.com/show_bug.cgi?id=512549
            hostname = URIpercentDecoding(hostname)
          end
          connection_content = getNetworkContent(
            hostname,
            # TRANSLATORS: List of input field labels,
            # first for network scan button,
            # second for name of printer queue
            _("Scan for LPD Servers"),
            _("Queue Name"),
            URIpercentDecoding(port_or_queue),
            uri_options
          )
          model_content = getContentFromCurrentModel(false)
          content = VBox(connection_content, model_content)
        when :cups
          hostname = ""
          queue = ""
          uri_options = ""
          current_device_uri = getCurrentDeviceURI
          if "ipp:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("ipp:/")) ||
              "http:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("http:/")
                )
            # fixed username and password for authentication in the form
            #   ipp://username:password@ip-address-or-hostname/...
            #   http://username:password@ip-address-or-hostname/...
            # but usage of this is really really not encouraged, see
            # https://bugzilla.novell.com/show_bug.cgi?id=512549
            # so that its setup not supported here but when
            # such an URI already exists, it should be shown correctly:
            if "ipp:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("ipp:/")
                )
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "ipp"
              )
            end
            if "http:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("http:/")
                )
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "http"
              )
            end
            # A Device URI to print via CUPS server has the form "ipp://server/printers/queue"
            # while a Device URI to access a network printer via IPP
            # does probably not contain "/printers/" so that this is used here
            # as a best effort attempt to distinguish both cases:
            if Builtins.issubstring(current_device_uri, "/printers/")
              # {ipp|http}://ip-address-or-hostname[:port-number]/resource[?option1=value1...[&optionN=valueN]...]
              # where resource is something like /printers/queue on a CUPS server.
              # Here ':' is no delimiter so that ip-address-or-hostname:port-number is one part
              uri_parts = Builtins.splitstring(current_device_uri, "/?")
              # Remove empty parts (e.g. ipp://server results ["ipp:","","server"]):
              uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
              Builtins.y2milestone(
                "ConnectionWizardDialog uri_parts = '%1'",
                uri_parts
              )
              # Note that uri_parts[0] = "{ipp:|http:}".
              if "" != Ops.get(uri_parts, 1, "")
                hostname = Ops.get(uri_parts, 1, "")
                if "printers" == Ops.get(uri_parts, 2, "")
                  if "" != Ops.get(uri_parts, 3, "")
                    queue = Ops.get(uri_parts, 3, "")
                    if Builtins.issubstring(Ops.get(uri_parts, 4, ""), "=")
                      uri_options = Ops.get(uri_parts, 4, "")
                    end
                  end
                end
              end
            end
          end
          # TRANSLATORS: Text entry to fill IP or hostname of remote server
          @hostname_label = _("&IP Address or Host Name [percent-encoded]")
          if !Builtins.issubstring(hostname, "@")
            # when it contains a '@' because a ipp/http URI can be of the form
            #   ipp://username:password@ip-address-or-hostname/...
            #   http://username:password@ip-address-or-hostname/...
            # see https://bugzilla.novell.com/show_bug.cgi?id=512549
            hostname = URIpercentDecoding(hostname)
            # TRANSLATORS: Text entry to fill IP or hostname of remote server
            @hostname_label = _("&IP Address or Host Name")
          end
          model_content = getContentFromCurrentModel(false)
          content = VBox(
            Left(
              HBox(
                Bottom(
                  ComboBox(
                    Id(:hostname),
                    Opt(:editable),
                    @hostname_label,
                    [hostname]
                  )
                ),
                Bottom(
                  MenuButton(
                    _("Look up"),
                    [
                      Item(Id(:scan), _("Scan for IPP Servers")),
                      Item(Id(:scan_broadcast), _("Scan for IPP Broadcasts")),
                      Item(Id(:scan_all), _("Look up for All Hosts"))
                    ]
                  ) # TRANSLATORS: Label for menu to search for remote servers
                )
              )
            ),
            Left(
              InputField(Id(:queue), _("Queue Name"), URIpercentDecoding(queue))
            ), # TRANSLATORS: InputField for a print queue name:
            Left(
              InputField(
                Id(:uri_options),
                # Show it as wide as possible because it may have to contain
                # longer stuff like 'option1=value1&option2=value2':
                Opt(:hstretch),
                # TRANSLATORS: InputField for optional Device URI parameters:
                _(
                  "Optional 'option=value' parameter (usually empty) [percent-encoded]"
                ),
                uri_options
              )
            ),
            Left(
              PushButton(
                Id(:test),
                # TRANSLATORS: Button to test remote printer machine
                _("&Test Connection")
              )
            ),
            model_content
          )
        when :ipx
          if !Printerlib.TestAndInstallPackage("ncpfs", "installed")
            if Popup.ContinueCancel(
                _(
                  "To access an IPX print queue, the RPM package ncpfs must be installed."
                )
              )
              Printerlib.TestAndInstallPackage("ncpfs", "install")
              # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
              # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
              # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
              # so that this leftover "abort" button must be explicitly hidden here:
              Wizard.HideAbortButton
            end
            # The user can also decide during the actual installation not to install it
            # or the installation may have failed for whatever reason
            # so that we test again whether or not it is now actually installed:
            if !Printerlib.TestAndInstallPackage("ncpfs", "installed")
              content = VBox(
                Left(Label(_("The RPM package ncpfs is not installed.")))
              )
            end
          else
            hostname = ""
            queue = ""
            user = ""
            pass = ""
            current_device_uri = getCurrentDeviceURI
            if "novell:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("novell:/")
                )
              # novell://server/queue
              # novell://username:password@server/queue
              # CUPS' "lpstat -v" suppresses "username:password@" (if it exists)
              # so that it may have to be retrieved form /etc/cups/printers.conf.
              # Fortunately getSMBuriWithUsernameAndPassword works here too
              # because the forms of IPX and SMB device URIs match sufficienty:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "novell"
              )
              # Here '/' is the only delimiter (so that username:password and server:port is one part):
              uri_parts = Builtins.splitstring(current_device_uri, "/")
              # Remove empty parts (e.g. novell://server results ["novell:","","server"]):
              uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
              Builtins.y2milestone(
                "ConnectionWizardDialog uri_parts = '%1'",
                uri_parts
              )
              if "" != Ops.get(uri_parts, 1, "") &&
                  "" != Ops.get(uri_parts, 2, "")
                if Builtins.issubstring(Ops.get(uri_parts, 1, ""), "@")
                  user_pass_hostname = Builtins.splitstring(
                    Ops.get(uri_parts, 1, ""),
                    ":@"
                  )
                  user = Ops.get(user_pass_hostname, 0, "")
                  pass = Ops.get(user_pass_hostname, 1, "")
                  hostname = Ops.get(user_pass_hostname, 2, "")
                  queue = Ops.get(uri_parts, 2, "")
                else
                  hostname = Ops.get(uri_parts, 1, "")
                  queue = Ops.get(uri_parts, 2, "")
                end
              end
            end
            model_content = getContentFromCurrentModel(true)
            content = VBox(
              Left(
                InputField(
                  Id(:hostname),
                  # TRANSLATORS: Text entry for IP or hostname of remote server
                  _("IP Address or Host Name"),
                  hostname
                )
              ),
              Left(
                InputField(
                  Id(:queue),
                  # TRANSLATORS: Text entry for name of remote printer queue
                  _("Queue Name"),
                  queue
                )
              ),
              Left(
                Frame(
                  _("Authenticate as"),
                  VBox(
                    InputField(
                      Id(:user),
                      # TRANSLATORS: Text entry for username (authentication)
                      _("User"),
                      user
                    ),
                    Password(
                      Id(:pass),
                      # TRANSLATORS: Text entry for password (authentication)
                      _("&Password"),
                      pass
                    )
                  )
                ) # TRANSLATORS: Frame label for authentication
              ),
              Left(
                PushButton(
                  Id(:test),
                  # TRANSLATORS: Button to test remote printer machine
                  _("&Test Connection")
                )
              ),
              model_content
            )
          end
        when :uri
          current_device_uri = getCurrentDeviceURI
          if "smb:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("smb:/"))
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "smb"
            )
          end
          if "novell:/" ==
              Builtins.substring(
                current_device_uri,
                0,
                Builtins.size("novell:/")
              )
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "novell"
            )
          end
          # Even the DeviceURI for ipp/http can contain
          # fixed username and password for authentication in the form
          #   ipp://username:password@ip-address-or-hostname/...
          #   http://username:password@ip-address-or-hostname/...
          # but usage of this is really really not encouraged, see
          # https://bugzilla.novell.com/show_bug.cgi?id=512549
          # so that its setup not supported here but when
          # such an URI already exists, it should be shown correctly:
          if "ipp:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("ipp:/"))
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "ipp"
            )
          end
          if "http:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("http:/"))
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "http"
            )
          end
          # Even the DeviceURI for lpd can contain a fixed username
          # (there is no authentication via LPD protocol)
          # to describe who requested a print job in the form
          #   lpd://username@ip-address-or-hostname/...
          # but usage of this is really really not encouraged, see
          # https://bugzilla.novell.com/show_bug.cgi?id=512549
          # so that its setup not supported here but when
          # such an URI already exists, it should be shown correctly:
          if "lpd:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("lpd:/"))
            # so that it may have to be retrieved form /etc/cups/printers.conf:
            current_device_uri = getUriWithUsernameAndPassword(
              current_device_uri,
              "lpd"
            )
          end
          model_content = getContentFromCurrentModel(true)
          content = VBox(
            Left(
              InputField(
                Id(:uri),
                # Show it as wide as possible because it may have to contain
                # longer stuff like 'scheme://server:port/path/to/resource':
                Opt(:hstretch),
                # TRANSLATORS: Text entry for URI (Uniform Resource Identifier)
                _("URI (Uniform Resource Identifier) [percent-encoded]"),
                current_device_uri
              )
            ),
            model_content
          )
        when :pipe
          if !Printerlib.TestAndInstallPackage("cups-backends", "installed")
            if Popup.ContinueCancel(
                _(
                  "To print via 'pipe', the RPM package cups-backends must be installed."
                )
              )
              Printerlib.TestAndInstallPackage("cups-backends", "install")
              # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
              # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
              # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
              # so that this leftover "abort" button must be explicitly hidden here:
              Wizard.HideAbortButton
            end
            # The user can also decide during the actual installation not to install it
            # or the installation may have failed for whatever reason
            # so that we test again whether or not it is now actually installed:
            if !Printerlib.TestAndInstallPackage("cups-backends", "installed")
              content = VBox(
                Left(
                  Label(_("The RPM package cups-backends is not installed."))
                )
              )
            end
          else
            uri = ""
            current_device_uri = getCurrentDeviceURI
            if "pipe:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("pipe:/")
                )
              # pipe:/path/to/command[?option1=value1&option2=value2...]
              # remove the scheme 'pipe:' so that only the '/path/to/command...' is left:
              uri = Builtins.mergestring(
                Builtins.sublist(
                  Builtins.splitstring(current_device_uri, ":"),
                  1
                ),
                ""
              )
            end
            model_content = getContentFromCurrentModel(false)
            content = VBox(
              Left(
                InputField(
                  Id(:program),
                  # Show it as wide as possible because it may have to contain
                  # longer stuff like 'path/to/command?option1=value1&option2=value2':
                  Opt(:hstretch),
                  # TRANSLATORS: Text entry for program name that will be called via pipe:
                  _("Program (/path/to/command?option=value) [percent-encoded]"),
                  uri
                )
              ),
              model_content
            )
          end
        when :beh
          if !Printerlib.TestAndInstallPackage("cups-backends", "installed")
            if Popup.ContinueCancel(
                _(
                  "To use 'beh', the RPM package cups-backends must be installed."
                )
              )
              Printerlib.TestAndInstallPackage("cups-backends", "install")
              # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
              # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
              # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
              # so that this leftover "abort" button must be explicitly hidden here:
              Wizard.HideAbortButton
            end
            # The user can also decide during the actual installation not to install it
            # or the installation may have failed for whatever reason
            # so that we test again whether or not it is now actually installed:
            if !Printerlib.TestAndInstallPackage("cups-backends", "installed")
              content = VBox(
                Left(
                  Label(_("The RPM package cups-backends is not installed."))
                )
              )
            end
          else
            uri = ""
            beh_do_not_disable = true
            beh_attempts = "0"
            beh_delay = "30"
            current_device_uri = getCurrentDeviceURI
            if "smb:/" ==
                Builtins.substring(current_device_uri, 0, Builtins.size("smb:/"))
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "smb"
              )
            end
            if "novell:/" ==
                Builtins.substring(
                  current_device_uri,
                  0,
                  Builtins.size("novell:/")
                )
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "novell"
              )
            end
            # Even the DeviceURI for ipp/http can contain
            # fixed username and password for authentication in the form
            #   ipp://username:password@ip-address-or-hostname/...
            #   http://username:password@ip-address-or-hostname/...
            # but usage of this is really really not encouraged, see
            # https://bugzilla.novell.com/show_bug.cgi?id=512549
            # so that its setup not supported here but when
            # such an URI already exists, it should be shown correctly:
            if "ipp:/" ==
                Builtins.substring(current_device_uri, 0, Builtins.size("ipp:/"))
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "ipp"
              )
            end
            if "http:/" ==
                Builtins.substring(current_device_uri, 0, Builtins.size("http:/"))
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "http"
              )
            end
            # Even the DeviceURI for lpd can contain a fixed username
            # (there is no authentication via LPD protocol)
            # to describe who requested a print job in the form
            #   lpd://username@ip-address-or-hostname/...
            # but usage of this is really really not encouraged, see
            # https://bugzilla.novell.com/show_bug.cgi?id=512549
            # so that its setup not supported here but when
            # such an URI already exists, it should be shown correctly:
            if "lpd:/" ==
                Builtins.substring(current_device_uri, 0, Builtins.size("lpd:/"))
              # so that it may have to be retrieved form /etc/cups/printers.conf:
              current_device_uri = getUriWithUsernameAndPassword(
                current_device_uri,
                "lpd"
              )
            end
            uri = current_device_uri
            if "beh:/" ==
                Builtins.substring(current_device_uri, 0, Builtins.size("beh:/"))
              # remove the beh-related stuff so that only the <originaluri> is left:
              uri = Builtins.mergestring(
                Builtins.sublist(Builtins.splitstring(current_device_uri, "/"), 4),
                "/"
              )
              uri_parts = Builtins.splitstring(current_device_uri, "/")
              # Remove possibly empty parts:
              uri_parts = Builtins.filter(uri_parts) { |part| "" != part }
              Builtins.y2milestone(
                "ConnectionWizardDialog uri_parts = '%1'",
                uri_parts
              )
              if "" != Ops.get(uri_parts, 1, "") &&
                  "" != Ops.get(uri_parts, 2, "") &&
                  "" != Ops.get(uri_parts, 3, "")
                beh_do_not_disable = false if "0" == Ops.get(uri_parts, 1, "")
                beh_attempts = Ops.get(uri_parts, 2, "")
                beh_delay = Ops.get(uri_parts, 3, "")
              end
            end
            model_content = getContentFromCurrentModel(true)
            content = VBox(
              Left(
                InputField(
                  Id(:beh_original_uri),
                  # Show it as wide as possible because it may have to contain
                  # longer stuff like 'scheme://server:port/path/to/resource':
                  Opt(:hstretch),
                  # TRANSLATORS: Text entry for device URI (Uniform Resource Identifier)
                  _(
                    "Device URI (for which 'beh' should be applied) [percent-encoded]"
                  ),
                  uri
                )
              ),
              Left(
                CheckBox(
                  Id(:beh_do_not_disable),
                  # TRANSLATORS: Check box
                  _("Never Disable the Queue"),
                  beh_do_not_disable
                )
              ),
              Left(
                InputField(
                  Id(:beh_attempts),
                  # TRANSLATORS: Text entry
                  _("Number of Retries ('0' means infinite retries)"),
                  beh_attempts
                )
              ),
              Left(
                InputField(
                  Id(:beh_delay),
                  # TRANSLATORS: Text entry
                  _("Delay in Seconds Between Two Retries"),
                  beh_delay
                )
              ),
              model_content
            )
          end
        when :directly, :network, :server, :special
          content = VBox(Left(Label(_("Select a specific connection type."))))
        else
          Builtins.y2error("Unknown selected item %1", selected)
      end
      UI.ReplaceWidget(:connection_settings_replace_point, content)

      nil
    end

    def ConnectionWizardDialog
      contents = VBox(
        HBox(
          HWeight(
            1,
            Tree(
              Id(:tree_selection),
              Opt(:notify),
              # TRANSLATORS: Label for tree widget description
              _("&Connection Type"),
              [
                Item(
                  Id(:directly),
                  # TRANSLATORS: Tree widget item
                  _("Directly Connected Device"),
                  true,
                  [
                    # Disabled legacy "Parallel Port" so that it is no longer accessible in the dialog:
                    #Item(Id(:parallel), _("Parallel Port")),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:usb), _("USB Port")),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:hplip), _("HP Devices (HPLIP)")),
                    # TRANSLATORS: Tree widget item
                    # Disabled legacy "Serial Port" so that it is no longer accessible in the dialog:
                    #Item(Id(:serial), _("Serial Port")),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:bluetooth), _("Bluetooth"))
                  ] # TRANSLATORS: Tree widget item
                ),
                Item(
                  Id(:network),
                  # TRANSLATORS: Tree widget item
                  _("Access Network Printer or Printserver Box via"),
                  true,
                  [
                    Item(Id(:tcp), _("TCP Port (AppSocket/JetDirect)")),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:lpd), _("Line Printer Daemon (LPD) Protocol")),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:ipp), _("Internet Printing Protocol (IPP)"))
                  ] # TRANSLATORS: Tree widget item
                ),
                Item(
                  Id(:server),
                  # TRANSLATORS: Tree widget item
                  _("Print via Print Server Machine"),
                  true,
                  [
                    Item(Id(:smb), _("Windows (R) or Samba (SMB/CIFS)")),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:lpr), _("Traditional UNIX Server (LPR/LPD)")),
                    # `item( `id(`iprint), _("iPrint (Novell OES)") ),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:cups), _("CUPS Server (IPP)")),
                    # TRANSLATORS: Tree widget item
                    # Disabled legacy "Novell Netware Print Server (IPX)" so that it is no longer accessible in the dialog:
                    #Item(Id(:ipx), _("Novell Netware Print Server (IPX)"))
                  ] # TRANSLATORS: Tree widget item
                ),
                Item(
                  Id(:special),
                  # TRANSLATORS: Tree widget item
                  _("Special"),
                  true,
                  [
                    Item(Id(:uri), _("Specify Arbitrary Device URI")),
                    # TRANSLATORS: Tree widget item
                    Item(
                      Id(:pipe),
                      _("Send Print Data to Other Program (pipe)")
                    ),
                    # TRANSLATORS: Tree widget item
                    Item(Id(:beh), _("Daisy-chain Backend Error Handler (beh)"))
                  ] # TRANSLATORS: Tree widget item
                )
              ]
            )
          ),
          HWeight(
            1,
            VBox(
              VStretch(),
              Frame(
                _("Connection Settings"),
                ReplacePoint(
                  Id(:connection_settings_replace_point),
                  VBox(Left(Label(_("Select a specific connection type."))))
                )
              ), # TRANSLATORS: Connection details widget
              VStretch()
            )
          )
        )
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
        _("Connection Wizard"),
        contents,
        Ops.get_string(@HELPS, "connection_wizard_dialog", ""),
        # Set a new label for the "back" button, see the comment above:
        Label.CancelButton,
        # Set a new label for the "next" button, see the comment above:
        Label.OKButton
      )
      Wizard.HideAbortButton
      # Try to preselect an item which matches to the currently selected Device URI
      # from the previous "add queue" or "modify queue" dialogs or
      # which matches to the currently selected queue in the "overview" dialog.
      # But when the previous dialog was "printing via network"
      # there is no currently available Device URI.
      current_device_uri = getCurrentDeviceURI
      if "" != current_device_uri
        if "parallel:/" ==
            Builtins.substring(
              current_device_uri,
              0,
              Builtins.size("parallel:/")
            )
          UI.ChangeWidget(:tree_selection, :CurrentItem, :parallel)
          changeSettingsDialog(:parallel)
        elsif "usb:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("usb:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :usb)
          changeSettingsDialog(:usb)
        elsif "hp:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("hp:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :hplip)
          changeSettingsDialog(:hplip)
        elsif "serial:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("serial:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :serial)
          changeSettingsDialog(:serial)
        elsif "bluetooth:/" ==
            Builtins.substring(
              current_device_uri,
              0,
              Builtins.size("bluetooth:/")
            )
          UI.ChangeWidget(:tree_selection, :CurrentItem, :bluetooth)
          changeSettingsDialog(:bluetooth)
        elsif "scsi:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("scsi:/"))
          # see https://bugzilla.novell.com/show_bug.cgi?id=580121
          # and http://www.cups.org/str.php?L3500
          # i.e. the scsi backend will be dropped.
          # Therefore in yast2-printer SCSI printer support is also dropped.
          # Because of the dropped scsi backend there must be a user notification:
          if !Printerlib.ExecuteBashCommand("ls /usr/lib*/cups/backend/scsi")
            Popup.ErrorDetails(
              _("In CUPS version 1.5 SCSI printer support is dropped."),
              # Popup::ErrorDetails details (for experts only):
              _(
                "An untested and insecure workaround might be\n" +
                  "to set 'FileDevice Yes' in cupsd.conf\n" +
                  "and use a DeviceURI like 'file:/dev/sg...'"
              )
            )
          end
          # In this case "Specify Arbitrary Device URI" is used as fallback:
          UI.ChangeWidget(:tree_selection, :CurrentItem, :uri)
          changeSettingsDialog(:uri)
        elsif "socket:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("socket:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :tcp)
          changeSettingsDialog(:tcp)
        elsif "lpd:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("lpd:/"))
          # belongs to the `lpr case (print via traditional UNIX server)
          # or to the `lpd case (access a network printer via LPD port)
          # because the Device URI is in both cases "lpd://server/queue".
          # Nevertheless a currently useless 'false' condition is implemented
          # to be prepared where to insert a reasonable condition
          # to distinguish the cases which may appear in the future.
          # Because access a network printer via LPD port happens more often
          # than print via traditional UNIX server, the first case is used
          # as fallback in any case here:
          if false
            UI.ChangeWidget(:tree_selection, :CurrentItem, :lpr)
            changeSettingsDialog(:lpr)
          else
            UI.ChangeWidget(:tree_selection, :CurrentItem, :lpd)
            changeSettingsDialog(:lpd)
          end
        elsif "ipp:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("ipp:/")) ||
            "http:/" ==
              Builtins.substring(current_device_uri, 0, Builtins.size("http:/"))
          # while a Device URI to access a network printer via IPP
          # does probably not contain "/printers/" so that this is used here
          # as a best effort attempt to distinguish both cases:
          if Builtins.issubstring(current_device_uri, "/printers/")
            UI.ChangeWidget(:tree_selection, :CurrentItem, :cups)
            changeSettingsDialog(:cups)
          else
            UI.ChangeWidget(:tree_selection, :CurrentItem, :ipp)
            changeSettingsDialog(:ipp)
          end
        elsif "smb:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("smb:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :smb)
          changeSettingsDialog(:smb)
        elsif "novell:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("novell:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :ipx)
          changeSettingsDialog(:ipx)
        elsif "pipe:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("pipe:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :pipe)
          changeSettingsDialog(:pipe)
        elsif "beh:/" ==
            Builtins.substring(current_device_uri, 0, Builtins.size("beh:/"))
          UI.ChangeWidget(:tree_selection, :CurrentItem, :beh)
          changeSettingsDialog(:beh)
        end
      end

      validateAndMakeURI = lambda do |selected|
        valid = false
        @connection_uri = ""
        case selected
          when :hplip, :parallel, :usb
            @selected_connection_index = Convert.to_integer(
              UI.QueryWidget(Id(:connection_selection), :CurrentItem)
            )
            if nil == @selected_connection_index
              Popup.AnyMessage(
                _("Select a connection"),
                # Body of a Popup::AnyMessage when no connection was selected
                # because there is no connection available to be selected:
                _(
                  "If no connection is shown here, it is not possible\n" +
                    "to access the device via this type of connection.\n" +
                    "Was the printer connected and switched on all the time?"
                )
              )
            elsif Ops.less_than(@selected_connection_index, 0)
              Popup.AnyMessage(
                _("Select a valid connection"),
                # Body of a Popup::AnyMessage when an invalid connection was selected
                # because the current connection is no longer valid:
                _(
                  "When the current connection is no longer valid,\n" +
                    "it does no longer work to access the device via this connection.\n" +
                    "Is the printer still connected and switched on?"
                )
              )
            else
              @connection_uri = Ops.get(
                Printer.connections,
                [@selected_connection_index, "uri"],
                ""
              )
              @connection_model = Ops.get(
                Printer.connections,
                [@selected_connection_index, "model"],
                "Unknown"
              )
              valid = true if "" != @connection_uri
            end
          when :serial
            @serial_device_node = Convert.to_string(
              UI.QueryWidget(:serial_device_node, :Value)
            )
            @serial_baud_rate = Convert.to_string(
              UI.QueryWidget(:serial_baud_rate, :Value)
            )
            @serial_data_bits = Convert.to_string(
              UI.QueryWidget(:serial_data_bits, :Value)
            )
            @serial_parity = Convert.to_string(
              UI.QueryWidget(:serial_parity, :Value)
            )
            @serial_flow_control = Convert.to_string(
              UI.QueryWidget(:serial_flow_control, :Value)
            )
            @serial_stop_bits = Convert.to_string(
              UI.QueryWidget(:serial_stop_bits, :Value)
            )
            if Builtins.size(@serial_device_node) == 0 ||
                Builtins.size(@serial_baud_rate) == 0
              Popup.Error(_("Serial device and baud rate could not be empty."))
            else
              if "space" == @serial_parity && "7" != @serial_data_bits
                Popup.Error(
                  _(
                    "The 'space' parity checking is only supported with 7 data bits."
                  )
                )
              else
                if "mark" == @serial_parity &&
                    ("7" != @serial_data_bits || "1" != @serial_stop_bits)
                  Popup.Error(
                    _(
                      "The 'mark' parity checking is only supported with 7 data bits and 1 stop bit."
                    )
                  )
                else
                  @connection_uri = Ops.add(
                    Ops.add(Ops.add("serial:", @serial_device_node), "?baud="),
                    @serial_baud_rate
                  )
                  if Ops.greater_than(Builtins.size(@serial_data_bits), 0)
                    @connection_uri = Ops.add(
                      Ops.add(@connection_uri, "+bits="),
                      @serial_data_bits
                    )
                  end
                  if Ops.greater_than(Builtins.size(@serial_parity), 0)
                    @connection_uri = Ops.add(
                      Ops.add(@connection_uri, "+parity="),
                      @serial_parity
                    )
                  end
                  if Ops.greater_than(Builtins.size(@serial_flow_control), 0)
                    @connection_uri = Ops.add(
                      Ops.add(@connection_uri, "+flow="),
                      @serial_flow_control
                    )
                  end
                  if Ops.greater_than(Builtins.size(@serial_stop_bits), 0)
                    @connection_uri = Ops.add(
                      Ops.add(@connection_uri, "+stop="),
                      @serial_stop_bits
                    )
                  end
                  valid = true
                end
              end
            end
          when :bluetooth
            @bluetooth_device_id = Convert.to_string(
              UI.QueryWidget(:bluetooth_device_id, :Value)
            )
            if Builtins.size(@bluetooth_device_id) == 0
              Popup.Error(_("Bluetooth device ID could not be empty."))
            else
              @connection_uri = Ops.add("bluetooth://", @bluetooth_device_id)
              valid = true
            end
          when :ipp, :uri
            @connection_uri = Convert.to_string(UI.QueryWidget(:uri, :Value))
            if Ops.greater_than(Builtins.size(@connection_uri), 0)
              # because special URI characters like ':' or '/' in connection_uri
              # must stay as is and not be percent encoded because only the values
              # of the URI parts must be percent encoded but not the whole URI.
              valid = true
            else
              Popup.Error(_("URI could not be empty."))
            end
          when :smb
            @smb_hostname = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            @smb_printer = Convert.to_string(UI.QueryWidget(:printer, :Value))
            @smb_domain = Convert.to_string(UI.QueryWidget(:domain, :Value))
            @smb_user = Convert.to_string(UI.QueryWidget(:user, :Value))
            @smb_pass = Convert.to_string(UI.QueryWidget(:pass, :Value))
            if "" == Builtins.filterchars(@smb_hostname, Printer.alnum_chars) ||
                "" == Builtins.filterchars(@smb_printer, Printer.alnum_chars)
              Popup.Error(_("Servername and printer could not be empty."))
            else
              if "" != Builtins.filterchars(@smb_user, Printer.alnum_chars) &&
                  Ops.less_than(Builtins.size(@smb_pass), 1) ||
                  "" == Builtins.filterchars(@smb_user, Printer.alnum_chars) &&
                    Ops.greater_than(Builtins.size(@smb_pass), 0)
                Popup.Error(_("Both user and password must be specified."))
              else
                @connection_uri = "smb://"
                if "" != Builtins.filterchars(@smb_user, Printer.alnum_chars) &&
                    Ops.greater_than(Builtins.size(@smb_pass), 0)
                  @connection_uri = Builtins.sformat(
                    "%1%2:%3@",
                    @connection_uri,
                    URIpercentEncoding(@smb_user),
                    URIpercentEncoding(@smb_pass)
                  )
                end
                if "" != Builtins.filterchars(@smb_domain, Printer.alnum_chars)
                  @connection_uri = Builtins.sformat(
                    "%1%2/",
                    @connection_uri,
                    URIpercentEncoding(@smb_domain)
                  )
                end
                @connection_uri = Builtins.sformat(
                  "%1%2/%3",
                  @connection_uri,
                  URIpercentEncoding(@smb_hostname),
                  URIpercentEncoding(@smb_printer)
                )
                valid = true
              end
            end
          when :tcp
            @tcp_hostname = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            @tcp_port = Convert.to_string(
              UI.QueryWidget(:port_or_queue, :Value)
            )
            @tcp_uri_options = Convert.to_string(
              UI.QueryWidget(:uri_options, :Value)
            )
            if "" != Builtins.filterchars(@tcp_hostname, Printer.alnum_chars)
              if "" != Builtins.filterchars(@tcp_port, Printer.alnum_chars)
                if "" !=
                    Builtins.filterchars(@tcp_uri_options, Printer.alnum_chars)
                  # because special URI characters like '=' or '&' in tcp_uri_options
                  # must stay as is and not be percent encoded because tcp_uri_options
                  # contains all options like 'option1=value1&option2=value2'.
                  @connection_uri = Builtins.sformat(
                    "socket://%1:%2?%3",
                    URIpercentEncoding(@tcp_hostname),
                    URIpercentEncoding(@tcp_port),
                    @tcp_uri_options
                  )
                else
                  @connection_uri = Builtins.sformat(
                    "socket://%1:%2",
                    URIpercentEncoding(@tcp_hostname),
                    URIpercentEncoding(@tcp_port)
                  )
                end
              else
                @connection_uri = Builtins.sformat(
                  "socket://%1",
                  URIpercentEncoding(@tcp_hostname)
                )
              end
              valid = true
            else
              Popup.Error(_("Servername could not be empty."))
            end
          when :lpd, :lpr
            @lpd_hostname = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            if !Builtins.issubstring(@lpd_hostname, "@")
              # when it contains a '@' because a lpd URI can be of the form
              #   lpd://username@ip-address-or-hostname/...
              # see https://bugzilla.novell.com/show_bug.cgi?id=512549
              @lpd_hostname = URIpercentEncoding(@lpd_hostname)
            end
            @lpd_queue = Convert.to_string(
              UI.QueryWidget(:port_or_queue, :Value)
            )
            @lpd_uri_options = Convert.to_string(
              UI.QueryWidget(:uri_options, :Value)
            )
            if "" != Builtins.filterchars(@lpd_hostname, Printer.alnum_chars) &&
                "" != Builtins.filterchars(@lpd_queue, Printer.alnum_chars)
              if "" !=
                  Builtins.filterchars(@lpd_uri_options, Printer.alnum_chars)
                # because special URI characters like '=' or '&' in lpd_uri_options
                # must stay as is and not be percent encoded because lpd_uri_options
                # contains all options like 'option1=value1&option2=value2'.
                @connection_uri = Builtins.sformat(
                  "lpd://%1/%2?%3",
                  @lpd_hostname,
                  URIpercentEncoding(@lpd_queue),
                  @lpd_uri_options
                )
              else
                @connection_uri = Builtins.sformat(
                  "lpd://%1/%2",
                  @lpd_hostname,
                  URIpercentEncoding(@lpd_queue)
                )
              end
              valid = true
            else
              Popup.Error(_("Servername and queue name could not be empty."))
            end
          when :cups
            @cups_hostname = Convert.to_string(
              UI.QueryWidget(:hostname, :Value)
            )
            if !Builtins.issubstring(@cups_hostname, "@")
              # when it contains a '@' because a ipp/http URI can be of the form
              #   ipp://username:password@ip-address-or-hostname/...
              #   http://username:password@ip-address-or-hostname/...
              # see https://bugzilla.novell.com/show_bug.cgi?id=512549
              @cups_hostname = URIpercentEncoding(@cups_hostname)
            end
            @cups_queue = Convert.to_string(UI.QueryWidget(:queue, :Value))
            @cups_uri_options = Convert.to_string(
              UI.QueryWidget(:uri_options, :Value)
            )
            if "" != Builtins.filterchars(@cups_hostname, Printer.alnum_chars) &&
                "" != Builtins.filterchars(@cups_queue, Printer.alnum_chars)
              if "" !=
                  Builtins.filterchars(@cups_uri_options, Printer.alnum_chars)
                # because special URI characters like '=' or '&' in cups_uri_options
                # must stay as is and not be percent encoded because cups_uri_options
                # contains all options like 'option1=value1&option2=value2'.
                @connection_uri = Builtins.sformat(
                  "ipp://%1/printers/%2?%3",
                  @cups_hostname,
                  URIpercentEncoding(@cups_queue),
                  @cups_uri_options
                )
              else
                @connection_uri = Builtins.sformat(
                  "ipp://%1/printers/%2",
                  @cups_hostname,
                  URIpercentEncoding(@cups_queue)
                )
              end
              valid = true
            else
              Popup.Error(_("Servername and queue name could not be empty."))
            end
          when :ipx
            @ipx_hostname = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            @ipx_queue = Convert.to_string(UI.QueryWidget(:queue, :Value))
            @ipx_user = Convert.to_string(UI.QueryWidget(:user, :Value))
            @ipx_pass = Convert.to_string(UI.QueryWidget(:pass, :Value))
            if "" != Builtins.filterchars(@ipx_hostname, Printer.alnum_chars) &&
                "" != Builtins.filterchars(@ipx_queue, Printer.alnum_chars)
              @connection_uri = "novell://"
              if "" != Builtins.filterchars(@ipx_user, Printer.alnum_chars) &&
                  Ops.greater_than(Builtins.size(@ipx_pass), 0)
                @connection_uri = Builtins.sformat(
                  "%1%2:%3@",
                  @connection_uri,
                  @ipx_user,
                  @ipx_pass
                )
              end
              @connection_uri = Builtins.sformat(
                "%1%2/%3",
                @connection_uri,
                @ipx_hostname,
                @ipx_queue
              )
              valid = true
            else
              Popup.Error(_("Servername and queue name could not be empty."))
            end
          when :beh
            @beh_original_uri = Convert.to_string(
              UI.QueryWidget(:beh_original_uri, :Value)
            )
            @beh_do_not_disable = Convert.to_boolean(
              UI.QueryWidget(:beh_do_not_disable, :Value)
            )
            @beh_attempts = Convert.to_string(
              UI.QueryWidget(:beh_attempts, :Value)
            )
            @beh_delay = Convert.to_string(UI.QueryWidget(:beh_delay, :Value))
            if "" !=
                Builtins.filterchars(@beh_original_uri, Printer.alnum_chars) &&
                "" != Builtins.filterchars(@beh_attempts, Printer.alnum_chars) &&
                "" != Builtins.filterchars(@beh_delay, Printer.alnum_chars)
              @connection_uri = Builtins.sformat(
                "beh:/%1/%2/%3/%4",
                @beh_do_not_disable ? "1" : "0",
                @beh_attempts,
                @beh_delay,
                @beh_original_uri
              )
              valid = true
            else
              Popup.Error(
                _(
                  "Device URI, number of retries, and delay could not be empty."
                )
              )
            end
          when :pipe
            @pipe = Convert.to_string(UI.QueryWidget(:program, :Value))
            if "" != Builtins.filterchars(@pipe, Printer.alnum_chars)
              # because special URI characters like '/ ? = &' in pipe
              # must stay as is and not be percent encoded because pipe
              # contains all like 'path/to/command?option1=value1&option2=value2'
              @connection_uri = Builtins.sformat("pipe:/%1", @pipe)
              valid = true
            else
              Popup.Error(_("Could not be empty."))
            end
          else
            Builtins.y2warning(
              "validateAndMakeURI unknown selected value: '%1'",
              selected
            )
        end
        @connection_uri = "" if !valid
        valid
      end

      validateModel = lambda do |selected|
        case selected
          when :hplip, :parallel, :usb

          when :beh, :bluetooth, :cups, :ipp, :ipx, :lpd, :lpr, :pipe, :serial, :smb, :tcp, :uri
            @connection_model = Convert.to_string(
              UI.QueryWidget(Id("manufacturers_combo_box"), :Value)
            )
            if "" == @connection_model
              # Do not change or translate "raw", it is a technical term
              # when no driver is used for a print queue.
              Popup.Error(_("Select a manufacturer or 'raw queue'."))
              return false
            end
          else
            Builtins.y2warning(
              "validateModel unknown selected value: '%1'",
              selected
            )
        end
        true
      end

      scanForServers = lambda do |selected, all|
        hosts = []
        current_host = Convert.to_string(UI.QueryWidget(:hostname, :Value))
        if all
          Builtins.y2milestone("scanForServers 'all'")
          Popup.ShowFeedback(
            _("Look up all hosts in the local network"),
            # Body of a Popup::ShowFeedback:
            _("Please wait...\nThis could take more than a minute.")
          )
          hosts = Convert.convert(
            SCR.Read(path(".net.hostnames")),
            :from => "any",
            :to   => "list <string>"
          )
          # Sleep half a second to let the user notice the Popup::ShowFeedback in any case
          # before it is removed even when the above SCR::Read finished immediately:
          Builtins.sleep(500)
          Popup.ClearFeedback
        else
          Builtins.y2milestone("scanForServers selected = '%1'", selected)
          case selected
            when :tcp
              @port = Convert.to_string(UI.QueryWidget(:port_or_queue, :Value))
              if "" == @port
                @port = "9100"
                UI.ChangeWidget(:port_or_queue, :Value, "9100")
              end
              Popup.ShowFeedback(
                # where %1 will be replaced by the port number:
                Builtins.sformat(
                  _("Scan for hosts which are accessible via TCP port %1"),
                  @port
                ),
                # Body of a Popup::ShowFeedback:
                _("Please wait...\nThis could take more than a minute.")
              )
              hosts = Convert.convert(
                SCR.Read(path(".net.hostnames"), Builtins.tointeger(@port)),
                :from => "any",
                :to   => "list <string>"
              )
              # Sleep half a second to let the user notice the Popup::ShowFeedback in any case
              # before it is removed even when the above SCR::Read finished immediately:
              Builtins.sleep(500)
              Popup.ClearFeedback
            when :smb
              Popup.ShowFeedback(
                _("Scan for hosts which are accessible via Samba (SMB)"),
                # Body of a Popup::ShowFeedback:
                _("Please wait...\nThis could take more than a minute.")
              )
              hosts = Convert.convert(
                SCR.Read(path(".net.hostnames.samba")),
                :from => "any",
                :to   => "list <string>"
              )
              # Sleep half a second to let the user notice the Popup::ShowFeedback in any case
              # before it is removed even when the above SCR::Read finished immediately:
              Builtins.sleep(500)
              Popup.ClearFeedback
            when :lpd, :lpr
              Popup.ShowFeedback(
                _("Scan for hosts which are accessible via port 515 (LPD/LPR)"),
                # Body of a Popup::ShowFeedback:
                _("Please wait...\nThis could take more than a minute.")
              )
              hosts = Convert.convert(
                SCR.Read(path(".net.hostnames"), 515),
                :from => "any",
                :to   => "list <string>"
              )
              # Sleep half a second to let the user notice the Popup::ShowFeedback in any case
              # before it is removed even when the above SCR::Read finished immediately:
              Builtins.sleep(500)
              Popup.ClearFeedback
            when :cups, :ipp
              Popup.ShowFeedback(
                _("Scan for hosts which are accessible via port 631 (CUPS/IPP)"),
                # Body of a Popup::ShowFeedback:
                _("Please wait...\nThis could take more than a minute.")
              )
              hosts = Convert.convert(
                SCR.Read(path(".net.hostnames"), 631),
                :from => "any",
                :to   => "list <string>"
              )
              #             hosts = (list<string>)filter (string h, hosts, ``{
              #                 list queues = (list<string>)SCR::Read (.cups.remote, h);
              #                 return size (queues) > 0;
              #             });
              # Sleep half a second to let the user notice the Popup::ShowFeedback in any case
              # before it is removed even when the above SCR::Read finished immediately:
              Builtins.sleep(500)
              Popup.ClearFeedback
            else
              Builtins.y2warning(
                "scanForServers unknown selected value: '%1'",
                selected
              )
          end
        end
        Builtins.y2milestone("scanForServers hosts = '%1'", hosts)
        if Ops.less_than(Builtins.size(hosts), 1)
          Popup.Message(
            _(
              "Scanning in the network did not find any host.\n(Network issue or firewall active?)"
            )
          )
          hosts = [current_host]
        end
        if !Builtins.contains(hosts, current_host)
          hosts = Builtins.prepend(hosts, current_host)
        end
        UI.ChangeWidget(:hostname, :Items, hosts)
        UI.ChangeWidget(:hostname, :Value, current_host)

        nil
      end

      testQueue = lambda do |selected|
        test_command = ""
        timeout = "5"
        host = ""
        port = ""
        queue = ""
        workgroup = ""
        user = ""
        password = ""
        case selected
          when :tcp
            host = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            port = Convert.to_string(UI.QueryWidget(:port_or_queue, :Value))
            test_command = Builtins.sformat(
              "%1test_remote_socket \"%2\" \"%3\" %4",
              Printerlib.yast_bin_dir,
              host,
              port,
              timeout
            )
            if !Printerlib.ExecuteBashCommand(test_command)
              Popup.ErrorDetails(
                Builtins.sformat(
                  # where %1 will be replaced by the port number
                  # and %2 will be replaced by the host name:
                  _("Access test failed for port '%1' on host '%2'."),
                  port,
                  host
                ), # Message of a Popup::ErrorDetails
                Ops.add(
                  Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                  Ops.get_string(Printerlib.result, "stdout", "")
                )
              )
              return false
            end
          when :lpd, :lpr
            host = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            queue = Convert.to_string(UI.QueryWidget(:port_or_queue, :Value))
            port = "515"
            test_command = Builtins.sformat(
              "%1test_remote_lpd \"%2\" \"%3\" %4",
              Printerlib.yast_bin_dir,
              host,
              queue,
              timeout
            )
            if !Printerlib.ExecuteBashCommand(test_command)
              Popup.ErrorDetails(
                Builtins.sformat(
                  # where %1 will be replaced by the queue name
                  # and %2 will be replaced by the host name:
                  _("Access test failed for queue '%1' on host '%2'."),
                  queue,
                  host
                ), # Message of a Popup::ErrorDetails
                Ops.add(
                  Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                  Ops.get_string(Printerlib.result, "stdout", "")
                )
              )
              return false
            end
          when :cups
            host = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            queue = Convert.to_string(UI.QueryWidget(:queue, :Value))
            test_command = Builtins.sformat(
              "%1test_remote_ipp \"%2\" \"%3\" %4",
              Printerlib.yast_bin_dir,
              host,
              queue,
              timeout
            )
            if !Printerlib.ExecuteBashCommand(test_command)
              Popup.ErrorDetails(
                Builtins.sformat(
                  # where %1 will be replaced by the queue name
                  # and %2 will be replaced by the host name:
                  _("Access test failed for queue '%1' on host '%2'."),
                  queue,
                  host
                ), # Message of a Popup::ErrorDetails
                Ops.add(
                  Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                  Ops.get_string(Printerlib.result, "stdout", "")
                )
              )
              return false
            end
          when :smb
            @active_directory = Convert.to_boolean(
              UI.QueryWidget(:active_directory_check_box, :Value)
            )
            if @active_directory
              if !Popup.ContinueCancel(
                  # because there is authentication via Active Directory (R) required:
                  _(
                    "This is only a generic test which may untruly report failures\n" +
                      "if authentication via Active Directory (R) is required.\n" +
                      "In this case a user who is allowed to print via Active Directory (R)\n" +
                      "should log in and test by himself if he can print from Gnome or KDE."
                  )
                )
                return true
              end
            end
            host = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            queue = Convert.to_string(UI.QueryWidget(:printer, :Value))
            workgroup = Convert.to_string(UI.QueryWidget(:domain, :Value))
            user = Convert.to_string(UI.QueryWidget(:user, :Value))
            password = Convert.to_string(UI.QueryWidget(:pass, :Value))
            test_command = Builtins.sformat(
              "%1test_remote_smb \"%2\" \"%3\" \"%4\" \"%5\" \"%6\" %7",
              Printerlib.yast_bin_dir,
              workgroup,
              host,
              queue,
              user,
              password,
              timeout
            )
            if !Printerlib.ExecuteBashCommand(test_command)
              if @active_directory
                Popup.ErrorDetails(
                  Builtins.sformat(
                    # where %1 will be replaced by the SMB share name
                    # and %2 will be replaced by the host name:
                    _(
                      "The generic test reports failures for share '%1' on host '%2'."
                    ),
                    queue,
                    host
                  ), # Message of a Popup::ErrorDetails
                  Ops.add(
                    Ops.add(
                      Ops.get_string(Printerlib.result, "stderr", ""),
                      "\n"
                    ),
                    Ops.get_string(Printerlib.result, "stdout", "")
                  )
                )
                return true
              end
              Popup.ErrorDetails(
                Builtins.sformat(
                  # where %1 will be replaced by the SMB share name
                  # and %2 will be replaced by the host name:
                  _("Access test failed for share '%1' on host '%2'."),
                  queue,
                  host
                ), # Message of a Popup::ErrorDetails
                Ops.add(
                  Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                  Ops.get_string(Printerlib.result, "stdout", "")
                )
              )
              return false
            end
          when :ipx
            host = Convert.to_string(UI.QueryWidget(:hostname, :Value))
            queue = Convert.to_string(UI.QueryWidget(:queue, :Value))
            user = Convert.to_string(UI.QueryWidget(:user, :Value))
            password = Convert.to_string(UI.QueryWidget(:pass, :Value))
            test_command = Builtins.sformat(
              "%1test_remote_novell \"%2\" \"%3\" \"%4\" \"%5\" %6",
              Printerlib.yast_bin_dir,
              host,
              queue,
              user,
              password,
              timeout
            )
            if !Printerlib.ExecuteBashCommand(test_command)
              Popup.ErrorDetails(
                Builtins.sformat(
                  # where %1 will be replaced by the queue name
                  # and %2 will be replaced by the host name:
                  _("Access test failed for queue '%1' on host '%2'."),
                  queue,
                  host
                ), # Message of a Popup::ErrorDetails
                Ops.add(
                  Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                  Ops.get_string(Printerlib.result, "stdout", "")
                )
              )
              return false
            end
        end
        Popup.Message(_("Test OK"))
        true
      end

      _UpdateConnectionsList = lambda do |selected|
        return false if "" == @connection_uri
        @connection_model = "Unknown" if "" == @connection_model
        # Avoid duplicate URIs because Printer::current_device_uri must point to a unique URI
        # otherwise preselection in BasicAddDialog and BasicModifyDialog would be ambiguous.
        # If an URI already exists, update its matching entry in the Printer::connections list.
        # Usually there should not exist duplicate URIs in the Printer::connections list
        # (in contrast duplicate URIs in the Printer::queues list are perfectly o.k.)
        # but if duplicate URIs exist in Printer::connections, all those entries are updated.
        uri_already_exists = false
        # I do not know if it is allowed to modify one same list "in place" via foreach like:
        #   list < string > words = [ "Jane", "World", "John" ];
        #   integer index = -1;
        #   foreach( string word,
        #            words,
        #            { index = index + 1;
        #              if( "World" == word )
        #              { words[index] = "Hello " + word;
        #              }
        #            }
        #          );
        # so that in any case the result words == [ "Jane", "Hello World", "John" ]
        # and therefore I prefer to be on the safe side with maplist
        # which might consume unnecessarily much memory and CPU
        # (maplist has two lists and all elements are at least copied
        #  instead of "in place" modification only where needed via foreach)
        # but for my small lists this does actually not matter:
        Printer.connections = Builtins.maplist(Printer.connections) do |connection_entry|
          if @connection_uri == Ops.get(connection_entry, "uri", "")
            uri_already_exists = true
            Builtins.y2internal(
              "UpdateConnectionsList: modify connections list type '%1' with uri '%2' for model '%3'",
              selected,
              @connection_uri,
              @connection_model
            )
            next {
              "uri"      => @connection_uri,
              "model"    => @connection_model,
              "deviceID" => "",
              "info"     => "modified by the connection wizard",
              "class"    => "ConnectionWizardDialog"
            }
          else
            next deep_copy(connection_entry)
          end
        end
        if !uri_already_exists
          Builtins.y2internal(
            "UpdateConnectionsList: adding connection type '%1' with uri '%2' for model '%3'",
            selected,
            @connection_uri,
            @connection_model
          )
          Printer.connections = Builtins.add(
            Printer.connections,
            {
              "uri"      => @connection_uri,
              "model"    => @connection_model,
              "deviceID" => "",
              "info"     => "created by the connection wizard",
              "class"    => "ConnectionWizardDialog"
            }
          )
        end
        # Set Printer::current_device_uri so that BasicAddDialog and BasicModifyDialog
        # can preselect the currently used connection when calling Printer::ConnectionItems(...)
        # which sets Printer::selected_connections_index if it matches to Printer::current_device_uri.
        # It makes sense to have the currently used connection from the ConnectionWizardDialog
        # preselected also in BasicModifyDialog because when the user launched the Connection Wizard
        # from the BasicModifyDialog he wants to change the connection so that it is sufficiently safe
        # to have the changed connection preselected when he is back in the BasicModifyDialog
        # so that the connection would get changed in the system without explicite selection
        # by the user in the BasicModifyDialog if the user clicks "OK" in the BasicModifyDialog.
        Printer.current_device_uri = @connection_uri
        true
      end

      #UI::OpenDialog(content);
      ret = nil
      while ret != :back && ret != :next
        ret = UI.UserInput
        selected = Convert.to_symbol(UI.QueryWidget(:tree_selection, :Value))
        Builtins.y2milestone(
          "ConnectionWizardDialog selected = '%1', ret = '%2'",
          selected,
          ret
        )
        case Convert.to_symbol(ret)
          when :tree_selection
            changeSettingsDialog(selected)
          when :next
            if validateAndMakeURI.call(selected) && validateModel.call(selected)
              Builtins.y2milestone("ConnectionWizardDialog writing settings")
              _UpdateConnectionsList.call(selected)
            else
              Builtins.y2error(
                "ConnectionWizardDialog: Could not validate for '%1'",
                selected
              )
              ret = nil
            end
          when :scan_all
            scanForServers.call(selected, true)
          when :scan
            scanForServers.call(selected, false)
          when :test
            testQueue.call(selected) if validateAndMakeURI.call(selected)
          when :active_directory_check_box
            # Be backward compatible for openSUSE < 11.3 and be prepared for /usr/lib64/cups/
            Printerlib.ExecuteBashCommand(
              "ls -1 /usr/lib*/cups/backend/smb | head -n1 | tr -d '[:space:]'"
            )
            @smb_backend_link_name = Ops.get_string(
              Printerlib.result,
              "stdout",
              ""
            )
            # Without a link name /usr/lib[64]/cups/backend/smb (which is provided by samba-client)
            # the rest makes no sense (in particular the ln commands would create nonsense links in $PWD):
            if "" == @smb_backend_link_name
              UI.ChangeWidget(Id(:active_directory_check_box), :Value, false)
              UI.ChangeWidget(Id(:active_directory_check_box), :Enabled, false)
            else
              smb_backend_link_target_commandline = + "readlink " + @smb_backend_link_name.shellescape + " | tr -d '[:space:]'"
              if Convert.to_boolean(
                  UI.QueryWidget(Id(:active_directory_check_box), :Value)
                )
                if !Printerlib.TestAndInstallPackage(
                    "samba-krb-printing",
                    "installed"
                  )
                  if Popup.ContinueCancel(
                      _(
                        "To support Active Directory (R), the RPM package samba-krb-printing must be installed."
                      )
                    )
                    Printerlib.TestAndInstallPackage(
                      "samba-krb-printing",
                      "install"
                    )
                    # There is no "abort" functionality which does a sudden death of the whole module (see dialogs.ycp).
                    # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
                    # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
                    # so that this leftover "abort" button must be explicitly hidden here:
                    Wizard.HideAbortButton
                  end
                end
                # The user can also decide during the actual installation not to install it
                # or the installation may have failed for whatever reason
                # so that we test again whether or not it is now actually installed:
                if Printerlib.TestAndInstallPackage(
                    "samba-krb-printing",
                    "installed"
                  )
                  # or if samba-krb-printing is installed since a longer time
                  # make sure that the symbolic link /usr/lib[64]/cups/backend/smb
                  # points to /usr/bin/get_printing_ticket:
                  Printerlib.ExecuteBashCommand(
                    "ln -sf /usr/bin/get_printing_ticket " + @smb_backend_link_name.shellescape
                  )
                end
              else
                Printerlib.ExecuteBashCommand(
                  smb_backend_link_target_commandline
                )
                if "/usr/bin/get_printing_ticket" ==
                    Ops.get_string(Printerlib.result, "stdout", "")
                  # Show a user notification before it gets disabled:
                  Popup.Warning(
                    _(
                      "Active Directory (R) support will be disabled for all SMB print queues."
                    )
                  )
                end
                # Regardless if samba-krb-printing is installed or not,
                # only let the symbolic link /usr/lib[64]/cups/backend/smb
                # point to its traditional target /usr/bin/smbspool (provided by samba-client):
                Printerlib.ExecuteBashCommand(
                  "ln -sf /usr/bin/smbspool " + @smb_backend_link_name.shellescape
                )
              end
              # Detremine and set the actually right state of the active_directory_check_box:
              # Only if the /usr/lib[64]/cups/backend/smb link points to /usr/bin/get_printing_ticket
              # there is support for Active Directory (R) for SMB print queues.
              Printerlib.ExecuteBashCommand(smb_backend_link_target_commandline)
              if "/usr/bin/get_printing_ticket" ==
                  Ops.get_string(Printerlib.result, "stdout", "")
                UI.ChangeWidget(Id(:active_directory_check_box), :Value, true)
              else
                UI.ChangeWidget(Id(:active_directory_check_box), :Value, false)
              end
            end
          else
            Builtins.y2milestone("Ignoring unexpected ret = '%1'", ret)
        end
      end
      # ret == `back || ret == `next
      deep_copy(ret) 
      #UI::CloseDialog();
    end
  end
end

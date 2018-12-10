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

# File:        include/printer/basicmodify.ycp
# Package:     Configuration of printer
# Summary:     Basic modify dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>

require "shellwords"

module Yast
  module PrinterBasicmodifyInclude
    def initialize_printer_basicmodify(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Popup"

      Yast.include include_target, "printer/helps.rb"
    end

    # BasicModifyDialog dialog
    # @return dialog result
    def BasicModifyDialog
      Builtins.y2milestone(
        "entering BasicModifyDialog for queue '%1'",
        Ops.get(Printer.queues, Printer.selected_queues_index, {})
      )
      any_model_driver_filter_input_text = _("any model")
      non_matching_fallback_driver_filter_string = "qqqqqqqqqq"
      commandline = ""
      name = Ops.get(
        Printer.queues,
        [Printer.selected_queues_index, "name"],
        ""
      )
      uri = Ops.get(Printer.queues, [Printer.selected_queues_index, "uri"], "")
      description = Ops.get(
        Printer.queues,
        [Printer.selected_queues_index, "description"],
        ""
      )
      location = Ops.get(
        Printer.queues,
        [Printer.selected_queues_index, "location"],
        ""
      )
      ppd = Ops.get(Printer.queues, [Printer.selected_queues_index, "ppd"], "")
      is_default = false
      if "yes" ==
          Ops.get(
            Printer.queues,
            [Printer.selected_queues_index, "default"],
            ""
          )
        is_default = true
      end
      accepting_jobs = true
      if "yes" ==
          Ops.get(
            Printer.queues,
            [Printer.selected_queues_index, "rejecting"],
            ""
          )
        accepting_jobs = false
      end
      printing_enabled = true
      if "yes" ==
          Ops.get(
            Printer.queues,
            [Printer.selected_queues_index, "disabled"],
            ""
          )
        printing_enabled = false
      end
      # Title of the Basic Modify Dialog where %1 will be replaced by the queue name.
      # The actual queue name is a system value which cannot be translated:
      caption = Builtins.sformat(_("Modify %1"), name)
      # Clear whatever content of a previous dialog which would show up here for several seconds
      # until all the following stuff is done before Wizard::SetContentsButtons is called
      # which finally shows the right content for this dialog.
      Wizard.SetContents(
        caption,
        Empty(),
        Ops.get_string(@HELPS, "basic_modify_dialog", ""),
        false,
        false
      )
      Wizard.HideAbortButton
      model = Printer.DeriveModelName(description, 0)
      driver_filter_input_text = Printer.DeriveModelName(model, 0)
      driver_filter_string = Printer.DeriveDriverFilterString(
        driver_filter_input_text
      )
      nick_name = ""
      driver_options_content = Empty()
      paper_choice_content = Empty()
      a4_paper_choice = false
      a4_default_paper = false
      a4_paper_choice_radio_button = RadioButton(Id(:a4), Opt(:disabled), "A&4")
      letter_paper_choice = false
      letter_default_paper = false
      letter_paper_choice_radio_button = RadioButton(
        Id(:letter),
        Opt(:disabled),
        "Le&tter"
      )
      default_paper_size = ""
      # Only local queues can be selected in the overview dialog to be modified.
      # For a local raw queue ppd is the empty string.
      # For a local queue with a System V style interface script ppd is "/etc/cups/interfaces/<name-of-the-script>".
      # For a local queue with URI "ipp://server/printers/queue" ppd is "ipp://server/printers/queue.ppd".
      # For a normal local queue with URI "ipp://server/resource" ppd is "/etc/cups/ppd/<queue-name>.ppd".
      # For a normal local queue ppd is "/etc/cups/ppd/<queue-name>.ppd".
      # The leading part "/etc/" may vary depending on how the local cupsd
      # is installed or configured, see "/usr/bin/cups-config --serverroot".
      if "" != ppd
        commandline = "test -r " + ppd.shellescape
        if Printerlib.ExecuteBashCommand(commandline)
          driver_options_content = PushButton(
            Id(:driver_options),
            # Label of a PushButton to go to a dialog
            # to set all available options for the printer driver
            # which is currently used for a print queue:
            _("All &Options for the Current Driver")
          )
        else
          ppd = ""
        end
      end
      if Builtins.issubstring(ppd, "/cups/ppd/")
        # which suppresses it in certain "lpinfo -m" output.
        # Note the YCP quoting: \" becomes " and \\n becomes \n in the commandline.
        commandline = "grep '^*NickName' " + ppd.shellescape
        commandline += " | cut -s -d '\"' -f2 | sed -e 's/(recommended)//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s ' ' | tr -d '\\n'"
        if Printerlib.ExecuteBashCommand(commandline)
          Builtins.y2milestone(
            "'%1' stdout (nick_name) is: '%2'",
            commandline,
            Ops.get_string(Printerlib.result, "stdout", "")
          )
          nick_name = Ops.get_string(Printerlib.result, "stdout", "")
          driver_filter_input_text = Printer.DeriveModelName(nick_name, 0)
          driver_filter_string = Printer.DeriveDriverFilterString(
            driver_filter_input_text
          )
        end
        if !Printer.DetermineDriverOptions("")
          # (e.g. the driver options from another previously modified queue):
          Printer.driver_options = []
        end
        Builtins.foreach(Printer.driver_options) do |driver_option|
          if "PageSize" == Ops.get_string(driver_option, "keyword", "")
            Builtins.foreach(Ops.get_list(driver_option, "values", [])) do |value|
              if "*A4" == value
                default_paper_size = "A4"
                a4_default_paper = true
                a4_paper_choice_radio_button = RadioButton(Id(:a4), "A&4", true)
              else
                if "A4" == value
                  a4_paper_choice = true
                  a4_paper_choice_radio_button = RadioButton(Id(:a4), "A&4")
                else
                  if "*Letter" == value
                    default_paper_size = "Letter"
                    letter_default_paper = true
                    letter_paper_choice_radio_button = RadioButton(
                      Id(:letter),
                      "Le&tter",
                      true
                    )
                  else
                    if "Letter" == value
                      letter_paper_choice = true
                      letter_paper_choice_radio_button = RadioButton(
                        Id(:letter),
                        "Le&tter"
                      )
                    else
                      if "*" == Builtins.substring(value, 0, 1)
                        default_paper_size = Builtins.substring(value, 1)
                      end
                    end
                  end
                end
              end
            end 

            Builtins.y2milestone(
              "Default paper size is: '%1'",
              default_paper_size
            )
          end
        end
      end
      # DefaultPageSize is required according to the Adobe PPD specification.
      # Nevertheless we don't rely on correct PPDs (e.g. whatever "third-party" PPDs)
      # and test if it really exists in the actually used PPD:
      if "" != default_paper_size
        default_paper_size_label = _("Default Paper Size of the Current Driver")
        if a4_default_paper || letter_default_paper
          paper_choice_content = RadioButtonGroup(
            Id(:paper_size_radio_buttons),
            HBox(
              Label(default_paper_size_label),
              HSpacing(2),
              a4_paper_choice_radio_button,
              HSpacing(1),
              letter_paper_choice_radio_button
            )
          )
        else
          if a4_paper_choice || letter_paper_choice
            paper_choice_content = RadioButtonGroup(
              Id(:paper_size_radio_buttons),
              HBox(
                Label(
                  Ops.add(
                    Ops.add(
                      Ops.add(default_paper_size_label, ": "),
                      default_paper_size
                    ),
                    " "
                  )
                ),
                HSpacing(2),
                a4_paper_choice_radio_button,
                HSpacing(1),
                letter_paper_choice_radio_button
              )
            )
          else
            paper_choice_content = Label(
              Ops.add(
                Ops.add(default_paper_size_label, ": "),
                default_paper_size
              )
            )
          end
        end
      end
      # If the currently used driver is replaced by another driver,
      # show the same content as in the BasicAddDialog to set the default paper size:
      new_driver_paper_choice_content = RadioButtonGroup(
        Id(:paper_size_radio_buttons),
        HBox(
          Label(_("Default paper size (if printer and driver supports it)")), # Label of a RadioButtonGroup to specify the default paper size:
          # Have none of the RadioButtons preselected which means that
          # by default the CUPS default is used for the default paper size.
          # For the CUPS 1.3 default see http://www.cups.org/str.php?L2846
          # For CUPS 1.4 the default depends on the "DefaultPaperSize"
          # setting in cupsd.conf
          # see https://bugzilla.novell.com/show_bug.cgi?id=395760
          # and http://www.cups.org/str.php?L2848
          HSpacing(2),
          RadioButton(Id(:a4), "A&4"),
          HSpacing(1),
          RadioButton(Id(:letter), "Le&tter"),
          HStretch()
        )
      )
      # Usually the id in the connection items is the matching index number in the connections list.
      # Here the id of the current connection is set to -1 because the uri of the current connection
      # is derived from the queues list and this uri may be not present in the connections list
      # for example when the queue has a special non-autodetectable DeviceURI (e.g. for iPrint)
      # or when the queue is for an USB printer which is currently not connected (e.g. a laptop user).
      # Therefore -1 (which means "invalid index number in the connections list") is used to be safe
      # and additionally -1 is used to distinguish when the current connection is kept
      # or when the connection was modified (then the id would be > 0 and valid in the connections list).
      # The current_connection item is preselected because it is the first entry in the
      # table of connections via prepend():
      current_connection = Item(
        Id(-1),
        _("Current Connection") + ": ",
        Ops.add(uri, " "),
        description
      )
      # Usually the id in the driver items is the matching index number in the ppds list.
      # Here the id of the current driver is set to -1 because the ppd for the current driver
      # is derived from the queues list and this ppd may be not present in the ppds list
      # for example when the queue has a ppd which is not in /usr/share/cups/model/ (e.g. a manually set up queue)
      # or when the ppd for the queue in /etc/cups/ppd/ was modified (e.g. different default option settings).
      # Therefore -1 (which means "invalid index number in the ppds list") is used to be safe
      # and additionally -1 is used to distinguish when the current driver is kept
      # or when the driver was modified (then the id would be > 0 and valid in the ppds list).
      # Furthermore the current_driver item is preselected via the additional "true".
      current_driver = Item(
        Id(-1),
        # Do not change or translate "raw", it is a technical term when no driver is used.
        # Do not change or translate "System V style interface script", it is a technical term.
        _(
          "No driver is used (it is a 'raw' queue or a 'System V style interface script' is used)"
        ),
        true
      )
      if "" != nick_name
        current_driver = Item(
          Id(-1),
          Ops.add(_("Current Driver") + ": ", nick_name),
          true
        )
      end
      if "" == driver_filter_string
        # to avoid that the full list of thousands of PPDs is shown automatically
        # because it can take a very long time until the user can proceed:
        driver_filter_input_text = _("Enter your printer model here.")
        driver_filter_string = non_matching_fallback_driver_filter_string
      end
      contents = VBox(
        VBox(
          HBox(
            Label(_("Connection")), # Caption for a Table with a list of printer connections:
            HStretch(),
            PushButton(
              Id(:more_connections),
              # Label of a PushButton to restart printer autodetection
              # to show more available printer connections
              # in the Table with a list of printer connections:
              _("&Detect More")
            ),
            PushButton(
              Id(:connection_wizard),
              # Label of a PushButton to go to the "Connection Wizard"
              # to specify the printer connection individually:
              _("Connection &Wizard")
            )
          ),
          ReplacePoint(
            Id(:connection_selection_replace_point),
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
              Builtins.prepend(
                Printer.ConnectionItems("BasicAddDialog"),
                current_connection
              )
            )
          )
        ),
        VStretch(),
        VBox(
          Left(
            Label(
              _(
                "Adjust Options of the Current Driver or Assign a Different Driver"
              )
            ) # Caption for a printer driver selection:
          ),
          ReplacePoint(
            Id(:paper_choice_and_driver_options_replace_point),
            VBox(Left(paper_choice_content), Left(driver_options_content))
          ),
          HBox(
            ReplacePoint(
              Id(:apply_driver_filter_replace_point),
              PushButton(
                Id(:apply_driver_filter),
                # This button must be the default
                # (it is activated when the user pressed the Enter key)
                # because when the user has clicked into InputField to enter something
                # it is normal to finish entering by pressing the Enter key
                # but if the Enter key was linked to 'Next' or 'Back',
                # the user would get the wrong action.
                Opt(:default),
                # Label of a PushButton to search a list for a search string
                # and then show the search result:
                _("&Search for")
              )
            ),
            ReplacePoint(
              Id(:driver_filter_input_replace_point),
              InputField(
                Id(:driver_filter_input),
                Opt(:hstretch),
                # No InputField header because there is the "Caption for a printer driver selection":
                "",
                # Make it lowercase to make it more obvious that this is a search string
                # which the user could change as needed and not a final fixed model name.
                # Many users do not understand that the model name which is preset here
                # (i.e. initially for this dialog and when the user selected a connection)
                # as search string can be changed by the user as needed to find drivers.
                Builtins.tolower(driver_filter_input_text)
              )
            ),
            PushButton(
              Id(:more_drivers),
              # Label of a PushButton to find and show more available printer drivers:
              _("&Find More")
            ),
            PushButton(
              Id(:add_driver),
              # Label of a PushButton to go to the "Add Driver" dialog
              # to install or remove driver packages (and perhaps download it before):
              _("Driver &Packages")
            )
          ),
          ReplacePoint(
            Id(:driver_selection_replace_point),
            SelectionBox(
              Id(:driver_selection),
              # By default there is no UserInput()
              # if only something was selected in the SelectionBox
              # (without clicking additionally a button)
              # but the notify option forces UserInput() in this case:
              Opt(:notify),
              "",
              Builtins.prepend(
                Printer.DriverItems(driver_filter_string, false),
                current_driver
              )
            )
          )
        ),
        VStretch(),
        VBox(
          HBox(
            TextEntry(
              Id(:description_input),
              Opt(:hstretch),
              # Label of a TextEntry for a short printer driver description (only one line):
              _("Description &Text"),
              description
            ),
            HSpacing(2),
            TextEntry(
              Id(:location_input),
              Opt(:hstretch),
              # Label of a TextEntry for printer location string:
              _("&Location"),
              location
            )
          ),
          Left(
            HBox(
              CheckBox(
                Id(:default_queue_checkbox),
                # CheckBox to set a local print queue to be the default queue:
                _("&Use as Default"),
                is_default
              ),
              HSpacing(2),
              CheckBox(
                Id(:accept_jobs_checkbox),
                # CheckBox to set a local print queue to accept print jobs:
                _("Accept Print &Jobs"),
                accepting_jobs
              ),
              HSpacing(2),
              CheckBox(
                Id(:enable_printing_checkbox),
                # CheckBox to enable printing for a local print queue:
                _("&Enable Printing"),
                printing_enabled
              )
            )
          )
        )
      )
      # According to the YaST Style Guide (dated Thu, 06 Nov 2008)
      # there is no longer a "abort" functionality which exits the whole module.
      # Instead this button is now named "Cancel" and its functionality is
      # to go back to the Overview dialog (i.e. what the "back" button would do)
      # because it reads "Cancel - Closes the window and returns to the overview."
      # Therefore the button with the "abort" functionality is not shown at all
      # and the button with the "back" functionality is named "Cancel".
      # According to the YaST Style Guide (dated Thu, 06 Nov 2008)
      # the "finish" button in a single (step) configuration dialog must now be named "OK".
      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "basic_modify_dialog", ""),
        # Set a new label for the "back" button, see the comment above:
        Label.CancelButton,
        # Set a new label for the "next" button, see the comment above:
        Label.OKButton
      )
      Wizard.HideAbortButton
      # Try to preselect the connection which matches to the current_device_uri
      # if such a connection exists in the connection_selection table:
      if Ops.greater_or_equal(Printer.selected_connections_index, 0)
        # exists in the connection_selection table because the Printer::ConnectionItems function
        # sets Printer::selected_connections_index != -1 only if such an item exists in the table
        # so that this item can be preselected:
        Builtins.y2milestone(
          "Preselected connection: '%1'",
          Ops.get(Printer.connections, Printer.selected_connections_index, {})
        )
        UI.ChangeWidget(
          :connection_selection,
          :CurrentItem,
          Id(Printer.selected_connections_index)
        )
        # In contrast to BasicAddDialog fake user input of a connection_selection here only
        # when a connection was preselected because initially drivers are shown which
        # match to the description of the queue which is to be modified here
        # but when the user had used the Connection Wizard, a different connection
        # becomes usually preselected and this requires different drivers to be shown:
        UI.FakeUserInput(:connection_selection)
      end
      user_input = nil
      while true
        # (the default widget is the result of UI::UserInput when the user pressed the Enter key)
        # regardless whatever function call or UI bug (e.g. bnc#558900) may have changed the default widget:
        UI.ReplaceWidget(
          Id(:apply_driver_filter_replace_point),
          PushButton(
            Id(:apply_driver_filter),
            # This button must be the default
            # (it is activated when the user pressed the Enter key)
            # because when the user has clicked into InputField to enter something
            # it is normal to finish entering by pressing the Enter key
            # but if the Enter key was linked to 'Next' or 'Back',
            # the user would get the wrong action.
            Opt(:default),
            # Label of a PushButton to search a list for a search string
            # and then show the search result:
            _("&Search for")
          )
        )
        if :apply_driver_filter == user_input
          # set the focus to the InputField for the driver search string
          # so that the user can just continue typing other search strings.
          # In contrast when the user is not already searching drivers,
          # it is annoying in particular in the text-only ncurses UI
          # when the focus becomes always set to the driver search string InputField.
          UI.SetFocus(:driver_filter_input)
        end
        # Wait for user input:
        user_input = UI.UserInput
        if :abort == user_input || :cancel == user_input || :back == user_input
          break
        end
        if :next == user_input
          commandline = "/usr/sbin/lpadmin -h localhost -p " + name.shellescape
          something_has_changed = false
          set_paper_size_later = false
          selected_connection_index = Convert.to_integer(
            UI.QueryWidget(Id(:connection_selection), :CurrentItem)
          )
          if Ops.greater_or_equal(selected_connection_index, 0)
            uri = Ops.get(
              Printer.connections,
              [selected_connection_index, "uri"],
              ""
            )
            if "" != uri
              commandline += " -v " + uri.shellescape
              Printer.current_device_uri = uri
              something_has_changed = true
            end
          end
          selected_ppd_index = Convert.to_integer(
            UI.QueryWidget(Id(:driver_selection), :CurrentItem)
          )
          if Ops.greater_or_equal(selected_ppd_index, 0)
            ppd = Ops.get(Printer.ppds, [selected_ppd_index, "ppd"], "")
            if "" != ppd
              commandline += " -m " + ppd.shellescape
              something_has_changed = true
              # The paper size for a new driver will be only set
              # after the new driver was actually successfully set:
              set_paper_size_later = true
            end
          else
            # Depending on the currently used driver no paper size selection might exists
            # in particular not for a 'raw' queue or when a 'System V style interface script' is used:
            if UI.WidgetExists(Id(:paper_size_radio_buttons))
              paper_size = UI.QueryWidget(
                Id(:paper_size_radio_buttons),
                :CurrentButton
              )
              if :a4 == paper_size && "A4" != default_paper_size
                commandline += " -o PageSize=A4"
                something_has_changed = true
              end
              if :letter == paper_size && "Letter" != default_paper_size
                commandline += " -o PageSize=Letter"
                something_has_changed = true
              end
            end
          end
          description_input = Convert.to_string(
            UI.QueryWidget(Id(:description_input), :Value)
          )
          # Delete ' characters because they are used for quoting in the bash commandline:
          description_input = Builtins.deletechars(description_input, "'")
          # Leading and/or trailing and/or sequences of spaces look ugly and are condensed here:
          description_input = Builtins.mergestring(
            Builtins.filter(Builtins.splitstring(description_input, " ")) do |word|
              "" != word
            end,
            " "
          )
          if description_input != description
            commandline += " -D " + description_input.shellescape
            something_has_changed = true
          end
          location_input = Convert.to_string(
            UI.QueryWidget(Id(:location_input), :Value)
          )
          # Delete ' characters because they are used for quoting in the bash commandline:
          location_input = Builtins.deletechars(location_input, "'")
          # Leading and/or trailing and/or sequences of spaces look ugly and are condensed here:
          location_input = Builtins.mergestring(
            Builtins.filter(Builtins.splitstring(location_input, " ")) do |word|
              "" != word
            end,
            " "
          )
          if location_input != location
            commandline += " -L " + location_input.shellescape
            something_has_changed = true
          end
          is_default_input = Convert.to_boolean(
            UI.QueryWidget(Id(:default_queue_checkbox), :Value)
          )
          if is_default_input != is_default
            something_has_changed = true
            if is_default_input
              # with other option settings so that a separate lpadmin command is called:
              commandline += " ; /usr/sbin/lpadmin -h localhost -d " + name.shellescape
            else
              # see http://www.cups.org/newsgroups.php?gcups.general+v:31874
              # All one can do is set up a dummy queue, make it the default, and remove it.
              # To be on the safe side the dummy queue neither accepts jobs
              # nor is printing enabled (no '-E' as last lpadmin option)
              # nor is it announced ("shared") to whatever BrowseAddress in cupsd.conf.
              # Here I assume blindly that no queue "yast2unsetdefaultqueue" exists.
              commandline += " ; /usr/sbin/lpadmin -h localhost -p yast2unsetdefaultqueue -v file:/dev/null -o printer-is-shared=false"
              commandline += " ; /usr/sbin/lpadmin -h localhost -d yast2unsetdefaultqueue"
              commandline += " ; /usr/sbin/lpadmin -h localhost -x yast2unsetdefaultqueue"
            end
          end
          accepting_jobs_input = Convert.to_boolean(
            UI.QueryWidget(Id(:accept_jobs_checkbox), :Value)
          )
          if accepting_jobs_input != accepting_jobs
            something_has_changed = true
            if accepting_jobs_input
              commandline += " ; /usr/sbin/accept -h localhost " + name.shellescape
            else
              commandline += " ; /usr/sbin/reject -h localhost " + name.shellescape
            end
          end
          printing_enabled_input = Convert.to_boolean(
            UI.QueryWidget(Id(:enable_printing_checkbox), :Value)
          )
          if printing_enabled_input != printing_enabled
            something_has_changed = true
            if printing_enabled_input
              commandline += " ; /usr/sbin/cupsenable -h localhost " + name.shellescape
            else
              commandline += " ; /usr/sbin/cupsdisable -h localhost " + name.shellescape
            end
          end
          if something_has_changed
            Wizard.DisableBackButton
            Wizard.DisableNextButton
            if !Printerlib.ExecuteBashCommand(commandline)
              Popup.ErrorDetails(
                # where %1 will be replaced by the queue name.
                # Only a simple message because this error does not happen on a normal system
                # (i.e. a system which is not totally broken or totally messed up).
                Builtins.sformat(_("Failed to modify %1."), name),
                Ops.get_string(Printerlib.result, "stderr", "")
              )
            else
              # after a new driver was actually successfully set.
              if set_paper_size_later
                # in particular not for a 'raw' queue or when a 'System V style interface script' is used.
                # When a driver is set for a 'raw' queue or for a queue with a 'System V style interface script',
                # it is therefore not possible to set the default paper size for the new driver now
                # so that the user would have to run the modify dialog again to do this.
                if UI.WidgetExists(Id(:paper_size_radio_buttons))
                  default_paper_size = ""
                  paper_size = UI.QueryWidget(
                    Id(:paper_size_radio_buttons),
                    :CurrentButton
                  )
                  default_paper_size = "A4" if :a4 == paper_size
                  default_paper_size = "Letter" if :letter == paper_size
                  # Try to set the requested default_paper_size if it is an available choice for this queue.
                  # If no default_paper_size is requested, the CUPS default is used.
                  # For the CUPS 1.3 default see http://www.cups.org/str.php?L2846
                  # For CUPS 1.4 the default depends on the "DefaultPaperSize" setting in cupsd.conf
                  # see https://bugzilla.novell.com/show_bug.cgi?id=395760
                  # and http://www.cups.org/str.php?L2848
                  if "" != default_paper_size
                    # Note the YCP quoting: \\< becomes \< and \\> becomes \> in the commandline.
                    # Note that default_paper_size does not need to be escaped because it is only set to
                    # well-defined values "A4" or "Letter" if paper_size is one of those two.
                    commandline = "lpoptions -h localhost -p " + name.shellescape + " -l"
                    commandline += " | grep '^PageSize.*\\<" + default_paper_size + "\\>'"
                    if Printerlib.ExecuteBashCommand(commandline)
                      commandline = "/usr/sbin/lpadmin -h localhost -p " + name.shellescape
                      commandline += " -o PageSize=" + default_paper_size
                      # Do not care if it fails to set the default_paper_size (i.e. show no error message to the user)
                      # because the default_paper_size setting is nice to have but not mandatoty for a working queue:
                      Printerlib.ExecuteBashCommand(commandline)
                    end
                  end
                end
              end
            end
            # Since CUPS 1.4 the new DirtyCleanInterval directive controls the delay when cupsd updates config files:
            if !Printerlib.WaitForUpdatedConfigFiles(
                _("Modifying Printer Setup")
              )
              Popup.WarningDetails(
                _("Modified Printer Configuration not yet Stored in the System"),
                # Explanation details of a Popup::WarningDetails.
                # The 'next dialog' is the overview dialog where the printer configurations are shown
                # which has a 'Refresh List' button to update the shown printer configurations:
                _(
                  "If the next dialog does not show the expected modifications, wait some time and use the 'Refresh List' button."
                )
              )
            end
            Wizard.EnableBackButton
            Wizard.EnableNextButton
          else
            Builtins.y2milestone("Nothing changed in 'Modify' dialog.")
          end
          # Exit this dialog in any case:
          break
        end
        break if :connection_wizard == user_input
        break if :add_driver == user_input
        if :driver_options == user_input
          if Ops.less_than(Printer.selected_queues_index, 0) ||
              "" ==
                Ops.get(
                  Printer.queues,
                  [Printer.selected_queues_index, "name"],
                  ""
                ) ||
              "remote" ==
                Ops.get(
                  Printer.queues,
                  [Printer.selected_queues_index, "config"],
                  "remote"
                )
            Popup.AnyMessage(
              _("No driver options available"),
              # Body of a Popup::AnyMessage when "Driver Options" was selected:
              _(
                "Possible reasons: Nothing selected or it is a remote configuration."
              )
            )
            next
          end
          # Take a changed paper size setting into account.
          # The Printer::DriverOptionItems call stores the current setting
          # in Printer::driver_options so that it is known the DriverOptionsDialog
          if UI.WidgetExists(Id(:paper_size_radio_buttons))
            paper_size = UI.QueryWidget(
              Id(:paper_size_radio_buttons),
              :CurrentButton
            )
            if :a4 == paper_size && "A4" != default_paper_size
              Printer.DriverOptionItems("PageSize", "A4")
            end
            if :letter == paper_size && "Letter" != default_paper_size
              Printer.DriverOptionItems("PageSize", "Letter")
            end
          end
          # Exit this dialog and go to the DriverOptionsDialog via the sequencer in wizards.ycp:
          break
        end
        if :more_connections == user_input
          UI.ReplaceWidget(
            Id(:connection_selection_replace_point),
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
              Builtins.prepend(
                Printer.ConnectionItems("MoreConnections"),
                current_connection
              )
            )
          )
          # Try to preselect the connection which matches to the current_device_uri
          # if such a connection exists in the connection_selection table:
          if Ops.greater_or_equal(Printer.selected_connections_index, 0)
            # exists in the connection_selection table because the Printer::ConnectionItems function
            # sets Printer::selected_connections_index != -1 only if such an item exists in the table
            # so that this item can be preselected:
            Builtins.y2milestone(
              "Preselected connection: '%1'",
              Ops.get(
                Printer.connections,
                Printer.selected_connections_index,
                {}
              )
            )
            UI.ChangeWidget(
              :connection_selection,
              :CurrentItem,
              Id(Printer.selected_connections_index)
            )
          end
          UI.FakeUserInput(:connection_selection)
          next
        end
        if :connection_selection == user_input
          selected_connection_index = Convert.to_integer(
            UI.QueryWidget(Id(:connection_selection), :CurrentItem)
          )
          if nil == selected_connection_index
            Popup.AnyMessage(
              _("No Connection Selected"),
              # Body of a Popup::AnyMessage when no connection was selected:
              _("Select a connection.")
            )
            next
          end
          # selected_connection_index is -1 for the currently used connection
          # which is an invalid index in the connections list because
          # it means that the connection is not to be exchanged.
          # To be safe that the currently used connection cannot be exchanged
          # Printer::selected_connections_index is set to -1 in this case.
          if selected_connection_index != Printer.selected_connections_index
            Printer.selected_connections_index = selected_connection_index
            Printer.current_device_uri = Ops.get(
              Printer.connections,
              [selected_connection_index, "uri"],
              ""
            )
            Builtins.y2milestone(
              "Selected connection is: %1",
              Ops.get(Printer.connections, selected_connection_index, {})
            )
            # Invalidate any previously selected driver, if a connection is selected anew
            # or if a previously selected connection had changed:
            Printer.selected_ppds_index = -1
          end
          if Ops.greater_or_equal(selected_connection_index, 0)
            # derive the driver_filter_string from the model of the new connection:
            driver_filter_string = ""
            driver_filter_input_text = ""
            model = Ops.get(
              Printer.connections,
              [Printer.selected_connections_index, "model"],
              ""
            )
            Builtins.y2milestone("Drivers for '%1'", model)
            if "" != model && "unknown" != Builtins.tolower(model)
              driver_filter_input_text = Printer.DeriveModelName(model, 0)
              driver_filter_string = Printer.DeriveDriverFilterString(
                driver_filter_input_text
              )
            end
          else
            # derive the driver_filter_string from the NickName of the currently used PPD
            # or derive the driver_filter_string from the description of the currently used connection:
            if "" != nick_name
              driver_filter_input_text = Printer.DeriveModelName(nick_name, 0)
            else
              model = Printer.DeriveModelName(description, 0)
              driver_filter_input_text = Printer.DeriveModelName(model, 0)
            end
            driver_filter_string = Printer.DeriveDriverFilterString(
              driver_filter_input_text
            )
          end
          if "" == driver_filter_string
            # to avoid that the full list of thousands of PPDs is shown automatically
            # because it can take a very long time until the user can proceed:
            driver_filter_input_text = _("Enter your printer model here.")
            driver_filter_string = non_matching_fallback_driver_filter_string
          end
          UI.ReplaceWidget(
            Id(:driver_filter_input_replace_point),
            InputField(
              Id(:driver_filter_input),
              Opt(:hstretch),
              # No InputField header because there is the "Caption for a printer driver selection":
              "",
              # Make it lowercase to make it more obvious that this is a search string
              # which the user could change as needed and not a final fixed model name.
              # Many users do not understand that the model name which is preset here
              # (i.e. initially for this dialog and when the user selected a connection)
              # as search string can be changed by the user as needed to find drivers.
              Builtins.tolower(driver_filter_input_text)
            )
          )
          UI.ReplaceWidget(
            Id(:driver_selection_replace_point),
            SelectionBox(
              Id(:driver_selection),
              # By default there is no UserInput()
              # if only something was selected in the SelectionBox
              # (without clicking additionally a button)
              # but the notify option forces UserInput() in this case:
              Opt(:notify),
              "",
              Builtins.prepend(
                Printer.DriverItems(driver_filter_string, false),
                current_driver
              )
            )
          )
          # Do the same as if user_input == `driver_selection
          # but don't show a popup if nil == selected_ppd_index:
          selected_ppd_index = Convert.to_integer(
            UI.QueryWidget(Id(:driver_selection), :CurrentItem)
          )
          next if nil == selected_ppd_index
          # selected_ppd_index is -1 for the currently used driver
          # which is an invalid index in the ppds list because
          # it means that the driver is not to be exchanged.
          # To be safe that the currently used driver cannot be exchanged
          # Printer::selected_ppds_index is set to -1 in this case.
          if selected_ppd_index != Printer.selected_ppds_index
            Printer.selected_ppds_index = selected_ppd_index
            if Ops.greater_or_equal(selected_ppd_index, 0)
              Builtins.y2milestone(
                "Selected driver is: %1",
                Ops.get(Printer.ppds, selected_ppd_index, {})
              )
            else
              if "" != nick_name
                Builtins.y2milestone(
                  "Selected currently used driver: '%1'",
                  nick_name
                )
              else
                Builtins.y2milestone(
                  "Selected currently used driver: No driver is used (it is a 'raw' queue or a 'System V style interface script' is used)"
                )
              end
            end
          end
          if Ops.greater_or_equal(selected_ppd_index, 0)
            # the widgets to change options for the currently used driver are removed:
            UI.ReplaceWidget(
              Id(:paper_choice_and_driver_options_replace_point),
              Empty()
            )
          else
            # the widgets to change options for the currently used driver are recreated:
            UI.ReplaceWidget(
              Id(:paper_choice_and_driver_options_replace_point),
              VBox(Left(paper_choice_content), Left(driver_options_content))
            )
          end
          next
        end
        if :driver_selection == user_input
          selected_ppd_index = Convert.to_integer(
            UI.QueryWidget(Id(:driver_selection), :CurrentItem)
          )
          if nil == selected_ppd_index
            Popup.AnyMessage(
              _("No Driver Selected"),
              # Body of a Popup::AnyMessage when no driver was selected:
              _("Select a driver.")
            )
            next
          end
          # selected_ppd_index is -1 for the currently used driver
          # and also for a possible dummy entry "Select a driver" which is inserted
          # by the DriverItems function when no driver was preselected.
          # -1 is an invalid index in the ppds list and
          # it means that the driver is not to be exchanged.
          # To be safe that the currently used driver cannot be exchanged
          # Printer::selected_ppds_index is set to -1 in this case.
          if selected_ppd_index != Printer.selected_ppds_index
            Printer.selected_ppds_index = selected_ppd_index
            if Ops.greater_or_equal(selected_ppd_index, 0)
              Builtins.y2milestone(
                "Selected driver is: %1",
                Ops.get(Printer.ppds, selected_ppd_index, {})
              )
            else
              if "" != nick_name
                Builtins.y2milestone(
                  "Selected currently used driver: '%1'",
                  nick_name
                )
              else
                Builtins.y2milestone(
                  "Selected currently used driver: No driver is used (it is a 'raw' queue or a 'System V style interface script' is used)"
                )
              end
            end
          end
          if Ops.greater_or_equal(selected_ppd_index, 0)
            # the widgets to change options for the currently used driver are removed and
            # the description_input field is overwritten with the NickName of the new selected driver:
            #UI::ReplaceWidget( `id(`paper_choice_and_driver_options_replace_point), `Empty() );
            UI.ReplaceWidget(
              Id(:paper_choice_and_driver_options_replace_point),
              Left(new_driver_paper_choice_content)
            )
            new_description = Ops.get(
              Printer.ppds,
              [selected_ppd_index, "nickname"],
              ""
            )
            if "" != model && "unknown" != Builtins.tolower(model)
              new_description = Ops.add(
                Ops.add(model, " with driver "),
                new_description
              )
            end
            # Delete ' characters because they are used for quoting in the bash commandline:
            new_description = Builtins.deletechars(new_description, "'")
            UI.ChangeWidget(Id(:description_input), :Value, new_description)
          else
            # the widgets to change options for the currently used driver are recreated and
            # the description_input field is restored with the current description of the queue:
            UI.ReplaceWidget(
              Id(:paper_choice_and_driver_options_replace_point),
              VBox(Left(paper_choice_content), Left(driver_options_content))
            )
            UI.ChangeWidget(Id(:description_input), :Value, description)
          end
          next
        end
        if :apply_driver_filter == user_input
          driver_filter_input_text = Convert.to_string(
            UI.QueryWidget(Id(:driver_filter_input), :Value)
          )
          Builtins.y2milestone("Drivers for '%1'", driver_filter_input_text)
          if any_model_driver_filter_input_text == driver_filter_input_text
            driver_filter_input_text = ""
          end
          driver_filter_string = Printer.DeriveDriverFilterString(
            driver_filter_input_text
          )
          if "" == driver_filter_string
            driver_filter_input_text = any_model_driver_filter_input_text
          end
          UI.ReplaceWidget(
            Id(:driver_filter_input_replace_point),
            InputField(
              Id(:driver_filter_input),
              Opt(:hstretch),
              # No InputField header because there is the "Caption for a printer driver selection":
              "",
              driver_filter_input_text
            )
          )
          UI.ReplaceWidget(
            Id(:driver_selection_replace_point),
            SelectionBox(
              Id(:driver_selection),
              # By default there is no UserInput()
              # if only something was selected in the SelectionBox
              # (without clicking additionally a button)
              # but the notify option forces UserInput() in this case:
              Opt(:notify),
              "",
              Builtins.prepend(
                Printer.DriverItems(driver_filter_string, false),
                current_driver
              )
            )
          )
          next
        end
        if :more_drivers == user_input
          if non_matching_fallback_driver_filter_string != driver_filter_string
            driver_filter_string = ""
          end
          valid_driver_found = false
          driver_items = []
          # Use the existing value of driver_filter_input_text
          # which is usually set to nick_name and to model as fallback
          # but it could be any string which was entered before by the user.
          # The "more drivers" functionality must work based on the current search string
          # and when nothing is found based on the current search string
          # it falls back to show all drivers so that there is a valid result in any case.
          driver_filter_input_text = Convert.to_string(
            UI.QueryWidget(Id(:driver_filter_input), :Value)
          )
          Builtins.y2milestone(
            "More drivers for '%1'",
            driver_filter_input_text
          )
          if "" != driver_filter_input_text &&
              "unknown" != Builtins.tolower(driver_filter_input_text) &&
              any_model_driver_filter_input_text != driver_filter_input_text &&
              non_matching_fallback_driver_filter_string != driver_filter_string
            manufacturer_and_model_number = Printer.DeriveModelName(
              driver_filter_input_text,
              2
            )
            # Note that manufacturer_and_model_number may be the empty string
            # (when driver_filter_input_text does not contain word which contains a number)
            # or manufacturer_and_model_number may be only one word
            # (when driver_filter_input_text starts with a known manufacturer
            #  but does not contain a word which contains a number
            #  or when driver_filter_input_text does not start with a known manufacturer
            #  but contains a word which contains a number).
            if "" != manufacturer_and_model_number &&
                Builtins.issubstring(manufacturer_and_model_number, " ")
              UI.ReplaceWidget(
                Id(:driver_filter_input_replace_point),
                InputField(
                  Id(:driver_filter_input),
                  Opt(:hstretch),
                  # No InputField header because there is the "Caption for a printer driver selection":
                  "",
                  manufacturer_and_model_number
                )
              )
              driver_filter_string = Printer.DeriveDriverFilterString(
                manufacturer_and_model_number
              )
              if "" != driver_filter_string
                driver_items = Printer.DriverItems(driver_filter_string, true)
                # Printer::DriverItems may result a driver_items list with one single element
                #   [ `item( `id( -1 ), _("No matching driver found.") ) ]
                # to show at least a meaningful text as fallback entry to the user
                # or Printer::DriverItems may result a driver_items list with the first item
                #   [ `item( `id( -1 ), _("Select a driver.") ), ... ]
                # when Printer::DriverItems could not preselect a driver item.
                # If a valid driver was found (but perhaps none was preselected),
                # there would be a non-negative id value of the first or second element
                # which is driver_items[0,0,0] or driver_items[1,0,0]
                # (id[0] is the value of the id, see the comment in Printer::DriverItems).
                if Ops.greater_or_equal(
                    Ops.get_integer(driver_items, [0, 0, 0], -1),
                    0
                  ) ||
                    Ops.greater_or_equal(
                      Ops.get_integer(driver_items, [1, 0, 0], -1),
                      0
                    )
                  valid_driver_found = true
                end
              end
            end
            # Try to use only the manufacturer or only the model number when nothing was found above:
            if !valid_driver_found
              manufacturer_or_model_number = Printer.DeriveModelName(
                driver_filter_input_text,
                1
              )
              if "" != manufacturer_or_model_number
                UI.ReplaceWidget(
                  Id(:driver_filter_input_replace_point),
                  InputField(
                    Id(:driver_filter_input),
                    Opt(:hstretch),
                    # No InputField header because there is the "Caption for a printer driver selection":
                    "",
                    manufacturer_or_model_number
                  )
                )
                driver_filter_string = Printer.DeriveDriverFilterString(
                  manufacturer_or_model_number
                )
                if "" != driver_filter_string
                  driver_items = Printer.DriverItems(driver_filter_string, true)
                  # Printer::DriverItems may result a driver_items list with one single element
                  #   [ `item( `id( -1 ), _("No matching driver found.") ) ]
                  # to show at least a meaningful text as fallback entry to the user
                  # or Printer::DriverItems may result a driver_items list with the first item
                  #   [ `item( `id( -1 ), _("Select a driver.") ), ... ]
                  # when Printer::DriverItems could not preselect a driver item.
                  # If a valid driver was found (but perhaps none was preselected),
                  # there would be a non-negative id value of the first or second element
                  # which is driver_items[0,0,0] or driver_items[1,0,0]
                  # (id[0] is the value of the id, see the comment in Printer::DriverItems).
                  if Ops.greater_or_equal(
                      Ops.get_integer(driver_items, [0, 0, 0], -1),
                      0
                    ) ||
                      Ops.greater_or_equal(
                        Ops.get_integer(driver_items, [1, 0, 0], -1),
                        0
                      )
                    valid_driver_found = true
                  end
                end
              end
            end
          end
          # Nothing was found above.
          # Fall back to show all drivers:
          if !valid_driver_found
            UI.ReplaceWidget(
              Id(:driver_filter_input_replace_point),
              InputField(
                Id(:driver_filter_input),
                Opt(:hstretch),
                # No InputField header because there is the "Caption for a printer driver selection":
                "",
                any_model_driver_filter_input_text
              )
            )
            driver_items = Printer.DriverItems("", true)
          end
          UI.ReplaceWidget(
            Id(:driver_selection_replace_point),
            SelectionBox(
              Id(:driver_selection),
              # By default there is no UserInput()
              # if only something was selected in the SelectionBox
              # (without clicking additionally a button)
              # but the notify option forces UserInput() in this case:
              Opt(:notify),
              "",
              Builtins.prepend(driver_items, current_driver)
            )
          )
          next
        end
        Builtins.y2milestone(
          "Ignoring unexpected returncode in BasicModifyDialog: %1",
          user_input
        )
        next
      end
      Builtins.y2milestone("leaving BasicModifyDialog")
      deep_copy(user_input)
    end
  end
end

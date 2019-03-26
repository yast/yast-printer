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

# File:        include/printer/basicadd.ycp
# Package:     Configuration of printer
# Summary:     Basic add dialog definition
# Authors:     Johannes Meixner <jsmeix@suse.de>

module Yast
  module PrinterBasicaddInclude
    def initialize_printer_basicadd(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Popup"

      Yast.include include_target, "printer/helps.rb"
    end

    # BasicAddDialog dialog
    # @return dialog result
    def BasicAddDialog
      Builtins.y2milestone("entering BasicAddDialog")
      any_model_driver_filter_input_text = _("any model")
      non_matching_fallback_driver_filter_string = "qqqqqqqqqq"
      # Caption for the "Add Printer" dialog (BasicAddDialog):
      caption = _("Add New Printer Configuration")
      # Clear whatever content of a previous dialog which would show up here for several seconds
      # until all the following stuff is done before Wizard::SetContentsButtons is called
      # which finally shows the right content for this dialog.
      Wizard.SetContents(
        caption,
        Empty(),
        Ops.get_string(@HELPS, "basic_add_dialog", ""),
        false,
        false
      )
      Wizard.HideAbortButton
      driver_filter_string = "BasicAddDialog"
      driver_filter_input_text = ""
      queue_name_proposal = ""
      model = Ops.get(
        Printer.connections,
        [Printer.selected_connections_index, "model"],
        ""
      )
      if "" != model && "unknown" != Builtins.tolower(model)
        queue_name_proposal = Printer.NewQueueName(Builtins.tolower(model))
        driver_filter_input_text = Printer.DeriveModelName(model, 0)
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
      contents = VBox(
        VBox(
          HBox(
            Label(_("Specify the Connection")), # Caption for a Table with a list of printer connections:
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
              Printer.ConnectionItems("BasicAddDialog")
            )
          )
        ),
        VStretch(),
        VBox(
          Left(
            Label(_("Find and Assign a Driver")) # Caption for a printer driver selection:
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
              [Item(Id(-1), _("Select a driver."))]
            )
          ),
          RadioButtonGroup(
            Id(:paper_size_radio_buttons),
            HBox(
              Label(_("Default paper size (if printer and driver supports it)")), # Label of a RadioButtonGroup to specify the default paper size:
              # Have none of the RadioButtons preselected which means that
              # by default the CUPS default is used for the default paper size.
              # For the CUPS 1.3 default see http://www.cups.org/str.php?L2846
              # For CUPS 1.4 the default depends on the "DefaultPaperSize" setting in cupsd.conf
              # see https://bugzilla.novell.com/show_bug.cgi?id=395760
              # and http://www.cups.org/str.php?L2848
              HSpacing(2),
              RadioButton(Id(:a4), "A&4"),
              HSpacing(1),
              RadioButton(Id(:letter), "Le&tter"),
              HStretch()
            )
          )
        ),
        VStretch(),
        Left(
          HBox(
            VBox(
              Left(
                ReplacePoint(
                  Id(:queue_name_input_replace_point),
                  InputField(
                    Id(:queue_name_input),
                    # Avoid that it becomes squeezed to only a few characters in text mode:
                    Opt(:hstretch),
                    # Header of a TextEntry to enter the queue name:
                    _("Set Arbitrary &Name"),
                    queue_name_proposal
                  )
                )
              ),
              Left(
                CheckBox(
                  Id(:default_queue_checkbox),
                  # CheckBox to set a local print queue to be the default queue:
                  _("&Use as Default"),
                  # When adding a new queue, do not use it as default queue by default
                  # because this would override an existing default queue setting:
                  false
                )
              )
            ),
            HStretch(),
            VBox(
              Right(
                Label(
                  # to set up HP printers:
                  _("Alternative setup for HP printers:")
                ) # Label text to run HPLIP's printer setup tool 'hp-setup'
              ),
              Right(
                PushButton(
                  Id(:run_hpsetup),
                  # Label of a PushButton to run HPLIP's printer setup tool 'hp-setup'.
                  # Do not change or translate "hp-setup", it is a program name:
                  _("Run &hp-setup")
                )
              ),
              Right(
                Label(
                  # printer setup tool 'hp-setup' runs in English language.
                  # Do not change or translate "hp-setup", it is a program name:
                  _("hp-setup runs in English language")
                ) # Label text to inform the user that HPLIP's
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
        Ops.get_string(@HELPS, "basic_add_dialog", ""),
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
      end
      UI.FakeUserInput(:connection_selection)
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
          if Ops.less_than(Printer.selected_connections_index, 0) &&
              Ops.less_than(Printer.selected_ppds_index, 0)
            Popup.AnyMessage(
              # nor a driver was selected:
              _("Nothing Selected"),
              # Body of a Popup::AnyMessage when neither a connection
              # nor a driver was selected:
              _("Select a connection and then assign a driver.")
            )
            next
          end
          if Ops.less_than(Printer.selected_connections_index, 0)
            Popup.AnyMessage(
              _("No Connection Selected"),
              # Body of a Popup::AnyMessage when no connection was selected:
              _("Select a connection.")
            )
            next
          end
          if Ops.less_than(Printer.selected_ppds_index, 0)
            Popup.AnyMessage(
              _("No Driver Selected"),
              # Body of a Popup::AnyMessage when no driver was selected:
              _("Select a driver.")
            )
            next
          end
          queue_name = Convert.to_string(
            UI.QueryWidget(Id(:queue_name_input), :Value)
          )
          if "" == queue_name
            Popup.AnyMessage(
              _("No Queue Name"),
              # Body of a Popup::AnyMessage when no queue name was entered:
              _("Enter a queue name.")
            )
            next
          end
          if "" !=
              Builtins.deletechars(
                queue_name,
                Ops.add(Printer.alnum_chars, "_")
              )
            Popup.AnyMessage(
              _("Invalid Queue Name"),
              # Body of a Popup::AnyMessage when a wrong queue name was entered:
              _(
                "Only letters (a-z and A-Z), numbers (0-9), and the underscore '_' are allowed for the queue name."
              )
            )
            next
          end
          validated_queue_name = Printer.NewQueueName(queue_name)
          if queue_name != validated_queue_name
            if !Popup.ContinueCancelHeadline(
                # when a queue name is changed to be valid:
                _("Confirm Validated Queue Name"),
                # Body of a Popup::ContinueCancelHeadline
                # when a queue name was automatically changed to be valid
                # where %1 will be replaced by the old invalid queue name
                # and %2 will be replaced by a new valid queue name
                Builtins.sformat(
                  _("'%1' is invalid or it exists already. Use '%2' instead?"),
                  queue_name,
                  validated_queue_name
                )
              )
              next
            end
            queue_name = validated_queue_name
          end
          is_default_queue = Convert.to_boolean(
            UI.QueryWidget(Id(:default_queue_checkbox), :Value)
          )
          default_paper_size = ""
          paper_size = UI.QueryWidget(
            Id(:paper_size_radio_buttons),
            :CurrentButton
          )
          default_paper_size = "A4" if :a4 == paper_size
          default_paper_size = "Letter" if :letter == paper_size
          Wizard.DisableBackButton
          Wizard.DisableNextButton
          # No error messages here because Printer::AddQueue already shows them:
          Printer.AddQueue(queue_name, is_default_queue, default_paper_size)
          # After a local queue was added, enforce to show also local queues
          # in particular when no local queues were shown before:
          Printer.queue_filter_show_local = true
          # Since CUPS 1.4 the new DirtyCleanInterval directive controls the delay when cupsd updates config files:
          if !Printerlib.WaitForUpdatedConfigFiles(
              _("Creating New Printer Setup")
            )
            Popup.ErrorDetails(
              _("New Printer Configuration not yet Stored in the System"),
              # Explanation details of a Popup::ErrorDetails.
              # The 'next dialog' is the overview dialog where the printer configurations are shown
              # which has a 'Refresh List' button to update the shown printer configurations:
              _(
                "If the next dialog does not show the new printer configuration as expected, wait some time and use the 'Refresh List' button."
              )
            )
          end
          Wizard.EnableBackButton
          Wizard.EnableNextButton
          # Exit this dialog in any case:
          break
        end
        break if :connection_wizard == user_input
        break if :add_driver == user_input
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
              Printer.ConnectionItems("MoreConnections")
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
          driver_filter_string = ""
          driver_filter_input_text = ""
          queue_name_proposal = ""
          model = Ops.get(
            Printer.connections,
            [Printer.selected_connections_index, "model"],
            ""
          )
          Builtins.y2milestone("Drivers for '%1'", model)
          if "" != model && "unknown" != Builtins.tolower(model)
            queue_name_proposal = Printer.NewQueueName(Builtins.tolower(model))
            driver_filter_input_text = Printer.DeriveModelName(model, 0)
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
              Printer.DriverItems(driver_filter_string, true)
            )
          )
          UI.ReplaceWidget(
            Id(:queue_name_input_replace_point),
            InputField(
              Id(:queue_name_input),
              # Avoid that it becomes squeezed to only a few characters in text mode:
              Opt(:hstretch),
              # Header of a TextEntry to enter the queue name:
              _("Set Arbitrary &Name"),
              queue_name_proposal
            )
          )
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
          if selected_ppd_index != Printer.selected_ppds_index
            Printer.selected_ppds_index = selected_ppd_index
            Builtins.y2milestone(
              "Selected driver is: %1",
              Ops.get(Printer.ppds, selected_ppd_index, {})
            )
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
              Printer.DriverItems(driver_filter_string, true)
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
          # which is by default set to the autodetected model name
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
              driver_items
            )
          )
          next
        end
        if :run_hpsetup == user_input
          # Printer::RunHpsetup() returns false only if hp-setup cannot be run.
          # It returns true in any other case because there is no usable exit code of hp-setup
          # (always zero even in case of error).
          # The hp-setup exit code does not matter because the printer autodetection in the Overview dialog
          # will show an appropriate result (e.g. no new print queue if hp-setup failed):
          Wizard.DisableBackButton
          Wizard.DisableNextButton
          if !Printer.RunHpsetup
            Popup.Error(
              # Only a simple message because before the RunHpsetup function was called
              # and this function would have shown more specific messages.
              # Do not change or translate "hp-setup", it is a program name:
              _("Failed to run hp-setup.")
            )
            Wizard.EnableBackButton
            Wizard.EnableNextButton
            next
          end
          # When hp-setup has finished, it is likely that a new print queue was created by it.
          # After a local queue was added, enforce to show also local queues
          # in particular when no local queues were shown before:
          Printer.queue_filter_show_local = true
          # Since CUPS 1.4 the new DirtyCleanInterval directive controls the delay when cupsd updates config files:
          if !Printerlib.WaitForUpdatedConfigFiles(
              _("Creating New Printer Setup")
            )
            Popup.ErrorDetails(
              _("New Printer Configuration not yet Stored in the System"),
              # Explanation details of a Popup::ErrorDetails.
              # The 'next dialog' is the overview dialog where the printer configurations are shown
              # which has a 'Refresh List' button to update the shown printer configurations:
              _(
                "If the next dialog does not show the new printer configuration as expected, wait some time and use the 'Refresh List' button."
              )
            )
          end
          # Exit this dialog and go back to the Overview dialog via the sequencer in wizards.ycp
          # to show the new printer autodetection results:
          Wizard.EnableBackButton
          Wizard.EnableNextButton
          break
        end
        Builtins.y2milestone(
          "Ignoring unexpected returncode in BasicAddDialog: %1",
          user_input
        )
        next
      end
      Builtins.y2milestone("leaving BasicAddDialog")
      deep_copy(user_input)
    end
  end
end

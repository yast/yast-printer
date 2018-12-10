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

# File:	clients/printer_proposal.ycp
# Package:	Configuration of printer
# Summary:	Proposal function dispatcher.
# Authors:	Johannes Meixner <jsmeix@suse.de>
#
# Proposal function dispatcher for printer configuration.
# See source/installation/proposal/proposal-API.txt

module Yast
  class PrinterProposalClient < Client
    def main

      textdomain "printer"

      Yast.import "Printer"
      Yast.import "Printerlib"
      Yast.import "Progress"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Service"
      Yast.import "Popup"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Printer proposal started")

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
      Builtins.y2milestone("Printer proposal func='%1'", @func)
      Builtins.y2milestone("Printer proposal param='%1'", @param)


      # Create a textual proposal and write it instantly to the system:
      if @func == "MakeProposal"
        @proposal = []
        @warning = nil
        @warning_level = nil
        @force_reset = Ops.get_boolean(@param, "force_reset", false)
        if @force_reset
          # avoid that the hardware proposal asks the user
          # to install the packages cups-client and cups, see
          # https://bugzilla.novell.com/show_bug.cgi?id=445719#c13
          Builtins.y2milestone(
            "Not calling Printer::Read() to avoid that the proposal asks to install cups-client and cups."
          )
        end
        # Propose configuration for each local printer:
        # Check if the packages cups-client and cups are installed
        # and skip the automated queue setup if one of them is missing, see
        # https://bugzilla.novell.com/show_bug.cgi?id=445719#c13
        # If cups-client is missing, it would run into an endless sequence of errors.
        # If cups is missing, there can be no local running cupsd which is
        # mandatory to set up local print queues.
        if !Printerlib.TestAndInstallPackage("cups-client", "installed")
          Builtins.y2milestone(
            "Skipped automated queue setup because the package cups-client is not installed."
          )
          @proposal = [
            _(
              "Cannot configure printing (required package cups-client is not installed)."
            )
          ]
        else
          if !Printerlib.TestAndInstallPackage("cups", "installed")
            Builtins.y2milestone(
              "Skipped automated queue setup because the package cups is not installed."
            )
            @proposal = [
              _(
                "Cannot configure local printers (required package cups is not installed)."
              )
            ]
          else
            # (i.e. a ServerName != "localhost/127.0.0.1" in /etc/cups/client.conf)
            # and ignore when it fails (i.e. use the fallback value silently):
            Printerlib.DetermineClientOnly
            # Skip automated queue setup when it is a client-only config:
            if Printerlib.client_only
              Builtins.y2milestone(
                "Skipped automated queue setup because it is a client-only config."
              )
              @proposal = [
                Builtins.sformat(
                  _(
                    "No local printer accessible (using remote CUPS server '%1' for printing)."
                  ),
                  Printerlib.client_conf_server_name
                )
              ]
            else
              if !Printerlib.GetAndSetCupsdStatus("")
                # try to make silently sure that a local cupsd is running
                # (i.e. start the cupsd without user confirmation)
                # because it is needed for automated queue setup
                # see https://bugzilla.novell.com/show_bug.cgi?id=418585
                # Note that because of Mode::installation() this happens only
                # if we are doing a fresh installation (but e.g. not for an update)
                # and because of Stage::cont() we are continuing the installation
                # in the target system (but we are e.g. not in the inst-sys system)
                # so that it should be sufficiently safe to (re)-start and enable
                # the cupsd without user confirmation here:
                if Mode.installation && Stage.cont
                  Builtins.y2milestone(
                    "Silently start and enable the cupsd because we are continuing a fresh installation in the target system."
                  )
                  if Service.Status("cups") != 0
                    Service.Start("cups")
                  else
                    # but actually it is not accessible according to GetAndSetCupsdStatus.
                    # For example the cupsd may run but failed to bind to the IPP port 631
                    # because whatever other service grabbed this port for a short while
                    # so that a restart could help here (a known ypbind/portmapper issue):
                    Service.Restart("cups")
                  end
                  Service.Enable("cups")
                  # Wait until the cupsd is actually accessible.
                  # In particular for the very first start of the cupsd it may take several seconds
                  # (up to more than a minute on a slow machine) until it is actually accessible,
                  # compare https://bugzilla.novell.com/show_bug.cgi?id=429397
                  # Sleep one second in any case so that the new started cupsd can become ready to operate:
                  Builtins.sleep(1000)
                  if !Printerlib.GetAndSetCupsdStatus("")
                    # Sleep 9 seconds so that the new started cupsd has more time to become ready to operate:
                    Builtins.sleep(9000)
                  end
                  if !Printerlib.GetAndSetCupsdStatus("")
                    # Wait half a minute for a new started cupsd:
                    Popup.TimedMessage(
                      _(
                        "Started the CUPS daemon.\nWaiting half a minute for the CUPS daemon to get ready to operate...\n"
                      ),
                      30
                    )
                  end
                  if !Printerlib.GetAndSetCupsdStatus("")
                    # for the very first time (e.g. on a new installed system)
                    # until the cupsd is actually ready to operate.
                    # E.g. because parsing of thousands of PPDs may need much time.
                    # Therefore enforce waiting one minute now.
                    # (Plain busy message without title.)
                    Popup.ShowFeedback(
                      "",
                      _(
                        "The CUPS daemon is not yet accessible.\nWaiting one minute so that it is ready to operate..."
                      )
                    )
                    Builtins.sleep(60000)
                    Popup.ClearFeedback
                  end
                end
              end
              # Skip automated queue setup when the cupsd is not accessible up to now.
              # A special case is when the cupsd does not listen on the official IANA IPP port (631).
              # Then Printerlib::GetAndSetCupsdStatus("") returns false because it calls
              # "lpstat -h localhost -r" which fails ("-h localhost:port" would have to be used).
              # The YaST printer module does not support when the cupsd listens on a non-official port
              # so that also in this special case no automated queue setup is done.
              if !Printerlib.GetAndSetCupsdStatus("")
                Builtins.y2milestone(
                  "Skipped automated queue setup because there is no local cupsd accessible (via port 631)."
                )
                @proposal = [
                  _(
                    "Cannot configure local printers (no local cupsd accessible)."
                  )
                ]
              else
                @detected_printers = Builtins.filter(
                  Convert.convert(
                    Printer.ConnectionItems("BasicAddDialog"),
                    :from => "list",
                    :to   => "list <term>"
                  )
                ) do |row|
                  # with an empty URI (i.e. no need to test this here)
                  # but Printer::ConnectionItems adds trailing spaces
                  # because the current YaST UI has almost no additional
                  # space between table columns:
                  model = String.CutBlanks(Ops.get_string(row, 1, ""))
                  !Builtins.issubstring(Builtins.tolower(model), "unknown")
                end
                Builtins.y2milestone(
                  "Detected local printers: %1",
                  @detected_printers
                )
                if Ops.less_than(Builtins.size(@detected_printers), 1)
                  Builtins.y2milestone(
                    "Skipped automated queue setup because there is no local printer detected."
                  )
                  @proposal = [_("No local printer detected.")]
                else
                  Builtins.y2milestone(
                    "Local printers detected, will set up queues for them:"
                  )
                  @initially_existing_queues = []
                  @already_set_up_uris = []
                  # An empty list of autodetected queues is the fallback which is correct:
                  Printer.AutodetectQueues
                  Builtins.foreach(Printer.queues) do |queue|
                    if "" != Ops.get(queue, "name", "")
                      @initially_existing_queues = Builtins.add(
                        @initially_existing_queues,
                        Ops.get(queue, "name", "")
                      )
                    end
                    if "" != Ops.get(queue, "uri", "")
                      @already_set_up_uris = Builtins.add(
                        @already_set_up_uris,
                        Ops.get(queue, "uri", "")
                      )
                    end
                  end 

                  Builtins.foreach(@detected_printers) do |printer|
                    # has almost no additional space between table columns:
                    model = String.CutBlanks(Ops.get_string(printer, 1, ""))
                    if "" != model && "unknown" != Builtins.tolower(model)
                      uri = String.CutBlanks(Ops.get_string(printer, 2, ""))
                      if "" != uri
                        Builtins.y2internal(
                          "Setting up a queue for URI '%1'",
                          uri
                        )
                        # See basicadd.ycp how a queue_name_proposal is set there:
                        queue_name = Printer.NewQueueName(
                          Builtins.tolower(model)
                        )
                        if Builtins.contains(@already_set_up_uris, uri)
                          Builtins.y2internal(
                            "Skipping printer '%1' because a queue with the same URI already exists.",
                            printer
                          )
                          next
                        end
                        Builtins.y2milestone(
                          "Proposed queue name: %1",
                          queue_name
                        )
                        # See basicadd.ycp how driver_filter_input_text and driver_filter_string are set there.
                        # The same is done here so that the proposal results the same as if the user
                        # would have blindly clicked [OK] in the BasicAddDialog:
                        driver_filter_input_text = Printer.DeriveModelName(
                          model,
                          0
                        )
                        driver_filter_string = Printer.DeriveDriverFilterString(
                          driver_filter_input_text
                        )
                        if "" != driver_filter_string
                          drivers = Printer.DriverItems(
                            driver_filter_string,
                            true
                          )
                          # Printer::DriverItems may result a drivers list with one single element
                          #   [ `item( `id( -1 ), _("No matching driver found.") ) ]
                          # to show at least a meaningful text as fallback entry to the user
                          # or Printer::DriverItems may result a drivers list with the first item
                          #   [ `item( `id( -1 ), _("Select a driver.") ), ... ]
                          # when Printer::DriverItems could not preselect a driver item.
                          # In contrast if a valid driver was found and preselected, there would be
                          # a non-negative id value of the first element which is drivers[0,0,0]
                          # (id[0] is the value of the id, see the comment in Printer::DriverItems).
                          # Only a test if both selected_ppds_index and selected_connections_index
                          # are non-negative makes sure that there is a valid driver and a valid connection.
                          Builtins.y2internal("Available drivers: %1", drivers)
                          Printer.selected_ppds_index = Ops.get_integer(
                            drivers,
                            [0, 0, 0],
                            -1
                          )
                          Printer.selected_connections_index = Ops.get_integer(
                            printer,
                            [0, 0],
                            -1
                          )
                          if Ops.greater_or_equal(
                              Printer.selected_ppds_index,
                              0
                            ) &&
                              Ops.greater_or_equal(
                                Printer.selected_connections_index,
                                0
                              )
                            Builtins.y2internal(
                              "Selected driver: %1",
                              Ops.get(drivers, 0)
                            )
                            # An empty default_paper_size results CUPS's default paper size
                            # (see the Printer::AddQueue function) so that the proposal results the same
                            # as if the user would have blindly clicked [OK] in the BasicAddDialog.
                            # The BasicAddDialog does by default not set the default queue
                            # to avoid that a possibly existing default queue gets overwritten.
                            is_default_queue = false
                            default_paper_size = ""
                            if Printer.AddQueue(
                                queue_name,
                                is_default_queue,
                                default_paper_size
                              )
                              @already_set_up_uris = Builtins.add(
                                @already_set_up_uris,
                                uri
                              )
                              # Since CUPS 1.4 the new DirtyCleanInterval directive controls
                              # the delay when cupsd updates config files (see basicadd.ycp).
                              if !Printerlib.WaitForUpdatedConfigFiles(
                                  _("Creating New Printer Setup")
                                )
                                Popup.ErrorDetails(
                                  _(
                                    "New Printer Configuration not yet Stored in the System"
                                  ),
                                  # Explanation details of a Popup::ErrorDetails.
                                  _(
                                    "This may result broken printer configurations."
                                  )
                                )
                              end
                              # Autodetect queues again so that Printer::NewQueueName
                              # can compare with existing queue names but ignore whatever failures
                              # (an empty list of autodetected queues is the fallback result):
                              Printer.AutodetectQueues
                            end
                          else
                            Builtins.y2error(
                              "No available drivers for printer %1",
                              printer
                            )
                          end
                        end
                      end
                    end
                  end 

                  Builtins.foreach(
                    Convert.convert(
                      Printer.QueueItems(true, false),
                      :from => "list",
                      :to   => "list <term>"
                    )
                  ) do |queue|
                    # has almost no additional space between table columns:
                    name = String.CutBlanks(Ops.get_string(queue, 2, ""))
                    description = String.CutBlanks(Ops.get_string(queue, 3, ""))
                    configuration = name
                    if description != ""
                      configuration = Ops.add(
                        Ops.add(configuration, " : "),
                        description
                      )
                    end
                    if Builtins.contains(@initially_existing_queues, name)
                      @proposal = Builtins.add(
                        @proposal,
                        Ops.add(
                          _("Found existing configuration") + " : ",
                          configuration
                        )
                      )
                    else
                      @proposal = Builtins.add(
                        @proposal,
                        Ops.add(
                          _("Created configuration") + " : ",
                          configuration
                        )
                      )
                    end
                  end
                end
              end
            end
          end
        end
        @proposal = Builtins.filter(@proposal) { |p| p != "" }
        if Builtins.size(@proposal) == 0
          @proposal = [_("No local printer configured.")]
        end
        @ret = {
          "raw_proposal"  => @proposal,
          "warning_level" => @warning_level,
          "warning"       => @warning
        }
      # Run the full printer module dialogs:
      elsif @func == "AskUser"
        # to make sure that when the full printer module dialogs are launched
        # it asks the user to install the packages cups-client and cups:
        @progress_orig = Progress.set(false)
        Printer.Read
        Progress.set(@progress_orig)
        # In printer.ycp the .propose argument calls PrinterAutoSequence and
        # PrinterAutoSequence in wizards.ycp runs only the MainSequence
        # which are all the usual dialogs (starting with the "Overview")
        # but without running before ReadDialog (which calls only Printer::Read)
        # and running afterwards WriteDialog (which calls only Printer::Write)
        # which is the reason that Printer::Read is called explicitly above.
        @seq = Convert.to_symbol(
          WFM.CallFunction("printer", [path(".propose")])
        )
        Builtins.y2debug("seq=%1", @seq)
        @ret = { "workflow_sequence" => @seq }
      # Create titles:
      elsif @func == "Description"
        @ret = {
          "rich_text_title" => _("Printer"),
          # Menu title for Printer in proposals
          "menu_title"      => _(
            "&Printer"
          ),
          "id"              => "printer"
        } # Rich text title for Printer in proposals
      # Dummy function to write the proposal (it is already written in the "MakeProposal" function):
      elsif @func == "Write"
        # it does actually nothing except to exit verbosely, see
        # http://en.opensuse.org/Archive:YaST_Printer_redesign#Basic_Implementation_Principles:
        # for background information.
        Builtins.y2milestone(
          "No need to call Printer::Write() because it does nothing."
        )
      else
        Builtins.y2error("Unknown function: %1", @func)
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("Printer proposal finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::PrinterProposalClient.new.main

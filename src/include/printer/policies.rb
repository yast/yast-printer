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

# File:        include/printer/policies.ycp
# Package:     Configuration of printer
# Summary:     DefaultPolicy and ErrorPolicy settings in cupsd.conf
# Authors:     Johannes Meixner <jsmeix@suse.de>
#
# $Id: policies.ycp 27914 2006-02-13 14:32:08Z locilka $
module Yast
  module PrinterPoliciesInclude
    def initialize_printer_policies(include_target)
      Yast.import "UI"

      textdomain "printer"

      Yast.import "Printerlib"
      Yast.import "Printer"
      Yast.import "Popup"

      Yast.include include_target, "printer/helps.rb"

      @initial_operation_policy = "default"
      # An entry for a ComboBox from which the user can select that the CUPS error policy
      # which is used when it fails to send a job to the printer is to
      # stop the printer and keep the job for future printing:
      @error_policy_stop_printer_string = _(
        "stop the printer and keep the job for future printing"
      )
      # An entry for a ComboBox from which the user can select that the CUPS error policy
      # which is used when it fails to send a job to the printer is to
      # re-send the job from the beginning after waiting some time
      # (the default JobRetryInterval is 30 seconds but this can be changed):
      @error_policy_retry_job_string = _(
        "re-send the job after waiting some time"
      )
      # An entry for a ComboBox from which the user can select that the CUPS error policy
      # which is used when it fails to send a job to the printer is to
      # abort and delete the job and proceed with the next job:
      @error_policy_abort_job_string = _(
        "abort and delete the job and proceed with the next job"
      )
      @initial_error_policy = "stop-printer"

      # Have the error policy stuff first because this is of more importance for a normal user.
      # Normal users may like to change the CUPS upstream default "stop-printer" error policy
      # to "abort-job" because is often more convenient for a workstation with local printers
      # when a failing print job is simply removed instead of having the whole queue disabled
      # and get the failed job re-printed when the queue becomes re-enabled at any time later.
      # In contrast normal users should usually not change the CUPS upstream default
      # operation policy "default" to something else because other operation policies
      # are either less secure or too secure for usual printing operation.
      @widgetPolicies = VBox(
        VStretch(),
        Left(
          ComboBox(
            Id("error_policy"),
            # Header for a ComboBox to specify the CUPS error policy:
            _("Specify the &error policy"),
            [
              Item(Id("stop-printer"), @error_policy_stop_printer_string),
              Item(Id("retry-job"), @error_policy_retry_job_string),
              Item(Id("abort-job"), @error_policy_abort_job_string)
            ]
          )
        ),
        Left(
          CheckBox(
            Id("apply_error_policy"),
            # CheckBox to apply the CUPS error policy which is selected in the ComboBox above
            # to all local printer configurations (i.e. to all local print queues).
            # When possible we perefer to use the wording "printer configuration"
            # instead of "print queue" because the latter may sound too technical
            # but sometimes (e.g. in the Connection Wizard) we must use the exact technical term:
            _("&Apply this error policy to all local printer configurations")
          )
        ),
        VStretch(),
        Left(
          ComboBox(
            Id("operation_policy"),
            # Header for a ComboBox to specify the CUPS operation policy:
            _("Specify the &operation policy"),
            [""]
          )
        ),
        Left(
          CheckBox(
            Id("apply_operation_policy"),
            # CheckBox to apply the CUPS operation policy which is selected in the ComboBox above
            # to all local printer configurations (i.e. to all local print queues).
            # When possible we perefer to use the wording "printer configuration"
            # instead of "print queue" because the latter may sound too technical
            # but sometimes (e.g. in the Connection Wizard) we must use the exact technical term:
            _(
              "Apply this operation &policy to all local printer configurations"
            )
          )
        ),
        VStretch()
      )
    end

    def initPolicies(key)
      Builtins.y2milestone("entering initPolicies with key '%1'", key)
      # Note that the "Policies" dialog is not useless when there is no local queue.
      # For example the user may like to configure the "Policies" before he set up the first local queue.
      policies_dialog_is_useless = false
      # Determine whether or not it is currently a real client-only config
      # (i.e. a ServerName != "localhost/127.0.0.1" in /etc/cups/client.conf)
      # and ignore when it fails (i.e. use the fallback value silently):
      Printerlib.DetermineClientOnly
      if Printerlib.client_only
        if !Popup.YesNoHeadline(
            Builtins.sformat(
              # where %1 will be replaced by the server name:
              _("Disable Remote CUPS Server '%1'"),
              Printerlib.client_conf_server_name
            ), # PopupYesNoHeadline headline
            # PopupYesNoHeadline body:
            _(
              "A remote CUPS server setting conflicts with setting policies for the local system."
            )
          )
          policies_dialog_is_useless = true
          Builtins.y2milestone(
            "policies_dialog_is_useless because user decided not to disable client-only CUPS server '%1'",
            Printerlib.client_conf_server_name
          )
        else
          if !Printerlib.ExecuteBashCommand(
              Ops.add(Printerlib.yast_bin_dir, "cups_client_only none")
            )
            Popup.ErrorDetails(
              _(
                "Failed to remove the 'ServerName' entry in /etc/cups/client.conf"
              ),
              Ops.add(
                Ops.add(Ops.get_string(Printerlib.result, "stderr", ""), "\n"),
                Ops.get_string(Printerlib.result, "stdout", "")
              )
            )
            policies_dialog_is_useless = true
            Builtins.y2milestone(
              "policies_dialog_is_useless because it failed to disable client-only CUPS server '%1'",
              Printerlib.client_conf_server_name
            )
          end
        end
      end
      # When it is no "client-only" config,
      # determine whether or not a local cupsd is accessible:
      if !policies_dialog_is_useless
        if !Printerlib.GetAndSetCupsdStatus("")
          if !Printerlib.GetAndSetCupsdStatus("start")
            policies_dialog_is_useless = true
            Builtins.y2milestone(
              "policies_dialog_is_useless because 'rccups start' failed."
            )
          end
        end
      end
      # Determine the existing policy names in '<Policy policy-name>' sections in /etc/cups/cupsd.conf:
      policy_names = [""]
      if Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf Policies")
        )
        # but possible duplicate policy names are not removed in the command output:
        policy_names = Builtins.toset(
          Builtins.splitstring(
            Ops.get_string(Printerlib.result, "stdout", ""),
            " "
          )
        )
      else
        policy_names = ["default"]
      end
      # Determine the DefaultPolicy in /etc/cups/cupsd.conf:
      if Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf DefaultPolicy")
        )
        # but possible duplicate policy names are not removed in the command output.
        # Multiple DefaultPolicy entries are a broken config but it can happen
        # and in this case the first DefaultPolicy entry is used:
        @initial_operation_policy = Ops.get(
          Builtins.splitstring(
            Ops.get_string(Printerlib.result, "stdout", ""),
            " "
          ),
          0,
          "default"
        )
      else
        @initial_operation_policy = "default"
      end
      # Use only the plain strings in the policy_names list without an id
      # for the operation_policy ComboBox:
      UI.ChangeWidget(Id("operation_policy"), :Items, policy_names)
      # Have the initial_operation_policy preselected:
      UI.ChangeWidget(Id("operation_policy"), :Value, @initial_operation_policy)
      # Have the CheckBox to apply the operation policy to all local print queues
      # un-checked in any case:
      UI.ChangeWidget(Id("apply_operation_policy"), :Value, false)
      # Determine the ErrorPolicy in /etc/cups/cupsd.conf:
      if Printerlib.ExecuteBashCommand(
          Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf ErrorPolicy")
        )
        # but possible duplicate policy names are not removed in the command output.
        # Multiple ErrorPolicy entries are a broken config but it can happen
        # and in this case the first ErrorPolicy entry is used:
        @initial_error_policy = Ops.get(
          Builtins.splitstring(
            Ops.get_string(Printerlib.result, "stdout", ""),
            " "
          ),
          0,
          "stop-printer"
        )
      else
        @initial_error_policy = "stop-printer"
      end
      # Have the initial_error_policy preselected:
      UI.ChangeWidget(Id("error_policy"), :Value, Id(@initial_error_policy))
      # Have the CheckBox to apply the error policy to all local print queues
      # un-checked in any case:
      UI.ChangeWidget(Id("apply_error_policy"), :Value, false)
      if policies_dialog_is_useless
        UI.ChangeWidget(Id("operation_policy"), :Enabled, false)
        UI.ChangeWidget(Id("apply_operation_policy"), :Enabled, false)
        UI.ChangeWidget(Id("error_policy"), :Enabled, false)
        UI.ChangeWidget(Id("apply_error_policy"), :Enabled, false)
      end
      Builtins.y2milestone(
        "leaving initPolicies with\n" +
          "initial_operation_policy = '%1'\n" +
          "initial_error_policy = '%2'",
        @initial_operation_policy,
        @initial_error_policy
      )

      nil
    end

    def ApplyPoliciesSettings
      applied_policies = true
      # Get the actual settings and values from the dialog:
      current_operation_policy = Convert.to_string(
        UI.QueryWidget(Id("operation_policy"), :Value)
      )
      apply_operation_policy = Convert.to_boolean(
        UI.QueryWidget(Id("apply_operation_policy"), :Value)
      )
      Builtins.y2milestone(
        "current_operation_policy: '%1' apply it to all local queues: '%2'",
        current_operation_policy,
        apply_operation_policy
      )
      current_error_policy = Convert.to_string(
        UI.QueryWidget(Id("error_policy"), :Value)
      )
      apply_error_policy = Convert.to_boolean(
        UI.QueryWidget(Id("apply_error_policy"), :Value)
      )
      Builtins.y2milestone(
        "current_error_policy: '%1' apply it to all local queues: '%2'",
        current_error_policy,
        apply_error_policy
      )
      if current_operation_policy == @initial_operation_policy &&
          current_error_policy == @initial_error_policy &&
          !apply_operation_policy &&
          !apply_error_policy
        Builtins.y2milestone("Nothing changed in 'Policies' dialog.")
        Builtins.y2milestone("leaving storePolicies")
        return true
      end
      if apply_operation_policy || apply_error_policy
        # The Overview dialog is also shown in any case after a queue was added.
        # Finally the Overview dialog is re-run (with a re-created list of queues) via the sequencer
        # after a queue was deleted.
        # The Overview dialog calls Printer::QueueItems which calls AutodetectQueues so that
        # the queues have been already autodetected and the Printer::queues list is up to date.
        # so that there is no need to call Printer::AutodetectQueues here again.
        Builtins.foreach(Printer.queues) do |queue|
          name = Ops.get(queue, "name", "")
          next if "" == Builtins.filterchars(name, Printer.alnum_chars)
          commandline = Ops.add(
            Ops.add("/usr/sbin/lpadmin -h localhost -p '", name),
            "'"
          )
          if apply_operation_policy
            commandline = Ops.add(
              Ops.add(
                Ops.add(commandline, " -o 'printer-op-policy="),
                current_operation_policy
              ),
              "'"
            )
          end
          if apply_error_policy
            commandline = Ops.add(
              Ops.add(
                Ops.add(commandline, " -o 'printer-error-policy="),
                current_error_policy
              ),
              "'"
            )
          end
          if !Printerlib.ExecuteBashCommand(commandline)
            Popup.ErrorDetails(
              Builtins.sformat(
                # where %1 will be replaced by the print queue name.
                _("Failed to apply the policy to '%1'"),
                name
              ), # Popup::ErrorDetails message
              Ops.get_string(Printerlib.result, "stderr", "")
            )
            applied_policies = false
          end
        end
      end
      if current_operation_policy != @initial_operation_policy
        if !Printerlib.ExecuteBashCommand(
            Ops.add(
              Ops.add(
                Printerlib.yast_bin_dir,
                "modify_cupsd_conf DefaultPolicy "
              ),
              current_operation_policy
            )
          )
          Popup.ErrorDetails(
            Builtins.sformat(
              # where %1 will be replaced by the default operation policy value.
              # Do not change or translate "DefaultPolicy", it is a system settings name.
              _("Failed to set 'DefaultPolicy %1' in /etc/cups/cupsd.conf"),
              current_operation_policy
            ), # Popup::ErrorDetails message
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          applied_policies = false
        end
      end
      if current_error_policy != @initial_error_policy
        if !Printerlib.ExecuteBashCommand(
            Ops.add(
              Ops.add(Printerlib.yast_bin_dir, "modify_cupsd_conf ErrorPolicy "),
              current_error_policy
            )
          )
          Popup.ErrorDetails(
            Builtins.sformat(
              # where %1 will be replaced by the default error policy value.
              # Do not change or translate "ErrorPolicy", it is a system settings name.
              _("Failed to set 'ErrorPolicy %1' in /etc/cups/cupsd.conf"),
              current_error_policy
            ), # Popup::ErrorDetails message
            Ops.get_string(Printerlib.result, "stderr", "")
          )
          applied_policies = false
        end
      end
      # Restart a local cupsd only if a policy in /etc/cups/cupsd.conf was changed:
      if current_operation_policy != @initial_operation_policy ||
          current_error_policy != @initial_error_policy
        # otherwise do nothing (i.e. do not start it now):
        if Printerlib.GetAndSetCupsdStatus("")
          if !Printerlib.GetAndSetCupsdStatus("restart")
            applied_policies = false
          end
        end
      end
      Builtins.y2milestone("leaving storePolicies")
      applied_policies
    end

    def handlePolicies(key, event)
      event = deep_copy(event)
      Builtins.y2milestone(
        "entering handlePolicies with key '%1'\nand event '%2'",
        key,
        event
      )
      if "Activated" == Ops.get_string(event, "EventReason", "")
        if :abort == Ops.get(event, "ID") || :cancel == Ops.get(event, "ID") ||
            :back == Ops.get(event, "ID")
          # There is only a "Cancel" functionality (via the "back" button) which goes back one step
          # and the button with the "abort" functionality is not shown at all (see dialogs.ycp).
          # Unfortunately when the YaST package installer is run via Printerlib::TestAndInstallPackage
          # it leaves a misused "abort" button labeled "Skip Autorefresh" with WidgetID "`abort"
          # so that this case is mapped to the "Cancel" functionality:
          return :policies_back
        end
        if :next == Ops.get(event, "ID")
          if !ApplyPoliciesSettings()
            Popup.Error(_("Failed to apply the settings to the system."))
          end
          return :policies_next
        end
      end
      nil
    end
  end
end

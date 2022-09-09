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

# File:        include/printer/Printerlib.ycp
# Package:     Configuration of printer
# Summary:     Common functionality
# Authors:     Michal Zugec <mzugec@suse.cz>
#              Johannes Meixner <jsmeix@suse.de>

require "shellwords"
require "yast"

module Yast
  class PrinterlibClass < Module
    def main
      Yast.import "UI"
      textdomain "printer"

      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Service"

      # Fortunately the tools are for all architectures always
      # installed in /usr/lib/YaST2/bin/ (i.e. no "lib64").
      # I tested this on Thu Aug 28 2008 using the command
      # rpm -qlp /work/CDs/all/full-sle10-sp2*/suse/*/yast2-printer.rpm | grep '/YaST2/bin/' | grep -v '/usr/lib/YaST2/bin/'
      @yast_bin_dir = "/usr/lib/YaST2/bin/"

      # The result map is used as a simple common local store for whatever additional results
      # (in particular commandline exit code, stdout, stderr, and whatever messages)
      # so that the local functions in this module can be of easy-to-use boolean type.
      # The following keys are used:
      # result["exit"]:<integer> for exit codes
      # result["stdout"]:<string> for stdout and whatever non-error-messages
      # result["stderr"]:<string> for stderr and whatever error-messages
      @result = { "exit" => 0, "stdout" => "", "stderr" => "" }

      # By default there is a local running cupsd.
      # But to be on the safe side, assume it is not:
      @local_cupsd_accessible = false

      # By default there is no active "ServerName" entry in /etc/cups/client.conf:
      @client_conf_server_name = ""
      @client_only = false

      # By default there is "Browsing On" in /etc/cups/cupsd.conf
      # which is even the fallback if there is no "Browsing" entry at all
      # or when the "Browsing" entry is deactivated by a leading '#' character.
      # Therefore browsing_on is only false if "Browsing Off" or "Browsing No"
      # is explicitly set in /etc/cups/cupsd.conf.
      @cupsd_conf_browsing_on = true

      # By default there is "BrowseAllow all" in /etc/cups/cupsd.conf
      # which is even the fallback if there is no "BrowseAllow" entry at all
      # or when the "BrowseAllow" entries are deactivated by a leading '#' character.
      # Multiple BrowseAllow lines are allowed, e.g.:
      #   BrowseAllow from @LOCAL
      #   BrowseAllow from 192.168.200.1
      #   BrowseAllow from 192.168.100.0/255.255.255.0
      # so that each BrowseAllow line value is stored as one string
      # in the cupsd_conf_browse_allow list of strings:
      @cupsd_conf_browse_allow = ["all"]

      # By default there is no "BrowsePoll" entry in /etc/cups/cupsd.conf
      # Multiple BrowsePoll lines are allowed, e.g.:
      #   BrowsePoll 192.168.100.1
      #   BrowsePoll 192.168.200.2
      # so that each BrowsePoll line value is stored as one string
      # in the cupsd_conf_browse_poll list of strings:
      @cupsd_conf_browse_poll = [""]
    end

    # Wrapper for SCR::Execute to execute a bash command to increase verbosity via y2milestone.
    # It reports the command via y2milestone in any case and it reports exit code, stdout
    # and stderr via y2milestone in case of non-zero exit code.
    # @param [String] bash_commandline string of the bash command to be executed
    # @return true on success
    def ExecuteBashCommand(bash_commandline)
      Builtins.y2milestone("Executing bash commandline: %1", bash_commandline)
      # Enforce a hopefully sane environment before running the actual command:
      bash_commandline = Ops.add(
        "export PATH='/sbin:/usr/sbin:/usr/bin:/bin' ; export LC_ALL='POSIX' ; export LANG='POSIX' ; umask 022 ; ",
        bash_commandline
      )
      @result = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), bash_commandline)
      )
      if Ops.get_integer(@result, "exit", 9999) != 0
        Builtins.y2warning(
          "'%1' exit code is: %2",
          bash_commandline,
          Ops.get_integer(@result, "exit", 9999)
        )
        Builtins.y2warning(
          "'%1' stdout is: %2",
          bash_commandline,
          Ops.get_string(@result, "stdout", "")
        )
        Builtins.y2warning(
          "'%1' stderr is: %2",
          bash_commandline,
          Ops.get_string(@result, "stderr", "")
        )
        return false
      end
      true
    end

    # Test whether the package is installed (calls 'rpm -q package_name') or
    # test whether the package is available to be installed (Package::Available)
    # and if yes then install it (Package::Install) if it is not yet installed or
    # remove the package (Package::Remove) if it is installed.
    # @param [String] package_name string of the package name
    # @param [String] action string of the action to be done (installed or install or remove).
    # @return true on success
    def TestAndInstallPackage(package_name, action)
      Builtins.y2milestone(
        "TestAndInstallPackage '%1' with action '%2'",
        package_name,
        action
      )
      # Intentionally Package::Installed(package_name) is not used here
      # because it does 'rpm -q' and if this fails it does 'rpm -q --whatprovides'
      # but I am only interested in the result for the real package name here
      # because alternatives would be handled in the upper-level functions
      # (e.g. in the user dialogs) which call TestAndInstallPackage:
      if "installed" == action
        if ExecuteBashCommand("rpm -q " + package_name.shellescape)
          Builtins.y2milestone(
            "TestAndInstallPackage: package '%1' is installed",
            Ops.get_string(@result, "stdout", package_name)
          )
          return true
        end
        # The "%1" makes the YCP Parser happy, otherwise it shows the warning
        # "Format string is not constant, no parameter checking possible".
        Builtins.y2milestone(
          "TestAndInstallPackage: %1",
          Ops.get_string(@result, "stdout", "package is not installed")
        )
        return false
      end
      if "install" == action
        if ExecuteBashCommand("rpm -q " + package_name.shellescape)
          Builtins.y2milestone(
            "TestAndInstallPackage: package '%1' is already installed",
            Ops.get_string(@result, "stdout", package_name)
          )
          return true
        end
        # Is the package available to be installed?
        # Package::Available returns nil if no package source is available.
        package_available = Package.Available(package_name)
        if nil == package_available
          Builtins.y2milestone(
            "TestAndInstallPackage: Required package %1 is not installed and there is no package repository available.",
            package_name
          )
          Popup.Error(
            Builtins.sformat(
              _(
                "Required package %1 is not installed and there is no package repository available."
              ),
              package_name
            ) # Message of a Popup::Error where %1 will be replaced by the package name:
          )
          return false
        end
        if !package_available
          Builtins.y2milestone(
            "TestAndInstallPackage: Required package %1 is not installed and not available in the repository.",
            package_name
          )
          Popup.Error(
            Builtins.sformat(
              _(
                "Required package %1 is not installed and not available in the repository."
              ),
              package_name
            ) # Message of a Popup::Error where %1 will be replaced by the package name:
          )
          return false
        end
        # Package::Install(package_name) has unexpected side-effects
        # because it does additionally remove whatever other packages
        # for example to "automatically solve" existing package conflicts
        # without any dialog where the user could accept or reject additional removals
        # (the user may have intentionally accepted whatever package conflict).
        # I am only interested to install exactly the one package which was specified
        # and all what this one package requires but I am not interested to get whatever
        # other packages removed but I do not know a function which does this.
        # Therefore I use Package::Install(package_name) because it is most important
        # to get all installed what is required by the package which was specified.
        if !Package.Install(package_name)
          Builtins.y2milestone(
            "TestAndInstallPackage: Failed to install required package %1.",
            package_name
          )
          Popup.Error(
            # Only a simple message because:
            # Either the user has explicitly rejected to install the package,
            # or this error does not happen on a normal system
            # (i.e. a system which is not totally broken or totally messed up).
            Builtins.sformat(
              _("Failed to install required package %1."),
              package_name
            )
          )
          return false
        end
      end
      if "remove" == action
        if !ExecuteBashCommand("rpm -q " + package_name.shellescape)
          Builtins.y2milestone(
            "TestAndInstallPackage: skip remove because %1",
            Ops.get_string(@result, "stdout", "package is not installed")
          )
          return true
        else
          if !Popup.ContinueCancel(
              Builtins.sformat(
                # where %1 will be replaced by the package name
                # when removing package %1 would break dependencies.
                _("Remove package %1?"),
                package_name
              ) # Body of a Popup::ContinueCancel
            )
            # Therefore we exit here but with "false" because
            # the request to remove the package was not done.
            return false
          end
        end
        # Intentionally Package::Remove(package_name) is not used here
        # because it does additionally remove whatever other packages
        # for example to "automatically solve" existing package conflicts
        # without any dialog where the user could accept or reject additional removals
        # (the user may have intentionally accepted whatever package conflict).
        # Furthermore Package::Remove(package_name) does additionally install
        # whatever other packages for example to "automatically solve" whatever
        # kind of soft requirements (Recommends) for other packages.
        # I am only interested to remove exactly the one package which was specified and
        # I am not interested to get whatever replacement package installed automatically
        # because alternatives and/or substitutes would be handled in the upper-level functions
        # (e.g. in the user dialogs) which call TestAndInstallPackage.
        # Usually (i.e. in a openSUSE standard system) the packages which are removed here
        # do not have dependencies or the calling function removes dependant packages
        # in the right order (e.g. first hplip and then hplip-hpijs, see driveradd.ycp)
        # but the user might have installed whatever third-party packages
        # which could have dependencies to the package which should be removed here.
        # Therefore there is a test if the removal would break RPM dependencies
        # but intentionally it is not tested whether the removal
        # would "break" whatever kind of soft requirements (Recommends).
        if !ExecuteBashCommand("rpm -e --test " + package_name.shellescape)
          # Therefore the exact RPM message is shown via a separated Popup::ErrorDetails.
          Popup.ErrorDetails(
            Builtins.sformat(
              # where %1 will be replaced by the package name.
              _("Removing package %1 would break dependencies."),
              package_name
            ), # Message of a Popup::ErrorDetails
            Ops.get_string(@result, "stderr", "")
          )
          if !Popup.ContinueCancelHeadline(
              Builtins.sformat(
                # where %1 will be replaced by the package name
                # when removing package %1 would break dependencies.
                _("Remove %1 regardless of breaking dependencies?"),
                package_name
              ), # Header of a Popup::ContinueCancelHeadline
              # Body of a Popup::ContinueCancelHeadline
              # when removing package %1 would break dependencies.
              _("Breaking dependencies leads to arbitrary failures elsewhere.")
            )
            # Therefore we exit here but with "false" because removing the package failed.
            return false
          end
        end
        if !ExecuteBashCommand("rpm -e --nodeps " + package_name.shellescape)
          Builtins.y2milestone(
            "TestAndInstallPackage: Failed to remove package %1.",
            package_name
          )
          Popup.ErrorDetails(
            Builtins.sformat(
              # where %1 will be replaced by the package name.
              # Only a simple message because this error does not happen on a normal system.
              _("Failed to remove package %1."),
              package_name
            ), # Message of a Popup::ErrorDetails
            Ops.get_string(@result, "stderr", "")
          )
          return false
        end
      end
      true
    end

    def GetAndSetCupsdStatus(new_status)
      # The value 'false' is also the right one when the command itself fails
      # (e.g. when there is no /usr/bin/lpstat binary or whatever broken stuff).
      # Since CUPS 1.4 'lpstat -r' results true even when scheduler is not running.
      # Therefore we must now grep in its output:
      local_cupsd_accessible_commandline = "/usr/bin/lpstat -h localhost -r | grep -q 'scheduler is running'"
      @local_cupsd_accessible = ExecuteBashCommand(
        local_cupsd_accessible_commandline
      )
      # Start cupsd:
      if "start" == new_status
        return true if @local_cupsd_accessible
        # Enforce user confirmation before a new service is started
        # to be on the safe side that the user knows about it:
        if !Popup.YesNoHeadline(
            _("Start locally running CUPS daemon"),
            # PopupYesNoHeadline body:
            _("A locally running CUPS daemon is needed.")
          )
          return false
        end
        if !Service.Start("cups")
          Popup.ErrorDetails(
            _("Failed to start the CUPS daemon"),
            Service.Error
          )
          return false
        end
        # Sleep one second in any case so that the new started cupsd can become ready to operate:
        Builtins.sleep(1000)
        # Wait half a minute for a new started cupsd is necessary because
        # when a client-only config is switched to a "get Browsing info" config
        # the BrowseInterval in cupsd.conf on remote CUPS servers is by default 30 seconds
        # so that the local cupsd should listen at least 31 seconds to get Browsing info
        # before e.g. the Overview dialog can be shown with the right current queues.
        Popup.TimedMessage(
          _(
            "Started the CUPS daemon.\nWaiting half a minute for the CUPS daemon to get ready to operate...\n"
          ),
          30
        )
        @local_cupsd_accessible = ExecuteBashCommand(
          local_cupsd_accessible_commandline
        )
        if !@local_cupsd_accessible
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
        @local_cupsd_accessible = ExecuteBashCommand(
          local_cupsd_accessible_commandline
        )
        if !@local_cupsd_accessible
          Popup.Error(_("No locally running CUPS daemon is accessible."))
          return false
        end
        if !Service.Enable("cups")
          Popup.ErrorDetails(
            _("Failed to enable starting of the CUPS daemon during system boot"),
            Service.Error
          )
          # This is not a fatal error, therefore return "successfully" nevertheless.
        end
        return true
      end
      # Restart cupsd:
      if "restart" == new_status
        # to be on the safe side regarding complaints in an enterprise environment
        # because a restart disrupts all currently actively printing jobs:
        if !Popup.YesNoHeadline(
            _("Restart locally running CUPS daemon"),
            # PopupYesNoHeadline body:
            _("A restart disrupts all currently active print jobs.")
          )
          return false
        end
        if !Service.Restart("cups")
          Popup.ErrorDetails(
            _("Failed to restart the CUPS daemon"),
            Service.Error
          )
          return false
        end
        # Sleep two seconds in any case so that the re-started cupsd can become ready to operate.
        # It may need one second for some cleanup before finishing
        # and one second to become ready to operate after starting.
        Builtins.sleep(2000)
        # Wait half a minute for a restarted cupsd is necessary because
        # when a "no Browsing info" config is switched to a "get Browsing info" config
        # the BrowseInterval in cupsd.conf on remote CUPS servers is by default 30 seconds
        # so that the local cupsd should listen at least 31 seconds to get Browsing info
        # before e.g. the Overview dialog can be shown with the right current queues.
        Popup.TimedMessage(
          _(
            "Restarted the CUPS daemon.\nWaiting half a minute for the CUPS daemon to get ready to operate...\n"
          ),
          30
        )
        @local_cupsd_accessible = ExecuteBashCommand(
          local_cupsd_accessible_commandline
        )
        if !@local_cupsd_accessible
          Popup.Error(_("No locally running CUPS daemon is accessible."))
          return false
        end
        # To be on the safe side, ask the user to enable the cupsd
        # to be started during boot if it is not yet enabled:
        if !Service.Enabled("cups")
          if Popup.YesNoHeadline(
              _("Enable starting of the CUPS daemon during system boot"),
              # PopupYesNoHeadline body:
              _("Currently the CUPS daemon is not started during system boot.")
            )
            if !Service.Enable("cups")
              Popup.ErrorDetails(
                _(
                  "Failed to enable starting of the CUPS daemon during system boot"
                ),
                Service.Error
              )
              # This is not a fatal error, therefore return "successfully" nevertheless.
            end
          end
        end
        return true
      end
      # Stop cupsd:
      if "stop" == new_status
        # to be on the safe side regarding complaints in an enterprise environment
        # because a stop disrupts all currently actively printing jobs:
        if !Popup.YesNoHeadline(
            _("Stop locally running CUPS daemon"),
            # PopupYesNoHeadline body:
            _("A stop disrupts all currently active print jobs.")
          )
          return false
        end
        # To be on the safe side try to stop and disable the cupsd
        # regardless if it is accessible or not and/or disabled or not
        # and ignore possible errors from Service::Stop and Service::Disable
        # (the local_cupsd_accessible test below should be sufficient):
        Service.Stop("cups")
        Service.Disable("cups")
        # Wait one second to make sure that cupsd has really finished (it may do some cleanup):
        Builtins.sleep(1000)
        @local_cupsd_accessible = ExecuteBashCommand(
          local_cupsd_accessible_commandline
        )
        if @local_cupsd_accessible
          Popup.Error(_("A locally running CUPS daemon is still accessible."))
          return false
        end
        return true
      end
      # If new_status is neither "start" nor "restart" nor "stop",
      # return whether or not the local cupsd is accessible:
      @local_cupsd_accessible
    end

    def DetermineClientOnly
      if ExecuteBashCommand(@yast_bin_dir + "cups_client_only")
        @client_conf_server_name = Ops.get_string(@result, "stdout", "")
        if "" != @client_conf_server_name &&
            "localhost" != @client_conf_server_name &&
            "127.0.0.1" != @client_conf_server_name
          # which is used to force client tools (e.g. lpadmin, lpinfo, lpstat)
          # to ask the local cupsd via the IPP port on localhost (127.0.0.1:631)
          # and not via the domain socket (/var/run/cups/cups.sock) because
          # the latter failed in the past for certain third-party clients (e.g. Java).
          # If the ServerName value in /etc/cups/client.conf is 'localhost'
          # it is actually no client-only config because the local cupsd is used.
          @client_only = true
          return true
        end
        @client_only = false
        return true
      end
      # The cups_client_only tool failed:
      @client_conf_server_name = Ops.get_string(@result, "stdout", "")
      if "" != @client_conf_server_name &&
          "localhost" != @client_conf_server_name &&
          "127.0.0.1" != @client_conf_server_name
        # cups_client_only fails when the client-only server is not accessible:
        Popup.ErrorDetails(
          # where %1 will be replaced by the server name.
          Builtins.sformat(
            _("The CUPS server '%1' is not accessible."),
            @client_conf_server_name
          ),
          Ops.get_string(@result, "stderr", "")
        )
        @client_only = true
        return false
      end
      if "localhost" == @client_conf_server_name ||
          "127.0.0.1" == @client_conf_server_name
        @client_only = false
        if !GetAndSetCupsdStatus("")
          return false if !GetAndSetCupsdStatus("start")
        end
        return true
      end
      # The cups_client_only tool failed for whatever reason.
      # Use fallback values:
      @client_conf_server_name = ""
      @client_only = false
      true
    end

    def DetermineBrowsing
      if ExecuteBashCommand(@yast_bin_dir + "modify_cupsd_conf Browsing")
        browsing = Builtins.tolower(Ops.get_string(@result, "stdout", "On"))
        if "off" == browsing || "no" == browsing
          @cupsd_conf_browsing_on = false
        else
          @cupsd_conf_browsing_on = true
        end
      else
        @cupsd_conf_browsing_on = true
        return false
      end
      true
    end

    def DetermineBrowseAllow
      if ExecuteBashCommand(@yast_bin_dir + "modify_cupsd_conf BrowseAllow")
        # but possible duplicate BrowseAllow values are not removed in the command output:
        @cupsd_conf_browse_allow = Builtins.toset(
          Builtins.splitstring(Ops.get_string(@result, "stdout", "all"), " ")
        )
      else
        @cupsd_conf_browse_allow = ["all"]
        return false
      end
      true
    end

    def DetermineBrowsePoll
      if ExecuteBashCommand(@yast_bin_dir + "modify_cupsd_conf BrowsePoll")
        # but possible duplicate BrowsePoll values are not removed in the command output:
        @cupsd_conf_browse_poll = Builtins.toset(
          Builtins.splitstring(Ops.get_string(@result, "stdout", ""), " ")
        )
      else
        @cupsd_conf_browse_poll = [""]
        return false
      end
      true
    end

    # Up to CUPS 1.3 cupsd writes changes to config files immediately so that the updated files
    # will be available after the corresponding command, function call, or IPP operation is completed.
    # Since CUPS 1.4 the new DirtyCleanInterval directive controls the delay when cupsd updates config files,
    # which defaults to 30 seconds. Setting it to 0 will have it write the changes on the next pass through
    # the main run loop - less immediate than before, but still should be within a few milliseconds.
    # To be on the safe side regarding "within a few milliseconds" (which could become much more
    # depending on which processes the scheduler lets run - in particular cupsd versus yast2-printer)
    # it sleeps in any case at least one second:
    def WaitForUpdatedConfigFiles(popupheader)
      # and then the default delay until cupsd writes config files like printers.conf
      # is 30 seconds which is also used here as fallback.
      dirty_clean_interval = 30
      # In openSUSE 11.2 there will be most likely still CUPS 1.3.x
      # where the above 30 seconds fallback would result needless waiting.
      # To avoid needless waiting there is a fail-safe test if CUPS 1.3.x is used
      # and if yes, the matching 0 seconds value is used.
      # Note the YCP quoting: \\. becomes \. in the commandline.
      if ExecuteBashCommand("cups-config --version | grep -q '^1\\.3'")
        dirty_clean_interval = 0
      end
      # Determine the DirtyCleanInterval value in /etc/cups/cupsd.conf:
      if ExecuteBashCommand(@yast_bin_dir + "modify_cupsd_conf DirtyCleanInterval")
        # the latter would require 'import "Printer"' but Printer does already 'import "Printerlib"'
        # and a cyclic import drives the YaST machinery mad (it collapses with "too many open files"):
        dirty_clean_interval_string = Builtins.filterchars(
          Ops.get_string(@result, "stdout", "30"),
          "0123456789"
        )
        if "" != dirty_clean_interval_string &&
            nil != Builtins.tointeger(dirty_clean_interval_string)
          dirty_clean_interval = Builtins.tointeger(dirty_clean_interval_string)
        end
        # Use the above defined fallback value 30 or the CUPS 1.3.x value 0
        # when there is no DirtyCleanInterval entry (this applies also for CUPS 1.3.x)
        # or when the DirtyCleanInterval value cannot be converted to an integer.
      end
      # Use fallback cupsd_conf_dirty_clean_interval value when the command above failed.
      Builtins.y2milestone(
        "Waiting DirtyCleanInterval='%1'+1 seconds for updated config files.",
        dirty_clean_interval
      )
      if Ops.less_than(dirty_clean_interval, 1)
        # be on the safe side and sleep one second but without user notification:
        Builtins.sleep(1000)
        return true
      end
      # Let impatient users interrupt the waiting for updated config files.
      # E.g. when several queues should be added or modified there is no need
      # to annoy the user with enforced waiting again and again for each queue.
      # Return true if the user did not interrupt the waiting for updated config files
      # but return false if the user interrupted the waiting for updated config files.
      # To be on the safe side sleep one second longer than the dirty_clean_interval.
      max_waiting_time = Ops.add(dirty_clean_interval, 1)
      waited_time = 0

      UI.OpenDialog(
        VBox(
          Label(popupheader),
          ProgressBar(
            Id("wait_for_updated_config_files_progress_bar"),
            # Label for a ProgressBar while waiting for updated config files:
            _("Updating configuration files..."),
            max_waiting_time,
            waited_time
          ),
          Right(
            PushButton(
              Id("skip_waiting_for_updated_config_files"),
              # Label for a PushButton to skip waiting for updated config files:
              _("&Skip waiting")
            )
          )
        )
      )
      while Ops.less_than(waited_time, max_waiting_time)
        user_input = Convert.to_string(UI.TimeoutUserInput(1000))
        # Break waiting loop if the user wants to skip waiting for updated config files:
        break if "skip_waiting_for_updated_config_files" == user_input
        # Otherwise update the progress bar and loop to wait one more second for user input:
        waited_time = Ops.add(waited_time, 1)
        UI.ChangeWidget(
          Id("wait_for_updated_config_files_progress_bar"),
          :Value,
          waited_time
        )
      end
      UI.CloseDialog
      if Ops.less_than(waited_time, dirty_clean_interval)
        # when the waiting_time is strictly less than the dirty_clean_interval.
        # Don't show a warning popup here.
        # A specific warning popup is shown by the caller in basicadd.ycp and basicmodify.ycp.
        return false
      end
      true
    end

    # Determine if any kind of firewall seems to be active by calling
    # "iptables -n -L | grep -E -q 'DROP|REJECT'"
    # to find out if there are currently dropping or rejecting packet filter rules.
    # One might use a more specific test via
    # "iptables -n -L | grep -v '^LOG' | grep -E -q '^DROP|^REJECT'"
    # to match only for DROP and REJECT targets and exclude LOG targets
    # but it does not cause real problems when there is a false positive result here
    # because all what happens it that then a needless firewall info popup would be shown.
    def FirewallSeemsToBeActive
      if ExecuteBashCommand("iptables -n -L | grep -E -q 'DROP|REJECT'")
        Builtins.y2milestone("A firewall seems to be active.")
        return true
      end
      # Return 'false' also as fallback value when the above command fails
      # because of whatever reason because this fallback value is safe
      # because it only results that no firewall info popup is shown
      # the "Print via Network" and/or "Share Printers" dialogs
      # but also the help text of those dialogs explains firewall stuff
      # so that sufficient information is available in any case:
      false
    end

    publish :variable => :yast_bin_dir, :type => "string"
    publish :variable => :result, :type => "map"
    publish :function => :ExecuteBashCommand, :type => "boolean (string)"
    publish :function => :TestAndInstallPackage, :type => "boolean (string, string)"
    publish :variable => :local_cupsd_accessible, :type => "boolean"
    publish :function => :GetAndSetCupsdStatus, :type => "boolean (string)"
    publish :variable => :client_conf_server_name, :type => "string"
    publish :variable => :client_only, :type => "boolean"
    publish :function => :DetermineClientOnly, :type => "boolean ()"
    publish :variable => :cupsd_conf_browsing_on, :type => "boolean"
    publish :function => :DetermineBrowsing, :type => "boolean ()"
    publish :variable => :cupsd_conf_browse_allow, :type => "list <string>"
    publish :function => :DetermineBrowseAllow, :type => "boolean ()"
    publish :variable => :cupsd_conf_browse_poll, :type => "list <string>"
    publish :function => :DetermineBrowsePoll, :type => "boolean ()"
    publish :function => :WaitForUpdatedConfigFiles, :type => "boolean (string)"
    publish :function => :FirewallSeemsToBeActive, :type => "boolean ()"
  end

  Printerlib = PrinterlibClass.new
  Printerlib.main
end

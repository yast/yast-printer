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

# File:        include/printer/helps.ycp
# Package:     Configuration of printer
# Summary:     Help texts of all the dialogs
# Authors:     Johannes Meixner <jsmeix@suse.de>

module Yast
  module PrinterHelpsInclude
    def initialize_printer_helps(include_target)
      textdomain "printer"

      # All helps are here
      @HELPS = {
        "read" =>
          # Read dialog help 1/1:
          _(
            "<p>\n" +
              "<b><big>Initializing printer Configuration</big></b><br>\n" +
              "</p>\n"
          ),
        "write" =>
          # Write dialog help 1/1:
          _(
            "<p>\n" +
              "<b><big>Finishing printer Configuration</big></b><br>\n" +
              "</p>\n"
          ),
        "overview" =>
          # Overview dialog help 1/7:
          _(
            "<p>\n" +
              "<b><big>Print Queue Overview</big></b><br>\n" +
              "A printer device is not used directly but via a print queue.<br>\n" +
              "When various applications submit print jobs simultaneously,\n" +
              "these jobs are put in a queue and are sent one after the other to the printer\n" +
              "device.<br>\n" +
              "It is possible to have several different print queues for the same printer\n" +
              "device.\n" +
              "For example a second queue with a monochrome-only driver for a color device\n" +
              "or a PostScript queue and a queue with a PCL driver for a PostScript+PCL printer.\n" +
              "</p>\n"
          ) +
            # Overview dialog help 2/7:
            _(
              "<p>\n" +
                "<b><big>Using Remote Queues:</big></b><br>\n" +
                "Remote queues exist on other hosts in the network,\n" +
                "therefore they cannot be changed on this host.<br>\n" +
                "The remote queues listed here are known on this host.\n" +
                "Usually they can be used directly by applications\n" +
                "so there is no need to set up a local queue for a printer\n" +
                "that is already available via a remote queue.<br>\n" +
                "</p>\n"
            ) +
            # Overview dialog help 3/7:
            _(
              "<p>\n" +
                "<b><big>Configure a printer:</big></b><br>\n" +
                "Press <b>Add</b> to set up a new queue for a printer device.\n" +
                "</p>"
            ) +
            # Overview dialog help 4/7:
            _(
              "<p>\n" +
                "<b><big>Change the settings for a queue:</big></b><br>\n" +
                "Select a local queue and press <b>Edit</b>.\n" +
                "</p>"
            ) +
            # Overview dialog help 5/7:
            _(
              "<p>\n" +
                "<b><big>Remove a queue:</big></b><br>\n" +
                "Select a local queue and press <b>Delete</b>.\n" +
                "</p>"
            ) +
            # Overview dialog help 6/7:
            _(
              "<p>\n" +
                "<b><big>Print a test page:</big></b><br>\n" +
                "Select the queue and press <b>Print Test Page</b>.\n" +
                "</p>"
            ) +
            # Overview dialog help 7/7:
            _(
              "<p>\n" +
                "<b><big>Refresh the list of queues:</big></b><br>\n" +
                "After changes to the network printing settings,\n" +
                "the available remote queues may have changed.\n" +
                "Usually it takes some time (up to several minutes)\n" +
                "until such changes become known to the local host.\n" +
                "Press <b>Refresh List</b> after some time to get an \n" +
                "up-to-date list of available remote queues.\n" +
                "</p>\n"
            ),
        "AutoYaSToverview" =>
          # AutoYaST Overview dialog help 1/1:
          _(
            "<p>\n" +
              "<b><big>AutoYaST Print Queue Overview</big></b><br>\n" +
              "AutoYaST supports only settings for printing with CUPS via network.<br>\n" +
              "There is no AutoYaST support to set up local print queues.\n" +
              "</p>"
          ),
        "basic_add_dialog" =>
          # BasicAddDialog help 1/7:
          _(
            "<p>\n" +
              "<b><big>Set Up a New Queue for a Printer Device</big></b><br>\n" +
              "A printer device is not used directly but via a print queue.<br>\n" +
              "When various application programs submit print jobs simultaneously,\n" +
              "the jobs queue up and are sent one after the other to the printer device.<br>\n" +
              "It is possible to have several different print queues for the same printer device.\n" +
              "Usually several print queues are needed when several different printer drivers\n" +
              "should be used for the same printer device.\n" +
              "For example a second queue with a monochrome-only driver\n" +
              "to enforce black-only printout on a color device\n" +
              "or a PostScript queue and a queue with a PCL driver for a PostScript+PCL printer\n" +
              "because printing via the PCL driver is usually faster (but with less quality).\n" +
              "</p>"
          ) +
            # BasicAddDialog help 2/7:
            _(
              "<p>\n" +
                "To set up a new queue:<br>\n" +
                "Select the connection of the matching printer device,<br>\n" +
                "find and assign a suitable printer driver, and<br>\n" +
                "set a unique queue name.\n" +
                "</p>"
            ) +
            # BasicAddDialog help 3/7:
            _(
              "<p>\n" +
                "The <b>connection</b> determines which way data is sent to the printer device.<br>\n" +
                "If a wrong connection is selected, no data can be sent to the device\n" +
                "so that there cannot be any printout.<br>\n" +
                "If a printer device is accessible via more than one connection type,\n" +
                "it is shown for each connection type.<br>\n" +
                "In particular HP devices are often accessible both via the 'usb:/...'\n" +
                "and the 'hp:/...' connection.\n" +
                "The latter is provided by the HP driver package 'hplip'.\n" +
                "For plain printing, both kinds of connections should work, but for anything else\n" +
                "(e.g. device status via 'hp-toolbox' or scanning with a HP all-in-one device)\n" +
                "the 'hp:/...' connection must be used.\n" +
                "</p>\n"
            ) +
            # BasicAddDialog help 4/7:
            _(
              "<p>\n" +
                "The <b>driver</b> determines that the right data is produced for the\n" +
                "specific printer model.<br>\n" +
                "If a wrong driver is assigned, wrong data is sent to the printer\n" +
                "which results bad looking printout, chaotic printout, or no printout at all.<br>\n" +
                "Initially the input field for the driver search string is preset\n" +
                "with the autodetected model name of the currently selected connection\n" +
                "and those drivers where the driver description matches to the model name\n" +
                "are shown by default.<br>\n" +
                "If driver descriptions match to the autodetected model name\n" +
                "and if all matching driver descriptions seem to belong to the same model,\n" +
                "the driver descriptions are sorted so that the most reasonable driver\n" +
                "should be listed topmost and this one is automatically preselected.\n" +
                "If no driver is automatically preselected, you must manually\n" +
                "find and select an appropriate driver.<br>\n" +
                "On the other hand if a driver was automatically preselected,\n" +
                "it does not necessarily mean that this driver is\n" +
                "a reasonable driver for your particular needs.\n" +
                "Strictly speaking an automatically preselected driver\n" +
                "may not work at all for your particular printer model.\n" +
                "The reason is that the automated driver selection\n" +
                "can only work based upon comparison of strings\n" +
                "(the autodetected model name and the driver descriptions)\n" +
                "so that the result can be only a best-guess proposal\n" +
                "how to set up your particular printer model.<br>\n" +
                "Therefore check if the currently preselected values make sense\n" +
                "and feel free to play around and modify the settings\n" +
                "to what you know what works best for your printer.<br>\n" +
                "If no driver description matches to the autodetected model name,\n" +
                "it does not necessarily mean that there is no driver available for the model.\n" +
                "Often only the model name in the driver descriptions\n" +
                "is different from the autodetected model name.\n" +
                "Therefore you can enter whatever you like as driver search string\n" +
                "and search through all available driver descriptions.<br>\n" +
                "Usually the default driver option settings should be reasonable\n" +
                "so that the driver works for your particular printer model.\n" +
                "Some driver option settings must match to your particular printer.\n" +
                "In particular the default paper size setting of the driver\n" +
                "must match to the paper which is actually loaded in your printer.\n" +
                "You can either explicitly select A4 or Letter as default paper size\n" +
                "or select nothing to use the built-in default paper size of the driver\n" +
                "which is also the fallback if the driver neither supports A4 nor Letter\n" +
                "(for example a driver for a small-format photo printer).\n" +
                "If you like to adjust other driver options except A4 or Letter,\n" +
                "you must first set up the queue and then in a second step\n" +
                "you can adjust all driver options in the 'Edit/Modify' dialog.\n" +
                "</p>"
            ) +
            # BasicAddDialog help 5/7:
            _(
              "<p>\n" +
                "Application programs do not show the actual printer device\n" +
                "but its associated <b>queue name</b>.<br>\n" +
                "Only letters (a-z and A-Z), numbers (0-9), and the underscore '_'\n" +
                "are allowed for the queue name and it must start with a letter.\n" +
                "</p>"
            ) +
            # BasicAddDialog help 6/7:
            _(
              "<p>\n" +
                "One of the print queues may be set to be <b>used by default</b>.<br>\n" +
                "Application programs should use such a system default print queue\n" +
                "if no other print queue was specified by the user.\n" +
                "But there is no such thing as the 'one and only' default queue.\n" +
                "Beside a system default queue any user can maintain his own\n" +
                "default queue setting and furthermore any application program\n" +
                "may implement its own particular way of default queue setting\n" +
                "(e.g. the application may remember the previously used queue).<br>\n" +
                "For details see the openSUSE support database\n" +
                "article 'Print Settings with CUPS' at<br>\n" +
                "http://en.opensuse.org/SDB:Print_Settings_with_CUPS\n" +
                "</p>"
            ) +
            # BasicAddDialog help 7/7:
            _(
              "<p>\n" +
                "An alternative way to set up HP devices is to <b>run hp-setup</b>.<br>\n" +
                "HP's own tool 'hp-setup' provides setup support in particular\n" +
                "for HP printers and HP all-in-one devices which require\n" +
                "a proprietary driver plugin to be downloaded from HP and\n" +
                "installed in the right way on a particular end-user's system.\n" +
                "Furthermore 'hp-setup' can provide better setup support\n" +
                "for HP network printers and HP all-in-one network devices\n" +
                "because HP's own tool can implement special handling\n" +
                "for special HP network devices.<br>\n" +
                "For details see the openSUSE support database\n" +
                "article 'How to set-up a HP printer' at<br>\n" +
                "http://en.opensuse.org/SDB:How_to_set-up_a_HP_printer\n" +
                "</p>"
            ),
        "basic_modify_dialog" =>
          # BasicModifyDialog help 1/4:
          _(
            "<p>\n" +
              "<b><big>Modify a Print Queue</big></b><br>\n" +
              "To modify a queue, select only what you really want to be changed.<br>\n" +
              "</p>"
          ) +
            # BasicModifyDialog help 2/4:
            _(
              "<p>\n" +
                "The <b>connection</b> determines how data is sent to the printer device.<br>\n" +
                "If a wrong connection is selected, no data can be sent to the device\n" +
                "so that there cannot be any printout.<br>\n" +
                "If a printer device is accessible via more than one connection type,\n" +
                "it is shown for each connection type.<br>\n" +
                "In particular HP devices are often accessible both via the 'usb:/...'\n" +
                "and the 'hp:/...' connection.\n" +
                "The latter is provided by the HP driver package 'hplip'.\n" +
                "For plain printing, both kinds of connections should work, but for anything else\n" +
                "(e.g. device status via 'hp-toolbox' or scanning with a HP all-in-one device)\n" +
                "the 'hp:/...' connection must be used.<br>\n" +
                "When you exchange the currently used connection with another one,\n" +
                "the input field for the driver search string is preset\n" +
                "with the autodetected model name of the new selected connection.\n" +
                "The drivers for which the driver description matches the model name\n" +
                "are shown by default.<br>\n" +
                "If driver descriptions match the autodetected model name\n" +
                "and if all matching driver descriptions seem to belong to the same model,\n" +
                "the driver descriptions are sorted so that the most reasonable driver\n" +
                "should be listed topmost (but still below the currently used driver).\n" +
                "On the other hand, it does not necessarily mean that this driver is\n" +
                "a reasonable driver for your particular needs.\n" +
                "The topmost listed driver may not work at all for your particular \n" +
                "printer model. The automated driver selection\n" +
                "compares strings (the autodetected model name and the driver \n" +
                "descriptions) so the result can only be a best-guess proposal\n" +
                "how to set up your particular printer model.<br>\n" +
                "Therefore check if the currently preselected values make sense.\n" +
                "Feel free to play around and modify the settings\n" +
                "to what you know works best for your printer.<br>\n" +
                "If no driver description matches the autodetected model name, it does \n" +
                "not necessarily mean that there is no driver available for the model.\n" +
                "Often the model name in the driver descriptions\n" +
                "is different from the autodetected model name.\n" +
                "Therefore you can enter whatever you like as driver search string\n" +
                "and search through all available driver descriptions.\n" +
                "</p>\n"
            ) +
            # BasicModifyDialog help 3/4:
            _(
              "<p>\n" +
                "The <b>driver</b> determines that the right data is produced for the\n" +
                "specific printer model.<br>\n" +
                "If a wrong driver is assigned, wrong data is sent to the printer\n" +
                "which results bad looking printout, chaotic printout, or no printout at all.<br>\n" +
                "You can either select another driver and modify its driver option settings later\n" +
                "or keep the currently used driver and modify its driver option settings now.<br>\n" +
                "Some driver option settings must match to your particular printer.\n" +
                "For example the default paper size setting of the driver\n" +
                "must match to the paper which is actually loaded in your printer.<br>\n" +
                "For other driver option settings you can choose what you like.\n" +
                "For example any choice of the available printing resolutions\n" +
                "should work for the particular driver.\n" +
                "Nevertheless it may happen that your particular printer fails to print\n" +
                "with high resolution. For example when you have a laser printer\n" +
                "which has insufficient built-in memory to process high resolution pages.<br>\n" +
                "When you exchange the currently used driver by another one,\n" +
                "you must first apply this change to the print queue\n" +
                "so that the new driver is used for the queue\n" +
                "(i.e. you must finish this dialog as a first step)\n" +
                "and then in a second step you can adjust all driver options\n" +
                "by using this dialog again.<br>\n" +
                "Initially the input field for the driver search string is preset\n" +
                "with the description of the currently used driver when the connection was not changed.\n" +
                "This results usually only one single driver which matches\n" +
                "so that you would have to enter a less specific driver search string\n" +
                "to get also other drivers or you use the 'Find More' button.\n" +
                "If no driver matches, it does not mean that there is no driver available.\n" +
                "Therefore you can enter whatever you like as driver search string\n" +
                "and search through all available driver descriptions.\n" +
                "</p>"
            ) +
            # BasicModifyDialog help 4/4:
            _(
              "<p>\n" +
                "In contrast to connection and driver where you must select the right one,\n" +
                "you are free to enter arbitrary strings for <b>description</b> and <b>location</b>.\n" +
                "Application programs often show description and location in the print dialog.\n" +
                "To make sure that those strings look correct in any language\n" +
                "which a particular user of a particular application program may use,\n" +
                "it is safe when you use only plain ASCII text without\n" +
                "special characters e.g. only ASCII letters (a-z and A-Z),\n" +
                "ASCII numbers (0-9), and the ASCII space character (20 hex).\n" +
                "Usually the description describes the model and optionally the driver\n" +
                "(e.g. 'ACME FunPrinter 1000 using generic PCL driver')\n" +
                "and the location describes where the printer is located\n" +
                "(e.g. 'Room 123' or 'Front Desk').\n" +
                "</p>"
            ),
        "driver_options_dialog" =>
          # DriverOptionsDialog help 1/3:
          _(
            "<p>\n" +
              "<b><big>Set Driver Options</big></b><br>\n" +
              "Usually it is best to leave the driver defaults because\n" +
              "the defaults should be reasonable for most cases.<br>\n" +
              "Additionally, the print dialogs in most applications\n" +
              "show the driver options too so that each user can specify\n" +
              "driver options for each individual printout.<br>\n" +
              "The only setting which should be checked in any case is the paper size,\n" +
              "which must be set to what is actually used by default in the printer.\n" +
              "</p>\n"
          ) +
            # DriverOptionsDialog help 2/3:
            _(
              "<p>\n" +
                "Non-default settings may not work in all cases or have unexpected\n" +
                "consequences.<br> \n" +
                "For example, a high resolution setting may not work for a laser printer\n" +
                "when its default built-in memory is insufficient to process high resolution\n" +
                "pages.<br> \n" +
                "Or a high quality setting may print intolerably slow on an inkjet printer.\n" +
                "</p>\n"
            ) +
            # DriverOptionsDialog help 3/3:
            _(
              "<p>\n" +
                "In certain cases printer-specific driver settings\n" +
                "must be adjusted to get the full functionality of a printer.<br>\n" +
                "In particular, when the printer has optional units installed like\n" +
                "a duplex unit or optional paper feeders, the respective driver settings\n" +
                "should be checked and adjusted.<br>\n" +
                "For example, a duplex unit option must be set to 'installed' or 'true'\n" +
                "otherwise the driver may ignore duplex printing option settings.\n" +
                "</p>\n"
            ),
        "add_driver_dialog" =>
          # AddDriverDialog help 1/2:
          _(
            "<p>\n" +
              "<b><big>Add or Remove Printer Driver Packages</big></b><br>\n" +
              "If a printer driver package is not marked, it is not installed.\n" +
              "Select the package if you want to install it.<br>\n" +
              "If a printer driver package is marked, it is installed.\n" +
              "Deselect the package if you want to remove it.\n" +
              "In the latter case, make sure that there is no printer configuration \n" +
              "which needs the driver.<br>\n" +
              "</p>\n"
          ) +
            # AddDriverDialog help 2/2:
            _(
              "<p>\n" +
                "<b><big>Add a Printer Description File</big></b><br>\n" +
                "To set up a printer configuration, a printer description file\n" +
                "(PPD file) is required.<br>\n" +
                "If a PPD file is not located in the /usr/share/cups/model/ directory,\n" +
                "it is not available to set up a printer configuration with it.\n" +
                "Therefore you can specify the full path of a PPD file,\n" +
                "which is located elsewhere on your system, to get it installed\n" +
                "in the /usr/share/cups/model/ directory.<br>\n" +
                "Note that a printer description file is not a driver.<br>\n" +
                "For non-PostScript printers the PPD file alone is\n" +
                "not sufficient to set up a working printer configuration.\n" +
                "In particular, it does not work for non-PostScript printers\n" +
                "to download a PPD file from the Internet and then set up\n" +
                "the printer with such a PPD file.\n" +
                "The plain printer setup would work but actual printing\n" +
                "would not work because the driver would be missing.\n" +
                "For non-PostScript printers, you need a printer driver\n" +
                "and a PPD file which matches exactly the particular driver.\n" +
                "Matching PPD files are automatically installed at the right place\n" +
                "when you install the above mentioned printer driver packages.<br>\n" +
                "Only for PostScript printers, a PPD file alone is usually\n" +
                "sufficient to set up a working PostScript printer configuration.\n" +
                "In particular, it is sufficient when the PPD file does not\n" +
                "contain a 'cupsFilter' entry because such an entry would\n" +
                "reference a printer driver.<br>\n" +
                "</p>\n"
            ),
        "connection_wizard_dialog" =>
          # ConnectionWizardDialog help 1/7:
          _(
            "<p>\n" +
              "<b><big>Specify the Connection</big></b><br>\n" +
              "The <b>connection</b> determines how data is sent to the printer device.<br>\n" +
              "If a wrong connection is used, no data can be sent to the device\n" +
              "so that there cannot be any printout.\n" +
              "</p>\n"
          ) +
            # ConnectionWizardDialog help 2/7:
            _(
              "<p>\n" +
                "<b><big>Printer Device URI</big></b><br>\n" +
                "A connection is specified as so called <b>device URI</b>.<br>\n" +
                "Its first word (the so called URI scheme) specifies the kind of data-transfer,\n" +
                "for example 'usb', 'socket', 'lpd', or 'ipp'.<br>\n" +
                "After the scheme there are more or less additional components\n" +
                "which specify the details for this kind of data-transfer.<br>\n" +
                "Space characters are not allowed in an URI.\n" +
                "Therefore a space character in a value of an URI component\n" +
                "is encoded as '%20' (20 is the hexadecimal value of the space character).<br>\n" +
                "The components of an URI are separated by special reserved characters like\n" +
                "colon ':', slash '/', question mark '?', ampersand '&amp;', or equals sign '='.<br>\n" +
                "Finally there could be optional parameters (separated by a question mark '?')\n" +
                "of the form 'option1=value1&amp;option2=value2&amp;option3=value3' so that\n" +
                "a full device URI could be for example:<br>\n" +
                "ipp://server.domain:631/printers/queuename?waitjob=false&amp;waitprinter=false<br>\n" +
                "Some examples:<br>\n" +
                "A USB printer model 'Fun Printer 1000+' made by 'ACME'\n" +
                "with serial number 'A1B2C3' may have a device URI like:<br>\n" +
                "usb://ACME/Fun%20Printer%201000%2B?serial=A1B2C3<br>\n" +
                "A network printer with IP 192.168.100.1 which is accessible\n" +
                "via port 9100 may have a device URI like:<br>\n" +
                "socket://192.168.100.1:9100<br>\n" +
                "A network printer with IP 192.168.100.2 which is accessible\n" +
                "via LPD protocol with a remote LPD queue name 'LPT1'\n" +
                "may have a device URI like:<br>\n" +
                "lpd://192.168.100.2/LPT1\n" +
                "</p>"
            ) +
            # ConnectionWizardDialog help 3/7:
            _(
              "<p>\n" +
                "<b><big>Percent Encoding</big></b><br>\n" +
                "The issue is complicated.\n" +
                "It is recommended to avoid reserved characters and spaces\n" +
                "for component values in URIs if the values are under your control\n" +
                "(e.g. you cannot avoid it when you must specify such characters\n" +
                "in values for an URI to access a remote print queue\n" +
                "but the remote print queue is not under your control).\n" +
                "Whenever possible use only so called 'unreserved characters'.\n" +
                "Unreserved characters are uppercase and lowercase letters,\n" +
                "decimal digits, hyphen, period, underscore, and tilde.\n" +
                "Even hyphen, period, tilde, and case sensitivity\n" +
                "could cause special issues in special cases\n" +
                "(e.g. only letters, digits, and underscore are known to work\n" +
                "for a CUPS print queue name and case is not significant there).\n" +
                "Therefore it is best to use only lowercase letters, digits,\n" +
                "and underscore for all values in all URIs if possible.<br>\n" +
                "Reserved characters and space characters in the value of a component\n" +
                "must be percent-encoded (also known as URL encoding).<br>\n" +
                "When an input field in the dialog is intended to enter\n" +
                "only a single value for a single component of the URI\n" +
                "(e.g. separated input fields for username and password),\n" +
                "you must enter spaces and reserved characters literally\n" +
                "(i.e. non-percent-encoded).\n" +
                "For such input fields all spaces and reserved characters\n" +
                "will be automatically percent-encoded.\n" +
                "For example if a password is actually 'Foo%20Bar' (non-percent-encoded),\n" +
                "it must be entered literally in the password input field in the dialog.\n" +
                "The automated percent-encoding results 'Foo%2520Bar' which is how\n" +
                "the value of the password component is actually stored in the URI.<br>\n" +
                "In contrast when an input field in the dialog is intended to enter\n" +
                "more that a single value for a single component of the URI\n" +
                "(e.g. a single input field for all optional parameters\n" +
                "like 'option1=value1&amp;option2=value2&amp;option3=value3'\n" +
                "or a single input field to enter the whole URI),\n" +
                "you must enter spaces and reserved characters percent-encoded\n" +
                "because an automated percent-encoding is no longer possible.\n" +
                "Assume in an optional parameter 'option=value'\n" +
                "the value would be 'this&amp;that' so that the whole\n" +
                "optional parameter would be 'option=this&amp;that' (literally).\n" +
                "But a literal '&amp;' character denotes\n" +
                "the separation of different optional parameters\n" +
                "so that 'option=this&amp;that' in an URI means\n" +
                "a first optional parameter 'option=this' and\n" +
                "a second optional parameter which is only 'that'.\n" +
                "Therefore a single optional parameter 'option=this&amp;that'\n" +
                "must be entered percent-encoded as 'option=this%26that'<br>\n" +
                "Input fields which require percent-encoded input\n" +
                "are denoted by a '[percent-encoded]' hint.<br>\n" +
                "Listing of characters and their percent encoding:<br>\n" +
                "space ' ' is percent encoded as %20<br>\n" +
                "exclamation mark ! is percent encoded as %21<br>\n" +
                "number sign # is percent encoded as %23<br>\n" +
                "Dollar sign $ is percent encoded as %24<br>\n" +
                "percentage % is percent encoded as %25<br>\n" +
                "ampersand &amp; is percent encoded as %26<br>\n" +
                "apostrophe / single quotation mark ' is percent encoded as %27<br>\n" +
                "left parenthesis ( is percent encoded as %28<br>\n" +
                "right parenthesis ) is percent encoded as %29<br>\n" +
                "asterisk * is percent encoded as %2A<br>\n" +
                "plus sign + is percent encoded as %2B<br>\n" +
                "comma , is percent encoded as %2C<br>\n" +
                "slash / is percent encoded as %2F<br>\n" +
                "colon : is percent encoded as %3A<br>\n" +
                "semicolon ; is percent encoded as %3B<br>\n" +
                "equals sign = is percent encoded as %3D<br>\n" +
                "question mark ? is percent encoded as %3F<br>\n" +
                "at sign @ is percent encoded as %40<br>\n" +
                "left bracket [ is percent encoded as %5B<br>\n" +
                "right bracket ] is percent encoded as %5D<br>\n" +
                "For details see 'Uniform Resource Identifier (URI): Generic Syntax' at<br>\n" +
                "http://tools.ietf.org/html/rfc3986\n" +
                "</p>"
            ) +
            # ConnectionWizardDialog help 4/7:
            _(
              "<p>\n" +
                "<b><big>Device URIs for Directly Connected Devices</big></b><br>\n" +
                "Devices which are connected via USB\n" +
                "are autodetected and the appropriate device URI is autogenerated.\n" +
                "For example:<br>\n" +
                "usb://ACME/Fun%20Printer?serial=A1B2C3<br>\n" +
                "hp:/usb/HP_LaserJet?serial=1234<br>\n" +
                "Usually only the autogenerated device URIs work.\n" +
                "When the device is not autodetected, there is usually no communication\n" +
                "with the device possible and no data can be sent to the device.<br>\n" +
                "To access a HP printer or all-in-one device via the backend 'hp',\n" +
                "the RPM package hplip must be installed.\n" +
                "The package provides HP's printing and scanning software HPLIP.<br>\n" +
                "In contrast devices which are connected via bluetooth\n" +
                "are not autodetected so that the device URI must be manually specified.\n" +
                "Example device URI:<br>\n" +
                "bluetooth://1A2B3C4D5E6F<br>\n" +
                "To access a device via bluetooth, the RPM package bluez-cups must be installed.\n" +
                "The package provides the CUPS backend 'bluetooth' which actually sends the data\n" +
                "to a bluetooth printer.\n" +
                "</p>"
            ) +
            # ConnectionWizardDialog help 5/7:
            _(
              "<p>\n" +
                "<b><big>Device URIs to Access a Network Printer or a Printserver Box</big></b><br>\n" +
                "A printserver box is a small device with a network connection\n" +
                "and a USB or parallel port connection to connect the actual printer.\n" +
                "A network printer has such a device built-in.\n" +
                "Access happens via three different network protocols.\n" +
                "See the manual of your network printer or printserver box\n" +
                "to find out what your particular device supports:<br>\n" +
                "<b>TCP Port (AppSocket/JetDirect)</b><br>\n" +
                "The IP address and a port number is needed to access it.\n" +
                "Often the port number 9100 is the right one.\n" +
                "It is the simplest, fastest, and generally the most reliable protocol.\n" +
                "The matching device URI is:<br>\n" +
                "socket://ip-address:port-number<br>.\n" +
                "<b>Line Printer Daemon (LPD) Protocol</b><br>\n" +
                "A LPD runs on the device and provides one or more LPD queues.\n" +
                "The IP address and a LPD queue name is needed to access it.\n" +
                "Almost all network printers and printserver boxes support it.\n" +
                "Often an arbitrary queue name or 'LPT1' works.\n" +
                "But using a correct LPD queue which does not change\n" +
                "the data or add additional formfeeds or banner pages\n" +
                "could be essential for reliable printing.\n" +
                "The matching device URI is:<br>\n" +
                "lpd://ip-address/queue<br>.\n" +
                "<b>Internet Printing Protocol (IPP)</b><br>\n" +
                "IPP is the native protocol for CUPS running on a real computer,\n" +
                "but if IPP is implemented in a small printserver box,\n" +
                "it is often not implemented properly. Only use IPP if the vendor\n" +
                "actually documents official support for it. \n" +
                "The matching device URI is:<br>\n" +
                "ipp://ip-address:port-number/resource<br>.\n" +
                "What 'port-number' and 'resource' exactly is depends\n" +
                "on the particular network printer or printserver box model.<br>\n" +
                "For <b>more information</b> have a look at<br>\n" +
                "http://www.cups.org/documentation.php/network.html\n" +
                "</p>\n"
            ) +
            # ConnectionWizardDialog help 6/7:
            _(
              "<p>\n" +
                "<b><big>Device URIs to Print Via a Print Server Machine</big></b><br>\n" +
                "In contrast to a printserver box a print server machine\n" +
                "means a real computer which offers a print service.<br>\n" +
                "Access happens via various different network protocols.\n" +
                "Ask your network administrator what which print server machine\n" +
                "provides in your particular network:<br>\n" +
                "<b>Windows (R) or Samba (SMB/CIFS)</b><br>\n" +
                "To access a SMB printer share, the RPM package samba-client must be installed.\n" +
                "The package provides the CUPS backend 'smb' which is a link to\n" +
                "the <tt>/usr/bin/smbspool</tt> program which actually sends the data\n" +
                "to a SMB printer share.<br>\n" +
                "A server name and a printer share name and optionally a workgroup name\n" +
                "is needed to access it.\n" +
                "Furthermore a user name and a password may be required to get access.\n" +
                "Have in mind that spaces and special characters in those values\n" +
                "must be percent-encoded (see above).<br>\n" +
                "By default CUPS runs backends (here smbspool) as user 'lp'.\n" +
                "When printing in an Active Directory (R) environment (AD)\n" +
                "the user 'lp' is not allowed to print in this environment\n" +
                "so that the traditional way to print via smbspool as user 'lp'\n" +
                "would not work.<br>\n" +
                "For printing in an AD environment additionally\n" +
                "the RPM package samba-krb-printing must be installed.\n" +
                "In this case the CUPS backend 'smb' link\n" +
                "is changed to <tt>/usr/bin/get_printing_ticket</tt>\n" +
                "which is a wrapper to run smbspool as the original user\n" +
                "who submitted a particular print job.\n" +
                "When the Kerberos protocol is used for authentication\n" +
                "in an AD environment, a user gets a ticket granting ticket (TGT)\n" +
                "via the display manager during login at the Gnome or KDE desktop.\n" +
                "When smbspool is run as the original user who submitted\n" +
                "a particular print job, it can access the TGT of this user\n" +
                "and use it to pass the printing data to the SMB printer share\n" +
                "even in an AD environment with Kerberos authentication.\n" +
                "In this case neither a fixed user name nor a fixed password\n" +
                "has to be specified for authentication.\n" +
                "A precondition is that get_printing_ticket runs on the same host\n" +
                "where the user who submitted a particular print job is logged in.\n" +
                "This means that it must be set up on the workstation\n" +
                "for the particular user who will submit such print jobs\n" +
                "and the user's workstation must send its printing data\n" +
                "directly to the SMB printer share in the AD environment.\n" +
                "In particular it does not work on a separated CUPS server machine\n" +
                "where users who submit print jobs are not logged in.<br>\n" +
                "For the traditional way a matching full device URI is:<br>\n" +
                "smb://username:password@workgroup/server/printer<br>\n" +
                "For example 'John Doe' with password '@home!' may use something like\n" +
                "the following device URI to access a 'Fun Printer 1000+' share:<br>\n" +
                "smb://John%20Doe:%40home%21@MYGROUP/homeserver/Fun%20Printer%201000%2B<br>\n" +
                "For <b>more information</b> have a look at <tt>man smbspool</tt> and<br>\n" +
                "http://en.opensuse.org/SDB:Printing_via_SMB_(Samba)_Share_or_Windows_Share<br>\n" +
                "'Windows' and 'Active Directory' are registered trademarks\n" +
                "of Microsoft Corporation in the United States and/or other countries.<br>\n" +
                "<b>Traditional UNIX Server (LPR)</b><br>\n" +
                "A Line Printer Daemon (LPD) runs on a traditional UNIX server\n" +
                "and provides one or more LPD queues.\n" +
                "The IP address and a LPD queue name is needed to access it.\n" +
                "The matching device URI is:<br>\n" +
                "lpd://ip-address/queue<br>\n" +
                "<b>CUPS Server</b><br>\n" +
                "Usually you should not set up a local print queue to access\n" +
                "a remote queue on a CUPS server. Instead do the setup\n" +
                "in the <b>Print Via Network</b> dialog.\n" +
                "Only if you really know that you must set up a local print queue\n" +
                "to access a remote queue on a CUPS server proceed here.<br>\n" +
                "IPP is the native protocol for CUPS which runs on a server.\n" +
                "The official IANA port for IPP is 631.\n" +
                "The matching device URI is:<br>\n" +
                "ipp://ip-address:631/printers/queue<br>\n" +
                "</p>"
            ) +
            # ConnectionWizardDialog help 7/7:
            _(
              "<p>\n" +
                "<b><big>Special Device URIs</big></b><br>\n" +
                "<b>Specify an Arbitrary Device URI</b>\n" +
                "if you know the exact right device URI for your particular case\n" +
                "or to modify an existing device URI in a special way.<br>\n" +
                "<b>Send Print Data to Other Program (pipe)</b><br>\n" +
                "To do this, the RPM package cups-backends must be installed.\n" +
                "The package provides the CUPS backend 'pipe' which runs\n" +
                "the program that you specified here.\n" +
                "The matching device URI is:<br>\n" +
                "pipe:/path/to/targetcommand<br>\n" +
                "<b>Daisy-chain Backend Error Handler (beh)</b><br>\n" +
                "To do this, the RPM package cups-backends must be installed.\n" +
                "The package provides the CUPS backend 'beh'.<br>\n" +
                "The backend 'beh' is a wrapper for the usual backend,\n" +
                "which is then called by beh.\n" +
                "This way beh can, depending on its configuration,\n" +
                "repeat the call of the backend or simply hide the error status\n" +
                "of the backend from being seen by the CUPS daemon.\n" +
                "The matching device URI is:<br>\n" +
                "beh:/nodisable/attempts/delay/originalDeviceURI<br>\n" +
                "If nodisable is '1' beh always exits successfully\n" +
                "so that the queue gets never disabled but on the other hand\n" +
                "print jobs are lost if there is an error.<br>\n" +
                "Attempts is the number of attempts to recall the backend\n" +
                "in case of an error. '0' means infinite retries.<br>\n" +
                "Delay is the number of seconds between two attempts\n" +
                "to call the backend.<br>\n" +
                "The last parameter is the original URI, which the queue had before.<br>\n" +
                "Example:<br>\n" +
                "beh:/1/3/5/socket://ip-address:port-number<br>\n" +
                "The beh backend tries to access a network printer 3 times with 5 second delay\n" +
                "between the attempts. If access still fails, the queue is not disabled\n" +
                "and the print job is lost.<br>\n" +
                "For <b>more information</b> have a look at <tt>/usr/lib[64]/cups/backend/beh</tt> and<br>\n" +
                "http://www.linuxfoundation.org/en/OpenPrinting/Database/BackendErrorHandler\n" +
                "</p>"
            ),
        "printing_via_network_dialog" =>
          # PrintingViaNetworkDialog help 1/4:
          _(
            "<p>\n" +
              "<b><big>Printing Via Network</big></b><br>\n" +
              "Usually CUPS (Common Unix Printing System) is used to print via network.<br>\n" +
              "By default CUPS uses its so called 'Browsing' mode\n" +
              "to make printers available via network.<br>\n" +
              "In this case remote CUPS servers must publish their printers via network\n" +
              "and accordingly on your host the CUPS daemon process (cupsd) must run\n" +
              "which is listening for incoming information about published printers.<br>\n" +
              "CUPS Browsing information is received via UDP port 631.<br>\n" +
              "Regarding firewall:<br>\n" +
              "Check if a firewall is active for a network zone\n" +
              "in which printers are published via network.\n" +
              "By default the SuSEfirewall allows any incoming information\n" +
              "via a network interface which belongs to the 'internal zone'\n" +
              "because this zone is trusted by default.<br>\n" +
              "It does not make sense to do printing in a trusted internal network\n" +
              "with a network interface which belongs to the untrusted 'external zone'\n" +
              "(the latter is the default setting for network interfaces to be safe).\n" +
              "In particular do not disable firewall protection for CUPS\n" +
              "(i.e. for IPP which uses TCP port 631 and UDP port 631)\n" +
              "for the untrusted 'external zone'.<br>\n" +
              "To use remote printers in a trusted internal network\n" +
              "and be protected by the firewall against unwanted access\n" +
              "from any external network (in particular from the Internet),\n" +
              "assign the network interface which belongs to the internal network\n" +
              "to the internal zone of the firewall.\n" +
              "Use the YaST Firewall setup module to do this fundamental setup\n" +
              "to gain security plus usefulness in your network\n" +
              "and using remote printers in a trusted internal network\n" +
              "will work without any further firewall setup.<br>\n" +
              "For details see the openSUSE support database\n" +
              "article 'CUPS and SANE Firewall settings' at<br>\n" +
              "http://en.opensuse.org/SDB:CUPS_and_SANE_Firewall_settings\n" +
              "</p>"
          ) +
            # PrintingViaNetworkDialog help 2/4:
            _(
              "<p>\n" +
                "If you can access remote CUPS servers for printing\n" +
                "but those servers do not publish their printer information via network\n" +
                "or when you cannot accept incoming information about published printers\n" +
                "(e.g. because you must have firewall protection for the network zone\n" +
                "in which printers are published), you can request printer information\n" +
                "from CUPS servers (provided the CUPS servers allow your access).<br>\n" +
                "For each CUPS server which is requested, a cups-polld process\n" +
                "is launched by the CUPS daemon process (cupsd) on your host.\n" +
                "By default each cups-polld polls a remote CUPS server\n" +
                "every 30 seconds for printer information.\n" +
                "</p>"
            ) +
            # PrintingViaNetworkDialog help 3/4:
            _(
              "<p>\n" +
                "If you print only via network and if you use only one single CUPS server,\n" +
                "there is no need to use CUPS Browsing and have a CUPS daemon running on your host.\n" +
                "Instead it is simpler to specify the CUPS server and access it directly.<br>\n" +
                "A possible drawback is that application programs may be delayed\n" +
                "for some time (until a timeout happens) when they try\n" +
                "to access the CUPS server but it is actually not available\n" +
                "(e.g. while traveling with a laptop). Usually it is a host name\n" +
                "resolution (DNS) timeout which causes the delay so that it may help\n" +
                "to have a hardcoded entry for the CUPS server in the /etc/hosts file.\n" +
                "</p>"
            ) +
            # PrintingViaNetworkDialog help 4/4:
            _(
              "<p>\n" +
                "You have to set up an appropriate print queue on your host\n" +
                "if there is no CUPS server in your network,\n" +
                "or when you must access a network printer directly,\n" +
                "or when you use another kind of print server\n" +
                "e.g. when printing via a Windows (R) or Samba server\n" +
                "or when printing via a traditional Unix server.<br>\n" +
                "'Windows' is a registered trademark\n" +
                "of Microsoft Corporation in the United States and/or other countries.\n" +
                "</p>"
            ),
        "sharing_dialog" =>
          # SharingDialog help 1/4:
          _(
            "<p>\n" +
              "<b><big>Sharing Print Queues and Publish Them Via Network</big></b><br>\n" +
              "Usually CUPS (Common Unix Printing System) should be set up to use\n" +
              "its so called 'Browsing' mode to make printers available via network.<br>\n" +
              "In this case CUPS servers publish their local print queues via network\n" +
              "and accordingly on CUPS client systems the CUPS daemon process (cupsd) must run\n" +
              "which is listening for incoming information about published printers.<br>\n" +
              "CUPS Browsing information is received via UDP port 631.\n" +
              "</p>"
          ) +
            # SharingDialog help 2/4:
            _(
              "<p>\n" +
                "First of all CUPS client systems must be allowed to access the CUPS server.\n" +
                "Then specify whether or not printers should be published to the clients.<br>\n" +
                "In a local network the usual way to set up CUPS Browsing is\n" +
                "to allow remote access for all hosts in the local network\n" +
                "and to publish printers to all those hosts.<br>\n" +
                "It is not required to publish printers in any case.<br>\n" +
                "If you have only one single CUPS server, there is no need to use CUPS Browsing.\n" +
                "Instead it is simpler to specify the CUPS server on the client systems\n" +
                "(via 'Printing Via Network') so that the clients access the server directly.\n" +
                "</p>"
            ) +
            # SharingDialog help 3/4:
            _(
              "<p>\n" +
                "There are various ways which can coexist how to specify\n" +
                "which remote hosts are allowed to access the CUPS server.<br>\n" +
                "Allow remote access for computers within the local network\n" +
                "will allow access from all hosts in the local network.\n" +
                "A remote host is in the local network when it has an IP address\n" +
                "that belongs to the same network as the CUPS server\n" +
                "and when the network connection of the host\n" +
                "uses a non-PPP interface on the CUPS server\n" +
                "(an interface whose IFF_POINTOPOINT flag is not set).<br>\n" +
                "Alternatively or additionally an explicite list of network interfaces\n" +
                "from which remote access is allowed can be specified.<br>\n" +
                "Alternatively or additionally an explicite list of\n" +
                "allowed IP addresses and/or networks can be specified.\n" +
                "</p>"
            ) +
            # SharingDialog help 4/4:
            _(
              "<p>\n" +
                "Regarding firewall:<br>\n" +
                "A firewall is used to protect running server processes\n" +
                "(in this case the CUPS server process 'cupsd')\n" +
                "on your host against unwanted access via network.<br>\n" +
                "Printing via network happens in a trusted internal network\n" +
                "(nobody lets arbitrary users from whatever external network\n" +
                "print on his printer) and usually the users need\n" +
                "physical printer access to get their paper output.<br>\n" +
                "By default the SuSEfirewall lets any network traffic pass\n" +
                "via a network interface which belongs to the 'internal zone'\n" +
                "because this zone is trusted by default.<br>\n" +
                "It does not make sense to do printing in a trusted internal network\n" +
                "with a network interface which belongs to the untrusted 'external zone'\n" +
                "(the latter is the default setting for network interfaces to be safe).\n" +
                "Do not disable firewall protection for CUPS\n" +
                "(i.e. for IPP which uses TCP port 631 and UDP port 631)\n" +
                "for the untrusted 'external zone'.<br>\n" +
                "To make printers accessible in a trusted internal network\n" +
                "and be protected by the firewall against unwanted access\n" +
                "from any external network (in particular from the Internet),\n" +
                "assign the network interface which belongs to the internal network\n" +
                "to the internal zone of the firewall.\n" +
                "Use the YaST Firewall setup module to do this fundamental setup\n" +
                "to gain security plus usefulness in your network and\n" +
                "sharing printers in a trusted internal network\n" +
                "will work without any further firewall setup.<br>\n" +
                "For details see the openSUSE support database\n" +
                "article 'CUPS and SANE Firewall settings' at<br>\n" +
                "http://en.opensuse.org/SDB:CUPS_and_SANE_Firewall_settings\n" +
                "</p>"
            ),
        "policies" =>
          # Policies help 1/2:
          _(
            "<p>\n" +
              "<b><big>CUPS Operation Policy</big></b><br>\n" +
              "Operation policies are the rules used for each operation in CUPS.\n" +
              "Such operations are for example 'print something', 'cancel a printout',\n" +
              "'configure a printer', 'modify or remove a printer configuration',\n" +
              "and 'enable or disable printing'.\n" +
              "</p>"
          ) +
            # Policies help 2/2:
            _(
              "<p>\n" +
                "<b><big>CUPS Error Policy</big></b><br>\n" +
                "The error policy defines the default policy that is used when\n" +
                "CUPS fails to send a print job to the printer device.<br>\n" +
                "Depending on the particular way how the printer is connected\n" +
                "(for example 'usb', 'socket', 'lpd', or 'ipp'),\n" +
                "and depending on the actual kind of failure,\n" +
                "the CUPS backend which actually sends the data to the printer\n" +
                "can overwrite the default error policy\n" +
                "and enforce another error policy (see <tt>man backend</tt>).\n" +
                "For example it can stop any further printing attempt\n" +
                "even when the default error policy is to retry the job.\n" +
                "This could happen when any attempt to establish\n" +
                "the communication with the printer is useless\n" +
                "so that it does no make sense to retry the job.\n" +
                "<br>\n" +
                "The following error policies exist:<br>\n" +
                "Stop the printer and keep the job for future printing.<br>\n" +
                "Re-send the job from the beginning after waiting some time (30 seconds by default).<br>\n" +
                "Abort and delete the job and proceed with the next job.\n" +
                "</p>"
            ),
        "autoconfig" =>
          # Autoconfig help 1/2:
          _(
            "<p>\n" +
              "<b><big>Automatic Configuration for Local Connected Printers</big></b><br>\n" +
              "Check the check box to run YaST's automatic configuration\n" +
              "for printers which are connected to the local host.<br>\n" +
              "For each autodetected local connected printer,\n" +
              "YaST tests if there exists already a configuration.\n" +
              "If there is not yet a configuration,\n" +
              "YaST tries to find a matching driver for the printer\n" +
              "and if one is found, the printer is configured.<br>\n" +
              "The resulting configuration is basically the same\n" +
              "as if one would have selected an autodetected printer\n" +
              "in the 'Add New Printer Configuration' dialog\n" +
              "and accepted whatever preselected values there.\n" +
              "</p>"
          ) +
            # Autoconfig help 2/2:
            _(
              "<p>\n" +
                "<b><big>Automatic Configuration for USB Printers</big></b><br>\n" +
                "The RPM package 'udev-configure-printer' provides\n" +
                "automatic configuration when USB printers are plugged in.<br>\n" +
                "When its check box is initially not checked, it is not installed\n" +
                "and then you can select it so that it will be installed.<br>\n" +
                "When its check box is initially checked, it is already installed\n" +
                "and then you can un-select it so that it will be removed.<br>\n" +
                "When udev-configure-printer is installed,\n" +
                "automatic USB printer configuration happens via the entries\n" +
                "in its udev config file /lib/udev/rules.d/70-printers.rules\n" +
                "which triggers to run 'udev-configure-printer add'\n" +
                "when a USB printer is plugged in\n" +
                "and 'udev-configure-printer remove' when it is unplugged.\n" +
                "There are no adjustable settings for udev-configure-printer\n" +
                "except one changes the 70-printers.rules file manually.\n" +
                "</p>"
            )
      } 

      # EOF
    end
  end
end

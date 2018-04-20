#
# spec file for package yast2-printer
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-printer
Version:        4.0.1
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2


BuildRequires:  update-desktop-files
BuildRequires:  xorg-x11-libX11-devel
BuildRequires:  yast2
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-testsuite

Recommends:     cups-client iptables netcat samba-client

Requires:       /bin/mktemp /usr/bin/sed
Requires:       yast2 >= 3.1.183

# Used to exclude libX11, libXau, libxcb, and libxcb-xlib from the requires list
# which are pulled in by Autoreqprov because of the basicadd_displaytest tool:
%define my_requires /tmp/my-requires

Requires:       yast2-ruby-bindings >= 1.0.0

Obsoletes:      yast2-printer-devel-doc

Summary:        YaST2 - Printer Configuration
License:        GPL-2.0
Group:          System/YaST

%description
This package contains the YaST2 component for printer configuration.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install

# Exclude libX11, libXau, libxcb, and libxcb-xlib from the requires list
# which are pulled in by Autoreqprov because of the basicadd_displaytest tool:
cat << EOF > %{my_requires}
grep -v 'basicadd_displaytest' | %{__find_requires}
EOF
chmod 755 %{my_requires}
%define __find_requires %{my_requires}


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/printer
%{yast_desktopdir}/printer.desktop
%{yast_moduledir}/*.rb
%{yast_clientdir}/printer*
%{yast_yncludedir}/printer/*
%{yast_schemadir}/autoyast/rnc/printer.rnc
%{yast_ydatadir}/testprint.ps
%{yast_ydatadir}/testprint.2pages.ps
%{yast_ybindir}/autodetect_print_queues
%{yast_ybindir}/autodetect_printers
%{yast_ybindir}/create_printer_ppd_database
%{yast_ybindir}/determine_printer_driver_options
%{yast_ybindir}/cups_client_only
%{yast_ybindir}/modify_cupsd_conf
%{yast_ybindir}/test_device
%{yast_ybindir}/test_remote_ipp
%{yast_ybindir}/test_remote_lpd
%{yast_ybindir}/test_remote_novell
%{yast_ybindir}/test_remote_smb
%{yast_ybindir}/test_remote_socket
%{yast_ybindir}/basicadd_displaytest
#Documentation
%dir %{yast_docdir}
%{yast_docdir}/COPYING

%changelog

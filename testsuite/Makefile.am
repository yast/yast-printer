#
# Makefile.am for .../testsuite
#
# modified according to inetd testsuite Makefile.am

AUTOMAKE_OPTIONS = dejagnu
ycp_testfiles = $(wildcard tests/*.out) $(wildcard tests/*.err) $(wildcard tests/*.ycp) $(wildcard tests/*.yh)

ag_misc = lib/yast2_ag.exp run/runtest-ag.sh
ag_testfiles = $(wildcard $(RPMNAME).test/ag_*.exp tests.ag/*.in tests.ag/*.out tests.ag/*.err tests.ag/*.ycp tests.ag/Postscript.ppd)
EXTRA_DIST = $(ycp_testfiles) $(ag_testfiles) $(ag_misc)

testsuite_prepare = @ydatadir@/testsuite/Makefile.testsuite

# explicitly list files we want for the ycp tests
# don't mess with: Makefile.am .cvsignore
all-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) \
		dirs \
		config/default.exp config/unix.exp config/unknown.exp \
		run/runtest.sh $(RPMNAME).test/testsuite.exp
	mkdir -p tmp



# Interferates with a agents testsuite.
#clean-local: $(testsuite_prepare)
#	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) clean

check-local: $(testsuite_prepare)
	make -f $(testsuite_prepare) RPMNAME=$(RPMNAME) srcdir=$(srcdir) check

# EOF

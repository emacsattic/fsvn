#!/bin/bash
#
# Test tool
#

makefile=Makefile.tmp
cfgfile=MAKE-CFG.el.tmp

function check ()
{
	local bin_dir=${1%/}
	local emacs_command=${2}
	local sample=${3}
	local direction=${4:-check}

	if [ -z "${emacs_command}" ] ; then
		echo "Skipping ${bin_dir}"
		return;
	fi

	if ! which "${emacs_command}" > /dev/null 2>&1 ; then
		echo "Skipping ${emacs_command}"
		return
	fi

	if [ ! -d ${bin_dir} ] ; then
		echo "Skipping ${bin_dir}"
		return
	fi

	local svn_command=${bin_dir}/svn
	local svnadmin_command=${bin_dir}/svnadmin

	if [ ! -x "${svn_command}" ] ; then
		echo "Skipping ${svn_command}"
		return
	fi

	echo "Starting test for ${bin_dir} ${emacs_command}"

	cat > ${cfgfile} <<EOF
(setq fsvn-svn-command "${svn_command}")
(setq fsvn-svnadmin-command "${svnadmin_command}")
(setq fsvn-home-directory "~/tmp/$(date +%Y%m%d%H%M%S)")
EOF

	rm -f ${makefile}

	IFS=" 
"
	while read line ; do
		if echo "${line}" | grep -q -e "^ *EMACS[ 	]*=" ; then
			echo "EMACS	= ${emacs_command}" >> ${makefile}
		elif echo "${line}" | grep -q -e "^ *CONFIG[ 	]*=" ; then
			echo "CONFIG  = ${cfgfile}" >> ${makefile}
		else
			echo "${line}" >> ${makefile}
		fi
	done < ${sample}

	if ! make -f ${makefile} ${direction} ; then
		echo "Error while ${bin_dir} ${emacs_command}" >&2
		return 1;
	fi
}

# for Unix (Linux)
UNIX_SVN_1_6_BIN=~/src/subversion-dev/inst-1.6.x/bin
UNIX_SVN_1_7_BIN=~/src/subversion-dev/inst-1.7.x/bin
UNIX_SVN_1_8_BIN=~/src/subversion-dev/inst-1.8.x/bin
EMACS_23_BIN=emacs-23.3
EMACS_24_BIN=emacs-24.3
EMACS_CURRENT_BIN=emacs-current
EMACS_BIN=emacs

# for Windows
WIN_SVN_1_6_BIN="c:/usr/local/subversion-dev/svn-win32-1.6.6/bin"
WIN_SVN_1_7_BIN="c:/usr/local/subversion-dev/svn-win32-1.7.14/bin"
WIN_SVN_1_8_BIN="c:/usr/local/subversion-dev/svn-win32-1.8.5/bin"
NTEMACS23_BIN="/cygdrive/c/usr/local/NTEmacs/23.3/bin/emacs.exe"
NTEMACS24_BIN="/cygdrive/c/usr/local/NTEmacs/24.2/bin/emacs.exe"

if ! uname | grep -q -i cygwin ; then
	check /usr/bin ${EMACS_BIN} Makefile

	check "${UNIX_SVN_1_6_BIN}" "${EMACS_23_BIN}" Makefile
	check "${UNIX_SVN_1_6_BIN}" "${EMACS_24_BIN}" Makefile
	check "${UNIX_SVN_1_6_BIN}" "${EMACS_CURRENT_BIN}" Makefile
	check "${UNIX_SVN_1_7_BIN}" "${EMACS_23_BIN}" Makefile
	check "${UNIX_SVN_1_7_BIN}" "${EMACS_24_BIN}" Makefile
	check "${UNIX_SVN_1_7_BIN}" "${EMACS_CURRENT_BIN}" Makefile
	check "${UNIX_SVN_1_8_BIN}" "${EMACS_23_BIN}" Makefile
	check "${UNIX_SVN_1_8_BIN}" "${EMACS_24_BIN}" Makefile
	check "${UNIX_SVN_1_8_BIN}" "${EMACS_CURRENT_BIN}" Makefile
else
	check "${WIN_SVN_1_6_BIN}" "${NTEMACS23_BIN}" Samples/Makefile.nt23
	check "${WIN_SVN_1_6_BIN}" "${NTEMACS24_BIN}" Samples/Makefile.nt
	check "${WIN_SVN_1_7_BIN}" "${NTEMACS23_BIN}" Samples/Makefile.nt23
	check "${WIN_SVN_1_7_BIN}" "${NTEMACS24_BIN}" Samples/Makefile.nt
	check "${WIN_SVN_1_8_BIN}" "${NTEMACS23_BIN}" Samples/Makefile.nt23
	check "${WIN_SVN_1_8_BIN}" "${NTEMACS24_BIN}" Samples/Makefile.nt

	check "${WIN_SVN_1_6_BIN}" "${NTEMACS23_BIN}" Samples/Makefile.nt23 check-in-console
	check "${WIN_SVN_1_6_BIN}" "${NTEMACS24_BIN}" Samples/Makefile.nt	check-in-console
	check "${WIN_SVN_1_7_BIN}" "${NTEMACS23_BIN}" Samples/Makefile.nt23 check-in-console
	check "${WIN_SVN_1_7_BIN}" "${NTEMACS24_BIN}" Samples/Makefile.nt	check-in-console
	check "${WIN_SVN_1_8_BIN}" "${NTEMACS23_BIN}" Samples/Makefile.nt23 check-in-console
	check "${WIN_SVN_1_8_BIN}" "${NTEMACS24_BIN}" Samples/Makefile.nt	check-in-console
fi

make clean -f ${makefile}

rm -f ${makefile} ${cfgfile}


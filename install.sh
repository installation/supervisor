#!/bin/bash

# Script to install Supervisord
# Author: Márk Sági-Kazár (sagikazarmark@gmail.com)
# This script installs Supervisord on several Linux distributions.
#
# Version: 3.0

# Variable definitions
DIR=$(cd `dirname $0` && pwd)
NAME="Supervisor"
SLUG="supervisor"
VER="3.0"
DEPENDENCIES=("python" "dialog" "tar")
TMP="/tmp/$SLUG"
INSTALL_LOG="$TMP/install.log"
ERROR_LOG="$TMP/error.log"

# Cleaning up
rm -rf $TMP
mkdir -p $TMP
cd $TMP
chmod 777 $TMP


# Basic function definitions

## Echo colored text
e()
{
	local color="\033[${2:-34}m"
	local log="${3:-$INSTALL_LOG}"
	echo -e "$color$1\033[0m"
	log "$1" "$log"
}

## Exit error
ee()
{
	local exit_code="${2:-1}"
	local color="${3:-31}"

	clear
	e "$1" "$color" "$ERROR_LOG"
	exit $exit_code
}

## Log messages
log()
{
	local log="${2:-$INSTALL_LOG}"
	echo "$1" >> "$log"
}

## Add dependency
dep()
{
	if [ ! -z "$1" ]; then
		DEPENDENCIES+=("$1")
	fi
}


# Checking root access
if [ $EUID -ne 0 ]; then
	ee "This script has to be ran as root!"
fi

# CTRL_C trap
ctrl_c()
{
	clear
	echo
	echo "Installation aborted by user!"
	cleanup
}
trap ctrl_c INT

# Basic checks

## Check for wget or curl or fetch
e "Checking for HTTP client..."
if [ `which curl 2> /dev/null` ]; then
	download="$(which curl) -s -O"
elif [ `which wget 2> /dev/null` ]; then
	download="$(which wget) --no-certificate"
elif [ `which fetch 2> /dev/null` ]; then
	download="$(which fetch)"
else
	dep "wget"
	download="$(which wget) --no-certificate"
	e "No HTTP client found, wget added to dependencies" 31
fi

## Check for package manager (apt or yum)
e "Checking for package manager..."
if [ `which apt-get 2> /dev/null` ]; then
	install[0]="apt"
	install[1]="$(which apt-get) -y --force-yes install"
elif [ `which yum 2> /dev/null` ]; then
	install[0]="yum"
	install[1]="$(which yum) -y install"
else
	ee "No package manager found."
fi

## Check for package manager (dpkg or rpm)
if [ `which dpkg 2> /dev/null` ]; then
	install[2]="dpkg"
	install[3]="$(which dpkg)"
elif [ `which rpm 2> /dev/null` ]; then
	install[2]="rpm"
	install[3]="$(which rpm)"
else
	ee "No package manager found."
fi

## Check for init system (update-rc.d or chkconfig)
e "Checking for init system..."
if [ `which update-rc.d 2> /dev/null` ]; then
	init="$(which update-rc.d)"
elif [ `which chkconfig 2> /dev/null` ]; then
	init="$(which chkconfig) --add"
else
	ee "Init system not found, service not started!"
fi


# Function definitions

## Install required packages
install()
{
	[ -z "$1" ] && { e "No package passed" 31; return 1; }

	e "Installing package: $1"
	${install[1]} "$1" >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Installing $1 failed"
	e "Package $1 successfully installed"

	return 0
}

## Check installed package
check()
{
	[ -z "$1" ] && { e "No package passed" 31; return 2; }

	case ${install[2]} in
		dpkg )
			${install[3]} -s "$1" &> /dev/null
			;;
		rpm )
			${install[3]} -qa | grep "$1"  &> /dev/null
			;;
	esac
	return $?
}

## Download required file
download()
{
	[ -z "$1" ] && { e "No package passed" 31; return 1; }

	local text="${2:-files}"
	e "Downloading $text"
	$download "$1" >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Downloading $text failed"
	e "Downloading $text finished"
	return 0
}

## Install init script
init()
{
	[ -z "$1" ] && { e "No init script passed" 31; return 1; }

	$init "$1" >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Error during init"
	return 0
}

## Show progressbar
progress()
{
	local progress=${1:-0}
	local gauge="${2:-Please wait}"
	local title="${3:-Installation progress}"

	echo $progress | dialog --backtitle "Installing $NAME $VER" \
	 --title "$title" --gauge "$gauge" 7 70 0
}

## Cleanup files
cleanup()
{
	cd $TMP 2> /dev/null || return 1
	find * -not -name '*.log' | xargs rm -rf
}


# Checking dependencies
for dep in ${DEPENDENCIES[@]}; do
	check "$dep"
	[ $? -eq 0 ] || install "$dep"
done


if [ -f /usr/local/bin/supervisord -o -f /usr/bin/supervisord ]; then
	dialog --stdout --backtitle "Installing $NAME $VER" \
	--title "WARNING" --defaultno \
	--yesno "Warning: $NAME is already installed. Do you want to continue?" 7 50
	case $? in
		0 )
			e "Installing $NAME over the previous version" 31
			;;
		* )
			ctrl_c
			exit 0
			;;
	esac
fi

config=$(dialog --stdout --backtitle "Installing $NAME $VER" \
--title "Configuration" \
--radiolist "Choose configuration" 11 40 3 \
 1 "Default config" off \
 2 "Predefined config" on \
 3 "Open editor" off )

# Setuptools
progress 10 "Downloading Setuptools"
cd $TMP
if [ -f $DIR/setuptools-1.0.tar.gz ]; then
	cp -r $DIR/setuptools-1.0.tar.gz $TMP
else
	download https://pypi.python.org/packages/source/s/setuptools/setuptools-1.0.tar.gz "Setuptools"
fi
progress 20 "Extracting Setuptools"
tar -xzf setuptools-1.0.tar.gz >> $INSTALL_LOG 2>> $ERROR_LOG
progress 30 "Installing Setuptools"
cd setuptools-1.0
python setup.py install >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Error installing Setuptools"

# Supervisor
progress 40 "Downloading $NAME $VER"
cd $TMP
if [ -f $DIR/supervisor-3.0.tar.gz ]; then
	cp -r $DIR/supervisor-3.0.tar.gz $TMP
else
	download https://pypi.python.org/packages/source/s/supervisor/supervisor-3.0.tar.gz "$NAME $VER"
fi
progress 50 "Extracting $NAME $VER"
tar -xzf supervisor-3.0.tar.gz >> $INSTALL_LOG 2>> $ERROR_LOG
progress 60 "Installing $NAME $VER"
cd supervisor-3.0
python setup.py install >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Installing $NAME $VER failed"

cd $TMP

progress 80 "Setting up $NAME $VER"
case $config in
	2 )
		if [ -f $DIR/config/supervisord.conf ]; then
			cp -r $DIR/config/supervisord.conf /etc/
		else
			download https://raw.github.com/sagikazarmark/supervisor/a996cbfc8394f280b33177d748e6a5b1070e8c4e/config/supervisord.conf "Supervisor config"
			mv supervisord.conf /etc/
		fi
		;;
	3 )
		echo_supervisord_conf >> /etc/supervisord.conf
		nano /etc/supervisord.conf
		;;
	* )
		echo_supervisord_conf >> /etc/supervisord.conf
		;;
esac

mkdir -p /etc/supervisord.d

[ -f /usr/bin/supervisord ] || ln -s /usr/local/bin/supervisord /usr/bin/supervisord
[ -f /usr/bin/supervisorctl ] || ln -s /usr/local/bin/supervisorctl /usr/bin/supervisorctl
[ -f /usr/bin/pidproxy ] || ln -s /usr/local/bin/pidproxy /usr/bin/pidproxy

progress 90 "Cleaning up"
cleanup

clear

if [ -f $DIR/supervisord ]; then
	cp -r $DIR/supervisord /etc/init.d/supervisord
else
	download https://raw.github.com/sagikazarmark/supervisor/a996cbfc8394f280b33177d748e6a5b1070e8c4e/supervisord "Supervisor init script"
	mv supervisord /etc/init.d/supervisord
fi
chmod +x /etc/init.d/supervisord

service supervisord stop 2>> $ERROR_LOG
service supervisord start 2>> $ERROR_LOG

if [ -s $ERROR_LOG ]; then
	e "Error log is not empty. Please check $ERROR_LOG for further details." 31
fi

e "Installation done."

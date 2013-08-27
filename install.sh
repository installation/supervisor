#!/bin/bash

# Script to install Supervisord
# Author: Márk Sági-Kazár (sagikazarmark@gmail.com)
# This script installs Supervisord on several Linux distributions.
#
# Version: 3.0

# Basic function definitions

## Echo colored text
e()
{
	local color="\033[${2:-34}m"
	echo -e "$color$1\033[0m"
}

## Exit error
ee()
{
	local exit_code="${2:-1}"
	local color="${3:-31}"

	e "$1" "$color"
	exit $exit_code
}

# Checking root access
if [ $EUID -ne 0 ]; then
	ee "This script has to be ran as root!"
fi

# Variable definitions
DIR=$(cd `dirname $0` && pwd)
NAME="Supervisord"
VER="3.0"
DEPENDENCIES=("python" "dialog" "tar")
TMP="/tmp/$NAME"
INSTALL_LOG="$TMP/install.log"
ERROR_LOG="$TMP/error.log"

# CTRL_C trap
ctrl_c()
{
	clear
	echo
	echo "Installation aborted by user!"
	rm -rf $TMP/supervisor* $TMP/setuptools*
}
trap ctrl_c INT

# Basic checks

## Check for wget or curl or fetch
e "Checking for HTTP client..."
if [ `which curl &> /dev/null` ]; then
	download="$(which curl) -O"
elif [ `which wget &> /dev/null` ]; then
	download="$(which wget) --no-certificate"
elif [ `which fetch &> /dev/null` ]; then
	download="$(which fetch)"
else
	DEPENDENCIES+=("wget")
	download="$(which wget) --no-certificate"
	e "No HTTP client found, wget added to dependencies" 31
fi

## Check for package manager (apt or yum)
e "Checking for package manager..."
if [ `which apt-get &> /dev/null` ]; then
	install="$(which apt-get) -y --force-yes install"
elif [ `which yum &> /dev/null` ]; then
	install="$(which yum) -y install"
else
	ee "No package manager found."
fi

## Check for init system (update-rc.d or chkconfig)
e "Checking for init system..."
if [ `which update-rc.d &> /dev/null` ]; then
	init="$(which update-rc.d)"
elif [ `which chkconfig &> /dev/null` ]; then
	init="$(which chkconfig) --add"
else
	ee "Init system not found, service not started!"
fi

## Clearing logs
rm -rf $INSTALL_LOG $ERROR_LOG

# Function definitions

## Install required packages
install()
{
	if [ -z "$1" ]; then
		e "Package not given" 31
		return 1
	else
		e "Installing package: $1"
		$install "$1" >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Error during package install"
		e "Package $1 successfully installed"
	fi

	return 0
}

download()
{
	if [ -z "$1" ]; then
		e "No download given" 31
		return 1
	else
		$download "$1" >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Error during download"
	fi

	return 0
}

init()
{
	if [ -z "$1" ]; then
		e "No init script given" 31
		return 1
	else
		$init "$1" >> $INSTALL_LOG 2>> $ERROR_LOG || ee "Error during init"
	fi

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

# Checking dependencies
for dep in ${DEPENDENCIES[@]}; do
	if [ ! $(which $dep &> /dev/null) ]; then
		install "$dep"
	fi
done

if [ -f /usr/local/bin/supervisord ]; then
	warning=$(dialog --stdout --backtitle "Installing $NAME $VER" \
	--title "WARNING" --defaultno \
	--yesno "Warning: $NAME is already installed. Do you want to continue?" 7 50 )

	case $warning in
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
 3 "Open editor" off)

mkdir -p $TMP
cd $TMP

progress 15 "Cleaning up"
rm -rf *

progress 30 "Downloading files"
download https://pypi.python.org/packages/source/s/supervisor/supervisor-3.0.tar.gz
download https://pypi.python.org/packages/source/s/setuptools/setuptools-1.0.tar.gz

progress 45 "Extracting files"
tar -xvzf supervisor-3.0.tar.gz >> $INSTALL_LOG 2>> $ERROR_LOG
tar -xvzf setuptools-1.0.tar.gz >> $INSTALL_LOG 2>> $ERROR_LOG

progress 60 "Installing Setuptools"
cd setuptools-1.0
python setup.py install >> $INSTALL_LOG 2>> $ERROR_LOG

progress 75 "Installing $NAME $VER"
cd ../supervisor-3.0
python setup.py install >> $INSTALL_LOG 2>> $ERROR_LOG

cd $TMP

progress 90 "Setting up $NAME $VER"
case $config in
	2 )
		if [ -f $DIR/config/supervisord.conf ]; then
			cp -r $DIR/config/supervisord.conf /etc/
		else
			download https://raw.github.com/sagikazarmark/server/ba3dafdfe1f61f2477ef8c961aa961101cee39a1/supervisord/config/supervisord.conf
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

progress 95 "Deleting setup files"
rm -rf setuptools* supervisor*

clear

if [ -f $DIR/supervisord ]; then
	cp -r $DIR/supervisord /etc/init.d/supervisord
else
	download https://raw.github.com/sagikazarmark/server/ba3dafdfe1f61f2477ef8c961aa961101cee39a1/supervisord/supervisord
	mv supervisord /etc/init.d/supervisord
fi
chmod +x /etc/init.d/supervisord

service supervisord stop
service supervisord start

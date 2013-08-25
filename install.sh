#!/bin/bash

# # Script to install Supervisord
# Author: Márk Sági-Kazár (sagikazarmark@gmail.com)
# This script installs Supervisord on Debian/Ubuntu based distributions.
#
# Version: 3.0

# Function definitions

## Echo colored text
e()
{
	color="\033[${2:-34}m"
	echo -e "$color$1\033[0m"
}

## Find linux distribution
find_distro()
{
if [ -f /etc/lsb-release ]; then
		DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
elif [ -f /etc/debian_version ]; then
		DISTRO="debian"
elif [ -f /etc/redhat-release ]; then
		DISTRO=$(cat /etc/redhat-release | cut -f 1 -d " " | tr '[:upper:]' '[:lower:]')
else
		DISTRO="$(uname -s) $(uname -r)"
fi
}

## Install required packages
install()
{
	if [ -z "$1" ]; then
		return 1
	else
		if [ `which apt-get 2> /dev/null` ]; then
			apt-get install -y -qq $1 &> /dev/null || return 2
		elif [ `which yum 2> /dev/null` ]; then
			yum install -y -q $1 &> /dev/null || return 2
		else
			return 3
		fi
		return 0
	fi
}

## Show progressbar
progress()
{
	progress=${1:-0}
	gauge="${2:-Please wait}"
	title="${3:-Installation progress}"

	echo $progress | dialog --backtitle "Installing $NAME $VER" \
	 --title "$title" --gauge "$gauge" 7 70 0
}

# Variable definitions

DIR=$(cd `dirname $0` && pwd)
NAME="Supervisord"
VER="3.0"
DEPENDENCIES=("python" "dialog" "wget")

# Checking root access
if [ $EUID -ne 0 ]; then
	e "This script has to be ran as root!" 31
	exit 1
fi

# Checking dependencies
for dep in ${DEPENDENCIES[@]}; do
	if [ ! $(which $dep 2> /dev/null) ]; then
		e "Installing package: $dep"
		install "$dep"
		case $? in
			0 )
				e "Package installed: $dep"
				;;
			1 )
				e "Invalid package: $dep" 31
				exit 1
				;;
			2 )
				e "Package install failed: $dep" 31
				exit 1
				;;
			3 )
				e "Package manager not found" 31
				exit 1
				;;
			* )
				e "Undefined Error" 31
				exit 1
				;;
		esac
	fi
done

if [ -f /usr/local/bin/supervisord ]; then
	warning=$(dialog --stdout --backtitle "Installing $NAME $VER" \
	--title "WARNING" \
	--radiolist "Warning: $NAME is already installed. Do you want to continue?" 11 40 2 \
	 1 "Yes" off \
	 2 "No" on )

	case $warning in
		1 )
			e "Installing $NAME over the previous version" 31
			;;
		* )
			e "Installation aborted"
			exit 1
			;;
	esac
fi

config=$(dialog --stdout --backtitle "Installing $NAME $VER" \
--title "Configuration" \
--radiolist "Choose configuration" 11 40 3 \
 1 "Default config" off \
 2 "Predefined config" on \
 3 "Open editor" off)

cd /tmp

progress 15 "Cleaning up"
rm -rf supervisor* setuptools*

progress 30 "Downloading files"
wget --quiet --no-check-certificate https://pypi.python.org/packages/source/s/supervisor/supervisor-3.0.tar.gz > /dev/null
wget --quiet --no-check-certificate https://pypi.python.org/packages/source/s/setuptools/setuptools-1.0.tar.gz > /dev/null

progress 45 "Extracting files"
tar -xvzf supervisor-3.0.tar.gz > /dev/null
tar -xvzf setuptools-1.0.tar.gz > /dev/null

progress 60 "Installing Setuptools"
cd setuptools-1.0
python setup.py install > /dev/null

progress 75 "Installing $NAME $VER"
cd ../supervisor-3.0
python setup.py install > /dev/null

cd ..

progress 90 "Setting up $NAME $VER"
case $config in
	2 )
		cp $DIR/config/supervisord.conf /etc/
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

#curl https://raw.github.com/gist/176149/88d0d68c4af22a7474ad1d011659ea2d27e35b8d/supervisord.sh > /etc/init.d/supervisord
cp $DIR/supervisord /etc/init.d/supervisord
chmod +x /etc/init.d/supervisord

if [ `which update-rc.d 2> /dev/null` ]; then
	update-rc.d supervisord defaults &> /dev/null || e "Error installing init script!" 31
elif [ `which chkconfig 2> /dev/null` ]; then
	chkconfig --add supervisord &> /dev/null || e "Error installing init script!" 31
else
	e "InitV not found, service not started!" 31
	exit 1
fi

service supervisord stop
service supervisord start

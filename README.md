Supervisor install & init script
================================

Install supervisor on several Linux distributions with one script

* Installs all dependencies using apt or yum
* Creates init script which is also distro-independent
* Runs update-rc or chkconfig
* Creates config of your choice (default, predefined, open up editor)

Note: Always change the configuration, even the predefined one. If you use the webinterface, remember to setup a password and check the port number.

Some program configuration are also included.

Tested on:
* CentOS 5.8/6.4
* Debian 6.0/7.0
* Fedora 17
* Ubuntu 10.04/12.04/12.10/13.04

Default temp dir is ````/tmp/Supervisor````, this can be changed in install script.

By default, the installer logs into ````$TMP/install.log```` and ````$TMP/error.log````. Check these for further info about the installation process.

## Installation

There are two ways to install supervisord: online and offline

Note: supervisor and setuptools are NOT included in this repository, so if you want to install supervisor offline, you have to download these files manually to either in the temp dir or the dir of the install script or clone this repository with ````--recursive```` option.

### Online installation

Clone this repository and run ````install.sh````
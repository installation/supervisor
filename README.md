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

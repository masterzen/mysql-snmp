#! /bin/sh
#
# Copyright (c) 2008, 2009 Brice Figureau
#
# This init script is based on:
# the skeleton	example file to build /etc/init.d/ scripts.
#		This file should be used to construct scripts for /etc/init.d.
#
#		Written by Miquel van Smoorenburg <miquels@cistron.nl>.
#		Modified for Debian 
#		by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#
# Version:	@(#)skeleton  1.9  26-Feb-2001  miquels@cistron.nl
#
### BEGIN INIT INFO
# Provides:          mysql-snmp
# Required-Start:    $syslog
# Required-Stop:     $syslog
# Should-Start:      $local_fs $remote_fs $network $named $time
# Should-Stop:       $local_fs $remote_fs $network $named $time
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop the mysql database server snmp agent
# Description:       Controls the launch/stop of Mysql SNMP agent.
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/sbin/mysql-snmp
DAEMON2="/usr/bin/perl"
NAME=mysql-snmp
DESC="Mysql SNMP Agent"
PID_FILE=/var/run/mysql-snmp.pid

test -x $DAEMON || exit 0

. /lib/lsb/init-functions

# Include mysql-snmp defaults if available
if [ -f /etc/default/mysql-snmp ] ; then
	. /etc/default/mysql-snmp
fi

set -e

START="--start --quiet --pidfile ${PID_FILE} --name ${NAME} --startas ${DAEMON}"
STOP="--stop --quiet --pidfile ${PID_FILE} --name ${NAME}"

case "$1" in
  start)
		echo -n "Starting $DESC: "
    if start-stop-daemon ${START} -- --daemon-pid ${PID_FILE} ${DAEMON_OPTS} >/dev/null ; then
            echo "${NAME}."
    else
            if start-stop-daemon --test ${DAEMON_OPTS} >/dev/null 2>&1; then
                    echo "(failed)."
                    exit 1
            else
                    echo "(already running)."
                    exit 0
            fi
    fi
    ;;
  stop)
		log_daemon_msg "Stopping $DESC" "$NAME"
		killproc -p ${PID_FILE} $DAEMON2
		log_end_msg $?
    ;;
  restart)
    $0 stop
    exec $0 start
    ;;
  force-reload)
    $0 restart
    ;;
  status)
    pidofproc -p ${PID_FILE} $DAEMON2 >/dev/null
    status=$?
    if [ $status -eq 0 ]; then
            log_success_msg "mysql-snmp server is running."
    else
            log_failure_msg "mysql-snmp server is not running."
    fi
    exit $status
    ;;
  *)
    echo "Usage: $0 start|stop|restart|status|force-reload"
    exit 1
    ;;
esac

exit 0

# NAME

tl-daemon - Run Timeline in background


# SYNOPSYS

*tl-daemon* {start|stop|kill|status}

# DESCRIPTION

Run *tl* in background and notify when specific patters appears in the timeline.

**start** [--foreground]

: Start Timeline in daemon mode, put Timeline in background, unless *--foreground*
option is present, in which case **tl** will start in foreground, but acting
as daemon.

**stop**

: Stop the Timeline Daemon

**kill**

: Force stop of the daemon

**status**

: Print the status of the daemon, if it's running or not.


# CONFIGURATION

*daemon.log.file*=*none*

: Set the log file of the daemon. By default, logging is disabled. Valid values
are a valid path, *stdout* which tells the daemon to print to standard output
the log, or *stderr* which tells the daemon to print to standard error.

*daemon.log.level*=*error*

: Set the daemon log level, valid values are *error* (the default) and *info*
(more verbose)

*daemon.interval*=*300*

: Set the interval time (in seconds) between two consecutives calls to *daemon.commands*

*daemon.commands*=*timeline refresh*

: A comma-separated list of commands to be executed by the daemon every
*daemon.interval* seconds.

*daemon.pidfile*=*$XDG_RUNTIME_DIR/tl.pid*

: The pidfile of the daemon

*notify.command*=*notify-send*

: The command to send notifications.

*notify.format*=*'Knock knock from %s:\n%s'*

: The format of the message to show in the notification. The first *%s* will
be expanded with the user who post the message, and the second one with the
message itself.

*notify.filter*=*mention*

: The filter to use to raise notifications. Read more about filters in the
**FILTER** section in the **tl-timeline**(1) man page.

*notify.cache-file*=*$XDG_CACHE_HOME/tl/notify.cache*

: The path to notification cache file. This file is used to track control
about what messages was already shown.


# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

*$XDG_RUNTIME_DIR/tl.pid*

: The default PID file for Timeline Daemon.

*$XDG_CACHE_HOME/tl/notify.cache*

: The default file for notification cache.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-timeline**(1), **send-notify**(1)

# TIMELINE

Part of the **tl**(1) suite.

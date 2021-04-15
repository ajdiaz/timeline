# NAME

tl-directory - Manage Timeline public directories


# SYNOPSYS

*tl-directory* {add|del|list|refresh|search} \<args\>...

# DESCRIPTION

Manage Timeline public directories. A public directory is a public URL that
contain a list of Timeline accounts that its owners decided to be published.

This a way to find new accounts interesting for you, but outside your network
(you can read more about your network in **tl-network**(1)). See below the
section **DIRECTORY FORMAT** to see how to create your own directory.

# SUBCOMMANDS

The *directory* commands accept the following subcomands:

**add** [\-\-force] \<name\> \<url\>

: Add a new public directory with the name passed as argument and the url
specified in arguments too. You can use the parameter *\-\-force* to override
any existent directory with the same name.

**del** \<name\>

: Forget the directory previouslyu added with that specific name.

**list**

: List all added directories in your *tl* instance.

**refresh** [name]

: Update the directory added with that specific name or all directories listed
in your Timeline instance. You should refreshing your directories frequently
(once per day is fine) to keep it up to date withe the upstream.


**search** \<regexp\>+

: Search for the regular expression(s) passed as argument(s) in all public
directories added to your Timeline.

# CONFIGURATION

Each directory added will be kept as key in your configuration file with the
format *directory.name = url*, where name and url are the arguments of **add**
subcommand.

Timeline suit configures by default one directory, called *default* which
points to main Timeline directory at https://tldir.ajdiaz.me, but you
can remove it or rename it if you want.

# DIRECTORY FORMAT

A directory is a text plain file contains one entry per line. The line has the
following format:

*name* *url* *tags..*

Where:

*name*

: Is a common name for the account. This name is how the owner of the account
prefers to be called. This is only a recommendation, you can of course follow
the account and give the name that you want.

*url*

: Is the URL to pull the account.

*tags*

: Is a white separated list of tags for the account. The directories can be
searched using regular expressions that match some of these tags.

Empty lines and lines started with a *#* sign will be ignored.

# FILES

*$XDG_CACHE_HOME/tl/directory.\**

: Each directory data will be stored here, in a file called *directory.name*, where
name is the name given to the directory when added.

# NOTES

1. The use of **tl-directory** requires external programs **curl** and
  **grep**.

2. You can use **tl-network**(1) as alternative to discover new accounts.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-network**(1), **re_syntax**(n), **curl**(1), **grep**(1)

# TIMELINE

Part of the **tl**(1) suite.

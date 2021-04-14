# NAME

tl-network - Discover your network


# SYNOPSYS

*tl-network* {list|refresh}

# DESCRIPTION

This commands allows you to discover your Timeline network. The network is
also known as friends-of-friends connection. This command will see who is
following by your followings and create a ponderated networks with the results.

When more edges are available to an account, more score in the network and
more relevant could be for you. For instance, an account A, followed by two
of your follows B and C, is more relevant than another account D followed
only by B.

# SUBCOMMANDS

**list**

: Print your discovered Timeline network


**refresh**

: Try to discover your network.


# CONFIGURATION

*network.list.{format,fields,color,color-field,style,style-field}*

: Set the proper format, fields and colors to display the network when execute
the subcommand *list*. To understand who format works, please read **FORMAT**
section in **tl-config**(1) man page.

*network.follower.{format,fields,color,color-field,style,style-field}*

: Set the proper format, fields and colors to display the followers
the subcommand *list*. To understand who format works, please read **FORMAT**
section in **tl-config**(1) man page.

*network.show-followers*=*true*

: If set to *true* (the default) the network **list** and **refresh** subcommand
will also display who is followed by who.

# FILES

*$XDG_CACHE_HOME/tl/network/*

: Stores the discovered network. Each time that you run **refresh** command
this data will be recreated.

# NOTES

1. You can use **tl-directory**(1) as alternative to discover new accounts.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-timeline**(1), **tl-directory**(1)

# TIMELINE

Part of the **tl**(1) suite.

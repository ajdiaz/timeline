# NAME

tl-view - Manage timeline views


# SYNOPSYS

*tl-view* {add|del|list} \<args\>

# DESCRIPTION

Views are sets of chained filters that you can save to quickly access to them
via **tl-timeline**(1) command.

The filters will be evaluated as a chain of OR operations, if the event match
almost one of the filter, then the filter will accept the event.

To known more about how filters can be used or the kind of filters that you
have available with Timeline, please read in the **tl-timeline**(1) man page,
the **FILTER** section.


# SUBCOMMANDS

The **tl-view** command accept the following subcommands:

**add** \<name\> \<filter\>+

: Create a new view with the name provided as argument which chain the filters
also passed in the arguments. You can pass all filters that you want.


**del** \<name\>

: Delete the view identified by the name provided as argument

**list**

: Display all configured views in your Timeline suite.


# CONFIGURATION SETTINGS

Views are save in the configuration file under the *views* section. You
can explore them using both, the **view list** subcommand or **tl-config**(1)
command.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl-config**(1), **tl-timeline**(1)

# TIMELINE

Part of the **tl**(1) suite.

# NAME

tl-alias - Manage your command aliases


# SYNOPSYS

*tl-alias* [\<name\> \<command\>]

# DESCRIPTION

Create, delete or show your command aliases. A command aliases is a way to call
commands and subcomands in a faster way. If you call the **tl-alias** without
arguments this will display all aliases defined in your config.

To set a new alias just pass two arguments, the *name* of the new alias and
the *command* to be called (it could be also composed by a subcomand, separated
by spaces, in that case you need to quote the command parameter).

You can delete the alias via the **tl-config**(1) command.

# CONFIGURATION SETTINGS

Aliases are saved in the configuration file under the section *alias*.

# DEFAULT ALIASES

There are some useful aliases that are defined by default when you install
Timeline:

*tr* - timeline refresh

*trn* - timeline refresh flag:new

*tl* - timeline list

*dr* - timeline refresh flag:new

*edit* - timeline edit

*e* - timeline edit

*post* - event post

*p* - event post

*reply* - event reply

*r* - event reply

*tag* - event tag

*info* - event info

*show* - event info

*score* - event score

*net* - network

*nl* - network list

*nr* - network refresh

*dir* - directory

*ds* - directory search

*pre* - account preview

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl-config**(1).

# TIMELINE

Part of the **tl**(1) suite.

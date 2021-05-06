# NAME

tl-abbr - Manage your abbreviations


# SYNOPSYS

*tl-abbr* [\<name\> \<command\>]

# DESCRIPTION

Create, delete or show your abbreviations. An abbreviation is a way to
translate some text in the input of an event for other text. For example
replacing *:smile:* for *:-)*.

To set a new abbr just pass two arguments, the *name* of the new abbr and
the *text* to replace *name* for.

You can delete the abbr via the **tl-config**(1) command.

# CONFIGURATION SETTINGS

Abbreviations are saved in the configuration file under the section *abbr*.

Also the following setting will change the abbreviation behaviour:

*input.emojis*=*false*

: If true enable native emoji support for abbreviations. See **tl-event**(1)
for more infirmation.

# DEFAULT ABBREVIATIONS

There are no default abbreviations unless the config setting *input.emojis*
is set to *true*.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl-config**(1), **tl-event**(1)

# TIMELINE

Part of the **tl**(1) suite.

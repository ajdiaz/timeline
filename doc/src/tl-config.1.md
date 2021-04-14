# NAME

tl-config - Configure your Timeline


# SYNOPSYS

*tl-config* {list|get|set|save|edit} {args...}

# DESCRIPTION

Manage the configuration of Timeline. This command has a number of subcommands depending
of the action to do. Each subcommands has its own parameters:

**list**

: List all configuration settings


**get** \<key\>

: Retrieve the value of the specific key.

**set** \<key\> \<value\>

: Set a new configuration value or reset a previous one.

**save**

: Dump the configuration settings to file

**edit**

: Open a editor (using environment variable *$EDITOR*) to edit manually the config file.


# CONFIGURATION

The configuration file is saved a git config file. There a number of configration keys which
are explained in the proper man page. For instance *network* keys will be explained in **tl-network**(1),
while generic ones are explained in **tl**(1) man page.

# FORMAT

The *tl* tool uses a very customizable printing mechanism to output the message
in commands like *timeline* or *network*. Messages are formated in the configuration
files, and explicit keys are explained in the proper man page of the command. But
there are some general key suffix:

*\<key\>.format*

: Set the output format. The output format is a **printf**(1) format, which
usually includes *%b* for color codes and *%s* for strings, but some fields
can also be casted to more comples output, like dates, for example a date
can be casted with *%Y-%m-%d* using the usual **strptime**(3) format.

*\<key\>.fields*

: Se the files to be printed using the format specified in *key.format*, the
  value must be a comma-separated list of fields, for example *date,name,user*,
  the fields will be expanded according to the format in the proper order.
  Each key must defined the fields that this configuration support, so fields
  for *network* could be different that fields for *timeline*, for instance.
  If you are curious about how format works internally check the source code
  file *src/format*.

*\<key\>{.|-}color-\<field\>*

: Set the color number to be used for the specific field. For example
*network.follower-color-date* set the color for the field *date* of the
output *follower* for command *network*. Color numbers depend of your
terminal capabilities. Check ANSI Color codes supported on your terminal.
The color must be a pair, comma separated, indicate the foreground in the
first term and the background in the second one, if missing use the 
default value. See **FORMAT EXAMPLE** below. A special value for color
is accepted: *CONSISTENT* which will use the same color (but a random one)
for each item.

*\<key\>{.|-}style-\<field\>*

: Set the font style for the field. Default value is *normal*, but *underline*
 and *italic* are valid too. Your term must support this kind of capabilities.
 See **tput**(1) man page to test it.

# FORMAT EXAMPLE

*network.list.format*='%b%s%b %b%s%b %b%s%b'

: Set the format for the network list, which consist in three fields,
all of them accept a color (the *%b* key before and after the *%s* will be
replace by the proper color.

*network.list.color*='7,'

: Set the default color, in this case use foreground color 7 (white) and use
default background (none set). Note the comma indicating the the background
term is missing.

*network.list.fields*='date,name,url'

: Set the fields to be displayed. In this case the fields *date*, *name* and *url*
in this exact order. The name of the fields must be supported by the command,
in this example **network list**.

*network.list.color-date*='3,'

: Set the color for field date to foreground 3 (yellow). Keeping all the other
fields to the default color setting in *network.list.color* parameter above.

*network.list.style-name*=italic

: Put the field name in the output in italic font (if the terminal support it).


# ENVIRONMENT VARIALES

*EDITOR*

: The editor used in **edit** subcomand to edit the configuration. If not present
use *vi*.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **git-config**(1), **strptime**(3), **printf**(1), **tput**(1)

# TIMELINE

Part of the **tl**(1) suite.

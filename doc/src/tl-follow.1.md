# NAME

tl-follow - Manage the accounts you follow


# SYNOPSYS

*tl-follow* {list|add|del} \<args\>+

# DESCRIPTION

Manage the accounts you follow in your Timeline instance. This command
accept subcommands.

**list**

: List the accounts you follow.


**add** \<pull_url\> [name]

: Start to follow the account pointed by the *pull_url* address. An optional
*name* will be used as user name, i.e. a familiar name for you instead of
long OID.

**del** [\-\-url] \<uid/url\>

: Stop follow an account idenfied by specific OID, or the specific *pull_url*
as was registered on **add** command.


# CONFIGURATION

This command has not associated configuration.

# FILES

*$XDG_DATA_HOME/tl/account/\*/FOLLOW*

: The path where followings of the account are registered.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **git-submodule**(1)

# TIMELINE

Part of the **tl**(1) suite.

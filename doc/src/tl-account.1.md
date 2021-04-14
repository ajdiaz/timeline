# NAME

tl-account - Manage your Timeline accounts


# SYNOPSYS

*tl-account* {create|delete|rebuild|clone|list|refresh|active|preview} {args...}

# DESCRIPTION

Manage the accounts for Timeline. This command has a number of subcommands depending
of the action to do. Each subcommands has its own parameters:

**create** [\-\-keyid \<keyid\>] \<name\> \<push_url\> \<pull_url\> [\<path\>]

: Create a new empty account (aka git repository) which will
push data to specified push_url and publish public url
as specified pull_url. Optionally, you can set the pat
where repository lives, if omit, uses default path for
accounts (see **FILES** below). The *\-\-keyid* flag sets a GPG keyid for
signing commits.

**delete** [\-\-force] \<name\>

:  Delete the account with name passed as argument.
If *\-\-force* parameter is present, then ignore if
account path exists or not, otherwise account delete
will not delete anything if path does not exists.
**CAUTION: this action cannot be undone.**

**rebuild** \<name\>

:  Recreate an account previously created. This command will
use config data to regenerate the account. This command is intended to use
when you accidentaly remove the contents of your account directory.

**clone**  [\-\-keyid \<keyid\>] \<name\> \<push_url\> \<pull_url\> [\<path\>]

: Similar to **create**, but use a previously initilizated and remote
repository instead of create new empty one.

**list**

: Return a list of configured accounts.

**active** [name]

: Switch to account passed as argument, or, if none, load
the default account. Default account when more than one
is created will be specified by configuration parameter
called *account.default*. See **tl-config**(1) for more information about how
to configure parameters.

**keyid** \<keyid\>

: Set the GPG KeyID to sign commits for the current active account. You can
use this command to set a key in account previously created but where KeyID was
not configured.

**refresh**

:  Pull changes from the remote repository. This action
should be automatically and you should not use it
manually. But, if you need it, here it is.

**preview** \<url\>

: Preview the contents of a remote account given its URL. This command allows you
to explore a remote account without following it.

# CONFIGURATION SETTINGS

The **account** command accept the following configuration settings that you can
set using **tl-config**(1) command:

*account.auto-push*=*true*

: If *true* (by default) always push a commit after created a new event or action
in the account.

*account.content-markdown*=*true*
: If *true* (by default) also generate **CONTENT.md** file in the repository with
Markdown format, intended to be served in Gemini server.

*account.preview-depth*=*100*

: Set the number (integer) of depth that a preview can go. This means that you
can only see this maximum number of post in a command **account preview**.

*account.default*

: Set the name of the default account if you have a multi account setup.

*account.keyid*

: Set the default KeyID for all accounts. It is recommended to set this paramenter
by account using the **account keyid** command.

*account.max-posts*=*20*

: The the number (integer) of posts that will be shown for every account. No more that
this number will be show for each configured follow or account.

*account.path*=*$XDG_DATA_HOME/tl/account/:$HOME/.tl/account*

: The path where account repositories will be kept. The path will be evaluated
in order, but new accounts will be created in the first one.


All this variables can also set by specific account, for example for KeyID:
*account.XXX.keyid* will be used for account called *XXX*. Note that configuration
for account expect the user name of the account (friendly name) not the OID.

# ENVIRONMENT VARIALES

*TIMELINE_EXPERIMENTAL_SHA256*

: Enable experimental feature of SHA256 hashed git objects. See **NOTES** below.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

*$XDG_DATA_HOME/tl/account/*

: Default directory where your account's repositories live.

# NOTES

1. Currently Timeline uses SHA-1 objects in git repo, which is the git recommendation.
   But git also support SHA-256 objects since version 2.19. In the future this
   could be change and repositories will be incompatible. If you want to be one
   step ahead, at your risk, you can set the enviroment variable *TIMELINE_EXPERIMENTAL_SHA256*
   to true (or any value different that empty string) to enable SHA256 objects.
   This value only make sense with **acount create**. See **git-init**(1) for more information.

2. The use of GPG signature for commits relies on git and gpg, so you need to have
   a GnuPG version installed on your systems to use this feature.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-user**(1), **tl-config**(1), **gpg**(1)

# TIMELINE

Part of the **tl**(1) suite.

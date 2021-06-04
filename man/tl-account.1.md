# NAME

tl-account - Manage your Timeline accounts


# SYNOPSYS

*tl-account* {create|delete|rebuild|clone|list|refresh|active|preview|keys|keygen|keyrevoke|encrkey|signkey} {args...}

# DESCRIPTION

Manage the accounts for Timeline. This command has a number of subcommands depending
on the action to do. Each subcommands has its own parameters:

**create** \<name\> \<push_url\> \<pull_url\> [\<path\>]

: Create a new empty account (aka git repository) which will
push data to specified *push_url* and publish public URL
as specified *pull_url*. Optionally, you can set the pat
where repository lives, if omitted, uses default path for
accounts (see **FILES** below). This step will also create a key pair for
sign and encrypt events (see **tl-crypto**(1) for more information), unless
the configuration parameter *account.auto-keygen* is set to false.

**delete** [\-\-force] \<name\>

:  Delete the account with name passed as argument.
If *\-\-force* parameter is present, then ignore if
account path exists or not, otherwise account delete
will not delete anything if path does not exist.
**CAUTION: this action cannot be undone.**

**rebuild** \<name\>

:  Recreate an account previously created. This command will
use configuration data to regenerate the account. This command is intended to use
when you accidentally remove the contents of your account directory. Please note
that this command cannot regenerate your keyring, that means, in practice, that
if you remove your keyring storage directory too you will lose access to old
encrypted messages.

**clone** \<name\> \<push_url\> \<pull_url\> [\<path\>]

: Similar to **create**, but use a previously initialized and remote
repository instead of create new empty one.

**list**

: Return a list of configured accounts.

**refresh**

:  Pull changes from the remote repository. This action
should be automatically, and you should not use it
manually. But, if you need it, here it is. This action also update the
account keyring with the new keys imported from follows, unless the configuration
option *crypto.auto-import* is set to false.

**active** [name]

: Switch to account passed as argument, or, if none, load
the default account. Default account when more than one
is created will be specified by configuration parameter
called *account.default*. See **tl-config**(1) for more information about how
to configure parameters are used.

**preview** \<url\>

: Preview the contents of a remote account given its URL. This command allows you
to explore a remote account without following it.

**keys**

: List the current secret keys available for the account. The flags *S* and *E*
at the right of the KeyID will indicate the default key for sign and encrypt,
respectively.

**keygen** [--no-default-sign] [--no-default-encr]

: Generate a timeline key pair to encrypt and sign events in the current active
account. By default the generated key is set as default key for sign and encrypt,
unless *--no-default-sign* or *--no-default-encr*.

**keyrevoke** [--force] \<KeyID\>

: Revoke the KeyID you pass as argument. Please note that you cannot revoke current
default key for sign or encrypt (well, actually you can if `--force` option
is present, but you should generate a new key pair before).

**encrkey** \<KeyID\>

: Set the provided Keyid as default encryption key for the current account.

**signkey** \<KeyID\>

: Set the provided Keyid as default sign key for the current account.


# CONFIGURATION SETTINGS

The **account** command accept the following configuration settings that you can
set using **tl-config**(1) command:

*account.auto-push*=*true*

: If *true* (by default) always push a commit after created a new event or action
in the account.

*account.auto-keygen*=*true*

: If *true* (by default) always create a key pair on *create*, *clone* and
*rebuild* (in this case only if no previous one found).

*account.content-markdown*=*true*
: If *true* (by default) also generate **CONTENT.md** file in the repository with
Markdown format, intended to be served in Gemini server.

*account.preview-depth*=*100*

: Set the number (integer) of depth that a preview can go. This means that you
can only see this maximum number of post in a command **account preview**.

*account.default*

: Set the name of the default account if you have a multi account setup.

*account.signkey*

: Set the default sign KeyID for all accounts. It is recommended to set this parameter
by account using the **account signkey** command. YOU SHOULD AVOID CHANGING THIS
SET MANUALLY, because the sign key setted for an account is also saved locally
in the account repository work tree.

*account.encrkey*

: Set the default encryption KeyID for all accounts. It is recommended to set this parameter
by account using the **account encrkey** command.

*account.encrypt-to-me*=*true*

: If *true* (the default) when post an encrypted event, the event will also
be encrypted to you as recipient, so you can also see your event in your timeline.

*account.max-posts*=*20*

: The number (integer) of posts that will be shown for every account. No more that
this number will be show for each configured follow or account.

*account.path*=*$XDG_DATA_HOME/tl/account/:$HOME/.tl/account*

: The path where account repositories will be kept. The path will be evaluated
in order, but new accounts will be created in the first one.

*account.keyring*

: Set the path of the keyring for account. For security reasons, global keyring
for all accounts will be ignored. Per account set is created prefixing to the
name of the account the first path found in setting *crypto.keyring-path*.
See **tl-crypto**(7) for more information.

## Per account variables

All these variables can also set by specific account, for example for KeyID:
*account.XXX.keyid* will be used for account called *XXX*. Note that configuration
for account expect the username of the account (friendly name) not the OID.

# ENVIRONMENT VARIABLES

*TIMELINE_EXPERIMENTAL_SHA256*

: Enable experimental feature of SHA256 hashed git objects. See **NOTES** below.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

*$XDG_DATA_HOME/tl/account/*

: Default directory where your account's repositories live.

# NOTES

1. Currently, Timeline uses SHA-1 objects in git repository, which is the git recommendation.
   But git also support SHA-256 objects since version 2.19. In the future this
   could be change and repositories will be incompatible. If you want to be one
   step ahead, at your risk, you can set the environment variable *TIMELINE_EXPERIMENTAL_SHA256*
   to true (or any value different that empty string) to enable SHA256 objects.
   This value only make sense with **account create**. See **git-init**(1) for more information.

2. The use of GPG signature for commits relies on Git and GPG, so you need to have
   a GnuPG version installed on your systems to use this feature. The encryption
   feature relies only in GPG.


# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-user**(1), **tl-config**(1), **tl-crypto**(7), **gpg**(1)

# TIMELINE

Part of the **tl**(1) suite.

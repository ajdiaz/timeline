# NAME

tl-crypto - Cryptography in Timeline


# SYNOPSYS

*tl* *

# DESCRIPTION

This manual page will explain how encryption works in Timeline. Timeline core
uses **git**(1) for signing (which uses GPG at the bottom) and **gpg**(1)
directly for encryption.

# KEY GENERATION

By default Timeline will create a new key pair for each account that you create
or clone. These key pairs will stored at a keyring per account. The path of the
keyring is made joining the value of *crypto.keyring-path* with the account
name (the human name provided as alias if any, or the account OID in other
case). This will create keys using ED25519/CV25519 algorithms (read the
**gpg**(1) manual for more information). The private part of the key will
be stored in the keyring path, and the public part will be exported armored
in two files in your account repo: *ENCRKEY* and *SIGNKEY* for encryption and
signing, respectively.

**WARNING!** If you remove accidentally the keyring path of the account you
will lose all private keys for that account, which means that you will be
not able to recover any previously encrypted message or signing new commits
with the same key. (Of course you can generate a new key pair).

You can generate at any time a new key pair using the command:

```{console}
tl account keygen
```

This command will generate a new key pair for the current enable account
(you can use the *-a* option in the command line to select other account
different than default one).

When you generate a new key pair these will be enabled as default keys for
signing and encryption, and updating the *ENCRKEY* and *SIGNKEY* files. You
can avoid this behaviour adding *--no-default-encr* and *--no-default--sign*
to not set the key as default for encryption and signing, respectively. See
**tl-account**(1) for more information.

You can use the command `tl account keys` to see the current available keys
for your account.

# KEY IMPORTATION

If the configuration setting *crypto.auto-import* is set to true, then on
every *refresh* of the timeline, or in every *follow add* command, Timeline
will inspect the remote repository for published *ENCRKEY* and *SIGNKEY* and
import them to the proper account keyring. You can avoid this behaviour
setting the configuration value to *false*, but then you need to handle
manually the updating process of your keyring. We really discourage this
approach. Let timeline to handle keys for you.

# KEY REVOCATION

You can revoke a key at any time by the command `tl account keyrevoke \<keyID\>`.
Once the key is revoked another one is automatically selected as primary
key for signing and encryption (if the revoked one was the primary one, of course).
You can change the default key as usual via the *account encrkey* and *account singkey*
commands.

The revoked key will be also exported in your *ENMCRKEY* or *SIGNKEY* (or both)
to inform your followers that this key is invalid from now. Previous revoked
key will kept in the keyring to ensure to read and verify old messages.

# SIGNING PROCESS

You can set any key to default as signing key using the command `tl account signkey \<keyID\>`.
If the key is set then on any event (post, reply...) you will sign the commit
with the proper key. You can also change the key to sign using the previous
command at any moment.

**WARNING!** Try to avoid changing the key ID manually in the configuration
file. Although this is possible, you need to change also the `.git/config`
file in the proper repository manually, which can provoke some confusion.
Is better to use the **tl-account**(1) command to do that.

# ENCRYPTION PROCESS

The encryption of an event uses **gpg**(1) to encrypt and sign the event
and save it as new event of *encrypted kind*. (Read **tl-event**(1) and
**tl-timeline**(1) to know more about event kinds). This event include a
recipient account (to who the message is intended to). The recipient can be
an account ID (we call this a *direct* message) or the special keyword *@all*
(we call this a anonymous recipient message). When *@all* is used the message
can be read for “anyone with the key” and, in fact, is not very different
of a direct message, but keep the recipient hidden. This is a plus for
anonymity conversations. By default timeline accept anonymous messages, but
you can ignore all of them setting *crypto.ignore-anon* configuration value
to *true*.

Also if you do not specify that an encrypted event is anonymous (using `--encrypt-anon`
option in **tl-event**(1) instead of `--encrypt`), the encryption will be
always direct, unless *crypto.always-anon* configuration value was set to true.

The encrypted kind event contains also a BASE64 encoded cryptogram produced
by **gpg**(1). The encrypted details of a successfully decrypted message can
be see using `event info` command.

Also, if *account.encrypt-to-me* is set to true (by default), timeline will
also post the same payload encrypted to yourself (in direct or anonymous
message, depends on the option chosen to the original message). The idea
behind this behaviour is to allows you to see encrypted messages for other
people. Like you cannot decrypt messages for others, you need also to send
a message to yourself to can decrypt it.

# DECRYPTION PROCESS

When timeline detects an encrypted event, just try to decrypt the payload. If
it's a direct message and is not for us, just ignore the message, unless
*timeline.show-all-encrypted* configuration value is set to true, in which case
an informational message is printed (of course you cannot decrypt a message
that is not for you). If the message is a direct one and it's for us, then
payload is decrypted and new event with the content of the payload is processed.


**NOTE** In fact, an encrypted message is more like an encrypted event, that means
that the decrypted payload contains another event, like a (plain) post, tag...
But also is possible to encrypt a already encrypted payload, and timeline just
run the decryption process twice, or more times if required. By design the **tl**(1)
command does not allow you to encrypt more than one time, but it should be possible
in theory.

For anonymous encrypted messages, timeline will try to decrypt it with any
available secret key in the account's keyring, unless *crypto.ignore-anon* is
set to true. If the decryption process fails, the message is ignored silently
(unless *timeline.show-anon-failed* is set to true, in which case an error
message is displayed on the timeline).

Decrypted messages will never be cached for security reasons.

# USING AN EXTERNAL GENERATED KEYS

**WARNING!** We discourage the use of external keys in timeline for some
reasons. The first one is that key could potentially exfiltrate some of your
personal data if you set them in your key, while the generated ones are only
associated with the timeline account. The second one is that the updating
process is responsible of the user, so you need to verify the other's key by
hand.

If you want to use an external keyring it's possible just setting the configuration
value *account.\<account_name\>.keyring* to the path of your keyring (usually `~/.gnupg`). This
configuration value must be set by account for security reasons, you cannot set
a global *account.keyring*. Finally you must set your default keys using the
commands *account encrkey* and *account signkey*. Is also recommended to disable
*account.auto-keygen* and *crypto.auto-import* to avoid the creation and the
importation of other keys and kept clean your keyring.

# CONFIGURATION SETTINGS

*account.auto-keygen*=*true*

: If set to *true* (the default) a new key pair will be created on any *account create*,
*account clone* or *account rebuild*.

*account.\<account_name\>.encrkey*, *account.\<account_name\>.signkey*

: Contains the Key ID of the keys used to encrypt and to sign for the specific
account. **DO NOT CHANGE THIS VALUE BY HAND. USE tl account encrkey OR tl account signkey INSTEAD**.

*account.encrypt-to-me*=*true*

: If set to *true* (by default) also generate a new encrypted message for yourself
for any encrypted message that you post (read **ENCRYPTION PROCESS** above for more information).

*crypto.gnupg-binary*=*gpg*

: Set the path to the **gpg**(1) binary to use, by default try to find it from `$PATH`.

*crypto.auto-import*=*true*

: If set to *true* (the default) timeline will import keys from followings automatically
and update them when necessary.

*crypto.ignore-anon*=*false*

: If set to *true* (*false*, by default) timeline will ignore all non-direct encrypted
messages. See **DECRYPTION PROCESS** above for more information).

*crypto.always-anon*=*false*

: If set to *true* (*false*, by default) all encrypted events will be posted as
anonymous messages instead of direct ones, even if no anonymity flag is set in
the command. Read **ENCRYPTION PROCESS** above for more information.

*crypto.keyring-path*=*${XDG_DATA_HOME:-$HOME/.local/share}/tl/keyring:$HOME/.tl/keyring*

: Set the PATH to prefix keyring. When a new keyring is created for an account, timeline
will search for all paths in this variable if any of them is already created, if so then
use it as prefix for the keyring to the account (the final keyring will be this
prefix plus the account name). If no one exists, then use the first one.

: You can see this configuration setting as a global *account.keyring*, which is
not used for security reasons.

# SOME DANGEROUS ERRORS

*ERROR Ignoring key XXX: account does not match YYY != ZZZ*

: This error means that the remote account publish a key pair intended to be
someone else. Timeline just remove these keys from your keyring. Most of the cases
this is a MITM attack attempt, but if you are really sure that the key is
correct, you need to import it manually using **tl-gpg**(1)

*SECURITY RISK. You've imported and invalid key*

: This error should never happen. Means that timeline import a key that cannot
verify (see the previous error), but timeline was not able to remove it from
the keyring, so the key is already imported. You must fix it manually with
**tl-gpg**(1).

# NOTES

* All the encryption and the signing process of the timeline rest on the shoulders
  of GPG, which means that it should be safe. Of course any security concern in GPG
  will also affect timeline.

# SEE ALSO

**tl**(1), **timeline**(7), **tl-timeline**(1), **tl-event**(1), **tl-config**(1), **tl-account**(1), **gpg**(1), **git**(1), **tl-gpg**(1).

# TIMELINE

Part of the **tl**(1) suite.

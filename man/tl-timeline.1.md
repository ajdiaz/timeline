# NAME

tl-timeline - Manage your timeline


# SYNOPSYS

*tl-timeline* {list|refresh|edit|orphans}

# DESCRIPTION

The **timeline** command allows you to manage your timeline. The timeline is
a way to see the posts of your accounts and also the accounts you follow.

# SUBCOMMANDS

The following subcommands are accepted with timeline command:

**list** [filter]

: Show current available timeline, but not refresh it from
the internet. Usually you want to use this if you are
offline, else use **refresh** subcommand instead.
For known more about filters read the **FILTER** section below.

**refresh** [filter]

: Pull changes in the current enabled timeline and show the results.
The filter passed as argument are used in the later display of the results,
not in the refresh. For known more about filters read the **FILTER** section
below.

**edit**

: Interactively edit your timeline. It's an advanced mode, use with careful.


**orphans**

:  Show the events in the timeline which are marked as orphans, usually these
are events that HMAC does not match. Find out more about orphaned events
in **timeline**(7) manual page.

# FLAGS

: Flags are special characters using in the timeline output to find out some
characteristics of the event. There are the following flags in order (left to right):

* **Encryption Flag**. (See configuration settings for *timeline.post.flag-encrypted-\**
  to view all possible values).
* **Signing Flag**. (See configuration settings for *timeline.post.flag-signed-\** to view
  all possible values).
* **Trust Flag**: Set to *timeline.post.flag-trusted* for replies, tags and scores that has a validated reference.
  This flags essentially means that the reply/tag/score was actually confirmed that was
  done for the specific event which refers, and no change are made in the original event.
  From version 1.9 all events should be trusted.
* **New Flag**: Set to *timeline.post.flag-new* for events that was never printed before.
* **Tagged Flag**: Set to *timeline.post.flag-tagged* for events that are tagged.
* **Reply Flag**: Set to *timeline.post.flag-replies* for events that are replied.

# CONFIGURATION SETTINGS

*timeline.show-untrusted-items*=*true*

: If true (by default) show events that cannot be verified that are related with
another one. This can happen when HMAC verification of a reply/tag/score fails.
Read more about HMAC signatures in **timeline**(7) manual page.

*timeline.show-all-encrypted*=*false*

: If set to true (false by default) show an informational message when an
encrypted event is found in the timeline, but cannot be decrypted.

*timeline.show-anon-failed*=*false*

: If set to true (false by default) show an error message when an anonymous encrypted
message found, but we cannot decrypt it. See **tl-crypto**(7) for more information
about anonymous encrypted messages.

*timeline.show-replies*=*true*

: If true (by default) show replies in the timeline.

*timeline.show-tags*=*true*

: If true (by default) show tags in the timeline.

*timeline.react-on-all*=*true*

: If true (by default) timeline will react (usually run a notification) when
found *@all* or *@everyone* mentions. See **tl-daemon**(1) for more
information about notifications.

*timeline.filter.show*=*''*

: When nonempty only events that matches the filter will be displayed. Read more
about filters in **FILTER** section below.

*timeline.filter.hide*=*'tag:spam score-min:0'*

: When nonempty remove from the display all events that match with that filter.
Read more about filters in **FILTER** section below.

*timeline.own-posts*=*true*

: When set to *true* (by default) show also your own events.

*timeline.use-shorts-ids*=*true*

: When *true* (by default) if the account has no username assigned, then
instead of show the entire OID number, display a short version. Read **timeline**(7)
and **tl-account**(1) page to known more about OIDs.


*timeline.post.format*=*'%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'*

*timeline.tag.format*=*'%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'*

*timeline.reply.format*=*'%b%-3d%b %b%(%Y%m%d %H%M%S)T%b %b%10s%b [%b%s%b] (%b%d%b) %b%s%b'*

: Set the format for timeline lines. See **FORMAT** section in **tl-config**(1)
manual for more information about formating. You can set the format for
*post*, *reply* and *tag*. Scores by nature are not displayed in timeline
as independent line.


*timeline.post.highlight-mesg*=*'@\[\^\\ ,.:;=\\!\\?]+'*

*timeline.reply.highlight-mesg*=*'@\[\^\\ ,.:;=\\!\\?]+'*

: Set the pattern used to highlight messages. A highlighted message should
be displayed in reverse mode. Only replies and posts can be highlighted.


*timeline.post.prefix*=*''*

*timeline.reply.prefix*=*'> '*

*timeline.tag.prefix*=*'# '*

: Set the prefix for every kind of event. Usually you want to prefix replies and
tags.


*timeline.reply.indent*=*' '*

*timeline.tag.indent*=*' '*

: Set an indentation spaces for replies and tags.


*timeline.post.flag-signed-good*=*S*

*timeline.post.flag-signed-bad*=*!*

*timeline.post.flag-signed-unknown*=*?*

*timeline.post.flag-signed-expired*=*X*

*timeline.post.flag-signed-revoked*=*R*

*timeline.post.flag-signed-missing*=*m*

*timeline.post.flag-signed-none*=*' '*

: Set the flags of signature. The signature is taken from the git log. So you
can verify here signed commits. To known more about signed commits, please read
**git-commit**(1). The same flags are available for *reply* and *tag* events.

*timeline.post.flag-encrypted-good*=*K*

*timeline.post.flag-encrypted-bad*=*!*

*timeline.post.flag-encrypted-unknown*=*m*

*timeline.post.flag-encrypted-expired*=*X*

*timeline.post.flag-encrypted-revoked*=*R*

*timeline.post.flag-encrypted-none*=*' '*

: Set the flags of encrypted. The encrypted result and encrypted key status is
taken from the GPG status. Read **tl-crypto**(7) manual page for more information.
The same flags are available for *reply* and *tag* events.

*timeline.post.flag-tagged*=*T*

*timeline.reply.flag-tagged*=*T*

: Set the flag to set when a post or a reply is tagged, but *timeline.show-tags*
are set to *false*.

*timeline.post.flag-replied*=*R*

*timeline.reply.flag-replied*=*R*

: Set the flag to set when a post or a reply is replied, but *timeline.show-replies*
are set to *false*.

*timeline.post.flag-new*=*N*

*timeline.reply.flag-new*=*N*

: Set the flag to set when a post was not previously shown in the index.

*timeline.post.flag-trusted*=*\**

*timeline.reply.flag-trusted*=*\**

: If *timeline.show-untrusted-items* is *true* then this flag will mark the
events that are trusted.

# FILTER

The filters are a way to simplify the output of the timeline. Filters allow you
to discard or show events according to some criteria. In general a filter is
really a list (white-separated) of criteria. The following criteria are available:

**tag:\<tag\>**

: Show (or hide if you are using the filter in *timeline.filter.hide*) the
events with the tag *tag*.

**flag:{trust|new|signed|sign-good|sign-bad|sign-unknown|sign-revoked|sign-missing|sign-expired}**

: Show (or hide) the events when the specific flag set. Valid flags are
*trust* (for trusted replies and all posts), *new* (for not already displayed
events), *signed* (for events signed, no matters the signature validation),
or specific *signed-\<status\>* (for only signed events which this particular
signature status).

**score-min:\<score\>**

: Show (or hide) events with almost *score* points.

**score-max:\<score\>**

: Show (or hide) events with no more than *score* points.

**view:\<view\>**

: Show (or hide) events that match the specific view. Read **tl-view**(1) for
more information about views.

**text:\<string\>**

: Show (or hide) events that match with the specified text. You can use
shell globs here, like *\** or *?*, but not regular expressions. Also, this
is the default filter, which means that if the filter expression does
not match with anyone in this list, then timeline will understand a text
filter with the *string* provided as filter.

**mention**

: Show events that mentions you, using the username that you provided to
your account. Please note that if someone mentions you with different
name this filter is useless.

# INDEX

Every event displayed in the timeline will be prefixed (according to the
format configured) with a sequential number called *index*. The index allows
you to refer to an event easily, without need to know the OID of the event
(EID).

Read the **tl-tutorial**(7) to learn how to use the index number or
discover the EID of an event.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

*$XDG_CACHE_HOME/tl/index.\*.cache*

: The file where the last generated index for an account is kept.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl-config**(1), **tl-view**(1), **tl-account**(1), **git-commit**(1)

# TIMELINE

Part of the **tl**(1) suite.

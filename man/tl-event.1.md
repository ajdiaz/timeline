# NAME

tl-event - Manage Timeline events


# SYNOPSYS

*tl-event* {post|reply|tag|score|info} \<args\>...

# DESCRIPTION

The **tl-event** command is the main command of Timeline. You can publish post,
replies, tags or scores in your timeline as also inspect other people
events.

Events, posts, replies, etc. are not the same thing. If you have a mess with
these terms, please read **TERMINOLOGY** section in **tl**(1) man page.

# SUBCOMMANDS

The **event** command allows the following subcommands and its respective
arguments:

**post** [--encrypt \<user\> | --encrypt-anon \<user\>] \<message\> [\<tags\>+]

: Post a new message in your timeline, if configuration option *account.auto-push*
is set to *true*, then also will push the change to the public repository. A
**message** could be any UTF-8 encoded text, including emojis, or any other
unicode stuff. Additionally, you can tag your post in the same step. Message
used in post will support **ABBREVIATIONS**. If `--encrypt` or `--encrypt-anon`
are present, the event will be posted encrypted. See **tl-crypto**(7) for
more information about how crypto works. 

**reply** [\-\-eid] \<num/eid\> \<message\> [\<tags\>+]

: Post a message as reply of the specific event. The source event to reply
can be identified by an EID (i.e. the unique identifier for a message that
you can get via **info** command), or easier, using the index number that
you can see when do a **tl-timeline**(1) *list* command. Additionally, you can
tag your post in the same step. Message used in reply will support
**ABBREVIATIONS**.

**tag**  [\-\-eid] \<num/eid\> \<tags\>+

: Tag an event with specific tags passed as arguments (white-space separated
list). You can identify the source event to tag using EID or timeline index,
like in *reply*, as explained above. See **timeline**(7) for more information
about what tags are.

**score**  [\-\-eid] \<num/eid\> {up|down}

: Score up (give +1 point) or down (give -1 point) to a specific event.
You can identify the source event to score using EID or timeline index,
like in *reply*, as explained above. See **timeline**(7) for more information
about what scores are.

**info**  [\-\-eid] \<num/eid\> 

: Get the event information for the event identified by the specific timeline
index number or EID (when *\-\-eid* is present).

# ABBREVIATIONS

Message used in post and reply will be parsed and some symbols can be replaced
by others. We call these abbreviations. For instance, you can add an abbreviation
using the *abbr* command (see *tl*(1)) to create an abbreviation *:lol:* to
be replaced by *:-D*.

Since version 1.9 Timeline support emojis natively, so no specific abbreviations
are required. Just enable it using configuration setting *input.emojis* to *true*

# CONFIG SETTINGS

*input.emojis*=*false*

: if true support natively emojis. Symbols like *:love:*, or *:smile:* will be
replaced by the proper emoji code. You can use the *abbr* command to list
all.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-timeline**(1), **tl-crypto**(7)

# TIMELINE

Part of the **tl**(1) suite.

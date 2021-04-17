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

**post** \<message\> [\<tags\>+]

: Post a new message in your timeline, if configuration option *account.auto-push*
is set to *true*, then also will push the change to the public repository. A
**message** could be any utf-8 encoded text, including emojis, or any other
unicode stuff. Aditionally you can tag your post in the same step.

**reply** [\-\-eid] \<num/eid\> \<message\> [\<tags\>+]

: Post a message as reply of the specific event. The source event to reply
can be identified by an EID (i.e. the unique identifier for a message that
you can get via **info** command), or easier, using the index number that
you can seen when do a **tl-timeline**(1) *list* command. Aditionally you can
tag your post in the same step.

**tag**  [\-\-eid] \<num/eid\> \<tags\>+

: Tag a event with specific tags passed as arguments (white-space separated
list). You can identify the source event to tag using EID or timeline index,
like in *reply*, as explained above. See **timeline**(7) for more information
about what tags are.

**score**  [\-\-eid] \<num/eid\> {up|down}

: Score up (give +1 point) or down (give -1 point) to a specific event.
You can identify the source event to score using EID or timeline index,
like in *reply*, as explained above. See **timeline**(7) for more information
about what scores are.

**info**  [\-\-eid] \<num/eid\> 

: Get the event information for the event idenfied by the specific timeline
index number or EID (when *\-\-eid* is present).

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl**(1), **tl-timeline**(1)

# TIMELINE

Part of the **tl**(1) suite.

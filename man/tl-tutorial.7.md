# NAME

tl-tutorial - A tutorial for new users in Timeline


# SYNOPSYS

*tl* *

# DESCRIPTION

This tutorial explains how to start with Timeline, how to create new account
or clone a previously existing one, follow other accounts, how to post, reply,
etc.

# CREATING OR CLONING ACCOUNT

There two different ways to start to use Timeline. The first one is creating a
new account, and the second one is cloning a previosly created one.

In the following examples we will create a local account named *myaccount*. The
name is how you can identify your account to manipulate it or in timeline
display, but keep in mind that this name is only for you.

## Creating new acccount

This is recommended way to use if you own your git repository server.

```{console}

tl account create myaccount push_url pull_url
```

Where *push_url* and *push_url* are the respective pull and push url grabbed from
your public repository.

Optionally you can add your public GPG key id to the config, to sign every
post that you do, executing the command:

```{console}
tl account keyid 0xffff
```

Where *0xffff* is your GPG key id.

## Clonning for remote repository

This is the recommende way for a public store repository,
To create a new account you must keep in mind that you need a public[^1] git repository.
You can use your own server (see *Creating new account* above)
or create a public account in one of the many public services that exists
for that[^2]. Once you created your public repo just grab the pull and the push
url (the pull one usually is HTTP/GIT while the push usually is SSH). Then
execute:

```{console}
tl account clone myaccount push_url pull_url
```

Where *push_url* and *push_url* are the respective pull and push url grabbed from
your public repository.

Optionally you can add your public GPG key id to the config, to sign every
post that you do, executing the command:

```{console}
tl account keyid 0xffff
```

## Rebuild from config

This option is intended to use when you accidentaly remove your local copy of
the the account. To restore from config just type:

```{console}
tl account rebuild myaccount
```

# FOLLOW OTHER ACCOUNTS

To follow other accounts you need to known the pull URL for them. You can discover
this URL using a couple of mechanism, please read **DISCOVERING NETWORK** section
and the **DIRECTORY** section.

Once you known the pull URL, just follow the account running the command:

```{console}
tl follow add pull_url myfirstfollow
```

This will add the account pointed by *pull_url* and internally you will name
this account as *myfirstfollow*. Please note that this name is internally for
you, and cannot be the same that other user use for the same account.

# SEE YOUR TIMELINE

The timeline is the list of all events what happened to you and to the accounts
that you follow. To see your current timeline just type:

```{console}
tl timeline refresh
```

or use the abbreviated form:

```{console}
tl tr
```

As you can notice, this command need to refresh the timeline, pulling changes
from all accounts that you follow. If you only want a quick view, and you do
not need the latest events, you can display the latest cached version doing

```{console}
tl timeline list
```

or also, with an abbreviated form:

```{console}
tl tl
```

In the output you will find something like that (it depends of your output format,
which you can change editing the config, please read **tl-config**(1) for know
more about formatting).:

```
24  20210321 171504  @timeline [SNT] (0) Hello @all We have new release: 1.6, codename “Engagement”
^^  ^^^^^^^^^^^^^^^  ^^^^^^^^^ ^^^^^ ^^^ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
|        |               |      |     |                          |
|        |               |      |     |                          This is the message of the post.
|        |               |      |     This is the score of the post
|        |               |      There are some flags
|        |               This is the user name of the account who post it.
|        This is the date and time of the event
This is the index id of the event.
```

Here is a more detailed explanation of the fields:

*Index Id*

: This is a temporary index which is generated each time that you display the timeline.
This index will allow you to reply or interact with other post more easy. Read the
section **POST AND REPLY MESSAGES** below to find out who the index id can help you.

*Date and time*

: No need more explanation, just the date and time of the post. By design Timeline does not support
more that one message per second in the same account. The format of the date, as also the entire
line is configurable via **tl-config**(1), please read also **tl-timeline**(1) to known more about
how to format lines and dates.

*Username*

: Is the username of the owner of the post. If the account has a familiar username then we will
use it, if not then use the account OID which is, sometimes a ver unconfortable large number.
See **tl-user**(1) to know more about how to set familiar names to accounts.

*Flags*

: Flags are special indicators for the event. The first character indicates if the post
is signed or not (see **tl-timeline**(1) for known all posibles values of this character). The
second character indicates if the event has any tag and the third one if the event has any
reply.

*Score*

: Show the score of the event. To know more about scores, please read the **SCORES** section
in **timeline**(7).

*Message*

: Need no explanation, just the message. Some words can be highlighted. If you want to know
more, please read **tl-timeline**(1) man page.

# POST AND REPLY MESSAGES

Post and replies are the core of any Timeline communication. To post a new message
just type:

```{console}
tl event post 'your post message'
```

Or an abbreviated form:

```{console}
tl p 'your post message'
```

This will post the message *your post message* in your timeline account.

To reply an event, you need to use the command *reply* in the following form:

```{console}
tl event reply num 'the reply message'
```
Or an abbreviated form:

```{console}
tl r num 'the reply message'
```

This command will reply the event identified by *num* with the reply text *the reply message*.
This *num* is the index id that you can get when doing a **timeline list** command, see
above the section **SEE YOUR TIMELINE** for more information.

Aditionally you can use the flag *\-\-eid* to use instead of the index number the 
event OID of de message to reply. Read **GET POST INFORMATION** below to learn more
about how to inspect the events and get the OID.

# TAG AND SCORE

Timeline add two new features to the social network world. The tagging and the
score.

## Tags

A tag is a label that a user can publicy define over an event. This is not
just a hashtag in the usual way. A tag is defined with other users not by the
owner of the post (well, in fact the owner can also set tags on this owns events).
You can filter your messages to see only certain tags or discard messages with
some tags (see **tl-timeline**(1) to see how to do this in deep).

For example you can view the messages related with vim:

```{console}
tl tl tag:vim
```

Note that because tagging is over the control of the owner, some people can
tag badly the event to gain impressions. This does not work very well on
timeline, because you can tag as *spam* the bad tag, and then ignore the tags
*spam* from your list.

## Scores

The score is a numeric value for an event. You can think to the score like
a *like* in other platforms. But you can give also a negative score. The score
value is always +1 and -1, you cannot give more than one point per account.

Of course you can filter messages using scores:

```{console}
tl tl min-score:10
```

This example will shown only events with more than 10 points. By default negative
messages will be ignored.

# GET POST INFORMATION

You can inspect the event using the command **tl event info**, followed by
the event index in the timeline.

This command will show you more information about the event, including the
event Id. The OID of an event is an unique identifier for this event in the
entire network.


[^1]: Actually a private repository is also allowed if you want. Does make not
 much sense, since only authorized users can clone your repo, but anyway
 there is the option.

 [^2]: For example https://sr.ht, https://gitlab.com, https://codeberg.org, https://github.com, among others.

# SEE ALSO

**tl**(1), **timeline**(7), **tl-timeline**(1), **tl-config**(1)

# TIMELINE

Part of the **tl**(1) suite.

# NAME

tl - the social network built on the top of git


# SYNOPSYS

*tl* [-h] [-a \<account\>] [-C \<file\>] [-V] [command \<args\>]

# DESCRIPTION

Timeline is a social network built on the top of git. The *tl* command allow you to interact with
the network. Calling *tl* without arguments allows you to enter in the interactive mode, while
in standalone mode you can pass the command in the command line argument.

For an introduction guide you can read the page **tl-tutorial**(7). To known
more about the background of Timeline, please read **timeline**(7).


# OPTIONS

\-a \<account\>

: Select an specific account where the interactive sessior or commands will be
executed. This flag makes sense when you have multiple accounts configurated and
you want to operated with other different of the default one.

\-C \<file\>

: Use another config file instead of the default one. See section **FILES** below
to find out where default file is.

\-V

: Print the Timeline suite version that the *tl* program came from.


# COMMANDS

There are the basic commands provide with Timeline. You can invoke them directly,
but using *tl* wrapper is recommended. Note that you can create command aliases with
the *alias* command, but they are only available using the *tl* wrapper.

**tl-account**(1)

: Create, delete and in general manage your Timeline accounts.

**tl-config**(1)

: Manage your *tl* configuration.

**tl-daemon**(1)

: Start/Stop *tl* in the background and refresh periodically your timeline.

**tl-directory**(1)

: Add, remove or search in public directories.

**tl-event**(1)

: Post, reply and in general manage your timeline events.

**tl-follow**(1)

: Manage your followers.

**tl-network**(1)

: Discover and manage your network (AKA friends of friends).

**tl-timeline**(1)

: Show your current timeline, including accounts that you follow. You can also
filter the output.

**tl-view**(1)

: Create and save views. A view is a filter which can be used to
show or hide posts from timeline. You can think a view like a
name for a filter.

**tl-abbr**(1)

: Manage abbreviations. See **tl-event**(1) for more information.

**tl-alias**(1)

: Manage command alias. Just a commodity to type less.

**tl-user**(1)

: Manage user aliases, a way to easy identify remote accounts.


**tl-git**(1)

: Send commands directly to underlying git repository of your account.

**tl-gpg**(1)

: Send commands directly to underlying gpg keyring of your account.

# BASIC CONCEPTS

* Timeline is designed to be distributed, which means that there is no main server which
  store all the accounts like other networks.

* Because of the distributed nature you need to discover new friends using **tl-network**(1)
  or **tl-directory**(1).

* You will only see the events of the people that you follow, nothing else. There is no
  way to print advertising to you (unless an account that you explicitely follow do
  the advertising. In this case you can also use tags and scores to mark that event
  as spam (read **tl-event**(1) and **timeline**(7) for more information).

* Timeline is designed for hackers, so you do not expect something fancy... well
  it has colors (because everyone loves colors) and unicode characters, include
  emojis (because everyone needs emojis to communicate).

* Because you only see the accounts you want to see, only what these accounts says
  about the others (that you also follow) is relevant. This means that don't
  matter than 1 million people tag a post like a spam, you will only considerer
  spam if any of the people that you follow mark this post as spam. You don't care
  about other opinions.

# TERMINOLOGY

\<account\>

: An account for Timeline is a git repository with specific format (see **timeline**(7) for full explanation
of the protocol). Usually the account is a repository with write permissions, but could be also
a read-only account.

\<event\>

: A record in a Timeline account, could be a **reply**, a **tag**, a **post** or a **score**.

\<follow\>

: A follow(ing) is an account that it's followed by you, where you are another
account.

\<post\>

: A record in a Timeline account which contains a message ownered by the account and no related with anything else
in the Timeline network.

\<reply\>

: A response to a previous Timeline event.

\<score\>

: A score (+1 or -1 points) over a previous Timeline event. See **timeline**(7) for a full explanation about scores.

\<tag\>

: A tag over a previous Timeline event. See **timeline**(7) for a full explanation of why tags are implemented
and for what tags could be used.

\<timeline\>

: The result of mixing all messages of the  account plus the messages of the accounts that the first account follows.

\<user\>

: The user is the common name of an account. Account names are hash identifiers which are difficult to
remember. An user is an arbitrary name for an account which makes the account easy to remember and
easy to identify by you.

# CONFIGURATION SETTINGS

Specific configuration settings for each command will be documented in the respective manual of the command.
Here we have the generic options for timeline.

*oid.use-cache*=*true*

: If *true* (by default) calculated hashes are cached to avoid future recalculations.

*oid.max-cache*=*1000*

: If *old.use-cache* is true, then set the maximum number of OIDs stored in cache.

*interactive.show-banner*=*true*

: If *true* (by default) show pretty Timeline ASCII ART logo in interactive mode.

*git.jobs*=*4*

: Set the number of jobs used when git is refreshing modules and cloning the repositories.

*git.defaultBranch*=*main*

: Set the default branch name when creating the repository.

*prompt.format*=*'%b%s:%b '*, *prompt.fields*=*account*, *prompt.color*=*'7,'*, *prompt.color-name*=*'7,'*

: Set the prompt of the interactive mode, for more information about the format
read the **FORMAT** section in the **tl-config**(1) man page.

*history.enabled*=*true*

: If *true* (by default) save the user history.

*history.file*=*$XDG_DATA_HOME/tl/history*

: If *history.enabled* is *true* then save the history in this file.

# FILES

*$XDG_CONFIG_HOME/tl/config*

: The main configuration file for timeline.

*$XDG_CACHE_HOME/tl/\*.cache*

: Differente cache files for *tl*. All files of this kind are safe to remove.

*$XDG_CACHE_HOME/tl/directory.\**

: Cache of directories added to *tl*. See **tl-directory**(1) for more
information.

*$XDG_DATA_HOME/tl/account/*

: Directory where a clone of your account's repositories live. See **tl-account**(1)
for more information.

*$XDG_DATA_HOME/tl/network/*

: Directory where a discovered network of friends is save. See **tl-network**(1)
for more information.

# REPORTING BUGS

We accept contributions, please send patches to mailing list <**timeline-devel@lists.ajdiaz.me**>.
Issues which are security relevant should be disclosed privately to to the security mailing
list <**timeline-security@lists.ajdiaz.me**>

# LICENSE

The Timeline suite and all programs provided by the suite are licensed under the terms
of GNU GPL v3 License. Run *tl license* to get a full copy of the license.

# SEE ALSO

**tl-tutorial**(7), **timeline**(7), **tl-crypto**(7), **git**(1), **gpg**(1)

# TIMELINE

Part of the **tl**(1) suite.

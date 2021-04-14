# NAME

timeline - Internal information about Timeline


# SYNOPSYS

*tl* \*

# DESCRIPTION

This document will explain the internals of the Timeline, including a lot of
important concepts to understand how Timeline works.

Timeline is a distributed social network built on the top of git, which means
that any account of the network is a git repository.

**NOTE**: Before reading this document please be sure that you has been read
and understand the **BASIC CONCEPTS** and  **TERMINOLOGY** defined in **tl**(1) man page.


# INSIDE THE GIT REPO

The git repository of a Timeline account will contain, mandatory a file called
*CONTENT*, and optional a directory *FOLLOW*. Of course you can add any other
files to the repo without problems.

## The CONTENT file

This file contents the events (one event per line) of the account: posts,
replies, etc. And must have the following format

```
timestamp kind body
```

Where

*timestamp*

: Is the UNIX timestamp in seconds when the event was created

*kind*

: The type of the event, could be one of the following: *P* (for posts),
*R* (for replies), *T* (for tags) and *S* (for scores).

*body*

: The content of the message which depend of the *kind*


Empty lines or lines began with *#* sign will be ignored.

The body format depend of the kind of the event, following the next table:

| Kind | Format | Description | Example |
|------|--------|-------------|---------|
| P    | *text* | * *text* is text of the post | `P This is a message` |
| R    | *ref* *text* | * *ref* is the reference to the post to reply. See **REFERENCES** section below for more information. | `R d4473ee7d3ba45a29efed144f43cc20cc2801be9:1618423758 This is a reply` |
|      |          | * *text* is the text of the reply. | |
| T    | *ref* *tag* | * *ref* is the reference to the post to tag. See **REFERENCES** section below for more information. | `T d4473ee7d3ba45a29efed144f43cc20cc2801be9:1618423758 tag` |
|      |         | * *tag* is the tag to set | |
| S    | *ref* *score* | * *ref* is the reference to the post to score See **REFERENCES** section below for more information. | `S d4473ee7d3ba45a29efed144f43cc20cc2801be9:1618423758 1` |
|      |           | * *score* is 1 or -1 indicating the score of the event which refer. | |

Here you have a full example of the CONTENT file:

```
1618138838 R d4473ee7d3ba45a29efed144f43cc20cc2801be9:1618138287 This is a reply of initial message, which is also tagged as initial
1618138707 T d4473ee7d3ba45a29efed144f43cc20cc2801be9:1618138287 initial
1618138287 P Initial message
```

## The FOLLOW directory

This directory contains the repositories of the accounts that you follow. All
directories inside this folders will be git submodules of the main account.

These accounts will follow the same pattern that the main account.

# REFERENCES

The references are a way to identify a event in the network. A reference is a EID
(event identifier) which has the following format:

``\<account\>:\<timestamp\>[:\<hmac\>]``

Where:

*account*

: Is the account OID of the account which store the message to refer.

*timestamp*

: The timestamp of the event to refer, as is found in the CONTENT file of the
*account*.

*hmac*

: (Only from version 1.8) the signature of the message to refer to avoid stamping.
This signature is created applied the object algorith in git (usually SHA1, but
experimental SHA256 is available, read **tl-account**(1)), to prevent the owner
of the post can edit manually the CONTENT and change the message once it get some
engagement. This feature can be enabled or disabled via **tl-config**(1), see **tl-timeline**(1)
to find the proper configuration setting to do that.

# SEE ALSO

**tl-tutorial**(7), **tl**(1), **tl-config**(1), **tl-account**(1), **tl-timeline**(1).

# TIMELINE

Part of the **tl**(1) suite.

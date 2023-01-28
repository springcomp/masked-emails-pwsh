This repository contains a set of PowerShell scripts designed to work with
a custom mail server in order to implement "masked emails".

# Overview

The scripts require [PowerShell Core 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.3)
to be installed. This is a proof-of-concept. Because I'm more familiar and productive with PowerShell than in bash, I chose to rely on PowerShell scripting for this first version.

The scripts are designed to work with a custom mail server base upon the
[fullstack, but simple mailserver](https://docker-mailserver.github.io/docker-mailserver/edge/).
The custom server runs as a Docker container. The scripts in this repository expect
the mailboxes to be available on the host's filesystem. So, please, be sure to update the
[docker-compose.yml](github.com/tomav/docker-mailserrver/blob/master/docker-compose.yml.dist)
file to mount the `/var/mail` folder as a bind mount.

## The following scripts are available:

- `add-masked-email`: adds a MailDir mailbox to docker-mailserver’s `./config/postfix-accounts.cf` file.
- `remove-masked-email`: removes a MailDir mailbox from docker-mailserver’s . `./config/postfix-accounts.cf` file.

Those scripts create or remove a mailbox for use by Postfix and Dovecot.
In order for one of these mailboxes to be considered a 'masked email' address, it is
necessary to run the `set-masked-email` script.

Those scripts use the mail server provided [setup script](https://github.com/docker-mailserver/docker-mailserver/wiki/setup.sh) `setup.sh` to add or remove an email address. This script must be modified to include the `-y` no-prompt confirmation switch to the `delmailuser` command.

- set-masked-email : adds metadata for the Purge Masked Emails and Forward Masked Emails cron jobs.
A masked email is a MailDir mailbox containing a `masked-email.json` file that contains the following data:

```
{
   "forwarding-enabled": true | false,
   "forward-to": <alternate-email-address>
}
```

- `get-masked-emails`: lists masked emails-configured mailboxes.
- `purge-masked-emails`: removes messages from masked email-configured mailboxes, according to the value of the 'AutoExpire' configuration parameter.
- `forward-masked-emails`: forwards messages from masked email-configured mailboxes to their corresponding alternate addresses.
- `forward-masked-email`: forwards messages from a single masked email-configured mailbox to its corresponding alternate addresses.

## Configuration Parameters

The masked email Cron jobs and scripts rely on the `/etc/masked-emails.conf` configuration file.
The following parameters are available:

- `AutoExpire`: specifies the delay after which a message from a masked email-configured mailbox must be deleted.
- `MailLocation`: the Dovecot's 'mail_location' parameter. e.g: `maildir:/path/to/%d/%n:LAYOUT=fs`.
- `MailServerRoot`: the location of the `docker-mailserver` folder containing the `docker-compose.yml` file and the `./config/` directory.

## Cron jobs

The masked email feature intalls the following two cron jobs:

```
# MASKED-EMAILS
# 
# /etc/crond.d/masked-emails-purge: crontab entries
#
# Removes expired messages from the MailDir-formatted
# mailboxes associated with the specified domain.
# A message is considered expired if it has been received
# at a time earlier then the value of the 'AutoExpire'
# configuration parameter.
#
# For instance, if 'AutoExpire' is set to '1d', all messages
# that have been received more than 1 day ago at the time
# of execution of this job will be deleted.
#
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
#
@daily         root purge-masked-emails -domain example.com
*/10 * * * *   root forward-masked-emails -domain example.com
#
```

## How-to Install

```sh
wget https://masked.blob.core.windows.net/debian/masked-emails-pwsh.deb
dpkg -i masked-emails-pwsh.deb
```

**Warning**: please, do not forget to modify the mail server provider setup script as instructed to in the description above.

Optionally, the `forward-masked-email` command supports adding a _forwarded to_ header notice while forwarding and email. Please, install the [make-fowarded-email](https://github.com/springcomp/make-forwarded-email) command if you need this feature.
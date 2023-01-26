#!/usr/bin/pwsh

## Removes a mailbox from Postfix and Dovecot.
##
## remove-masked-email.ps1 \
##       [-Username] <username> \
##       [-DeleteFolder] \
##       [[-Config] <configuration-file>] \
##       [-Force] \
##       [-WhatIf] \
##       [-Verbose]
##
## -Username <mailbox> : email address of the user.
##
## -DeleteFolder : removes the MailDir folder
##     associated with the mailbox on the filesystem.
##
## -Config <config> : specifies an alternate path
##     for the configuration file. The default value
##     is '/etc/masked-emails.conf'.
##
## -Force : restarts the mail server
##
## -WhatIf : does not actually remove a user
##     but prints what the script would do instead.
##
## -Verbose : includes more detailed logs to the console.
##

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 1)]
    [Alias("Address")]
    [Alias("Username")]
    [string]$email,

    [Alias("ConfigurationFile")]
    [Alias("ConfigFile")]
    [string]$config = "/etc/masked-emails.conf",

    [Switch]$force,
    [Switch]$whatIf
)

BEGIN
{
    . /usr/share/masked-emails/scripts/Read-Configuration.ps1
    . /usr/share/masked-emails/scripts/Add-MailLocationRootConfiguration.ps1

    $pos = $email.IndexOf("@")
    if ($pos -eq -1){
        Write-Host "The specified mailbox address is not a valid email address." -Foreground Red
        Exit
    }

    $username = $email.Substring(0, $pos)
    $domain = $email.Substring($pos + 1)
}
PROCESS
{
    $configuration = Read-Configuration -Path $config
    $configuration["Domain"] = $domain

    # Determine the mailbox root path

    $root = $configuration["MailServerRoot"]

    $config = Join-Path -Path $root -ChildPath "config"
    $passdb = Join-Path -Path $config -ChildPath "postfix-accounts.cf"

    $exists = Get-Content -Path $passdb | ? {
        $_.StartsWith($email)
    } | Select-Object -First 1

    if (-not $exists) {
        Write-Host "The mailbox for $($email) does not exist." -ForegroundColor Red
        return
    }

    # Remove email address

    $setup = Join-Path -Path $root -ChildPath "setup.sh"
    $command = "pushd $root; $setup email del $email; popd"

    if ($whatIf.IsPresent){
        Write-Host $command
    } else {
        Invoke-Expression $command
        Write-Verbose $command
    }

    # Remove the MailDir mailbox

    $mailbox = Join-Path -Path $mailLocationRoot -ChildPath $username
    if (Test-Path -Path $mailbox){
        $mailboxCommand = "rm -rf `"$mailbox`""
        if ($whatIf.IsPresent){
            Write-Host $mailboxCommand -ForegroundColor Gray
        } else {
            Write-Verbose $mailboxCommand
            Invoke-Expression $mailboxCommand
        }
    }
}

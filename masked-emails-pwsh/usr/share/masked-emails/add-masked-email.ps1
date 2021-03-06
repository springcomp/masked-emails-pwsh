#!/usr/bin/pwsh

## Adds a new mailbox to Postfix and Dovecot.
##
## add-masked-email.ps1 \
##       [-Username] <email-address> \
##       [-Hash|Password[Hash]] <ssha512-hash> \
##       [[-Config] <configuration-file>] \
##       [-Force] \
##       [-WhatIf] \
##       [-Verbose]
##
## -Username <email-address> : email address of the user.
##
## -Password <hash> : specifies the SSHA512 hash
##     of the user password.
##
## -Config <config> : specifies an alternate path
##     for the configuration file. The default value
##     is '/etc/masked-emails.conf'.
##
## -WhatIf : does not actually add a user
##     but prints what the script would do instead.
##
## -Verbose : includes more detailed logs to the console.
##

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias("Address")]
    [Alias("Username")]
    [string]$email,

    [Parameter(Mandatory = $true, Position = 1)]
    [Alias("Hash")]
    [string]$passwordHash,

    [Alias("ConfigurationFile")]
    [Alias("ConfigFile")]
    [string]$config = "/etc/masked-emails.conf",

    [Switch]$force,
    [Switch]$whatIf
)

BEGIN {
    . /usr/share/masked-emails/scripts/Read-Configuration.ps1
    . /usr/share/masked-emails/scripts/Add-MailLocationRootConfiguration.ps1

    $pos = $email.IndexOf("@")
    if ($pos -eq -1) {
        Write-Host "The specified mailbox address is not a valid email address." -Foreground Red
        Exit
    }

    $username = $email.Substring(0, $pos)
    $domain = $email.Substring($pos + 1)
}
PROCESS {
    $configuration = Read-Configuration -Path $config
    $configuration["Domain"] = $domain

    # Determine the mailbox root path

    $root = $configuration["MailServerRoot"]

    # Add an entry to the postfix-accounts.cf file
    # if it does not already exist

    $config = Join-Path -Path $root -ChildPath "config"
    $passdb = Join-Path -Path $config -ChildPath "postfix-accounts.cf"

    $exists = Get-Content -Path $passdb | ? {
        $_.StartsWith($email)
    } | Select-Object -First 1


    if ($null -ne $exists) {
        Write-Host "The mailbox for $($email) already exists." -ForegroundColor Red
        return
    }

    $setup = Join-Path -Path $root -ChildPath "setup.sh"
    $command = "pushd $root; $setup email add $email $passwordHash; popd"
	
    if ($whatIf.IsPresent) {
        Write-Host $command -ForegroundColor Gray
    }
    else {
        Write-Verbose $command
        Invoke-Expression $command
	[Threading.Thread]::Sleep(2000)
    }
}

#!/usr/bin/env -S pwsh -NoProfile

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
    # And the user-specific relative path containing messages

    Add-MailLocationRootConfiguration -Config $configuration

    $mailLocationRoot = $configuration["MailLocationRoot"]
    $relativeUserPath = $configuration["RelativeUserPath"]

    # Update the entry to the postfix-accounts.cf file

    $config = Join-Path -Path ($configuration["MailServerRoot"]) -ChildPath "config"
    $passdb = Join-Path -Path $config -ChildPath "postfix-accounts.cf"

    $exists = Get-Content -Path $passdb | ? {
        $_.StartsWith($email)
    } | Select-Object -First 1

    if (-not $exists) {
        Write-Host "The mailbox for $($email) does not exist." -ForegroundColor Red
        return
    }

    $pwd = "$($email)|{SSHA512}$($passwordHash)"
    $pwdMessage = "$passdb -> `"$pwd`"";

    $passdbTemp = "/tmp/postfix-accounts.cf"

    Get-Content -Path $passdb |? {
        if ($_.StartsWith($email)){
            if ($whatIf.IsPresent){
                Write-Host $pwdMessage -Foreground Gray
            } else {
                Add-Content -Path $passdbTemp -Value $pwd
                Write-Verbose $pwdMessage
            }
            return $false
        } else {
            return $true
        }
    } |% {
        if (-not $whatIf.IsPresent){
            Add-Content -Path $passdbTemp -Value $_
        }
    }

    if (-not $whatIf.IsPresent){
        Move-Item -Path $passdbTemp -Destination $passdb -Force
    }

    if ($force.IsPresent) {

    # Restart mail server

        $root = $configuration["MailServerRoot"]
        $compose = Join-Path -Path $root -ChildPath "docker-compose.yml"
        $up = "pushd $root; /usr/local/bin/docker-compose --file $compose up --detach; popd"
        $down = "pushd $root; /usr/local/bin/docker-compose --file $compose down; popd"
    
        if ($whatIf.IsPresent) {
            Write-Host $down
            Write-Host $up
        }
        else {
            Write-Verbose $down
            Invoke-Expression $down
            Write-Verbose $up
            Invoke-Expression $up
        }
    }
}


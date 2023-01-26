#!/usr/bin/env -S pwsh -NoProfile

## Forwards messages from a masked-email
## mailbox to the specified alternate address.
##
## forward-masked-email.ps1 \
##	[-Username] <email-address> \
##	[[-Config] <configuration-file>] \
##	[-WhatIf] \
##	[-Verbose]
##
## -Username <email-address> : name of the user/mailbox.
##
## -Config <config> : specifies an alternate path
##     for the configuration file. The default value
##     is '/etc/masked-emails.conf'.
##
##     The CmdLet needs the following parameters:
##      - MailLocation : (see -Domain above)
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

    [Alias("ConfigurationFile")]
    [Alias("ConfigFile")]
    [string]$config = "/etc/masked-emails.conf",

    [Switch]$whatIf
)

BEGIN
{
    . /usr/share/masked-emails/scripts/Read-Configuration.ps1
    . /usr/share/masked-emails/scripts/Add-MailLocationRootConfiguration.ps1
    . /usr/share/masked-emails/scripts/Get-MaskedEmailSettingName.ps1
    . /usr/share/masked-emails/scripts/Is-MailDirMessage.ps1

    Function Forward-Message{
        param(
            [string]$path,
            [string]$forwardTo
        )

        ## format the message

        ## send the message

        $forwardCommand = "cat `"$($path)`" | msmtp $($forwardTo)"
        if ($whatIf.IsPresent){
            Write-Host $forwardCommand
        } else {
            Write-Verbose $forwardCommand
            Invoke-Expression $forwardCommand
        }

        ## remove the corresponding file

        Remove-Item -Path $path
    }

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
    # And the user-specific relative path containing messages

    Add-MailLocationRootConfiguration -Config $configuration

    $mailLocationRoot = $configuration["MailLocationRoot"]
    $relativeUserPath = $configuration["RelativeUserPath"]

    $mailboxRoot = Join-Path -Path $mailLocationRoot -ChildPath $username
    if (-not (Test-Path -Path $mailboxRoot)){
        Write-Host "The mailbox for $($username) at location $($mailboxRoot) does not exist" -ForegroundColor Red
        return
    }

    $maskedEmail = Join-Path -Path $mailboxRoot -ChildPath (Get-MaskedEmailSettingName)
    if (-not (Test-Path -Path $maskedEmail)){
        Write-host "The mailbox for $($username) has not been configured for masked email forwarding." -ForegroundColor Red
        Write-host "Please, run the following command:" -ForegroundColor Yellow
        Write-host "> set-masked-email $email -ForwardTo alternate@example.com" -ForegroundColor Yellow
        return
    }

    $setting = Get-Content -Path $maskedEmail | ConvertFrom-JSON

    if (-not $setting."forwarding-enabled"){
        Write-Verbose "Forwarding is disabled for mailbox $email"
        return
    }

    $forwardTo = $setting."forward-to"
    
    $relativePath = $relativeUserPath.Replace("%n", $username)
    $relativeRoot = Join-Path -Path $mailLocationRoot -ChildPath $relativePath

    "cur", "new" |% {
        $inbox = Join-Path -Path $relativeRoot -ChildPath $_
        Get-ChildItem -Path $inbox -EA SilentlyContinue |? { Is-MailDirMessage -Name $_.Name } |% {
            Forward-Message -Path $_.FullName -ForwardTo $forwardTo
        }
    }
}

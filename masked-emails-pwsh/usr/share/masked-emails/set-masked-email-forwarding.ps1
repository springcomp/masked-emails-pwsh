#!/usr/bin/env -S pwsh -NoProfile

## Enables or disables forwarding
## messages from a mailbox to a specified
## alternate email address
##
## set-masked-email-forwarding.ps1 \
##	[-Username] <email-address> \
##	[-ForwardTo] <email-address> \
##	[-Enable] \
##	[-Disable] \
##	[[-Config] <configuration-file>] \
##	[-WhatIf] \
##	[-Verbose]
##
## -Username <email-address> : name of the user/mailbox.
##
## -ForwardTo <email-address> : email address of the user.
##
## -Disable : disable forwarding to the alternate address.
##      When disabled, received messages stay in
##      the user mailbox for the duration of the
##      'AutoExpire' configuration parameter.
##
##	The forwarding daemon considers the list of
##	user mailboxes for which to attempt forwarding
##	messages to an alternate email address.
##
##	For a disabled address, the forwarding daemon
##	will not perform forwarding of the messages.
##
##      A disabled address can be enabled by running
##      the command again (without the  -Disable flag).
##
## -Config <config> : specifies an alternate path
##     for the configuration file. The default value
##     is '/etc/masked-emails.conf'.
##
##     The CmdLet needs the following parameters:
##      - MailLocationRoot
##
## -WhatIf : does not actually enable / disable forwarding
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

    [Parameter(Position = 1)]
    [Alias("AlternateAddress")]
    [string]$forwardTo = $null,

    [Switch]$enable = $false,
    [Switch]$disable = $false,

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

    if ($disable.IsPresent -and $enable.IsPresent){
        Write-Host "Only one of -Enable, -Disable or -ForwardTo flag must be present." -Foreground Red
        return
    }
    if ($forwardTo -ne $null -and $forwardTo.Length -gt 0){
        if (-not $disable.IsPresent){
            $enable = $true
        }
    }

    $pos = $email.IndexOf("@")
    if ($pos -eq -1){
        Write-Host "The specified mailbox address is not a valid email address." -Foreground Red
        return
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
        New-Item -ItemType Directory -Path $mailboxRoot | Out-Null
        $owner = $configuration["UserID"]
        Invoke-Expression "chown -R $owner `"$mailboxRoot`""
        Invoke-Expression "chmod 700 `"$mailboxRoot`""
    }

    $maskedEmail = Join-Path -Path $mailboxRoot -ChildPath (Get-MaskedEmailSettingName)
    if (Test-Path -Path $maskedEmail){
        $setting = Get-Content -Path $maskedEmail | ConvertFrom-JSON
        $setting."forwarding-enabled" = (-not $disable.IsPresent)
        if ($forwardTo -ne $null -and $forwardTo.Length -gt 0){
            $setting."forward-to" = $forwardTo
        }
    } else {
        $setting = New-Object -Type PSObject
        $setting | Add-Member -MemberType NoteProperty -Name "mailbox" -Value $email
        $setting | Add-Member -MemberType NoteProperty -Name "forwarding-enabled" -Value (-not $disable.IsPresent)
        $setting | Add-Member -MemberType NoteProperty -Name "forward-to" -Value $forwardTo
    }

    $json = (ConvertTo-JSON -InputObject $setting)
    $message = "$maskedEmail --> $json"
    if ($whatIf.IsPresent){
        Write-Host $message -ForegroundColor Gray
    } else {
        Write-Verbose $message
        Set-Content -Path $maskedEmail -Value $json
    }

    # Send a confirmation email

    if ($enable) {

        $message = "<html><body><p>Your address '$email' is now active.</p></body></html>"
        $body = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($message))

        . /usr/share/masked-emails/send-email.ps1 `
            -address $email `
            -subject "$email is active!" `
            -message $body	
    }

}

# vi: set tabstop=4

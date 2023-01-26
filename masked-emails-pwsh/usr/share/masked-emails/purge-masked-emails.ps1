#!/usr/bin/env -S pwsh -NoProfile

## Removes all expired messages from a set of maildir-formatted
## mailboxes associated with the specified domain.
##
## purge-masked-emails.ps1 \
##       [-Domain] <domain> \
##       [[-Config] <configuration-file>] \
##       [-WhatIf] \
##       [-Verbose]
##
## -Domain <domain> : specifies the domain to purge
##
##     This CmdLet iterates over all message from
##     the mailboxes at the location specified in
##     Dovecot's mail_location configuration parameter
##     and attempts to extract the reception time
##     from the name of the message file.
##
##     According to the MailDir specification, the first
##     part of the filename is the result of the time(3)
##     Unix function.
##    
## -Config <config> : specifies an alternate path
##     for the configuration file. The default value
##     is '/etc/masked-emails.conf'.
##
##     The CmdLet needs the following parameters:
##      - AutoExpire : the duration after which
##        messages are deleted. Valid values for
##        this parameter are "never" or values
##        that can be passed on to the sleep(1) command.
##        E.g: "1d", "2h", "3.50m", "3600s", etc.
##
## -WhatIf : does not actually remove any messages
##     but prints what the script would do instead.
##
## -Verbose : includes more detailed logs to the console.
##

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$domain,

    [Parameter(Position = 1)]
    [Alias("ConfigurationFile")]
    [Alias("ConfigFile")]
    [string]$config = "/etc/masked-emails.conf",

    [Switch]$whatIf
)

BEGIN
{
    . /usr/share/masked-emails/scripts/Read-Configuration.ps1
    . /usr/share/masked-emails/scripts/Add-MailLocationRootConfiguration.ps1
    . /usr/share/masked-emails/scripts/Get-MaskedEmail.ps1
    . /usr/share/masked-emails/scripts/Is-MailDirMessage.ps1
    . /usr/share/masked-emails/scripts/Get-MailDirMessageTimestamp.ps1

    Function ConvertFrom-SleepDuration{
        [CmdletBinding()]
        param([string]$duration)
        if ($duration -eq "never"){
            Write-Output [TimeSpan]::MaxValue	
        } else {
            [regex] $pattern = "^(?<number>[1-9][0-9]*(?:\.[0-9]*)?)(?<unit>s|m|h|d)?$"
            $match = $pattern.Match($duration)
            if ($match.Success){
                $unit = "s"
                if ($match.Groups["unit"].Value.Length -gt 0){
                    $unit = $match.Groups["unit"].Value
                }

                # it is safe to use [Double]::Parse
                # because the format of the number
                # is already validated by the regex

                $number = $match.Groups["number"].Value
                $float = [Double]::Parse($number)

                $timeSpan = [TimeSpan]::Zero

                if ($unit -eq "s") { $timeSpan = $timeSpan.Add([TimeSpan]::FromSeconds($float)) }
                if ($unit -eq "m") { $timeSpan = $timeSpan.Add([TimeSpan]::FromMinutes($float)) }
                if ($unit -eq "h") { $timeSpan = $timeSpan.Add([TimeSpan]::FromHours($float)) }
                if ($unit -eq "d") { $timeSpan = $timeSpan.Add([TimeSpan]::FromDays($float)) }

                Write-Output $timeSpan
                
            } else {
                throw "Syntax error: invalid value for configuration parameter 'AutoExpire'."
            }
        }
    }

    Function Format-TimeSpan{
        [CmdletBinding()]
        param([TimeSpan] $timeSpan)

        if ($timeSpan -gt [TimeSpan]::FromDays(1.0)){
            $days = $timeSpan.ToString("dd")
            Write-Output "$($days) days ago"
            return
        }
        if ($timeSpan -gt [TimeSpan]::FromHours(1.0)){
            $hours = $timeSpan.ToString("hh")
            Write-Output "$($hours) hours ago"
            return
        }
        if ($timeSpan -gt [TimeSpan]::FromMinutes(1.0)){
            $minutes = $timeSpan.ToString("mm")
            Write-Output "$($minutes) minutes ago"
            return
        }
        if ($timeSpan -gt [TimeSpan]::FromSeconds(1.0)){
            $seconds = $timeSpan.ToString("ss")
            Write-Output "$($seconds) seconds ago"
            return
        }
    }

    $MASKED_EMAIL_JSON = "masked-email.json"
}

PROCESS
{
    Write-Host "Removing expired messages from domain ($domain)..." -ForegroundColor Cyan

    $configuration = Read-Configuration -Path $config
    $configuration["Domain"] = $domain

    # Initialize the AutoExpire TimeSpan

    $autoExpireDelay = $configuration["AutoExpire"]
    $autoExpireDuration = ConvertFrom-SleepDuration -Duration $autoExpireDelay
    $utcNow = [DateTime]::UtcNow

    # Determine the mailbox root path
    # And the user-specific relative path containing messages

    Add-MailLocationRootConfiguration -Config $configuration

    $mailLocationRoot = $configuration["MailLocationRoot"]
    $relativeUserPath = $configuration["RelativeUserPath"]

    Write-Verbose "Looking up messages in $($mailLocationRoot) folder."

    # Iterate over all user mailboxes and messages
    # https://cr.yp.to/proto/maildir.html

    $ae = $configuration["AutoExpire"]

    Get-MaskedEmail -Root $mailLocationRoot |% {
        $mailboxRoot = $_.Fullname
        Get-ChildItem -Path $mailboxRoot -Recurse |? {
            Is-MailDirMessage -Name $_.Name } |% {
    
            $path = $_.FullName
            $name = $_.Name
    
            $receivedUtc = Get-MailDirMessageTimestamp -Name $name
            $sinceThen = $utcNow - $receivedUtc
    
            $receivedUtcText = $receivedUtc.ToString("yyyy-MM-ddTHH:mm:ss.fff")
            $sinceThenText = Format-TimeSpan -TimeSpan $sinceThen
    
            $relativePath = $path.Replace($mailLocationRoot, "`$(DOMAIN)")
    
            if ($sinceThen -ge $autoExpireDuration){
                $reason = "Removing message '$($relativePath)', received more than $($sinceThenText) on $($receivedUtcText), which is more than the 'AutoExpired' duration ($ae)."
                if ($whatIf.IsPresent){
                    Write-Host $reason -ForegroundColor Gray
                } else {
                    Remove-Item -Path $path -Force
                    Write-Verbose $reason
                }
            }
            else{
                $aeText = Format-TimeSpan -TimeSpan $autoExpireDuration
                Write-Verbose "Keeping message '$($relativePath)' because it was received on $($receivedUtcText), less than $aeText as specified by the 'AutoExpire' duration."
            }
        }
    }

    Add-Content -Path "/tmp/purge-masked-emails.log" -Value "$(Get-Date): purge-masked-emails.ps1 was run."
    Write-Host "Removing expired messages from domain ($domain)... Done." -ForegroundColor Cyan
}

# vi: set tabstop=4

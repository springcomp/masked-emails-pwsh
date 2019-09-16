#!/usr/bin/pwsh

## Lists all masked-emails configured mailboxes from a
## set of maildir-formatted mailboxes associated with
## the specified domain.
##
## get-masked-emails.ps1 \
##	[-Domain] <domain> \
##	[-Detailed] \
##	[[-Config] <configuration-file>] 
##
## -Domain <domain> : specifies the domain to purge
##
##     This CmdLet iterates over all root mailboxes
##     specified in Dovecot's mail_location config
##     parameter for the existence of a file named
##     'masked-email.json'.
##    
## -Detailed : displays masked-email settings

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

[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$domain,

	[Switch]$detailed = $false,
	[Switch]$nologo = $false,

	[Alias("ConfigurationFile")]
	[Alias("ConfigFile")]
	[string]$config = "/etc/masked-emails.conf"
)

BEGIN
{
	. /usr/share/masked-emails/scripts/Read-Configuration.ps1
	. /usr/share/masked-emails/scripts/Add-MailLocationRootConfiguration.ps1
	. /usr/share/masked-emails/scripts/Get-MaskedEmail.ps1
	. /usr/share/masked-emails/scripts/Get-MaskedEmailSettingName.ps1
}

PROCESS
{
	if (-not $nologo.IsPresent){
		Write-Host "Retrieving masked-email addresses for domain ($domain)..." -ForegroundColor Cyan
	}

	$configuration = Read-Configuration -Path $config
	$configuration["Domain"] = $domain

	# Determine the mailbox root path
	# And the user-specific relative path containing messages

	Add-MailLocationRootConfiguration -Config $configuration

	$mailLocationRoot = $configuration["MailLocationRoot"]
	$relativeUserPath = $configuration["RelativeUserPath"]

	Write-Verbose "Looking up mailboxes in $($mailLocationRoot) folder."

	# Iterate over all user mailboxes
	# https://cr.yp.to/proto/maildir.html

	Get-MaskedEmail -Root $mailLocationRoot |% {
		$mailbox = $_.Name
		$address = "$($mailbox)@$($domain)"

		Write-Output $address
		if ($detailed.IsPresent){
			$mailboxRoot = Join-Path -Path $mailLocationRoot -ChildPath $mailbox
			$setting = Join-Path -Path $mailboxRoot -ChildPath (Get-MaskedEmailSettingName)
			Get-Content -Path $setting -Raw
		}
	}

	if (-not $nologo.IsPresent){
		Write-Host "Retrieving masked-email addresses for domain ($domain)... Done." -ForegroundColor Cyan
	}
}

# vi: set tabstop=4


#!/usr/bin/pwsh

## Forwards messages from a set of masked-email
## mailboxes to their corresponding alternate addresses.
##
## forward-masked-emails.ps1 \
##	[-Domain] <domain> \
##	[[-Config] <configuration-file>] \
##	[-WhatIf] \
##	[-Verbose]
##
## -Domain <domain> : domain name of the mailboxes
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

	# hard-coding script location because $PSScriptRoot currently does not work
	# github.com/PowerShell/PowerShell/issues/4217

	Function Get-ScriptDirectory { "/usr/local/bin" }
	$forwardMaskedEmail = Join-Path -Path (Get-ScriptDirectory) -ChildPath "forward-masked-email"
}
PROCESS
{
	$configuration = Read-Configuration -Path $config
	$configuration["Domain"] = $domain

	Add-MailLocationRootConfiguration -Config $configuration

	$mailLocationRoot = $configuration["MailLocationRoot"]
	$relativeUserPath = $configuration["RelativeUserPath"]

	Get-MaskedEmail -Root $mailLocationRoot |% {
		$username = $_.Name
		$address = "$($username)@$($domain)"

		Write-Verbose "forward-masked-email -Address $address"

		. $forwardMaskedEmail `
				-Address $address `
				-WhatIf:$whatIf `
				-Verbose:$verbose
	}
	Add-Content -Path "/tmp/purge-masked-emails.log" -Value "$(Get-Date): forward-masked-emails.ps1 was run."
}


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
	# And the user-specific relative path containing messages

	Add-MailLocationRootConfiguration -Config $configuration

	$mailLocationRoot = $configuration["MailLocationRoot"]
	$relativeUserPath = $configuration["RelativeUserPath"]

	# Remove entry from passwd file

	$config = Join-Path -Path ($configuration["MailServerRoot"]) -ChildPath "config"
	$passdb = Join-Path -Path $config -ChildPath "postfix-accounts.cf"

	$passdbTemp = "/tmp/postfix-accounts.cf"

	Get-Content -Path $passdb |? {
		$passdbMessage = "$passdb X--> `"$_`""
		if ($_.StartsWith($email)){
			if ($whatIf.IsPresent){
				Write-Host $passdbMessage
			} else {
				Write-Verbose $passdbMessage
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

	if ($force.IsPresent){

		# Restart mail server

		$compose = Join-Path -Path ($configuration["MailServerRoot"]) -ChildPath "docker-compose.yml"
		$up = "/usr/local/bin/docker-compose --file $compose up --detach"
		$down = "/usr/local/bin/docker-compose --file $compose down"

		if ($whatIf.IsPresent){
			Write-Host $down
			Write-Host $up
		} else {
			Write-Verbose $down
			Invoke-Expression $down
			Write-Verbose $up
			Invoke-Expression $up
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
}

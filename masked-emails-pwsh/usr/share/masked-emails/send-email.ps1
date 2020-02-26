#!/usr/bin/pwsh

## Sends an HTML message to the specified recipient.
## Typically used for sending an email as part of the
## 'reset password' workflow, this script uses msmtp
## to send an HTML email body to the specified recipient.
##
## send-email.ps1 \
##	[-To] <email-address> \
##	[-Body] <html-body-path> \
##	[-WhatIf] \
##	[-Verbose]
##
## -To <email-address> : recipient 
## -Subject <subject> : single-line email subject
## -Body <html-body> : path to an HTML-formatted email body
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
	[Alias("To")]
	[string]$recipient,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$subject,

    [Parameter(Mandatory = $true, Position = 2, ValueFromPipeline = $true, ParameterSetName = 'MessagePath')]
    [Alias("PSPath")]
    [string]$bodyPath = $null,

    [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Base64String')]
    [Alias("HTML")]
    [Alias("Body")] 
    [string]$message = $null,

	[Switch]$whatIf
)

BEGIN
{
	Function Send-Message{
		param(
			[string]$path,
			[string]$forwardTo,
            [switch]$whatIf
		)

		## format the message

		## send the message

		$sendCommand = "cat `"$($path)`" | msmtp $($forwardTo)"
		if ($whatIf.IsPresent){
			Write-Host $sendCommand
		} else {
			Write-Verbose $sendCommand
			Invoke-Expression $sendCommand
		}
	}

    ## Save the HTML to a temporary file

    if (-not $bodyPath) {

        $bodyPath = [IO.Path]::GetTempFileName()
        $shouldDelete = $true

        Write-Verbose "Expanding base64 message into a temporary file $bodyPath."

        Set-Content -Path $bodyPath -Encoding UTF8 -Value (
            [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($message))
        )

    } else {

        if (-not (Test-Path $bodyPath)){
	    	Write-Host "The specified email message path does not exist." -Foreground Red
	    	Exit
        }

    }

    ## Create a temporary file to format an email message

    $messagePath = [IO.Path]::GetTempFileName()
    $rfc822date = (Get-Date -Format "ddd, dd MM yyyy HH:mm:ss K")
}

PROCESS
{
    Set-Content -Path $messagePath -Value @"
From: Masked Emails <no-reply@maskedbox.space>
To: $recipient
Subject: $subject
Date: $rfc822date
Content-Type: text/html; charset="utf-8"

"@

    Add-Content -Path $messagePath -Value (
        Get-Content -Path $bodyPath -Raw -Encoding UTF8
    )

    $email = Get-Content -Path $messagePath -Encoding UTF8 -Raw
    Write-Verbose $email

    Send-Message -Path $messagePath -ForwardTo $recipient -Whatif:$WhatIf
}

END
{
    if (Test-Path $messagePath) {
        Remove-Item -Path $messagePath -EA SilentlyContinue | Out-Null
    }
    if ($shouldDelete) {
        Remove-Item -Path $bodyPath -EA SilentlyContinue | Out-Null
    }
}

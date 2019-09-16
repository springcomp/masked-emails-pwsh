Function Get-MailDirMessageTimestamp
{
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias("PSPath")]
		[string]$name
	)

	BEGIN
	{
		Function Get-HostName{
			$hostName = [Net.Dns]::GetHostName()
			Write-Output $hostName
		}

		Function ConvertFrom-UnixTimestamp{
			[CmdletBinding()]
			param([Int64]$timestamp)
			$epoch = New-Object -Type System.DateTime -ArgumentList @(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
			Write-Output $epoch.AddSeconds($timestamp)
		}

		$hostName = Get-HostName
		$messagePattern = "(?<time>[1-9][0-9]{9})\..+\.$($hostName),S=.*"
		$messageRegex = [regex] $messagePattern

	}
	PROCESS
	{
		$timeMatch = $messageRegex.Match($name)
		if ($timeMatch.Success) {
			$time = $timeMatch.Groups["time"].Value

			$receivedUtc = ConvertFrom-UnixTimestamp -Timestamp $time
			Write-Output $receivedUtc
		}
	}
}

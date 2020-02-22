Function Is-MailDirMessage
{
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias("PSPath")]
		[string]$name
	)

	BEGIN
	{
		# https://cr.yp.to/proto/maildir.html

		$messagePattern = "(?<time>[1-9][0-9]{9})\..+\.(?<hostName>[^,]+),S=.*"
	}
	PROCESS
	{
		$raw = Split-Path -Path $name -Leaf
		$raw -Match $messagePattern
	}
}

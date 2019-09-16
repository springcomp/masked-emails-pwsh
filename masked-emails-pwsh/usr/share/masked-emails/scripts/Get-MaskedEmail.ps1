Function Get-MaskedEmail
{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias("Path")]
		[Alias("Root")]
		[string]$mailLocationRoot
	)

	BEGIN
	{
		. /usr/share/masked-emails/scripts/Get-MaskedEmailSettingName.ps1
	}
	PROCESS
	{
		Get-ChildItem -Path $mailLocationRoot |? {
			$folder = $_.Fullname
			$json = Join-Path -Path $folder -ChildPath (Get-MaskedEmailSettingName)
		    	Test-Path $json	
		}
	}
}

# vi: set tabstop=4


Function Add-MailLocationRootConfiguration {
	[CmdletBinding()]
	param(
		[hashtable]$configuration
	)
	
	BEGIN
	{
		$domain = $configuration["Domain"]
		$mailLocation = $configuration["MailLocation"]
	}
	
	PROCESS
	{
		$prefix = @()	
		$suffix = @()

		$prefixed = $true

		# Check supported MailLocation value
	
		$pattern = "^maildir:(?<path>.*):LAYOUT=fs$"
		$regex = [regex] $pattern
		$match = $regex.Match($mailLocation)
		if (-not $match.Success){
			throw "Unsupported 'MailLocation' parameter."
		}

		$path = $match.Groups["path"].Value
		$path.Split("/") |% {
			$fragment = $_
			if ($fragment -match "%d"){
				$fragment = $fragment.Replace("%d", $domain)
			}
			if ($fragment -match "%n"){
				$prefixed = $false
			}
			if ($prefixed){
				$prefix += $fragment
			} else {
				$suffix += $fragment
			}
		}

		$configuration["MailLocationRoot"] = [String]::Join("/", $prefix)
		$configuration["RelativeUserPath"] = [String]::Join("/", $suffix)
	}
}

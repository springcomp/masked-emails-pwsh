Function Read-Configuration {
       [CmdletBinding()]
       param([string] $path)

       $config = @{}

       Get-Content -Path $path |? {
       	-not ($_.Length -eq 0 -or $_.StartsWith("#"))
       } |% {
       	$line = $_
       	$index = $line.IndexOfAny("`t ")
       	if ($index -ne -1) {
       		$parameter = $line.Substring(0, $index).Trim()	
       		$value = $line.Substring($index + 1).Trim()
       		$config[$parameter] = $value
       	}
       }

       Write-Output $config
}

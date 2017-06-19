# inspired from https://raw.githubusercontent.com/spoonypirate/BoxstarterPackages/master/lyx-boxstarter/tools/ChocolateyInstall.ps1

<# usage

cinst --yes boxstarter
. "$env:appdata\Boxstarter\BoxstarterShell.ps1"
New-PackageFromScript update.ps1 MyUpdate
Install-BoxstarterPackage -Force MyUpdate

#>

# set-psdebug -Strict -Trace 1

try {

	# Boxstarter options
	$Boxstarter.RebootOk=$true # Allow reboots?
	$Boxstarter.NoPassword=$false # Is this a machine with no login password?
	$Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot

	$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

	# Basic setup
	Update-ExecutionPolicy RemoteSigned
	Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives `
	  -EnableShowFileExtensions -EnableShowFullPathInTitleBar
	#Enable-RemoteDesktop
	Disable-InternetExplorerESC
	Set-TaskbarOptions -Size Small -Lock -Dock Bottom -Combine Never

	if (Test-PendingReboot) {
		Invoke-Reboot
	}

	Install-WindowsUpdate -AcceptEula
	if (Test-PendingReboot) {
		Invoke-Reboot
	}

} catch {
	$logstring = $_.Exception.Message
	Write-Host "DEBUG $logstring"
	$Logfile = "c:\$(gc env:computername).log"
	Add-content $Logfile -value Get-Date
	Add-content $Logfile -value $logstring
	# shutdown -r has been disabled by boxstarter
 	Invoke-Reboot
}


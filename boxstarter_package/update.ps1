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

	cinst --yes --ignore-checksums vim

	# Basic setup
	Update-ExecutionPolicy RemoteSigned
	Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives `
	  -EnableShowProtectedOSFiles -EnableShowFileExtensions `
	  -EnableShowFullPathInTitleBar
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
	Write-Host "DEBUG $($_.Exception.Message)"
	$Logfile = "c:\$(gc env:computername).log"
	$logstring = $($_.Exception.Message)
	Add-content $Logfile -value Get-Date
	Add-content $Logfile -value $logstring
	# shutdown -r has been disabled by boxstarter
 	Invoke-Reboot
}


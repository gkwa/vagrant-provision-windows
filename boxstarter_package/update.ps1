# inspired from https://raw.githubusercontent.com/spoonypirate/BoxstarterPackages/master/lyx-boxstarter/tools/ChocolateyInstall.ps1

<# usage

cinst --yes boxstarter
. "$env:appdata\Boxstarter\BoxstarterShell.ps1"
Install-BoxstarterPackage https://raw.githubusercontent.com/TaylorMonacelli/windows-update/master/update.ps1

#>

# set-psdebug -Strict -Trace 1

try {

	cinst install --yes --allow-empty-checksums vim

	# Boxstarter options
	$Boxstarter.RebootOk=$true # Allow reboots?
	$Boxstarter.NoPassword=$false # Is this a machine with no login password?
	$Boxstarter.AutoLogin=$true # Save my password securely and auto-login after a reboot

	$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

	# Basic setup
	Update-ExecutionPolicy RemoteSigned
	Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowProtectedOSFiles -EnableShowFileExtensions -EnableShowFullPathInTitleBar
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

	Write-Host "taylordebug $($_.Exception.Message)"
	if ($($_.Exception.Message) -like '*E_OUTOFMEMORY*') {
		# shutdown -r has been disabled by boxstarter
 		Invoke-Reboot
	}
#	throw $_.Exception
#	Write-ChocolateyFailure 'https://github.com/taylormonacelli/windows-update/update.ps1 failed' $($_.Exception.Message)
#	throw
}

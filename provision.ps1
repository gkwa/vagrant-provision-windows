<# 

# usage example:

$env:HEADLESS='true'
$vmname='eval-win10x64-enterprise'
packer_build $vmname
vagrant destroy --force; . $root/provision.ps1; vup $vmname

#>

if (!(Get-Variable vmname -Scope Global -ErrorAction SilentlyContinue)){
	Write-Host '$vmname not defined, set it and run again (eg $vmname="eval-win7x64-enterprise")'
}

if (!(Get-Variable root -Scope Global -ErrorAction SilentlyContinue)) {
	Write-host '$root not defined, set it and run again (eg $root="$pwd")'
	Exit 1
}

# http://stackoverflow.com/a/24745822/1495086
# scope matters
if(test-path Alias:\wget){
	Remove-Item -Path Alias:\wget
}

function redoAll()
{
	$vmlist=@(
		'eval-win10x64-enterprise',
		'eval-win10x86-enterprise',
		'eval-win2008r2-datacenter',
		'eval-win2008r2-standard',
		'eval-win2012r2-datacenter',
		'eval-win2012r2-standard',
		'eval-win7x64-enterprise',
		'eval-win7x86-enterprise',
		'eval-win81x64-enterprise',
		'eval-win81x86-enterprise',
		'eval-win8x64-enterprise'
	);

	. $root/provision.ps1
	foreach ($vmname in $vmlist) {
		vagrant box remove --force $vmname
		vup $vmname
		vagrant destroy --force
	}
}

function deletevms(){
	bash -c "vboxmanage list vms | sed -n 's,.*{\(.*\)},vboxmanage controlvm \1 poweroff; vboxmanage unregistervm \1 --delete,p' | sh -x -";
}

function vagrant_box_add( $vmname )
{
	vagrant box add --force --provider virtualbox $vmname `
	  $root/boxcutter-windows/box/virtualbox/${vmname}*.box
}

function cleanup( $vmname ){
	deletevms
	deletevms
	deletevms
	if(test-path D:/vbox/$vmname){
		remove-item -force -recurse D:/vbox/$vmname
	}
	if(test-path $root/boxcutter-windows/output-virtualbox-iso){
		remove-item -force -recurse $root/boxcutter-windows/output-virtualbox-iso
	}
	if(test-path $root/boxcutter-windows/out.log){
		remove-item -force $root/boxcutter-windows/out.log
	}
}

function packer_build( $vmname )
{
	$d=$pwd
	cd $root/boxcutter-windows
	make virtualbox/$vmname 2>&1 | tee out.log
	vagrant_box_add $vmname
	cd "$d"
}

function packer_rebuild( $vmname )
{
	$d=$pwd
	cd $root/boxcutter-windows
	make --always-make virtualbox/$vmname 2>&1 | tee out.log
	vagrant_box_add $vmname
	cd "$d"
}

function box_exists_already( $vmname )
{
	$boxlist=vagrant box list --no-color | 
	  Select-String '^([^(]*)' -AllMatches | 
	  Foreach-Object { $_.Matches } | 
	  Foreach-Object { $_.Groups[1].Value } | 
	  Foreach-Object { $_.Trim() }

	$boxlist -contains $vmname
}

function vmdestroy( $vmname )
{
	vagrant destroy --force
	handle $vmname

	$boxlist=vagrant box list --no-color | 
	  Select-String '^([^(]*)' -AllMatches | 
	  Foreach-Object {$_.Matches} | 
	  Foreach-Object {$_.Groups[1].Value} | 
	  Foreach-Object {$_.Trim()}
}

function setup_boxstarter_package( $vmname, $vmdir )
{
	mkdir -force $vmdir/boxstarter_package | Out-Null
	Copy-Item $root/boxstarter_package/update.ps1 $vmdir/boxstarter_package/update.ps1
}

function create_boxstarter_update_file( $vmname, $vmdir )
{
@'
Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
Install-ChocolateyPinnedTaskBarItem -TargetFilePath C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe

$env:Path += ";$env:ALLUSERSPROFILE\chocolatey\bin"

cinst --yes boxstarter
. "$env:appdata\Boxstarter\BoxstarterShell.ps1"

# 	-KeepWindowOpen:$false
# 	-NoNewWindow:$false
New-PackageFromScript c:\vagrant\boxstarter_package\update.ps1 MyUpdate
Install-BoxstarterPackage -Force MyUpdate
'@ | Out-File -encoding 'ASCII' $vmdir/update2.ps1
}


function create_vagrantfile( $vmname, $vmdir )
{
	@"
`$script9 = <<'SCRIPT9'
cd c:/vagrant

if (test-path Alias:\wget) {
	Remove-Item -Force -Path Alias:\wget
}

wget --quiet --timestamping --no-check-certificate https://ssl-tools.net/certificates/02faf3e291435468607857694df5e45b68851868.pem
wget --quiet --timestamping --no-check-certificate https://chocolatey.org/install.ps1
wget --quiet --timestamping --no-check-certificate https://certs.godaddy.com/repository/gdicsg2.cer
wget --quiet --timestamping --no-check-certificate https://certs.godaddy.com/repository/gdroot-g2.crt

certutil -addstore -f TrustedPublisher c:/vagrant/gdroot-g2.crt
certutil -addstore -f TrustedPublisher c:/vagrant/02faf3e291435468607857694df5e45b68851868.pem
certutil -addstore -f Root c:/vagrant/gdroot-g2.crt
certutil -addstore -f Root c:/vagrant/02faf3e291435468607857694df5e45b68851868.pem

Set-Item -Path env:chocolateyProxyLocation -value ""

. ./install.ps1
SCRIPT9

Vagrant.configure("2") do |config|
  config.vm.box = "$vmname"
  config.vm.communicator = "winrm"

config.vm.provision "bootstrap", type: "shell" do |s|
 s.inline = `$script9
end

config.vm.provision "reboot", type: "shell" do |s1| 
 s1.inline = "shutdown -t 0 -r"
end

config.vm.provision "boxstarter", type: "shell" do |s2| 
 s2.path = "update2.ps1"
end

config.vm.provider "virtualbox" do |v|
  v.memory = 4024
v.cpus = 2
v.customize ["setextradata", "global", "GUI/SuppressMessages", "all" ]
v.customize ["modifyvm", :id, "--vcpenabled", "on"]
end
end
"@ | Out-File -encoding 'ASCII' $vmdir/Vagrantfile
}

function listHandles($vmname, $handle_out)
{
	$regex='^(.*)\s+pid: (\d+)\s+type: ([^ ]+)\s+([A-Fa-f0-9]+): (.*)'

	foreach( $line in $handle_out ) {
		$line | Select-String $regex -AllMatches |
		  Foreach-Object { $_.Matches } |
		  Foreach-Object {
			  $pname=$_.Groups[1].Value.Trim()
			  $_pid=$_.Groups[2].Value.Trim()
			  $fpath=$_.Groups[5].Value.Trim()
			  "{0} {1} {2} {3}" -f $_pid, [System.IO.Path]::GetExtension($fpath), $pname, $fpath
			  "taskkill /F /pid $_pid"
		  }
	}
}

function vup($vmname)
{
	cd $root
	$handle_out = handle $vmname
	listHandles $vmname $handle_out
	cleanup $vmname

	# instantiate new test instance
	cd $root
	$vmdir = "$root/$vmname"
	remove-item -ea 0 -recurse $vmdir
	mkdir -force $vmdir | out-null

	cd $root
	if(test-path $vmdir/Vagrantfile){
		vagrant destroy --force
	}

	create_vagrantfile $vmname $vmdir
	create_boxstarter_update_file $vmname $vmdir
	setup_boxstarter_package $vmname $vmdir
	cd $vmdir

	# download wget.exe to host will make c:\vagrant\wget.exe available inside guest vm
	wget -qN http://installer-bin.streambox.com/wget.exe
	if(!(box_exists_already $vmname)){
		packer_build $vmname
	}
	vagrant up --no-destroy-on-error --no-provision
	$tries=1;
	do {
		# try again, it seems to work the second time, dunno why
		# I exepect vagrant >1.9.1 will fix this
		# https://github.com/mitchellh/vagrant/issues/7717
		vagrant provision --provision-with bootstrap
	} while($lastExitCode -ne 0 -and $tries++ -le 3)
	#	vagrant rdp
	email -bs "${vmname}: packer is done" taylor
}

if (!(Get-Variable vmname -Scope Global -ErrorAction SilentlyContinue)){
	Write-Host '$vmname not defined, set it and run again (eg $vmname="eval-win7x64-enterprise")'
	Exit 1
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
	stop-process -ea SilentlyContinue -processname VBoxSVC
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

function cleanup2(){
	vagrant destroy --force
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

function vagrant_up_with_without_autoproxy($vmname)
{
	cd $root
	cleanup $vmname

	# instantiate new test instance
	cd $root
	$vmdir = "$root/$vmname"
	remove-item -ea 0 -recurse $vmdir
	mkdir -force $vmdir | out-null

	cd $root
	make -C win_settings installer=disable_auto_proxy.exe
	copy-item $root/disable_auto_proxy.xml $vmdir
	copy-item $root/schedule_task.bat $vmdir
	copy-item $root/disable_auto_proxy.vbs $vmdir
	copy-item $root/disable_auto_proxy.ps1 $vmdir
	copy-item $root/win_settings/disable_auto_proxy.exe $vmdir
	if(test-path $vmdir/Vagrantfile){
		vagrant destroy --force
	}

	@"
`$script = <<-'SCRIPT'
cd c:\\vagrant
./disable_auto_proxy.exe /S
SCRIPT

`$script2 = <<SCRIPT2
cd c:\\vagrant
wscript ./disable_auto_proxy.vbs
SCRIPT2

`$script3 = <<'SCRIPT3'
echo 1 | Out-File -encoding 'ASCII' 'C:\Windows\Temp\out.txt'
SCRIPT3

`$script4 = <<'SCRIPT4'
echo 1 | Out-File -encoding 'ASCII' 'C:\Windows\Temp\out.txt'
SCRIPT4

`$script5 = <<'SCRIPT5'
wscript c:\\vagrant\\disable_auto_proxy.vbs
SCRIPT5

`$script6 = <<'SCRIPT6'
wscript c:\\vagrant\\disable_auto_proxy.vbs
SCRIPT6

`$script7 = <<'SCRIPT7'
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
SCRIPT7

`$script8 = <<'SCRIPT8'

# http://www.mcgearytech.com/change-internet-options-connection-settings-with-vb-script-or-power-shell/

Set-ItemProperty -Path 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings' ProxyEnable -value 0
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'
$data = (Get-ItemProperty -Path $key -Name DefaultConnectionSettings).DefaultConnectionSettings
$data[8] = 1
Set-ItemProperty -Path $key -Name DefaultConnectionSettings -Value $data
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections'
$data = (Get-ItemProperty -Path $key -Name SavedLegacySettings).SavedLegacySettings
$data[8] = 1
Set-ItemProperty -Path $key -Name SavedLegacySettings -Value $data
SCRIPT8


`$script9 = <<'SCRIPT9'
cd c:/vagrant
Remove-item alias:wget
wget -N --no-check-certificate https://ssl-tools.net/certificates/02faf3e291435468607857694df5e45b68851868.pem
wget -N --no-check-certificate https://certs.godaddy.com/repository/gdicsg2.cer
wget -N --no-check-certificate https://chocolatey.org/install.ps1
wget -N --no-check-certificate https://certs.godaddy.com/repository/gdroot-g2.crt
certutil -addstore -f "TrustedPublisher" c:/vagrant/gdroot-g2.crt
certutil -addstore -f "TrustedPublisher" c:/vagrant/02faf3e291435468607857694df5e45b68851868.pem
certutil -addstore -f "Root" c:/vagrant/gdroot-g2.crt
certutil -addstore -f "Root" c:/vagrant/02faf3e291435468607857694df5e45b68851868.pem

$env:chocolateyProxyLocation="http://localhost"
$env:chocolateyProxyLocation="localhost:8888"
$env:chocolateyProxyLocation="10.0.2.1"
$env:chocolateyProxyLocation="http://localhost:8888"
$env:chocolateyProxyLocation=""
. ./install.ps1
SCRIPT9

Vagrant.configure("2") do |config|
  config.vm.box = "$vmname"

# config.vm.provision :shell, :path => "disable_auto_proxy.ps1"
# config.vm.provision "not running" OR "not being run" powershell
# config.vm.provision "shell", inline: `$script3
# config.vm.provision "shell", inline: `$script4
# config.vm.provision "shell", inline: `$script5
# config.vm.provision "shell", inline: `$script6
# config.vm.provision :shell, :path => "schedule_task.bat"
# config.vm.provision "shell", inline: `$script7
# config.vm.provision "shell", inline: `$script8
config.vm.provision "shell", inline: `$script9

config.vm.provider "virtualbox" do |v|
  v.memory = 4024
v.cpus = 2
end
end
"@ | Out-File -encoding 'ASCII' $vmdir/Vagrantfile

	cd $vmdir

	# download wget.exe to host will make c:\vagrant\wget.exe available inside guest vm
	wget -qN http://installer-bin.streambox.com/wget.exe
	if(!(box_exists_already $vmname)){
		packer_build $vmname
	}
	vagrant up
	vagrant rdp
	email -bs "${vmname}: packer is done" taylor
}

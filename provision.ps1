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

Vagrant.configure("2") do |config|
  config.vm.box = "$vmname"
config.vm.provision "shell", path: "disable_auto_proxy.ps1", powershell_elevated_interactive: true, privileged: true

config.vm.provider "virtualbox" do |v|
  v.memory = 4024
v.cpus = 2
end
end
"@ | Out-File -encoding 'ASCII' $vmdir/Vagrantfile

	cd $vmdir

	# download wget.exe to host will make c:\vagrant\wget.exe available inside guest vm
	wget -qN http://installer-bin.streambox.com/wget.exe
	vagrant up
	vagrant rdp
	email -bs "${vmname}: packer is done" taylor
}

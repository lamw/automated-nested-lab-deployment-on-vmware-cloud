# Author: William Lam
# Website: www.virtuallyghetto.com

# Cloud Provider
# AWS, Google, Microsoft, Oracle
$SddcProvider = "AWS"

# vCenter Server used to deploy vSphere with Kubernetes Lab
$VIServer = "vcenter.sddc-a-b-c-d.vmwarevmc.com"
$VIUsername = "cloudadmin@vmc.local"
$VIPassword = "FILL-ME-IN"

# Full Path to both the Nested ESXi VA and Extracted VCSA ISO
$NestedESXiApplianceOVA = "C:\Users\Administrator\Desktop\Nested\Nested_ESXi7.0_Appliance_Template_v1.ova"
$VCSAInstallerPath = "C:\Users\Administrator\Desktop\Nested\VMware-VCSA-all-7.0.0-16620007"
$PhotonNFSOVA = "C:\Users\Administrator\Desktop\Nested\PhotonOS_NFS_Appliance_0.1.0.ova"
$PhotonOSOVA = "C:\Users\Administrator\Desktop\Nested\photon-hw13_uefi-3.0-26156e2.ova"

# Nested ESXi VMs to deploy
$NestedESXiHostnameToIPs = @{
"esxi-1" = "192.168.1.11"
"esxi-2" = "192.168.1.12"
"esxi-3" = "192.168.1.13"
}

# Nested ESXi VM Resources
$NestedESXivCPU = "4"
$NestedESXivMEM = "24" #GB
$NestedESXiCachingvDisk = "8" #GB # Applicable to Google & Oracle SDDC deployment only
$NestedESXiCapacityvDisk = "100" #GB Applicable to Google & Oracle SDDC deployment only

# Applicable to AWS and Microsoft SDDC deployment
$NFSVMDisplayName = "nfs"
$NFSVMHostname = "nfs.vmware.corp"
$NFSVMIPAddress = "192.168.1.20"
$NFSVMPrefix = "24"
$NFSVMVolumeLabel = "nfs"
$NFSVMCapacity = "100" #GB
$NFSVMRootPassword = "VMware1!"

# VCSA Deployment Configuration
$VCSADeploymentSize = "tiny"
$VCSADisplayName = "vcsa"
$VCSAIPAddress = "192.168.1.10"
$VCSAHostname = "vcsa.vmware.corp" #Change to IP if you don't have valid DNS
$VCSAPrefix = "24"
$VCSASSODomainName = "vsphere.local"
$VCSASSOPassword = "VMware1!"
$VCSARootPassword = "VMware1!"
$VCSASSHEnable = "true"

# General Deployment Configuration for Nested ESXi, VCSA & NSX VMs
$VMDatacenter = "SDDC-Datacenter"
$VMCluster = "Cluster-1"
$VMResourcePool = "Compute-ResourcePool"
$VMNetwork = "sddc-cgw-network-1"
$VMDatastore = "WorkloadDatastore"

$VMNetmask = "255.255.255.0"
$VMGateway = "192.168.1.1"
$VMDNS = "192.168.1.100"
$VMNTP = "pool.ntp.org"
$VMPassword = "VMware1!"
$VMDomain = "vmware.corp"
$VMSyslog = "192.168.1.10"
$VMFolder = "Workloads"
# Applicable to Nested ESXi only
$VMSSH = "true"
$VMVMFS = "false"

# Name of new vSphere Datacenter/Cluster when VCSA is deployed
$NewVCDatacenterName = "Nested-SDDC-Datacenter"
$NewVCVSANClusterName = "Nested-SDDC-Cluster"
$NewVCVDSName = "Nested-SDDC-VDS"
$NewVCMgmtDVPGName = "Nested-Management"
$NewVCWorkloadDVPGName = "Nested-Workload"
$NewVCWorkloadVMFormat = "Workload-" # workload-01,02,03,etc
$NewVcWorkloadVMCount = 2

# Advanced Configurations
# Set to 1 only if you have DNS (forward/reverse) for ESXi hostnames
$addHostByDnsName = 1

#### DO NOT EDIT BEYOND HERE ####

$debug = $true
$verboseLogFile = "nested-sddc-lab-deployment.log"
$random_string = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})
$VAppName = "Nested-SDDC-Lab-$random_string"

$preCheck = 1
$confirmDeployment = 1
$deployNFSVM = 1
$deployNestedESXiVMs = 1
$deployVCSA = 1
$setupNewVC = 1
$addESXiHostsToVC = 1
$configureESXiStorage = 1
$configureVDS = 1
$clearHealthCheckAlarm = 1
$moveVMsIntovApp = 1
$deployWorkload = 0

$vcsaSize2MemoryStorageMap = @{
"tiny"=@{"cpu"="2";"mem"="12";"disk"="415"};
"small"=@{"cpu"="4";"mem"="19";"disk"="480"};
"medium"=@{"cpu"="8";"mem"="28";"disk"="700"};
"large"=@{"cpu"="16";"mem"="37";"disk"="1065"};
"xlarge"=@{"cpu"="24";"mem"="56";"disk"="1805"}
}

$sddcProviderService = @{
    "AWS"="VMware Cloud on AWS (VMC)";
    "Microsoft"="Azure VMware Solution (AVS)";
    "Google"="Google Cloud VMware Engine (GCVE)";
    "Oracle"="Oracle Cloud VMware Solution (OCVS)";
}

$supportedStorageType = @{
    "AWS"="NFS";
    "Microsoft"="NFS";
    "Google"="VSAN";
    "Oracle"="VSAN";
}

$esxiTotalCPU = 0
$vcsaTotalCPU = 0
$esxiTotalMemory = 0
$vcsaTotalMemory = 0
$esxiTotalStorage = 0

$StartTime = Get-Date

Function My-Logger {
    param(
    [Parameter(Mandatory=$true)]
    [String]$message
    )

    $timeStamp = Get-Date -Format "MM-dd-yyyy_hh:mm:ss"

    Write-Host -NoNewline -ForegroundColor White "[$timestamp]"
    Write-Host -ForegroundColor Green " $message"
    $logMessage = "[$timeStamp] $message"
    $logMessage | Out-File -Append -LiteralPath $verboseLogFile
}

if($preCheck -eq 1) {
    if($SddcProvider -ne "AWS" -and $SddcProvider -ne "Microsoft" -and $SddcProvider -ne "Google" -and $SddcProvider -ne "Oracle") {
        Write-Host -ForegroundColor Red "`n`$SddcProvider variable is incorrectly set. Supported providers are `"AWS`", `"Microsoft`", `"Google`" and `"Oracle`" ...`n"
        exit
    }

    if(!(Test-Path $NestedESXiApplianceOVA)) {
        Write-Host -ForegroundColor Red "`nUnable to find $NestedESXiApplianceOVA ...`n"
        exit
    }

    if(!(Test-Path $VCSAInstallerPath)) {
        Write-Host -ForegroundColor Red "`nUnable to find $VCSAInstallerPath ...`n"
        exit
    }

    if($supportedStorageType.$SddcProvider -eq "NFS") {
        if(!(Test-Path $PhotonNFSOVA)) {
            Write-Host -ForegroundColor Red "`nUnable to find $PhotonNFSOVA ...`n"
            exit
        }
    }

    if($deployWorkload -eq 1) {
        if(!(Test-Path $PhotonOSOVA)) {
            Write-Host -ForegroundColor Red "`nUnable to find $PhotonOSOVA ...`n"
            exit
        }
    }

    if($PSVersionTable.PSEdition -ne "Core") {
        Write-Host -ForegroundColor Red "`tPowerShell Core was not detected, please install that before continuing ... `n"
        exit
    }
}

if($confirmDeployment -eq 1) {
    Write-Host -ForegroundColor Magenta "`nPlease confirm the following configuration will be deployed:`n"

    Write-Host -ForegroundColor Yellow "---- Nested SDDC Automated Lab Deployment Configuration ---- "
    Write-Host -NoNewline -ForegroundColor Green "SDDC Provider: "
    Write-Host -ForegroundColor White $SddcProvider
    Write-Host -NoNewline -ForegroundColor Green "VMware Cloud Service: "
    Write-Host -ForegroundColor White $sddcProviderService.$SddcProvider

    Write-Host -NoNewline -ForegroundColor Green "`nNested ESXi Image Path: "
    Write-Host -ForegroundColor White $NestedESXiApplianceOVA
    Write-Host -NoNewline -ForegroundColor Green "VCSA Image Path: "
    Write-Host -ForegroundColor White $VCSAInstallerPath

    if($supportedStorageType.$SddcProvider -eq "NFS") {
        Write-Host -NoNewline -ForegroundColor Green "NFS Image Path: "
        Write-Host -ForegroundColor White $PhotonNFSOVA
    }

    if($deployWorkload -eq 1) {
        Write-Host -NoNewline -ForegroundColor Green "PhotonOS Image Path: "
        Write-Host -ForegroundColor White $PhotonOVA
    }

    Write-Host -ForegroundColor Yellow "`n---- vCenter Server Deployment Target Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "vCenter Server Address: "
    Write-Host -ForegroundColor White $VIServer
    Write-Host -NoNewline -ForegroundColor Green "VM Network: "
    Write-Host -ForegroundColor White $VMNetwork

    Write-Host -NoNewline -ForegroundColor Green "VM Cluster: "
    Write-Host -ForegroundColor White $VMCluster
    Write-Host -NoNewline -ForegroundColor Green "VM Resource Pool: "
    Write-Host -ForegroundColor White $VMResourcePool
    Write-Host -NoNewline -ForegroundColor Green "VM Storage: "
    Write-Host -ForegroundColor White $VMDatastore
    Write-Host -NoNewline -ForegroundColor Green "VM vApp: "
    Write-Host -ForegroundColor White $VAppName

    Write-Host -ForegroundColor Yellow "`n---- vESXi Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "# of Nested ESXi VMs: "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.count
    Write-Host -NoNewline -ForegroundColor Green "vCPU: "
    Write-Host -ForegroundColor White $NestedESXivCPU
    Write-Host -NoNewline -ForegroundColor Green "vMEM: "
    Write-Host -ForegroundColor White "$NestedESXivMEM GB"

    if($supportedStorageType.$SddcProvider -eq "NFS") {
        Write-Host -NoNewline -ForegroundColor Green "NFS Storage: "
        Write-Host -ForegroundColor White "$NFSVMCapacity GB"
    } else {
        Write-Host -NoNewline -ForegroundColor Green "vSAN Caching VMDK: "
        Write-Host -ForegroundColor White "$NestedESXiCachingvDisk GB"
        Write-Host -NoNewline -ForegroundColor Green "vSAN Capacity VMDK: "
        Write-Host -ForegroundColor White "$NestedESXiCapacityvDisk GB"
    }

    Write-Host -NoNewline -ForegroundColor Green "IP Address(s): "
    Write-Host -ForegroundColor White $NestedESXiHostnameToIPs.Values
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway
    Write-Host -NoNewline -ForegroundColor Green "DNS: "
    Write-Host -ForegroundColor White $VMDNS
    Write-Host -NoNewline -ForegroundColor Green "NTP: "
    Write-Host -ForegroundColor White $VMNTP
    Write-Host -NoNewline -ForegroundColor Green "Syslog: "
    Write-Host -ForegroundColor White $VMSyslog
    Write-Host -NoNewline -ForegroundColor Green "Enable SSH: "
    Write-Host -ForegroundColor White $VMSSH

    Write-Host -ForegroundColor Yellow "`n---- VCSA Configuration ----"
    Write-Host -NoNewline -ForegroundColor Green "Deployment Size: "
    Write-Host -ForegroundColor White $VCSADeploymentSize
    Write-Host -NoNewline -ForegroundColor Green "SSO Domain: "
    Write-Host -ForegroundColor White $VCSASSODomainName
    Write-Host -NoNewline -ForegroundColor Green "Enable SSH: "
    Write-Host -ForegroundColor White $VCSASSHEnable
    Write-Host -NoNewline -ForegroundColor Green "Hostname: "
    Write-Host -ForegroundColor White $VCSAHostname
    Write-Host -NoNewline -ForegroundColor Green "IP Address: "
    Write-Host -ForegroundColor White $VCSAIPAddress
    Write-Host -NoNewline -ForegroundColor Green "Netmask "
    Write-Host -ForegroundColor White $VMNetmask
    Write-Host -NoNewline -ForegroundColor Green "Gateway: "
    Write-Host -ForegroundColor White $VMGateway

    $esxiTotalCPU = $NestedESXiHostnameToIPs.count * [int]$NestedESXivCPU
    $esxiTotalMemory = $NestedESXiHostnameToIPs.count * [int]$NestedESXivMEM
    if($SddcProvider -eq "AWS" -or $SddcProvider -eq "Microsoft") {
        $esxiTotalStorage = [int]$NFSCapacity
    } else {
        $esxiTotalStorage = ($NestedESXiHostnameToIPs.count * [int]$NestedESXiCachingvDisk) + ($NestedESXiHostnameToIPs.count * [int]$NestedESXiCapacityvDisk)
    }
    $vcsaTotalCPU = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.cpu
    $vcsaTotalMemory = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.mem
    $vcsaTotalStorage = $vcsaSize2MemoryStorageMap.$VCSADeploymentSize.disk

    Write-Host -ForegroundColor Yellow "`n---- Resource Requirements ----"
    Write-Host -NoNewline -ForegroundColor Green "ESXi     VM CPU: "
    Write-Host -NoNewline -ForegroundColor White $esxiTotalCPU
    Write-Host -NoNewline -ForegroundColor Green " ESXi     VM Memory: "
    Write-Host -NoNewline -ForegroundColor White $esxiTotalMemory "GB "
    Write-Host -NoNewline -ForegroundColor Green "ESXi     VM Storage: "
    Write-Host -ForegroundColor White $esxiTotalStorage "GB"
    Write-Host -NoNewline -ForegroundColor Green "VCSA     VM CPU: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalCPU
    Write-Host -NoNewline -ForegroundColor Green " VCSA     VM Memory: "
    Write-Host -NoNewline -ForegroundColor White $vcsaTotalMemory "GB "
    Write-Host -NoNewline -ForegroundColor Green "VCSA     VM Storage: "
    Write-Host -ForegroundColor White $vcsaTotalStorage "GB"

    if($supportedStorageType.$SddcProvider -eq "NFS") {
        Write-Host -NoNewline -ForegroundColor Green "NFS      VM CPU: "
        Write-Host -NoNewline -ForegroundColor White "2"
        Write-Host -NoNewline -ForegroundColor Green " NFS      VM Memory: "
        Write-Host -NoNewline -ForegroundColor White "4 GB "
        Write-Host -NoNewline -ForegroundColor Green "NFS      VM Storage: "
        Write-Host -ForegroundColor White $NFSVMCapacity "GB"

        $nfsCPU = 2
        $nfsMemory = 4
        $nfsStorage = $NFSCapacity
    } else {
        $nfsCPU = 0
        $nfsMemory = 0
        $nfsStorage = 0
    }

    Write-Host -ForegroundColor White "---------------------------------------------"
    Write-Host -NoNewline -ForegroundColor Green "Total CPU: "
    Write-Host -ForegroundColor White ($esxiTotalCPU + $vcsaTotalCPU + $nsxManagerTotalCPU + $nsxEdgeTotalCPU + $nfsCPU)
    Write-Host -NoNewline -ForegroundColor Green "Total Memory: "
    Write-Host -ForegroundColor White ($esxiTotalMemory + $vcsaTotalMemory + $nsxManagerTotalMemory + $nsxEdgeTotalMemory + $nfsMemory) "GB"
    Write-Host -NoNewline -ForegroundColor Green "Total Storage: "
    Write-Host -ForegroundColor White ($esxiTotalStorage + $vcsaTotalStorage + $nsxManagerTotalStorage + $nsxEdgeTotalStorage + $nfsStorage) "GB"

    Write-Host -ForegroundColor Magenta "`nWould you like to proceed with this deployment?`n"
    $answer = Read-Host -Prompt "Do you accept (Y or N)"
    if($answer -ne "Y" -or $answer -ne "y") {
        exit
    }
    Clear-Host
}

if( $deployNFSVM -eq 1 -or $deployNestedESXiVMs -eq 1 -or $deployVCSA -eq 1) {
    My-Logger "Connecting to Management vCenter Server $VIServer ..."
    $viConnection = Connect-VIServer $VIServer -User $VIUsername -Password $VIPassword -WarningAction SilentlyContinue

    $datastore = Get-Datastore -Server $viConnection -Name $VMDatastore | Select -First 1
    $resourcepool = Get-ResourcePool -Server $viConnection -Name $VMResourcePool
    $cluster = Get-Cluster -Server $viConnection -Name $VMCluster
    $datacenter = $cluster | Get-Datacenter
    $vmhost = $cluster | Get-VMHost | Select -First 1
}

if($deployNestedESXiVMs -eq 1) {
    $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
        $VMName = $_.Key
        $VMIPAddress = $_.Value

        $ovfconfig = Get-OvfConfiguration $NestedESXiApplianceOVA
        $ovfNetworkLabel = ($ovfconfig.NetworkMapping | Get-Member -MemberType Properties).Name
        $ovfconfig.NetworkMapping.$ovfNetworkLabel.value = $VMNetwork

        $ovfconfig.common.guestinfo.hostname.value = $VMName
        $ovfconfig.common.guestinfo.ipaddress.value = $VMIPAddress
        $ovfconfig.common.guestinfo.netmask.value = $VMNetmask
        $ovfconfig.common.guestinfo.gateway.value = $VMGateway
        $ovfconfig.common.guestinfo.dns.value = $VMDNS
        $ovfconfig.common.guestinfo.domain.value = $VMDomain
        $ovfconfig.common.guestinfo.ntp.value = $VMNTP
        $ovfconfig.common.guestinfo.syslog.value = $VMSyslog
        $ovfconfig.common.guestinfo.password.value = $VMPassword
        if($VMSSH -eq "true") {
            $VMSSHVar = $true
        } else {
            $VMSSHVar = $false
        }
        $ovfconfig.common.guestinfo.ssh.value = $VMSSHVar

        My-Logger "Deploying Nested ESXi VM $VMName ..."
        $vm = Import-VApp -Source $NestedESXiApplianceOVA -OvfConfiguration $ovfconfig -Name $VMName -Location $resourcepool -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Force

        My-Logger "Adding vmnic2/vmnic3 to $VMNetwork ..."
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        New-NetworkAdapter -VM $vm -Type Vmxnet3 -NetworkName $VMNetwork -StartConnected -confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        My-Logger "Updating vCPU Count to $NestedESXivCPU & vMEM to $NestedESXivMEM GB ..."
        Set-VM -Server $viConnection -VM $vm -NumCpu $NestedESXivCPU -MemoryGB $NestedESXivMEM -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        if($supportedStorageType.$SddcProvider -eq "VSAN") {
            My-Logger "Updating vSAN Cache VMDK size to $NestedESXiCachingvDisk GB & Capacity VMDK size to $NestedESXiCapacityvDisk GB ..."
            Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 2" | Set-HardDisk -CapacityGB $NestedESXiCachingvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
            Get-HardDisk -Server $viConnection -VM $vm -Name "Hard disk 3" | Set-HardDisk -CapacityGB $NestedESXiCapacityvDisk -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }

        My-Logger "Powering On $vmname ..."
        $vm | Start-Vm -RunAsync | Out-Null
    }
}

if($deployNFSVM -eq 1 -and $supportedStorageType.$SddcProvider -eq "NFS") {
    $ovfconfig = Get-OvfConfiguration $PhotonNFSOVA
    $ovfNetworkLabel = ($ovfconfig.NetworkMapping | Get-Member -MemberType Properties).Name
    $ovfconfig.NetworkMapping.$ovfNetworkLabel.value = $VMNetwork

    $ovfconfig.common.guestinfo.hostname.value = $NFSVMHostname
    $ovfconfig.common.guestinfo.ipaddress.value = $NFSVMIPAddress
    $ovfconfig.common.guestinfo.netmask.value = $NFSVMPrefix
    $ovfconfig.common.guestinfo.gateway.value = $VMGateway
    $ovfconfig.common.guestinfo.dns.value = $VMDNS
    $ovfconfig.common.guestinfo.domain.value = $VMDomain
    $ovfconfig.common.guestinfo.root_password.value = $NFSVMRootPassword
    $ovfconfig.common.guestinfo.nfs_volume_name.value = $NFSVMVolumeLabel
    $ovfconfig.Common.disk2size.value = $NFSVMCapacity

    My-Logger "Deploying PhotonOS NFS VM $NFSVMDisplayName ..."
    $vm = Import-VApp -Source $PhotonNFSOVA -OvfConfiguration $ovfconfig -Name $NFSVMDisplayName -Location $resourcepool -VMHost $vmhost -Datastore $datastore -DiskStorageFormat thin -Force

    My-Logger "Powering On $NFSVMDisplayName ..."
    $vm | Start-Vm -RunAsync | Out-Null
}

if($deployVCSA -eq 1) {
        if($IsWindows) {
            $config = (Get-Content -Raw "$($VCSAInstallerPath)\vcsa-cli-installer\templates\install\embedded_vCSA_on_VC.json") | convertfrom-json
        } else {
            $config = (Get-Content -Raw "$($VCSAInstallerPath)/vcsa-cli-installer/templates/install/embedded_vCSA_on_VC.json") | convertfrom-json
        }

        $config.'new_vcsa'.vc.hostname = $VIServer
        $config.'new_vcsa'.vc.username = $VIUsername
        $config.'new_vcsa'.vc.password = $VIPassword
        $config.'new_vcsa'.vc.deployment_network = $VMNetwork
        $config.'new_vcsa'.vc.datastore = $datastore
        $config.'new_vcsa'.vc.datacenter = $datacenter.name
        $config.'new_vcsa'.appliance.thin_disk_mode = $true
        $config.'new_vcsa'.appliance.deployment_option = $VCSADeploymentSize
        $config.'new_vcsa'.appliance.name = $VCSADisplayName
        $config.'new_vcsa'.network.ip_family = "ipv4"
        $config.'new_vcsa'.network.mode = "static"
        $config.'new_vcsa'.network.ip = $VCSAIPAddress
        $config.'new_vcsa'.network.dns_servers[0] = $VMDNS
        $config.'new_vcsa'.network.prefix = $VCSAPrefix
        $config.'new_vcsa'.network.gateway = $VMGateway
        $config.'new_vcsa'.os.ntp_servers = $VMNTP
        $config.'new_vcsa'.network.system_name = $VCSAHostname
        $config.'new_vcsa'.os.password = $VCSARootPassword
        if($VCSASSHEnable -eq "true") {
            $VCSASSHEnableVar = $true
        } else {
            $VCSASSHEnableVar = $false
        }
        $config.'new_vcsa'.os.ssh_enable = $VCSASSHEnableVar
        $config.'new_vcsa'.sso.password = $VCSASSOPassword
        $config.'new_vcsa'.sso.domain_name = $VCSASSODomainName

        # Hack due to JSON depth issue
        $config.'new_vcsa'.vc.psobject.Properties.Remove("target")
        $config.'new_vcsa'.vc | Add-Member NoteProperty -Name target -Value "REPLACE-ME"

        if($IsWindows) {
            My-Logger "Creating VCSA JSON Configuration file for deployment ..."
            $config | ConvertTo-Json | Set-Content -Path "$($ENV:Temp)\jsontemplate.json"
            $target = "[`"$VMCluster`",`"Resources`",`"$VMResourcePool`"]"
            (Get-Content -path "$($ENV:Temp)\jsontemplate.json" -Raw) -replace '"REPLACE-ME"',$target | Set-Content -path "$($ENV:Temp)\jsontemplate.json"

            My-Logger "Deploying the VCSA ..."
            Invoke-Expression "$($VCSAInstallerPath)\vcsa-cli-installer\win32\vcsa-deploy.exe install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:Temp)\jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
        } elseif($IsMacOS) {
            My-Logger "Creating VCSA JSON Configuration file for deployment ..."
            $config | ConvertTo-Json | Set-Content -Path "$($ENV:TMPDIR)jsontemplate.json"

            My-Logger "Deploying the VCSA ..."
            Invoke-Expression "$($VCSAInstallerPath)/vcsa-cli-installer/mac/vcsa-deploy install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip $($ENV:TMPDIR)jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
        } elseif ($IsLinux) {
            My-Logger "Creating VCSA JSON Configuration file for deployment ..."
            $config | ConvertTo-Json | Set-Content -Path "/tmp/jsontemplate.json"

            My-Logger "Deploying the VCSA ..."
            Invoke-Expression "$($VCSAInstallerPath)/vcsa-cli-installer/lin64/vcsa-deploy install --no-ssl-certificate-verification --accept-eula --acknowledge-ceip /tmp/jsontemplate.json"| Out-File -Append -LiteralPath $verboseLogFile
        }
}

if($moveVMsIntovApp -eq 1) {
    My-Logger "Creating vApp $VAppName ..."
    $VApp = New-VApp -Name $VAppName -Server $viConnection -Location $resourcepool

    if(-Not (Get-Folder $VMFolder -ErrorAction Ignore)) {
        My-Logger "Creating VM Folder $VMFolder ..."
        $folder = New-Folder -Name $VMFolder -Server $viConnection -Location (Get-Datacenter $VMDatacenter | Get-Folder vm)
    }

    if($deployNFSVM -eq 1 -and $supportedStorageType.$SddcProvider -eq "NFS") {
        $vcsaVM = Get-VM -Name $NFSVMDisplayName -Server $viConnection
        My-Logger "Moving $NFSVMDisplayName into $VAppName vApp ..."
        Move-VM -VM $vcsaVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }

    if($deployNestedESXiVMs -eq 1) {
        My-Logger "Moving Nested ESXi VMs into $VAppName vApp ..."
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $vm = Get-VM -Name $_.Key -Server $viConnection
            Move-VM -VM $vm -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployVCSA -eq 1) {
        $vcsaVM = Get-VM -Name $VCSADisplayName -Server $viConnection
        My-Logger "Moving $VCSADisplayName into $VAppName vApp ..."
        Move-VM -VM $vcsaVM -Server $viConnection -Destination $VApp -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
    }

    My-Logger "Moving $VAppName to VM Folder $VMFolder ..."
    Move-VApp -Server $viConnection $VAppName -Destination (Get-Folder -Server $viConnection $VMFolder) | Out-File -Append -LiteralPath $verboseLogFile
}

if( $deployNFSVM -eq 1 -or $deployNestedESXiVMs -eq 1 -or $deployVCSA -eq 1) {
    My-Logger "Disconnecting from $VIServer ..."
    Disconnect-VIServer -Server $viConnection -Confirm:$false
}

if($setupNewVC -eq 1) {
    My-Logger "Connecting to the new VCSA ..."
    $vc = Connect-VIServer $VCSAIPAddress -User "administrator@$VCSASSODomainName" -Password $VCSASSOPassword -WarningAction SilentlyContinue -Force

    $d = Get-Datacenter -Server $vc $NewVCDatacenterName -ErrorAction Ignore
    if( -Not $d) {
        My-Logger "Creating Datacenter $NewVCDatacenterName ..."
        New-Datacenter -Server $vc -Name $NewVCDatacenterName -Location (Get-Folder -Type Datacenter -Server $vc) | Out-File -Append -LiteralPath $verboseLogFile
    }

    $c = Get-Cluster -Server $vc $NewVCVSANClusterName -ErrorAction Ignore
    if( -Not $c) {
        if($configureESXiStorage -eq 1 -and $supportedStorageType.$SddcProvider -eq "VSAN") {
            My-Logger "Creating VSAN Cluster $NewVCVSANClusterName ..."
            New-Cluster -Server $vc -Name $NewVCVSANClusterName -Location (Get-Datacenter -Name $NewVCDatacenterName -Server $vc) -DrsEnabled -VsanEnabled | Out-File -Append -LiteralPath $verboseLogFile
        } else {
            My-Logger "Creating vSphere Cluster $NewVCVSANClusterName ..."
            New-Cluster -Server $vc -Name $NewVCVSANClusterName -Location (Get-Datacenter -Name $NewVCDatacenterName -Server $vc) -DrsEnabled | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($addESXiHostsToVC -eq 1) {
        $NestedESXiHostnameToIPs.GetEnumerator() | Sort-Object -Property Value | Foreach-Object {
            $VMName = $_.Key
            $VMIPAddress = $_.Value

            $targetVMHost = $VMIPAddress
            if($addHostByDnsName -eq 1) {
                $targetVMHost = $VMName
            }
            My-Logger "Adding ESXi host $targetVMHost to Cluster ..."
            Add-VMHost -Server $vc -Location (Get-Cluster -Name $NewVCVSANClusterName) -User "root" -Password $VMPassword -Name $targetVMHost -Force | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($configureESXiStorage -eq 1) {
        if($supportedStorageType.$SddcProvider -eq "VSAN") {
            My-Logger "Enabling VSAN & disabling VSAN Health Check ..."
            Get-VsanClusterConfiguration -Server $vc -Cluster $NewVCVSANClusterName | Set-VsanClusterConfiguration -HealthCheckIntervalMinutes 0 | Out-File -Append -LiteralPath $verboseLogFile

            foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
                $luns = $vmhost | Get-ScsiLun | select CanonicalName, CapacityGB

                My-Logger "Querying ESXi host disks to create VSAN Diskgroups ..."
                foreach ($lun in $luns) {
                    if(([int]($lun.CapacityGB)).toString() -eq "$NestedESXiCachingvDisk") {
                        $vsanCacheDisk = $lun.CanonicalName
                    }
                    if(([int]($lun.CapacityGB)).toString() -eq "$NestedESXiCapacityvDisk") {
                        $vsanCapacityDisk = $lun.CanonicalName
                    }
                }
                My-Logger "Creating VSAN DiskGroup for $vmhost ..."
                New-VsanDiskGroup -Server $vc -VMHost $vmhost -SsdCanonicalName $vsanCacheDisk -DataDiskCanonicalName $vsanCapacityDisk | Out-File -Append -LiteralPath $verboseLogFile
            }
        } else {
            My-Logger "Adding NFS Storage ..."
            foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
                $vmhost | New-Datastore -Nfs -Name $NFSVMVolumeLabel -Path /mnt/${NFSVMVolumeLabel} -NfsHost $NFSVMIPAddress | Out-File -Append -LiteralPath $verboseLogFile
            }
        }
    }

    if($configureVDS -eq 1) {
        $vds = New-VDSwitch -Server $vc  -Name $NewVCVDSName -Location (Get-Datacenter -Name $NewVCDatacenterName) -Mtu 1600

        New-VDPortgroup -Server $vc -Name $NewVCMgmtDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile
        New-VDPortgroup -Server $vc -Name $NewVCWorkloadDVPGName -Vds $vds | Out-File -Append -LiteralPath $verboseLogFile

        foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
            My-Logger "Adding $vmhost to $NewVCVDSName"
            $vds | Add-VDSwitchVMHost -VMHost $vmhost | Out-Null

            $vmhostNetworkAdapter = Get-VMHost $vmhost | Get-VMHostNetworkAdapter -Physical -Name vmnic1
            $vds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter $vmhostNetworkAdapter -Confirm:$false
        }
    }

    if($clearHealthCheckAlarm -eq 1 -and $supportedStorageType.$SddcProvider -eq "VSAN") {
        My-Logger "Clearing Health Check Alarms ..."
        $alarmMgr = Get-View AlarmManager -Server $vc
        Get-Cluster -Server $vc | where {$_.ExtensionData.TriggeredAlarmState} | %{
            $cluster = $_
            $Cluster.ExtensionData.TriggeredAlarmState | %{
                $alarmMgr.AcknowledgeAlarm($_.Alarm,$cluster.ExtensionData.MoRef)
            }
        }
        $alarmSpec = New-Object VMware.Vim.AlarmFilterSpec
        $alarmMgr.ClearTriggeredAlarms($alarmSpec)
    }

    # Final configure and then exit maintanence mode in case patching was done earlier
    foreach ($vmhost in Get-Cluster -Server $vc | Get-VMHost) {
        # Disable Core Dump Warning
        Get-AdvancedSetting -Entity $vmhost -Name UserVars.SuppressCoredumpWarning | Set-AdvancedSetting -Value 1 -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        # Enable vMotion traffic
        $vmhost | Get-VMHostNetworkAdapter -VMKernel | Set-VMHostNetworkAdapter -VMotionEnabled $true -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile

        if($vmhost.ConnectionState -eq "Maintenance") {
            Set-VMHost -VMhost $vmhost -State Connected -RunAsync -Confirm:$false | Out-File -Append -LiteralPath $verboseLogFile
        }
    }

    if($deployWorkload -eq 1) {
        $vmhost = Get-Cluster -Server $vc | Get-VMHost | Select -First 1
        $datastore = Get-Datastore -Server $vc

        $ovfconfig = Get-OvfConfiguration -Server $vc $PhotonOSOVA
        $ovfNetworkLabel = ($ovfconfig.NetworkMapping | Get-Member -MemberType Properties).Name
        $ovfconfig.NetworkMapping.$ovfNetworkLabel.value = $NewVCWorkloadDVPGName

        foreach ($i in 1..$NewVcWorkloadVMCount) {
            $VMName = "$NewVCWorkloadVMFormat$i"
            $vm = Import-VApp -Server $vc -Source $PhotonOSOVA -OvfConfiguration $ovfconfig -Name $VMName -VMHost $VMhost -Datastore $Datastore -DiskStorageFormat thin -Force
            $vm | Start-VM -Server $vc -Confirm:$false | Out-Null
        }
    }

    My-Logger "Disconnecting from new VCSA ..."
    Disconnect-VIServer $vc -Confirm:$false
}

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

My-Logger "Nested SDDC Lab Deployment Complete!"
My-Logger "StartTime: $StartTime"
My-Logger "  EndTime: $EndTime"
My-Logger " Duration: $duration minutes"
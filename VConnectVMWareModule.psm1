function VConnect-AddPSSnapIn {
param($snapInName)
    $allSnapInsLoaded = (Get-PSSnapin).Name

    $private:isAdded = $allSnapInsLoaded | Select-String $private:snapInName
    if (!$private:isAdded) {
        Add-PSSnapin $snapInName
    }
}

function VConnect-Connect-VIServer {
param($HostServerName, $HostServerPort, $UserName, $Password)
    $private:x = Connect-VIServer -Server $HostServerName -Port $HostServerPort -User $UserName -Password $Password
    return $private:x
}

function VConnect-CreateOrGetFolderForVM {
param($folderName, $dc)
    $private:dcVmFolderMoRef = VConnect-GetDatacenterVmFolderMoRef $dc
    $private:dcVmFolder = Get-Folder -Id $private:dcVmFolderMoRef	

    $private:f = VConnect-GetFolder $private:folderName $private:dcVmFolderMoRef
    if(!$private:f) {		
        $private:newFolderMORef = $private:dcVmFolder | New-Folder -Name $private:folderName # Create new folder if it does not exist
        $private:f = VConnect-GetFolder $private:folderName $private:dcVmFolderMoRef
    }
    return $private:f
}

function VConnect-GetDatacenterVmFolderMoRef {
param($dc)
    $private:dcView = Get-View $dc
    $private:dcVmFolderMoRef = $private:dcView.VmFolder
    return	$private:dcVmFolderMoRef
}

function VConnect-GetFolder {
param($folderName, $dcVmFolderMoRef)
    $private:folder = Get-Folder -Name $private:folderName -Type 'VM' | ?{ $_.Parent.Id -eq $private:dcVmFolderMoRef }
    return $private:folder
}

# Gets the Folder for VM
function VConnect-OLDGetVMFolder {
param($folderName, $datacenter, $shouldFolderExist)
    $private:dc = Get-Datacenter -Name $datacenter
    $private:dcVmFolderMoRef = VConnect-GetDatacenterVmFolderMoRef $private:dc
    $private:f = VConnect-GetFolder $folderName $private:dcVmFolderMoRef
    if ($private:shouldFolderExist -and !$private:f) {
        $errorMsg = "Folder '$folderName' not found."
        throw $errorMsg	
    }
    return $private:f
}

function VConnect-GetLocation {
    param($Datacenter, $Cluster, $FolderName, $RootFolderPath, $ResourcePoolName, $shouldExist)
    if($private:FolderName)
    {
        $private:location = VConnect-GetVMFolder -folderName $FolderName -datacenter $Datacenter -rootFolderPath $RootFolderPath -shouldFolderExist $shouldExist
    }
    else
    {
        $private:location = VConnect-GetResourcePool -Datacenter $Datacenter -Cluster $Cluster -ResourcePoolName $ResourcePoolName -shouldRPExist $shouldExist
    }
    return $private:location
}


# Gets the Folder for VM
function VConnect-GetVMFolder {
param($folderName, $datacenter, $rootFolderPath, $shouldFolderExist)
    if($rootFolderPath) {
        $fullPath = "{0}/vm/{1}/{2}" -f $datacenter, $rootFolderPath, $folderName
    }
    else {
        $fullPath = "{0}/vm/{1}" -f $datacenter, $folderName
    }
    $si = get-view ServiceInstance
    $private:searchIndex = Get-view $si.Content.SearchIndex
    $private:folderMoRef = $private:searchIndex.FindByInventoryPath($fullPath);
    if ($private:shouldFolderExist -and !$private:folderMoRef) {
        $errorMsg = "Folder '$folderName' not found."
        throw $errorMsg	
    }
    $private:f = Get-Folder -Id $private:folderMoRef
    return $private:f
}

function VConnect-GetResourcePool {
    param($Datacenter, $Cluster, $ResourcePoolName, $shouldRPExist)
    $private:dc = Get-Datacenter -Name $private:Datacenter 
    $private:rp = $private:dc | Get-Cluster -Name $private:Cluster | Get-ResourcePool -Name $private:ResourcePoolName
    if ($private:shouldRPExist -and !$private:rp) {
        $errorMsg = "ResourcePool '$private:ResourcePoolName' not found."
        throw $errorMsg	
    }
    return $private:rp
}


# Add the argument (key = value) to the dict, if value is valid (non null)
function VConnect-AddArgumentIfValid {
    param($key, $value, $dict)

    if ($value -ne $null) {
        $dict[$key] = $value
    }
}

function VConnect-GetScriptResult { 
param([bool] $isSuccess,
      [int] $errorCode,
      [string] $message, 						  
      [PSObject] $details)
    
    $result = @{ 
                    IsSuccess = $isSuccess
                    Message = $message
                    ErrorCode = $errorCode
                    Exception = ""
                    Details = $details
                }  
    return New-Object PSObject -Property $result
}

function VConnect-GetScriptErrorResult { 
param([string] $message,
      [string] $exception)
    
    $resultOb = VConnect-GetScriptResult $false -1 $message $null
    $resultOb.Exception = $exception
    return $resultOb
}

function VConnect-GetFullLastError {
    return ($error[0] | out-string)
}

function VConnect-GetVM($Datacenter, $Cluster, $FolderName, $RootFolderPath, $ResourcePoolName, $VMName) {
    $private:location = VConnect-GetLocation -Datacenter $Datacenter -Cluster $Cluster -FolderName $FolderName -RootFolderPath $RootFolderPath -ResourcePoolName $ResourcePoolName -shouldExist $false
    $private:vm = $private:location | Get-VM -Name $private:VMName -ErrorAction SilentlyContinue
    return $private:vm
}

function VConnect-StopVM($Datacenter, $Cluster, $FolderName, $RootFolderPath, $ResourcePoolName, $VMName) {
    $private:vm = VConnect-GetVM -Datacenter $Datacenter -Cluster $Cluster -FolderName $FolderName -RootFolderPath $RootFolderPath -ResourcePoolName $ResourcePoolName -VMName $VMName
    $private:vm | Stop-VM -Confirm:$false
    if (!$?)
    {
        $errorMessage = "Failure performing operation.`nError Message:`n"
        $errorMessage += $global:error[0].ToString()
        throw $errorMessage
    } 
    return $private:vm 
}

function VConnect-StartVM($Datacenter, $Cluster, $FolderName, $RootFolderPath, $ResourcePoolName, $VMName) {
    $private:vm = VConnect-GetVM -Datacenter $Datacenter -Cluster $Cluster -FolderName $FolderName -RootFolderPath $RootFolderPath -ResourcePoolName $ResourcePoolName -VMName $VMName
    $private:vm | Start-VM -Confirm:$false
    if (!$?)
    {
        $errorMessage = "Failure performing operation.`nError Message:`n"
        $errorMessage += $global:error[0].ToString()
        throw $errorMessage
    } 
    return $private:vm 
}

function VConnect-MountIso($Datacenter, $Cluster, $FolderName, $RootFolderPath, $ResourcePoolName, $VMName, $ISOPath) {
    $private:vm = VConnect-GetVM -Datacenter $Datacenter -Cluster $Cluster -FolderName $FolderName -RootFolderPath $RootFolderPath -ResourcePoolName $ResourcePoolName -VMName $VMName
    if (!$?)
    {
        $errorMessage = "Failure getting VM.`nError Message:`n"
        $errorMessage += $global:error[0].ToString()
        throw $errorMessage
    } 
    $private:cddrive=Get-CDDrive -VM $private:vm
    $modCds = Set-CDDrive -CD $private:cddrive -IsoPath $ISOPath -Confirm:$false
    if (!$?)
    {
        $errorMessage = "Failure mounting ISO to VM.`nError Message:`n"
        $errorMessage += $error[0].ToString()
        throw $errorMessage
    } 

    return $private:vm 
}

function VConnect-Init() {
param($HostServerName, $HostServerPort, $UserName, $Password)
    $vmwareModules = Get-Module -ListAvailable 'VMware.VimAutomation.*'
    Write-Debug "VMware Modules Count: $($vmwareModules.Count)"
    # $isVMwareSnapinLoaded = Get-PSSnapin | ?{ $_.Name -eq 'VMware.VimAutomation.Core' }

    if ($vmwareModules.count -gt 0) {
        Write-Debug "Loading VMware Modules..."
        Import-Module VMware.VimAutomation.Core
        Import-Module VMware.VimAutomation.Vds
        VConnect-AddPSSnapIn VMware.VimAutomation.License
        VConnect-AddPSSnapIn VMware.DeployAutomation
        VConnect-AddPSSnapIn VMware.ImageBuilder
    }
    else {
        Write-Debug "Loading VMware SnapIns..."
        VConnect-AddPSSnapIn VMware.VimAutomation.Core
        VConnect-AddPSSnapIn VMware.VimAutomation.Vds
        VConnect-AddPSSnapIn VMware.VimAutomation.License
        VConnect-AddPSSnapIn VMware.DeployAutomation
        VConnect-AddPSSnapIn VMware.ImageBuilder
    }

    # This is so that all PowerCLI commands do not ask for "hey your DefaultVIServerMode setting is not set and I am not able to figure out whether I should execute this command on all connected default servers or just the last one connected. Please choose Y or N"
    Set-PowerCLIConfiguration -DefaultVIServerMode single -scope session -Confirm:$false | Out-Null
    $connection = VConnect-Connect-VIServer $HostServerName $HostServerPort $UserName $Password -ErrorAction Stop
    return $connection
}

function Write-Host {

}
## Export the functions
Export-ModuleMember -Function VConnect-AddPSSnapIn
Export-ModuleMember -Function VConnect-GetVMFolder
Export-ModuleMember -Function VConnect-AddArgumentIfValid
Export-ModuleMember -Function VConnect-GetScriptResult
Export-ModuleMember -Function VConnect-GetScriptErrorResult
Export-ModuleMember -Function VConnect-Init
Export-ModuleMember -Function VConnect-GetVM
Export-ModuleMember -Function VConnect-StopVM
Export-ModuleMember -Function VConnect-StartVM
Export-ModuleMember -Function VConnect-GetFullLastError
Export-ModuleMember -Function Write-Host
Export-ModuleMember -Function VConnect-MountIso

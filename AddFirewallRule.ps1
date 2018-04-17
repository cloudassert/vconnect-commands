# *************************************************************************************** #
# Adding Firewall rules
# *************************************************************************************** #

# User Inputs: AdminUser, AdminPassword, RuleName, Direction, Protocol, LocalPort, Action
# Direction values: in, out
# Action values: allow, block
# Protocol values: TCP, UDP

# *************************************************************************************** #

# Common Functions - Do not Remove this
. .\ExtensionsCommon.ps1

try 
{   
	$connection = VConnect-Connect-VIServer-V2 -ErrorAction Stop
    	$location = VConnect-GetLocation $Datacenter $Cluster $FolderName $RootFolderPath $ResourcePoolName $true $connection
	$vm = VConnect-GetVM $VMId $VMName $location $connection
	if($vm) 
    	{
		$vm | Start-VM -ErrorAction SilentlyContinue -Server $connection
		$adminPass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
		$credential = New-Object System.Management.Automation.PSCredential ($AdminUser, $adminPass)
		$batscript = 'netsh advfirewall firewall add rule name="{0}" protocol="{1}" dir="{2}" localport="{3}" action="{4}"' -f $RuleName, $Protocol, $Direction, $PortNumber, $Action
 		Invoke-VMScript -ScriptText $batscript -VM $vm -GuestCredential $credential -ScriptType Bat
        	if (!$?)
	        {
        	    $errorMessage = "Failure adding the firewall rule.`nError Message:`n"
	            $errorMessage += $error[0].ToString()
        	    throw $errorMessage 
        	}
	        $resultObj = @{
        	    DisplayName = $rule.DisplayName
	            Enabled = $rule.Enabled
        	}
	        $result = New-Object PSObject -Property $resultObj
	        return Get-ScriptResult $true 0 "Adding firewall rule Succeeded" $result        
    	}
}
catch 
{
    $errorMessage = $_.Exception.Message
    $exception = Get-FullLastError
    return Get-ScriptErrorResult $errorMessage $exception  
}
finally
{
    Disconnect-VIServer -Server $connection -Confirm:$false
}
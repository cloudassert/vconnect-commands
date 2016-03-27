###############################
# Initialize VConnect endpoint 
###############################

# Provide the User Name you have configured in VConnect API web.config
$userName = "" 

# Provide the Password you have configured in VConnect API web.config
$password = "" 

# Provide the HOSTNAME of VConnect API Service (From Resource Provider URL Configured in WAP Admin Portal --> VConnect --> Settings
$serverName="localhost" 

# Provide the PORT of VConnect API Service (usually its the default 31101)
$serverPort = 31101 

function Get-VConnectResult($vconnectUrl, $userName, $password)
{
    $private:uri = New-Object System.Uri ($private:vconnectUrl)  
    $private:encoded =  [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($private:userName+":"+$private:password ))  
    $private:headers = @{Authorization = "Basic "+$private:encoded}  
 
     ##################
    # Call VConnect
    ##################
    $private:r = Invoke-WebRequest -Uri $private:uri.AbsoluteUri -Headers $private:headers  
 
     ##########################################
    # Fix Json issues encounted in powershell
    ##########################################
    $private:jc = $private:r.Content.Replace('"name":','"WAPName":');
    $private:jc = $private:jc.Replace('"displayName":','"WAPDisplayName":');
    ###################
    # Convert From Json
    ###################
    $private:om = ConvertFrom-Json -InputObject $private:jc
    return $private:om 
}

function Post-VConnectData($vconnectUrl, $userName, $password, $data)
{
    $private:uri = New-Object System.Uri ($private:vconnectUrl)  
    $private:encoded =  [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($private:userName+":"+$private:password ))  
    $private:headers = @{Authorization = "Basic "+$private:encoded}  
 
    $private:bodyJson = ConvertTo-Json $private:data -Compress
    
    $r = Invoke-WebRequest -Uri $uri.AbsoluteUri -Headers $headers  -Method Post -Body $bodyJson -ContentType "application/json"
    "Response Status:" + $r.StatusCode
    "Response Status Desc:" + $r.StatusDescription
    return $r
}

function Get-VMTemplates()
{
    $controller = "admin/VMTemplateDefs"
    $getActionMethod = "GET"
    $getTemplatesUrl = [string]::Format("http://{0}:{1}/{2}/{3}",$serverName,$serverPort,$controller,$getActionMethod) 
    return Get-VConnectResult -vconnectUrl $getTemplatesUrl -userName $userName -password $password
}

function Get-VMTemplate($connectionId, $displayName)
{
    $templates = Get-VMTemplates
    return $templates | Where-Object {$_.DisplayName -match $displayName -and $_.ConnectionId -eq $connectionId}
}

function Get-VMTemplateWithId($connectionId, $vmTemplateId)
{
    $templates = Get-VMTemplates
    return $templates | Where-Object {$_.DisplayName -match $displayName -and $_.VMTemplateId -eq $vmTemplateId}
}

function Clone-VMTemplate($connectionId, $displayName, $newTemplateDisplayName)
{
    $template = Get-VMTemplate -connectionId $connectionId -displayName $displayName
    $controller = "admin/VMTemplateDefs"
    $getActionMethod = "Clone"
    $cloneTemplateUrl = [string]::Format("http://{0}:{1}/{2}/{3}",$serverName,$serverPort,$controller,$getActionMethod) 
    
    $body = @{
                VMTemplateId = $template.VMTemplateId # Provide id of an existing template
                DisplayName = $template.DisplayName + ' ' +$newTemplateDisplayName # Provide a new Display Name for the Cloned Template
            } 
    Post-VConnectData -vconnectUrl $cloneTemplateUrl -userName $userName -password $password -data $body
}

function Delete-VMTemplate($connectionId, $vmTemplateId)
{
    $template = Get-VMTemplateWithId -connectionId $connectionId -vmTemplateId $vmTemplateId
    $controller = "admin/VMTemplateDefs"
    $getActionMethod = "Delete"
    $deleteTemplateUrl = [string]::Format("http://{0}:{1}/{2}/{3}",$serverName,$serverPort,$controller,$getActionMethod) 
    
    $body = @{
                VMTemplateId = $vmTemplateId
             } 

    Post-VConnectData -vconnectUrl $deleteTemplateUrl -userName $userName -password $password -data $body
}

function Get-Connections()
{
    $controller = "admin/Connections"
    $actionMethod = "GET"
    $vconnectUrl = [string]::Format("http://{0}:{1}/{2}/{3}",$serverName,$serverPort,$controller,$actionMethod) 
    return Get-VConnectResult -vconnectUrl $vconnectUrl -userName $userName -password $password
}

function Get-Connection($connectionName)
{
    $controller = "admin/Connections"
    $actionMethod = "GET"
    $vconnectUrl = [string]::Format("http://{0}:{1}/{2}/{3}",$serverName,$serverPort,$controller,$actionMethod) 
    $connections = Get-VConnectResult -vconnectUrl $vconnectUrl -userName $userName -password $password
    return $connections | Where-Object {$_.ConnectionName -match $connectionName}
}
Get-VMTemplates
#Clone-VMTemplate -connectionId 1 -displayName 'Win2K8 AFD 1' -newTemplateDisplayName 'Clone-1'
#Delete-VMTemplate -connectionId 1 -vmTemplateId 54
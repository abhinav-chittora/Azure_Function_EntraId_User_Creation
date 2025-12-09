using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Starting Azure AD user creation"

try {
    $body = $Request.Body
    
    if (-not $body.DisplayName -or -not $body.UserPrincipalName -or -not $body.MailNickname) {
        throw "Missing required parameters: DisplayName, UserPrincipalName, and MailNickname are required"
    }
    
    if ($env:MSI_ENDPOINT) {
        Connect-MgGraph -Identity -NoWelcome | Out-Null
        Write-Host "Connected using Managed Identity"
    } else {
        Connect-MgGraph -Scopes "User.ReadWrite.All", "GroupMember.ReadWrite.All" -NoWelcome | Out-Null
        Write-Host "Connected using interactive login"
    }
    
    $userParams = @{
        DisplayName = $body.DisplayName
        UserPrincipalName = $body.UserPrincipalName
        MailNickname = $body.MailNickname
        AccountEnabled = if ($null -ne $body.AccountEnabled) { $body.AccountEnabled } else { $true }
        PasswordProfile = @{
            Password = if ($body.Password) { $body.Password } else { -join ((65..90) + (97..122) + (48..57) + (33..47) | Get-Random -Count 16 | ForEach-Object {[char]$_}) }
            ForceChangePasswordNextSignIn = if ($null -ne $body.ForceChangePasswordNextSignIn) { $body.ForceChangePasswordNextSignIn } else { $true }
        }
    }
    
    $newUser = New-MgUser -BodyParameter $userParams
    Write-Host "User created successfully: $($newUser.UserPrincipalName)"
    
    $addedGroups = @()
    if ($body.GroupIds -and $body.GroupIds.Count -gt 0) {
        foreach ($groupId in $body.GroupIds) {
            try {
                New-MgGroupMember -GroupId $groupId -DirectoryObjectId $newUser.Id
                $addedGroups += $groupId
                Write-Host "Added user to group: $groupId"
            } catch {
                Write-Host "Failed to add to group $groupId : $_"
            }
        }
    }
    if ($body.GroupNames -and $body.GroupNames.Count -gt 0) {
        foreach ($groupName in $body.GroupNames) {
            try {
                $group = Get-MgGroup -Filter "displayName eq '$groupName'"
                if ($group) {
                    New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
                    $addedGroups += $groupName
                    Write-Host "Added user to group: $groupName"
                } else {
                    Write-Host "Group not found: $groupName"
                }
            } catch {
                Write-Host "Failed to add to group $groupName : $_"
            }
        }
    }
    
    $result = @{
        status = "success"
        user = @{
            id = $newUser.Id
            displayName = $newUser.DisplayName
            userPrincipalName = $newUser.UserPrincipalName
            accountEnabled = $newUser.AccountEnabled
            groupsAdded = $addedGroups
        }
    }
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Created
        Body = ($result | ConvertTo-Json -Depth 3)
        Headers = @{ "Content-Type" = "application/json" }
    })
    
} catch {
    Write-Host "Error: $_"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::BadRequest
        Body = @{ status = "error"; message = $_.Exception.Message } | ConvertTo-Json
        Headers = @{ "Content-Type" = "application/json" }
    })
}

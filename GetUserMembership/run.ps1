using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Getting user group memberships"

try {
    $userPrincipalName = $Request.Query.UserPrincipalName
    
    if (-not $userPrincipalName) {
        throw "UserPrincipalName parameter is required"
    }
    
    # Authentication
    if ($env:MSI_ENDPOINT) {
        Connect-MgGraph -Identity -NoWelcome | Out-Null
    } else {
        Connect-MgGraph -Scopes "User.Read.All", "GroupMember.Read.All" -NoWelcome | Out-Null
    }
    
    # Get user
    $user = Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'"
    if (-not $user) {
        throw "User not found: $userPrincipalName"
    }
    
    # Get group memberships
    $memberships = Get-MgUserMemberOf -UserId $user.Id
    
    $groups = $memberships | Where-Object { $_.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.group' } | ForEach-Object {
        @{
            id = $_.Id
            displayName = $_.AdditionalProperties.displayName
            description = $_.AdditionalProperties.description
        }
    }
    
    $result = @{
        status = "success"
        user = @{
            id = $user.Id
            displayName = $user.DisplayName
            userPrincipalName = $user.UserPrincipalName
        }
        groups = $groups
        totalGroups = $groups.Count
    }
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = ($result | ConvertTo-Json -Depth 4)
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

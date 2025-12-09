using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Starting Azure AD audit log check"

# Get parameters from query string or use defaults
$daysBack = if ($Request.Query.DaysBack) { [int]$Request.Query.DaysBack } else { 7 }
$targetEventCode = if ($Request.Query.EventCode) { $Request.Query.EventCode } else { "50034" }

try {
    # Authentication: Use Managed Identity in Azure, interactive locally
    if ($env:MSI_ENDPOINT) {
        Connect-MgGraph -Identity -NoWelcome | Out-Null
        Write-Host "Connected using Managed Identity"
    } else {
        Connect-MgGraph -Scopes "AuditLog.Read.All" -NoWelcome | Out-Null
        Write-Host "Connected using interactive login"
    }
    
    # Fetch audit logs
    $startDate = (Get-Date).AddDays(-$daysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-Host "Fetching logs from $startDate"
    
    $auditLogs = Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge $startDate and category eq 'UserManagement'" -All
    Write-Host "Retrieved $($auditLogs.Count) audit log entries"
    
    # Filter for account creation failures
    $failedCreations = $auditLogs | Where-Object {
        $_.ActivityDisplayName -like "*Add user*"  -and
        $_.Result -eq "failure" # -and
        # $_.ResultReason -like "*$targetEventCode*"
    }
    
    # Prepare response
    $result = @{
        status = "success"
        daysBack = $daysBack
        targetEventCode = $targetEventCode
        totalLogs = $auditLogs.Count
        failedCreations = $failedCreations.Count
        failures = $failedCreations | ForEach-Object {
            @{
                timestamp = $_.ActivityDateTime
                user = $_.InitiatedBy.User.UserPrincipalName
                targetUser = $_.TargetResources[0].UserPrincipalName
                result = $_.Result
                reason = $_.ResultReason
                correlationId = $_.CorrelationId
            }
        }
    }
    
    Write-Host "Found $($failedCreations.Count) failed account creation(s)"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body = ($result | ConvertTo-Json -Depth 5)
        Headers = @{ "Content-Type" = "application/json" }
    })
    
} catch {
    Write-Host "Error: $_"
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        Body = @{ status = "error"; message = $_.Exception.Message } | ConvertTo-Json
        Headers = @{ "Content-Type" = "application/json" }
    })
} finally {
    # Disconnect-MgGraph -ErrorAction SilentlyContinue
}

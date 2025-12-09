# Azure AD User Management Functions

Azure Functions for managing Azure AD users and audit logs using PowerShell and Microsoft Graph API.

## Prerequisites

- Azure Functions Core Tools
- PowerShell 7.4+
- Microsoft.Graph PowerShell module
- Azure AD tenant with appropriate permissions

## Functions

### 1. AuditLogChecker

Check Azure AD audit logs for failed user creation attempts.

**Endpoint:** `GET/POST /api/AuditLogChecker`

**Parameters:**

- `DaysBack` (optional): Number of days to look back (default: 7)
- `EventCode` (optional): Target event code (default: "50034")

**Example:**

```bash
curl "http://localhost:7071/api/AuditLogChecker?DaysBack=14"
```

### 2. CreateUser

Create a new Azure AD user with optional group membership.

**Endpoint:** `POST /api/CreateUser`

**Required Parameters:**

- `DisplayName`: User's display name
- `UserPrincipalName`: User's UPN (email)
- `MailNickname`: Mail alias

**Optional Parameters:**

- `Password`: Custom password (auto-generated if not provided)
- `AccountEnabled`: Enable/disable account (default: true)
- `ForceChangePasswordNextSignIn`: Force password change (default: true)
- `GroupIds`: Array of group IDs to add user to
- `GroupNames`: Array of group display names to add user to

**Example:**

```bash
curl -X POST http://localhost:7071/api/CreateUser \
  -H "Content-Type: application/json" \
  -d '{
    "DisplayName": "John Doe",
    "UserPrincipalName": "john.doe@yourdomain.com",
    "MailNickname": "johndoe",
    "Password": "SecurePass123!",
    "GroupNames": ["Developers", "IT Team"]
  }'
```

### 3. GetUserMembership

Retrieve group memberships for a user.

**Endpoint:** `GET /api/GetUserMembership`

**Parameters:**

- `UserPrincipalName`: User's UPN

**Example:**

```bash
curl "http://localhost:7071/api/GetUserMembership?UserPrincipalName=john.doe@yourdomain.com"
```

## Local Development

1. Install dependencies:

    ```bash
    Install-Module Microsoft.Graph -Scope CurrentUser
    ```

2. Configure settings:

    ```bash
    # Set IsEncrypted to false in local.settings.json for local dev
    ```

3. Start the function:

    ```bash
    func start
    ```

## Authentication

- **Local:** Interactive login with required Microsoft Graph scopes
- **Azure:** Managed Identity with assigned permissions

## Required Permissions

- `AuditLog.Read.All` - Read audit logs
- `User.ReadWrite.All` - Create and manage users
- `User.Read.All` - Read user information
- `GroupMember.ReadWrite.All` - Manage group memberships
- `GroupMember.Read.All` - Read group memberships

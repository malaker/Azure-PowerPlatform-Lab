# Dataverse Service Implementations

This folder contains multiple implementations of `IDataverseService` with different authentication mechanisms.

## Available Implementations

### 1. DataverseService (Managed Identity)
**File:** `DataverseService.cs`

**Authentication Method:** Uses Azure Managed Identity (System-Assigned or User-Assigned)

**When to Use:**
- Running in Azure (App Service, Azure Functions, Container Apps, etc.)
- No need to manage credentials/secrets
- Most secure option for Azure-hosted applications
- Supports both delegated and application permissions

**Configuration Required:**
```json
{
  "Dataverse": {
    "Url": "https://your-org.crm.dynamics.com/"
  }
}
```

**Setup Steps:**
1. Enable Managed Identity on your Azure resource
2. Grant the Managed Identity permissions to Dataverse using the `apiPermissions.ps1` script
3. No credentials needed in configuration

---

### 2. DataverseServiceWithAppRegistration (Client Secret)
**File:** `DataverseServiceWithAppRegistration.cs`

**Authentication Method:** Uses App Registration with Client Secret (Client Credentials Flow)

**When to Use:**
- Running locally or outside Azure
- Need consistent identity across environments
- Service-to-service authentication
- Background jobs/daemons

**Configuration Required:**
```json
{
  "Dataverse": {
    "Url": "https://your-org.crm.dynamics.com/",
    "AppRegistration": {
      "ClientId": "your-app-client-id",
      "ClientSecret": "your-client-secret",
      "TenantId": "your-tenant-id"
    }
  }
}
```

**Setup Steps:**
1. Create an App Registration in Azure AD
2. Create a client secret for the app
3. Create an Application User in Dataverse
4. Assign security roles to the Application User
5. Store credentials securely (Azure Key Vault recommended for production)

**Security Note:** Client secrets should be stored in Azure Key Vault and rotated regularly.

---

## Dependency Injection Configuration

### Option 1: Using Managed Identity (Default)

```csharp
// In Program.cs or Startup.cs
builder.Services.AddScoped<IDataverseService, DataverseService>();
```

### Option 2: Using App Registration

```csharp
// In Program.cs or Startup.cs
builder.Services.AddScoped<IDataverseService, DataverseServiceWithAppRegistration>();
```

### Option 3: Conditional Registration (Based on Configuration)

```csharp
// In Program.cs or Startup.cs
var useAppRegistration = builder.Configuration.GetValue<bool>("Dataverse:UseAppRegistration", false);

if (useAppRegistration)
{
    builder.Services.AddScoped<IDataverseService, DataverseServiceWithAppRegistration>();
}
else
{
    builder.Services.AddScoped<IDataverseService, DataverseService>();
}
```

### Option 4: Named Services (Use Both)

```csharp
// In Program.cs or Startup.cs
builder.Services.AddScoped<DataverseService>();
builder.Services.AddScoped<DataverseServiceWithAppRegistration>();

// Create a factory
builder.Services.AddScoped<IDataverseService>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var useAppRegistration = config.GetValue<bool>("Dataverse:UseAppRegistration", false);

    return useAppRegistration
        ? sp.GetRequiredService<DataverseServiceWithAppRegistration>()
        : sp.GetRequiredService<DataverseService>();
});
```

---

## ServiceClient Connection Strings

Both implementations use the `ServiceClient` class from the Dataverse SDK. Here are the connection string formats:

### Managed Identity
The `DataverseService` uses `DefaultAzureCredential` which automatically handles token acquisition.

### App Registration (Client Secret)
```
AuthType=ClientSecret;Url=https://your-org.crm.dynamics.com/;ClientId=<client-id>;ClientSecret=<client-secret>
```

### Certificate-Based Authentication (Future Enhancement)
```
AuthType=Certificate;Url=https://your-org.crm.dynamics.com/;ClientId=<client-id>;Thumbprint=<cert-thumbprint>
```

---

## Setting Up App Registration for Dataverse

### 1. Create App Registration
```powershell
# Azure Portal > Azure Active Directory > App registrations > New registration
# Or use Azure CLI
az ad app create --display-name "Dataverse-ServiceApp"
```

### 2. Create Client Secret
```powershell
# Azure Portal > App registration > Certificates & secrets > New client secret
# Or use Azure CLI
az ad app credential reset --id <app-id>
```

### 3. Grant API Permissions
Use the included PowerShell script:
```powershell
.\Scripts\apiPermissions.ps1 `
    -ManagedIdentityName "your-managed-identity" `
    -ResourceGroupName "your-resource-group"
```

### 4. Create Application User in Dataverse
1. Go to Power Platform Admin Center
2. Navigate to your environment > Settings > Users + permissions > Application users
3. Click "New app user"
4. Select your App Registration
5. Assign security roles (e.g., System Administrator, or custom roles)

---

## Environment-Specific Configuration

### local.settings.json (Local Development)
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
  },
  "Dataverse": {
    "Url": "https://your-org.crm.dynamics.com/",
    "UseAppRegistration": true,
    "AppRegistration": {
      "ClientId": "your-client-id",
      "ClientSecret": "your-client-secret",
      "TenantId": "your-tenant-id"
    }
  }
}
```

### Azure App Settings (Production)
For production, use Managed Identity and store sensitive values in Azure Key Vault:

```
Dataverse__Url = https://your-org.crm.dynamics.com/
Dataverse__UseAppRegistration = false
```

Or if using App Registration in production:
```
Dataverse__Url = https://your-org.crm.dynamics.com/
Dataverse__UseAppRegistration = true
Dataverse__AppRegistration__ClientId = <from-key-vault>
Dataverse__AppRegistration__ClientSecret = @Microsoft.KeyVault(SecretUri=https://your-vault.vault.azure.net/secrets/DataverseClientSecret/)
Dataverse__AppRegistration__TenantId = your-tenant-id
```

---

## Comparison Matrix

| Feature | Managed Identity | App Registration |
|---------|-----------------|------------------|
| **Credential Management** | Automatic | Manual (secrets/certs) |
| **Credential Rotation** | Automatic | Manual |
| **Local Development** | Requires Azure CLI or VS | Works with secrets |
| **Azure Hosting** | ✅ Recommended | ✅ Supported |
| **On-Premises** | ❌ Not supported | ✅ Supported |
| **Security** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ (with Key Vault) |
| **Setup Complexity** | Low | Medium |
| **Identity Type** | Azure Resource | Application |

---

## Best Practices

1. **Production:** Use Managed Identity whenever possible
2. **Secrets:** Store client secrets in Azure Key Vault, never in source control
3. **Permissions:** Follow principle of least privilege - grant only necessary permissions
4. **Monitoring:** Enable logging to track authentication failures
5. **Rotation:** Rotate client secrets every 90 days or less
6. **Testing:** Use App Registration for local development, Managed Identity in Azure

---

## Troubleshooting

### Common Issues

**Issue:** "Unable to connect to Dataverse"
- Check that the Dataverse URL is correct
- Verify the Managed Identity or App has permissions
- Check Application User exists in Dataverse with proper security roles

**Issue:** "Authentication failed"
- For Managed Identity: Ensure identity is enabled and has permissions
- For App Registration: Verify client ID, secret, and tenant ID are correct

**Issue:** "Insufficient privileges"
- Check security roles assigned to the Application User in Dataverse
- Verify API permissions are granted and admin consent is provided

---

## Additional Resources

- [Microsoft Dataverse Service Client Documentation](https://learn.microsoft.com/power-apps/developer/data-platform/xrm-tooling/use-connection-strings-xrm-tooling-connect)
- [Azure Managed Identity Documentation](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
- [App Registration Best Practices](https://learn.microsoft.com/azure/active-directory/develop/security-best-practices-for-app-registration)

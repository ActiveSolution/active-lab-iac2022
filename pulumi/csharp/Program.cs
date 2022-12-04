using System.Collections.Generic;
using Pulumi;
using Pulumi.AzureNative.KeyVault;
using Pulumi.AzureNative.KeyVault.Inputs;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.Web;
using Pulumi.AzureNative.Web.Inputs;
using Pulumi.Random;

return await Pulumi.Deployment.RunAsync(async () =>
{
    var getName = (string resourcetype) => $"{Pulumi.Deployment.Instance.ProjectName.ToLower()}-{resourcetype}-";

    var config = new Pulumi.Config();

    var resourceGroup = new ResourceGroup("PulumiLab", new()
    {
        ResourceGroupName = "PulumiLab"
    });

    var appSvcPlan = new AppServicePlan(getName("plan"), new()
    {
        ResourceGroupName = resourceGroup.Name,
        Kind = "Linux",
        Reserved = true,
        Sku = new SkuDescriptionArgs
        {
            Name = config.Require("appServicePlanSize"),
            Size = config.Require("appServicePlanSize"),
            Tier = config.Require("appServicePlanTier")
        }
    }, 
    new() { Parent = resourceGroup });

    var isFreeTier = config.Require("appServicePlanTier").ToLower() == "free";

    var app = new WebApp(getName("web"), new()
    {
        ResourceGroupName = resourceGroup.Name,
        ServerFarmId = appSvcPlan.Id,
        SiteConfig = new SiteConfigArgs {
            LinuxFxVersion = "DOCKER|iacworkshop.azurecr.io/infrawebapp:v1",
            AlwaysOn = !isFreeTier,
            Use32BitWorkerProcess = isFreeTier
        },
        Identity = new ManagedServiceIdentityArgs() {
            Type = Pulumi.AzureNative.Web.ManagedServiceIdentityType.SystemAssigned
        }
    }, 
    new() { Parent = appSvcPlan });

    var clientConfig = await Pulumi.AzureNative.Authorization.GetClientConfig.InvokeAsync();

    var kv = new Vault(getName("kv"), new() {
        ResourceGroupName = resourceGroup.Name,
        Properties = new VaultPropertiesArgs {
            TenantId = clientConfig.TenantId,
            Sku = new SkuArgs
            {
                Family = SkuFamily.A,
                Name = SkuName.Standard
            },
            AccessPolicies = new[] {
                new AccessPolicyEntryArgs {
                    ObjectId = clientConfig.ObjectId,
                    TenantId = clientConfig.TenantId,
                    Permissions = new PermissionsArgs {
                        Secrets = {
                            SecretPermissions.Get,
                            SecretPermissions.List,
                            SecretPermissions.Set,
                            SecretPermissions.Delete
                        }
                    }
                },
                new AccessPolicyEntryArgs {
                    ObjectId = app.Identity.Apply(x => x!.PrincipalId),
                    TenantId = app.Identity.Apply(x => x!.TenantId),
                    Permissions = new PermissionsArgs {
                        Secrets = {
                            SecretPermissions.Get,
                            SecretPermissions.List
                        }
                    }
                }
            }
        }
    }, new() { Parent = resourceGroup });

    new Secret("testSecret", new()
    {
        ResourceGroupName = resourceGroup.Name,
        VaultName = kv.Name,
        SecretName = "testSecret",
        Properties = new SecretPropertiesArgs { Value = "secretValue" }
    }, new() { Parent = kv });

    var password = new RandomPassword("sqlAdminPassword", new() {
        Length = 16,
        Special = true
    });

    var sqlServer = new Pulumi.AzureNative.Sql.Server(getName("sql"), new() {
        ResourceGroupName = resourceGroup.Name,
        AdministratorLogin = "infraadmin",
        AdministratorLoginPassword = password.Result,
        Administrators = new Pulumi.AzureNative.Sql.Inputs.ServerExternalAdministratorArgs {
            Login = app.Name,
            Sid = app.Identity.Apply(x => x!.PrincipalId)
        }
    }, new() { Parent = resourceGroup });

    var db = new Pulumi.AzureNative.Sql.Database(getName("db"), new() {
        DatabaseName = "infradb",
        ResourceGroupName = resourceGroup.Name,
        ServerName = sqlServer.Name,
        Collation = "SQL_Latin1_General_CP1_CI_AS",
        Sku = new Pulumi.AzureNative.Sql.Inputs.SkuArgs { Name = "Basic" },
        MaxSizeBytes = 1 * 1024 * 1024 * 1024
    }, new() { Parent = sqlServer });

    new Pulumi.AzureNative.Sql.FirewallRule("AllowAllWindowsAzureIps", new() {
        FirewallRuleName = "AllowAllWindowsAzureIps",
        ServerName = sqlServer.Name,
        ResourceGroupName = resourceGroup.Name,
        StartIpAddress = "0.0.0.0",
        EndIpAddress = "0.0.0.0"
    }, new() { Parent = sqlServer });

    new WebAppConnectionStrings("ConnectionStrings", new() {
        Name = app.Name,
        ResourceGroupName = app.ResourceGroup,
        Properties = new InputMap<ConnStringValueTypePairArgs> {
            { 
                "infradb", 
                new ConnStringValueTypePairArgs {
                    Type = ConnectionStringType.SQLServer,
                    Value = sqlServer.Name.Apply(x => $"Data Source=tcp:${x}.database.windows.net,1433;Initial Catalog=infradb;Authentication=Active Directory Interactive;")
                } 
            }
        }
    }, new() { Parent = app });

    var laws = new Pulumi.AzureNative.OperationalInsights.Workspace(getName("laws"), new() {
        ResourceGroupName = resourceGroup.Name,
    }, new() { Parent = resourceGroup });

    var ai = new Pulumi.AzureNative.Insights.V20200202.Component(getName("ai"), new() {
        ResourceGroupName = resourceGroup.Name,
        WorkspaceResourceId = laws.Id,
        ApplicationType = "web",
        Kind = "web"
    }, new() { Parent = app });

    new WebAppApplicationSettings("AppSettings", new() {
        Name = app.Name,
        ResourceGroupName = app.ResourceGroup,
        Properties = {
            { "DOCKER_REGISTRY_SERVER_URL", "https://iacworkshop.azurecr.io" },
            { "DOCKER_REGISTRY_SERVER_USERNAME", "iacworkshop" },
            { "DOCKER_REGISTRY_SERVER_PASSWORD", "XXX" },
            { "KeyVaultName", kv.Name },
            { "APPINSIGHTS_INSTRUMENTATIONKEY", ai.InstrumentationKey },
            { "APPLICATIONINSIGHTS_CONNECTION_STRING", ai.ConnectionString },
            { "ApplicationInsightsAgent_EXTENSION_VERSION", "~3" },
            { "XDT_MicrosoftApplicationInsights_Mode", "recommended" }
        }
    }, new() { Parent = app });

    return new Dictionary<string, object?> {
        ["websiteAddress"] = app.DefaultHostName.Apply(x => $"https://{x}/")
    };
});
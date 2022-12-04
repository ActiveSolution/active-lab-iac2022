import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure-native";
import * as random from "@pulumi/random";
import * as insights from '@pulumi/azure-native/insights/v20200202';

function getName(resourceType: string) {
    return `${pulumi.getProject().toLowerCase()}-${resourceType}-`
}

const config = new pulumi.Config();
const clientConfig = pulumi.output(azure.authorization.getClientConfig());

const resourceGroup = new azure.resources.ResourceGroup("PulumiLab", {
    resourceGroupName: "PulumiLab"
});

const appSvcPlan = new azure.web.AppServicePlan(getName("plan"), {
    resourceGroupName: resourceGroup.name,
    kind: "linux",
    reserved: true,
    sku: {
        name: config.require("appServicePlanSize"),
        size: config.require("appServicePlanSize"),
        tier: config.require("appServicePlanTier")
    }
}, {
    parent: resourceGroup
})

const isFreeTier = config.require("appServicePlanTier").toLowerCase() == "free";

const app = new azure.web.WebApp(getName("web"), {
    resourceGroupName: resourceGroup.name,
    serverFarmId: appSvcPlan.id,
    siteConfig: {
        linuxFxVersion: "DOCKER|iacworkshop.azurecr.io/infrawebapp:v1",
        alwaysOn: !isFreeTier,
        use32BitWorkerProcess: isFreeTier
    },
    identity: {
        type: azure.types.enums.web.ManagedServiceIdentityType.SystemAssigned
    }
}, {
    parent: appSvcPlan
});

const kv = new azure.keyvault.Vault(getName("kv"), {
    resourceGroupName: resourceGroup.name,
    properties: {
        tenantId: clientConfig.tenantId,
        sku: {
            family: azure.keyvault.SkuFamily.A,
            name: azure.keyvault.SkuName.Standard
        },
        accessPolicies: [
            {
                objectId: clientConfig.objectId,
                tenantId: clientConfig.tenantId,
                permissions: {
                    secrets: [
                        "get",
                        "list",
                        "set",
                        "delete"
                    ]
                }
            },
            {
                objectId: app.identity.apply(x => x!.principalId),
                tenantId: app.identity.apply(x => x!.tenantId),
                permissions: {
                    secrets: [
                        "get",
                        "list"
                    ]
                }
            }
        ]
    }
}, {
    parent: resourceGroup
})

new azure.keyvault.Secret("testSecret", {
    resourceGroupName: resourceGroup.name,
    vaultName: kv.name,
    secretName: "testSecret",
    properties: {
        value: "secretValue",
    },
}, {
    parent: kv
});

const password = new random.RandomPassword("sqlAdminPassword", {
    length: 16,
    special: true
});

const sqlServer = new azure.sql.Server(getName("sql"), {
    resourceGroupName: resourceGroup.name,
    administratorLogin: "infraadmin",
    administratorLoginPassword: password.result,
    administrators: {
        login: app.name,
        sid: app.identity.apply(x => x!.principalId)
    }
}, {
    parent: resourceGroup
});

const db = new azure.sql.Database(getName("db"), {
    databaseName: "infradb",
    resourceGroupName: resourceGroup.name,
    serverName: sqlServer.name,
    collation: "SQL_Latin1_General_CP1_CI_AS",
    sku: {
        name: "Basic"
    },
    maxSizeBytes: 1 * 1024 * 1024 * 1024
}, {
    parent: sqlServer
});

const laws = new azure.operationalinsights.Workspace(getName("laws"), {
    resourceGroupName: resourceGroup.name,
}, {
    parent: resourceGroup
});

const ai = new insights.Component(getName("ai"), {
    resourceGroupName: resourceGroup.name,
    workspaceResourceId: laws.id,
    applicationType: "web",
    kind: "web"
}, {
    parent: app
});

new azure.web.WebAppApplicationSettings("AppSettings", {
    name: app.name,
    resourceGroupName: app.resourceGroup,
    properties: {
        "DOCKER_REGISTRY_SERVER_URL": "https://iacworkshop.azurecr.io",
        "DOCKER_REGISTRY_SERVER_USERNAME": "iacworkshop",
        "DOCKER_REGISTRY_SERVER_PASSWORD": "XXX",
        "KeyVaultName": kv.name,
        "APPINSIGHTS_INSTRUMENTATIONKEY": ai.instrumentationKey,
        "APPLICATIONINSIGHTS_CONNECTION_STRING": ai.connectionString,
        "ApplicationInsightsAgent_EXTENSION_VERSION": "~3",
        "XDT_MicrosoftApplicationInsights_Mode": "recommended"
    }
}, {
    parent: app
});

new azure.web.WebAppConnectionStrings("ConnectionStrings", {
    name: app.name,
    resourceGroupName: app.resourceGroup,
    properties: {
        "infradb": {
            type: azure.types.enums.web.ConnectionStringType.SQLAzure,
            value: pulumi.interpolate `Data Source=tcp:${sqlServer.name}.database.windows.net,1433;Initial Catalog=infradb;Authentication=Active Directory Interactive;`
        }
    }
}, {
    parent: app
});

new azure.sql.FirewallRule("AllowAllWindowsAzureIps", {
    firewallRuleName: "AllowAllWindowsAzureIps",
    serverName: sqlServer.name,
    resourceGroupName: resourceGroup.name,
    startIpAddress: "0.0.0.0",
    endIpAddress: "0.0.0.0",
}, {
    parent: sqlServer
});

export const websiteAddress = pulumi.interpolate `https://${app.defaultHostName}/`;
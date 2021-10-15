import * as pulumi from "@pulumi/pulumi";
import * as azure from "@pulumi/azure-native";
import * as az from "@pulumi/azure";

export class WebAppWithApplicationInsights extends pulumi.ComponentResource {
    public identity: pulumi.Output<azure.types.output.web.ManagedServiceIdentityResponse | undefined>;
    public name: pulumi.Output<string>;
    public defaultHostName: pulumi.Output<string>;
    private appSettings: {[key: string]: pulumi.Input<string>} = {};
    private connectionStrings: {[key: string]: pulumi.Input<azure.types.input.web.ConnStringValueTypePairArgs>} = {};

    constructor(name: string, props: WebAppWithApplicationInsightsProps, opts?: pulumi.ComponentResourceOptions) {
        super("PulumiLab:class:WebAppWithApplicationInsights", name, {}, opts)

        const app = new azure.web.WebApp(props.webName, {
            resourceGroupName: props.resourceGroupName,
            serverFarmId: props.appServicePlanId,
            siteConfig: {
                linuxFxVersion: "DOCKER|iacworkshop.azurecr.io/infrawebapp:v1",
                alwaysOn: !props.isFreeTier,
                use32BitWorkerProcess: props.isFreeTier
            },
            identity: {
                type: "SystemAssigned"
            }
        }, {
            parent: this
        });
        this.identity = app.identity;
        this.name = app.name;
        this.defaultHostName = app.defaultHostName;

        const ai = new az.appinsights.Insights(props.aiName, {
            resourceGroupName: props.resourceGroupName,
            workspaceId: props.workspaceId,
            applicationType: "web"
        }, {
            parent: app
        });

        new azure.web.WebAppConnectionStrings("ConnectionStrings", {
            name: app.name,
            resourceGroupName: app.resourceGroup,
            properties: this.connectionStrings
        }, {
            parent: app
        });

        this.appSettings = {
            "DOCKER_REGISTRY_SERVER_URL": "https://iacworkshop.azurecr.io",
            "DOCKER_REGISTRY_SERVER_USERNAME": "iacworkshop",
            "DOCKER_REGISTRY_SERVER_PASSWORD": "XXX",
            "APPINSIGHTS_INSTRUMENTATIONKEY": ai.instrumentationKey,
            "APPLICATIONINSIGHTS_CONNECTION_STRING": ai.connectionString,
            "ApplicationInsightsAgent_EXTENSION_VERSION": "~3",
            "XDT_MicrosoftApplicationInsights_Mode": "recommended"
        };
        new azure.web.WebAppApplicationSettings("AppSettings", {
            name: app.name,
            resourceGroupName: app.resourceGroup,
            properties: this.appSettings
        }, {
            parent: app
        });
    }

    addAppSetting(name: string, value: pulumi.Input<string>) {
        this.appSettings[name] = value;
    }
    addConnectionString(name: string, type: azure.types.enums.web.ConnectionStringType, value: pulumi.Input<string>) {
        this.connectionStrings[name] = {
            type: type,
            value: value
        };
    }
}

interface WebAppWithApplicationInsightsProps {
    webName: string,
    resourceGroupName: pulumi.Input<string>,
    appServicePlanId: pulumi.Input<string>,
    isFreeTier: boolean,
    aiName: string,
    workspaceId: pulumi.Input<string>
}
using Pulumi;
using Pulumi.AzureNative.Web;
using Pulumi.AzureNative.Web.Inputs;

public class WebAppWithApplicationInsightsArgs : ResourceArgs
{
    public string WebName { get; set; }
    public Input<string> ResourceGroupName { get; set; }
    public Input<string> AppServicePlanId { get; set; }
    public bool IsFreeTier { get; set; }
    public string AiName { get; set; }
    public Input<string> WorkspaceId { get; set; }
}

public class WebAppWithApplicationInsights : ComponentResource
{
    private InputMap<string> appSettings;
    private InputMap<ConnStringValueTypePairArgs> connectionStrings = new();

    public WebAppWithApplicationInsights(string name, WebAppWithApplicationInsightsArgs args, ComponentResourceOptions? options = null) 
        : base("PulumiLab:class:WebAppWithApplicationInsights", name, args, options)
    {
        var app = new WebApp(args.WebName, new()
        {
            ResourceGroupName = args.ResourceGroupName,
            ServerFarmId = args.AppServicePlanId,
            SiteConfig = new SiteConfigArgs {
                LinuxFxVersion = "DOCKER|iacworkshop.azurecr.io/infrawebapp:v1",
                AlwaysOn = !args.IsFreeTier,
                Use32BitWorkerProcess = args.IsFreeTier
            },
            Identity = new ManagedServiceIdentityArgs() {
                Type = Pulumi.AzureNative.Web.ManagedServiceIdentityType.SystemAssigned
            }
        }, 
        new() { Parent = this });

        var ai = new Pulumi.AzureNative.Insights.V20200202.Component(args.AiName, new() {
            ResourceGroupName = args.ResourceGroupName,
            WorkspaceResourceId = args.WorkspaceId,
            ApplicationType = "web",
            Kind = "web"
        }, new() { Parent = app });

        this.appSettings = new InputMap<string> {
                { "DOCKER_REGISTRY_SERVER_URL", "https://iacworkshop.azurecr.io" },
                { "DOCKER_REGISTRY_SERVER_USERNAME", "iacworkshop" },
                { "DOCKER_REGISTRY_SERVER_PASSWORD", "JtA75wA31qqzawrPyOiC/bSr6y5whHIC" },
                { "APPINSIGHTS_INSTRUMENTATIONKEY", ai.InstrumentationKey },
                { "APPLICATIONINSIGHTS_CONNECTION_STRING", ai.ConnectionString },
                { "ApplicationInsightsAgent_EXTENSION_VERSION", "~3" },
                { "XDT_MicrosoftApplicationInsights_Mode", "recommended" }
            };

        new WebAppApplicationSettings("AppSettings", new() {
            Name = app.Name,
            ResourceGroupName = app.ResourceGroup,
            Properties = this.appSettings
        }, new() { Parent = app });

        new WebAppConnectionStrings("ConnectionStrings", new() {
            Name = app.Name,
            ResourceGroupName = app.ResourceGroup,
            Properties = this.connectionStrings
        }, new() { Parent = app });

        Identity = app.Identity;
        Name = app.Name;
        DefaultHostName = app.DefaultHostName;

        this.RegisterOutputs();
    }

    public void AddAppSetting(string name, Input<string> value)
    {
        this.appSettings.Add(name, value);
    }
    
    public void AddConnectionString(string name, ConnectionStringType type, Input<string> value) {
        this.connectionStrings.Add(name, new ConnStringValueTypePairArgs {
            Type = type,
            Value = value
        });
    }
    
    public Output<Pulumi.AzureNative.Web.Outputs.ManagedServiceIdentityResponse?> Identity { get; private set; }
    public Output<string> Name { get; private set; }
    public Output<string> DefaultHostName { get; private set; }
}
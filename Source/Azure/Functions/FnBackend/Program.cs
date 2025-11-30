using FnBackend.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Abstractions;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Configurations;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Web;
using Microsoft.OpenApi.Models;

var builder = new HostBuilder()
    .ConfigureFunctionsWebApplication(workerApplication =>
    {
        workerApplication.UseMiddleware<FnBackend.Middleware.AuthenticationMiddleware>();
        workerApplication.UseMiddleware<FnBackend.Middleware.HttpContextAccessorMiddleware>();
    })
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices((context, services) =>
    {
        services.AddLogging(logging =>
        {
            logging.AddConsole();
        });

        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.Configure<LoggerFilterOptions>(options =>
        {
            // The Application Insights SDK adds a default logging filter that instructs ILogger to capture only Warning and more severe logs. Application Insights requires an explicit override.
            // Log levels can also be configured using appsettings.json. For more information, see https://learn.microsoft.com/en-us/azure/azure-monitor/app/worker-service#ilogger-logs
            LoggerFilterRule? toRemove = options.Rules.FirstOrDefault(rule => rule.ProviderName
                == "Microsoft.Extensions.Logging.ApplicationInsights.ApplicationInsightsLoggerProvider");

            if (toRemove is not null)
            {
                options.Rules.Remove(toRemove);
            }
        });

        // Configure Azure AD JWT Bearer Authentication
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddMicrosoftIdentityWebApi(options =>
            {
                context.Configuration.Bind("AzureAd", options);
                options.TokenValidationParameters.NameClaimType = "name";
            },
            options =>
            {
                context.Configuration.Bind("AzureAd", options);
            });

        services.AddAuthorization();

        // Register HttpContextAccessor for accessing HTTP context in services
        services.AddHttpContextAccessor();

        // Register Dataverse service
        services.AddScoped<IDataverseService, DataverseService>();

        // Configure OpenAPI/Swagger
        services.AddSingleton<IOpenApiConfigurationOptions>(sp =>
        {
            var configuration = sp.GetRequiredService<IConfiguration>();
            var tenantId = configuration["AzureAd:TenantId"] ?? "common";
            var clientId = configuration["AzureAd:ClientId"] ?? "your-client-id";

            var options = new OpenApiConfigurationOptions()
            {
                Info = new OpenApiInfo()
                {
                    Version = "v1",
                    Title = "Azure Functions Backend API",
                    Description = "API for Microsoft Power Platform integration with Azure Functions and Dataverse. Protected with OAuth2 (Azure AD).",
                    Contact = new OpenApiContact()
                    {
                        Name = "API Support",
                        Email = "support@example.com"
                    }
                },
                Servers = DefaultOpenApiConfigurationOptions.GetHostNames(),
                OpenApiVersion = OpenApiVersionType.V2, // Use OpenAPI 2.0 (Swagger) for Power Platform compatibility
                IncludeRequestingHostName = true,
                ForceHttps = false,
                ForceHttp = false
            };

            return options;
        });
    })
    //local development
    .ConfigureAppConfiguration((context, config) =>
    {
        // Add appsettings.json
        config.AddJsonFile("appsettings.json", optional: true, reloadOnChange: true);

        // Add environment-specific appsettings
        var environmentName = context.HostingEnvironment.EnvironmentName;
        config.AddJsonFile($"appsettings.{environmentName}.json", optional: true, reloadOnChange: true);

        // Add environment variables (this includes local.settings.json Values in Azure Functions)
        config.AddEnvironmentVariables();
    });



var host = builder.Build();

await host.RunAsync();

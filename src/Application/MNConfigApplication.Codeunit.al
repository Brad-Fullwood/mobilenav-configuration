#if BJF_MN_CONFIG_SOURCE
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Application boundary: resolves one provider, validates its complete declaration,
/// executes it, and records success in the same transaction.
/// </summary>
codeunit 77784 "BJF MN Config Application"
{
    procedure ApplyProvider(ProviderType: Enum "BJF MN Config Provider")
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        ConfigurationBuilder: Codeunit "BJF MN Config Builder";
        Provider: Interface "BJF MN Config Provider";
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ProviderVersion: Integer;
    begin
        ProviderCatalog.GetMetadata(
            ProviderType, ProviderId, ProviderName, ProviderDescription, ProviderVersion);

        Provider := ProviderType;
        Provider.DefineConfiguration(ConfigurationBuilder);
        ConfigurationBuilder.GetLines(TempConfigurationLine);

        ConfigurationValidator.Validate(TempConfigurationLine);
        ConfigurationExecutor.Execute(TempConfigurationLine);
        StatusManagement.RecordApplied(ProviderId, ProviderName, ProviderVersion);
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationValidator: Codeunit "BJF MN Config Validator";
        ConfigurationExecutor: Codeunit "BJF MN Config Executor";
        StatusManagement: Codeunit "BJF MN Config Status Mgt.";
}
#endif

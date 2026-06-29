#if BJF_MN_CONFIG_SOURCE
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Discovers registered providers and validates their required metadata contract.</summary>
codeunit 77782 "BJF MN Provider Catalog"
{
    Access = Internal;

    procedure Populate(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary)
    var
        ProviderType: Enum "BJF MN Config Provider";
        Ordinal: Integer;
    begin
        ProviderBuffer.Reset();
        ProviderBuffer.DeleteAll();

        foreach Ordinal in Enum::"BJF MN Config Provider".Ordinals() do
            if Ordinal <> Enum::"BJF MN Config Provider"::None.AsInteger() then begin
                ProviderType := Enum::"BJF MN Config Provider".FromInteger(Ordinal);
                AddProvider(ProviderBuffer, ProviderType);
            end;
    end;

    procedure GetMetadata(ProviderType: Enum "BJF MN Config Provider"; var ProviderId: Code[50]; var ProviderName: Text[100]; var ProviderDescription: Text[250]; var ProviderVersion: Integer)
    var
        Provider: Interface "BJF MN Config Provider";
    begin
        if ProviderType = Enum::"BJF MN Config Provider"::None then
            Error(NoneProviderErr);

        Provider := ProviderType;
        ProviderId := Provider.GetId();
        ProviderName := Provider.GetName();
        ProviderDescription := Provider.GetDescription();
        ProviderVersion := Provider.GetVersion();
        ValidateMetadata(ProviderId, ProviderName, ProviderDescription, ProviderVersion);
    end;

    local procedure AddProvider(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary; ProviderType: Enum "BJF MN Config Provider")
    var
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ProviderVersion: Integer;
    begin
        GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription, ProviderVersion);
        EnsureUniqueId(ProviderBuffer, ProviderId);

        ProviderBuffer.Init();
        ProviderBuffer.Provider := ProviderType;
        ProviderBuffer."Provider ID" := ProviderId;
        ProviderBuffer.Name := ProviderName;
        ProviderBuffer.Description := ProviderDescription;
        ProviderBuffer."Defined Version" := ProviderVersion;
        ConfigurationStatus.PopulateState(ProviderBuffer);
        ProviderBuffer.Insert();
    end;

    local procedure EnsureUniqueId(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary; ProviderId: Code[50])
    begin
        ProviderBuffer.SetRange("Provider ID", ProviderId);
        if not ProviderBuffer.IsEmpty() then
            Error(DuplicateIdErr, ProviderId);
        ProviderBuffer.Reset();
    end;

    local procedure ValidateMetadata(ProviderId: Code[50]; ProviderName: Text[100]; ProviderDescription: Text[250]; ProviderVersion: Integer)
    begin
        if ProviderId = '' then
            Error(IdRequiredErr);
        if ProviderName = '' then
            Error(NameRequiredErr, ProviderId);
        if ProviderDescription = '' then
            Error(DescriptionRequiredErr, ProviderId);
        if ProviderVersion <= 0 then
            Error(VersionRequiredErr, ProviderId);
    end;

    var
        ConfigurationStatus: Record "BJF MN Config Status";
        NoneProviderErr: Label 'The None value is not a configuration provider.';
        IdRequiredErr: Label 'A MobileNAV configuration provider returned an empty provider ID.';
        NameRequiredErr: Label 'MobileNAV configuration provider %1 returned an empty name.', Comment = '%1 = provider id';
        DescriptionRequiredErr: Label 'MobileNAV configuration provider %1 returned an empty description.', Comment = '%1 = provider id';
        VersionRequiredErr: Label 'MobileNAV configuration provider %1 must return a positive version.', Comment = '%1 = provider id';
        DuplicateIdErr: Label 'More than one MobileNAV configuration provider uses the ID %1.', Comment = '%1 = provider id';
}
#endif

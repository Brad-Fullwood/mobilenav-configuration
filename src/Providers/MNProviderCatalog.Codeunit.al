namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Discovers registered providers, validates their metadata, and fingerprints each definition so
/// the admin page can show whether what is applied still matches what is declared.
/// </summary>
codeunit 77782 "BJF MN Provider Catalog"
{
    Access = Internal;

    procedure Populate(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary)
    var
        ProviderType: Enum "BJF MN Config Provider";
        Ordinal: Integer;
    begin
        ProviderBuffer.Reset();
        ProviderBuffer.DeleteAll(false);

        foreach Ordinal in Enum::"BJF MN Config Provider".Ordinals() do
            if Ordinal <> Enum::"BJF MN Config Provider"::None.AsInteger() then begin
                ProviderType := Enum::"BJF MN Config Provider".FromInteger(Ordinal);
                this.AddProvider(ProviderBuffer, ProviderType);
            end;
    end;

    procedure GetMetadata(ProviderType: Enum "BJF MN Config Provider"; var ProviderId: Code[50]; var ProviderName: Text[100]; var ProviderDescription: Text[250])
    var
        Provider: Interface "BJF MN Config Provider";
    begin
        if ProviderType = Enum::"BJF MN Config Provider"::None then
            Error(this.NoneProviderErr);

        Provider := ProviderType;
        ProviderId := Provider.GetId();
        ProviderName := Provider.GetName();
        ProviderDescription := Provider.GetDescription();
        this.ValidateMetadata(ProviderId, ProviderName, ProviderDescription);
    end;

    /// <summary>Builds the provider's definition and returns its lines with the profile rows expanded.</summary>
    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        ConfigurationBuilder: Codeunit "BJF MN Config Builder";
        Provider: Interface "BJF MN Config Provider";
    begin
        Provider := ProviderType;
        Provider.DefineConfiguration(ConfigurationBuilder);
        ConfigurationBuilder.GetLines(TempConfigurationLine);
    end;

    local procedure AddProvider(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary; ProviderType: Enum "BJF MN Config Provider")
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
    begin
        this.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        this.EnsureUniqueId(ProviderBuffer, ProviderId);
        this.BuildDefinition(ProviderType, TempConfigurationLine);

        ProviderBuffer.Init();
        ProviderBuffer.Provider := ProviderType;
        ProviderBuffer."Provider ID" := ProviderId;
        ProviderBuffer.Name := ProviderName;
        ProviderBuffer.Description := ProviderDescription;
        ProviderBuffer."Defined Hash" := this.ConfigurationHash.Compute(TempConfigurationLine);
        this.ConfigurationStatus.PopulateState(ProviderBuffer);
        ProviderBuffer.Insert(false);
    end;

    local procedure EnsureUniqueId(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary; ProviderId: Code[50])
    begin
        ProviderBuffer.SetRange("Provider ID", ProviderId);
        if not ProviderBuffer.IsEmpty() then
            Error(this.DuplicateIdErr, ProviderId);
        ProviderBuffer.Reset();
    end;

    local procedure ValidateMetadata(ProviderId: Code[50]; ProviderName: Text[100]; ProviderDescription: Text[250])
    begin
        if ProviderId = '' then
            Error(this.IdRequiredErr);
        if ProviderName = '' then
            Error(this.NameRequiredErr, ProviderId);
        if ProviderDescription = '' then
            Error(this.DescriptionRequiredErr, ProviderId);
    end;

    var
        ConfigurationStatus: Record "BJF MN Config Status";
        ConfigurationHash: Codeunit "BJF MN Config Hash";
        NoneProviderErr: Label 'The None value is not a configuration provider.';
        IdRequiredErr: Label 'A MobileNAV configuration provider returned an empty provider ID.';
        NameRequiredErr: Label 'MobileNAV configuration provider %1 returned an empty name.', Comment = '%1 = provider id';
        DescriptionRequiredErr: Label 'MobileNAV configuration provider %1 returned an empty description.', Comment = '%1 = provider id';
        DuplicateIdErr: Label 'More than one MobileNAV configuration provider uses the ID %1.', Comment = '%1 = provider id';
}

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
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        ProviderType: Enum "BJF MN Config Provider";
    begin
        ProviderBuffer.Reset();
        ProviderBuffer.DeleteAll(false);

        foreach ProviderType in this.ProviderTypes() do
            this.AddProvider(ProviderBuffer, ProviderType, TempConfigurationLine, TempConfigurationProperty);
    end;

    /// <summary>Every registered provider, in enum order, without None.</summary>
    /// <returns>The provider types.</returns>
    procedure ProviderTypes() ProviderTypeList: List of [Enum "BJF MN Config Provider"]
    var
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"BJF MN Config Provider".Ordinals() do
            if Ordinal <> Enum::"BJF MN Config Provider"::None.AsInteger() then
                ProviderTypeList.Add(Enum::"BJF MN Config Provider".FromInteger(Ordinal));
        exit(ProviderTypeList);
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

    /// <summary>Builds the provider's definition: its lines, with the profile rows expanded, and its properties.</summary>
    /// <param name="ProviderType">The provider to build.</param>
    /// <param name="TempConfigurationLine">Returns the provider's lines.</param>
    /// <param name="TempConfigurationProperty">Returns the provider's properties.</param>
    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    var
        ConfigurationBuilder: Codeunit "BJF MN Config Builder";
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        Provider: Interface "BJF MN Config Provider";
    begin
        Provider := ProviderType;
        Provider.DefineConfiguration(ConfigurationBuilder);
        ConfigurationBuilder.GetDefinition(TempConfigurationLine, TempConfigurationProperty);
        ConfigurationApplication.ExpandTranslatedCaptions(TempConfigurationLine);
    end;

    /// <summary>Adds a provider's row to the buffer: its metadata, the hash of its definition and its applied state.</summary>
    /// <param name="ProviderBuffer">Receives the provider's row.</param>
    /// <param name="ProviderType">The provider to add.</param>
    /// <param name="TempConfigurationLine">Returns the provider's lines, as hashed.</param>
    /// <param name="TempConfigurationProperty">Returns the provider's properties, as hashed.</param>
    procedure AddProvider(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary; ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    var
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
    begin
        this.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        this.EnsureUniqueId(ProviderBuffer, ProviderId);
        this.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);

        ProviderBuffer.Init();
        ProviderBuffer.Validate(Provider, ProviderType);
        ProviderBuffer.Validate("Provider ID", ProviderId);
        ProviderBuffer.Validate(Name, ProviderName);
        ProviderBuffer.Validate(Description, ProviderDescription);
        ProviderBuffer.Validate("Defined Hash", this.ConfigurationHash.Compute(TempConfigurationLine, TempConfigurationProperty));
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

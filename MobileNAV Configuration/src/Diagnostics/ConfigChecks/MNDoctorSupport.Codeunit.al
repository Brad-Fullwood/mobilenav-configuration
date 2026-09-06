namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// What every configuration check shares: the registered providers and their rebuilt
/// definitions, the profiles to check against, and the fix-context format a check and its
/// ApplyFix agree on. Checks compare declared intent with live data; they never apply.
/// </summary>
codeunit 77799 "BJF MN Doctor Support"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Profile Setup" = r,
        tabledata "MobileNAV Master Data" = r;

    procedure ListProviders(var TempProvider: Record "BJF MN Provider Buffer" temporary)
    begin
        this.ProviderCatalog.Populate(TempProvider);
        TempProvider.Reset();
    end;

    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
    begin
        this.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
    end;

    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    begin
        this.ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
        TempConfigurationLine.Reset();
        TempConfigurationProperty.Reset();
    end;

    /// <summary>Every profile MobileNAV defines.</summary>
    procedure ListProfiles(var Profiles: List of [Code[30]])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                Profiles.Add(MasterData.Code);
            until MasterData.Next() = 0;
    end;

    /// <summary>Every profile that has at least one user, which is where field rows are written.</summary>
    procedure ListFieldProfiles(var Profiles: List of [Code[30]])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        if ProfileSetup.FindSet() then
            repeat
                if not Profiles.Contains(ProfileSetup.Profile) then
                    Profiles.Add(ProfileSetup.Profile);
            until ProfileSetup.Next() = 0;
    end;

    /// <summary>Packs a fix's kind and arguments into a finding's Fix Context.</summary>
    procedure PackFix(Kind: Text; Args: List of [Text]): Text
    var
        Packed: TextBuilder;
        Arg: Text;
    begin
        Packed.Append(Kind);
        foreach Arg in Args do begin
            Packed.Append(this.FixSeparatorTok);
            Packed.Append(Arg);
        end;
        exit(Packed.ToText());
    end;

    procedure UnpackFix(FixContext: Text; var Kind: Text; var Args: List of [Text])
    var
        Parts: List of [Text];
    begin
        Parts := FixContext.Split(this.FixSeparatorTok);
        Kind := Parts.Get(1);
        Parts.RemoveAt(1);
        Args := Parts;
    end;

    /// <summary>Prefixes a finding with the provider it concerns.</summary>
    procedure Prefix(TempProvider: Record "BJF MN Provider Buffer" temporary; Message: Text): Text
    begin
        exit(StrSubstNo(this.PrefixedMsg, TempProvider.Name, Message));
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        PrefixedMsg: Label '[%1] %2', Comment = '%1 = provider name, %2 = finding', Locked = true;
        FixSeparatorTok: Label '|', Locked = true;
}

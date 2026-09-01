namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>
/// What every configuration check needs: the registered providers and their rebuilt
/// definitions, the live MobileNAV rows a declaration maps to, and a fix-context format the
/// checks and their fixes share. Checks compare declared intent to live data; they never apply.
/// </summary>
codeunit 77799 "BJF MN Doctor Support"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r,
        tabledata "MobileNAV Profile Setup" = r,
        tabledata "MobileNAV Master Data" = r,
        tabledata "Tenant Web Service" = r;

    procedure ListProviders(var TempProvider: Record "BJF MN Provider Buffer" temporary)
    begin
        this.ProviderCatalog.Populate(TempProvider);
        TempProvider.Reset();
    end;

    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        this.ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine);
        TempConfigurationLine.Reset();
    end;

    /// <summary>Resolves the service name a page id is registered under; empty when MobileNAV has no Main row for it.</summary>
    procedure GetServiceName(PageId: Integer): Text[100]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if ServiceSetup.FindFirst() then
            exit(ServiceSetup."Service Name");
        exit('');
    end;

    procedure GetMainRow(ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        exit(ServiceSetup.Get(ServiceName, ServiceSetup."Line Type"::Main));
    end;

    /// <summary>Finds the service-level field row for a page control, resolving the control name the way MobileNAV stores it.</summary>
    procedure FindFieldRow(ServiceName: Text[100]; ControlName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.SetRange(FieldName, this.StoredFieldName(ControlName));
        exit(ServiceSetup.FindFirst());
    end;

    procedure StoredFieldName(ControlName: Text[100]): Text[75]
    begin
        exit(CopyStr(this.WebServiceHandling.ConvertFieldName(ControlName), 1, 75));
    end;

    /// <summary>The name of an option field's current member, as MobileNAV's configuration compares it.</summary>
    procedure OptionName(var ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer): Text
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
        Ordinal: Integer;
        Index: Integer;
    begin
        RecRef.GetTable(ServiceSetup);
        FieldRef := RecRef.Field(FieldNumber);
        Ordinal := FieldRef.Value();
        for Index := 1 to FieldRef.EnumValueCount() do
            if FieldRef.GetEnumValueOrdinal(Index) = Ordinal then
                exit(FieldRef.GetEnumValueName(Index));
        exit('');
    end;

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

    procedure HasWebService(ObjectType: Option; ServiceName: Text[100]; var TenantWebService: Record "Tenant Web Service"): Boolean
    begin
        exit(TenantWebService.Get(ObjectType, ServiceName));
    end;

    /// <summary>Packs a fix's kind and arguments into the finding's Fix Context; see Unpack.</summary>
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

    procedure Prefix(TempProvider: Record "BJF MN Provider Buffer" temporary; Message: Text): Text
    begin
        exit(StrSubstNo(this.PrefixedMsg, TempProvider.Name, Message));
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        PrefixedMsg: Label '[%1] %2', Comment = '%1 = provider name, %2 = finding', Locked = true;
        FixSeparatorTok: Label '|', Locked = true;
}

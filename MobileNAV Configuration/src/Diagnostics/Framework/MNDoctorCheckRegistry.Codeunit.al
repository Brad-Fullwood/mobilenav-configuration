namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Fills the Doctor Check table from the check type enum, so the Doctor page can count and list the checks.</summary>
codeunit 77814 "BJF MN Doctor Check Registry"
{
    Access = Internal;
    Permissions = tabledata "BJF Doctor Check" = rim;

    /// <summary>Adds each check the enum holds that the table lacks, and corrects the area and description of the rest.</summary>
    procedure Refresh()
    var
        DoctorCheck: Record "BJF Doctor Check";
        CheckType: Enum "BJF Diagnostic Check Type";
        Ordinal: Integer;
        NewArea: Text[50];
        NewDescription: Text[250];
    begin
        foreach Ordinal in Enum::"BJF Diagnostic Check Type".Ordinals() do begin
            CheckType := Enum::"BJF Diagnostic Check Type".FromInteger(Ordinal);
            NewArea := CopyStr(this.AreaOf(Ordinal), 1, MaxStrLen(NewArea));
            NewDescription := CopyStr(this.DescriptionOf(CheckType), 1, MaxStrLen(NewDescription));
            if not DoctorCheck.Get(CheckType) then begin
                DoctorCheck.Init();
                DoctorCheck.Validate("Check Type", CheckType);
                DoctorCheck.Validate("Check Area", NewArea);
                DoctorCheck.Validate("What It Checks", NewDescription);
                DoctorCheck.Insert(false);
            end else
                if (DoctorCheck."Check Area" <> NewArea) or (DoctorCheck."What It Checks" <> NewDescription) then begin
                    DoctorCheck.Validate("Check Area", NewArea);
                    DoctorCheck.Validate("What It Checks", NewDescription);
                    DoctorCheck.Modify(false);
                end;
        end;
    end;

    /// <summary>The area a check belongs to, from its ordinal. Ordinals below 100 are MobileNAV's, 100 to 199 are satellite apps', 200 and up are configuration checks.</summary>
    /// <param name="Ordinal">The check's ordinal in the enum.</param>
    /// <returns>The area caption.</returns>
    local procedure AreaOf(Ordinal: Integer): Text
    begin
        if Ordinal < 100 then
            exit(this.MobileNAVAreaLbl);
        if Ordinal < 200 then
            exit(this.SatelliteAreaLbl);
        exit(this.ConfigurationAreaLbl);
    end;

    /// <summary>What a check looks at, in plain words.</summary>
    /// <param name="CheckType">The check.</param>
    /// <returns>The description shown in the checks list.</returns>
    local procedure DescriptionOf(CheckType: Enum "BJF Diagnostic Check Type"): Text
    var
        Descriptions: Dictionary of [Integer, Text];
        Description: Text;
    begin
        this.FillDescriptions(Descriptions);
        if Descriptions.Get(CheckType.AsInteger(), Description) then
            exit(Description);
        exit(this.OtherAppLbl);
    end;

    local procedure FillDescriptions(var Descriptions: Dictionary of [Integer, Text])
    begin
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines".AsInteger(), this.LeftoverJnlLinesLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Page Relations".AsInteger(), this.PageRelationsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"MobileNAV Version".AsInteger(), this.VersionLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Emulator HttpClient".AsInteger(), this.EmulatorHttpLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Layout Buffers".AsInteger(), this.LayoutBuffersLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Option Captions".AsInteger(), this.OptionCaptionsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Services".AsInteger(), this.ConfigServicesLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Fields".AsInteger(), this.ConfigFieldsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Profiles".AsInteger(), this.ConfigProfilesLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Page Rules".AsInteger(), this.ConfigPageRulesLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Apply State".AsInteger(), this.ConfigApplyStateLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Properties".AsInteger(), this.ConfigPropertiesLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Staging".AsInteger(), this.ConfigStagingLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Relations".AsInteger(), this.ConfigRelationsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Page Rows".AsInteger(), this.ConfigPageRowsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Groups".AsInteger(), this.ConfigGroupsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Layouts".AsInteger(), this.ConfigLayoutsLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Master Data".AsInteger(), this.ConfigMasterDataLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Appearance".AsInteger(), this.ConfigAppearanceLbl);
        Descriptions.Add(Enum::"BJF Diagnostic Check Type"::"Config Line Formats".AsInteger(), this.ConfigLineFormatsLbl);
    end;

    var
        MobileNAVAreaLbl: Label 'MobileNAV';
        SatelliteAreaLbl: Label 'Other apps';
        ConfigurationAreaLbl: Label 'Configuration';
        LeftoverJnlLinesLbl: Label 'Stale lines in the item journal batch that the MobileNAV output card writes to.';
        PageRelationsLbl: Label 'Relation rows and the card pages that list pages open, so a broken reference does not stop every rebuild.';
        VersionLbl: Label 'Whether the installed MobileNAV is older than the version this app was verified against.';
        OptionCaptionsLbl: Label 'Option fields whose captions outnumber their values, which stops the login with "Option captions don''t match to values", and whether Refresh Page takes option values from the field instead of the page''s WSDL.';
        LayoutBuffersLbl: Label 'Dynamic layout buffer rows left from old configuration builds, which stop a login once their Query ID comes round again.';
        EmulatorHttpLbl: Label 'Whether the device emulator may call the page services through HttpClient.';
        ConfigServicesLbl: Label 'Declared pages are registered, published as web services and reachable.';
        ConfigFieldsLbl: Label 'Declared control visibility and importance on the live field rows.';
        ConfigProfilesLbl: Label 'Profile rows match what the provider declared.';
        ConfigPageRulesLbl: Label 'Link relations and page rules that undo an otherwise correct configuration.';
        ConfigApplyStateLbl: Label 'Declared configuration has reached the devices, and no construction window is left open.';
        ConfigPropertiesLbl: Label 'Page and control settings on the live rows.';
        ConfigStagingLbl: Label 'Declared wizards exist with their stages and switches.';
        ConfigRelationsLbl: Label 'Declared links and lookups exist on the live page, with their filters and propagated fields.';
        ConfigPageRowsLbl: Label 'Filters, flow filters, saved filters and offline operations.';
        ConfigGroupsLbl: Label 'Declared field order and field groups.';
        ConfigLayoutsLbl: Label 'Dynamic layouts with their conditions, actions and action lines.';
        ConfigMasterDataLbl: Label 'Categories, their translations, profiles and per-profile page switches.';
        ConfigAppearanceLbl: Label 'Captions and menu pictures on the live rows.';
        ConfigLineFormatsLbl: Label 'Line format rows, in the order the framework writes them.';
        OtherAppLbl: Label 'Check contributed by another app.';
}

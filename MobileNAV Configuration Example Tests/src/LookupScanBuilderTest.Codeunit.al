namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Checks the builder rules for a lookup that also takes a scan, as MobileNAV configures Bin_Code,
/// Lot_No and Serial_No: Validation(), MobileType() and RegEx() are accepted on a Lookup and become the
/// field settings the apply writes and the doctor compares. The tests read no MobileNAV data.
/// </summary>
codeunit 50159 "Lookup Scan Builder Test"
{
    Subtype = Test;
    Access = Internal;

    /// <summary>A lookup with Validation and MobileType gives one lookup line and both field settings.</summary>
    [Test]
    procedure LookupCarriesValidationAndMobileType()
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
        Configuration: Codeunit "BJF MN Config Builder";
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Lookup(this.ControlTok, Page::"MobileNAV Bin", this.CodeFieldTok, this.DescriptionFieldTok)
                .Validation(Enum::"BJF MN Validation Behavior"::ScanOrManualEntry)
                .MobileType(Enum::"BJF MN Mobile Type"::Barcode)
                .Filter(this.CodeFieldTok, this.CodeFieldTok);
        Configuration.GetDefinition(TempLine, TempProperty);

        TempLine.SetRange("Control Name", this.ControlTok);
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Lookup Field");
        if TempLine.Count() <> 1 then
            Error(this.LookupLineCountErr, TempLine.Count());
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Scan Field");
        if not TempLine.IsEmpty() then
            Error(this.ScanLineErr);

        this.AssertSetting(TempProperty, Enum::"BJF MN Property"::FieldMobileType, this.BarcodeTok);
        this.AssertSetting(TempProperty, Enum::"BJF MN Property"::FieldValidationBehavior, this.ScanOrManualEntryTok);
    end;

    /// <summary>
    /// A lookup with RegEx gives the pattern and RegEx Results settings. A Barcode field with a
    /// lookup and no pattern makes the device ask which field takes the scan.
    /// </summary>
    [Test]
    procedure LookupCarriesRegEx()
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
        Configuration: Codeunit "BJF MN Config Builder";
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Lookup(this.ControlTok, Page::"MobileNAV Bin", this.CodeFieldTok, this.DescriptionFieldTok)
                .Validation(Enum::"BJF MN Validation Behavior"::ScanOrManualEntry)
                .MobileType(Enum::"BJF MN Mobile Type"::Barcode)
                .RegEx(this.AnyValuePatternTok, this.FirstGroupTok)
                .Filter(this.CodeFieldTok, this.CodeFieldTok);
        Configuration.GetDefinition(TempLine, TempProperty);

        this.AssertSetting(TempProperty, Enum::"BJF MN Property"::RegExPattern, this.AnyValuePatternTok);
        this.AssertSetting(TempProperty, Enum::"BJF MN Property"::RegExResults, this.FirstGroupTok);
        this.AssertSetting(TempProperty, Enum::"BJF MN Property"::FieldMobileType, this.BarcodeTok);
    end;

    /// <summary>A lookup without Validation or MobileType declares neither setting, so MobileNAV's own values stay.</summary>
    [Test]
    procedure PlainLookupLeavesFieldSettingsAlone()
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
        Configuration: Codeunit "BJF MN Config Builder";
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Lookup(this.ControlTok, Page::"MobileNAV Bin", this.CodeFieldTok, this.DescriptionFieldTok);
        Configuration.GetDefinition(TempLine, TempProperty);

        TempProperty.SetRange("Control Name", this.ControlTok);
        TempProperty.SetFilter(Property, '%1|%2', Enum::"BJF MN Property"::FieldMobileType, Enum::"BJF MN Property"::FieldValidationBehavior);
        if not TempProperty.IsEmpty() then
            Error(this.UnexpectedSettingErr);
    end;

    /// <summary>MobileType() on a plain field is still refused.</summary>
    [Test]
    procedure MobileTypeOnFieldIsRefused()
    var
        Configuration: Codeunit "BJF MN Config Builder";
    begin
        asserterror Configuration.Page(Page::"MobileNAV Item")
            .Field(this.ControlTok)
                .MobileType(Enum::"BJF MN Mobile Type"::Barcode);
        if not GetLastErrorText().Contains(this.NotApplicableTok) then
            Error(this.WrongErrorErr, GetLastErrorText());
    end;

    local procedure AssertSetting(var TempProperty: Record "BJF MN Config Property" temporary; Property: Enum "BJF MN Property"; Expected: Text)
    begin
        TempProperty.Reset();
        TempProperty.SetRange("Control Name", this.ControlTok);
        TempProperty.SetRange(Property, Property);
        if not TempProperty.FindFirst() then
            Error(this.SettingMissingErr, Format(Property));
        if TempProperty.Value <> Expected then
            Error(this.SettingValueErr, Format(Property), Expected, TempProperty.Value);
        TempProperty.Reset();
    end;

    var
        ControlTok: Label 'No', Locked = true;
        CodeFieldTok: Label 'Code', Locked = true;
        DescriptionFieldTok: Label 'Description', Locked = true;
        BarcodeTok: Label 'Barcode', Locked = true;
        ScanOrManualEntryTok: Label 'ScanOrManualEntry', Locked = true;
        AnyValuePatternTok: Label '^(.*)$', Locked = true;
        FirstGroupTok: Label '1', Locked = true;
        NotApplicableTok: Label 'does not apply to', Locked = true;
        LookupLineCountErr: Label 'Expected one lookup line, found %1.', Comment = '%1 = number of lines';
        ScanLineErr: Label 'The lookup also produced a scan line.';
        SettingMissingErr: Label 'The lookup has no %1 setting.', Comment = '%1 = setting';
        SettingValueErr: Label 'The lookup''s %1 setting is %3, expected %2.', Comment = '%1 = setting, %2 = expected value, %3 = actual value';
        UnexpectedSettingErr: Label 'A lookup without Validation or MobileType declares a mobile type or validation behavior setting.';
        WrongErrorErr: Label 'MobileType() on a field failed with an unexpected error: %1', Comment = '%1 = error text';
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Finds option fields whose captions outnumber their stored values. The configuration build takes
/// the captions from MobileNAV CaptionML Admin (the user's language, then ENU, then the field's option
/// captions) and the values from the service setup row, and keeps one value per caption while values
/// last. The device splits both lists on commas and stops the login with "Option captions don't match
/// to values" when the counts differ.
/// The cause is where MobileNAV's Refresh Page takes the values from. ValidateFieldNo on the service
/// setup table reads them from the page's SOAP WSDL while HasUserData is true (MobileNAV can still
/// retrieve the credentials a device left at its last login), and that WSDL leaves out
/// values an enum extension adds to a table of another app. The captions come from the field and do
/// include them. HasUserData is false when MobileNAV Master Data "AddOn-Converted Option String" is set,
/// and ValidateFieldNo then converts the field's own option members with ConvertOptionString, which
/// gives the names the SOAP service accepts. No MobileNAV page shows that field, so the check reports it
/// while it is off and its fix sets it once. Every later Refresh Page then writes complete values.
/// </summary>
codeunit 77817 "BJF Check Option Captions" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV CaptionML Admin." = r,
        tabledata "MobileNAV Master Data" = rm,
        tabledata "MobileNAV Service Setup" = rm;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        MasterData: Record "MobileNAV Master Data";
        ServiceSetup: Record "MobileNAV Service Setup";
        CaptionSource: Text;
        CaptionCount: Integer;
        ValueCount: Integer;
    begin
        if this.GetGeneralSetup(MasterData) then
            if not MasterData."AddOn-Converted Option String" then
                Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Option Captions", Enum::"BJF Diagnostic Severity"::Warning,
                    this.WsdlSourceMsg, MasterData.RecordId(), this.WsdlSourceFixMsg);
        ServiceSetup.SetFilter("Line Type", '<>%1', ServiceSetup."Line Type"::Main);
        ServiceSetup.SetFilter(OptionValues, '<>%1', '');
        if ServiceSetup.FindSet() then
            repeat
                ValueCount := this.CountItems(ServiceSetup.BuildOptionValues(true));
                CaptionCount := this.MaxCaptionCount(ServiceSetup, CaptionSource);
                if CaptionCount > ValueCount then
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Option Captions", Enum::"BJF Diagnostic Severity"::Blocker,
                        StrSubstNo(this.MismatchMsg, ServiceSetup."Service Name", ServiceSetup.FieldName, CaptionCount, CaptionSource, ValueCount),
                        ServiceSetup.RecordId(), StrSubstNo(this.FixMsg, ServiceSetup."Service Name", ServiceSetup.FieldName));
            until ServiceSetup.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        LicenseSetup: Record "MobileNAV License Setup";
    begin
        case Finding."Related Record ID".TableNo() of
            Database::"MobileNAV Master Data":
                this.UseFieldOptionMembers();
            Database::"MobileNAV Service Setup":
                begin
                    if not ServiceSetup.Get(Finding."Related Record ID") then
                        exit;
                    if (ServiceSetup."Table No." = 0) or (ServiceSetup."Field No." = 0) then
#pragma warning disable AA0448 // FieldName is the stored control name, a value of the row.
                        Error(this.NoFieldErr, ServiceSetup."Service Name", ServiceSetup.FieldName);
#pragma warning restore AA0448
                    this.UseFieldOptionMembers();
                    // MobileNAV's own Field No. validation rebuilds the values and captions, the same step Refresh Page runs.
                    ServiceSetup.Validate("Field No.", ServiceSetup."Field No.");
                    ServiceSetup.Modify(false);
                    // Devices keep their downloaded configuration until the next build; this makes every user rebuild at login.
                    LicenseSetup.SetConfigurationChanged();
                end;
        end;
    end;

    /// <summary>Sets AddOn-Converted Option String, so Refresh Page takes option values from the field's option members instead of the page's WSDL.</summary>
    local procedure UseFieldOptionMembers()
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not this.GetGeneralSetup(MasterData) then
            Error(this.NoGeneralSetupErr);
        if MasterData."AddOn-Converted Option String" then
            exit;
        MasterData.Validate("AddOn-Converted Option String", true);
        MasterData.Modify(false);
    end;

    local procedure GetGeneralSetup(var MasterData: Record "MobileNAV Master Data"): Boolean
    begin
        exit(MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal));
    end;

    /// <summary>The largest caption count among the caption sources the build can use for the row.</summary>
    /// <param name="ServiceSetup">The option row.</param>
    /// <param name="CaptionSource">Receives where the largest list comes from.</param>
    /// <returns>The number of captions.</returns>
    local procedure MaxCaptionCount(ServiceSetup: Record "MobileNAV Service Setup"; var CaptionSource: Text): Integer
    var
        ItemCount: Integer;
        MaxCount: Integer;
    begin
        MaxCount := this.MaxCaptionRowCount(ServiceSetup, CaptionSource);
        if this.HasEnglishCaptionRow(ServiceSetup) or (ServiceSetup."Table No." = 0) or (ServiceSetup."Field No." = 0) then
            exit(MaxCount);
        ItemCount := this.CountItems(ServiceSetup.GetOptionCaptions(ServiceSetup."Table No.", ServiceSetup."Field No."));
        if ItemCount > MaxCount then begin
            MaxCount := ItemCount;
            CaptionSource := this.FieldCaptionsLbl;
        end;
        exit(MaxCount);
    end;

    local procedure MaxCaptionRowCount(ServiceSetup: Record "MobileNAV Service Setup"; var CaptionSource: Text): Integer
    var
        CaptionML: Record "MobileNAV CaptionML Admin.";
        ItemCount: Integer;
        MaxCount: Integer;
    begin
        MaxCount := 0;
        this.FilterCaptionRows(ServiceSetup, CaptionML);
        CaptionML.SetLoadFields("Language Code", "Option Caption ML", "Option Caption ML 2");
        if CaptionML.FindSet() then
            repeat
                ItemCount := this.CountItems(CaptionML."Option Caption ML" + CaptionML."Option Caption ML 2");
                if ItemCount > MaxCount then begin
                    MaxCount := ItemCount;
                    CaptionSource := StrSubstNo(this.CaptionRowLbl, CaptionML."Language Code");
                end;
            until CaptionML.Next() = 0;
        exit(MaxCount);
    end;

    local procedure HasEnglishCaptionRow(ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    var
        CaptionML: Record "MobileNAV CaptionML Admin.";
    begin
        this.FilterCaptionRows(ServiceSetup, CaptionML);
        CaptionML.SetRange("Language Code", this.EnglishTok);
        exit(not CaptionML.IsEmpty());
    end;

    local procedure FilterCaptionRows(ServiceSetup: Record "MobileNAV Service Setup"; var CaptionML: Record "MobileNAV CaptionML Admin.")
    begin
        CaptionML.SetRange("Page ID", this.PageObjectId(ServiceSetup."Service Name"));
        CaptionML.SetRange("Control ID", ServiceSetup.ControlID);
    end;

    local procedure PageObjectId(ServiceName: Text[100]): Integer
    var
        MainRow: Record "MobileNAV Service Setup";
    begin
        MainRow.SetRange("Service Name", ServiceName);
        MainRow.SetRange("Line Type", MainRow."Line Type"::Main);
        MainRow.SetLoadFields("Object ID");
        if MainRow.FindFirst() then
            exit(MainRow."Object ID");
        exit(0);
    end;

    /// <summary>The number of items the device gets when it splits the list on commas. An empty list has none.</summary>
    /// <param name="List">A comma separated list.</param>
    /// <returns>The number of items.</returns>
    procedure CountItems(List: Text): Integer
    begin
        if List = '' then
            exit(0);
        exit(StrLen(List) - StrLen(DelChr(List, '=', ',')) + 1);
    end;

    var
        MismatchMsg: Label 'Option field %2 on %1 has %3 captions (%4) and %5 values. The device stops the login with "Option captions don''t match to values".', Comment = '%1 = service name, %2 = field name, %3 = caption count, %4 = caption source, %5 = value count';
        FixMsg: Label 'Set AddOn-Converted Option String in MobileNAV Master Data, rebuild the option values and captions of %2 on %1 through MobileNAV''s Field No. validation, and rebuild every user''s configuration at the next login.', Comment = '%1 = service name, %2 = field name';
        WsdlSourceMsg: Label 'AddOn-Converted Option String is off in MobileNAV Master Data, so Refresh Page takes option values from the page''s web service description. That description leaves out values an enum extension adds to another app''s table, and the next refresh of such a field stops the login with "Option captions don''t match to values".';
        WsdlSourceFixMsg: Label 'Set AddOn-Converted Option String, so Refresh Page takes option values from the field''s option members.';
        NoGeneralSetupErr: Label 'MobileNAV Master Data has no general setup row.';
        NoFieldErr: Label 'Row %2 on %1 has no table field to read the options from.', Comment = '%1 = service name, %2 = field name';
        CaptionRowLbl: Label 'caption row %1', Comment = '%1 = language code';
        FieldCaptionsLbl: Label 'the field''s option captions';
        EnglishTok: Label 'ENU', Locked = true;
}

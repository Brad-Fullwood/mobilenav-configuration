namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does each declared control's service-level row say what the provider declared? Visibility,
/// editability, filter availability and importance are compared, and a button, link or scan
/// left at MobileNAV's Additional importance is a Blocker: that section is where buttons go to
/// be never found.
/// </summary>
codeunit 77795 "BJF Check Config Fields" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rm;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                TempLine.SetFilter(Operation, '%1|%2|%3|%4',
                    Enum::"BJF MN Config Operation"::Field, Enum::"BJF MN Config Operation"::"Function Field",
                    Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Scan Field");
                if TempLine.FindSet() then
                    repeat
                        this.CheckControl(Finding, TempProvider, TempLine);
                    until TempLine.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        FieldRow: Record "MobileNAV Service Setup";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        Kind: Text;
        Args: List of [Text];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.ImportanceFixTok then
            Error(this.NoAutomaticFixErr);
        if not this.Support.FindFieldRow(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100), FieldRow) then
            Error(this.RowGoneErr);
        FieldManagement.SetOptionField(FieldRow, FieldRow.FieldNo(Mandatory), Args.Get(3));
        FieldRow.Modify(true);
    end;

    local procedure CheckControl(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary)
    var
        FieldRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        LiveImportance: Text;
    begin
        ServiceName := this.Support.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit; // Reported by the services check.
        if not this.Support.FindFieldRow(ServiceName, Line."Control Name", FieldRow) then begin
            Finding.Add(Finding."Check Type"::"Config Fields", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.NoFieldRowMsg, Line."Control Name", ServiceName)));
            exit;
        end;

        if FieldRow.Visible <> Line.Visible then
            this.Mismatch(Finding, TempProvider, Line, ServiceName, FieldRow, this.VisibleTok, Format(Line.Visible), Format(FieldRow.Visible));
        if (Line.Operation <> Enum::"BJF MN Config Operation"::"Linked Field") and (FieldRow.Editable <> Line.Editable) then
            this.Mismatch(Finding, TempProvider, Line, ServiceName, FieldRow, this.EditableTok, Format(Line.Editable), Format(FieldRow.Editable));
        if (Line.Operation = Enum::"BJF MN Config Operation"::Field) and (FieldRow."Visible as Filter" <> Line.Filterable) then
            this.Mismatch(Finding, TempProvider, Line, ServiceName, FieldRow, this.FilterableTok, Format(Line.Filterable), Format(FieldRow."Visible as Filter"));

        LiveImportance := this.Support.OptionName(FieldRow, FieldRow.FieldNo(Mandatory));
        if UpperCase(LiveImportance) <> UpperCase(Line.Importance) then
            this.ImportanceFinding(Finding, TempProvider, Line, ServiceName, FieldRow, LiveImportance);
    end;

    local procedure Mismatch(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; FieldRow: Record "MobileNAV Service Setup"; Property: Text; Declared: Text; Live: Text)
    begin
        Finding.Add(Finding."Check Type"::"Config Fields", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.MismatchMsg, Line."Control Name", ServiceName, Property, Declared, Live)), FieldRow.RecordId());
    end;

    local procedure ImportanceFinding(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; FieldRow: Record "MobileNAV Service Setup"; LiveImportance: Text)
    var
        Severity: Enum "BJF Diagnostic Severity";
        Args: List of [Text];
        HidesButton: Boolean;
    begin
        HidesButton := (Line.Operation <> Enum::"BJF MN Config Operation"::Field) and (UpperCase(LiveImportance) = this.AdditionalTok);
        if HidesButton then
            Severity := Severity::Blocker
        else
            Severity := Severity::Warning;
        Args.Add(ServiceName);
        Args.Add(Line."Control Name");
        Args.Add(Line.Importance);
        Finding.AddWithFix(Finding."Check Type"::"Config Fields", Severity,
            this.Support.Prefix(TempProvider, StrSubstNo(this.ImportanceMsg, Line."Control Name", ServiceName, LiveImportance, Line.Importance)),
            FieldRow.RecordId(), StrSubstNo(this.ImportanceFixMsg, Line."Control Name", Line.Importance),
            this.Support.PackFix(this.ImportanceFixTok, Args));
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        NoFieldRowMsg: Label 'Control %1 is declared on %2 but MobileNAV has no field row for it. Apply the provider, or check the control name.', Comment = '%1 = control, %2 = service';
        MismatchMsg: Label 'Control %1 on %2: %3 is declared %4 but MobileNAV has %5. Apply the provider.', Comment = '%1 = control, %2 = service, %3 = property, %4 = declared, %5 = live';
        ImportanceMsg: Label 'Control %1 on %2 sits at importance %3 but is declared %4. At Additional a button is hidden behind the card''s "show more" section.', Comment = '%1 = control, %2 = service, %3 = live importance, %4 = declared importance';
        ImportanceFixMsg: Label 'Set importance of %1 to %2.', Comment = '%1 = control, %2 = importance';
        RowGoneErr: Label 'The MobileNAV field row this finding refers to no longer exists.';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        ImportanceFixTok: Label 'IMPORTANCE', Locked = true;
        AdditionalTok: Label 'ADDITIONAL', Locked = true;
        VisibleTok: Label 'Visible', Locked = true;
        EditableTok: Label 'Editable', Locked = true;
        FilterableTok: Label 'Filterable', Locked = true;
}

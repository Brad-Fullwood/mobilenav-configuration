namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The three MobileNAV page rules that silently undo a correct-looking configuration: a link's
/// relation row must exist and must not carry a lookup binding (RelatedPgCodeFldName) or it
/// renders as a lookup instead of a button; a per-user page needs its UserID mark and Own
/// filter; and a page with any editable control needs Page Update on or the whole card is
/// read-only.
/// </summary>
codeunit 77797 "BJF Check Config Page Rules" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rm;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.CheckProvider(Finding, TempProvider);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        Kind: Text;
        Args: List of [Text];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        case Kind of
            this.RelationFixTok:
                begin
                    if not ServiceSetup.Get(Finding."Related Record ID") then
                        Error(this.RowGoneErr);
                    // A relation with this field set is a lookup binding, not a button.
                    ServiceSetup.RelatedPgCodeFldName := '';
                    ServiceSetup.Modify(false);
                end;
            this.ScopeFixTok:
                FieldManagement.ConfigureUserScope(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100));
            this.PageUpdateFixTok:
                begin
                    if not this.Support.GetMainRow(CopyStr(Args.Get(1), 1, 100), ServiceSetup) then
                        Error(this.RowGoneErr);
                    ServiceSetup.Validate("Page Update", true);
                    ServiceSetup.Modify(true);
                end;
            else
                Error(this.NoAutomaticFixErr);
        end;
    end;

    local procedure CheckProvider(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary)
    var
        TempLine: Record "BJF MN Config Line" temporary;
        EditablePages: List of [Integer];
        PageId: Integer;
    begin
        this.Support.BuildDefinition(TempProvider.Provider, TempLine);
        if TempLine.FindSet() then
            repeat
                case TempLine.Operation of
                    Enum::"BJF MN Config Operation"::"Linked Field":
                        this.CheckRelation(Finding, TempProvider, TempLine);
                    Enum::"BJF MN Config Operation"::"User Scope":
                        this.CheckUserScope(Finding, TempProvider, TempLine);
                    Enum::"BJF MN Config Operation"::Field,
                    Enum::"BJF MN Config Operation"::"Function Field",
                    Enum::"BJF MN Config Operation"::"Scan Field":
                        if TempLine.Editable and not EditablePages.Contains(TempLine."Page ID") then
                            EditablePages.Add(TempLine."Page ID");
                end;
            until TempLine.Next() = 0;
        foreach PageId in EditablePages do
            this.CheckPageUpdate(Finding, TempProvider, PageId);
    end;

    local procedure CheckRelation(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary)
    var
        FieldRow: Record "MobileNAV Service Setup";
        RelationRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        Args: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        if not this.Support.FindFieldRow(ServiceName, Line."Control Name", FieldRow) then
            exit;
        RelationRow.SetRange("Object Type", FieldRow."Object Type");
        RelationRow.SetRange("Service Name", ServiceName);
        RelationRow.SetRange("Line Type", RelationRow."Line Type"::Relation);
        RelationRow.SetRange("Page Line No.", FieldRow."Page Line No.");
        RelationRow.SetRange("Relation No.", 1);
        if not RelationRow.FindFirst() then begin
            Finding.Add(Finding."Check Type"::"Config Page Rules", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.NoRelationMsg, Line."Control Name", ServiceName)), FieldRow.RecordId());
            exit;
        end;
        if RelationRow.RelatedPgCodeFldName <> '' then
            Finding.AddWithFix(Finding."Check Type"::"Config Page Rules", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.LookupBindingMsg, Line."Control Name", ServiceName, RelationRow.RelatedPgCodeFldName)),
                RelationRow.RecordId(), StrSubstNo(this.RelationFixMsg, Line."Control Name"),
                this.Support.PackFix(this.RelationFixTok, Args));
    end;

    local procedure CheckUserScope(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary)
    var
        FieldRow: Record "MobileNAV Service Setup";
        FilterRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        Args: List of [Text];
        Missing: Boolean;
    begin
        ServiceName := this.Support.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        if not this.Support.FindFieldRow(ServiceName, Line."Control Name", FieldRow) then
            exit;
        Missing := UpperCase(this.Support.OptionName(FieldRow, FieldRow.FieldNo(MobileType))) <> this.UserIdTok;
        if not Missing then begin
            FilterRow.SetRange("Service Name", ServiceName);
            FilterRow.SetRange("Line Type", FilterRow."Line Type"::Filter);
            FilterRow.SetRange("Page Line No.", 0);
            FilterRow.SetRange("Relation No.", 0);
            FilterRow.SetRange(SourceFieldName, FieldRow.FieldName);
            FilterRow.SetRange("Filter Comparsion Type", FilterRow."Filter Comparsion Type"::Own);
            Missing := FilterRow.IsEmpty();
        end;
        if not Missing then
            exit;
        Args.Add(ServiceName);
        Args.Add(Line."Control Name");
        Finding.AddWithFix(Finding."Check Type"::"Config Page Rules", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NoScopeMsg, ServiceName, Line."Control Name")),
            FieldRow.RecordId(), StrSubstNo(this.ScopeFixMsg, ServiceName),
            this.Support.PackFix(this.ScopeFixTok, Args));
    end;

    local procedure CheckPageUpdate(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; PageId: Integer)
    var
        MainRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        Args: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(PageId);
        if ServiceName = '' then
            exit;
        if not this.Support.GetMainRow(ServiceName, MainRow) then
            exit;
        if MainRow."Page Update" then
            exit;
        Args.Add(ServiceName);
        Finding.AddWithFix(Finding."Check Type"::"Config Page Rules", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.PageUpdateOffMsg, ServiceName)),
            MainRow.RecordId(), StrSubstNo(this.PageUpdateFixMsg, ServiceName),
            this.Support.PackFix(this.PageUpdateFixTok, Args));
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        NoRelationMsg: Label 'Link %1 on %2 has no relation row, so it opens nothing. Apply the provider.', Comment = '%1 = control, %2 = service';
        LookupBindingMsg: Label 'Link %1 on %2 carries a lookup binding (%3), so MobileNAV draws it as a lookup rather than a button.', Comment = '%1 = control, %2 = service, %3 = bound field';
        RelationFixMsg: Label 'Clear the lookup binding on link %1.', Comment = '%1 = control';
        NoScopeMsg: Label 'Page %1 is declared MineOnly over %2 but the user mark or the Own filter is missing, so every device sees every user''s rows.', Comment = '%1 = service, %2 = control';
        ScopeFixMsg: Label 'Write the user scope for %1.', Comment = '%1 = service';
        PageUpdateOffMsg: Label 'Page %1 has editable controls but Page Update is off, so the device draws the whole card read-only.', Comment = '%1 = service';
        PageUpdateFixMsg: Label 'Turn Page Update on for %1.', Comment = '%1 = service';
        RowGoneErr: Label 'The MobileNAV row this finding refers to no longer exists.';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        RelationFixTok: Label 'RELATION', Locked = true;
        ScopeFixTok: Label 'USERSCOPE', Locked = true;
        PageUpdateFixTok: Label 'PAGEUPDATE', Locked = true;
        UserIdTok: Label 'USERID', Locked = true;
}

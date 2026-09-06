namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Do a page's filters, flow filters, saved filters and offline operations exist as declared?
/// Each kind is compared with what "BJF MN Filter Mgt." would write and rewritten by the fix.
/// </summary>
codeunit 77701 "BJF Check Config Page Rows" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                this.CheckPageFilters(Finding, TempProvider, TempLine);
                this.CheckFlowFilters(Finding, TempProvider, TempLine);
                this.CheckSavedFilters(Finding, TempProvider, TempLine);
                this.CheckOperations(Finding, TempProvider, TempLine);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        PageId: Integer;
        ServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(PageId, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        case Kind of
            this.PageFiltersFixTok:
                this.FilterManagement.ApplyPageFilters(ServiceName, TempLine, PageId);
            this.FlowFilterFixTok:
                this.FilterManagement.ApplyFlowFilter(ServiceName, CopyStr(Args.Get(3), 1, 100));
            this.SavedFiltersFixTok:
                this.FilterManagement.ApplySavedFilters(ServiceName, TempLine, PageId);
            this.OperationsFixTok:
                this.FilterManagement.ApplyOperations(ServiceName, TempLine, PageId);
            else
                Error(this.NoAutomaticFixErr);
        end;
    end;

    local procedure CheckPageFilters(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        FilterRow: Record "MobileNAV Service Setup";
        Expected: List of [Text];
        PageId: Integer;
        ServiceName: Text[100];
    begin
        foreach PageId in this.PagesWith(TempLine, Enum::"BJF MN Config Operation"::"User Scope", Enum::"BJF MN Config Operation"::"Page Filter") do begin
            ServiceName := this.Lookup.GetServiceName(PageId);
            if ServiceName <> '' then begin
                Clear(Expected);
                TempLine.SetRange("Page ID", PageId);
                TempLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"User Scope", Enum::"BJF MN Config Operation"::"Page Filter");
                if TempLine.FindSet() then
                    repeat
                        Expected.Add(this.PageFilterSignature(TempLine));
                    until TempLine.Next() = 0;
                TempLine.Reset();
                this.FilterManagement.SetPageFilterRange(ServiceName, FilterRow);
                this.ReportRows(Finding, TempProvider, PageId, ServiceName, this.CompareRows(FilterRow, Expected, this.PageFiltersLbl), this.PageFiltersFixTok, '');
            end;
        end;
    end;

    local procedure CheckFlowFilters(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        ServiceName: Text[100];
    begin
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Flow Filter");
        if TempLine.FindSet() then
            repeat
                ServiceName := this.Lookup.GetServiceName(TempLine."Page ID");
                if ServiceName <> '' then
                    this.ReportRows(Finding, TempProvider, TempLine."Page ID", ServiceName, this.FlowFilterProblem(ServiceName, TempLine."Control Name"), this.FlowFilterFixTok, TempLine."Control Name");
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure FlowFilterProblem(ServiceName: Text[100]; FlowFilterFieldName: Text[100]): Text
    var
        FlowFilterRow: Record "MobileNAV Service Setup";
    begin
        if not this.FilterManagement.FindFlowFilterRow(ServiceName, FlowFilterFieldName, FlowFilterRow) then
            exit(StrSubstNo(this.NoFlowFilterLbl, FlowFilterFieldName));
        if not (FlowFilterRow.Visible and FlowFilterRow."Visible as Filter") then
            exit(StrSubstNo(this.HiddenFlowFilterLbl, FlowFilterFieldName));
        exit('');
    end;

    local procedure CheckSavedFilters(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        SavedFilterRow: Record "MobileNAV Service Setup";
        Expected: List of [Text];
        PageId: Integer;
        ServiceName: Text[100];
    begin
        foreach PageId in this.PagesWith(TempLine, Enum::"BJF MN Config Operation"::"Saved Filter", Enum::"BJF MN Config Operation"::"Saved Filter") do begin
            ServiceName := this.Lookup.GetServiceName(PageId);
            if ServiceName <> '' then begin
                Expected := this.ExpectedSavedFilters(TempLine, PageId);
                this.FilterManagement.SetSavedFilterRange(ServiceName, SavedFilterRow);
                this.ReportRows(Finding, TempProvider, PageId, ServiceName, this.CompareRows(SavedFilterRow, Expected, this.SavedFiltersLbl), this.SavedFiltersFixTok, '');
            end;
        end;
    end;

    local procedure CheckOperations(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        OperationRow: Record "MobileNAV Service Setup";
        Expected: List of [Text];
        PageId: Integer;
        ServiceName: Text[100];
    begin
        foreach PageId in this.PagesWith(TempLine, Enum::"BJF MN Config Operation"::Operation, Enum::"BJF MN Config Operation"::Operation) do begin
            ServiceName := this.Lookup.GetServiceName(PageId);
            if ServiceName <> '' then begin
                Clear(Expected);
                TempLine.SetRange("Page ID", PageId);
                TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Operation);
                if TempLine.FindSet() then
                    repeat
                        Expected.Add(this.OperationSignature(TempLine, ServiceName));
                    until TempLine.Next() = 0;
                TempLine.Reset();
                this.FilterManagement.SetOperationRange(ServiceName, OperationRow);
                OperationRow.SetCurrentKey("Service Name", "Page Line No.", "Relation No.", "Line Type", "Line No.");
                this.ReportRows(Finding, TempProvider, PageId, ServiceName, this.CompareRows(OperationRow, Expected, this.OperationsLbl), this.OperationsFixTok, '');
            end;
        end;
    end;

    /// <summary>Saved filters flatten to one signature per head followed by one per field, matching MobileNAV's key order.</summary>
    local procedure ExpectedSavedFilters(var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer) Expected: List of [Text]
    var
        TempFieldLine: Record "BJF MN Config Line" temporary;
    begin
        TempFieldLine.Copy(TempLine, true);
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Saved Filter");
        if TempLine.FindSet() then
            repeat
                Expected.Add(this.Join(TempLine."Control Name", Format(TempLine."Own Filter Set", 0, 9), UpperCase(TempLine."View Type")));
                TempFieldLine.Reset();
                TempFieldLine.SetRange("Page ID", PageId);
                TempFieldLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Saved Filter Field");
                TempFieldLine.SetRange("Control Name", TempLine."Control Name");
                if TempFieldLine.FindSet() then
                    repeat
                        Expected.Add(this.Join(this.Lookup.StoredFieldName(TempFieldLine."Target Filter Field"), UpperCase(TempFieldLine."Search Type"), TempFieldLine."Filter Value"));
                    until TempFieldLine.Next() = 0;
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure PageFilterSignature(FilterLine: Record "BJF MN Config Line" temporary): Text
    begin
        if FilterLine.Operation = Enum::"BJF MN Config Operation"::"User Scope" then
            exit(this.Join(this.Lookup.StoredFieldName(FilterLine."Control Name"), this.OwnTok, ''));
        exit(this.Join(this.Lookup.StoredFieldName(FilterLine."Control Name"), UpperCase(FilterLine."Filter Type") + this.SeparatorTok + UpperCase(FilterLine.Comparison) + this.SeparatorTok + UpperCase(FilterLine."Filter Scope"), FilterLine."Filter Value"));
    end;

    local procedure OperationSignature(OperationLine: Record "BJF MN Config Line" temporary; ServiceName: Text[100]): Text
    var
        FieldRow: Record "MobileNAV Service Setup";
        PageLineNo: Integer;
        Target: Text;
    begin
        if (OperationLine."Control Name" <> '') and this.Lookup.FindFieldRow(ServiceName, OperationLine."Control Name", FieldRow) then
            PageLineNo := FieldRow."Page Line No.";
        if UpperCase(OperationLine."Filter Type") = this.FieldTypeTok then
            Target := this.Lookup.StoredFieldName(OperationLine."Target Filter Field")
        else
            Target := OperationLine."Filter Value";
        exit(this.Join(Format(PageLineNo, 0, 9) + this.SeparatorTok + UpperCase(OperationLine."Operation Type"), this.Lookup.StoredFieldName(OperationLine."Source Field") + this.SeparatorTok + UpperCase(OperationLine."Filter Type"), Target));
    end;

    local procedure RowSignature(Row: Record "MobileNAV Service Setup"): Text
    var
        Target: Text;
    begin
        case Row."Line Type" of
            Row."Line Type"::Filter:
                begin
                    if Row."Filter Comparsion Type" = Row."Filter Comparsion Type"::Own then
                        exit(this.Join(Row.SourceFieldName, this.OwnTok, ''));
                    exit(this.Join(Row.SourceFieldName, UpperCase(this.Lookup.OptionName(Row, Row.FieldNo(FilterType))) + this.SeparatorTok + UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Filter Comparsion Type"))) + this.SeparatorTok + UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Filter Scope"))), Row.FilterValue));
                end;
            Row."Line Type"::SavedFilter:
                begin
                    if Row."Line No." = 0 then
                        exit(this.Join(Row.Name, Format(Row."Own Filter Set", 0, 9), UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("View Type")))));
                    exit(this.Join(Row.FieldName, UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Search Type"))), Row.FilterValue));
                end;
            Row."Line Type"::Operation:
                begin
                    if Row.FilterType = Row.FilterType::FIELD then
                        Target := Row.DestFieldName
                    else
                        Target := Row.FilterValue;
                    exit(this.Join(Format(Row."Page Line No.", 0, 9) + this.SeparatorTok + UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Operation Type"))), Row.SourceFieldName + this.SeparatorTok + UpperCase(this.Lookup.OptionName(Row, Row.FieldNo(FilterType))), Target));
                end;
        end;
        exit('');
    end;

    local procedure CompareRows(var Row: Record "MobileNAV Service Setup"; Expected: List of [Text]; KindName: Text): Text
    var
        Index: Integer;
    begin
        if Row.Count() <> Expected.Count() then
            exit(StrSubstNo(this.CountLbl, KindName, Expected.Count(), Row.Count()));
        if Row.FindSet() then
            repeat
                Index += 1;
                if this.RowSignature(Row) <> Expected.Get(Index) then
                    exit(StrSubstNo(this.RowLbl, KindName, Index));
            until Row.Next() = 0;
        exit('');
    end;

    local procedure ReportRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; PageId: Integer; ServiceName: Text[100]; Problem: Text; FixKind: Text; Extra: Text)
    var
        MainRow: Record "MobileNAV Service Setup";
        Args: List of [Text];
    begin
        if Problem = '' then
            exit;
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(PageId, 0, 9));
        if Extra <> '' then
            Args.Add(Extra);
        if this.Lookup.FindMainRow(ServiceName, MainRow) then;
        Finding.AddWithFix(Finding."Check Type"::"Config Page Rows", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.PageRowsMsg, ServiceName, Problem)),
            MainRow.RecordId(), StrSubstNo(this.FixMsg, ServiceName),
            this.Support.PackFix(FixKind, Args));
    end;

    local procedure PagesWith(var TempLine: Record "BJF MN Config Line" temporary; FirstOperation: Enum "BJF MN Config Operation"; SecondOperation: Enum "BJF MN Config Operation") PageIds: List of [Integer]
    begin
        TempLine.Reset();
        TempLine.SetFilter(Operation, '%1|%2', FirstOperation, SecondOperation);
        if TempLine.FindSet() then
            repeat
                if not PageIds.Contains(TempLine."Page ID") then
                    PageIds.Add(TempLine."Page ID");
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure Join(First: Text; Second: Text; Third: Text): Text
    begin
        exit(First + this.SeparatorTok + Second + this.SeparatorTok + Third);
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        FilterManagement: Codeunit "BJF MN Filter Mgt.";
        PageRowsMsg: Label 'Page %1 does not match MobileNAV: %2', Comment = '%1 = service name, %2 = what differs';
        FixMsg: Label 'Rewrite the rows of %1 from the declaration.', Comment = '%1 = service name';
        CountLbl: Label '%1: %2 declared, %3 found.', Comment = '%1 = row kind, %2 = declared count, %3 = live count';
        RowLbl: Label '%1: row %2 differs.', Comment = '%1 = row kind, %2 = row position';
        NoFlowFilterLbl: Label 'flow filter %1 has no field row.', Comment = '%1 = flow filter field name';
        HiddenFlowFilterLbl: Label 'flow filter %1 is not visible as a filter.', Comment = '%1 = flow filter field name';
        PageFiltersLbl: Label 'page filters';
        SavedFiltersLbl: Label 'saved filters';
        OperationsLbl: Label 'operations';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        PageFiltersFixTok: Label 'PAGEFILTERS', Locked = true;
        FlowFilterFixTok: Label 'FLOWFILTER', Locked = true;
        SavedFiltersFixTok: Label 'SAVEDFILTERS', Locked = true;
        OperationsFixTok: Label 'OPERATIONS', Locked = true;
        FieldTypeTok: Label 'FIELD', Locked = true;
        OwnTok: Label 'OWN', Locked = true;
        SeparatorTok: Label '|', Locked = true;
}

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
        PageId: Integer;
        ServiceName: Text[100];
    begin
        this.Support.ReadProviderFix(Finding, '', Kind, Args, TempLine);
        Evaluate(PageId, Args.Get(1));
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        case Kind of
            this.PageFiltersFixTok:
                this.FilterManagement.ApplyPageFilters(ServiceName, TempLine, PageId);
            this.FlowFilterFixTok:
                this.FilterManagement.ApplyFlowFilter(ServiceName, CopyStr(Args.Get(2), 1, 100));
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
        MainRow: Record "MobileNAV Service Setup";
        FilterRow: Record "MobileNAV Service Setup";
        TempDeclaredRow: Record "MobileNAV Service Setup" temporary;
        PageId: Integer;
        ServiceName: Text[100];
        Problem: Text;
    begin
        foreach PageId in TempLine.PageIdsWith(Enum::"BJF MN Config Operation"::"User Scope", Enum::"BJF MN Config Operation"::"Page Filter") do begin
            ServiceName := this.Support.GetServiceName(PageId);
            if (ServiceName <> '') and this.Lookup.FindMainRow(ServiceName, MainRow) then begin
                TempDeclaredRow.Reset();
                TempDeclaredRow.DeleteAll(false);
                if this.TryBuildPageFilters(MainRow, TempLine, PageId, TempDeclaredRow) then begin
                    this.FilterManagement.SetPageFilterRange(ServiceName, TempDeclaredRow);
                    this.FilterManagement.SetPageFilterRange(ServiceName, FilterRow);
                    Problem := this.CompareRows(TempDeclaredRow, FilterRow, this.PageFiltersLbl);
                end else
                    Problem := GetLastErrorText();
                TempLine.Reset();
                this.ReportRows(Finding, TempProvider, PageId, ServiceName, Problem, this.PageFiltersFixTok, '');
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
                ServiceName := this.Support.GetServiceName(TempLine."Page ID");
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
        TempDeclaredRow: Record "MobileNAV Service Setup" temporary;
        PageId: Integer;
        ServiceName: Text[100];
        Problem: Text;
    begin
        foreach PageId in TempLine.PageIdsWith(Enum::"BJF MN Config Operation"::"Saved Filter") do begin
            ServiceName := this.Support.GetServiceName(PageId);
            if ServiceName <> '' then begin
                TempDeclaredRow.Reset();
                TempDeclaredRow.DeleteAll(false);
                if this.TryBuildSavedFilters(ServiceName, TempLine, PageId, TempDeclaredRow) then begin
                    this.FilterManagement.SetSavedFilterRange(ServiceName, TempDeclaredRow);
                    this.FilterManagement.SetSavedFilterRange(ServiceName, SavedFilterRow);
                    Problem := this.CompareRows(TempDeclaredRow, SavedFilterRow, this.SavedFiltersLbl);
                end else
                    Problem := GetLastErrorText();
                TempLine.Reset();
                this.ReportRows(Finding, TempProvider, PageId, ServiceName, Problem, this.SavedFiltersFixTok, '');
            end;
        end;
    end;

    local procedure CheckOperations(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        MainRow: Record "MobileNAV Service Setup";
        OperationRow: Record "MobileNAV Service Setup";
        TempDeclaredRow: Record "MobileNAV Service Setup" temporary;
        PageId: Integer;
        ServiceName: Text[100];
        Problem: Text;
    begin
        foreach PageId in TempLine.PageIdsWith(Enum::"BJF MN Config Operation"::Operation) do begin
            ServiceName := this.Support.GetServiceName(PageId);
            if (ServiceName <> '') and this.Lookup.FindMainRow(ServiceName, MainRow) then begin
                TempDeclaredRow.Reset();
                TempDeclaredRow.DeleteAll(false);
                if this.TryBuildOperations(MainRow, TempLine, PageId, TempDeclaredRow) then begin
                    this.FilterManagement.SetOperationRange(ServiceName, TempDeclaredRow);
                    this.FilterManagement.SetOperationRange(ServiceName, OperationRow);
                    Problem := this.CompareRows(TempDeclaredRow, OperationRow, this.OperationsLbl);
                end else
                    Problem := GetLastErrorText();
                TempLine.Reset();
                this.ReportRows(Finding, TempProvider, PageId, ServiceName, Problem, this.OperationsFixTok, '');
            end;
        end;
    end;

    [TryFunction]
    local procedure TryBuildPageFilters(MainRow: Record "MobileNAV Service Setup"; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; var FilterRow: Record "MobileNAV Service Setup")
    begin
        this.FilterManagement.BuildPageFilters(MainRow, TempLine, PageId, FilterRow);
    end;

    [TryFunction]
    local procedure TryBuildSavedFilters(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; var SavedFilterRow: Record "MobileNAV Service Setup")
    begin
        this.FilterManagement.BuildSavedFilters(ServiceName, TempLine, PageId, SavedFilterRow);
    end;

    [TryFunction]
    local procedure TryBuildOperations(MainRow: Record "MobileNAV Service Setup"; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; var OperationRow: Record "MobileNAV Service Setup")
    begin
        this.FilterManagement.BuildOperations(MainRow, TempLine, PageId, OperationRow);
    end;

    local procedure Signatures(var Rows: Record "MobileNAV Service Setup"): List of [Text]
    var
        Signature: List of [Text];
    begin
        if Rows.FindSet() then
            repeat
                Signature.Add(this.RowSignature(Rows));
            until Rows.Next() = 0;
        exit(Signature);
    end;

    local procedure RowSignature(Row: Record "MobileNAV Service Setup"): Text
    var
        Target: Text;
    begin
        case Row."Line Type" of
            Row."Line Type"::Filter:
                begin
                    if Row."Filter Comparsion Type" = Row."Filter Comparsion Type"::Own then
                        exit(this.Support.Signature(Row.SourceFieldName, this.OwnTok, ''));
                    exit(this.Support.Signature(Row.SourceFieldName, UpperCase(this.Lookup.OptionName(Row, Row.FieldNo(FilterType))), UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Filter Comparsion Type"))), UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Filter Scope"))), Row.FilterValue));
                end;
            Row."Line Type"::SavedFilter:
                begin
                    if Row."Line No." = 0 then
                        exit(this.Support.Signature(Row.Name, Format(Row."Own Filter Set", 0, 9), UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("View Type")))));
                    exit(this.Support.Signature(Row.FieldName, UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Search Type"))), Row.FilterValue));
                end;
            Row."Line Type"::Operation:
                begin
                    if Row.FilterType = Row.FilterType::FIELD then
                        Target := Row.DestFieldName
                    else
                        Target := Row.FilterValue;
                    exit(this.Support.Signature(Format(Row."Page Line No.", 0, 9), UpperCase(this.Lookup.OptionName(Row, Row.FieldNo("Operation Type"))), Row.SourceFieldName, UpperCase(this.Lookup.OptionName(Row, Row.FieldNo(FilterType))), Target));
                end;
        end;
        exit('');
    end;

    local procedure CompareRows(var DeclaredRows: Record "MobileNAV Service Setup"; var LiveRows: Record "MobileNAV Service Setup"; KindName: Text): Text
    begin
        exit(this.Support.FirstDifference(KindName, this.Signatures(DeclaredRows), this.Signatures(LiveRows)));
    end;

    local procedure ReportRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; PageId: Integer; ServiceName: Text[100]; Problem: Text; FixKind: Text; Extra: Text)
    var
        Args: List of [Text];
    begin
        if Problem = '' then
            exit;
        Args.Add(Format(PageId, 0, 9));
        if Extra <> '' then
            Args.Add(Extra);
        this.Support.AddProviderFinding(Finding, Finding."Check Type"::"Config Page Rows", Finding.Severity::Blocker, TempProvider,
            StrSubstNo(this.PageRowsMsg, ServiceName, Problem), this.Support.MainRowId(ServiceName), StrSubstNo(this.FixMsg, ServiceName),
            FixKind, Args);
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        FilterManagement: Codeunit "BJF MN Filter Mgt.";
        PageRowsMsg: Label 'Page %1 does not match MobileNAV: %2', Comment = '%1 = service name, %2 = what differs';
        FixMsg: Label 'Rewrite the rows of %1 from the declaration.', Comment = '%1 = service name';
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
        OwnTok: Label 'OWN', Locked = true;
}

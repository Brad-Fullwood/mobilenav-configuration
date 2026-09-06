namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// The rows that hang off a page or its fields other than relations: page-level filters (with
/// MineOnly's Own filter among them), visible flow filters, saved filters and offline
/// operations. Each kind is rebuilt from the definition on every apply and written the way
/// MobileNAV's own import writes it.
/// </summary>
codeunit 77765 "BJF MN Filter Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rimd;

    /// <summary>Rewrites the page-level filter rows from the page's User Scope and Page Filter lines.</summary>
    procedure ApplyPageFilters(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        MainRow: Record "MobileNAV Service Setup";
        FilterRow: Record "MobileNAV Service Setup";
        LineNo: Integer;
    begin
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            Error(this.ServiceMissingErr, ServiceName);
        this.SetPageFilterRange(ServiceName, FilterRow);
        FilterRow.DeleteAll(false);

        TempLine.Reset();
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"User Scope", Enum::"BJF MN Config Operation"::"Page Filter");
        if TempLine.FindSet() then
            repeat
                LineNo += 10000;
                this.InsertPageFilter(MainRow, TempLine, LineNo);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    procedure SetPageFilterRange(ServiceName: Text[100]; var FilterRow: Record "MobileNAV Service Setup")
    begin
        FilterRow.Reset();
        FilterRow.SetRange("Service Name", ServiceName);
        FilterRow.SetRange("Line Type", FilterRow."Line Type"::Filter);
        FilterRow.SetRange("Page Line No.", 0);
        FilterRow.SetRange("Relation No.", 0);
    end;

    /// <summary>Makes one of the source table's flow filters a visible filter of the page, creating its field row when needed.</summary>
    procedure ApplyFlowFilter(ServiceName: Text[100]; FlowFilterFieldName: Text[100])
    var
        MainRow: Record "MobileNAV Service Setup";
        FlowFilterRow: Record "MobileNAV Service Setup";
        TableField: Record Field;
    begin
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            Error(this.ServiceMissingErr, ServiceName);
        TableField.SetRange(TableNo, MainRow."Table No.");
        TableField.SetRange(Class, TableField.Class::FlowFilter);
        TableField.SetRange(FieldName, FlowFilterFieldName);
        if not TableField.FindFirst() then
            Error(this.FlowFilterMissingErr, FlowFilterFieldName, MainRow."Table No.", ServiceName);

        if this.FindFlowFilterRow(ServiceName, FlowFilterFieldName, FlowFilterRow) then begin
            if FlowFilterRow."Visible as Filter" and FlowFilterRow.Visible then
                exit;
#pragma warning disable PC0037
            FlowFilterRow.Visible := true;
            FlowFilterRow."Visible as Filter" := true;
#pragma warning restore PC0037
            FlowFilterRow.Modify(false);
            exit;
        end;

        FlowFilterRow.Init();
        FlowFilterRow.Validate("Service Name", ServiceName);
        FlowFilterRow.Validate("Line Type", FlowFilterRow."Line Type"::Field);
        FlowFilterRow.Validate("Page Line No.", this.LastPageLineNo(ServiceName) + 10000);
        FlowFilterRow.Validate("Relation No.", 0);
        FlowFilterRow.Validate("Line No.", 0);
#pragma warning disable PC0037
        FlowFilterRow."Object Type" := MainRow."Object Type";
        FlowFilterRow."Object ID" := MainRow."Object ID";
        FlowFilterRow."Table No." := TableField.TableNo;
        FlowFilterRow."Field No." := TableField."No.";
        FlowFilterRow.FieldClass := FlowFilterRow.FieldClass::FlowFilter;
        FlowFilterRow.Order := this.LastOrder(ServiceName) + 1;
        FlowFilterRow.Visible := true;
        FlowFilterRow."Visible as Filter" := true;
#pragma warning restore PC0037
        FlowFilterRow.Validate(ControlID, this.LastControlId(ServiceName) + 1);
        FlowFilterRow.Validate(FieldName, this.Lookup.StoredFieldName(FlowFilterFieldName));
        FlowFilterRow.ValidateFieldNo(TableField.TableNo, TableField."No.", false, true);
        FlowFilterRow.Insert(true);
    end;

    procedure FindFlowFilterRow(ServiceName: Text[100]; FlowFilterFieldName: Text[100]; var FlowFilterRow: Record "MobileNAV Service Setup"): Boolean
    begin
        if not this.Lookup.FindFieldRow(ServiceName, FlowFilterFieldName, FlowFilterRow) then
            exit(false);
        exit(FlowFilterRow.FieldClass = FlowFilterRow.FieldClass::FlowFilter);
    end;

    /// <summary>Rewrites the page's saved filters from its Saved Filter lines, numbered from 1 as MobileNAV numbers them.</summary>
    procedure ApplySavedFilters(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        HeadRow: Record "MobileNAV Service Setup";
        FilterIndex: Integer;
    begin
        this.SetSavedFilterRange(ServiceName, HeadRow);
        HeadRow.DeleteAll(false);

        TempLine.Reset();
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Saved Filter");
        if TempLine.FindSet() then
            repeat
                FilterIndex += 1;
                this.InsertSavedFilter(ServiceName, TempLine, FilterIndex);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    procedure SetSavedFilterRange(ServiceName: Text[100]; var SavedFilterRow: Record "MobileNAV Service Setup")
    begin
        SavedFilterRow.Reset();
        SavedFilterRow.SetRange("Service Name", ServiceName);
        SavedFilterRow.SetRange("Line Type", SavedFilterRow."Line Type"::SavedFilter);
    end;

    /// <summary>Rewrites the page-level and field-level operations from the page's Operation lines.</summary>
    procedure ApplyOperations(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        MainRow: Record "MobileNAV Service Setup";
        OperationRow: Record "MobileNAV Service Setup";
        LineNos: Dictionary of [Integer, Integer];
    begin
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            Error(this.ServiceMissingErr, ServiceName);
        this.SetOperationRange(ServiceName, OperationRow);
        OperationRow.DeleteAll(false);

        TempLine.Reset();
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Operation);
        if TempLine.FindSet() then
            repeat
                this.InsertOperation(MainRow, TempLine, LineNos);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    procedure SetOperationRange(ServiceName: Text[100]; var OperationRow: Record "MobileNAV Service Setup")
    begin
        OperationRow.Reset();
        OperationRow.SetRange("Service Name", ServiceName);
        OperationRow.SetRange("Line Type", OperationRow."Line Type"::Operation);
        OperationRow.SetRange("Relation No.", 0);
    end;

    local procedure InsertPageFilter(MainRow: Record "MobileNAV Service Setup"; FilterLine: Record "BJF MN Config Line" temporary; LineNo: Integer)
    var
        FilterRow: Record "MobileNAV Service Setup";
    begin
        FilterRow.Init();
        FilterRow.Validate("Object Type", MainRow."Object Type");
        FilterRow.Validate("Service Name", MainRow."Service Name");
        FilterRow.Validate("Line Type", FilterRow."Line Type"::Filter);
        FilterRow.Validate("Page Line No.", 0);
        FilterRow.Validate("Relation No.", 0);
        FilterRow.Validate("Line No.", LineNo);
#pragma warning disable PC0037
        FilterRow."Object ID" := MainRow."Object ID";
        FilterRow.RelatedPageName := MainRow.RelatedPageName;
        FilterRow."Related Table No." := MainRow."Table No.";
        FilterRow.SourceFieldName := this.Lookup.StoredFieldName(FilterLine."Control Name");
        FilterRow.DestFieldName := '';
        FilterRow.FilterValue := FilterLine."Filter Value";
#pragma warning restore PC0037
        if FilterLine.Operation = Enum::"BJF MN Config Operation"::"User Scope" then begin
#pragma warning disable PC0037
            FilterRow.FilterType := FilterRow.FilterType::FIELD;
            FilterRow."Filter Comparsion Type" := FilterRow."Filter Comparsion Type"::Own;
            FilterRow.DestFieldName := FilterRow.SourceFieldName;
            FilterRow.FilterValue := '';
#pragma warning restore PC0037
        end else begin
            this.Lookup.SetOptionField(FilterRow, FilterRow.FieldNo(FilterType), FilterLine."Filter Type");
            this.Lookup.SetOptionField(FilterRow, FilterRow.FieldNo("Filter Comparsion Type"), FilterLine.Comparison);
            this.Lookup.SetOptionField(FilterRow, FilterRow.FieldNo("Filter Scope"), FilterLine."Filter Scope");
        end;
        FilterRow.Insert(false);
    end;

    local procedure InsertSavedFilter(ServiceName: Text[100]; var HeadLine: Record "BJF MN Config Line" temporary; FilterIndex: Integer)
    var
        TempFieldLine: Record "BJF MN Config Line" temporary;
        HeadRow: Record "MobileNAV Service Setup";
        FieldRow: Record "MobileNAV Service Setup";
        FieldIndex: Integer;
    begin
        HeadRow.Init();
        HeadRow.Validate("Service Name", ServiceName);
        HeadRow.Validate("Line Type", HeadRow."Line Type"::SavedFilter);
        HeadRow.Validate("Page Line No.", FilterIndex);
        HeadRow.Validate("Relation No.", 0);
        HeadRow.Validate("Line No.", 0);
#pragma warning disable PC0037
        HeadRow.Name := CopyStr(HeadLine."Control Name", 1, MaxStrLen(HeadRow.Name));
        HeadRow."Own Filter Set" := HeadLine."Own Filter Set";
#pragma warning restore PC0037
        this.Lookup.SetOptionField(HeadRow, HeadRow.FieldNo("View Type"), HeadLine."View Type");
        HeadRow.Insert(false);

        TempFieldLine.Copy(HeadLine, true);
        TempFieldLine.Reset();
        TempFieldLine.SetRange("Page ID", HeadLine."Page ID");
        TempFieldLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Saved Filter Field");
        TempFieldLine.SetRange("Control Name", HeadLine."Control Name");
        if TempFieldLine.FindSet() then
            repeat
                FieldIndex += 1;
                FieldRow := HeadRow;
                FieldRow.Init();
                FieldRow.Validate("Line No.", FieldIndex);
#pragma warning disable PC0037
                FieldRow.FieldName := CopyStr(this.Lookup.StoredFieldName(TempFieldLine."Target Filter Field"), 1, MaxStrLen(FieldRow.FieldName));
                FieldRow.FilterValue := TempFieldLine."Filter Value";
#pragma warning restore PC0037
                this.Lookup.SetOptionField(FieldRow, FieldRow.FieldNo("Search Type"), TempFieldLine."Search Type");
                FieldRow.Insert(false);
            until TempFieldLine.Next() = 0;
    end;

    local procedure InsertOperation(MainRow: Record "MobileNAV Service Setup"; OperationLine: Record "BJF MN Config Line" temporary; var LineNos: Dictionary of [Integer, Integer])
    var
        FieldRow: Record "MobileNAV Service Setup";
        OperationRow: Record "MobileNAV Service Setup";
        PageLineNo: Integer;
        LineNo: Integer;
    begin
        if OperationLine."Control Name" <> '' then begin
            if not this.Lookup.FindFieldRow(MainRow."Service Name", OperationLine."Control Name", FieldRow) then
                Error(this.ControlMissingErr, OperationLine."Control Name", MainRow."Service Name");
            PageLineNo := FieldRow."Page Line No.";
        end;
        if LineNos.Get(PageLineNo, LineNo) then;
        LineNo += 10000;
        LineNos.Set(PageLineNo, LineNo);

        OperationRow.Init();
        OperationRow.Validate("Object Type", MainRow."Object Type");
        OperationRow.Validate("Service Name", MainRow."Service Name");
        OperationRow.Validate("Line Type", OperationRow."Line Type"::Operation);
        OperationRow.Validate("Page Line No.", PageLineNo);
        OperationRow.Validate("Relation No.", 0);
        OperationRow.Validate("Line No.", LineNo);
#pragma warning disable PC0037
        OperationRow."Object ID" := MainRow."Object ID";
        OperationRow.RelatedPageName := CopyStr(MainRow."Service Name", 1, MaxStrLen(OperationRow.RelatedPageName));
        OperationRow."Related Table No." := MainRow."Table No.";
        OperationRow.ControlID := FieldRow.ControlID;
        OperationRow.FieldName := FieldRow.FieldName;
        OperationRow.SourceFieldName := this.Lookup.StoredFieldName(OperationLine."Source Field");
        if OperationLine."Filter Type" = this.FieldTypeTok then
            OperationRow.DestFieldName := this.Lookup.StoredFieldName(OperationLine."Target Filter Field")
        else
            OperationRow.FilterValue := OperationLine."Filter Value";
#pragma warning restore PC0037
        this.Lookup.SetOptionField(OperationRow, OperationRow.FieldNo("Operation Type"), OperationLine."Operation Type");
        this.Lookup.SetOptionField(OperationRow, OperationRow.FieldNo(FilterType), OperationLine."Filter Type");
        OperationRow.Insert(false);
    end;

    local procedure LastPageLineNo(ServiceName: Text[100]): Integer
    var
        FieldRow: Record "MobileNAV Service Setup";
    begin
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        if FieldRow.FindLast() then
            exit(FieldRow."Page Line No.");
        exit(0);
    end;

    local procedure LastOrder(ServiceName: Text[100]): Integer
    var
        FieldRow: Record "MobileNAV Service Setup";
    begin
        FieldRow.SetCurrentKey("Service Name", "Line Type", "Page Line No.", "Relation No.", "Line No.");
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        FieldRow.SetCurrentKey(Order);
        if FieldRow.FindLast() then
            exit(FieldRow.Order);
        exit(0);
    end;

    local procedure LastControlId(ServiceName: Text[100]): Integer
    var
        FieldRow: Record "MobileNAV Service Setup";
        LastId: Integer;
    begin
        LastId := 0;
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        if FieldRow.FindSet() then
            repeat
                if FieldRow.ControlID > LastId then
                    LastId := FieldRow.ControlID;
            until FieldRow.Next() = 0;
        exit(LastId);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        FieldTypeTok: Label 'FIELD', Locked = true;
        ServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = service name';
        ControlMissingErr: Label 'Control %1 was not found on MobileNAV service %2.', Comment = '%1 = control name, %2 = service name';
        FlowFilterMissingErr: Label 'Table %2 behind MobileNAV service %3 has no flow filter named %1.', Comment = '%1 = field name, %2 = table no., %3 = service name';
}

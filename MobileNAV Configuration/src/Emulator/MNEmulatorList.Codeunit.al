namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// Answers the list request of the device emulator. It reads one page's source table with the
/// sort, the predefined and flow filters, the parent relation, the saved filter, the filter panel
/// and the search that the device applies, then returns one page of rows. Nothing is written.
/// </summary>
codeunit 77726 "BJF MN Emulator List"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV FlowFilters" = r,
        tabledata "MobileNAV User Key Selection" = r;

    var
        EmuConfig: Codeunit "BJF MN Emulator Config";
        EmuRecords: Codeunit "BJF MN Emulator Records";
        ServiceRequiredErr: Label 'The list request has no service.';
        ServiceNotFoundErr: Label 'The service %1 is not in the loaded configuration.', Comment = '%1 = the Service Name';
        ParentPositionErr: Label 'The parent record of the service %1 has no position, or the record is gone.', Comment = '%1 = the parent Service Name';
        RelationMissingErr: Label 'The service %1 has no relation from the field %2 to the service %3.', Comment = '%1 = the parent Service Name, %2 = the parent field, %3 = the child Service Name';
        ParentFieldMissingErr: Label 'The parent field %1 is not on the parent page.', Comment = '%1 = the parent field name';
        FilterFieldMissingErr: Label 'The filter field %1 is not on the page.', Comment = '%1 = the field name';
        SavedFilterMissingErr: Label 'The saved filter %1 is not in the configuration.', Comment = '%1 = the saved filter name';

    /// <summary>
    /// Answers one list request. The caller loads the configuration first, see "BJF MN Emulator Config".
    /// </summary>
    /// <param name="Request">The request object with kind list, see emu-design.md.</param>
    /// <returns>The list response object.</returns>
    procedure ListJson(Request: JsonObject): JsonObject
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        TempRows: Record "MobileNAV Settings Buffer" temporary;
        TempFieldRows: Record "MobileNAV Settings Buffer" temporary;
        EmuLayouts: Codeunit "BJF MN Emulator Layouts";
        SourceRef: RecordRef;
        KeyIndexes: List of [Integer];
        KeyCaptions: List of [Text];
        CellFormats: array [1000] of Text[1024];
        RowArray: JsonArray;
        Response: JsonObject;
        ServiceName: Text;
        KeyNo: Integer;
        ChosenKey: Integer;
        Ascending: Boolean;
        SkipCount: Integer;
        PageSize: Integer;
        DefaultPageSize: Integer;
        HasMore: Boolean;
    begin
        ServiceName := this.TextValue(Request, 'service', '');
        if ServiceName = '' then
            Error(this.ServiceRequiredErr);
        if not this.EmuConfig.FindMain(ServiceName, TempMain) then
            Error(this.ServiceNotFoundErr, ServiceName);
        TempMain.ParseListCellFormatsXml(CellFormats);
        this.EmuConfig.CopyRows(ServiceName, TempRows);
        this.EmuConfig.CopyRows(ServiceName, TempFieldRows);
        this.EmuRecords.OpenSource(TempMain, SourceRef);

        this.CollectKeys(SourceRef.Number(), KeyIndexes, KeyCaptions);
        KeyNo := this.ChooseKey(Request, TempMain, Ascending);
        ChosenKey := this.ApplyKey(KeyNo, Ascending, KeyIndexes, SourceRef);

        this.ApplyPredefinedFilters(TempRows, TempFieldRows, SourceRef);
        this.ApplyFlowFilters(this.EmuConfig.LoadedUserId(), ServiceName, SourceRef);
        this.ApplyParent(Request, ServiceName, TempFieldRows, SourceRef);
        this.ApplySavedFilter(this.TextValue(Request, 'savedFilter', ''), TempRows, TempFieldRows, SourceRef);
        this.ApplyFilterPanel(Request, TempFieldRows, SourceRef);
        this.ApplySearch(this.TextValue(Request, 'search', ''), TempRows, SourceRef);

        DefaultPageSize := 50;
        if TempMain."List Display Limit" > 0 then
            DefaultPageSize := TempMain."List Display Limit";
        PageSize := this.IntValue(Request, 'top', DefaultPageSize);
        if PageSize < 1 then
            PageSize := DefaultPageSize;
        if PageSize > 200 then
            PageSize := 200;
        SkipCount := this.IntValue(Request, 'skip', 0);
        if SkipCount < 0 then
            SkipCount := 0;
        HasMore := this.AddRows(TempMain, TempFieldRows, SourceRef, EmuLayouts, SkipCount, PageSize, CellFormats, RowArray);

        Response.Add('kind', 'list');
        Response.Add('service', ServiceName);
        Response.Add('caption', this.ServiceCaption(TempMain));
        Response.Add('pageType', Format(TempMain."Page Type"));
        Response.Add('insertAllowed', TempMain."Page Insert");
        Response.Add('cardService', this.CardService(TempMain, ServiceName));
        Response.Add('rows', RowArray);
        Response.Add('hasMore', HasMore);
        Response.Add('skip', SkipCount);
        Response.Add('top', PageSize);
        Response.Add('filterFields', this.FilterFields(TempRows));
        Response.Add('savedFilters', this.SavedFilterNames(TempRows));
        Response.Add('keys', this.KeysJson(KeyCaptions));
        Response.Add('sortKey', ChosenKey);
        Response.Add('ascending', Ascending);
        Response.Add('appliedFilters', SourceRef.GetFilters());
        exit(Response);
    end;

    /// <summary>
    /// Lists the enabled, not removed keys of a table in the order MobileNAV's Key page numbers them.
    /// The position in the list is the key number that the user selection and the device use.
    /// </summary>
    /// <param name="ObjectTableNo">The table ID of the source table.</param>
    /// <param name="KeyIndexes">Receives the physical key index of each key, in number order.</param>
    /// <param name="KeyCaptions">Receives the key text of each key, in number order.</param>
    procedure CollectKeys(ObjectTableNo: Integer; var KeyIndexes: List of [Integer]; var KeyCaptions: List of [Text])
    var
        RealKey: Record "Key";
    begin
        RealKey.SetLoadFields(TableNo, Enabled, ObsoleteState, "No.", "Key");
        RealKey.SetRange(TableNo, ObjectTableNo);
        RealKey.SetRange(Enabled, true);
        RealKey.SetFilter(ObsoleteState, '<>%1', RealKey.ObsoleteState::Removed);
        if RealKey.FindSet() then
            repeat
                KeyIndexes.Add(RealKey."No.");
                KeyCaptions.Add(RealKey."Key");
            until RealKey.Next() = 0;
    end;

    /// <summary>
    /// Picks the key number to sort by. The request wins, then the user's key selection, then the
    /// page's default key. The ascending flag comes with the choice.
    /// </summary>
    /// <param name="Request">The request object, with optional sortKey and ascending.</param>
    /// <param name="TempMain">The service's Main row, with the page ID and the default key.</param>
    /// <param name="Ascending">Receives the sort direction. It starts as the request value, default true.</param>
    /// <returns>The chosen key number, or 0 when no key is chosen.</returns>
    procedure ChooseKey(Request: JsonObject; var TempMain: Record "MobileNAV Settings Buffer" temporary; var Ascending: Boolean): Integer
    var
        UserKeySelection: Record "MobileNAV User Key Selection";
        RequestKey: Integer;
    begin
        Ascending := this.BoolValue(Request, 'ascending', true);
        RequestKey := this.IntValue(Request, 'sortKey', 0);
        if RequestKey > 0 then
            exit(RequestKey);

        UserKeySelection.SetLoadFields("Key No.", Ascending);
        UserKeySelection.SetRange("User ID", this.EmuConfig.LoadedUserId());
        UserKeySelection.SetRange("Page No.", TempMain."Object ID");
        if UserKeySelection.FindFirst() then begin
            Ascending := UserKeySelection.Ascending;
            exit(UserKeySelection."Key No.");
        end;
        if TempMain."Default Key No." > 0 then begin
            Ascending := TempMain."Default Key Ascending";
            exit(TempMain."Default Key No.");
        end;
        exit(0);
    end;

    /// <summary>
    /// Applies a key number to the source table. A number outside the key list applies no key.
    /// </summary>
    /// <param name="KeyNo">The key number from ChooseKey, 1 for the first key.</param>
    /// <param name="Ascending">The sort direction.</param>
    /// <param name="KeyIndexes">The physical key index of each key number.</param>
    /// <param name="SourceRef">The open source table.</param>
    /// <returns>The key number applied, or 0 when none was applied.</returns>
    procedure ApplyKey(KeyNo: Integer; Ascending: Boolean; KeyIndexes: List of [Integer]; var SourceRef: RecordRef): Integer
    begin
        if (KeyNo < 1) or (KeyNo > KeyIndexes.Count()) then
            exit(0);
        SourceRef.CurrentKeyIndex(KeyIndexes.Get(KeyNo));
        SourceRef.Ascending(Ascending);
        exit(KeyNo);
    end;

    /// <summary>
    /// Applies the predefined filters of the page: Filter rows without a relation, except the
    /// rows scoped Offline. The filters go in filter group 2.
    /// </summary>
    /// <param name="TempRows">The rows of the service. Its filters are set here.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table.</param>
    procedure ApplyPredefinedFilters(var TempRows: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    begin
        TempRows.Reset();
        TempRows.SetRange("Line Type", TempRows."Line Type"::"Filter");
        TempRows.SetRange("Relation No.", 0);
        SourceRef.FilterGroup(2);
        if TempRows.FindSet() then
            repeat
                this.ApplyPredefinedFilter(TempRows, TempFieldRows, SourceRef);
            until TempRows.Next() = 0;
        SourceRef.FilterGroup(0);
    end;

    /// <summary>Applies one predefined filter row to the source table.</summary>
    /// <param name="FilterRow">A Filter row of the service.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table, with filter group 2 current.</param>
    local procedure ApplyPredefinedFilter(var FilterRow: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        FieldNo: Integer;
        ComparisonType: Integer;
    begin
        if FilterRow."Filter Scope" = FilterRow."Filter Scope"::Offline then
            exit;
        FieldNo := this.EmuRecords.FieldNo(TempFieldRows, SourceRef, FilterRow.SourceFieldName);
        if FieldNo = 0 then
            exit;
        ComparisonType := FilterRow."Filter Comparison Type";
        SourceRef.Field(FieldNo).SetFilter(this.EmuRecords.ComparisonPrefix(ComparisonType) + FilterRow.FilterValue);
    end;

    /// <summary>
    /// Applies the user's flow filters for the service. The filters go in filter group 2.
    /// </summary>
    /// <param name="UserId">The user whose flow filters apply.</param>
    /// <param name="ServiceName">The service whose flow filters apply.</param>
    /// <param name="SourceRef">The open source table.</param>
    procedure ApplyFlowFilters(UserId: Code[50]; ServiceName: Text; var SourceRef: RecordRef)
    var
        FlowFilter: Record "MobileNAV FlowFilters";
    begin
        FlowFilter.SetLoadFields("Field ID", "Filter Text");
        FlowFilter.SetRange("User ID", UserId);
        FlowFilter.SetRange("Service Name", ServiceName);
        if not FlowFilter.FindSet() then
            exit;
        SourceRef.FilterGroup(2);
        repeat
            if (FlowFilter."Filter Text" <> '') and SourceRef.FieldExist(FlowFilter."Field ID") then
                SourceRef.Field(FlowFilter."Field ID").SetFilter(FlowFilter."Filter Text");
        until FlowFilter.Next() = 0;
        SourceRef.FilterGroup(0);
    end;

    /// <summary>
    /// Applies the relation to a parent record when the request has a parent: the parent's relation
    /// row for the field, and its filter rows. The filters go in filter group 4. Public, so the forms
    /// codeunit reads the same relation filters for the defaults of a new record.
    /// </summary>
    /// <param name="Request">The request object, with an optional parent object.</param>
    /// <param name="ServiceName">The child service, which the relation names as its related page.</param>
    /// <param name="TempFieldRows">A copy of the child's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open child source table.</param>
    procedure ApplyParent(Request: JsonObject; ServiceName: Text; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        TempParentMain: Record "MobileNAV Settings Buffer" temporary;
        TempParentRows: Record "MobileNAV Settings Buffer" temporary;
        TempParentFieldRows: Record "MobileNAV Settings Buffer" temporary;
        ParentRef: RecordRef;
        ParentObject: JsonObject;
        ParentService: Text;
        ParentField: Text;
        ParentPosition: Text;
        PageLineNo: Integer;
        RelationNo: Integer;
    begin
        ParentObject := this.ObjectValue(Request, 'parent');
        ParentService := this.TextValue(ParentObject, 'service', '');
        if ParentService = '' then
            exit;
        ParentField := this.TextValue(ParentObject, 'field', '');
        ParentPosition := this.TextValue(ParentObject, 'position', '');
        if not this.EmuConfig.FindMain(ParentService, TempParentMain) then
            Error(this.ServiceNotFoundErr, ParentService);
        this.EmuConfig.CopyRows(ParentService, TempParentRows);
        this.EmuConfig.CopyRows(ParentService, TempParentFieldRows);
        this.EmuRecords.OpenSource(TempParentMain, ParentRef);
        if (ParentPosition = '') or not this.EmuRecords.FindByPosition(ParentRef, ParentPosition) then
            Error(this.ParentPositionErr, ParentService);

        this.FindRelation(TempParentRows, ParentService, ParentField, ServiceName, PageLineNo, RelationNo);
        TempParentRows.Reset();
        TempParentRows.SetRange("Line Type", TempParentRows."Line Type"::"Filter");
        TempParentRows.SetRange("Page Line No.", PageLineNo);
        TempParentRows.SetRange("Relation No.", RelationNo);
        SourceRef.FilterGroup(4);
        if TempParentRows.FindSet() then
            repeat
                this.ApplyRelationFilter(TempParentRows, TempParentFieldRows, ParentRef, TempFieldRows, SourceRef);
            until TempParentRows.Next() = 0;
        SourceRef.FilterGroup(0);
    end;

    /// <summary>
    /// Finds the parent's relation row for a field that leads to the child service.
    /// </summary>
    /// <param name="TempParentRows">The rows of the parent service. Its filters are set here.</param>
    /// <param name="ParentService">The parent service name, for the error.</param>
    /// <param name="ParentField">The parent trigger field.</param>
    /// <param name="ServiceName">The child service, the related page of the relation.</param>
    /// <param name="PageLineNo">Receives the Page Line No. of the relation.</param>
    /// <param name="RelationNo">Receives the Relation No. of the relation.</param>
    local procedure FindRelation(var TempParentRows: Record "MobileNAV Settings Buffer" temporary; ParentService: Text; ParentField: Text; ServiceName: Text; var PageLineNo: Integer; var RelationNo: Integer)
    begin
        TempParentRows.SetRange("Line Type", TempParentRows."Line Type"::Relation);
        TempParentRows.SetRange(FieldName, ParentField);
        TempParentRows.SetRange(RelatedPageName, ServiceName);
        if not TempParentRows.FindFirst() then
            Error(this.RelationMissingErr, ParentService, ParentField, ServiceName);
        PageLineNo := TempParentRows."Page Line No.";
        RelationNo := TempParentRows."Relation No.";
    end;

    /// <summary>
    /// Applies one filter row of a relation to the child. A Field filter takes the parent's value
    /// of its source field. A Filter or Const filter takes its own value.
    /// </summary>
    /// <param name="FilterRow">A Filter row of the parent's relation.</param>
    /// <param name="TempParentFieldRows">A copy of the parent's rows, used for field lookups.</param>
    /// <param name="ParentRef">The open parent record, positioned on the parent.</param>
    /// <param name="TempFieldRows">A copy of the child's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open child source table, with filter group 4 current.</param>
    local procedure ApplyRelationFilter(var FilterRow: Record "MobileNAV Settings Buffer" temporary; var TempParentFieldRows: Record "MobileNAV Settings Buffer" temporary; var ParentRef: RecordRef; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        ChildNo: Integer;
        ComparisonType: Integer;
    begin
        ChildNo := this.EmuRecords.FieldNo(TempFieldRows, SourceRef, FilterRow.DestFieldName);
        if ChildNo = 0 then
            exit;
        case FilterRow.FilterType of
            FilterRow.FilterType::"Field":
                this.SetChildValue(SourceRef, ChildNo, this.ParentValueText(TempParentFieldRows, ParentRef, FilterRow.SourceFieldName));
            FilterRow.FilterType::"Filter", FilterRow.FilterType::"Const":
                begin
                    ComparisonType := FilterRow."Filter Comparison Type";
                    SourceRef.Field(ChildNo).SetFilter(this.EmuRecords.ComparisonPrefix(ComparisonType) + FilterRow.FilterValue);
                end;
        end;
    end;

    /// <summary>
    /// Reads the display value of a parent field for a Field relation filter.
    /// </summary>
    /// <param name="TempParentFieldRows">A copy of the parent's rows, used for field lookups.</param>
    /// <param name="ParentRef">The open parent record, positioned on the parent.</param>
    /// <param name="FieldName">The parent field name from the filter row.</param>
    /// <returns>The value as text.</returns>
    local procedure ParentValueText(var TempParentFieldRows: Record "MobileNAV Settings Buffer" temporary; var ParentRef: RecordRef; FieldName: Text): Text
    var
        ParentNo: Integer;
    begin
        ParentNo := this.EmuRecords.FieldNo(TempParentFieldRows, ParentRef, FieldName);
        if ParentNo = 0 then
            Error(this.ParentFieldMissingErr, FieldName);
        exit(Format(ParentRef.Field(ParentNo).Value()));
    end;

    /// <summary>
    /// Sets a child field to a value. A text field takes a range, any other type takes a filter,
    /// so the value parses as the field's type.
    /// </summary>
    /// <param name="SourceRef">The open child source table.</param>
    /// <param name="FieldNo">The child field number.</param>
    /// <param name="Value">The value text.</param>
    local procedure SetChildValue(var SourceRef: RecordRef; FieldNo: Integer; Value: Text)
    begin
        if this.IsTextField(SourceRef, FieldNo) then
            SourceRef.Field(FieldNo).SetRange(Value)
        else
            SourceRef.Field(FieldNo).SetFilter(Value);
    end;

    /// <summary>
    /// Applies a saved filter by name: its header row (Line No. 0) and the criteria rows of the same
    /// page. The filters go in filter group 0.
    /// </summary>
    /// <param name="SavedFilterName">The saved filter name, or '' for none.</param>
    /// <param name="TempRows">The rows of the service. Its filters are set here.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table.</param>
    local procedure ApplySavedFilter(SavedFilterName: Text; var TempRows: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        PageLineNo: Integer;
    begin
        if SavedFilterName = '' then
            exit;
        TempRows.Reset();
        TempRows.SetRange("Line Type", TempRows."Line Type"::SavedFilter);
        TempRows.SetRange("Line No.", 0);
        TempRows.SetRange(TempRows.Name, SavedFilterName);
        if not TempRows.FindFirst() then
            Error(this.SavedFilterMissingErr, SavedFilterName);
        PageLineNo := TempRows."Page Line No.";

        TempRows.Reset();
        TempRows.SetRange("Line Type", TempRows."Line Type"::SavedFilter);
        TempRows.SetRange("Page Line No.", PageLineNo);
        TempRows.SetFilter("Line No.", '<>0');
        SourceRef.FilterGroup(0);
        if TempRows.FindSet() then
            repeat
                this.ApplySavedCriteria(TempRows, TempFieldRows, SourceRef);
            until TempRows.Next() = 0;
    end;

    /// <summary>
    /// Applies one criteria row of a saved filter. The search type decides the filter text:
    /// BeginMatch, Equal or AnyMatch.
    /// </summary>
    /// <param name="Criteria">A SavedFilter criteria row.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table.</param>
    local procedure ApplySavedCriteria(var Criteria: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        FieldNo: Integer;
        FilterText: Text;
    begin
        FieldNo := this.EmuRecords.FieldNo(TempFieldRows, SourceRef, Criteria.FieldName);
        if FieldNo = 0 then
            exit;
        case Criteria."Search Type" of
            Criteria."Search Type"::BeginMatch:
                FilterText := '@' + Criteria.FilterValue + '*';
            Criteria."Search Type"::AnyMatch:
                FilterText := '@*' + Criteria.FilterValue + '*';
            else
                FilterText := Criteria.FilterValue;
        end;
        SourceRef.Field(FieldNo).SetFilter(FilterText);
    end;

    /// <summary>
    /// Applies the filter panel of the request, one field and value per entry. Entries with an
    /// empty value are skipped. The filters go in filter group 0.
    /// </summary>
    /// <param name="Request">The request object, with an optional filters array.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table.</param>
    local procedure ApplyFilterPanel(Request: JsonObject; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        FilterToken: JsonToken;
        Filters: JsonArray;
        Entry: JsonObject;
        Index: Integer;
        FieldName: Text;
        FilterValue: Text;
        FieldNo: Integer;
    begin
        SourceRef.FilterGroup(0);
        if not Request.Get('filters', FilterToken) then
            exit;
        if not FilterToken.IsArray() then
            exit;
        Filters := FilterToken.AsArray();
        for Index := 0 to Filters.Count() - 1 do begin
            Filters.Get(Index, FilterToken);
            Entry := FilterToken.AsObject();
            FieldName := this.TextValue(Entry, 'field', '');
            FilterValue := this.TextValue(Entry, 'value', '');
            if FilterValue <> '' then begin
                FieldNo := this.EmuRecords.FieldNo(TempFieldRows, SourceRef, FieldName);
                if FieldNo = 0 then
                    FieldNo := this.EmuRecords.FieldNoByElement(TempFieldRows, SourceRef, FieldName);
                if FieldNo = 0 then
                    Error(this.FilterFieldMissingErr, FieldName);
                SourceRef.Field(FieldNo).SetFilter(FilterValue);
            end;
        end;
    end;

    /// <summary>
    /// Applies the search box. It is an OR across the visible text and code fields of the page
    /// whose class is Normal, in filter group -1.
    /// </summary>
    /// <param name="SearchText">The search text, or '' for none.</param>
    /// <param name="TempRows">The rows of the service. Its filters are set here.</param>
    /// <param name="SourceRef">The open source table.</param>
    local procedure ApplySearch(SearchText: Text; var TempRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    begin
        if SearchText = '' then
            exit;
        TempRows.Reset();
        TempRows.SetRange("Line Type", TempRows."Line Type"::Field);
        TempRows.SetRange(Visible, true);
        TempRows.SetFilter("Field No.", '<>0');
        TempRows.SetRange(FieldClass, TempRows.FieldClass::Normal);
        SourceRef.FilterGroup(-1);
        if TempRows.FindSet() then
            repeat
                if this.IsTextField(SourceRef, TempRows."Field No.") then
                    SourceRef.Field(TempRows."Field No.").SetFilter('@*' + SearchText + '*');
            until TempRows.Next() = 0;
        SourceRef.FilterGroup(0);
    end;

    /// <summary>
    /// Reads one page of records. The record after the page decides hasMore.
    /// </summary>
    /// <param name="TempMain">The service's Main row, with the line formats and the page ID.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table, with its filters and sort applied.</param>
    /// <param name="EmuLayouts">The layouts codeunit of the request. One instance serves every row.</param>
    /// <param name="SkipCount">The number of records to skip.</param>
    /// <param name="PageSize">The number of rows to return.</param>
    /// <param name="CellFormats">The list cell formats of the service, by cell number, see ParseListCellFormatsXml.</param>
    /// <param name="RowArray">Receives the row objects.</param>
    /// <returns>True when another record exists after the page.</returns>
    local procedure AddRows(var TempMain: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var EmuLayouts: Codeunit "BJF MN Emulator Layouts"; SkipCount: Integer; PageSize: Integer; var CellFormats: array [1000] of Text[1024]; var RowArray: JsonArray): Boolean
    var
        Skipped: Integer;
        Added: Integer;
        HasRecord: Boolean;
    begin
        Skipped := 0;
        Added := 0;
        HasRecord := SourceRef.FindSet();
        while HasRecord and (Skipped < SkipCount) do begin
            HasRecord := SourceRef.Next() <> 0;
            Skipped += 1;
        end;
        while HasRecord and (Added < PageSize) do begin
            RowArray.Add(this.RowJson(TempMain, TempFieldRows, SourceRef, EmuLayouts, CellFormats));
            Added += 1;
            HasRecord := SourceRef.Next() <> 0;
        end;
        exit(HasRecord);
    end;

    /// <summary>
    /// Builds one row of the list response from the current record: its position, its lines, its
    /// field control and the layout parts that a row shows.
    /// </summary>
    /// <param name="TempMain">The service's Main row, with the first and second line formats, the page ID and the service name.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="EmuLayouts">The layouts codeunit of the request.</param>
    /// <param name="CellFormats">The list cell formats of the service, by cell number.</param>
    /// <returns>The row object: position, line1, line2, line3, fieldControl and layout.</returns>
    local procedure RowJson(var TempMain: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var EmuLayouts: Codeunit "BJF MN Emulator Layouts"; var CellFormats: array [1000] of Text[1024]): JsonObject
    var
        Row: JsonObject;
        Effects: JsonObject;
    begin
        Row.Add('position', this.EmuRecords.Position(SourceRef));
        this.AddLines(TempMain, TempFieldRows, SourceRef, CellFormats, Row);
        // The page service read in a later phase supplies the field control.
        Row.Add('fieldControl', '');
        Effects := EmuLayouts.Evaluate(TempMain."Service Name", TempFieldRows, SourceRef);
        Row.Add('layout', this.LayoutPart(Effects));
        exit(Row);
    end;

    /// <summary>
    /// Adds the lines of a row. A list that has grid text formats sends the three lines of its cells, and each
    /// line has a left part and a right part joined by a tab. The cells are 3 top left, 4 middle left, 5 bottom
    /// left, 6 top right, 7 middle right and 8 bottom right. A list without them sends the first and second
    /// line formats on the left, as the device does. The emulator splits a line on the tab.
    /// </summary>
    /// <param name="TempMain">The service's Main row, with the first and second line formats.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="CellFormats">The list cell formats of the service, by cell number.</param>
    /// <param name="Row">The row object that receives line1, line2 and line3.</param>
    local procedure AddLines(var TempMain: Record "MobileNAV Settings Buffer" temporary; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var CellFormats: array [1000] of Text[1024]; var Row: JsonObject)
    begin
        if not this.HasGridTexts(CellFormats) then begin
            Row.Add('line1', this.EmuRecords.FormatLine(TempMain."First Line Format", TempFieldRows, SourceRef));
            Row.Add('line2', this.EmuRecords.FormatLine(TempMain."Second Line Format", TempFieldRows, SourceRef));
            exit;
        end;
        Row.Add('line1', this.CellLine(CellFormats, 3, 6, TempFieldRows, SourceRef));
        Row.Add('line2', this.CellLine(CellFormats, 4, 7, TempFieldRows, SourceRef));
        Row.Add('line3', this.CellLine(CellFormats, 5, 8, TempFieldRows, SourceRef));
    end;

    /// <summary>Tells whether the service has a list cell format, which makes its list use the grid texts.</summary>
    /// <param name="CellFormats">The list cell formats of the service, by cell number.</param>
    /// <returns>True when one of the cells 3 to 8 has a format.</returns>
    local procedure HasGridTexts(var CellFormats: array [1000] of Text[1024]): Boolean
    var
        CellNo: Integer;
    begin
        for CellNo := 3 to 8 do
            if CellFormats[CellNo] <> '' then
                exit(true);
        exit(false);
    end;

    /// <summary>
    /// Builds one line of a grid row: the text of the left cell, then a tab and the text of the right cell.
    /// The tab is left out when the right cell has no format.
    /// </summary>
    /// <param name="CellFormats">The list cell formats of the service, by cell number.</param>
    /// <param name="LeftCellNo">The cell number of the left part.</param>
    /// <param name="RightCellNo">The cell number of the right part.</param>
    /// <param name="TempFieldRows">A copy of the service's rows, used for field lookups.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <returns>The line text.</returns>
    local procedure CellLine(var CellFormats: array [1000] of Text[1024]; LeftCellNo: Integer; RightCellNo: Integer; var TempFieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef): Text
    var
        LeftText: Text;
    begin
        LeftText := this.EmuRecords.FormatLine(CellFormats[LeftCellNo], TempFieldRows, SourceRef);
        if CellFormats[RightCellNo] = '' then
            exit(LeftText);
        exit(LeftText + this.TabText() + this.EmuRecords.FormatLine(CellFormats[RightCellNo], TempFieldRows, SourceRef));
    end;

    /// <summary>Returns a text with one tab character, the separator of the left and right parts of a line.</summary>
    /// <returns>The tab text.</returns>
    local procedure TabText(): Text[1]
    var
        TabChar: Char;
        Tab: Text[1];
    begin
        TabChar := 9;
        Tab[1] := TabChar;
        exit(Tab);
    end;

    /// <summary>
    /// Keeps the parts of the layout effects that a list row shows: the line colours, the background
    /// colour and the row icon. The field effects stay out of the list response.
    /// </summary>
    /// <param name="Effects">The layout effects of the row, from the layouts codeunit.</param>
    /// <returns>The layout object of the row: colors and rowIcon.</returns>
    local procedure LayoutPart(Effects: JsonObject): JsonObject
    var
        Part: JsonObject;
    begin
        Part.Add('colors', this.ObjectValue(Effects, 'colors'));
        Part.Add('rowIcon', this.TextValue(Effects, 'rowIcon', ''));
        exit(Part);
    end;

    /// <summary>
    /// Lists the filter fields of the service: Field rows with Visible as Filter, in their order.
    /// </summary>
    /// <param name="TempRows">The rows of the service. Its filters are set here.</param>
    /// <returns>An array of objects with field and caption.</returns>
    local procedure FilterFields(var TempRows: Record "MobileNAV Settings Buffer" temporary): JsonArray
    var
        Fields: JsonArray;
        Entry: JsonObject;
    begin
        TempRows.Reset();
        TempRows.SetCurrentKey("Service Name", "Line Type", "Order");
        TempRows.SetRange("Line Type", TempRows."Line Type"::Field);
        TempRows.SetRange("Visible as Filter", true);
        if TempRows.FindSet() then
            repeat
                Clear(Entry);
                Entry.Add('field', TempRows.FieldName);
                if TempRows.LocalizedFieldName <> '' then
                    Entry.Add('caption', TempRows.LocalizedFieldName)
                else
                    Entry.Add('caption', TempRows.FieldName);
                Fields.Add(Entry);
            until TempRows.Next() = 0;
        exit(Fields);
    end;

    /// <summary>Lists the saved filter names of the service, sorted by name.</summary>
    /// <param name="TempRows">The rows of the service. Its filters are set here.</param>
    /// <returns>An array of objects with name.</returns>
    local procedure SavedFilterNames(var TempRows: Record "MobileNAV Settings Buffer" temporary): JsonArray
    var
        Names: List of [Text];
        Saved: JsonArray;
        Entry: JsonObject;
        Index: Integer;
    begin
        TempRows.Reset();
        TempRows.SetRange("Line Type", TempRows."Line Type"::SavedFilter);
        TempRows.SetRange("Line No.", 0);
        if TempRows.FindSet() then
            repeat
                Names.Add(TempRows.Name);
            until TempRows.Next() = 0;
        this.SortTexts(Names);
        for Index := 1 to Names.Count() do begin
            Clear(Entry);
            Entry.Add('name', Names.Get(Index));
            Saved.Add(Entry);
        end;
        exit(Saved);
    end;

    /// <summary>
    /// Builds the keys array of the response. The number is the position in the list.
    /// </summary>
    /// <param name="KeyCaptions">The key text of each key, in number order.</param>
    /// <returns>An array of objects with no and caption.</returns>
    local procedure KeysJson(KeyCaptions: List of [Text]): JsonArray
    var
        Keys: JsonArray;
        Entry: JsonObject;
        Index: Integer;
    begin
        for Index := 1 to KeyCaptions.Count() do begin
            Clear(Entry);
            Entry.Add('no', Index);
            Entry.Add('caption', KeyCaptions.Get(Index));
            Keys.Add(Entry);
        end;
        exit(Keys);
    end;

    /// <summary>
    /// Returns the caption of the service: the localized name, else the name.
    /// </summary>
    /// <param name="TempMain">The service's Main row.</param>
    /// <returns>The caption text.</returns>
    local procedure ServiceCaption(var TempMain: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        if TempMain.LocalizedName <> '' then
            exit(TempMain.LocalizedName);
        exit(TempMain.Name);
    end;

    /// <summary>
    /// Returns the card service of a list: the related page when it is in the configuration, else
    /// the list itself when it is a list card or a card, else ''.
    /// </summary>
    /// <param name="TempMain">The service's Main row.</param>
    /// <param name="ServiceName">The service name of the list.</param>
    /// <returns>The card service name, or ''.</returns>
    local procedure CardService(var TempMain: Record "MobileNAV Settings Buffer" temporary; ServiceName: Text): Text
    var
        TempRelatedMain: Record "MobileNAV Settings Buffer" temporary;
    begin
        if TempMain.RelatedPageName <> '' then
            if this.EmuConfig.FindMain(TempMain.RelatedPageName, TempRelatedMain) then
                exit(TempMain.RelatedPageName);
        if TempMain."Page Type" in [TempMain."Page Type"::ListCard, TempMain."Page Type"::Card] then
            exit(ServiceName);
        exit('');
    end;

    /// <summary>
    /// Tells whether a source field exists and is a text or code field.
    /// </summary>
    /// <param name="SourceRef">The open source table.</param>
    /// <param name="FieldNo">The field number.</param>
    /// <returns>True for a text or code field that exists.</returns>
    local procedure IsTextField(var SourceRef: RecordRef; FieldNo: Integer): Boolean
    var
        FieldRef: FieldRef;
    begin
        if not SourceRef.FieldExist(FieldNo) then
            exit(false);
        FieldRef := SourceRef.Field(FieldNo);
        exit(FieldRef.Type() in [FieldType::Text, FieldType::Code]);
    end;

    /// <summary>Sorts texts ascending with an insertion sort. The lists are short.</summary>
    /// <param name="Values">The texts to sort in place.</param>
    local procedure SortTexts(var Values: List of [Text])
    var
        Current: Text;
        Slot: Integer;
        Index: Integer;
    begin
        for Index := 2 to Values.Count() do begin
            Current := Values.Get(Index);
            Slot := Index;
            while (Slot > 1) and (Values.Get(Slot - 1) > Current) do begin
                Values.Set(Slot, Values.Get(Slot - 1));
                Slot -= 1;
            end;
            Values.Set(Slot, Current);
        end;
    end;

    /// <summary>Reads a text property of a JSON object.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <param name="DefaultText">The value returned when the property is missing, not a value, or null.</param>
    /// <returns>The text of the property, or the default.</returns>
    local procedure TextValue(Request: JsonObject; PropertyName: Text; DefaultText: Text): Text
    var
        Token: JsonToken;
    begin
        if not this.HasValue(Request, PropertyName, Token) then
            exit(DefaultText);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads an integer property of a JSON object.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <param name="DefaultValue">The value returned when the property is missing, not a value, or null.</param>
    /// <returns>The integer of the property, or the default.</returns>
    local procedure IntValue(Request: JsonObject; PropertyName: Text; DefaultValue: Integer): Integer
    var
        Token: JsonToken;
    begin
        if not this.HasValue(Request, PropertyName, Token) then
            exit(DefaultValue);
        exit(Token.AsValue().AsInteger());
    end;

    /// <summary>Reads a boolean property of a JSON object.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <param name="DefaultValue">The value returned when the property is missing, not a value, or null.</param>
    /// <returns>The boolean of the property, or the default.</returns>
    local procedure BoolValue(Request: JsonObject; PropertyName: Text; DefaultValue: Boolean): Boolean
    var
        Token: JsonToken;
    begin
        if not this.HasValue(Request, PropertyName, Token) then
            exit(DefaultValue);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>Reads a nested object of a JSON object.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <returns>The nested object, or an empty object when the property is missing or not an object.</returns>
    local procedure ObjectValue(Request: JsonObject; PropertyName: Text): JsonObject
    var
        Token: JsonToken;
        Empty: JsonObject;
    begin
        if not Request.Get(PropertyName, Token) then
            exit(Empty);
        if not Token.IsObject() then
            exit(Empty);
        exit(Token.AsObject());
    end;

    /// <summary>Tells whether a JSON property holds a value that is not null.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <param name="Token">Receives the property token when it exists.</param>
    /// <returns>True when the property holds a value.</returns>
    local procedure HasValue(Request: JsonObject; PropertyName: Text; var Token: JsonToken): Boolean
    begin
        if not Request.Get(PropertyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        exit(not Token.AsValue().IsNull());
    end;
}

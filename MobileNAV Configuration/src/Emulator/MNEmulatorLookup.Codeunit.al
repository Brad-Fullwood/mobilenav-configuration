namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// Answers the lookup request of the device emulator. A lookup field opens its related page as a
/// picker. This codeunit reads the related page's source table, filters it on the search text, and
/// returns one page of code and description pairs. Nothing is written.
/// </summary>
codeunit 77735 "BJF MN Emulator Lookup"
{
    Access = Internal;

    var
        EmuConfig: Codeunit "BJF MN Emulator Config";
        EmuRecords: Codeunit "BJF MN Emulator Records";
        EmuList: Codeunit "BJF MN Emulator List";
        ServiceMissingErr: Label 'The service %1 is not in the loaded configuration.', Comment = '%1 = the Service Name of the lookup request';
        FieldMissingErr: Label 'The field %1 is not on the page.', Comment = '%1 = the field name';
        NoLookupErr: Label 'The field %1 has no lookup.', Comment = '%1 = the field name';
        RelatedMissingErr: Label 'The lookup page %1 is not in the loaded configuration.', Comment = '%1 = the related Service Name';
        CodeFieldMissingErr: Label 'The lookup code field %1 is not on the page %2.', Comment = '%1 = the code field name, %2 = the related Service Name';

    /// <summary>
    /// Answers one lookup request: one page of the related page's records, as code and description.
    /// The caller loads the configuration first, see "BJF MN Emulator Config". The position in the
    /// request is not used: the related page's relation filters are not applied.
    /// </summary>
    /// <param name="Request">The request object with kind lookup, the service, the field, the search text and the paging.</param>
    /// <returns>The lookup response object, with the rows of the related page.</returns>
    procedure LookupJson(Request: JsonObject): JsonObject
    var
        TempRelation: Record "MobileNAV Settings Buffer" temporary;
        TempRelatedMain: Record "MobileNAV Settings Buffer" temporary;
        SourceRef: RecordRef;
        RowArray: JsonArray;
        Response: JsonObject;
        ServiceName: Text;
        FieldName: Text;
        SearchText: Text;
        CaptionText: Text;
        CodeFieldNo: Integer;
        DescFieldNo: Integer;
        SkipCount: Integer;
        PageSize: Integer;
        HasMore: Boolean;
    begin
        ServiceName := this.TextValue(Request, 'service', '');
        FieldName := this.TextValue(Request, 'field', '');
        this.LookupRelation(ServiceName, FieldName, TempRelation);
        this.OpenRelated(TempRelation, TempRelatedMain, SourceRef, CodeFieldNo, DescFieldNo);

        SearchText := this.TextValue(Request, 'search', '');
        if SearchText <> '' then
            this.ApplySearch(SearchText, CodeFieldNo, DescFieldNo, SourceRef);

        this.ReadPaging(Request, SkipCount, PageSize);
        HasMore := this.AddRows(SourceRef, CodeFieldNo, DescFieldNo, SkipCount, PageSize, RowArray);

        CaptionText := TempRelatedMain.LocalizedName;
        if CaptionText = '' then
            CaptionText := TempRelation.RelatedPageName;

        Response.Add('kind', 'lookup');
        Response.Add('service', ServiceName);
        Response.Add('field', FieldName);
        Response.Add('relatedService', TempRelation.RelatedPageName);
        Response.Add('caption', CaptionText);
        Response.Add('multiSelect', TempRelation.MultiSelect);
        Response.Add('rows', RowArray);
        Response.Add('hasMore', HasMore);
        Response.Add('skip', SkipCount);
        Response.Add('top', PageSize);
        exit(Response);
    end;

    /// <summary>
    /// Finds the Relation row of a lookup field. The field must be on the service, and its relation
    /// must name a code field. The relation is the one the card uses for its drill-downs: the Relation
    /// row with the same Page Line No.
    /// </summary>
    /// <param name="ServiceName">The service of the field.</param>
    /// <param name="FieldName">The FieldName of the field.</param>
    /// <param name="RelationRow">Receives a copy of the Relation row.</param>
    local procedure LookupRelation(ServiceName: Text; FieldName: Text; var RelationRow: Record "MobileNAV Settings Buffer" temporary)
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        TempRows: Record "MobileNAV Settings Buffer" temporary;
        PageLineNo: Integer;
    begin
        if not this.EmuConfig.FindMain(ServiceName, TempMain) then
            Error(this.ServiceMissingErr, ServiceName);

        this.EmuConfig.CopyRows(ServiceName, TempRows);
        TempRows.SetRange("Line Type", TempRows."Line Type"::Field);
        TempRows.SetRange(TempRows.FieldName, FieldName);
        if not TempRows.FindFirst() then
            Error(this.FieldMissingErr, FieldName);
        PageLineNo := TempRows."Page Line No.";

        TempRows.Reset();
        TempRows.SetRange("Line Type", TempRows."Line Type"::Relation);
        TempRows.SetRange("Page Line No.", PageLineNo);
        if not TempRows.FindFirst() then
            Error(this.NoLookupErr, FieldName);
        if TempRows.RelatedPgCodeFldName = '' then
            Error(this.NoLookupErr, FieldName);
        RelationRow := TempRows;
    end;

    /// <summary>
    /// Opens the source table of the related page and finds its code and description fields.
    /// </summary>
    /// <param name="RelationRow">The Relation row of the lookup field.</param>
    /// <param name="RelatedMain">Receives the Main row of the related page.</param>
    /// <param name="SourceRef">Receives the open source table of the related page, with its view.</param>
    /// <param name="CodeFieldNo">Receives the number of the code field.</param>
    /// <param name="DescFieldNo">Receives the number of the description field, or 0 when the relation names none.</param>
    local procedure OpenRelated(var RelationRow: Record "MobileNAV Settings Buffer" temporary; var RelatedMain: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var CodeFieldNo: Integer; var DescFieldNo: Integer)
    var
        TempRelatedRows: Record "MobileNAV Settings Buffer" temporary;
        RelatedService: Text;
    begin
        RelatedService := RelationRow.RelatedPageName;
        if not this.EmuConfig.FindMain(RelatedService, RelatedMain) then
            Error(this.RelatedMissingErr, RelatedService);
        this.EmuConfig.CopyRows(RelatedService, TempRelatedRows);
        this.EmuRecords.OpenSource(RelatedMain, SourceRef);
        this.ApplyListView(RelatedService, RelatedMain, SourceRef);

        CodeFieldNo := this.EmuRecords.FieldNo(TempRelatedRows, SourceRef, RelationRow.RelatedPgCodeFldName);
        if CodeFieldNo = 0 then
            Error(this.CodeFieldMissingErr, RelationRow.RelatedPgCodeFldName, RelatedService);
        DescFieldNo := 0;
        if RelationRow.RelatedPgDescFldName <> '' then
            DescFieldNo := this.EmuRecords.FieldNo(TempRelatedRows, SourceRef, RelationRow.RelatedPgDescFldName);
    end;

    /// <summary>
    /// Applies the sort, the predefined filters and the user's flow filters that the related list applies
    /// on the device, in the same order as the list. The parent relation, the saved filter and the filter
    /// panel do not apply to a lookup.
    /// </summary>
    /// <param name="ServiceName">The related service, whose rows hold the predefined filters.</param>
    /// <param name="RelatedMain">The Main row of the related page. Its default key applies when the user has no key selection.</param>
    /// <param name="SourceRef">The open source table of the related page.</param>
    local procedure ApplyListView(ServiceName: Text; var RelatedMain: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        TempFilterRows: Record "MobileNAV Settings Buffer" temporary;
        TempFieldRows: Record "MobileNAV Settings Buffer" temporary;
        EmptyRequest: JsonObject;
        KeyIndexes: List of [Integer];
        KeyCaptions: List of [Text];
        KeyNo: Integer;
        Ascending: Boolean;
    begin
        this.EmuConfig.CopyRows(ServiceName, TempFilterRows);
        this.EmuConfig.CopyRows(ServiceName, TempFieldRows);
        this.EmuList.CollectKeys(SourceRef.Number(), KeyIndexes, KeyCaptions);
        KeyNo := this.EmuList.ChooseKey(EmptyRequest, RelatedMain, Ascending);
        this.EmuList.ApplyKey(KeyNo, Ascending, KeyIndexes, SourceRef);
        this.EmuList.ApplyPredefinedFilters(TempFilterRows, TempFieldRows, SourceRef);
        this.EmuList.ApplyFlowFilters(this.EmuConfig.LoadedUserId(), ServiceName, SourceRef);
    end;

    /// <summary>
    /// Filters the source table on the search text. The description field takes the filter, or the
    /// code field when the page has no text description. Only text and code fields take it.
    /// </summary>
    /// <param name="SearchText">The text the user typed.</param>
    /// <param name="CodeFieldNo">The number of the code field.</param>
    /// <param name="DescFieldNo">The number of the description field, or 0 when there is none.</param>
    /// <param name="SourceRef">The open source table.</param>
    local procedure ApplySearch(SearchText: Text; CodeFieldNo: Integer; DescFieldNo: Integer; var SourceRef: RecordRef)
    var
        SearchFieldNo: Integer;
    begin
        SearchFieldNo := DescFieldNo;
        if (SearchFieldNo = 0) or not this.IsTextField(SourceRef, SearchFieldNo) then
            SearchFieldNo := CodeFieldNo;
        if this.IsTextField(SourceRef, SearchFieldNo) then
            SourceRef.Field(SearchFieldNo).SetFilter('@*' + SearchText + '*');
    end;

    /// <summary>Tells whether a table field is a text or code field.</summary>
    /// <param name="SourceRef">The open source table.</param>
    /// <param name="FieldNo">The number of the field.</param>
    /// <returns>True when the field exists and is a text or code field.</returns>
    local procedure IsTextField(var SourceRef: RecordRef; FieldNo: Integer): Boolean
    var
        FieldRef: FieldRef;
    begin
        if not SourceRef.FieldExist(FieldNo) then
            exit(false);
        FieldRef := SourceRef.Field(FieldNo);
        exit((FieldRef.Type() = FieldType::Text) or (FieldRef.Type() = FieldType::Code));
    end;

    /// <summary>Reads the paging of a lookup request. The page holds 50 rows by default and 200 at most.</summary>
    /// <param name="Request">The request object.</param>
    /// <param name="SkipCount">Receives the number of rows to skip.</param>
    /// <param name="PageSize">Receives the number of rows to return.</param>
    local procedure ReadPaging(Request: JsonObject; var SkipCount: Integer; var PageSize: Integer)
    begin
        PageSize := this.IntValue(Request, 'top', 50);
        if PageSize < 1 then
            PageSize := 50;
        if PageSize > 200 then
            PageSize := 200;
        SkipCount := this.IntValue(Request, 'skip', 0);
        if SkipCount < 0 then
            SkipCount := 0;
    end;

    /// <summary>
    /// Reads one page of records. The record after the page decides hasMore.
    /// </summary>
    /// <param name="SourceRef">The open source table, with its filters and sort applied.</param>
    /// <param name="CodeFieldNo">The number of the code field.</param>
    /// <param name="DescFieldNo">The number of the description field, or 0 when there is none.</param>
    /// <param name="SkipCount">The number of records to skip.</param>
    /// <param name="PageSize">The number of rows to return.</param>
    /// <param name="RowArray">Receives the row objects.</param>
    /// <returns>True when another record exists after the page.</returns>
    local procedure AddRows(var SourceRef: RecordRef; CodeFieldNo: Integer; DescFieldNo: Integer; SkipCount: Integer; PageSize: Integer; var RowArray: JsonArray): Boolean
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
            RowArray.Add(this.RowJson(SourceRef, CodeFieldNo, DescFieldNo));
            Added += 1;
            HasRecord := SourceRef.Next() <> 0;
        end;
        exit(HasRecord);
    end;

    /// <summary>Builds one row of the lookup response from the current record.</summary>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="CodeFieldNo">The number of the code field.</param>
    /// <param name="DescFieldNo">The number of the description field, or 0 when there is none.</param>
    /// <returns>The row object: code, description and position.</returns>
    local procedure RowJson(var SourceRef: RecordRef; CodeFieldNo: Integer; DescFieldNo: Integer): JsonObject
    var
        RowObject: JsonObject;
    begin
        RowObject.Add('code', this.FieldText(CodeFieldNo, SourceRef));
        RowObject.Add('description', this.FieldText(DescFieldNo, SourceRef));
        RowObject.Add('position', this.EmuRecords.Position(SourceRef));
        exit(RowObject);
    end;

    /// <summary>
    /// Returns the display text of a table field of the current record, through the records codeunit.
    /// </summary>
    /// <param name="FieldNo">The number of the field, or 0 for an empty text.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <returns>The display text.</returns>
    local procedure FieldText(FieldNo: Integer; var SourceRef: RecordRef): Text
    var
        TempValueRow: Record "MobileNAV Settings Buffer" temporary;
    begin
        TempValueRow."Field No." := FieldNo;
        exit(this.EmuRecords.FieldValue(TempValueRow, SourceRef));
    end;

    /// <summary>Reads a text property of a JSON object.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <param name="DefaultText">The text returned when the property is missing or null.</param>
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
    /// <param name="DefaultValue">The value returned when the property is missing or null.</param>
    /// <returns>The integer of the property, or the default.</returns>
    local procedure IntValue(Request: JsonObject; PropertyName: Text; DefaultValue: Integer): Integer
    var
        Token: JsonToken;
    begin
        if not this.HasValue(Request, PropertyName, Token) then
            exit(DefaultValue);
        exit(Token.AsValue().AsInteger());
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

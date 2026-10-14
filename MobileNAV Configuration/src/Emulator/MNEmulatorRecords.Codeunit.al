namespace BradFullwood.MobileNAV.Configuration;

using System.IO;
using System.Reflection;
using System.Text;

/// <summary>
/// Reads the records a page shows for the device emulator. It opens the page's source table with
/// the view from Page Metadata, reads each field as display text and fills a line format with
/// the values. Nothing is written.
/// </summary>
codeunit 77727 "BJF MN Emulator Records"
{
    Access = Internal;

    /// <summary>
    /// Opens the source table of a page and applies the view the page sets in Page Metadata.
    /// </summary>
    /// <param name="MainRow">The service's Main row. Its Object ID is the page.</param>
    /// <param name="SourceRef">Receives the open source table with the page's view applied.</param>
    procedure OpenSource(var MainRow: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef)
    var
        PageMetadata: Record "Page Metadata";
    begin
        PageMetadata.SetLoadFields(SourceTable, SourceTableView);
        if not PageMetadata.Get(MainRow."Object ID") then
            Error(this.PageMissingErr, MainRow."Object ID", MainRow."Service Name");
        SourceRef.Open(PageMetadata.SourceTable);
        if PageMetadata.SourceTableView <> '' then
            SourceRef.SetView(PageMetadata.SourceTableView);
    end;

    /// <summary>Finds the record at a saved position on the primary key and keeps the page's sort key.</summary>
    /// <param name="SourceRef">The open source table.</param>
    /// <param name="SavedPosition">A position from Position, passed back unchanged.</param>
    /// <returns>True when the record at the position still exists.</returns>
    procedure FindByPosition(var SourceRef: RecordRef; SavedPosition: Text): Boolean
    var
        KeyIndex: Integer;
        Found: Boolean;
    begin
        KeyIndex := SourceRef.CurrentKeyIndex();
        SourceRef.CurrentKeyIndex(1);
        SourceRef.SetPosition(SavedPosition);
        Found := SourceRef.Find('=');
        SourceRef.CurrentKeyIndex(KeyIndex);
        exit(Found);
    end;

    /// <summary>Returns the position of the current record, for FindByPosition.</summary>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <returns>The position text.</returns>
    procedure Position(var SourceRef: RecordRef): Text
    begin
        exit(SourceRef.GetPosition(false));
    end;

    /// <summary>
    /// Returns the table field a Field row reads. The Field row with that FieldName wins, and
    /// the table field with that name is the fallback.
    /// </summary>
    /// <param name="FieldRows">The rows of one service. Its filters are reset on exit.</param>
    /// <param name="SourceRef">The open source table.</param>
    /// <param name="FieldName">The FieldName of the Field row, or the name of a table field.</param>
    /// <returns>The field number, or 0 when neither matches.</returns>
    procedure FieldNo(var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; FieldName: Text): Integer
    var
        FieldRef: FieldRef;
        FieldNumber: Integer;
        Index: Integer;
    begin
        FieldRows.SetRange("Line Type", FieldRows."Line Type"::Field);
        FieldRows.SetRange(FieldRows.FieldName, FieldName);
        if FieldRows.FindFirst() then
            FieldNumber := FieldRows."Field No.";
        FieldRows.Reset();
        if FieldNumber <> 0 then
            exit(FieldNumber);

        for Index := 1 to SourceRef.FieldCount() do begin
            FieldRef := SourceRef.FieldIndex(Index);
            if FieldRef.Name() = FieldName then
                exit(FieldRef.Number());
        end;
        exit(0);
    end;

    /// <summary>
    /// Returns the table field for an element name. The Field row whose element name equals it wins,
    /// and the table field with that element name is the fallback. The comparison ignores case.
    /// </summary>
    /// <param name="FieldRows">The rows of one service. Its filters are reset on exit.</param>
    /// <param name="SourceRef">The open source table.</param>
    /// <param name="ElementName">The XML element name of the field, as the page service sends it.</param>
    /// <returns>The field number, or 0 when neither matches.</returns>
    procedure FieldNoByElement(var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; ElementName: Text): Integer
    var
        FieldNumber: Integer;
    begin
        FieldNumber := this.FieldRowNoByElement(FieldRows, ElementName);
        if FieldNumber <> 0 then
            exit(FieldNumber);
        exit(this.TableFieldNoByElement(SourceRef, ElementName));
    end;

    /// <summary>
    /// Returns the Field number of the first Field row whose element name equals ElementName. A row
    /// with Field No. 0 does not count.
    /// </summary>
    /// <param name="FieldRows">The rows of one service. Its filters are reset on exit.</param>
    /// <param name="ElementName">The XML element name of the field.</param>
    /// <returns>The field number, or 0 when no Field row matches.</returns>
    local procedure FieldRowNoByElement(var FieldRows: Record "MobileNAV Settings Buffer" temporary; ElementName: Text): Integer
    var
        FieldNumber: Integer;
    begin
        FieldRows.SetRange("Line Type", FieldRows."Line Type"::Field);
        if FieldRows.FindSet() then
            repeat
                if (FieldRows."Field No." <> 0) and this.SameElement(FieldRows.FieldName, ElementName) then
                    FieldNumber := FieldRows."Field No.";
            until (FieldRows.Next() = 0) or (FieldNumber <> 0);
        FieldRows.Reset();
        exit(FieldNumber);
    end;

    /// <summary>Returns the number of the first table field whose element name equals ElementName.</summary>
    /// <param name="SourceRef">The open source table.</param>
    /// <param name="ElementName">The XML element name of the field.</param>
    /// <returns>The field number, or 0 when no table field matches.</returns>
    local procedure TableFieldNoByElement(var SourceRef: RecordRef; ElementName: Text): Integer
    var
        FieldRef: FieldRef;
        Index: Integer;
    begin
        for Index := 1 to SourceRef.FieldCount() do begin
            FieldRef := SourceRef.FieldIndex(Index);
            if this.SameElement(FieldRef.Name(), ElementName) then
                exit(FieldRef.Number());
        end;
        exit(0);
    end;

    /// <summary>
    /// Finds the first record that holds the given values. Each match item names a field, by its
    /// FieldName or its element name, and gives a value. A text or code field takes the value as it
    /// is. Any other field takes it as a filter.
    /// The caller opens SourceRef with OpenSource just before this call, so the page's view applies
    /// and no other filter is set. This procedure does not reset SourceRef, because a reset would
    /// drop that view.
    /// </summary>
    /// <param name="FieldRows">The rows of one service. Its filters are reset on exit.</param>
    /// <param name="SourceRef">The open source table. Positioned on the first match when one is found.</param>
    /// <param name="Match">The match items. Each is an object with a field and a value.</param>
    /// <returns>True when a record matches all the items.</returns>
    procedure FindByMatch(var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; Match: JsonArray): Boolean
    var
        FieldRef: FieldRef;
        MatchToken: JsonToken;
        MatchItem: JsonObject;
        FieldName: Text;
        MatchValue: Text;
        FieldNumber: Integer;
    begin
        foreach MatchToken in Match do begin
            MatchItem := MatchToken.AsObject();
            FieldName := this.JsonText(MatchItem, 'field');
            MatchValue := this.JsonText(MatchItem, 'value');
            FieldNumber := this.FieldNo(FieldRows, SourceRef, FieldName);
            if FieldNumber = 0 then
                FieldNumber := this.FieldNoByElement(FieldRows, SourceRef, FieldName);
            if FieldNumber = 0 then
                Error(this.MatchFieldMissingErr, FieldName);

            FieldRef := SourceRef.Field(FieldNumber);
            if (FieldRef.Type() = FieldType::Text) or (FieldRef.Type() = FieldType::Code) then
                FieldRef.SetRange(MatchValue)
            else
                FieldRef.SetFilter(MatchValue);
        end;
        exit(SourceRef.FindFirst());
    end;

    /// <summary>
    /// Returns the value of the table field a Field row reads, as display text. A FlowField is
    /// calculated first. A decimal uses the row's Decimal Places. A blob always gives a placeholder. A media
    /// or media set gives the placeholder when it holds a picture, and an empty text when it is empty.
    /// </summary>
    /// <param name="FieldRow">The Field row. Its Field No. picks the table field.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <returns>The display text, or an empty text when the field does not exist or a media field is empty.</returns>
    procedure FieldValue(var FieldRow: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef): Text
    var
        FieldRef: FieldRef;
    begin
        if FieldRow."Field No." = 0 then
            exit('');
        if not SourceRef.FieldExist(FieldRow."Field No.") then
            exit('');

        FieldRef := SourceRef.Field(FieldRow."Field No.");
        if FieldRef.Class() = FieldClass::FlowField then
            FieldRef.CalcField();

        case FieldRef.Type() of
            FieldType::Decimal:
                if FieldRow."Decimal Places" <> '' then
                    exit(Format(FieldRef.Value(), 0, StrSubstNo(this.DecimalFormatTok, FieldRow."Decimal Places")));
            FieldType::Blob, FieldType::Media, FieldType::MediaSet:
                exit(this.PictureText(FieldRef));
        end;
        // Format of an option gives its caption in the session language.
        exit(Format(FieldRef.Value()));
    end;

    /// <summary>
    /// Returns the placeholder for a picture. A blob always has one. A media or media set has one only when it
    /// holds a picture, so an empty field shows nothing.
    /// </summary>
    /// <param name="FieldRef">The blob, media or media set field.</param>
    /// <returns>The placeholder, or an empty text for an empty media field.</returns>
    local procedure PictureText(var FieldRef: FieldRef): Text
    var
        TempMedia: Record "Config. Media Buffer" temporary;
    begin
        case FieldRef.Type() of
            FieldType::Media:
                begin
                    TempMedia.Media := FieldRef.Value();
                    if not TempMedia.Media.HasValue() then
                        exit('');
                end;
            FieldType::MediaSet:
                begin
                    TempMedia."Media Set" := FieldRef.Value();
                    if TempMedia."Media Set".Count() = 0 then
                        exit('');
                end;
        end;
        exit(this.PictureLbl);
    end;

    /// <summary>Returns the caption of a Field row: its localized name, else its FieldName.</summary>
    /// <param name="FieldRow">The Field row.</param>
    /// <returns>The caption.</returns>
    procedure FieldCaption(var FieldRow: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        if FieldRow.LocalizedFieldName <> '' then
            exit(FieldRow.LocalizedFieldName);
        exit(FieldRow.FieldName);
    end;

    /// <summary>
    /// Fills a line format with the values of one record. [n] is the caption of the Field row
    /// with Order n + 1, and {n} is its value. Text outside the brackets is copied as it is.
    /// A bracket that names no row, or is not a number, stays as written. An unclosed bracket
    /// copies the rest of the text as it is.
    /// Example: with Order 1 = Item No. "A10" and Order 2 = Description "Pump", the format
    /// {0} - {1} gives A10 - Pump.
    /// </summary>
    /// <param name="LineFormat">The line format, for example {0} - {1}.</param>
    /// <param name="FieldRows">The rows of one service. Its filters are reset on exit.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <returns>The line text.</returns>
    procedure FormatLine(LineFormat: Text; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef): Text
    var
        Output: TextBuilder;
        Current: Text;
        Remainder: Text;
        Token: Text;
        Index: Integer;
        CloseAt: Integer;
    begin
        FieldRows.SetRange("Line Type", FieldRows."Line Type"::Field);
        Index := 1;
        while Index <= StrLen(LineFormat) do begin
            Current := CopyStr(LineFormat, Index, 1);
            if (Current = '[') or (Current = '{') then begin
                Remainder := CopyStr(LineFormat, Index + 1);
                CloseAt := StrPos(Remainder, this.ClosingBracket(Current));
                if CloseAt = 0 then begin
                    Output.Append(CopyStr(LineFormat, Index));
                    Index := StrLen(LineFormat) + 1;
                end else begin
                    Token := CopyStr(Remainder, 1, CloseAt - 1);
                    Output.Append(this.BracketText(Current, Token, FieldRows, SourceRef));
                    Index := Index + CloseAt + 1;
                end;
            end else begin
                Output.Append(Current);
                Index := Index + 1;
            end;
        end;
        FieldRows.Reset();
        exit(Output.ToText());
    end;

    /// <summary>Returns the operator that goes in front of a filter value for a comparison type.</summary>
    /// <param name="ComparisonType">The Filter Comparison Type of a row: 0 Equal, 1 NotEqual, 2 Less, 3 LessOrEqual, 4 Greater, 5 GreaterOrEqual.</param>
    /// <returns>The operator in front of a filter value. Equal, Own and NotOwn give an empty text.</returns>
    procedure ComparisonPrefix(ComparisonType: Integer): Text
    begin
        case ComparisonType of
            1:
                exit('<>');
            2:
                exit('<');
            3:
                exit('<=');
            4:
                exit('>');
            5:
                exit('>=');
            else
                exit('');
        end;
    end;

    /// <summary>Returns the text of one bracket: its caption for [n], its value for {n}.</summary>
    /// <param name="OpenChar">The opening bracket, [ or {.</param>
    /// <param name="Token">The text between the brackets.</param>
    /// <param name="FieldRows">The rows of one service, filtered on Field.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <returns>The caption or value, or the bracket text as written when it names no row.</returns>
    local procedure BracketText(OpenChar: Text; Token: Text; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef): Text
    var
        Number: Integer;
    begin
        if (Token = '') or not Evaluate(Number, Token) then
            exit(OpenChar + Token + this.ClosingBracket(OpenChar));

        FieldRows.SetRange(FieldRows.Order, Number + 1);
        if not FieldRows.FindFirst() then
            exit(OpenChar + Token + this.ClosingBracket(OpenChar));

        if OpenChar = '[' then
            exit(this.FieldCaption(FieldRows));
        exit(this.FieldValue(FieldRows, SourceRef));
    end;

    /// <summary>Returns the closing bracket that goes with an opening bracket.</summary>
    /// <param name="OpenChar">The opening bracket, [ or {.</param>
    /// <returns>The closing bracket.</returns>
    local procedure ClosingBracket(OpenChar: Text): Text
    begin
        if OpenChar = '[' then
            exit(']');
        exit('}');
    end;

    /// <summary>Tells whether a field name and an element name are the same element, ignoring case.</summary>
    /// <param name="FieldName">The FieldName of a Field row, or the name of a table field.</param>
    /// <param name="ElementName">The element name to compare with.</param>
    /// <returns>True when ElementName is the element name of FieldName.</returns>
    local procedure SameElement(FieldName: Text; ElementName: Text): Boolean
    var
        Soap: Codeunit "BJF MN Emulator Soap";
    begin
        exit(UpperCase(Soap.ElementName(FieldName)) = UpperCase(ElementName));
    end;

    /// <summary>Reads a text property of a JSON object, or '' when it is missing, not a value or null.</summary>
    /// <param name="Item">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <returns>The text of the property.</returns>
    local procedure JsonText(Item: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Item.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    var
        PageMissingErr: Label 'The page %1 of the service %2 is not in Page Metadata.', Comment = '%1 = the page ID, %2 = the Service Name';
        MatchFieldMissingErr: Label 'The match field %1 is not on the page.', Comment = '%1 = the field name of the match item';
        DecimalFormatTok: Label '<Precision,%1><Standard Format,0>', Locked = true;
        PictureLbl: Label '(picture)';
}

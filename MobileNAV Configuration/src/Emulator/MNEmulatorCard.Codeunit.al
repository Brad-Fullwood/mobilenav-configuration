namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Builds the card response of the device emulator for one record: its title, its field groups,
/// its drill-downs, its buttons, its staging and its layout effects. It reads the cached configuration
/// and the record. Nothing is written.
/// </summary>
codeunit 77729 "BJF MN Emulator Card"
{
    Access = Internal;
    Permissions = tabledata "BJF MN Emulator Setup" = r;

    /// <summary>
    /// Answers a card request. The record is the one at the position the list sent, so the card
    /// shows the record the user tapped. Without a position, it is the first record that holds the
    /// match items, or without match items the first record of the page in its view order. A page
    /// with no record shows a new card when it allows insert. The layout effects of the record hide
    /// fields, make fields read-only and replace captions in the card. When the request asks for live values and a connection exists, the values
    /// and the field control come from the page service, else from the record in process. A request with
    /// isNew true describes a record that does not exist yet: its values are blank, except the defaults
    /// in the defaults object, which are text keyed by FieldName. The position is ''.
    /// </summary>
    /// <param name="Request">The request JSON object, with the service, the position or the match items, the live flag, or isNew and defaults.</param>
    /// <returns>The card object: title, groups, drill-downs, actions, field control, commands, staging and layout.</returns>
    procedure CardJson(Request: JsonObject): JsonObject
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        TempRows: Record "MobileNAV Settings Buffer" temporary;
        TempFields: Record "MobileNAV Settings Buffer" temporary;
        TempRelations: Record "MobileNAV Settings Buffer" temporary;
        EmuSetup: Record "BJF MN Emulator Setup";
        Config: Codeunit "BJF MN Emulator Config";
        Records: Codeunit "BJF MN Emulator Records";
        EmuActions: Codeunit "BJF MN Emulator Actions";
        Layouts: Codeunit "BJF MN Emulator Layouts";
        SourceRef: RecordRef;
        Card: JsonObject;
        Layout: JsonObject;
        Staging: JsonObject;
        Groups: JsonArray;
        Drilldowns: JsonArray;
        CardActions: JsonArray;
        Match: JsonArray;
        GroupFields: List of [JsonObject];
        ServiceName: Text;
        Position: Text;
        CardCaption: Text;
        Title: Text;
        GroupCaption: Text;
        FieldControl: Text;
        LiveError: Text;
        Live: Boolean;
        IsNew: Boolean;
        StageCount: Integer;
    begin
        ServiceName := this.TextValue(Request, 'service');
        Position := this.TextValue(Request, 'position');
        Match := this.MatchValues(Request);
        IsNew := this.BoolValue(Request, 'isNew');
        if not Config.FindMain(ServiceName, TempMain) then
            Error(this.MissingServiceErr, ServiceName);
        Config.CopyRows(ServiceName, TempRows);
        Config.CopyRows(ServiceName, TempRelations);
        Config.CopyRows(ServiceName, TempFields);
        TempFields.SetCurrentKey("Service Name", "Line Type", "Order");
        TempFields.SetRange("Line Type", TempFields."Line Type"::Field);

        Records.OpenSource(TempMain, SourceRef);
        this.NewDefaults := this.DefaultsOf(Request);
        Title := this.PositionRecord(IsNew, Records, TempMain, TempRows, SourceRef, Position, Match);
        this.IsNewRecord := IsNew;

        CardCaption := this.CardCaptionOf(TempMain, ServiceName);

        StageCount := this.StagingFor(TempMain, ServiceName, Staging);

        Layout := Layouts.Evaluate(ServiceName, TempRows, SourceRef);

        GroupCaption := this.GeneralLbl;
        if TempFields.FindSet() then
            repeat
                this.AddRow(TempFields, TempRelations, SourceRef, Records, Layout, StageCount, Groups, GroupCaption, GroupFields, CardActions, Drilldowns);
            until TempFields.Next() = 0;
        this.CloseGroup(Groups, GroupCaption, GroupFields);

        Live := this.ApplyLiveRead(Request, ServiceName, SourceRef, Groups, FieldControl, LiveError);

        // A card read never writes. A missing setup row is read as its defaults and is not inserted.
        if not EmuSetup.Get(this.SetupKeyTok) then
            EmuSetup.Init();

        Card.Add('kind', 'card');
        Card.Add('service', ServiceName);
        Card.Add('caption', CardCaption);
        Card.Add('position', Position);
        Card.Add('isNew', IsNew);
        Card.Add('title', Title);
        Card.Add('groups', Groups);
        Card.Add('drilldowns', Drilldowns);
        Card.Add('actions', CardActions);
        Card.Add('fieldControl', FieldControl);
        Card.Add('commands', EmuActions.ParseFieldControl(FieldControl));
        Card.Add('live', Live);
        Card.Add('liveError', LiveError);
        Card.Add('staging', Staging);
        Card.Add('layout', Layout);
        Card.Add('writesAllowed', EmuSetup.WritesAllowed());
        exit(Card);
    end;

    /// <summary>Returns the caption of the card: the localized name of the page, else the service name.</summary>
    /// <param name="TempMain">The service's Main row.</param>
    /// <param name="ServiceName">The service of the card.</param>
    /// <returns>The caption text.</returns>
    local procedure CardCaptionOf(var TempMain: Record "MobileNAV Settings Buffer" temporary; ServiceName: Text): Text
    begin
        if TempMain.LocalizedName <> '' then
            exit(TempMain.LocalizedName);
        exit(ServiceName);
    end;

    /// <summary>
    /// Moves the source table to the record of the card. The position wins when the request has one,
    /// else the first record that holds the match items. The position is set to the record found.
    /// </summary>
    /// <param name="Records">The records codeunit.</param>
    /// <param name="SourceRef">The open source table, opened with OpenSource just before.</param>
    /// <param name="TempRows">The rows of the service, for the field numbers of the match items.</param>
    /// <param name="Position">The position of the request. Receives the position of the record found.</param>
    /// <param name="Match">The match items of the request.</param>
    local procedure FindRecord(Records: Codeunit "BJF MN Emulator Records"; var SourceRef: RecordRef; var TempRows: Record "MobileNAV Settings Buffer" temporary; var Position: Text; Match: JsonArray)
    begin
        if Position <> '' then begin
            if not Records.FindByPosition(SourceRef, Position) then
                Error(this.RecordGoneErr);
        end else
            if not Records.FindByMatch(TempRows, SourceRef, Match) then
                Error(this.MatchGoneErr);
        Position := Records.Position(SourceRef);
    end;

    /// <summary>
    /// Moves the source table to the record of the card and returns its title. A new card has no record:
    /// the source is initialised, the title is blank and the position stays ''. A request with neither a
    /// position nor match items shows the first record of the page, or a new card when the page has none.
    /// </summary>
    /// <param name="IsNew">Whether the card is for a record that does not exist yet. Receives true when the page has no record and allows insert.</param>
    /// <param name="Records">The records codeunit.</param>
    /// <param name="TempMain">The service's Main row, for the title format and the insert flag.</param>
    /// <param name="TempRows">The rows of the service.</param>
    /// <param name="SourceRef">The open source table, opened with OpenSource just before.</param>
    /// <param name="Position">The position of the request. Receives the position of the record found.</param>
    /// <param name="Match">The match items of the request.</param>
    /// <returns>The title of the record, or '' for a new card.</returns>
    local procedure PositionRecord(var IsNew: Boolean; Records: Codeunit "BJF MN Emulator Records"; var TempMain: Record "MobileNAV Settings Buffer" temporary; var TempRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var Position: Text; Match: JsonArray): Text
    begin
        if IsNew then begin
            SourceRef.Init();
            exit('');
        end;
        if (Position = '') and (Match.Count() = 0) then begin
            this.FirstRecord(IsNew, Records, TempMain, SourceRef, Position);
            if IsNew then
                exit('');
        end else
            this.FindRecord(Records, SourceRef, TempRows, Position, Match);
        exit(Records.FormatLine(TempMain."First Line Format", TempRows, SourceRef));
    end;

    /// <summary>
    /// Moves the source table to the first record of the page, in the order and with the filters of its
    /// SourceTableView. When the page has no record, the card is a new card if the page allows insert,
    /// else the request is an error.
    /// </summary>
    /// <param name="IsNew">Receives true when the page has no record and allows insert.</param>
    /// <param name="Records">The records codeunit.</param>
    /// <param name="TempMain">The service's Main row, for the insert flag.</param>
    /// <param name="SourceRef">The open source table, opened with OpenSource just before.</param>
    /// <param name="Position">Receives the position of the first record.</param>
    local procedure FirstRecord(var IsNew: Boolean; Records: Codeunit "BJF MN Emulator Records"; var TempMain: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var Position: Text)
    begin
        if SourceRef.FindFirst() then begin
            Position := Records.Position(SourceRef);
            exit;
        end;
        if not TempMain."Page Insert" then
            Error(this.NoRecordErr);
        IsNew := true;
        SourceRef.Init();
    end;

    /// <summary>
    /// Reads the record through the page service when the request asks for live values. On success the
    /// field values come from the entity, and the field control is the entity's FieldControl element.
    /// A new card is never read live, because it has no record.
    /// </summary>
    /// <param name="Request">The request JSON object, with the live flag.</param>
    /// <param name="ServiceName">The service of the card.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="Groups">The groups of the card. Its field values are replaced on success.</param>
    /// <param name="FieldControl">Receives the field control of the entity on success.</param>
    /// <param name="LiveError">Receives the reason when the live read fails.</param>
    /// <returns>True when the live values were read.</returns>
    local procedure ApplyLiveRead(Request: JsonObject; ServiceName: Text; var SourceRef: RecordRef; var Groups: JsonArray; var FieldControl: Text; var LiveError: Text): Boolean
    var
        Entity: XmlElement;
    begin
        if this.IsNewRecord then
            exit(false);
        if not this.BoolValue(Request, 'live') then
            exit(false);
        if not this.ReadLive(ServiceName, SourceRef, Entity, LiveError) then
            exit(false);
        this.ApplyLiveValues(Groups, Entity);
        FieldControl := this.EntityText(Entity, 'FieldControl');
        exit(true);
    end;

    /// <summary>
    /// Reads the record through the page service of the MobileNAV page. The token gate comes first:
    /// without a token nothing is sent, and the error says how to connect.
    /// </summary>
    /// <param name="ServiceName">The service whose page service is read.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="Entity">Receives the entity element of the page service.</param>
    /// <param name="LiveError">Receives the reason when the live read fails. Empty on success.</param>
    /// <returns>True when the entity was read.</returns>
    local procedure ReadLive(ServiceName: Text; var SourceRef: RecordRef; var Entity: XmlElement; var LiveError: Text): Boolean
    var
        EmuToken: Codeunit "BJF MN Emulator Token";
        Soap: Codeunit "BJF MN Emulator Soap";
        AccessToken: SecretText;
    begin
        if not EmuToken.TryGetToken(AccessToken) then begin
            LiveError := this.NotConnectedErr;
            exit(false);
        end;
        if Soap.ReadByRecId(ServiceName, SourceRef.RecordId(), Entity) then
            exit(true);
        LiveError := Soap.LastError();
        exit(false);
    end;

    /// <summary>
    /// Replaces the value of each field object with the value from the page service entity, for every
    /// field whose element the entity holds. A field without that element keeps its value from the record.
    /// </summary>
    /// <param name="Groups">The groups of the card. Its field objects are changed in place.</param>
    /// <param name="Entity">The entity element read through the page service.</param>
    local procedure ApplyLiveValues(var Groups: JsonArray; Entity: XmlElement)
    var
        Soap: Codeunit "BJF MN Emulator Soap";
        GroupToken: JsonToken;
        GroupFieldsToken: JsonToken;
        FieldToken: JsonToken;
        FieldObj: JsonObject;
        Element: Text;
    begin
        foreach GroupToken in Groups do
            if GroupToken.AsObject().Get('fields', GroupFieldsToken) then
                foreach FieldToken in GroupFieldsToken.AsArray() do begin
                    FieldObj := FieldToken.AsObject();
                    Element := Soap.ElementName(this.TextValue(FieldObj, 'name'));
                    if this.HasElement(Entity, Element) then
                        this.PutValue(FieldObj, Soap.EntityValue(Entity, Element));
                end;
    end;

    /// <summary>Sets the value of a field object, adding the key when the object does not have it yet.</summary>
    /// <param name="FieldObj">The field object. Changed in place.</param>
    /// <param name="Value">The value to store.</param>
    local procedure PutValue(var FieldObj: JsonObject; Value: Text)
    begin
        if FieldObj.Contains('value') then
            FieldObj.Replace('value', Value)
        else
            FieldObj.Add('value', Value);
    end;

    /// <summary>Tells whether the entity has a child element with the given local name.</summary>
    /// <param name="Entity">The entity element.</param>
    /// <param name="Element">The local name of the child element.</param>
    /// <returns>True when the child element exists.</returns>
    local procedure HasElement(Entity: XmlElement; Element: Text): Boolean
    var
        Node: XmlNode;
    begin
        exit(Entity.SelectSingleNode(StrSubstNo(this.ElementXPathTok, Element), Node));
    end;

    /// <summary>Returns the text of a child element of the entity, or '' when the element is missing.</summary>
    /// <param name="Entity">The entity element.</param>
    /// <param name="Element">The local name of the child element.</param>
    /// <returns>The inner text of the element.</returns>
    local procedure EntityText(Entity: XmlElement; Element: Text): Text
    var
        Soap: Codeunit "BJF MN Emulator Soap";
    begin
        if not this.HasElement(Entity, Element) then
            exit('');
        exit(Soap.EntityValue(Entity, Element));
    end;

    /// <summary>Reads the match items of a card request, or an empty array when there are none.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The match items: objects with a field and a value.</returns>
    local procedure MatchValues(Request: JsonObject): JsonArray
    var
        Token: JsonToken;
        Matches: JsonArray;
    begin
        if not Request.Get('match', Token) then
            exit(Matches);
        if not Token.IsArray() then
            exit(Matches);
        exit(Token.AsArray());
    end;

    /// <summary>
    /// Builds the staging object of the card and returns the number of stages the field tokens use.
    /// Staging is on when the service enables it and has at least one Stage row.
    /// </summary>
    /// <param name="TempMain">The service's Main row.</param>
    /// <param name="ServiceName">The service of the card.</param>
    /// <param name="Staging">Receives the staging object.</param>
    /// <returns>The number of stages, 0 when staging is off.</returns>
    local procedure StagingFor(var TempMain: Record "MobileNAV Settings Buffer" temporary; ServiceName: Text; var Staging: JsonObject): Integer
    var
        TempStages: Record "MobileNAV Settings Buffer" temporary;
        Config: Codeunit "BJF MN Emulator Config";
        StagingOn: Boolean;
        StageCount: Integer;
    begin
        Config.CopyRows(ServiceName, TempStages);
        TempStages.SetRange("Line Type", TempStages."Line Type"::Stage);
        StagingOn := TempMain."Enable Staging" and not TempStages.IsEmpty();
        StageCount := 0;
        if StagingOn then
            StageCount := TempStages.Count();
        Staging := this.StagingJson(TempMain, TempStages, StagingOn);
        exit(StageCount);
    end;

    /// <summary>
    /// Builds the staging object of the card: whether staging is on, the behaviour, the Auto Next and
    /// Back-Next flags, and the stages in their buffer order. The stages are empty when staging is off.
    /// </summary>
    /// <param name="TempMain">The service's Main row.</param>
    /// <param name="TempStages">The Stage rows of the service. The caller sets the filter on the line type.</param>
    /// <param name="StagingOn">True when staging is enabled and the service has at least one stage.</param>
    /// <returns>The staging object.</returns>
    local procedure StagingJson(var TempMain: Record "MobileNAV Settings Buffer" temporary; var TempStages: Record "MobileNAV Settings Buffer" temporary; StagingOn: Boolean): JsonObject
    var
        Staging: JsonObject;
        StageArray: JsonArray;
    begin
        if StagingOn then
            if TempStages.FindSet() then
                repeat
                    StageArray.Add(this.StageJson(TempStages));
                until TempStages.Next() = 0;
        Staging.Add('enabled', StagingOn);
        Staging.Add('behavior', Format(TempMain."Staging Behavior"));
        Staging.Add('autoNext', TempMain."Auto Next Stage");
        Staging.Add('backNextVisible', TempMain."Back-Next Visible");
        Staging.Add('stages', StageArray);
        exit(Staging);
    end;

    /// <summary>Builds one stage object of the staging object. The caption is the stage code.</summary>
    /// <param name="StageRow">The Stage row, positioned on the stage.</param>
    /// <returns>The stage object with its code, caption and restart flag.</returns>
    local procedure StageJson(var StageRow: Record "MobileNAV Settings Buffer" temporary): JsonObject
    var
        StageObj: JsonObject;
    begin
        StageObj.Add('code', StageRow.Stage);
        StageObj.Add('caption', StageRow.Stage);
        StageObj.Add('restartFrom', StageRow."Staging Restart From");
        exit(StageObj);
    end;

    /// <summary>
    /// Reads the layout effects of one card field: its hidden flag, read-only flag and caption. The layout
    /// effects keep one object per field name under the fields property.
    /// </summary>
    /// <param name="Layout">The layout effects of the record.</param>
    /// <param name="FieldName">The FieldName of the field.</param>
    /// <returns>The effects object of the field, or an empty object when no layout touches the field.</returns>
    local procedure LayoutField(Layout: JsonObject; FieldName: Text): JsonObject
    var
        FieldsToken: JsonToken;
        FieldToken: JsonToken;
        NoEffects: JsonObject;
    begin
        if not Layout.Get('fields', FieldsToken) then
            exit(NoEffects);
        if not FieldsToken.AsObject().Get(FieldName, FieldToken) then
            exit(NoEffects);
        exit(FieldToken.AsObject());
    end;

    /// <summary>
    /// Sorts one Field row into the card: a group marker opens a new group, a navigation row becomes
    /// a drill-down, and every other visible row becomes a field, and a button also an action. A row
    /// that a layout hides is left out.
    /// </summary>
    /// <param name="FieldRow">The Field row, positioned on it.</param>
    /// <param name="Relations">The rows of the service, for the relations of the rows.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="Records">The records codeunit, for captions and values.</param>
    /// <param name="Layout">The layout effects of the record.</param>
    /// <param name="StageCount">The number of stages, 0 when staging is off.</param>
    /// <param name="Groups">Receives the closed groups.</param>
    /// <param name="GroupCaption">The caption of the open group.</param>
    /// <param name="GroupFields">The field objects of the open group.</param>
    /// <param name="CardActions">Receives the action objects.</param>
    /// <param name="Drilldowns">Receives the drill-down objects.</param>
    local procedure AddRow(var FieldRow: Record "MobileNAV Settings Buffer" temporary; var Relations: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; Records: Codeunit "BJF MN Emulator Records"; Layout: JsonObject; StageCount: Integer; var Groups: JsonArray; var GroupCaption: Text; var GroupFields: List of [JsonObject]; var CardActions: JsonArray; var Drilldowns: JsonArray)
    begin
        if not FieldRow.Visible then
            exit;
        if this.IsGroupRow(FieldRow) then begin
            this.CloseGroup(Groups, GroupCaption, GroupFields);
            GroupCaption := '';
            if FieldRow.FieldClass = FieldRow.FieldClass::GroupStart then
                GroupCaption := Records.FieldCaption(FieldRow);
            exit;
        end;
        if this.BoolValue(this.LayoutField(Layout, FieldRow.FieldName), 'hidden') then
            exit;
        if FieldRow.DisplayInMenu then begin
            this.AddDrilldown(FieldRow, Relations, Records, Drilldowns);
            exit;
        end;
        GroupFields.Add(this.FieldJson(FieldRow, Relations, SourceRef, Records, Layout, StageCount));
        if FieldRow."Function Name" <> '' then
            CardActions.Add(this.ActionJson(FieldRow, Records));
    end;

    /// <summary>Adds the open group to the groups when it holds fields, then empties it.</summary>
    /// <param name="Groups">Receives the group object.</param>
    /// <param name="GroupCaption">The caption of the open group.</param>
    /// <param name="GroupFields">The field objects of the open group. Emptied on exit.</param>
    local procedure CloseGroup(var Groups: JsonArray; GroupCaption: Text; var GroupFields: List of [JsonObject])
    begin
        if GroupFields.Count() > 0 then
            Groups.Add(this.GroupJson(GroupCaption, GroupFields));
        Clear(GroupFields);
    end;

    /// <summary>Tells whether a row is a group marker, a group start or a group end.</summary>
    /// <param name="FieldRow">The Field row to test.</param>
    /// <returns>True for a GroupStart or GroupEnd row.</returns>
    local procedure IsGroupRow(var FieldRow: Record "MobileNAV Settings Buffer" temporary): Boolean
    begin
        exit((FieldRow.FieldClass = FieldRow.FieldClass::GroupStart) or (FieldRow.FieldClass = FieldRow.FieldClass::GroupEnd));
    end;

    /// <summary>Builds one group object from the field objects collected for it.</summary>
    /// <param name="GroupCaption">The caption of the group. '' for a group after a group end.</param>
    /// <param name="GroupFields">The field objects of the group, in card order.</param>
    /// <returns>The group object with its caption and fields.</returns>
    local procedure GroupJson(GroupCaption: Text; GroupFields: List of [JsonObject]): JsonObject
    var
        GroupObj: JsonObject;
        FieldArray: JsonArray;
        FieldObject: JsonObject;
    begin
        foreach FieldObject in GroupFields do
            FieldArray.Add(FieldObject);
        GroupObj.Add('caption', GroupCaption);
        GroupObj.Add('fields', FieldArray);
        exit(GroupObj);
    end;

    /// <summary>
    /// Builds one field object of a card. Its relation decides whether the field is a lookup, a
    /// drill-down to another service, or neither. The layout makes the field read-only when it says so,
    /// and replaces the caption when it sets one. The staging tokens are sent as the card has them, and the
    /// UI hides and locks fields per stage.
    /// </summary>
    /// <param name="FieldRow">The Field row, positioned on the field.</param>
    /// <param name="Relations">The rows of the service, for the relation of the field.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="Records">The records codeunit, for captions and values.</param>
    /// <param name="Layout">The layout effects of the record.</param>
    /// <param name="StageCount">The number of stages, 0 when staging is off. The token list is padded to this count.</param>
    /// <returns>The field object.</returns>
    local procedure FieldJson(var FieldRow: Record "MobileNAV Settings Buffer" temporary; var Relations: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; Records: Codeunit "BJF MN Emulator Records"; Layout: JsonObject; StageCount: Integer): JsonObject
    var
        FieldObj: JsonObject;
        Drill: JsonObject;
        FieldEffects: JsonObject;
        IsEditable: Boolean;
        IsLookup: Boolean;
        HasDrill: Boolean;
    begin
        this.FieldRelation(FieldRow, Relations, Drill, IsLookup, HasDrill);
        FieldEffects := this.LayoutField(Layout, FieldRow.FieldName);
        IsEditable := FieldRow.Editable and not this.BoolValue(Layout, 'pageReadOnly') and not this.BoolValue(FieldEffects, 'readOnly');

        FieldObj.Add('name', FieldRow.FieldName);
        FieldObj.Add('caption', this.FieldCaptionText(Records, FieldRow, FieldEffects));
        FieldObj.Add('value', this.FieldText(FieldRow, Records, SourceRef));
        FieldObj.Add('mobileType', Format(FieldRow.MobileType));
        FieldObj.Add('fieldType', Format(FieldRow.FieldType));
        FieldObj.Add('editable', IsEditable);
        FieldObj.Add('mandatory', Format(FieldRow.Mandatory));
        FieldObj.Add('stage', FieldRow.Stage);
        FieldObj.Add('stages', this.StageTokens(FieldRow.Stage, StageCount));
        FieldObj.Add('quantityIncrement', this.QuantityIncrementOf(FieldRow));
        FieldObj.Add('decimalPlaces', FieldRow."Decimal Places");
        FieldObj.Add('minValue', FieldRow.SourceFieldName);
        FieldObj.Add('maxValue', FieldRow.DestFieldName);
        FieldObj.Add('requiredForInsert', FieldRow."Required for Insert");
        FieldObj.Add('blob', this.IsBlobField(FieldRow));
        FieldObj.Add('functionType', Format(FieldRow."Function Type"));
        if HasDrill then
            FieldObj.Add('drill', Drill)
        else
            FieldObj.Add('drill', this.NullValue());
        FieldObj.Add('lookup', IsLookup);
        FieldObj.Add('button', FieldRow."Function Name" <> '');
        FieldObj.Add('functionName', FieldRow."Function Name");
        exit(FieldObj);
    end;

    /// <summary>
    /// Reads the relation of a field. A relation with a code and a description field makes a lookup. Any
    /// other relation makes a drill-down, when its related service is in the cached configuration.
    /// </summary>
    /// <param name="FieldRow">The Field row, positioned on the field.</param>
    /// <param name="Relations">The rows of the service. Its filters are set by this procedure.</param>
    /// <param name="Drill">Receives the drill-down object when the field has one.</param>
    /// <param name="IsLookup">Receives true for a lookup field.</param>
    /// <param name="HasDrill">Receives true for a field with a drill-down.</param>
    local procedure FieldRelation(var FieldRow: Record "MobileNAV Settings Buffer" temporary; var Relations: Record "MobileNAV Settings Buffer" temporary; var Drill: JsonObject; var IsLookup: Boolean; var HasDrill: Boolean)
    var
        TempScratchMain: Record "MobileNAV Settings Buffer" temporary;
        Config: Codeunit "BJF MN Emulator Config";
    begin
        if not this.FindRelation(Relations, FieldRow."Page Line No.") then
            exit;
        if (Relations.RelatedPgCodeFldName <> '') and (Relations.RelatedPgDescFldName <> '') then begin
            IsLookup := true;
            exit;
        end;
        if not Config.FindMain(Relations.RelatedPageName, TempScratchMain) then
            exit;
        Drill.Add('service', Relations.RelatedPageName);
        Drill.Add('field', FieldRow.FieldName);
        HasDrill := true;
    end;

    /// <summary>
    /// Returns the caption of a card field: the layout caption when the layout sets one, else the caption
    /// of the field.
    /// </summary>
    /// <param name="Records">The records codeunit, for the caption.</param>
    /// <param name="FieldRow">The Field row, positioned on the field.</param>
    /// <param name="FieldEffects">The layout effects of the field.</param>
    /// <returns>The caption text.</returns>
    local procedure FieldCaptionText(Records: Codeunit "BJF MN Emulator Records"; var FieldRow: Record "MobileNAV Settings Buffer" temporary; FieldEffects: JsonObject): Text
    begin
        if this.TextValue(FieldEffects, 'caption') <> '' then
            exit(this.TextValue(FieldEffects, 'caption'));
        exit(Records.FieldCaption(FieldRow));
    end;

    /// <summary>
    /// Returns the quantity increment of a field. A Quantity field with no increment steps by 1.
    /// </summary>
    /// <param name="FieldRow">The Field row, positioned on the field.</param>
    /// <returns>The quantity increment, 0 for a field that has none.</returns>
    local procedure QuantityIncrementOf(var FieldRow: Record "MobileNAV Settings Buffer" temporary): Decimal
    begin
        if (FieldRow."Quantity Increment" = 0) and (FieldRow.MobileType = FieldRow.MobileType::Quantity) then
            exit(1);
        exit(FieldRow."Quantity Increment");
    end;

    /// <summary>
    /// Splits the stage token list of a field into one token per stage. A stage without a token is
    /// hidden (H), as the device treats a field that has no token for a stage.
    /// </summary>
    /// <param name="Tokens">The Stage text of the Field row: one token per stage, separated by commas.</param>
    /// <param name="StageCount">The number of stages. 0 when staging is off, which gives an empty array.</param>
    /// <returns>The tokens: '' editable, R read-only, H hidden.</returns>
    local procedure StageTokens(Tokens: Text; StageCount: Integer): JsonArray
    var
        TokenArray: JsonArray;
        CommaCount: Integer;
        TokenCount: Integer;
        Index: Integer;
    begin
        if StageCount = 0 then
            exit(TokenArray);
        if Tokens <> '' then begin
            CommaCount := StrLen(Tokens) - StrLen(DelChr(Tokens, '=', ','));
            TokenCount := CommaCount + 1;
        end;
        for Index := 1 to TokenCount do
            TokenArray.Add(DelChr(SelectStr(Index, Tokens), '<>', ' '));
        for Index := TokenCount + 1 to StageCount do
            TokenArray.Add('H');
        exit(TokenArray);
    end;

    /// <summary>
    /// Tells whether a field holds a picture, a signature or a file, which the device sends as a blob.
    /// </summary>
    /// <param name="FieldRow">The Field row, positioned on the field.</param>
    /// <returns>True for the image, PDF, signature, Excel and file MobileTypes.</returns>
    local procedure IsBlobField(var FieldRow: Record "MobileNAV Settings Buffer" temporary): Boolean
    begin
        exit(FieldRow.MobileType in [FieldRow.MobileType::Image, FieldRow.MobileType::PDF, FieldRow.MobileType::Signature,
                                     FieldRow.MobileType::Excel, FieldRow.MobileType::CacheableImage, FieldRow.MobileType::"File",
                                     FieldRow.MobileType::CacheablePDF, FieldRow.MobileType::CacheableFile, FieldRow.MobileType::CacheableExcel]);
    end;

    /// <summary>Builds one action object for a button row.</summary>
    /// <param name="FieldRow">The button row, positioned on the button.</param>
    /// <param name="Records">The records codeunit, for the caption.</param>
    /// <returns>The action object with the field, its caption and its function name.</returns>
    local procedure ActionJson(var FieldRow: Record "MobileNAV Settings Buffer" temporary; Records: Codeunit "BJF MN Emulator Records"): JsonObject
    var
        ButtonObject: JsonObject;
    begin
        ButtonObject.Add('field', FieldRow.FieldName);
        ButtonObject.Add('caption', Records.FieldCaption(FieldRow));
        ButtonObject.Add('functionName', FieldRow."Function Name");
        this.AddActionIcon(FieldRow, ButtonObject);
        exit(ButtonObject);
    end;

    /// <summary>
    /// Adds the icon of a button, as the app chooses it (CardToolbarItemCollector): a PDF, Excel, image or signature
    /// field has its own icon, a field with a menu picture shows the picture, and any other button the function icon.
    /// A button with a picture gets no icon code, so the emulator draws the picture.
    /// </summary>
    /// <param name="FieldRow">The button row, positioned on the button.</param>
    /// <param name="ButtonObject">The action object. Receives icon, or picture and pictureType.</param>
    local procedure AddActionIcon(var FieldRow: Record "MobileNAV Settings Buffer" temporary; var ButtonObject: JsonObject)
    var
        Pictures: Codeunit "BJF MN Emulator Pictures";
        IconCode: Text;
    begin
        IconCode := this.TypeIconCode(FieldRow);
        if IconCode <> '' then begin
            ButtonObject.Add('icon', IconCode);
            exit;
        end;
        if FieldRow."Menu Picture Version" > 0 then
            Pictures.AddButtonPicture(FieldRow."Service Name", FieldRow.FieldName, ButtonObject);
        if not ButtonObject.Contains('picture') then
            ButtonObject.Add('icon', 'function_call');
    end;

    /// <summary>Returns the app icon code of a field type that has its own icon.</summary>
    /// <param name="FieldRow">The button row, positioned on the button.</param>
    /// <returns>The icon code: ea_pdf, ea_excel, ea_gallery or signature, or '' for the other field types.</returns>
    local procedure TypeIconCode(var FieldRow: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        case FieldRow.MobileType of
            FieldRow.MobileType::PDF:
                exit('ea_pdf');
            FieldRow.MobileType::Excel:
                exit('ea_excel');
            FieldRow.MobileType::Image, FieldRow.MobileType::CacheableImage:
                exit('ea_gallery');
            FieldRow.MobileType::Signature:
                exit('signature');
        end;
        exit('');
    end;

    /// <summary>
    /// Adds a navigation row (Display In Menu) to the drill-downs, when its relation leads to a
    /// service in the cached configuration.
    /// </summary>
    /// <param name="FieldRow">The navigation row, positioned on it.</param>
    /// <param name="Relations">The rows of the service, for the relation of the row.</param>
    /// <param name="Records">The records codeunit, for the caption.</param>
    /// <param name="Drilldowns">Receives the drill-down object.</param>
    local procedure AddDrilldown(var FieldRow: Record "MobileNAV Settings Buffer" temporary; var Relations: Record "MobileNAV Settings Buffer" temporary; Records: Codeunit "BJF MN Emulator Records"; var Drilldowns: JsonArray)
    var
        TempScratchMain: Record "MobileNAV Settings Buffer" temporary;
        Config: Codeunit "BJF MN Emulator Config";
        Drilldown: JsonObject;
    begin
        if not this.FindRelation(Relations, FieldRow."Page Line No.") then
            exit;
        if not Config.FindMain(Relations.RelatedPageName, TempScratchMain) then
            exit;
        Drilldown.Add('field', FieldRow.FieldName);
        Drilldown.Add('caption', Records.FieldCaption(FieldRow));
        Drilldown.Add('service', Relations.RelatedPageName);
        Drilldowns.Add(Drilldown);
    end;

    /// <summary>
    /// Finds the Relation row that belongs to a Field row: the Relation row with the same Page Line No.
    /// </summary>
    /// <param name="Relations">The rows of one service. Its filters are set by this procedure.</param>
    /// <param name="PageLineNo">The Page Line No. of the Field row.</param>
    /// <returns>True when a Relation row exists. The row is the current record of Relations.</returns>
    local procedure FindRelation(var Relations: Record "MobileNAV Settings Buffer" temporary; PageLineNo: Integer): Boolean
    begin
        Relations.SetRange("Line Type", Relations."Line Type"::Relation);
        Relations.SetRange("Page Line No.", PageLineNo);
        exit(Relations.FindFirst());
    end;

    /// <summary>Returns a JSON null, for the drill field of a field without a drill-down.</summary>
    /// <returns>A null JSON value.</returns>
    local procedure NullValue(): JsonValue
    var
        NullJson: JsonValue;
    begin
        NullJson.SetValueToNull();
        exit(NullJson);
    end;

    /// <summary>Reads a text property of the request, or '' when it is missing or not a value.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <returns>The text of the property.</returns>
    local procedure TextValue(Request: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Request.Get(PropertyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Reads a boolean property of the request, or false when it is missing, not a value or null.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <returns>The boolean of the property.</returns>
    local procedure BoolValue(Request: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if not Request.Get(PropertyName, Token) then
            exit(false);
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>
    /// Reads the display value of a field. A record that does not exist yet shows its default, or blank.
    /// </summary>
    /// <param name="FieldRow">The Field row.</param>
    /// <param name="Records">The records codeunit.</param>
    /// <param name="SourceRef">The open source table.</param>
    /// <returns>The display value.</returns>
    local procedure FieldText(var FieldRow: Record "MobileNAV Settings Buffer" temporary; Records: Codeunit "BJF MN Emulator Records"; var SourceRef: RecordRef): Text
    var
        DefaultToken: JsonToken;
    begin
        if not this.IsNewRecord then
            exit(Records.FieldValue(FieldRow, SourceRef));
        if this.NewDefaults.Get(FieldRow.FieldName, DefaultToken) then
            exit(DefaultToken.AsValue().AsText());
        exit('');
    end;

    /// <summary>Reads the defaults object of a card request, or an empty object when it has none.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The defaults object.</returns>
    local procedure DefaultsOf(Request: JsonObject): JsonObject
    var
        Token: JsonToken;
        NoDefaults: JsonObject;
    begin
        if not Request.Get('defaults', Token) then
            exit(NoDefaults);
        if not Token.IsObject() then
            exit(NoDefaults);
        exit(Token.AsObject());
    end;

    var
        IsNewRecord: Boolean;
        NewDefaults: JsonObject;
        GeneralLbl: Label 'General';
        NoRecordErr: Label 'The page has no record to show.';
        MissingServiceErr: Label 'The service %1 has no Main row in the loaded configuration.', Comment = '%1 = the Service Name of the card request';
        RecordGoneErr: Label 'The record at this position no longer exists. Reload the list.';
        MatchGoneErr: Label 'No record matches the match items of the card request. Reload the list.';
        NotConnectedErr: Label 'The emulator is not connected to Business Central, so the live values are not read. Connect it on the emulator setup page first.';
        ElementXPathTok: Label '*[local-name()=''%1'']', Locked = true;
        SetupKeyTok: Label 'SETUP', Locked = true;
}

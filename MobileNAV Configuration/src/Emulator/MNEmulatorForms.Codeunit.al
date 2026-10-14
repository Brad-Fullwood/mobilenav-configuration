namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Answers the device emulator requests that make a new record or run a dialog: newCard, create and
/// dialogRun. A new record takes its defaults from the parent of the list it was opened from, through
/// the list's relation filters. Create and dialogRun write through the MobileNAV page service, as a
/// device does, so both need the setup's Allow Writes.
/// </summary>
codeunit 77739 "BJF MN Emulator Forms"
{
    Access = Internal;

    /// <summary>
    /// Answers a newCard request. The card holds empty inputs, and each field that the parent's relation
    /// filters fix to one value shows that value. A dialog page (Page Type Report) also names the function
    /// service that its dialog runs in. Nothing is written.
    /// </summary>
    /// <param name="Request">The request: service, and parent when the list the user is on has one.</param>
    /// <returns>The card object, with kind newCard, isNew true and the dialog flags.</returns>
    procedure NewCardJson(Request: JsonObject): JsonObject
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        Card: Codeunit "BJF MN Emulator Card";
        CardRequest: JsonObject;
        Defaults: JsonObject;
        Response: JsonObject;
        ServiceName: Text;
        IsDialog: Boolean;
    begin
        ServiceName := this.ServiceOf(Request);
        this.LoadMain(ServiceName, TempMain);
        this.ParentDefaults(Request, ServiceName, Defaults);
        IsDialog := TempMain."Page Type" = TempMain."Page Type"::Report;

        CardRequest.Add('service', ServiceName);
        CardRequest.Add('isNew', true);
        CardRequest.Add('defaults', Defaults);
        Response := Card.CardJson(CardRequest);
        Response.Remove('kind');
        Response.Add('kind', 'newCard');
        Response.Add('dialog', IsDialog);
        if IsDialog then
            Response.Add('functionService', this.FunctionService(TempMain));
        exit(Response);
    end;

    /// <summary>
    /// Creates a record through the page service and answers with the card of the new record. The values
    /// are the parent defaults first, then the values of the request, which win. The field names become
    /// element names with the Soap codeunit.
    /// </summary>
    /// <param name="Request">The request: service, values by FieldName, and parent when the list has one.</param>
    /// <returns>The card object of the new record, with kind create and created true.</returns>
    procedure CreateJson(Request: JsonObject): JsonObject
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        Soap: Codeunit "BJF MN Emulator Soap";
        ActionsRun: Codeunit "BJF MN Emulator Actions";
        Records: Codeunit "BJF MN Emulator Records";
        Card: Codeunit "BJF MN Emulator Card";
        SourceRef: RecordRef;
        RecId: RecordId;
        Entity: XmlElement;
        CreateExchange: Text;
        Defaults: JsonObject;
        FieldValues: Dictionary of [Text, Text];
        Values: Dictionary of [Text, Text];
        CardRequest: JsonObject;
        Response: JsonObject;
        ServiceName: Text;
        FieldName: Text;
        WsKey: Text;
        Position: Text;
    begin
        this.RequireWrites();
        ServiceName := this.ServiceOf(Request);
        this.LoadMain(ServiceName, TempMain);
        this.ParentDefaults(Request, ServiceName, Defaults);
        this.CopyValues(Defaults, FieldValues);
        this.CopyValues(this.ObjectValue(Request, 'values'), FieldValues);
        foreach FieldName in FieldValues.Keys() do
            Values.Set(Soap.ElementName(FieldName), FieldValues.Get(FieldName));

        if not Soap.Create(ServiceName, Values, Entity) then
            exit(ActionsRun.SoapFailed(Request, 'create', Soap));
        CreateExchange := Soap.LastExchange();
        WsKey := Soap.EntityKey(Entity);
        if not Soap.RecIdFromKey(ServiceName, WsKey, RecId) then
            exit(ActionsRun.SoapFailed(Request, 'create', Soap));

        Records.OpenSource(TempMain, SourceRef);
        if not SourceRef.Get(RecId) then
            Error(this.CreatedMissingErr);
        Position := Records.Position(SourceRef);

        CardRequest.Add('service', ServiceName);
        CardRequest.Add('position', Position);
        Response := Card.CardJson(CardRequest);
        Response.Remove('kind');
        Response.Add('kind', 'create');
        Response.Add('created', true);
        ActionsRun.AddSoapExchange(Request, CreateExchange, Response);
        exit(Response);
    end;

    /// <summary>
    /// Runs a dialog page's function as a codeunit call on the function service of the page. The values are
    /// keyed by control name and go to the codeunit parameters by name. The answer is read the way a
    /// page function answer is read.
    /// </summary>
    /// <param name="Request">The request: service, functionName and values by control name.</param>
    /// <returns>The dialogRun object: fieldControl, commands, fileName, base64Result and message.</returns>
    procedure DialogRunJson(Request: JsonObject): JsonObject
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        Soap: Codeunit "BJF MN Emulator Soap";
        ActionsRun: Codeunit "BJF MN Emulator Actions";
        Values: Dictionary of [Text, Text];
        Response: JsonObject;
        ServiceName: Text;
        FunctionName: Text;
        FunctionServiceName: Text;
        ReturnValue: Text;
        FieldControl: Text;
        FileName: Text;
        Base64Result: Text;
    begin
        this.RequireWrites();
        ServiceName := this.ServiceOf(Request);
        FunctionName := this.TextValue(Request, 'functionName', '');
        if FunctionName = '' then
            Error(this.MissingFunctionErr);
        this.LoadMain(ServiceName, TempMain);
        FunctionServiceName := this.FunctionService(TempMain);
        this.CopyCodeunitValues(this.ObjectValue(Request, 'values'), Soap, Values);

        if not Soap.CallCodeunit(FunctionServiceName, FunctionName, Values, ReturnValue) then
            exit(ActionsRun.SoapFailed(Request, 'dialogRun', Soap));
        ActionsRun.ReadResult(ReturnValue, FieldControl, FileName, Base64Result);
        if (FileName = '') and (Base64Result <> '') then
            FileName := ActionsRun.DefaultFileName(FunctionName, Base64Result);

        Response.Add('kind', 'dialogRun');
        Response.Add('service', ServiceName);
        Response.Add('fieldControl', FieldControl);
        Response.Add('commands', ActionsRun.ParseFieldControl(FieldControl));
        Response.Add('fileName', FileName);
        Response.Add('base64Result', Base64Result);
        Response.Add('message', '');
        ActionsRun.AddSoapExchange(Request, Soap.LastExchange(), Response);
        exit(Response);
    end;

    /// <summary>Reads the service of a request. The request must name one.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The Service Name.</returns>
    local procedure ServiceOf(Request: JsonObject): Text
    var
        ServiceName: Text;
    begin
        ServiceName := this.TextValue(Request, 'service', '');
        if ServiceName = '' then
            Error(this.ServiceRequiredErr);
        exit(ServiceName);
    end;

    /// <summary>Copies the Main row of a service from the loaded configuration. Errors when it is not there.</summary>
    /// <param name="ServiceName">The service to find.</param>
    /// <param name="TempMain">Receives the Main row.</param>
    local procedure LoadMain(ServiceName: Text; var TempMain: Record "MobileNAV Settings Buffer" temporary)
    var
        Config: Codeunit "BJF MN Emulator Config";
    begin
        if not Config.FindMain(ServiceName, TempMain) then
            Error(this.ServiceNotFoundErr, ServiceName);
    end;

    /// <summary>Stops the request when the setup does not allow writes. The check is the one the actions codeunit makes.</summary>
    local procedure RequireWrites()
    var
        EmulatorSetup: Record "BJF MN Emulator Setup";
    begin
        EmulatorSetup.GetSetup();
        if not EmulatorSetup.WritesAllowed() then
            Error(this.WritesOffLbl);
    end;

    /// <summary>
    /// The function service of a dialog: the Main row's OptionValues2, else the MobileNAV report service.
    /// </summary>
    /// <param name="TempMain">The Main row of the dialog page.</param>
    /// <returns>The service name of the codeunit that runs the dialog function.</returns>
    local procedure FunctionService(var TempMain: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        if TempMain.OptionValues2 <> '' then
            exit(TempMain.OptionValues2);
        exit(this.ReportServiceLbl);
    end;

    /// <summary>
    /// Reads the defaults of a new record from its parent. The relation filters of the parent are applied to
    /// the child source, and each field whose filter names one value gives its default. Nothing is written.
    /// The filters are read in filter group 4, where the relation filters are set.
    /// </summary>
    /// <param name="Request">The request, with the parent object. Without a parent there are no defaults.</param>
    /// <param name="ServiceName">The child service.</param>
    /// <param name="Defaults">Receives the default text of each field, by FieldName.</param>
    local procedure ParentDefaults(Request: JsonObject; ServiceName: Text; var Defaults: JsonObject)
    var
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        TempFieldRows: Record "MobileNAV Settings Buffer" temporary;
        Config: Codeunit "BJF MN Emulator Config";
        Records: Codeunit "BJF MN Emulator Records";
        ListRun: Codeunit "BJF MN Emulator List";
        SourceRef: RecordRef;
    begin
        if this.TextValue(this.ObjectValue(Request, 'parent'), 'service', '') = '' then
            exit;
        this.LoadMain(ServiceName, TempMain);
        Config.CopyRows(ServiceName, TempFieldRows);
        Records.OpenSource(TempMain, SourceRef);
        ListRun.ApplyParent(Request, ServiceName, TempFieldRows, SourceRef);

        TempFieldRows.SetRange("Line Type", TempFieldRows."Line Type"::Field);
        SourceRef.FilterGroup(4);
        if TempFieldRows.FindSet() then
            repeat
                this.AddFilterDefault(SourceRef, TempFieldRows, Defaults);
            until TempFieldRows.Next() = 0;
        SourceRef.FilterGroup(0);
    end;

    /// <summary>Adds the default of one field from its filter in filter group 4, when the filter names one value.</summary>
    /// <param name="SourceRef">The child source table, with the relation filters in filter group 4.</param>
    /// <param name="FieldRow">The Field row.</param>
    /// <param name="Defaults">Receives the default text, by FieldName. A field already in it keeps its value.</param>
    local procedure AddFilterDefault(var SourceRef: RecordRef; var FieldRow: Record "MobileNAV Settings Buffer" temporary; var Defaults: JsonObject)
    var
        DefaultText: Text;
    begin
        if (FieldRow."Field No." = 0) or (FieldRow.FieldName = '') then
            exit;
        if Defaults.Contains(FieldRow.FieldName) then
            exit;
        if this.SingleValue(SourceRef.Field(FieldRow."Field No.").GetFilter(), DefaultText) then
            Defaults.Add(FieldRow.FieldName, DefaultText);
    end;

    /// <summary>
    /// Turns a filter text into the one value it names. A leading equals sign and surrounding quotes are
    /// removed. Ranges, lists and patterns name more than one value and give false.
    /// </summary>
    /// <param name="FilterText">The filter text of the field.</param>
    /// <param name="Value">Receives the value when the filter names one.</param>
    /// <returns>True when the filter names exactly one value.</returns>
    local procedure SingleValue(FilterText: Text; var Value: Text): Boolean
    begin
        Value := this.UnquotedFilter(FilterText);
        if Value = '' then
            exit(false);
        exit(not this.HasMultiValueMark(Value));
    end;

    /// <summary>Removes a leading equals sign and the quotes around a filter text.</summary>
    /// <param name="FilterText">The filter text.</param>
    /// <returns>The filter text without its equals sign and quotes.</returns>
    local procedure UnquotedFilter(FilterText: Text): Text
    var
        Value: Text;
    begin
        Value := FilterText;
        if Value.StartsWith('=') then
            Value := CopyStr(Value, 2);
        if (StrLen(Value) >= 2) and Value.StartsWith('''') and Value.EndsWith('''') then
            Value := CopyStr(Value, 2, StrLen(Value) - 2);
        exit(Value);
    end;

    /// <summary>Tells whether a value holds a range, a list or a pattern mark of a filter.</summary>
    /// <param name="Value">The value to test.</param>
    /// <returns>True when the value holds one of the marks.</returns>
    local procedure HasMultiValueMark(Value: Text): Boolean
    var
        Index: Integer;
    begin
        if Value.Contains('..') then
            exit(true);
        for Index := 1 to StrLen(this.MultiValueMarksTok) do
            if Value.Contains(CopyStr(this.MultiValueMarksTok, Index, 1)) then
                exit(true);
        exit(false);
    end;

    /// <summary>Copies the properties of a JSON object into a dictionary. A value that is not text gives ''.</summary>
    /// <param name="ValuesObject">The object to copy.</param>
    /// <param name="Values">Receives one entry for each property. An existing entry is replaced.</param>
    local procedure CopyValues(ValuesObject: JsonObject; var Values: Dictionary of [Text, Text])
    var
        PropertyName: Text;
        PropertyToken: JsonToken;
    begin
        foreach PropertyName in ValuesObject.Keys() do begin
            ValuesObject.Get(PropertyName, PropertyToken);
            Values.Set(PropertyName, this.TokenText(PropertyToken));
        end;
    end;

    /// <summary>
    /// Copies the dialog values for a codeunit call. Each value is keyed by its control name and also by
    /// the element name of that name, so a codeunit parameter matches either spelling. Soap.CallCodeunit
    /// matches the parameters by name, ignoring case.
    /// </summary>
    /// <param name="ValuesObject">The values object of the request, keyed by control name.</param>
    /// <param name="Soap">The Soap codeunit, which converts names to element names.</param>
    /// <param name="Values">Receives the values, keyed by control name and by element name.</param>
    local procedure CopyCodeunitValues(ValuesObject: JsonObject; var Soap: Codeunit "BJF MN Emulator Soap"; var Values: Dictionary of [Text, Text])
    var
        FieldValues: Dictionary of [Text, Text];
        ControlName: Text;
        ElementKey: Text;
    begin
        this.CopyValues(ValuesObject, FieldValues);
        foreach ControlName in FieldValues.Keys() do begin
            Values.Set(ControlName, FieldValues.Get(ControlName));
            ElementKey := Soap.ElementName(ControlName);
            if not Values.ContainsKey(ElementKey) then
                Values.Set(ElementKey, FieldValues.Get(ControlName));
        end;
    end;

    /// <summary>Reads the text of a JSON value token, or '' for a null or a non-value token.</summary>
    /// <param name="PropertyToken">The token to read.</param>
    /// <returns>The text of the value.</returns>
    local procedure TokenText(PropertyToken: JsonToken): Text
    begin
        if not PropertyToken.IsValue() then
            exit('');
        if PropertyToken.AsValue().IsNull() then
            exit('');
        exit(PropertyToken.AsValue().AsText());
    end;

    /// <summary>Reads a JSON object property of a request, or an empty object when it is missing or not an object.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <returns>The object of the property.</returns>
    local procedure ObjectValue(Request: JsonObject; PropertyName: Text): JsonObject
    var
        PropertyToken: JsonToken;
        NoObject: JsonObject;
    begin
        if not Request.Get(PropertyName, PropertyToken) then
            exit(NoObject);
        if not PropertyToken.IsObject() then
            exit(NoObject);
        exit(PropertyToken.AsObject());
    end;

    /// <summary>Reads a text property of a JSON object.</summary>
    /// <param name="Request">The JSON object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <param name="DefaultText">The value returned when the property is missing, not a value, or null.</param>
    /// <returns>The text of the property, or the default.</returns>
    local procedure TextValue(Request: JsonObject; PropertyName: Text; DefaultText: Text): Text
    var
        PropertyToken: JsonToken;
    begin
        if not Request.Get(PropertyName, PropertyToken) then
            exit(DefaultText);
        if not PropertyToken.IsValue() then
            exit(DefaultText);
        if PropertyToken.AsValue().IsNull() then
            exit(DefaultText);
        exit(PropertyToken.AsValue().AsText());
    end;

    var
        MissingFunctionErr: Label 'The request names no function.';
        ServiceNotFoundErr: Label 'The configuration has no page for the service %1.', Comment = '%1 = Service Name';
        ServiceRequiredErr: Label 'The request names no service.';
        CreatedMissingErr: Label 'The page service created the record, but the source table does not hold it. Reload the list.';
        WritesOffLbl: Label 'Writes to MobileNAV are off. Turn on Allow Writes on the MobileNAV Device Emulator page.';
        ReportServiceLbl: Label 'MobileNAVReport', Locked = true;
        MultiValueMarksTok: Label '|&<>*?@,', Locked = true;
}

namespace BradFullwood.MobileNAV.Configuration;

using System.Environment;

/// <summary>
/// Answers the emulator requests that change data or report the connection: a button press, a
/// field edit or scan, a dialog answer, and the connection state. A write goes to the tenant's own
/// SOAP page service of the MobileNAV page, as a device sends it, so the page triggers and the
/// [ServiceEnabled] functions run as on a device. The record is found in process by its position,
/// and its RecordId selects the entity in the service. The FieldControl of the answer becomes a
/// list of commands for the emulator page. Writes need the setup's Allow Writes.
/// </summary>
codeunit 77732 "BJF MN Emulator Actions"
{
    Access = Internal;

    /// <summary>
    /// Runs a button of the page. The page function named by the request runs on the record at the
    /// position, with the values the button sends.
    /// </summary>
    /// <param name="Request">The action request: service, position, field, functionName and values.</param>
    /// <returns>The action object with the field control, its commands and the file result.</returns>
    procedure ActionJson(Request: JsonObject): JsonObject
    var
        Soap: Codeunit "BJF MN Emulator Soap";
        SourceRef: RecordRef;
        Entity: XmlElement;
        Values: Dictionary of [Text, Text];
        Response: JsonObject;
        ServiceName: Text;
        Position: Text;
        FieldName: Text;
        FunctionName: Text;
        WsKey: Text;
        ReturnValue: Text;
        FieldControl: Text;
        FileName: Text;
        Base64Result: Text;
    begin
        ServiceName := this.TextValue(Request, 'service', '');
        Position := this.TextValue(Request, 'position', '');
        FieldName := this.TextValue(Request, 'field', '');
        FunctionName := this.TextValue(Request, 'functionName', '');
        if FunctionName = '' then
            Error(this.MissingFunctionErr);

        if not this.ReadEntity(Soap, ServiceName, Position, SourceRef, Entity, WsKey) then
            exit(this.SoapFailed(Request, 'action', Soap));
        this.AddValues(this.ObjectValue(Request, 'values'), Values);
        if not Soap.CallFunction(ServiceName, FunctionName, WsKey, FieldName, Values, ReturnValue) then
            exit(this.SoapFailed(Request, 'action', Soap));
        this.ReadResult(ReturnValue, FieldControl, FileName, Base64Result);
        if (FileName = '') and (Base64Result <> '') then
            FileName := this.DefaultFileName(FunctionName, Base64Result);

        Response.Add('kind', 'action');
        Response.Add('service', ServiceName);
        Response.Add('position', Position);
        Response.Add('fieldControl', FieldControl);
        Response.Add('commands', this.ParseFieldControl(FieldControl));
        Response.Add('fileName', FileName);
        Response.Add('base64Result', Base64Result);
        this.AddSoapExchange(Request, Soap.LastExchange(), Response);
        exit(Response);
    end;

    /// <summary>Writes one field of the record through the page service, as a device edit or scan does.</summary>
    /// <param name="Request">The update request: service, position, field and value.</param>
    /// <returns>The update object with the record's position after the write and its commands.</returns>
    procedure UpdateJson(Request: JsonObject): JsonObject
    var
        Soap: Codeunit "BJF MN Emulator Soap";
        FieldName: Text;
    begin
        FieldName := this.TextValue(Request, 'field', '');
        if FieldName = '' then
            Error(this.MissingFieldErr);
        exit(this.WriteJson('update', Request, Soap.ElementName(FieldName), this.TextValue(Request, 'value', '')));
    end;

    /// <summary>
    /// Answers a dialog that the page raised. The answer is written into the FieldControl element of the
    /// entity, which runs the page's OnValidate and sends the next commands back.
    /// </summary>
    /// <param name="Request">The dialogAnswer request: service, position and answer.</param>
    /// <returns>The dialogAnswer object with the record's position after the write and its commands.</returns>
    procedure DialogAnswerJson(Request: JsonObject): JsonObject
    begin
        exit(this.WriteJson('dialogAnswer', Request, 'FieldControl', this.TextValue(Request, 'answer', '')));
    end;

    /// <summary>
    /// Reports whether the emulator can reach Business Central and send writes, and what is missing.
    /// Nothing is written.
    /// </summary>
    /// <returns>The connection object: connected, tokenSource, writesAllowed, sandbox, message and theme.</returns>
    procedure ConnectionJson(): JsonObject
    var
        EmulatorSetup: Record "BJF MN Emulator Setup";
        EmulatorConfig: Codeunit "BJF MN Emulator Config";
        EmulatorToken: Codeunit "BJF MN Emulator Token";
        EnvironmentInformation: Codeunit "Environment Information";
        AccessToken: SecretText;
        Connection: JsonObject;
        Connected: Boolean;
        Sandbox: Boolean;
    begin
        EmulatorSetup.GetSetup();
        Connected := EmulatorToken.TryGetToken(AccessToken);
        Sandbox := EnvironmentInformation.IsSandbox();

        Connection.Add('kind', 'connection');
        Connection.Add('connected', Connected);
        Connection.Add('tokenSource', Format(EmulatorSetup."Token Source"));
        Connection.Add('writesAllowed', EmulatorSetup.WritesAllowed());
        Connection.Add('sandbox', Sandbox);
        Connection.Add('environment', EnvironmentInformation.GetEnvironmentName());
        Connection.Add('message', this.ConnectionMessage(EmulatorSetup, Connected, Sandbox));
        Connection.Add('theme', EmulatorConfig.ThemeJson());
        exit(Connection);
    end;

    /// <summary>
    /// Adds the SOAP exchange of a call to an answer when the request sets debug to true. The exchange
    /// shows the request body and the reply, so a reply that the emulator reads wrongly can be checked.
    /// </summary>
    /// <param name="Request">The request object.</param>
    /// <param name="ExchangeText">The exchange from LastExchange, read right after the call.</param>
    /// <param name="Answer">The answer that gets the soapExchange key.</param>
    procedure AddSoapExchange(Request: JsonObject; ExchangeText: Text; var Answer: JsonObject)
    begin
        if this.DebugRequested(Request) then
            Answer.Add('soapExchange', ExchangeText);
    end;

    /// <summary>
    /// Answers a SOAP call that failed. Without debug the error is raised, as Respond reports it. With debug
    /// set to true the answer is an error object that also carries the exchange of the failed call, so the
    /// caller sees the request and the reply.
    /// </summary>
    /// <param name="Request">The request object.</param>
    /// <param name="Kind">The kind of the request, which the error object names.</param>
    /// <param name="Soap">The SOAP codeunit that made the failed call.</param>
    /// <returns>The error object, with kind error, message, request and soapExchange.</returns>
    procedure SoapFailed(Request: JsonObject; Kind: Text; var Soap: Codeunit "BJF MN Emulator Soap"): JsonObject
    var
        ErrorAnswer: JsonObject;
    begin
        if not this.DebugRequested(Request) then
            Error(this.SoapErr, Soap.LastError());
        ErrorAnswer.Add('kind', 'error');
        ErrorAnswer.Add('message', Soap.LastError());
        ErrorAnswer.Add('request', Kind);
        ErrorAnswer.Add('soapExchange', Soap.LastExchange());
        exit(ErrorAnswer);
    end;

    /// <summary>Reads the debug flag of a request. A request without the flag is not a debug request.</summary>
    /// <param name="Request">The request object.</param>
    /// <returns>True when the request has debug set to true.</returns>
    local procedure DebugRequested(Request: JsonObject): Boolean
    var
        DebugToken: JsonToken;
    begin
        if not Request.Get('debug', DebugToken) then
            exit(false);
        if not DebugToken.IsValue() then
            exit(false);
        if DebugToken.AsValue().IsNull() then
            exit(false);
        exit(DebugToken.AsValue().AsBoolean());
    end;

    /// <summary>
    /// Splits a FieldControl descriptor into commands. Items are split on commas, each item at its first
    /// colon into the command and its payload, and the payload on colons into arguments. Escaped ### and
    /// $$$ in the arguments become , and :. Empty items are dropped.
    /// </summary>
    /// <param name="Descriptor">The FieldControl text of the answer.</param>
    /// <returns>The commands, each with cmd and args.</returns>
    procedure ParseFieldControl(Descriptor: Text): JsonArray
    var
        Commands: JsonArray;
        Item: Text;
    begin
        foreach Item in Descriptor.Split(',') do
            if Item <> '' then
                Commands.Add(this.CommandJson(Item));
        exit(Commands);
    end;

    /// <summary>Builds the command object of one descriptor item.</summary>
    /// <param name="Item">One item of the descriptor, for example T:Posted.</param>
    /// <returns>The command object.</returns>
    local procedure CommandJson(Item: Text): JsonObject
    var
        Command: JsonObject;
        Args: JsonArray;
        Colon: Integer;
    begin
        Colon := StrPos(Item, ':');
        if Colon = 0 then
            Command.Add('cmd', Item)
        else begin
            this.AddArgs(CopyStr(Item, Colon + 1), Args);
            Command.Add('cmd', CopyStr(Item, 1, Colon - 1));
        end;
        Command.Add('args', Args);
        exit(Command);
    end;

    /// <summary>Splits a payload on colons into unescaped arguments. An empty payload gives one empty argument.</summary>
    /// <param name="Payload">The text after the first colon of the item.</param>
    /// <param name="Args">Receives the arguments.</param>
    local procedure AddArgs(Payload: Text; var Args: JsonArray)
    var
        Rest: Text;
        Colon: Integer;
    begin
        Rest := Payload;
        Colon := StrPos(Rest, ':');
        while Colon > 0 do begin
            Args.Add(this.Unescape(CopyStr(Rest, 1, Colon - 1)));
            Rest := CopyStr(Rest, Colon + 1);
            Colon := StrPos(Rest, ':');
        end;
        Args.Add(this.Unescape(Rest));
    end;

    /// <summary>Turns the escapes of a descriptor value back into the characters they replace.</summary>
    /// <param name="Value">The escaped value.</param>
    /// <returns>The value with ### as , and $$$ as :.</returns>
    local procedure Unescape(Value: Text): Text
    begin
        exit(Value.Replace('###', ',').Replace('$$$', ':'));
    end;

    /// <summary>
    /// Finds the record at the position, reads its entity through the page service and returns the
    /// service key of the entity. The write checks run first, so nothing is sent while writes are off.
    /// </summary>
    /// <param name="Soap">The SOAP codeunit that reads the entity.</param>
    /// <param name="ServiceName">The MobileNAV page service.</param>
    /// <param name="Position">The position of the record, as the list or card sent it.</param>
    /// <param name="SourceRef">Receives the record, positioned on the record.</param>
    /// <param name="Entity">Receives the entity of the record.</param>
    /// <param name="WsKey">Receives the service key of the entity.</param>
    /// <returns>False when the page service does not return the entity. Soap.LastError gives the reason.</returns>
    local procedure ReadEntity(var Soap: Codeunit "BJF MN Emulator Soap"; ServiceName: Text; Position: Text; var SourceRef: RecordRef; var Entity: XmlElement; var WsKey: Text): Boolean
    var
        EmulatorSetup: Record "BJF MN Emulator Setup";
        TempMain: Record "MobileNAV Settings Buffer" temporary;
        TempRows: Record "MobileNAV Settings Buffer" temporary;
        Config: Codeunit "BJF MN Emulator Config";
        Records: Codeunit "BJF MN Emulator Records";
        RecId: RecordId;
    begin
        EmulatorSetup.GetSetup();
        if not EmulatorSetup.WritesAllowed() then
            Error(this.WritesOffLbl);
        if not Config.FindMain(ServiceName, TempMain) then
            Error(this.MissingServiceErr, ServiceName);
        Config.CopyRows(ServiceName, TempRows);
        Records.OpenSource(TempMain, SourceRef);
        if not Records.FindByPosition(SourceRef, Position) then
            Error(this.RecordGoneErr);
        RecId := SourceRef.RecordId();
        if not Soap.ReadByRecId(ServiceName, RecId, Entity) then
            exit(false);
        WsKey := Soap.EntityKey(Entity);
        exit(true);
    end;

    /// <summary>
    /// Sends one element write to the page service and answers with the record's position after the
    /// write. The record is found again by its RecordId. When the key changed and the RecordId no longer
    /// finds it, the position from the request is returned.
    /// </summary>
    /// <param name="Kind">The kind of the answer: update or dialogAnswer.</param>
    /// <param name="Request">The request with service and position.</param>
    /// <param name="XmlElementName">The entity element to write, already converted to the element name.</param>
    /// <param name="NewValue">The value to write.</param>
    /// <returns>The write answer: kind, service, position, fieldControl and commands.</returns>
    local procedure WriteJson(Kind: Text; Request: JsonObject; XmlElementName: Text; NewValue: Text): JsonObject
    var
        Soap: Codeunit "BJF MN Emulator Soap";
        Records: Codeunit "BJF MN Emulator Records";
        RecId: RecordId;
        SourceRef: RecordRef;
        Entity: XmlElement;
        ServiceName: Text;
        Position: Text;
        NewPosition: Text;
        WsKey: Text;
        FieldControl: Text;
        Answer: JsonObject;
    begin
        ServiceName := this.TextValue(Request, 'service', '');
        Position := this.TextValue(Request, 'position', '');
        if not this.ReadEntity(Soap, ServiceName, Position, SourceRef, Entity, WsKey) then
            exit(this.SoapFailed(Request, Kind, Soap));
        RecId := SourceRef.RecordId();
        if not Soap.Update(ServiceName, WsKey, XmlElementName, NewValue, Entity) then
            exit(this.SoapFailed(Request, Kind, Soap));
        FieldControl := Soap.EntityValue(Entity, 'FieldControl');

        if SourceRef.Get(RecId) then
            NewPosition := Records.Position(SourceRef)
        else
            NewPosition := Position;

        Answer.Add('kind', Kind);
        Answer.Add('service', ServiceName);
        Answer.Add('position', NewPosition);
        Answer.Add('fieldControl', FieldControl);
        Answer.Add('commands', this.ParseFieldControl(FieldControl));
        this.AddSoapExchange(Request, Soap.LastExchange(), Answer);
        exit(Answer);
    end;

    /// <summary>
    /// Reads the answer of a page function. The return value is the MobileNAV result XML, either as
    /// raw XML or as escaped text. A blank result gives blank values. Public, so the forms codeunit reads
    /// the answer of a dialog function the same way.
    /// </summary>
    /// <param name="ReturnValue">The text the page service returned.</param>
    /// <param name="FieldControl">Receives the fieldControl element.</param>
    /// <param name="FileName">Receives the fileName element.</param>
    /// <param name="Base64Result">Receives the base64Result element.</param>
    procedure ReadResult(ReturnValue: Text; var FieldControl: Text; var FileName: Text; var Base64Result: Text)
    var
        ResultDocument: XmlDocument;
        ResultRoot: XmlElement;
        ResultText: Text;
    begin
        ResultText := ReturnValue.Trim();
        if ResultText = '' then
            exit;
        if not ResultText.StartsWith('<') then
            ResultText := this.UnescapeXml(ResultText);
        if not XmlDocument.ReadFrom(ResultText, ResultDocument) then
            Error(this.ResultErr);
        if not ResultDocument.GetRoot(ResultRoot) then
            Error(this.ResultErr);
        FieldControl := this.ChildText(ResultRoot, 'fieldControl');
        FileName := this.ChildText(ResultRoot, 'fileName');
        Base64Result := this.ChildText(ResultRoot, 'base64Result');
    end;

    /// <summary>
    /// Names a file for an answer that has base64 data and no fileName. The name is the function name with
    /// an extension that the start of the base64 data shows: PDF, PNG, JPEG or GIF. Other data keeps the
    /// function name alone. Public, so the forms codeunit names the answer of a dialog function the same way.
    /// </summary>
    /// <param name="FunctionName">The function that gave the answer.</param>
    /// <param name="Base64Result">The base64 data of the answer.</param>
    /// <returns>The file name, for example StockCountPrint.pdf.</returns>
    procedure DefaultFileName(FunctionName: Text; Base64Result: Text): Text
    begin
        if Base64Result.StartsWith('JVBER') then
            exit(FunctionName + '.pdf');
        if Base64Result.StartsWith('iVBOR') then
            exit(FunctionName + '.png');
        if Base64Result.StartsWith('/9j/') then
            exit(FunctionName + '.jpg');
        if Base64Result.StartsWith('R0lGOD') then
            exit(FunctionName + '.gif');
        exit(FunctionName);
    end;

    /// <summary>Reads the text of the first child element with a name, or '' when there is none.</summary>
    /// <param name="Root">The element to search.</param>
    /// <param name="ElementName">The local name of the child element.</param>
    /// <returns>The inner text of the child.</returns>
    local procedure ChildText(Root: XmlElement; ElementName: Text): Text
    var
        ChildNode: XmlNode;
    begin
        if Root.SelectSingleNode('./*[local-name()="' + ElementName + '"]', ChildNode) then
            exit(ChildNode.AsXmlElement().InnerText());
        exit('');
    end;

    /// <summary>Turns the XML escapes of a text back into characters. The ampersand goes last.</summary>
    /// <param name="Value">The escaped XML text.</param>
    /// <returns>The unescaped text.</returns>
    local procedure UnescapeXml(Value: Text): Text
    begin
        exit(Value.Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"').Replace('&apos;', '''').Replace('&amp;', '&'));
    end;

    /// <summary>Copies the values of a JSON object into a dictionary. A value that is not text gives ''.</summary>
    /// <param name="ValuesObject">The values object of the request.</param>
    /// <param name="Values">Receives one entry for each property.</param>
    local procedure AddValues(ValuesObject: JsonObject; var Values: Dictionary of [Text, Text])
    var
        PropertyName: Text;
        PropertyToken: JsonToken;
    begin
        foreach PropertyName in ValuesObject.Keys() do begin
            ValuesObject.Get(PropertyName, PropertyToken);
            Values.Set(PropertyName, this.TokenText(PropertyToken));
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

    /// <summary>Gives the reason the emulator cannot send writes, in the order of the checks, or '' when all pass.</summary>
    /// <param name="EmulatorSetup">The emulator setup.</param>
    /// <param name="Connected">Whether a token is available.</param>
    /// <param name="Sandbox">Whether the environment is a sandbox.</param>
    /// <returns>The hint, or '' when writes can be sent.</returns>
    local procedure ConnectionMessage(var EmulatorSetup: Record "BJF MN Emulator Setup"; Connected: Boolean; Sandbox: Boolean): Text
    begin
        if not Connected then
            exit(this.NotConnectedLbl);
        if not EmulatorSetup."Allow Writes" then
            exit(this.WritesOffLbl);
        if not (Sandbox or EmulatorSetup."Allow Writes in Production") then
            exit(this.ProductionLbl);
        exit('');
    end;

    var
        MissingFieldErr: Label 'The request names no field.';
        MissingFunctionErr: Label 'The action request names no function.';
        MissingServiceErr: Label 'The configuration has no page for the service %1.', Comment = '%1 = Service Name';
        NotConnectedLbl: Label 'The emulator is not connected to Business Central. Check Emulator Setup on the MobileNAV Device Emulator page.';
        ProductionLbl: Label 'Writes are off in production. Turn on Allow Writes in Production on the MobileNAV Device Emulator page.';
        RecordGoneErr: Label 'The record is gone. Reopen the list and try again.';
        ResultErr: Label 'The MobileNAV result is not valid XML.';
        SoapErr: Label '%1', Comment = '%1 = the error that the MobileNAV page service returned';
        WritesOffLbl: Label 'Writes to MobileNAV are off. Turn on Allow Writes on the MobileNAV Device Emulator page.';
}

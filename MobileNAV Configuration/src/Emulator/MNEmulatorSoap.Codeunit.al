namespace BradFullwood.MobileNAV.Configuration;

using System.Text;

/// <summary>
/// Sends the device emulator's writes, scans and button presses to the tenant's own SOAP page
/// service, the way a device does. A call reads the record with ReadByRecId to get its web service
/// key, then calls Update or a page function on that key. Every call uses the signed-in user's
/// delegated token from "BJF MN Emulator Token".
/// </summary>
codeunit 77731 "BJF MN Emulator Soap"
{
    Access = Internal;
    SingleInstance = true;

    var
        EmulatorToken: Codeunit "BJF MN Emulator Token";
        EncodeDecode: Codeunit "MobileNAV Encode Decode Helper";
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        ParameterCache: Dictionary of [Text, Text];
        LastErrorText: Text;
        LastRequestText: Text;
        LastReplyText: Text;
        NoTokenErr: Label 'The emulator is not connected to Business Central. Connect it on the emulator setup page first.';
        NoBaseUrlErr: Label 'The session SOAP address has no /WS/ part, so the emulator cannot build a service address.';
        UnsafeNameErr: Label 'The name %1 cannot be used in a SOAP request.', Comment = '%1 = the service, element or function name';
        BlockedErr: Label 'The request was blocked by the runtime. Turn on "Allow HttpClient Requests" for this extension in Extension Management, then try again.';
        CallFailedErr: Label 'The web service call failed: %1', Comment = '%1 = the error text from the runtime';
        HttpStatusErr: Label 'The web service returned HTTP status %1 %2.', Comment = '%1 = the status code, %2 = the reason phrase';
        NotXmlErr: Label 'The web service returned a reply that is not XML.';
        NoEntityErr: Label 'The web service reply has no %1 record.', Comment = '%1 = the service name';
        NoFunctionErr: Label 'The web service does not describe the page function %1.', Comment = '%1 = the function name';
        NoRecIdErr: Label 'The web service reply has no record id for the key of %1.', Comment = '%1 = the service name';
        PageTypeTok: Label 'Page', Locked = true;
        CodeunitTypeTok: Label 'Codeunit', Locked = true;
        ResultXPathTok: Label '//*[local-name()="%1"]/*[local-name()="%2"]', Locked = true;
        ReturnXPathTok: Label '//*[local-name()="%1_Result"]/*[local-name()="return_value"]', Locked = true;
        ResultNodeXPathTok: Label '//*[local-name()="%1_Result"]', Locked = true;
        RequestTok: Label 'REQUEST:', Locked = true;
        ResponseTok: Label 'RESPONSE:', Locked = true;
        ChildXPathTok: Label './*[local-name()="%1"]', Locked = true;
        WsdlSequenceXPathTok: Label '//*[local-name()="element"][@name="%1"]/*[local-name()="complexType"]/*[local-name()="sequence"]/*[local-name()="element"]', Locked = true;
        OperationOpenTok: Label '<%1 xmlns="%2">', Locked = true;
        OperationCloseTok: Label '</%1>', Locked = true;
        ElementTok: Label '<%1>%2</%1>', Locked = true;

    /// <summary>Returns the reason the last call failed.</summary>
    /// <returns>The error text, or an empty text after a call that succeeded.</returns>
    procedure LastError(): Text
    begin
        exit(this.LastErrorText);
    end;

    /// <summary>
    /// Returns the request body and the reply of the last SOAP call, for the debug option of the emulator
    /// requests. The token is sent in a header, so it is not part of either text.
    /// </summary>
    /// <returns>REQUEST:, the request body, a blank line, RESPONSE: and the reply. Each part is cut to 20000 characters.</returns>
    procedure LastExchange(): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine(this.RequestTok);
        Builder.AppendLine(this.ExchangePart(this.LastRequestText));
        Builder.AppendLine();
        Builder.AppendLine(this.ResponseTok);
        Builder.Append(this.ExchangePart(this.LastReplyText));
        exit(Builder.ToText());
    end;

    /// <summary>
    /// Reads one record through the page service by its RecordId. The entity that comes back has
    /// the web service key that Update and the page functions take.
    /// </summary>
    /// <param name="ServiceName">The page service, such as MNBinContent.</param>
    /// <param name="RecId">The record the user sees.</param>
    /// <param name="Entity">Receives the entity element of the reply.</param>
    /// <returns>True when the service returned the record.</returns>
    procedure ReadByRecId(ServiceName: Text; RecId: RecordId; var Entity: XmlElement): Boolean
    var
        ResponseDoc: XmlDocument;
    begin
        this.LastErrorText := '';
        if not this.Post(this.PageTypeTok, ServiceName, 'ReadByRecId', this.Envelope(this.PageNamespace(ServiceName), 'ReadByRecId', this.XmlElementOf('recId', this.RecIdText(RecId))), ResponseDoc) then
            exit(false);
        exit(this.FindEntity(ResponseDoc, 'ReadByRecId_Result', ServiceName, Entity));
    end;

    /// <summary>
    /// Converts a web service key to the RecordId of its record, through the page's GetRecIdFromKey
    /// operation. The key goes in an element named Key, as MobileNAV's Soap Helper sends it.
    /// </summary>
    /// <param name="ServiceName">The page service.</param>
    /// <param name="WsKey">The web service key of the record.</param>
    /// <param name="RecId">Receives the record id that the service returned.</param>
    /// <returns>True when the service returned a record id that parses.</returns>
    procedure RecIdFromKey(ServiceName: Text; WsKey: Text; var RecId: RecordId): Boolean
    var
        ResponseDoc: XmlDocument;
        ReplyText: Text;
    begin
        this.LastErrorText := '';
        if not this.Post(this.PageTypeTok, ServiceName, 'GetRecIdFromKey', this.Envelope(this.PageNamespace(ServiceName), 'GetRecIdFromKey', this.XmlElementOf('Key', WsKey)), ResponseDoc) then
            exit(false);
        if this.FirstText(ResponseDoc, StrSubstNo(this.ResultXPathTok, 'GetRecIdFromKey_Result', 'GetRecIdFromKey_Result'), ReplyText) then
            if Evaluate(RecId, ReplyText, 9) then
                exit(true);
        this.LastErrorText := StrSubstNo(this.NoRecIdErr, ServiceName);
        exit(false);
    end;

    /// <summary>Writes one field of a record through the page service, as a device does when the user edits it.</summary>
    /// <param name="ServiceName">The page service.</param>
    /// <param name="WsKey">The web service key from the entity that ReadByRecId returned.</param>
    /// <param name="FieldElementName">The XML element of the field, from ElementName.</param>
    /// <param name="NewValue">The new value as text.</param>
    /// <param name="Entity">Receives the entity element of the reply, which holds the key after the write.</param>
    /// <returns>True when the service accepted the write.</returns>
    procedure Update(ServiceName: Text; WsKey: Text; FieldElementName: Text; NewValue: Text; var Entity: XmlElement): Boolean
    var
        ResponseDoc: XmlDocument;
        Builder: TextBuilder;
    begin
        this.LastErrorText := '';
        if not this.IsSafeName(FieldElementName) then begin
            this.LastErrorText := StrSubstNo(this.UnsafeNameErr, FieldElementName);
            exit(false);
        end;
        Builder.Append(this.XmlWrap(ServiceName, this.XmlElementOf('Key', WsKey) + this.XmlElementOf(FieldElementName, NewValue)));
        if not this.Post(this.PageTypeTok, ServiceName, 'Update', this.Envelope(this.PageNamespace(ServiceName), 'Update', Builder.ToText()), ResponseDoc) then
            exit(false);
        exit(this.FindEntity(ResponseDoc, 'Update_Result', ServiceName, Entity));
    end;

    /// <summary>
    /// Creates a record through the page service, as a device does when the user adds one. Each value
    /// becomes one element of the record, so the names must already be element names.
    /// </summary>
    /// <param name="ServiceName">The page service.</param>
    /// <param name="Values">The field values by element name. Values are escaped, names are not.</param>
    /// <param name="Entity">Receives the entity element of the reply, which holds the key of the new record.</param>
    /// <returns>True when the service created the record.</returns>
    procedure Create(ServiceName: Text; Values: Dictionary of [Text, Text]; var Entity: XmlElement): Boolean
    var
        ResponseDoc: XmlDocument;
        Builder: TextBuilder;
        ValueName: Text;
    begin
        this.LastErrorText := '';
        foreach ValueName in Values.Keys() do begin
            if not this.IsSafeName(ValueName) then begin
                this.LastErrorText := StrSubstNo(this.UnsafeNameErr, ValueName);
                exit(false);
            end;
            Builder.Append(this.XmlElementOf(ValueName, Values.Get(ValueName)));
        end;
        if not this.Post(this.PageTypeTok, ServiceName, 'Create', this.Envelope(this.PageNamespace(ServiceName), 'Create', this.XmlWrap(ServiceName, Builder.ToText())), ResponseDoc) then
            exit(false);
        exit(this.FindEntity(ResponseDoc, 'Create_Result', ServiceName, Entity));
    end;

    /// <summary>
    /// Calls a page function, such as a button's function, on the record with the given key.
    /// The parameter names come from the service WSDL. The first parameter receives the key,
    /// pageName, fieldName and deviceID receive the service, the control and the device ID, and
    /// the other names come from ExtraValues. Parameters with no value are sent empty.
    /// </summary>
    /// <param name="ServiceName">The page service.</param>
    /// <param name="FunctionName">The page function, as the WSDL names it.</param>
    /// <param name="WsKey">The web service key of the record.</param>
    /// <param name="ControlName">The control the user acted on.</param>
    /// <param name="ExtraValues">Values for the other parameters, by parameter name.</param>
    /// <param name="ReturnValue">Receives the return_value of the reply, or the output parameters of a procedure with no return value.</param>
    /// <returns>True when the service answered the call.</returns>
    procedure CallFunction(ServiceName: Text; FunctionName: Text; WsKey: Text; ControlName: Text; ExtraValues: Dictionary of [Text, Text]; var ReturnValue: Text): Boolean
    var
        EmulatorSetup: Record "BJF MN Emulator Setup";
        ResponseDoc: XmlDocument;
        ParameterList: List of [Text];
        Builder: TextBuilder;
        ParameterNamesText: Text;
        ParameterName: Text;
        ParameterValue: Text;
        Index: Integer;
    begin
        this.LastErrorText := '';
        ReturnValue := '';
        if not this.IsSafeName(FunctionName) then begin
            this.LastErrorText := StrSubstNo(this.UnsafeNameErr, FunctionName);
            exit(false);
        end;
        ParameterNamesText := this.ParameterNames(this.PageTypeTok, ServiceName, FunctionName);
        if ParameterNamesText = '' then
            exit(false);

        EmulatorSetup.GetSetup();
        ParameterList := ParameterNamesText.Split(',');
        for Index := 1 to ParameterList.Count() do begin
            ParameterList.Get(Index, ParameterName);
            if Index = 1 then
                ParameterValue := WsKey
            else
                ParameterValue := this.FunctionParameterValue(ParameterName, ServiceName, ControlName, EmulatorSetup."Device ID", ExtraValues);
            Builder.Append(this.XmlElementOf(ParameterName, ParameterValue));
        end;

        if not this.Post(this.PageTypeTok, ServiceName, FunctionName, this.Envelope(this.PageNamespace(ServiceName), FunctionName, Builder.ToText()), ResponseDoc) then
            exit(false);
        this.ReturnValueOf(ResponseDoc, FunctionName, ReturnValue);
        exit(true);
    end;

    /// <summary>
    /// Calls a procedure of a codeunit web service, such as a dialog page's function codeunit. The
    /// parameter names and their order come from the codeunit WSDL. Each parameter takes the value
    /// of the same name in Values, ignoring case, and is sent empty when Values has none.
    /// </summary>
    /// <param name="ServiceName">The codeunit web service, as published.</param>
    /// <param name="FunctionName">The procedure, as the WSDL names it.</param>
    /// <param name="Values">The parameter values by name.</param>
    /// <param name="ReturnValue">Receives the return_value of the reply, or the output parameters of a procedure with no return value.</param>
    /// <returns>True when the service answered the call.</returns>
    procedure CallCodeunit(ServiceName: Text; FunctionName: Text; Values: Dictionary of [Text, Text]; var ReturnValue: Text): Boolean
    var
        ResponseDoc: XmlDocument;
        ParameterList: List of [Text];
        Builder: TextBuilder;
        ParameterNamesText: Text;
        ParameterName: Text;
        Index: Integer;
    begin
        this.LastErrorText := '';
        ReturnValue := '';
        if not this.IsSafeName(FunctionName) then begin
            this.LastErrorText := StrSubstNo(this.UnsafeNameErr, FunctionName);
            exit(false);
        end;
        ParameterNamesText := this.ParameterNames(this.CodeunitTypeTok, ServiceName, FunctionName);
        if ParameterNamesText = '' then
            exit(false);

        ParameterList := ParameterNamesText.Split(',');
        for Index := 1 to ParameterList.Count() do begin
            ParameterList.Get(Index, ParameterName);
            Builder.Append(this.XmlElementOf(ParameterName, this.ExtraValue(Values, ParameterName)));
        end;

        if not this.Post(this.CodeunitTypeTok, ServiceName, FunctionName, this.Envelope(this.CodeunitNamespace(ServiceName), FunctionName, Builder.ToText()), ResponseDoc) then
            exit(false);
        this.ReturnValueOf(ResponseDoc, FunctionName, ReturnValue);
        exit(true);
    end;

    /// <summary>Returns the key element of an entity, the web service key that Update takes.</summary>
    /// <param name="Entity">An entity element from ReadByRecId, Update or CallFunction.</param>
    /// <returns>The key text, or an empty text when the entity has no Key element.</returns>
    procedure EntityKey(Entity: XmlElement): Text
    begin
        exit(this.EntityValue(Entity, 'Key'));
    end;

    /// <summary>Returns the text of one child element of an entity.</summary>
    /// <param name="Entity">The entity element.</param>
    /// <param name="Name">The child element name, such as Qty_to_Handle.</param>
    /// <returns>The element text, or an empty text when the child does not exist.</returns>
    procedure EntityValue(Entity: XmlElement; Name: Text): Text
    var
        Node: XmlNode;
    begin
        if not Entity.SelectSingleNode(StrSubstNo(this.ChildXPathTok, Name), Node) then
            exit('');
        exit(Node.AsXmlElement().InnerText());
    end;

    /// <summary>Converts a control name to the XML element name that the page service uses.</summary>
    /// <param name="ControlName">The control name from the FieldControl or the field caption.</param>
    /// <returns>The element name, as MobileNAV converts it.</returns>
    procedure ElementName(ControlName: Text): Text
    begin
        exit(this.WebServiceHandling.ConvertFieldName(ControlName));
    end;

    /// <summary>
    /// Formats a RecordId as the page service expects it in ReadByRecId. Format 9 is the form in
    /// which MobileNAV reads the RecordId text that GetRecIdFromKey returns, with
    /// Evaluate(RecId, Text, 9) in Codeunit 42012860 (WSKeyToRecIDEx). Learn gives format 9 as the
    /// English table name with the primary key, and it has no documented format 10.
    /// </summary>
    /// <param name="RecId">The record to format.</param>
    /// <returns>The RecordId text.</returns>
    local procedure RecIdText(RecId: RecordId): Text
    begin
        exit(Format(RecId, 0, 9));
    end;

    /// <summary>Builds a SOAP 1.1 envelope with one operation in the given namespace.</summary>
    /// <param name="Namespace">The namespace of the operation, from PageNamespace or CodeunitNamespace.</param>
    /// <param name="Operation">The operation element, such as Update.</param>
    /// <param name="OperationContent">The XML inside the operation element. It is not escaped.</param>
    /// <returns>The envelope text.</returns>
    local procedure Envelope(Namespace: Text; Operation: Text; OperationContent: Text): Text
    var
        Builder: TextBuilder;
    begin
        Builder.Append('<?xml version="1.0" encoding="utf-8"?>');
        Builder.Append('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body>');
        Builder.Append(StrSubstNo(this.OperationOpenTok, Operation, Namespace));
        Builder.Append(OperationContent);
        Builder.Append(StrSubstNo(this.OperationCloseTok, Operation));
        Builder.Append('</soap:Body></soap:Envelope>');
        exit(Builder.ToText());
    end;

    /// <summary>Returns the namespace of a page service, which is the lower-case service name.</summary>
    /// <param name="ServiceName">The page service.</param>
    /// <returns>The namespace URI.</returns>
    local procedure PageNamespace(ServiceName: Text): Text
    begin
        exit('urn:microsoft-dynamics-schemas/page/' + LowerCase(ServiceName));
    end;

    /// <summary>Returns the namespace of a codeunit service, which is the service name as published.</summary>
    /// <param name="ServiceName">The codeunit service.</param>
    /// <returns>The namespace URI.</returns>
    local procedure CodeunitNamespace(ServiceName: Text): Text
    begin
        exit('urn:microsoft-dynamics-schemas/codeunit/' + ServiceName);
    end;

    /// <summary>Wraps XML content in an element. The content is not escaped.</summary>
    /// <param name="Name">The element name.</param>
    /// <param name="InnerXml">The content, already XML.</param>
    /// <returns>The element text.</returns>
    local procedure XmlWrap(Name: Text; InnerXml: Text): Text
    begin
        exit(StrSubstNo(this.ElementTok, Name, InnerXml));
    end;

    /// <summary>Builds an element that holds one text value, escaped for XML.</summary>
    /// <param name="Name">The element name.</param>
    /// <param name="Value">The value as text.</param>
    /// <returns>The element text.</returns>
    local procedure XmlElementOf(Name: Text; Value: Text): Text
    begin
        exit(this.XmlWrap(Name, this.XmlEscape(Value)));
    end;

    /// <summary>Escapes the five characters that XML does not allow in text.</summary>
    /// <param name="Value">The text to escape.</param>
    /// <returns>The escaped text.</returns>
    local procedure XmlEscape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace('''', '&apos;'));
    end;

    /// <summary>
    /// Checks that a name can be placed in XML and a URL without escaping. Letters outside ASCII are
    /// allowed, because field names in Business Central can contain them.
    /// </summary>
    /// <param name="Name">The name to check.</param>
    /// <returns>True when the name is not empty and has no character that breaks the request.</returns>
    local procedure IsSafeName(Name: Text): Boolean
    var
        Index: Integer;
        Character: Text[1];
    begin
        if Name = '' then
            exit(false);
        for Index := 1 to StrLen(Name) do begin
            Character := CopyStr(Name, Index, 1);
            if Character in ['<', '>', '&', '"', '''', '/', '=', ':', ' ', '?', '#', '%'] then
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Sends one SOAP request to a page or codeunit service with the signed-in user's token, and reads the reply.
    /// </summary>
    /// <param name="ObjectType">Page or Codeunit, the kind of web service. It is in the URL and the SOAPAction.</param>
    /// <param name="ServiceName">The web service.</param>
    /// <param name="Operation">The operation, used in the SOAPAction header.</param>
    /// <param name="SoapBody">The complete envelope.</param>
    /// <param name="ResponseDoc">Receives the parsed reply.</param>
    /// <returns>True when the service answered HTTP 200 with no fault.</returns>
    local procedure Post(ObjectType: Text; ServiceName: Text; Operation: Text; SoapBody: Text; var ResponseDoc: XmlDocument): Boolean
    var
        Client: HttpClient;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Url: Text;
        IsParsed: Boolean;
    begin
        if not this.IsSafeName(ServiceName) then begin
            this.LastErrorText := StrSubstNo(this.UnsafeNameErr, ServiceName);
            exit(false);
        end;
        if not this.NewClient(Client) then
            exit(false);
        Url := this.ServiceUrl(ObjectType, ServiceName);
        if Url = '' then
            exit(false);

        Content.WriteFrom(SoapBody);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'text/xml; charset=utf-8');
        ContentHeaders.Add('SOAPAction', 'urn:microsoft-dynamics-schemas/' + LowerCase(ObjectType) + '/' + LowerCase(ServiceName) + ':' + Operation);

        this.LastRequestText := SoapBody;
        this.LastReplyText := '';
        if not this.TryPost(Client, Url, Content, Response) then begin
            this.LastErrorText := this.SendError(GetLastErrorText());
            exit(false);
        end;

        Response.Content().ReadAs(ResponseText);
        this.LastReplyText := ResponseText;
        IsParsed := XmlDocument.ReadFrom(ResponseText, ResponseDoc);
        exit(not this.ReplyFailed(IsParsed, ResponseDoc, Response));
    end;

    /// <summary>Sets LastError when a reply holds a SOAP fault, an HTTP error status or no XML.</summary>
    /// <param name="IsParsed">True when the reply parsed as XML.</param>
    /// <param name="ResponseDoc">The parsed reply.</param>
    /// <param name="Response">The HTTP response.</param>
    /// <returns>True when the reply is an error.</returns>
    local procedure ReplyFailed(IsParsed: Boolean; var ResponseDoc: XmlDocument; var Response: HttpResponseMessage): Boolean
    var
        FaultText: Text;
    begin
        if IsParsed then
            if this.FirstText(ResponseDoc, '//*[local-name()="Fault"]/*[local-name()="faultstring"]', FaultText) then begin
                this.LastErrorText := FaultText;
                exit(true);
            end;
        if Response.HttpStatusCode() <> 200 then begin
            this.LastErrorText := StrSubstNo(this.HttpStatusErr, Response.HttpStatusCode(), Response.ReasonPhrase());
            exit(true);
        end;
        if not IsParsed then begin
            this.LastErrorText := this.NotXmlErr;
            exit(true);
        end;
        exit(false);
    end;

    /// <summary>Returns the address of a web service. It sits under the session SOAP base address.</summary>
    /// <param name="ObjectType">Page or Codeunit.</param>
    /// <param name="ServiceName">The web service.</param>
    /// <returns>The service address, or an empty text when the session has no SOAP address.</returns>
    local procedure ServiceUrl(ObjectType: Text; ServiceName: Text): Text
    var
        BaseUrl: Text;
        WsPosition: Integer;
    begin
        BaseUrl := GetUrl(ClientType::SOAP);
        WsPosition := StrPos(BaseUrl, '/WS/');
        if WsPosition = 0 then begin
            this.LastErrorText := this.NoBaseUrlErr;
            exit('');
        end;
        exit(CopyStr(BaseUrl, 1, WsPosition - 1) + '/WS/' + this.EncodeDecode.URLEncode(CompanyName()) + '/' + ObjectType + '/' + ServiceName);
    end;

    /// <summary>Creates an HTTP client with the signed-in user's bearer token.</summary>
    /// <param name="Client">Receives the client.</param>
    /// <returns>True when a token is available.</returns>
    [NonDebuggable]
    local procedure NewClient(var Client: HttpClient): Boolean
    var
        AccessToken: SecretText;
    begin
        if not this.EmulatorToken.TryGetToken(AccessToken) then begin
            this.LastErrorText := this.NoTokenErr;
            exit(false);
        end;
        Client.DefaultRequestHeaders().Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));
        Client.Timeout(60000);
        exit(true);
    end;

    /// <summary>Downloads the WSDL of a page or codeunit service.</summary>
    /// <param name="ObjectType">Page or Codeunit.</param>
    /// <param name="ServiceName">The web service.</param>
    /// <param name="WsdlDoc">Receives the parsed WSDL.</param>
    /// <returns>True when the WSDL was downloaded and parsed.</returns>
    local procedure GetWsdl(ObjectType: Text; ServiceName: Text; var WsdlDoc: XmlDocument): Boolean
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Url: Text;
    begin
        if not this.NewClient(Client) then
            exit(false);
        Url := this.ServiceUrl(ObjectType, ServiceName);
        if Url = '' then
            exit(false);
        if not this.TryGet(Client, Url + '?WSDL', Response) then begin
            this.LastErrorText := this.SendError(GetLastErrorText());
            exit(false);
        end;
        if Response.HttpStatusCode() <> 200 then begin
            this.LastErrorText := StrSubstNo(this.HttpStatusErr, Response.HttpStatusCode(), Response.ReasonPhrase());
            exit(false);
        end;
        Response.Content().ReadAs(ResponseText);
        if not XmlDocument.ReadFrom(ResponseText, WsdlDoc) then begin
            this.LastErrorText := this.NotXmlErr;
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Returns the parameter names of a page function in the order the WSDL lists them. The answer
    /// is cached per service and function for this session.
    /// </summary>
    /// <param name="ObjectType">Page or Codeunit.</param>
    /// <param name="ServiceName">The web service.</param>
    /// <param name="FunctionName">The page or codeunit function.</param>
    /// <returns>The names joined with commas, or an empty text when the WSDL does not describe the function.</returns>
    local procedure ParameterNames(ObjectType: Text; ServiceName: Text; FunctionName: Text): Text
    var
        WsdlDoc: XmlDocument;
        CacheKey: Text;
        Names: Text;
    begin
        CacheKey := ObjectType + '|' + ServiceName + '|' + FunctionName;
        if this.ParameterCache.ContainsKey(CacheKey) then
            exit(this.ParameterCache.Get(CacheKey));

        if not this.GetWsdl(ObjectType, ServiceName, WsdlDoc) then
            exit('');
        Names := this.WsdlParameterNames(WsdlDoc, FunctionName);
        if Names = '' then begin
            this.LastErrorText := StrSubstNo(this.NoFunctionErr, FunctionName);
            exit('');
        end;
        this.ParameterCache.Set(CacheKey, Names);
        exit(Names);
    end;

    /// <summary>Reads the parameter names of a page function from a parsed WSDL.</summary>
    /// <param name="WsdlDoc">The parsed WSDL.</param>
    /// <param name="FunctionName">The page function.</param>
    /// <returns>The names joined with commas, in WSDL order. Empty when the function is not in the WSDL.</returns>
    local procedure WsdlParameterNames(var WsdlDoc: XmlDocument; FunctionName: Text): Text
    var
        Nodes: XmlNodeList;
        Node: XmlNode;
        Attr: XmlAttribute;
        Builder: TextBuilder;
        Index: Integer;
    begin
        if not WsdlDoc.SelectNodes(StrSubstNo(this.WsdlSequenceXPathTok, FunctionName), Nodes) then
            exit('');
        for Index := 1 to Nodes.Count() do begin
            Nodes.Get(Index, Node);
            if Node.AsXmlElement().Attributes().Get('name', Attr) then begin
                if Builder.ToText() <> '' then
                    Builder.Append(',');
                Builder.Append(Attr.Value());
            end;
        end;
        exit(Builder.ToText());
    end;

    /// <summary>Returns the value of a page function parameter other than the key.</summary>
    /// <param name="ParameterName">The parameter name from the WSDL.</param>
    /// <param name="ServiceName">The page service, sent as pageName.</param>
    /// <param name="ControlName">The control, sent as fieldName.</param>
    /// <param name="DeviceId">The emulator device ID, sent as deviceID.</param>
    /// <param name="ExtraValues">Values for the other parameters, by name.</param>
    /// <returns>The value, or an empty text when no value is given.</returns>
    local procedure FunctionParameterValue(ParameterName: Text; ServiceName: Text; ControlName: Text; DeviceId: Text; ExtraValues: Dictionary of [Text, Text]): Text
    begin
        case LowerCase(ParameterName) of
            'pagename':
                exit(ServiceName);
            'fieldname':
                exit(ControlName);
            'deviceid':
                exit(DeviceId);
        end;
        exit(this.ExtraValue(ExtraValues, ParameterName));
    end;

    /// <summary>Looks up a value by parameter name, ignoring case.</summary>
    /// <param name="ExtraValues">The values by name.</param>
    /// <param name="ParameterName">The name to find.</param>
    /// <returns>The value, or an empty text when no name matches.</returns>
    local procedure ExtraValue(ExtraValues: Dictionary of [Text, Text]; ParameterName: Text): Text
    var
        ExtraKey: Text;
    begin
        foreach ExtraKey in ExtraValues.Keys() do
            if LowerCase(ExtraKey) = LowerCase(ParameterName) then
                exit(ExtraValues.Get(ExtraKey));
        exit('');
    end;

    /// <summary>
    /// Reads the return value of a call. A MobileNAV function answers with a return_value element. A
    /// procedure with no return value, such as a dialog page's function, answers with its output
    /// parameters as children of the result element. Those children are copied into a return_value
    /// element, escaped, so the answer reader finds them by their local names.
    /// </summary>
    /// <param name="ResponseDoc">The parsed reply.</param>
    /// <param name="FunctionName">The operation, which names the result element FunctionName_Result.</param>
    /// <param name="ReturnValue">Receives the return_value text, or an empty text when the reply has no result.</param>
    local procedure ReturnValueOf(var ResponseDoc: XmlDocument; FunctionName: Text; var ReturnValue: Text)
    var
        ResultNode: XmlNode;
        ChildNode: XmlNode;
        ChildNodes: XmlNodeList;
        Builder: TextBuilder;
        Index: Integer;
    begin
        ReturnValue := '';
        if this.FirstText(ResponseDoc, StrSubstNo(this.ReturnXPathTok, FunctionName), ReturnValue) then
            exit;
        if not ResponseDoc.SelectSingleNode(StrSubstNo(this.ResultNodeXPathTok, FunctionName), ResultNode) then
            exit;
        if not ResultNode.AsXmlElement().SelectNodes('./*', ChildNodes) then
            exit;
        for Index := 1 to ChildNodes.Count() do begin
            ChildNodes.Get(Index, ChildNode);
            Builder.Append(this.XmlElementOf(ChildNode.AsXmlElement().LocalName(), ChildNode.AsXmlElement().InnerText()));
        end;
        ReturnValue := this.XmlWrap('return_value', Builder.ToText());
    end;

    /// <summary>Cuts a part of the debug exchange to the length the emulator returns.</summary>
    /// <param name="Value">The request body or the reply.</param>
    /// <returns>The first 20000 characters.</returns>
    local procedure ExchangePart(Value: Text): Text
    begin
        exit(CopyStr(Value, 1, 20000));
    end;

    /// <summary>Reads the text of the first node that an XPath selects.</summary>
    /// <param name="Doc">The parsed reply or WSDL.</param>
    /// <param name="XPath">The path to the element.</param>
    /// <param name="Value">Receives the element text.</param>
    /// <returns>True when the element exists.</returns>
    local procedure FirstText(var Doc: XmlDocument; XPath: Text; var Value: Text): Boolean
    var
        Node: XmlNode;
    begin
        if not Doc.SelectSingleNode(XPath, Node) then
            exit(false);
        Value := Node.AsXmlElement().InnerText();
        exit(true);
    end;

    /// <summary>Finds the entity element in a reply, under the result element of the operation.</summary>
    /// <param name="ResponseDoc">The parsed reply.</param>
    /// <param name="ResultName">The result element, such as Update_Result.</param>
    /// <param name="ServiceName">The page service, which names the entity.</param>
    /// <param name="Entity">Receives the entity element.</param>
    /// <returns>True when the entity is in the reply.</returns>
    local procedure FindEntity(var ResponseDoc: XmlDocument; ResultName: Text; ServiceName: Text; var Entity: XmlElement): Boolean
    var
        Node: XmlNode;
    begin
        if not ResponseDoc.SelectSingleNode(StrSubstNo(this.ResultXPathTok, ResultName, ServiceName), Node) then begin
            this.LastErrorText := StrSubstNo(this.NoEntityErr, ServiceName);
            exit(false);
        end;
        Entity := Node.AsXmlElement();
        exit(true);
    end;

    /// <summary>Makes a short message from an error that a failed HTTP call raised.</summary>
    /// <param name="ErrorText">The text from GetLastErrorText.</param>
    /// <returns>The message for LastError.</returns>
    local procedure SendError(ErrorText: Text): Text
    begin
        if StrPos(LowerCase(ErrorText), 'blocked') > 0 then
            exit(this.BlockedErr);
        exit(StrSubstNo(this.CallFailedErr, ErrorText));
    end;

    [TryFunction]
    local procedure TryPost(var Client: HttpClient; Url: Text; var Content: HttpContent; var Response: HttpResponseMessage)
    begin
        Client.Post(Url, Content, Response);
    end;

    [TryFunction]
    local procedure TryGet(var Client: HttpClient; Url: Text; var Response: HttpResponseMessage)
    begin
        Client.Get(Url, Response);
    end;
}

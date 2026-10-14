namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Checks the device emulator's JSON protocol: the error answers of Respond, the FieldControl parser
/// that turns a page answer into commands for the emulator page, and the buffer state report, which
/// must not add a login log row. The first four tests need no MobileNAV configuration. The buffer
/// state test needs MobileNAV installed only.
/// </summary>
codeunit 50155 "Emulator Test"
{
    Subtype = Test;
    Access = Internal;
    Permissions = tabledata "MobileNAV Login Log" = r;

    /// <summary>An unknown request kind comes back as an error answer that names the kind.</summary>
    [Test]
    procedure UnknownKindAnswersError()
    var
        Emulator: Codeunit "BJF MN Emulator";
        Response: JsonObject;
        ResponseText: Text;
    begin
        // Given a request whose kind the emulator does not know
        // When the request goes through Respond
        ResponseText := Emulator.Respond('{"kind":"nonsense"}');

        // Then the answer is an error that names the kind
        this.ReadObject(ResponseText, Response);
        this.AssertEqual(this.ErrorKindTok, this.TextOf(Response, 'kind'));
        this.AssertContains(this.TextOf(Response, 'message'), this.NonsenseTok);
    end;

    /// <summary>Text that is not JSON comes back as an error answer, and Respond does not raise an error.</summary>
    [Test]
    procedure NotJsonAnswersErrorWithoutRaising()
    var
        Emulator: Codeunit "BJF MN Emulator";
        Response: JsonObject;
        ResponseText: Text;
    begin
        // Given a request text that is not a JSON object
        // When the request goes through Respond
        ResponseText := Emulator.Respond(this.NotJsonTok);

        // Then the answer is an error with a message
        this.ReadObject(ResponseText, Response);
        this.AssertEqual(this.ErrorKindTok, this.TextOf(Response, 'kind'));
        if this.TextOf(Response, 'message') = '' then
            Error(this.EmptyMessageErr);
    end;

    /// <summary>A FieldControl descriptor splits into commands, with escapes restored in their arguments.</summary>
    [Test]
    procedure ParseFieldControlSplitsCommands()
    var
        EmulatorActions: Codeunit "BJF MN Emulator Actions";
        Commands: JsonArray;
    begin
        // Given a descriptor of six items, with an empty argument, an escaped comma and an escaped colon
        // When the descriptor is parsed
        Commands := EmulatorActions.ParseFieldControl(this.DescriptorTok);

        // Then there are six commands, and the arguments of four of them are right
        this.AssertEqualInt(6, Commands.Count());
        this.AssertCommand(Commands, 0, this.TCmdTok, this.PostedArgTok);
        this.AssertCommand(Commands, 1, this.RPCmdTok, '');
        this.AssertCommand(Commands, 3, this.MCCmdTok, this.TitleCommaArgTok);
        this.AssertCommand(Commands, 4, this.MTCmdTok, this.ColonArgTok);
    end;

    /// <summary>An empty descriptor gives no commands.</summary>
    [Test]
    procedure ParseFieldControlEmptyGivesNoCommands()
    var
        EmulatorActions: Codeunit "BJF MN Emulator Actions";
        Commands: JsonArray;
    begin
        // Given an empty descriptor
        // When the descriptor is parsed
        Commands := EmulatorActions.ParseFieldControl('');

        // Then there are no commands
        this.AssertEqualInt(0, Commands.Count());
    end;

    /// <summary>The buffer state answer has its kind, and reading it adds no MobileNAV login log row.</summary>
    [Test]
    procedure BufferStateAddsNoLoginLog()
    var
        MNLoginLog: Record "MobileNAV Login Log";
        Emulator: Codeunit "BJF MN Emulator";
        Response: JsonObject;
        ResponseText: Text;
        LogCountBefore: Integer;
    begin
        // Given the number of login log rows before the request
        LogCountBefore := MNLoginLog.Count();

        // When the buffer state is requested through Respond
        ResponseText := Emulator.Respond(this.BufferStateRequestTok);

        // Then the answer is a buffer state and the login log has the same number of rows
        this.ReadObject(ResponseText, Response);
        this.AssertEqual(this.BufferStateKindTok, this.TextOf(Response, 'kind'));
        this.AssertEqualInt(LogCountBefore, MNLoginLog.Count());
    end;

    /// <summary>Reads a JSON object from text. Fails when the text is not a JSON object.</summary>
    /// <param name="ResponseText">The text to read.</param>
    /// <param name="Response">Receives the object.</param>
    local procedure ReadObject(ResponseText: Text; var Response: JsonObject)
    begin
        if not Response.ReadFrom(ResponseText) then
            Error(this.NotAnObjectErr, ResponseText);
    end;

    /// <summary>Reads a text property of a JSON object. Fails when the property is missing.</summary>
    /// <param name="Obj">The object to read.</param>
    /// <param name="PropertyName">The name of the property.</param>
    /// <returns>The text of the property.</returns>
    local procedure TextOf(Obj: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not Obj.Get(PropertyName, Token) then
            Error(this.MissingPropertyErr, PropertyName);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Checks one command of a parsed descriptor: its cmd, and its single argument.</summary>
    /// <param name="Commands">The parsed commands.</param>
    /// <param name="Index">The zero-based index of the command.</param>
    /// <param name="ExpectedCmd">The expected cmd.</param>
    /// <param name="ExpectedArg">The expected value of the only argument.</param>
    local procedure AssertCommand(Commands: JsonArray; Index: Integer; ExpectedCmd: Text; ExpectedArg: Text)
    var
        CommandToken: JsonToken;
        ArgsToken: JsonToken;
        ArgToken: JsonToken;
        Command: JsonObject;
        Args: JsonArray;
    begin
        Commands.Get(Index, CommandToken);
        Command := CommandToken.AsObject();
        this.AssertEqual(ExpectedCmd, this.TextOf(Command, 'cmd'));

        Command.Get('args', ArgsToken);
        Args := ArgsToken.AsArray();
        this.AssertEqualInt(1, Args.Count());
        Args.Get(0, ArgToken);
        this.AssertEqual(ExpectedArg, ArgToken.AsValue().AsText());
    end;

    /// <summary>Fails when the two texts differ.</summary>
    /// <param name="Expected">The expected text.</param>
    /// <param name="Actual">The text the test got.</param>
    local procedure AssertEqual(Expected: Text; Actual: Text)
    begin
        if Expected <> Actual then
            Error(this.MismatchErr, Expected, Actual);
    end;

    /// <summary>Fails when the two integers differ.</summary>
    /// <param name="Expected">The expected number.</param>
    /// <param name="Actual">The number the test got.</param>
    local procedure AssertEqualInt(Expected: Integer; Actual: Integer)
    begin
        this.AssertEqual(Format(Expected), Format(Actual));
    end;

    /// <summary>Fails when the text does not contain the expected text.</summary>
    /// <param name="Actual">The text to search.</param>
    /// <param name="Expected">The text that must be in it.</param>
    local procedure AssertContains(Actual: Text; Expected: Text)
    begin
        if not Actual.Contains(Expected) then
            Error(this.NotContainedErr, Expected, Actual);
    end;

    var
        ErrorKindTok: Label 'error', Locked = true;
        BufferStateKindTok: Label 'bufferState', Locked = true;
        BufferStateRequestTok: Label '{"kind":"bufferState"}', Locked = true;
        NonsenseTok: Label 'nonsense', Locked = true;
        NotJsonTok: Label 'this is not JSON', Locked = true;
        DescriptorTok: Label 'T:Posted,RP:,MI:1,MC:Title###x,MT:a$$$b,MB:YesNo', Locked = true;
        TCmdTok: Label 'T', Locked = true;
        PostedArgTok: Label 'Posted', Locked = true;
        RPCmdTok: Label 'RP', Locked = true;
        MCCmdTok: Label 'MC', Locked = true;
        TitleCommaArgTok: Label 'Title,x', Locked = true;
        MTCmdTok: Label 'MT', Locked = true;
        ColonArgTok: Label 'a:b', Locked = true;
        EmptyMessageErr: Label 'The error answer has an empty message.';
        NotAnObjectErr: Label 'The answer is not a JSON object: %1', Comment = '%1 = the text that was read';
        MissingPropertyErr: Label 'The answer has no property %1.', Comment = '%1 = the property name';
        MismatchErr: Label 'Expected "%1" but got "%2".', Comment = '%1 = expected text, %2 = actual text';
        NotContainedErr: Label 'The text "%2" does not contain "%1".', Comment = '%1 = expected text, %2 = the text that was searched';
}

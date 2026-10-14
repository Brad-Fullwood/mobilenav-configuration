namespace BradFullwood.MobileNAV.Configuration;

using System.Text;

/// <summary>
/// Reads and writes the stored builds of "BJF MN Emulator Config". It computes the fingerprint that
/// decides whether a stored build still matches MobileNAV, and it turns the rows of the six buffer tables
/// into JSON and back. Reads and writes run in try functions, so a stored build that cannot be read or
/// written is rebuilt instead of failing the request.
/// </summary>
codeunit 77821 "BJF MN Emulator Cache Codec"
{
    Access = Internal;
    Permissions = tabledata "BJF MN Emulator Cache" = rim,
        tabledata "MobileNAV CaptionML Admin." = r,
        tabledata "MobileNAV License Setup" = r,
        tabledata "MobileNAV Line Format" = r,
        tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Profile Setup" = r,
        tabledata "MobileNAV Service Setup" = r,
        tabledata "MobileNAV Svc. Setup Main" = r,
        tabledata "MobileNAV User Setup" = r;

    /// <summary>Builds the fingerprint in a try function, so a MobileNAV table that cannot be read gives no fingerprint instead of an error.</summary>
    /// <param name="Fingerprint">Receives the fingerprint.</param>
    /// <returns>False when no fingerprint can be built. The caller then builds without storing.</returns>
    [TryFunction]
    procedure TryCurrentFingerprint(var Fingerprint: Text[2048])
    begin
        Fingerprint := this.CurrentFingerprint();
    end;

    /// <summary>
    /// Builds the fingerprint of the MobileNAV state a configuration build reads. It holds the versions of this
    /// app and of MobileNAV, and the row count and latest SystemModifiedAt of each MobileNAV configuration table.
    /// A deleted row changes the count, and a changed row changes the latest time. The user, the language and
    /// the profile are not in it, because the cache key holds them.
    /// </summary>
    /// <returns>The fingerprint text, which is compared as a whole.</returns>
    local procedure CurrentFingerprint(): Text[2048]
    var
        AppInfo: ModuleInfo;
        MobileNAVAppId: Guid;
        Builder: TextBuilder;
    begin
        Evaluate(MobileNAVAppId, this.MobileNAVAppIdTok);
        NavApp.GetCurrentModuleInfo(AppInfo);
        Builder.Append(this.FormatVersionTok);
        Builder.Append('|app=' + Format(AppInfo.AppVersion()));
        if NavApp.GetModuleInfo(MobileNAVAppId, AppInfo) then
            Builder.Append('|mobilenav=' + Format(AppInfo.AppVersion()));
        this.AddTablesState(Builder);
        exit(CopyStr(Builder.ToText(), 1, 2048));
    end;

    /// <summary>Reads the stored build of a user, language and profile.</summary>
    /// <param name="ForUserId">The user of the build.</param>
    /// <param name="LanguageCode">The MobileNAV language code of the build.</param>
    /// <param name="ProfileCode">The profile of the build, or ''.</param>
    /// <param name="ExpectedFingerprint">The fingerprint the stored build must hold.</param>
    /// <param name="Stored">Receives the stored JSON when the fingerprint matches.</param>
    /// <param name="Matches">True when a stored build exists and its fingerprint equals the expected one.</param>
    /// <returns>False when the read raised an error. The caller then builds the configuration again.</returns>
    [TryFunction]
    procedure TryRead(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; ExpectedFingerprint: Text[2048]; var Stored: JsonObject; var Matches: Boolean)
    var
        Cache: Record "BJF MN Emulator Cache";
        InStr: InStream;
    begin
        Matches := false;
        Cache.SetLoadFields(Fingerprint, Payload);
        if not Cache.Get(ForUserId, LanguageCode, ProfileCode) then
            exit;
        if Cache.Fingerprint <> ExpectedFingerprint then
            exit;
        Cache.Payload.CreateInStream(InStr, TextEncoding::UTF8);
        if not Stored.ReadFrom(InStr) then
            exit;
        Matches := true;
    end;

    /// <summary>Stores a build for a user, language and profile, replacing the stored one.</summary>
    /// <param name="ForUserId">The user of the build.</param>
    /// <param name="LanguageCode">The MobileNAV language code of the build.</param>
    /// <param name="ProfileCode">The profile of the build, or ''.</param>
    /// <param name="BuildFingerprint">The fingerprint the build was started with.</param>
    /// <param name="BuildDuration">The time the build took, in milliseconds.</param>
    /// <param name="Stored">The rows of the build as JSON.</param>
    /// <returns>False when the write raised an error, for example a concurrent insert. The configuration is still used.</returns>
    [TryFunction]
    procedure TryWrite(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; BuildFingerprint: Text[2048]; BuildDuration: Integer; Stored: JsonObject)
    var
        Cache: Record "BJF MN Emulator Cache";
        OutStr: OutStream;
        StoredText: Text;
    begin
        Stored.WriteTo(StoredText);
        if not Cache.Get(ForUserId, LanguageCode, ProfileCode) then begin
            Cache.Init();
            Cache.Validate("User ID", ForUserId);
            Cache.Validate("Language Code", LanguageCode);
            Cache.Validate("Profile Code", ProfileCode);
            Cache.Insert(false);
        end;
        Cache.Validate(Fingerprint, BuildFingerprint);
        Cache.Validate("Built At", CurrentDateTime());
        Cache.Validate("Build Duration (ms)", BuildDuration);
        Clear(Cache.Payload);
        Cache.Payload.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(StoredText);
        Cache.Modify(false);
    end;

    /// <summary>Adds the row count and the latest SystemModifiedAt of each MobileNAV table the build reads.</summary>
    /// <param name="Builder">Receives one segment per table.</param>
    local procedure AddTablesState(var Builder: TextBuilder)
    begin
        this.AddServiceSetupState(Builder);
        this.AddServiceSetupMainState(Builder);
        this.AddLineFormatState(Builder);
        this.AddMasterDataState(Builder);
        this.AddProfileSetupState(Builder);
        this.AddLicenseSetupState(Builder);
        this.AddUserSetupState(Builder);
        this.AddCaptionMLAdminState(Builder);
    end;

    /// <summary>Adds the state of MobileNAV Service Setup.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddServiceSetupState(var Builder: TextBuilder)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        ServiceSetup.SetLoadFields(SystemModifiedAt);
        if ServiceSetup.FindSet() then
            repeat
                Rows += 1;
                if ServiceSetup.SystemModifiedAt > Latest then
                    Latest := ServiceSetup.SystemModifiedAt;
            until ServiceSetup.Next() = 0;
        this.AddState(Builder, 'ServiceSetup', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV Svc. Setup Main.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddServiceSetupMainState(var Builder: TextBuilder)
    var
        ServiceSetupMain: Record "MobileNAV Svc. Setup Main";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        ServiceSetupMain.SetLoadFields(SystemModifiedAt);
        if ServiceSetupMain.FindSet() then
            repeat
                Rows += 1;
                if ServiceSetupMain.SystemModifiedAt > Latest then
                    Latest := ServiceSetupMain.SystemModifiedAt;
            until ServiceSetupMain.Next() = 0;
        this.AddState(Builder, 'ServiceSetupMain', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV Line Format.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddLineFormatState(var Builder: TextBuilder)
    var
        LineFormat: Record "MobileNAV Line Format";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        LineFormat.SetLoadFields(SystemModifiedAt);
        if LineFormat.FindSet() then
            repeat
                Rows += 1;
                if LineFormat.SystemModifiedAt > Latest then
                    Latest := LineFormat.SystemModifiedAt;
            until LineFormat.Next() = 0;
        this.AddState(Builder, 'LineFormat', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV Master Data, which holds the colours, the categories and the profiles.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddMasterDataState(var Builder: TextBuilder)
    var
        MasterData: Record "MobileNAV Master Data";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        MasterData.SetLoadFields(SystemModifiedAt);
        if MasterData.FindSet() then
            repeat
                Rows += 1;
                if MasterData.SystemModifiedAt > Latest then
                    Latest := MasterData.SystemModifiedAt;
            until MasterData.Next() = 0;
        this.AddState(Builder, 'MasterData', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV Profile Setup.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddProfileSetupState(var Builder: TextBuilder)
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        ProfileSetup.SetLoadFields(SystemModifiedAt);
        if ProfileSetup.FindSet() then
            repeat
                Rows += 1;
                if ProfileSetup.SystemModifiedAt > Latest then
                    Latest := ProfileSetup.SystemModifiedAt;
            until ProfileSetup.Next() = 0;
        this.AddState(Builder, 'ProfileSetup', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV License Setup.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddLicenseSetupState(var Builder: TextBuilder)
    var
        LicenseSetup: Record "MobileNAV License Setup";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        LicenseSetup.SetLoadFields(SystemModifiedAt);
        if LicenseSetup.FindSet() then
            repeat
                Rows += 1;
                if LicenseSetup.SystemModifiedAt > Latest then
                    Latest := LicenseSetup.SystemModifiedAt;
            until LicenseSetup.Next() = 0;
        this.AddState(Builder, 'LicenseSetup', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV User Setup.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddUserSetupState(var Builder: TextBuilder)
    var
        UserSetup: Record "MobileNAV User Setup";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        UserSetup.SetLoadFields(SystemModifiedAt);
        if UserSetup.FindSet() then
            repeat
                Rows += 1;
                if UserSetup.SystemModifiedAt > Latest then
                    Latest := UserSetup.SystemModifiedAt;
            until UserSetup.Next() = 0;
        this.AddState(Builder, 'UserSetup', Rows, Latest);
    end;

    /// <summary>Adds the state of MobileNAV CaptionML Admin.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    local procedure AddCaptionMLAdminState(var Builder: TextBuilder)
    var
        CaptionMLAdmin: Record "MobileNAV CaptionML Admin.";
        Rows: Integer;
        Latest: DateTime;
    begin
        Rows := 0;
        Latest := 0DT;
        CaptionMLAdmin.SetLoadFields(SystemModifiedAt);
        if CaptionMLAdmin.FindSet() then
            repeat
                Rows += 1;
                if CaptionMLAdmin.SystemModifiedAt > Latest then
                    Latest := CaptionMLAdmin.SystemModifiedAt;
            until CaptionMLAdmin.Next() = 0;
        this.AddState(Builder, 'CaptionMLAdmin', Rows, Latest);
    end;

    /// <summary>Appends one table segment to the fingerprint.</summary>
    /// <param name="Builder">The fingerprint being built.</param>
    /// <param name="TableName">A short name for the table.</param>
    /// <param name="Rows">The row count.</param>
    /// <param name="Latest">The latest SystemModifiedAt of the rows, or 0DT for none.</param>
    local procedure AddState(var Builder: TextBuilder; TableName: Text; Rows: Integer; Latest: DateTime)
    begin
        Builder.Append('|' + TableName + '=' + Format(Rows) + ':' + Format(Latest, 0, 9));
    end;

    /// <summary>Converts the settings buffer rows of a build to JSON. Each row is an array of its stored field values.</summary>
    /// <param name="Source">The rows of the build.</param>
    /// <returns>One JSON array per row.</returns>
    procedure SettingsToJson(var Source: Record "MobileNAV Settings Buffer" temporary): JsonArray
    var
        RecRef: RecordRef;
        Row: JsonArray;
        Rows: JsonArray;
    begin
        if Source.FindSet() then
            repeat
                RecRef.GetTable(Source);
                Row := this.RowValues(RecRef, 5);
                this.AddSettingsBlobs(Source, Row);
                Rows.Add(Row);
            until Source.Next() = 0;
        exit(Rows);
    end;

    /// <summary>Converts the Sett. Buff. Main rows of a build to JSON.</summary>
    /// <param name="Source">The rows of the build.</param>
    /// <returns>One JSON array per row.</returns>
    procedure MainExtraToJson(var Source: Record "MobileNAV Sett. Buff. Main" temporary): JsonArray
    var
        RecRef: RecordRef;
        Rows: JsonArray;
    begin
        if Source.FindSet() then
            repeat
                RecRef.GetTable(Source);
                Rows.Add(this.RowValues(RecRef, 0));
            until Source.Next() = 0;
        exit(Rows);
    end;

    /// <summary>Converts the dynamic layout rows of a build to JSON.</summary>
    /// <param name="Source">The rows of the build.</param>
    /// <returns>One JSON array per row.</returns>
    procedure LayoutToJson(var Source: Record "MobileNAV Dynamic Layout Buff." temporary): JsonArray
    var
        RecRef: RecordRef;
        Rows: JsonArray;
    begin
        if Source.FindSet() then
            repeat
                RecRef.GetTable(Source);
                Rows.Add(this.RowValues(RecRef, 0));
            until Source.Next() = 0;
        exit(Rows);
    end;

    /// <summary>Converts the layout condition rows of a build to JSON.</summary>
    /// <param name="Source">The rows of the build.</param>
    /// <returns>One JSON array per row.</returns>
    procedure ConditionToJson(var Source: Record "MobileNAV D. L. Cond. Buff." temporary): JsonArray
    var
        RecRef: RecordRef;
        Rows: JsonArray;
    begin
        if Source.FindSet() then
            repeat
                RecRef.GetTable(Source);
                Rows.Add(this.RowValues(RecRef, 0));
            until Source.Next() = 0;
        exit(Rows);
    end;

    /// <summary>Converts the layout action rows of a build to JSON.</summary>
    /// <param name="Source">The rows of the build.</param>
    /// <returns>One JSON array per row.</returns>
    procedure ActionToJson(var Source: Record "MobileNAV D. L. Action Buff." temporary): JsonArray
    var
        RecRef: RecordRef;
        Rows: JsonArray;
    begin
        if Source.FindSet() then
            repeat
                RecRef.GetTable(Source);
                Rows.Add(this.RowValues(RecRef, 0));
            until Source.Next() = 0;
        exit(Rows);
    end;

    /// <summary>Converts the layout action line rows of a build to JSON.</summary>
    /// <param name="Source">The rows of the build.</param>
    /// <returns>One JSON array per row.</returns>
    procedure ActionLineToJson(var Source: Record "MobileNAV D. L. Act. L. Buff." temporary): JsonArray
    var
        RecRef: RecordRef;
        Rows: JsonArray;
    begin
        if Source.FindSet() then
            repeat
                RecRef.GetTable(Source);
                Rows.Add(this.RowValues(RecRef, 0));
            until Source.Next() = 0;
        exit(Rows);
    end;

    /// <summary>Fills the settings buffer copy from JSON rows made by SettingsToJson. The target is emptied first.</summary>
    /// <param name="Rows">The JSON rows.</param>
    /// <param name="Target">Receives the rows.</param>
    /// <returns>False when a row does not match the table. The target then holds a part of the rows, so the caller must not use it.</returns>
    procedure SettingsFromJson(Rows: JsonArray; var Target: Record "MobileNAV Settings Buffer" temporary): Boolean
    var
        RecRef: RecordRef;
        Token: JsonToken;
    begin
        Target.Reset();
        Target.DeleteAll(false);
        foreach Token in Rows do begin
            if not Token.IsArray() then
                exit(false);
            Target.Init();
            RecRef.GetTable(Target);
            if not this.FillRow(Token.AsArray(), RecRef, 5) then
                exit(false);
            RecRef.SetTable(Target);
            if not this.ReadSettingsBlobs(Token.AsArray(), Target) then
                exit(false);
            Target.Insert(false);
        end;
        exit(true);
    end;

    /// <summary>Fills the Sett. Buff. Main copy from JSON rows made by MainExtraToJson. The target is emptied first.</summary>
    /// <param name="Rows">The JSON rows.</param>
    /// <param name="Target">Receives the rows.</param>
    /// <returns>False when a row does not match the table.</returns>
    procedure MainExtraFromJson(Rows: JsonArray; var Target: Record "MobileNAV Sett. Buff. Main" temporary): Boolean
    var
        RecRef: RecordRef;
        Token: JsonToken;
    begin
        Target.Reset();
        Target.DeleteAll(false);
        foreach Token in Rows do begin
            if not Token.IsArray() then
                exit(false);
            Target.Init();
            RecRef.GetTable(Target);
            if not this.FillRow(Token.AsArray(), RecRef, 0) then
                exit(false);
            RecRef.SetTable(Target);
            Target.Insert(false);
        end;
        exit(true);
    end;

    /// <summary>Fills the dynamic layout copy from JSON rows made by LayoutToJson. The target is emptied first.</summary>
    /// <param name="Rows">The JSON rows.</param>
    /// <param name="Target">Receives the rows.</param>
    /// <returns>False when a row does not match the table.</returns>
    procedure LayoutFromJson(Rows: JsonArray; var Target: Record "MobileNAV Dynamic Layout Buff." temporary): Boolean
    var
        RecRef: RecordRef;
        Token: JsonToken;
    begin
        Target.Reset();
        Target.DeleteAll(false);
        foreach Token in Rows do begin
            if not Token.IsArray() then
                exit(false);
            Target.Init();
            RecRef.GetTable(Target);
            if not this.FillRow(Token.AsArray(), RecRef, 0) then
                exit(false);
            RecRef.SetTable(Target);
            Target.Insert(false);
        end;
        exit(true);
    end;

    /// <summary>Fills the layout condition copy from JSON rows made by ConditionToJson. The target is emptied first.</summary>
    /// <param name="Rows">The JSON rows.</param>
    /// <param name="Target">Receives the rows.</param>
    /// <returns>False when a row does not match the table.</returns>
    procedure ConditionFromJson(Rows: JsonArray; var Target: Record "MobileNAV D. L. Cond. Buff." temporary): Boolean
    var
        RecRef: RecordRef;
        Token: JsonToken;
    begin
        Target.Reset();
        Target.DeleteAll(false);
        foreach Token in Rows do begin
            if not Token.IsArray() then
                exit(false);
            Target.Init();
            RecRef.GetTable(Target);
            if not this.FillRow(Token.AsArray(), RecRef, 0) then
                exit(false);
            RecRef.SetTable(Target);
            Target.Insert(false);
        end;
        exit(true);
    end;

    /// <summary>Fills the layout action copy from JSON rows made by ActionToJson. The target is emptied first.</summary>
    /// <param name="Rows">The JSON rows.</param>
    /// <param name="Target">Receives the rows.</param>
    /// <returns>False when a row does not match the table.</returns>
    procedure ActionFromJson(Rows: JsonArray; var Target: Record "MobileNAV D. L. Action Buff." temporary): Boolean
    var
        RecRef: RecordRef;
        Token: JsonToken;
    begin
        Target.Reset();
        Target.DeleteAll(false);
        foreach Token in Rows do begin
            if not Token.IsArray() then
                exit(false);
            Target.Init();
            RecRef.GetTable(Target);
            if not this.FillRow(Token.AsArray(), RecRef, 0) then
                exit(false);
            RecRef.SetTable(Target);
            Target.Insert(false);
        end;
        exit(true);
    end;

    /// <summary>Fills the layout action line copy from JSON rows made by ActionLineToJson. The target is emptied first.</summary>
    /// <param name="Rows">The JSON rows.</param>
    /// <param name="Target">Receives the rows.</param>
    /// <returns>False when a row does not match the table.</returns>
    procedure ActionLineFromJson(Rows: JsonArray; var Target: Record "MobileNAV D. L. Act. L. Buff." temporary): Boolean
    var
        RecRef: RecordRef;
        Token: JsonToken;
    begin
        Target.Reset();
        Target.DeleteAll(false);
        foreach Token in Rows do begin
            if not Token.IsArray() then
                exit(false);
            Target.Init();
            RecRef.GetTable(Target);
            if not this.FillRow(Token.AsArray(), RecRef, 0) then
                exit(false);
            RecRef.SetTable(Target);
            Target.Insert(false);
        end;
        exit(true);
    end;

    /// <summary>Tells whether a field is saved. Only normal fields with a number below the system field range are saved.</summary>
    /// <param name="Item">The field.</param>
    /// <returns>True for a saved field.</returns>
    local procedure IsStored(var Item: FieldRef): Boolean
    var
        SystemFieldFirstNo: Integer;
    begin
        SystemFieldFirstNo := 2000000000;
        exit((Item.Class() = FieldClass::Normal) and (Item.Number() < SystemFieldFirstNo));
    end;

    /// <summary>Returns the stored values of one row, in field order. Blob fields are left out: the caller writes them.</summary>
    /// <param name="RecRef">The row, opened on its table.</param>
    /// <param name="BlobsHandled">The number of blob fields the caller writes itself.</param>
    /// <returns>One JSON string per stored field that is not a blob.</returns>
    local procedure RowValues(var RecRef: RecordRef; BlobsHandled: Integer): JsonArray
    var
        Item: FieldRef;
        Values: JsonArray;
        BlobCount: Integer;
        Index: Integer;
    begin
        for Index := 1 to RecRef.FieldCount() do begin
            Item := RecRef.FieldIndex(Index);
            if this.IsStored(Item) and (Item.Type() = FieldType::Blob) then
                BlobCount += 1;
            if this.IsStored(Item) and (Item.Type() <> FieldType::Blob) then
                Values.Add(this.ValueText(Item));
        end;
        if BlobCount <> BlobsHandled then
            Error(this.BlobCountErr, BlobCount, BlobsHandled);
        exit(Values);
    end;

    /// <summary>Writes the stored values of one row into a row that was initialised from its table. The values come in field order, then the extra values.</summary>
    /// <param name="Values">The JSON strings from RowValues, followed by the extra values.</param>
    /// <param name="RecRef">The row, opened on its table.</param>
    /// <param name="ExtraValues">The number of values at the end that are not field values, such as blob text.</param>
    /// <returns>False when a value cannot be read or the count does not match.</returns>
    local procedure FillRow(Values: JsonArray; var RecRef: RecordRef; ExtraValues: Integer): Boolean
    var
        Item: FieldRef;
        Token: JsonToken;
        Index: Integer;
        Position: Integer;
    begin
        Position := 0;
        for Index := 1 to RecRef.FieldCount() do begin
            Item := RecRef.FieldIndex(Index);
            if this.IsStored(Item) and (Item.Type() <> FieldType::Blob) then begin
                if not Values.Get(Position, Token) then
                    exit(false);
                if not this.AssignValue(Item, Token.AsValue().AsText()) then
                    exit(false);
                Position += 1;
            end;
        end;
        exit(Position + ExtraValues = Values.Count());
    end;

    /// <summary>Adds the five blob fields of a settings row as base64 text, after the field values.</summary>
    /// <param name="Source">The settings row.</param>
    /// <param name="Row">Receives the base64 texts.</param>
    local procedure AddSettingsBlobs(var Source: Record "MobileNAV Settings Buffer" temporary; var Row: JsonArray)
    var
        Base64Convert: Codeunit "Base64 Convert";
        InStr: InStream;
    begin
        Source.Template.CreateInStream(InStr);
        Row.Add(Base64Convert.ToBase64(InStr));
        Source."List Cell Formats".CreateInStream(InStr);
        Row.Add(Base64Convert.ToBase64(InStr));
        Source."Option Strings BLOB".CreateInStream(InStr);
        Row.Add(Base64Convert.ToBase64(InStr));
        Source.OptionValuesBLOB.CreateInStream(InStr);
        Row.Add(Base64Convert.ToBase64(InStr));
        Source.OptionCaptionsBLOB.CreateInStream(InStr);
        Row.Add(Base64Convert.ToBase64(InStr));
    end;

    /// <summary>Writes the five blob fields of a settings row from the base64 texts at the end of its values.</summary>
    /// <param name="Values">The JSON values of the row.</param>
    /// <param name="Target">The row, already filled with its field values.</param>
    /// <returns>False when the row has no blob texts or a text cannot be decoded.</returns>
    local procedure ReadSettingsBlobs(Values: JsonArray; var Target: Record "MobileNAV Settings Buffer" temporary): Boolean
    var
        OutStr: OutStream;
        Start: Integer;
    begin
        if Values.Count() < 5 then
            exit(false);
        Start := Values.Count() - 5;
        Target.Template.CreateOutStream(OutStr);
        if not this.DecodeBlob(Values, Start, OutStr) then
            exit(false);
        Target."List Cell Formats".CreateOutStream(OutStr);
        if not this.DecodeBlob(Values, Start + 1, OutStr) then
            exit(false);
        Target."Option Strings BLOB".CreateOutStream(OutStr);
        if not this.DecodeBlob(Values, Start + 2, OutStr) then
            exit(false);
        Target.OptionValuesBLOB.CreateOutStream(OutStr);
        if not this.DecodeBlob(Values, Start + 3, OutStr) then
            exit(false);
        Target.OptionCaptionsBLOB.CreateOutStream(OutStr);
        exit(this.DecodeBlob(Values, Start + 4, OutStr));
    end;

    /// <summary>Decodes one base64 text of a row into a blob. An empty text leaves the blob empty.</summary>
    /// <param name="Values">The JSON values of the row.</param>
    /// <param name="Index">The position of the text in Values.</param>
    /// <param name="OutStr">The blob to write.</param>
    /// <returns>False when the position does not exist.</returns>
    local procedure DecodeBlob(Values: JsonArray; Index: Integer; var OutStr: OutStream): Boolean
    var
        Base64Convert: Codeunit "Base64 Convert";
        Token: JsonToken;
        Base64Text: Text;
    begin
        if not Values.Get(Index, Token) then
            exit(false);
        Base64Text := Token.AsValue().AsText();
        if Base64Text = '' then
            exit(true);
        Base64Convert.FromBase64(Base64Text, OutStr);
        exit(true);
    end;

    /// <summary>Formats one field value as text.</summary>
    /// <param name="Item">The field.</param>
    /// <returns>The text to store.</returns>
    local procedure ValueText(var Item: FieldRef): Text
    var
        BooleanValue: Boolean;
        GuidValue: Guid;
        TextValue: Text;
    begin
        case Item.Type() of
            FieldType::Boolean:
                begin
                    BooleanValue := Item.Value();
                    if BooleanValue then
                        exit('1');
                    exit('0');
                end;
            FieldType::Integer, FieldType::Option, FieldType::BigInteger, FieldType::Decimal:
                exit(Format(Item.Value(), 0, 9));
            FieldType::Text, FieldType::Code:
                begin
                    TextValue := Item.Value();
                    exit(TextValue);
                end;
            FieldType::Guid:
                begin
                    GuidValue := Item.Value();
                    exit(Format(GuidValue));
                end;
            FieldType::Date, FieldType::Time, FieldType::DateTime:
                exit(this.OffsetText(Item));
        end;
        Error(this.UnsupportedFieldErr, Item.Name(), Format(Item.Type()));
    end;

    /// <summary>Formats a date, time or date-time as an offset from zero, so that a blank value comes back blank.</summary>
    /// <param name="Item">The field.</param>
    /// <returns>The offset as text: days for a date, milliseconds for a time or a date-time.</returns>
    local procedure OffsetText(var Item: FieldRef): Text
    var
        DateValue: Date;
        TimeValue: Time;
        DateTimeValue: DateTime;
        DayCount: Integer;
        Offset: Decimal;
    begin
        case Item.Type() of
            FieldType::Date:
                begin
                    DateValue := Item.Value();
                    DayCount := DateValue - 0D;
                    exit(Format(DayCount, 0, 9));
                end;
            FieldType::Time:
                begin
                    TimeValue := Item.Value();
                    Offset := TimeValue - 000000T;
                    exit(Format(Offset, 0, 9));
                end;
        end;
        DateTimeValue := Item.Value();
        Offset := DateTimeValue - 0DT;
        exit(Format(Offset, 0, 9));
    end;

    /// <summary>Writes one stored value into a field. It is the reverse of ValueText.</summary>
    /// <param name="Item">The field.</param>
    /// <param name="StoredText">The text from ValueText.</param>
    /// <returns>False when the text does not read as the field type.</returns>
    local procedure AssignValue(var Item: FieldRef; StoredText: Text): Boolean
    var
        BooleanValue: Boolean;
        GuidValue: Guid;
    begin
        case Item.Type() of
            FieldType::Boolean:
                begin
                    BooleanValue := StoredText = '1';
                    Item.Value(BooleanValue);
                    exit(true);
                end;
            FieldType::Integer, FieldType::Option, FieldType::BigInteger, FieldType::Decimal:
                exit(this.AssignNumber(Item, StoredText));
            FieldType::Text, FieldType::Code:
                begin
                    Item.Value(StoredText);
                    exit(true);
                end;
            FieldType::Guid:
                begin
                    if not Evaluate(GuidValue, StoredText) then
                        exit(false);
                    Item.Value(GuidValue);
                    exit(true);
                end;
            FieldType::Date, FieldType::Time, FieldType::DateTime:
                exit(this.AssignTemporal(Item, StoredText));
        end;
        exit(false);
    end;

    /// <summary>Writes one stored number into an integer, option, big integer or decimal field.</summary>
    /// <param name="Item">The field.</param>
    /// <param name="StoredText">The text from ValueText.</param>
    /// <returns>False when the text is not a number of the field type.</returns>
    local procedure AssignNumber(var Item: FieldRef; StoredText: Text): Boolean
    var
        BigIntegerValue: BigInteger;
        DecimalValue: Decimal;
        IntegerValue: Integer;
    begin
        case Item.Type() of
            FieldType::Integer, FieldType::Option:
                begin
                    if not Evaluate(IntegerValue, StoredText, 9) then
                        exit(false);
                    Item.Value(IntegerValue);
                end;
            FieldType::BigInteger:
                begin
                    if not Evaluate(BigIntegerValue, StoredText, 9) then
                        exit(false);
                    Item.Value(BigIntegerValue);
                end;
            else begin
                if not Evaluate(DecimalValue, StoredText, 9) then
                    exit(false);
                Item.Value(DecimalValue);
            end;
        end;
        exit(true);
    end;

    /// <summary>Writes one stored offset into a date, time or date-time field. It is the reverse of OffsetText.</summary>
    /// <param name="Item">The field.</param>
    /// <param name="StoredText">The text from OffsetText.</param>
    /// <returns>False when the text is not an offset of the field type.</returns>
    local procedure AssignTemporal(var Item: FieldRef; StoredText: Text): Boolean
    var
        DateValue: Date;
        DateTimeValue: DateTime;
        DayCount: Integer;
        DecimalValue: Decimal;
        Offset: Duration;
        TimeValue: Time;
    begin
        case Item.Type() of
            FieldType::Date:
                begin
                    if not Evaluate(DayCount, StoredText, 9) then
                        exit(false);
                    DateValue := 0D + DayCount;
                    Item.Value(DateValue);
                end;
            FieldType::Time:
                begin
                    if not Evaluate(DecimalValue, StoredText, 9) then
                        exit(false);
                    Offset := DecimalValue;
                    TimeValue := 000000T + Offset;
                    Item.Value(TimeValue);
                end;
            else begin
                if not Evaluate(DecimalValue, StoredText, 9) then
                    exit(false);
                Offset := DecimalValue;
                DateTimeValue := 0DT + Offset;
                Item.Value(DateTimeValue);
            end;
        end;
        exit(true);
    end;

    var
        MobileNAVAppIdTok: Label 'fd09b53c-ff32-4d9c-91ce-6a82a87b8c9c', Locked = true;
        FormatVersionTok: Label 'v1', Locked = true;
        BlobCountErr: Label 'The emulator cache found %1 blob fields in a row, and it handles %2.', Comment = '%1 = the blob fields found, %2 = the blob fields handled';
        UnsupportedFieldErr: Label 'The emulator cache cannot store the field %1 of type %2.', Comment = '%1 = the field name, %2 = the field type';
}

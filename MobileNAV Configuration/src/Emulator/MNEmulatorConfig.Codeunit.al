namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The cache of one user's built MobileNAV configuration. A rolled-back build from
/// "BJF MN Emulator Config Run" fills it, and the emulator's screens read the copies without a
/// rebuild. Load keeps the copies of this session while the MobileNAV fingerprint holds, and reads
/// the stored build of "BJF MN Emulator Cache" when its fingerprint matches. Only otherwise does it
/// build. EnsureLoaded rebuilds only when nothing is loaded or the user, language or profile differ
/// from the loaded ones. Profile lists come from the live tables.
/// </summary>
codeunit 77724 "BJF MN Emulator Config"
{
    Access = Internal;
    SingleInstance = true;
    Permissions = tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Profile Setup" = r;

    /// <summary>
    /// Loads the configuration of a user. The copies held in this session are kept while the MobileNAV
    /// fingerprint is unchanged. Otherwise the stored build is used when its fingerprint matches. Otherwise
    /// the configuration is built, rolled back, and stored for the next load.
    /// </summary>
    /// <param name="ForUserId">The Business Central user whose configuration is built.</param>
    /// <param name="LanguageCode">MobileNAV language code for the captions, for example ENU.</param>
    /// <param name="ProfileCode">The profile to emulate, or '' for the user's own profile rows.</param>
    procedure Load(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30])
    begin
        this.LoadConfiguration(ForUserId, LanguageCode, ProfileCode, false);
    end;

    /// <summary>
    /// Builds the configuration of a user again, even when the session copies or the stored build still
    /// match. The new build replaces the stored one. Use it when the user asks for a rebuild.
    /// </summary>
    /// <param name="ForUserId">The Business Central user whose configuration is built.</param>
    /// <param name="LanguageCode">MobileNAV language code for the captions, for example ENU.</param>
    /// <param name="ProfileCode">The profile to emulate, or '' for the user's own profile rows.</param>
    procedure Rebuild(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30])
    begin
        this.LoadConfiguration(ForUserId, LanguageCode, ProfileCode, true);
    end;

    /// <summary>
    /// Does the work of Load and Rebuild. A build that fails leaves the copies empty.
    /// </summary>
    /// <param name="ForUserId">The Business Central user whose configuration is needed.</param>
    /// <param name="LanguageCode">MobileNAV language code for the captions, for example ENU.</param>
    /// <param name="ProfileCode">The profile to emulate, or '' for the user's own profile rows.</param>
    /// <param name="Force">True to build even when a copy matches.</param>
    local procedure LoadConfiguration(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; Force: Boolean)
    var
        Cache: Codeunit "BJF MN Emulator Cache Codec";
        Fingerprint: Text[2048];
        Storable: Boolean;
    begin
        Storable := Cache.TryCurrentFingerprint(Fingerprint);
        if not Storable then
            Fingerprint := '';
        if not Force and Storable then begin
            if this.IsCurrent(ForUserId, LanguageCode, ProfileCode, Fingerprint) then
                exit;
            if this.RestoreStored(ForUserId, LanguageCode, ProfileCode, Fingerprint) then
                exit;
        end;
        this.BuildAndStore(ForUserId, LanguageCode, ProfileCode, Fingerprint, Storable);
    end;

    /// <summary>Tells whether the copies of this session are the configuration asked for, built from the current MobileNAV state.</summary>
    /// <param name="ForUserId">The user asked for.</param>
    /// <param name="LanguageCode">The language asked for.</param>
    /// <param name="ProfileCode">The profile asked for.</param>
    /// <param name="Fingerprint">The current fingerprint.</param>
    /// <returns>True when the copies can be used as they are.</returns>
    local procedure IsCurrent(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; Fingerprint: Text[2048]): Boolean
    begin
        exit((Fingerprint <> '') and this.IsLoaded and (this.LoadedUser = ForUserId) and (this.LoadedLanguageCode = LanguageCode) and (this.LoadedProfileCode = ProfileCode) and (this.LoadedFingerprint = Fingerprint));
    end;

    /// <summary>Copies the stored build of the user into the copies of this session, when its fingerprint matches.</summary>
    /// <param name="ForUserId">The user asked for.</param>
    /// <param name="LanguageCode">The language asked for.</param>
    /// <param name="ProfileCode">The profile asked for.</param>
    /// <param name="Fingerprint">The current fingerprint.</param>
    /// <returns>True when the stored build was copied and is now loaded.</returns>
    local procedure RestoreStored(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; Fingerprint: Text[2048]): Boolean
    var
        Cache: Codeunit "BJF MN Emulator Cache Codec";
        Stored: JsonObject;
        Matches: Boolean;
        Restored: Boolean;
    begin
        if Fingerprint = '' then
            exit(false);
        if not Cache.TryRead(ForUserId, LanguageCode, ProfileCode, Fingerprint, Stored, Matches) then
            exit(false);
        if not Matches then
            exit(false);
        if not this.TryRestoreRows(Stored, Restored) then
            exit(false);
        if not Restored then
            exit(false);
        this.SetLoaded(ForUserId, LanguageCode, ProfileCode, Fingerprint);
        exit(true);
    end;

    /// <summary>Builds the configuration in MobileNAV's build run, keeps its rows, and stores them for the next load.</summary>
    /// <param name="ForUserId">The user to build for.</param>
    /// <param name="LanguageCode">The language to build in.</param>
    /// <param name="ProfileCode">The profile to emulate, or ''.</param>
    /// <param name="Fingerprint">The fingerprint taken before the build, or '' when none could be taken.</param>
    /// <param name="Storable">True when the build may be stored.</param>
    local procedure BuildAndStore(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; Fingerprint: Text[2048]; Storable: Boolean)
    var
        ConfigRun: Codeunit "BJF MN Emulator Config Run";
        Started: DateTime;
        Elapsed: Decimal;
        BuildDuration: Integer;
    begin
        Started := CurrentDateTime();
        this.ClearCache();
        ConfigRun.SetUser(ForUserId, LanguageCode);
        ConfigRun.SetProfile(ProfileCode);
        Commit(); // Codeunit.Run with a return value needs a committed transaction.
        ClearLastError();
        if ConfigRun.Run() then
            Error(this.NotRolledBackErr);
        if GetLastErrorText() <> ConfigRun.CompletedMarker() then
            Error(this.BuildFailedErr, GetLastErrorText());
        ConfigRun.GetRows(this.TempRow, this.TempMainExtra, this.TempLayout, this.TempCondition, this.TempAction, this.TempActionLine);
        Elapsed := CurrentDateTime() - Started;
        BuildDuration := Elapsed;
        this.SetLoaded(ForUserId, LanguageCode, ProfileCode, Fingerprint);
        if Storable then
            this.TryStore(ForUserId, LanguageCode, ProfileCode, Fingerprint, BuildDuration);
    end;

    /// <summary>Converts the copies to JSON and stores them. An error in either step leaves no stored build.</summary>
    /// <param name="ForUserId">The user of the build.</param>
    /// <param name="LanguageCode">The language of the build.</param>
    /// <param name="ProfileCode">The profile of the build.</param>
    /// <param name="Fingerprint">The fingerprint the build was started with.</param>
    /// <param name="BuildDuration">The time the build took, in milliseconds.</param>
    /// <returns>False when the store raised an error. The copies of this session are kept either way.</returns>
    [TryFunction]
    local procedure TryStore(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; Fingerprint: Text[2048]; BuildDuration: Integer)
    var
        Cache: Codeunit "BJF MN Emulator Cache Codec";
    begin
        Cache.TryWrite(ForUserId, LanguageCode, ProfileCode, Fingerprint, BuildDuration, this.PayloadJson());
    end;

    /// <summary>Records the user, language, profile and fingerprint of the copies that are now loaded.</summary>
    /// <param name="ForUserId">The user of the copies.</param>
    /// <param name="LanguageCode">The language of the copies.</param>
    /// <param name="ProfileCode">The profile of the copies.</param>
    /// <param name="Fingerprint">The fingerprint the copies were built or checked with.</param>
    local procedure SetLoaded(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]; Fingerprint: Text[2048])
    begin
        this.LoadedUser := ForUserId;
        this.LoadedLanguageCode := LanguageCode;
        this.LoadedProfileCode := ProfileCode;
        this.LoadedFingerprint := Fingerprint;
        this.IsLoaded := true;
    end;

    /// <summary>
    /// Copies the rows of a stored build into the copies of this codeunit. A row that does not fit the table
    /// stops the copy, and the caller then builds the configuration again.
    /// </summary>
    /// <param name="Stored">The stored build as JSON.</param>
    /// <param name="Restored">True when every row kind was copied.</param>
    /// <returns>False when copying raised an error.</returns>
    [TryFunction]
    local procedure TryRestoreRows(Stored: JsonObject; var Restored: Boolean)
    begin
        Restored := this.RestoreFirstRows(Stored) and this.RestoreLastRows(Stored);
    end;

    /// <summary>Copies the settings, Sett. Buff. Main and dynamic layout rows of a stored build.</summary>
    /// <param name="Stored">The stored build as JSON.</param>
    /// <returns>False when a row array is missing or does not fit its table.</returns>
    local procedure RestoreFirstRows(Stored: JsonObject): Boolean
    var
        Cache: Codeunit "BJF MN Emulator Cache Codec";
        Rows: JsonArray;
    begin
        if not this.RowsOf(Stored, 'settings', Rows) then
            exit(false);
        if not Cache.SettingsFromJson(Rows, this.TempRow) then
            exit(false);
        if not this.RowsOf(Stored, 'mainExtra', Rows) then
            exit(false);
        if not Cache.MainExtraFromJson(Rows, this.TempMainExtra) then
            exit(false);
        if not this.RowsOf(Stored, 'layout', Rows) then
            exit(false);
        exit(Cache.LayoutFromJson(Rows, this.TempLayout));
    end;

    /// <summary>Copies the layout condition, action and action line rows of a stored build.</summary>
    /// <param name="Stored">The stored build as JSON.</param>
    /// <returns>False when a row array is missing or does not fit its table.</returns>
    local procedure RestoreLastRows(Stored: JsonObject): Boolean
    var
        Cache: Codeunit "BJF MN Emulator Cache Codec";
        Rows: JsonArray;
    begin
        if not this.RowsOf(Stored, 'condition', Rows) then
            exit(false);
        if not Cache.ConditionFromJson(Rows, this.TempCondition) then
            exit(false);
        if not this.RowsOf(Stored, 'action', Rows) then
            exit(false);
        if not Cache.ActionFromJson(Rows, this.TempAction) then
            exit(false);
        if not this.RowsOf(Stored, 'actionLine', Rows) then
            exit(false);
        exit(Cache.ActionLineFromJson(Rows, this.TempActionLine));
    end;

    /// <summary>Reads one row array of a stored build.</summary>
    /// <param name="Stored">The stored build.</param>
    /// <param name="RowKey">The name of the row array.</param>
    /// <param name="Rows">Receives the rows.</param>
    /// <returns>False when the stored build has no array under the name.</returns>
    local procedure RowsOf(Stored: JsonObject; RowKey: Text; var Rows: JsonArray): Boolean
    var
        Token: JsonToken;
    begin
        if not Stored.Get(RowKey, Token) then
            exit(false);
        if not Token.IsArray() then
            exit(false);
        Rows := Token.AsArray();
        exit(true);
    end;

    /// <summary>Converts the copies of this codeunit into the stored build.</summary>
    /// <returns>The row arrays of the six row kinds, by the names that RowsOf reads.</returns>
    local procedure PayloadJson(): JsonObject
    var
        Cache: Codeunit "BJF MN Emulator Cache Codec";
        Payload: JsonObject;
    begin
        Payload.Add('settings', Cache.SettingsToJson(this.TempRow));
        Payload.Add('mainExtra', Cache.MainExtraToJson(this.TempMainExtra));
        Payload.Add('layout', Cache.LayoutToJson(this.TempLayout));
        Payload.Add('condition', Cache.ConditionToJson(this.TempCondition));
        Payload.Add('action', Cache.ActionToJson(this.TempAction));
        Payload.Add('actionLine', Cache.ActionLineToJson(this.TempActionLine));
        exit(Payload);
    end;

    /// <summary>
    /// Rebuilds the cache only when nothing is loaded, or when the user, language or profile differ
    /// from the loaded ones.
    /// </summary>
    /// <param name="ForUserId">The Business Central user whose configuration is needed.</param>
    /// <param name="LanguageCode">MobileNAV language code for the captions, for example ENU.</param>
    /// <param name="ProfileCode">The profile to emulate, or '' for the user's own profile rows.</param>
    procedure EnsureLoaded(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30])
    begin
        if this.IsLoaded and (this.LoadedUser = ForUserId) and (this.LoadedLanguageCode = LanguageCode) and (this.LoadedProfileCode = ProfileCode) then
            exit;
        this.Load(ForUserId, LanguageCode, ProfileCode);
    end;

    /// <summary>The user of the loaded configuration.</summary>
    /// <returns>The user ID, or '' when nothing is loaded.</returns>
    procedure LoadedUserId(): Code[50]
    begin
        exit(this.LoadedUser);
    end;

    /// <summary>The caption language of the loaded configuration.</summary>
    /// <returns>The MobileNAV language code, or '' when nothing is loaded.</returns>
    procedure LoadedLanguage(): Code[10]
    begin
        exit(this.LoadedLanguageCode);
    end;

    /// <summary>The profile of the loaded configuration.</summary>
    /// <returns>The profile code, or '' when nothing is loaded or the user's own profile rows are emulated.</returns>
    procedure LoadedProfile(): Code[30]
    begin
        exit(this.LoadedProfileCode);
    end;

    /// <summary>Tells whether the cache holds a built configuration.</summary>
    /// <returns>True when a configuration is loaded.</returns>
    procedure IsConfigurationLoaded(): Boolean
    begin
        exit(this.IsLoaded);
    end;

    /// <summary>
    /// Copies the cached settings buffer rows of one service, every Line Type, into the caller's
    /// record. The caller's record is emptied first.
    /// </summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetRow">Receives the rows.</param>
    procedure CopyRows(ServiceName: Text; var TargetRow: Record "MobileNAV Settings Buffer" temporary)
    begin
        TargetRow.Reset();
        TargetRow.DeleteAll(false);
        this.TempRow.Reset();
        if ServiceName <> '' then
            this.TempRow.SetRange("Service Name", ServiceName);
        if this.TempRow.FindSet() then
            repeat
                TargetRow := this.TempRow;
                TargetRow.Insert(false);
            until this.TempRow.Next() = 0;
        this.TempRow.Reset();
    end;

    /// <summary>
    /// Copies the Main row of one service into the caller's record. The caller's record is emptied
    /// first, and the copied row is the only row and the current one.
    /// </summary>
    /// <param name="ServiceName">The Service Name of the service.</param>
    /// <param name="MainRow">Receives the Main row.</param>
    /// <returns>True when the cache holds a Main row for the service.</returns>
    procedure FindMain(ServiceName: Text; var MainRow: Record "MobileNAV Settings Buffer" temporary): Boolean
    begin
        MainRow.Reset();
        MainRow.DeleteAll(false);
        this.TempRow.Reset();
        this.TempRow.SetRange("Line Type", this.TempRow."Line Type"::Main);
        this.TempRow.SetRange("Service Name", ServiceName);
        if not this.TempRow.FindFirst() then begin
            this.TempRow.Reset();
            exit(false);
        end;
        MainRow := this.TempRow;
        this.TempRow.Reset();
        MainRow.Insert(false);
        exit(true);
    end;

    /// <summary>
    /// Copies the cached Sett. Buff. Main rows of one service into the caller's record. The caller's
    /// record is emptied first.
    /// </summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetExtra">Receives the rows.</param>
    procedure CopyMainExtra(ServiceName: Text; var TargetExtra: Record "MobileNAV Sett. Buff. Main" temporary)
    begin
        TargetExtra.Reset();
        TargetExtra.DeleteAll(false);
        this.TempMainExtra.Reset();
        if ServiceName <> '' then
            this.TempMainExtra.SetRange("Service Name", ServiceName);
        if this.TempMainExtra.FindSet() then
            repeat
                TargetExtra := this.TempMainExtra;
                TargetExtra.Insert(false);
            until this.TempMainExtra.Next() = 0;
        this.TempMainExtra.Reset();
    end;

    /// <summary>
    /// Copies the cached dynamic layout, condition, action and action line rows of one service into
    /// the caller's records. Each caller's record is emptied first.
    /// </summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetLayout">Receives the dynamic layout rows.</param>
    /// <param name="TargetCondition">Receives the layout condition rows.</param>
    /// <param name="TargetAction">Receives the layout action rows.</param>
    /// <param name="TargetActionLine">Receives the layout action line rows.</param>
    procedure CopyLayouts(ServiceName: Text; var TargetLayout: Record "MobileNAV Dynamic Layout Buff." temporary; var TargetCondition: Record "MobileNAV D. L. Cond. Buff." temporary; var TargetAction: Record "MobileNAV D. L. Action Buff." temporary; var TargetActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary)
    begin
        this.CopyLayoutRows(ServiceName, TargetLayout);
        this.CopyConditionRows(ServiceName, TargetCondition);
        this.CopyActionRows(ServiceName, TargetAction);
        this.CopyActionLineRows(ServiceName, TargetActionLine);
    end;

    /// <summary>Copies the cached dynamic layout rows of one service into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetLayout">Receives the rows.</param>
    local procedure CopyLayoutRows(ServiceName: Text; var TargetLayout: Record "MobileNAV Dynamic Layout Buff." temporary)
    begin
        TargetLayout.Reset();
        TargetLayout.DeleteAll(false);
        this.TempLayout.Reset();
        if ServiceName <> '' then
            this.TempLayout.SetRange("Service Name", ServiceName);
        if this.TempLayout.FindSet() then
            repeat
                TargetLayout := this.TempLayout;
                TargetLayout.Insert(false);
            until this.TempLayout.Next() = 0;
        this.TempLayout.Reset();
    end;

    /// <summary>Copies the cached layout condition rows of one service into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetCondition">Receives the rows.</param>
    local procedure CopyConditionRows(ServiceName: Text; var TargetCondition: Record "MobileNAV D. L. Cond. Buff." temporary)
    begin
        TargetCondition.Reset();
        TargetCondition.DeleteAll(false);
        this.TempCondition.Reset();
        if ServiceName <> '' then
            this.TempCondition.SetRange("Service Name", ServiceName);
        if this.TempCondition.FindSet() then
            repeat
                TargetCondition := this.TempCondition;
                TargetCondition.Insert(false);
            until this.TempCondition.Next() = 0;
        this.TempCondition.Reset();
    end;

    /// <summary>Copies the cached layout action rows of one service into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetAction">Receives the rows.</param>
    local procedure CopyActionRows(ServiceName: Text; var TargetAction: Record "MobileNAV D. L. Action Buff." temporary)
    begin
        TargetAction.Reset();
        TargetAction.DeleteAll(false);
        this.TempAction.Reset();
        if ServiceName <> '' then
            this.TempAction.SetRange("Service Name", ServiceName);
        if this.TempAction.FindSet() then
            repeat
                TargetAction := this.TempAction;
                TargetAction.Insert(false);
            until this.TempAction.Next() = 0;
        this.TempAction.Reset();
    end;

    /// <summary>Copies the cached layout action line rows of one service into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="ServiceName">The Service Name to copy. '' copies every row.</param>
    /// <param name="TargetActionLine">Receives the rows.</param>
    local procedure CopyActionLineRows(ServiceName: Text; var TargetActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary)
    begin
        TargetActionLine.Reset();
        TargetActionLine.DeleteAll(false);
        this.TempActionLine.Reset();
        if ServiceName <> '' then
            this.TempActionLine.SetRange("Service Name", ServiceName);
        if this.TempActionLine.FindSet() then
            repeat
                TargetActionLine := this.TempActionLine;
                TargetActionLine.Insert(false);
            until this.TempActionLine.Next() = 0;
        this.TempActionLine.Reset();
    end;

    /// <summary>
    /// Reads the device colours from MobileNAV Master Data: the rows of Type Color, one per colour area, with
    /// Red, Green and Blue from 0 to 255. The rows have no user or profile key, so every user and profile gets
    /// the same theme. The obsolete areas (Normal to Title) are left out. An area without a row is left out too,
    /// so the caller keeps its own colour for it.
    /// </summary>
    /// <returns>The theme, with one property per colour area, for example PageBackground: #227DAF.</returns>
    procedure ThemeJson(): JsonObject
    var
        ColorRow: Record "MobileNAV Master Data";
        Theme: JsonObject;
        AreaName: Text;
        Ordinal: Integer;
    begin
        ColorRow.SetRange(Type, ColorRow.Type::Color);
        ColorRow.SetLoadFields(Area, Red, Green, Blue);
        if ColorRow.FindSet() then
            repeat
                Ordinal := ColorRow.Area;
                AreaName := this.ColorAreaName(Ordinal);
                if AreaName <> '' then
                    if Theme.Contains(AreaName) then
                        Theme.Replace(AreaName, this.HexColor(ColorRow.Red, ColorRow.Green, ColorRow.Blue))
                    else
                        Theme.Add(AreaName, this.HexColor(ColorRow.Red, ColorRow.Green, ColorRow.Blue));
            until ColorRow.Next() = 0;
        exit(Theme);
    end;

    /// <summary>Returns the member name of a colour area, or '' for an obsolete area.</summary>
    /// <param name="Ordinal">The ordinal of the Area option of a colour row.</param>
    /// <returns>The member name, for example PageBackground, or ''.</returns>
    local procedure ColorAreaName(Ordinal: Integer): Text
    var
        AreaNames: List of [Text];
    begin
        if Ordinal <= 5 then // Ordinals 0 to 5, Normal to Title, are obsolete.
            exit('');
        AreaNames := this.AreaNamesTok.Split(',');
        if Ordinal >= AreaNames.Count() then
            exit('');
        exit(AreaNames.Get(Ordinal + 1));
    end;

    /// <summary>Formats the Red, Green and Blue values of a colour as a CSS hex colour.</summary>
    /// <param name="Red">The red value, 0 to 255.</param>
    /// <param name="Green">The green value, 0 to 255.</param>
    /// <param name="Blue">The blue value, 0 to 255.</param>
    /// <returns>The colour as #RRGGBB in capitals.</returns>
    local procedure HexColor(Red: Integer; Green: Integer; Blue: Integer): Text
    begin
        exit('#' + this.HexByte(Red) + this.HexByte(Green) + this.HexByte(Blue));
    end;

    /// <summary>Formats one colour value as two hex digits. A value outside 0 to 255 is limited to that range.</summary>
    /// <param name="Value">The colour value.</param>
    /// <returns>Two hex digits in capitals.</returns>
    local procedure HexByte(Value: Integer): Text
    begin
        if Value < 0 then
            Value := 0;
        if Value > 255 then
            Value := 255;
        exit(CopyStr(this.HexDigitsTok, Value div 16 + 1, 1) + CopyStr(this.HexDigitsTok, Value mod 16 + 1, 1));
    end;

    /// <summary>
    /// Lists every profile code that exists, and the profile codes assigned to a user. Both lists
    /// are read from the live tables and come in key order, which is ascending, without duplicates.
    /// </summary>
    /// <param name="ForUserId">The user whose assigned profiles are listed.</param>
    /// <param name="AllProfiles">Receives every profile code.</param>
    /// <param name="UserProfiles">Receives the profile codes of the user's user-level profile rows.</param>
    procedure ProfileCodes(ForUserId: Code[50]; var AllProfiles: List of [Text]; var UserProfiles: List of [Text])
    var
        MasterData: Record "MobileNAV Master Data";
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        Clear(AllProfiles);
        Clear(UserProfiles);

        MasterData.SetRange(MasterData.Type, MasterData.Type::Profile);
        MasterData.SetLoadFields("Code");
        if MasterData.FindSet() then
            repeat
                if not AllProfiles.Contains(MasterData."Code") then
                    AllProfiles.Add(MasterData."Code");
            until MasterData.Next() = 0;

        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        ProfileSetup.SetRange(ID, ForUserId);
        ProfileSetup.SetLoadFields("Profile");
        if ProfileSetup.FindSet() then
            repeat
                if not UserProfiles.Contains(ProfileSetup."Profile") then
                    UserProfiles.Add(ProfileSetup."Profile");
            until ProfileSetup.Next() = 0;
    end;

    /// <summary>Empties the cached rows and forgets the loaded user, language and profile.</summary>
    local procedure ClearCache()
    begin
        this.TempRow.Reset();
        this.TempRow.DeleteAll(false);
        this.TempMainExtra.Reset();
        this.TempMainExtra.DeleteAll(false);
        this.TempLayout.Reset();
        this.TempLayout.DeleteAll(false);
        this.TempCondition.Reset();
        this.TempCondition.DeleteAll(false);
        this.TempAction.Reset();
        this.TempAction.DeleteAll(false);
        this.TempActionLine.Reset();
        this.TempActionLine.DeleteAll(false);
        this.LoadedUser := '';
        this.LoadedLanguageCode := '';
        this.LoadedProfileCode := '';
        this.LoadedFingerprint := '';
        this.IsLoaded := false;
    end;

    var
        TempRow: Record "MobileNAV Settings Buffer" temporary;
        TempMainExtra: Record "MobileNAV Sett. Buff. Main" temporary;
        TempLayout: Record "MobileNAV Dynamic Layout Buff." temporary;
        TempCondition: Record "MobileNAV D. L. Cond. Buff." temporary;
        TempAction: Record "MobileNAV D. L. Action Buff." temporary;
        TempActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary;
        LoadedUser: Code[50];
        LoadedLanguageCode: Code[10];
        LoadedProfileCode: Code[30];
        LoadedFingerprint: Text[2048];
        IsLoaded: Boolean;
        HexDigitsTok: Label '0123456789ABCDEF', Locked = true;
        AreaNamesTok: Label 'Normal,Dark,Border,Background,FirstLine,Title,ButtonTitleBackground,ButtonTitleForeground,HighlightBackground,HighlightForeground,DialogBorder,Separator,GroupSeparator,WindowBackground,WindowForeground,DisabledButtonBackground,DisabledButtonForeground,CardDisabledCaption,CardMandatoryCaption,CardValidatedCaption,PageBackground,PageForeground,TitleToolbarBackground,TitleToolbarForeground,HomeTileBackground,CardAdditionalCaption,ToolbarAdditionalCaption,Custom1,Custom2,Custom3,Custom4,Custom5,Custom6,Custom7,Custom8,Custom9,Custom10', Locked = true;
        NotRolledBackErr: Label 'The emulator''s configuration run finished without rolling back. Nothing was changed on purpose, check the user''s MobileNAV rows.';
        BuildFailedErr: Label '%1', Comment = '%1 = the error the configuration build stopped with';
}

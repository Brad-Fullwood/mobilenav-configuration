namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The one entry point of the device emulator. It answers the requests of the emulator page and
/// of the API page "BJF MN Emulator Request API". The configuration comes from the session cache
/// of "BJF MN Emulator Config", lists from "BJF MN Emulator List" and cards from
/// "BJF MN Emulator Card". Respond runs each request in "BJF MN Emulator Request Run", so an
/// error comes back as an error response.
/// </summary>
codeunit 77723 "BJF MN Emulator"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV License Setup" = r,
        tabledata "MobileNAV Settings Buffer" = r;

    /// <summary>
    /// Answers one emulator request. The request is a JSON object whose kind picks the answer:
    /// menu (a user's main menu), profiles, list, card, lookup, bufferState, connection, action, update,
    /// dialogAnswer, newCard, create or dialogRun. Requests of kind list, card, lookup, profiles, action, update,
    /// dialogAnswer, newCard, create and dialogRun load the configuration first when the one loaded differs
    /// from what they name. Connection and bufferState do not. Any other kind raises an error. Use Respond
    /// from callers that must not stop on an error.
    /// </summary>
    /// <param name="RequestText">The request JSON, for example {"kind":"menu","user":"ADMIN"}.</param>
    /// <returns>The response JSON. Its kind is the request's kind.</returns>
    procedure Handle(RequestText: Text): Text
    var
        EmulatorActions: Codeunit "BJF MN Emulator Actions";
        Request: JsonObject;
        Response: JsonObject;
        Kind: Text;
        ResponseText: Text;
    begin
        Kind := this.RequestKind(RequestText, Request);

        case Kind of
            'menu':
                Response := this.MenuJson(this.RequestUser(Request), this.RequestLanguage(Request), this.RequestProfile(Request));
            'bufferState':
                Response := this.BufferStateJson(this.RequestUser(Request));
            'connection':
                Response := EmulatorActions.ConnectionJson();
            else
                Response := this.SessionResponse(Kind, Request);
        end;

        if not Response.Contains('kind') then
            Response.Add('kind', Kind);
        Response.WriteTo(ResponseText);
        exit(ResponseText);
    end;

    /// <summary>Reads the kind of a request and returns the request object it came from.</summary>
    /// <param name="RequestText">The request JSON text.</param>
    /// <param name="Request">Receives the parsed request object.</param>
    /// <returns>The kind of the request.</returns>
    local procedure RequestKind(RequestText: Text; var Request: JsonObject): Text
    var
        KindToken: JsonToken;
    begin
        if not Request.ReadFrom(RequestText) then
            Error(this.InvalidRequestErr);
        if not Request.Get('kind', KindToken) then
            Error(this.MissingKindErr);
        if not KindToken.IsValue() then
            Error(this.MissingKindErr);
        if KindToken.AsValue().IsNull() then
            Error(this.MissingKindErr);
        exit(KindToken.AsValue().AsText());
    end;

    /// <summary>Answers a list request, after loading the configuration it names.</summary>
    /// <param name="Request">The list request.</param>
    /// <returns>The list response object.</returns>
    local procedure ListResponse(Request: JsonObject): JsonObject
    var
        ListRun: Codeunit "BJF MN Emulator List";
    begin
        this.EnsureSession(Request);
        exit(ListRun.ListJson(Request));
    end;

    /// <summary>Answers a card request, after loading the configuration it names.</summary>
    /// <param name="Request">The card request.</param>
    /// <returns>The card response object.</returns>
    local procedure CardResponse(Request: JsonObject): JsonObject
    var
        CardRun: Codeunit "BJF MN Emulator Card";
    begin
        this.EnsureSession(Request);
        exit(CardRun.CardJson(Request));
    end;

    /// <summary>Answers a lookup request, after loading the configuration it names.</summary>
    /// <param name="Request">The lookup request.</param>
    /// <returns>The lookup response object.</returns>
    local procedure LookupResponse(Request: JsonObject): JsonObject
    var
        LookupRun: Codeunit "BJF MN Emulator Lookup";
    begin
        this.EnsureSession(Request);
        exit(LookupRun.LookupJson(Request));
    end;

    /// <summary>
    /// Answers a request that needs the configuration it names: profiles, list, card, lookup, the
    /// requests that write through the page service, and the forms requests. Any other kind raises an error.
    /// </summary>
    /// <param name="Kind">The request kind.</param>
    /// <param name="Request">The request object.</param>
    /// <returns>The response object of the kind.</returns>
    local procedure SessionResponse(Kind: Text; Request: JsonObject): JsonObject
    var
        Response: JsonObject;
    begin
        case Kind of
            'profiles':
                Response := this.ProfilesJson(this.EnsureSession(Request));
            'list':
                Response := this.ListResponse(Request);
            'card':
                Response := this.CardResponse(Request);
            'lookup':
                Response := this.LookupResponse(Request);
            'action', 'update', 'dialogAnswer':
                Response := this.ActionsResponse(Kind, Request);
            'newCard', 'create', 'dialogRun':
                Response := this.FormsResponse(Kind, Request);
            else
                Error(this.UnknownKindErr, Kind);
        end;
        exit(Response);
    end;

    /// <summary>
    /// Answers a request that makes a new record or runs a dialog: newCard, create or dialogRun. The
    /// configuration is loaded first, as for a list or card.
    /// </summary>
    /// <param name="Kind">The request kind: newCard, create or dialogRun.</param>
    /// <param name="Request">The request object.</param>
    /// <returns>The answer of the forms codeunit.</returns>
    local procedure FormsResponse(Kind: Text; Request: JsonObject): JsonObject
    var
        EmulatorForms: Codeunit "BJF MN Emulator Forms";
    begin
        this.EnsureSession(Request);
        case Kind of
            'newCard':
                exit(EmulatorForms.NewCardJson(Request));
            'create':
                exit(EmulatorForms.CreateJson(Request));
            else
                exit(EmulatorForms.DialogRunJson(Request));
        end;
    end;

    /// <summary>
    /// Answers a request that writes through the page service: a button, a field edit or a dialog
    /// answer. The configuration is loaded first, as for a list or card.
    /// </summary>
    /// <param name="Kind">The request kind: action, update or dialogAnswer.</param>
    /// <param name="Request">The request object.</param>
    /// <returns>The answer of the actions codeunit.</returns>
    local procedure ActionsResponse(Kind: Text; Request: JsonObject): JsonObject
    var
        EmulatorActions: Codeunit "BJF MN Emulator Actions";
    begin
        this.EnsureSession(Request);
        case Kind of
            'action':
                exit(EmulatorActions.ActionJson(Request));
            'update':
                exit(EmulatorActions.UpdateJson(Request));
            else
                exit(EmulatorActions.DialogAnswerJson(Request));
        end;
    end;

    /// <summary>
    /// Answers one emulator request without raising an error. The request runs in
    /// "BJF MN Emulator Request Run". When it fails, the answer is an error object with the message.
    /// </summary>
    /// <param name="RequestText">The request JSON, as Handle takes it.</param>
    /// <returns>The response JSON, or {"kind":"error","message":...,"request":...} when the request fails.</returns>
    procedure Respond(RequestText: Text): Text
    var
        TempRequest: Record "BJF MN Emulator Request" temporary;
    begin
        if StrLen(RequestText) > MaxStrLen(TempRequest.Request) then
            exit(this.ErrorText(StrSubstNo(this.TooLongErr, MaxStrLen(TempRequest.Request)), this.KindOf(RequestText)));

        TempRequest.Validate("Entry No.", 1);
        TempRequest.Validate(Request, CopyStr(RequestText, 1, MaxStrLen(TempRequest.Request)));
        TempRequest.Insert(false);
        Commit(); // Codeunit.Run with a return value needs a committed transaction.
        ClearLastError();
        if Codeunit.Run(Codeunit::"BJF MN Emulator Request Run", TempRequest) then
            exit(TempRequest.GetResponse());
        exit(this.ErrorText(GetLastErrorText(), this.KindOf(RequestText)));
    end;

    /// <summary>Runs MobileNAV's configuration build for a user and returns the user's main menu.</summary>
    /// <param name="ForUserId">The Business Central user whose menu is built.</param>
    /// <param name="LanguageCode">MobileNAV language code for the captions, for example ENU.</param>
    /// <param name="ProfileCode">The profile to emulate, or '' for the user's own profile rows.</param>
    /// <returns>JSON with the user, the language, the profile, the theme and the categories, each with its tiles.</returns>
    procedure MenuJson(ForUserId: Code[50]; LanguageCode: Code[10]; ProfileCode: Code[30]): JsonObject
    var
        TempMenuRows: Record "MobileNAV Settings Buffer" temporary;
        Config: Codeunit "BJF MN Emulator Config";
        Menu: JsonObject;
        Categories: JsonArray;
    begin
        Config.Load(ForUserId, LanguageCode, ProfileCode);
        Config.CopyRows('', TempMenuRows);
        TempMenuRows.SetRange("Line Type", TempMenuRows."Line Type"::Main);

        this.AddCategories(TempMenuRows, Categories);
        Menu.Add('kind', 'menu');
        Menu.Add('user', ForUserId);
        Menu.Add('language', LanguageCode);
        Menu.Add('profile', ProfileCode);
        Menu.Add('theme', Config.ThemeJson());
        Menu.Add('categories', Categories);
        exit(Menu);
    end;

    /// <summary>Adds one object per category, in the order of each category's lowest tile Order.</summary>
    /// <param name="MenuRows">The menu rows of the build.</param>
    /// <param name="Categories">Receives the category objects.</param>
    local procedure AddCategories(var MenuRows: Record "MobileNAV Settings Buffer" temporary; var Categories: JsonArray)
    var
        SortKeys: List of [Text];
        ServiceOfKey: Dictionary of [Text, Text];
        CategoryOfKey: Dictionary of [Text, Text];
        CategoryCodes: List of [Text];
        CategoryCaptions: Dictionary of [Text, Text];
        SortKey: Text;
        CategoryCode: Text;
    begin
        MenuRows.SetRange(DisplayInMenu, true);
        if MenuRows.FindSet() then
            repeat
                SortKey := this.TileSortKey(MenuRows);
                SortKeys.Add(SortKey);
                ServiceOfKey.Set(SortKey, MenuRows."Service Name");
                CategoryOfKey.Set(SortKey, MenuRows.Category);
            until MenuRows.Next() = 0;
        this.InsertionSort(SortKeys);

        foreach SortKey in SortKeys do begin
            CategoryCode := CategoryOfKey.Get(SortKey);
            if not CategoryCodes.Contains(CategoryCode) then begin
                CategoryCodes.Add(CategoryCode);
                this.FindRow(MenuRows, ServiceOfKey.Get(SortKey));
                CategoryCaptions.Set(CategoryCode, this.CategoryCaption(MenuRows));
            end;
        end;

        foreach CategoryCode in CategoryCodes do
            Categories.Add(this.CategoryJson(MenuRows, SortKeys, ServiceOfKey, CategoryOfKey, CategoryCode, CategoryCaptions.Get(CategoryCode)));
    end;

    /// <summary>Builds one category object with its tiles in sort order.</summary>
    /// <param name="MenuRows">The menu rows of the build.</param>
    /// <param name="SortKeys">The tile sort keys, in sort order.</param>
    /// <param name="ServiceOfKey">The Service Name of each sort key.</param>
    /// <param name="CategoryOfKey">The category code of each sort key.</param>
    /// <param name="CategoryCode">The category to build.</param>
    /// <param name="CategoryCaptionText">The caption of the category.</param>
    /// <returns>The category object with its tiles.</returns>
    local procedure CategoryJson(var MenuRows: Record "MobileNAV Settings Buffer" temporary; SortKeys: List of [Text]; ServiceOfKey: Dictionary of [Text, Text]; CategoryOfKey: Dictionary of [Text, Text]; CategoryCode: Text; CategoryCaptionText: Text): JsonObject
    var
        Category: JsonObject;
        Tiles: JsonArray;
        SortKey: Text;
    begin
        foreach SortKey in SortKeys do
            if CategoryOfKey.Get(SortKey) = CategoryCode then begin
                this.FindRow(MenuRows, ServiceOfKey.Get(SortKey));
                Tiles.Add(this.TileJson(MenuRows));
            end;
        Category.Add('code', CategoryCode);
        Category.Add('caption', CategoryCaptionText);
        Category.Add('tiles', Tiles);
        exit(Category);
    end;

    /// <summary>Builds one tile object from the current menu row.</summary>
    /// <param name="MenuRows">The menu rows, positioned on the tile.</param>
    /// <returns>The tile object.</returns>
    local procedure TileJson(var MenuRows: Record "MobileNAV Settings Buffer" temporary): JsonObject
    var
        Pictures: Codeunit "BJF MN Emulator Pictures";
        Tile: JsonObject;
        TileCaption: Text;
    begin
        TileCaption := MenuRows.LocalizedName;
        if TileCaption = '' then
            TileCaption := MenuRows."Service Name";
        Tile.Add('service', MenuRows."Service Name");
        Tile.Add('caption', TileCaption);
        Tile.Add('pageId', MenuRows."Object ID");
        Tile.Add('order', MenuRows."Order");
        Tile.Add('pageType', Format(MenuRows."Page Type"));
        Tile.Add('mainMenuAction', this.MainMenuActionText(MenuRows));
        // Only a Main row with a menu picture version can have a tile picture, so the other tiles skip the read.
        if MenuRows."Menu Picture Version" > 0 then
            Pictures.AddTilePicture(MenuRows."Service Name", Tile);
        exit(Tile);
    end;

    /// <summary>
    /// What the tile does when tapped. Only a tile of a card page in the menu has one: Create opens a new
    /// record, Open opens the single record. The rule is MobileNAV's own (GetMainMenuActionText).
    /// </summary>
    /// <param name="MenuRows">The menu rows, positioned on the tile's Main row.</param>
    /// <returns>Create, Open, or '' for a tile with no main menu action.</returns>
    local procedure MainMenuActionText(var MenuRows: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        if not MenuRows.DisplayInMenu then
            exit('');
        if not (MenuRows."Page Type" in [MenuRows."Page Type"::Card, MenuRows."Page Type"::OfflineCard]) then
            exit('');
        case MenuRows."Main Menu Action" of
            MenuRows."Main Menu Action"::Create:
                exit(this.CreateActionLbl);
            MenuRows."Main Menu Action"::Open:
                exit(this.OpenActionLbl);
        end;
        exit('');
    end;

    /// <summary>The caption of a category: its localized name, its code, or the Other label for no category.</summary>
    /// <param name="MenuRows">The menu rows, positioned on a tile of the category.</param>
    /// <returns>The category caption.</returns>
    local procedure CategoryCaption(var MenuRows: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        if MenuRows.CategoryLocalizedName <> '' then
            exit(MenuRows.CategoryLocalizedName);
        if MenuRows.Category <> '' then
            exit(MenuRows.Category);
        exit(this.OtherLbl);
    end;

    /// <summary>Sort key of a tile: its Order padded to ten digits, then its Service Name.</summary>
    /// <param name="MenuRows">The menu rows, positioned on the tile.</param>
    /// <returns>The sort key.</returns>
    local procedure TileSortKey(var MenuRows: Record "MobileNAV Settings Buffer" temporary): Text
    begin
        exit(Format(MenuRows."Order", 0, '<Integer,10><Filler Character,0>') + '|' + MenuRows."Service Name");
    end;

    /// <summary>Positions the menu rows on the row of a Service Name. The row filter on DisplayInMenu stays set.</summary>
    /// <param name="MenuRows">The menu rows to position.</param>
    /// <param name="ServiceName">The Service Name of the row.</param>
    local procedure FindRow(var MenuRows: Record "MobileNAV Settings Buffer" temporary; ServiceName: Text)
    begin
        MenuRows.SetRange("Service Name", ServiceName);
        if not MenuRows.FindFirst() then
            Error(this.MissingRowErr, ServiceName);
    end;

    /// <summary>Sorts the keys ascending with an insertion sort. The lists are short.</summary>
    /// <param name="Keys">The keys to sort in place.</param>
    local procedure InsertionSort(var Keys: List of [Text])
    var
        Index: Integer;
        Position: Integer;
        Current: Text;
        Shifting: Boolean;
    begin
        for Index := 2 to Keys.Count() do begin
            Current := Keys.Get(Index);
            Position := Index - 1;
            Shifting := Position > 0;
            while Shifting do
                if Keys.Get(Position) > Current then begin
                    Keys.Set(Position + 1, Keys.Get(Position));
                    Position := Position - 1;
                    Shifting := Position > 0;
                end else
                    Shifting := false;
            Keys.Set(Position + 1, Current);
        end;
    end;

    /// <summary>
    /// Loads the configuration that a list, card, profiles or write request reads. The user is the one
    /// the request names, else the loaded user, else the session user. Language and profile that the
    /// request does not carry come from the loaded configuration only when the user is the loaded user.
    /// Otherwise they are the session language and the profile ''. An empty user or language counts as
    /// not carried. An empty profile names the user's own profile rows.
    /// </summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The user the request resolves to.</returns>
    local procedure EnsureSession(Request: JsonObject): Code[50]
    var
        Config: Codeunit "BJF MN Emulator Config";
        ScreenRenderer: Codeunit "BJF MN Screen Renderer";
        DefaultUser: Code[50];
        DefaultLanguage: Code[10];
        DefaultProfile: Code[30];
        UserCode: Code[50];
        LanguageCode: Code[10];
        ProfileCode: Code[30];
    begin
        if Config.IsConfigurationLoaded() then
            DefaultUser := Config.LoadedUserId()
        else
            DefaultUser := CopyStr(UserId(), 1, MaxStrLen(DefaultUser));

        UserCode := CopyStr(this.TextValue(Request, 'user', DefaultUser), 1, MaxStrLen(UserCode));
        if UserCode = '' then
            UserCode := DefaultUser;

        if Config.IsConfigurationLoaded() and (UserCode = Config.LoadedUserId()) then begin
            DefaultLanguage := Config.LoadedLanguage();
            DefaultProfile := Config.LoadedProfile();
        end else begin
            DefaultLanguage := ScreenRenderer.SessionLanguageCode();
            DefaultProfile := '';
        end;

        LanguageCode := CopyStr(this.TextValue(Request, 'language', DefaultLanguage), 1, MaxStrLen(LanguageCode));
        if LanguageCode = '' then
            LanguageCode := DefaultLanguage;
        ProfileCode := CopyStr(this.TextValue(Request, 'profile', DefaultProfile), 1, MaxStrLen(ProfileCode));
        Config.EnsureLoaded(UserCode, LanguageCode, ProfileCode);
        exit(UserCode);
    end;

    /// <summary>Lists the profile codes that exist and the ones assigned to a user.</summary>
    /// <param name="ForUserId">The user whose assigned profiles are listed.</param>
    /// <returns>JSON with the user, all profile codes and the assigned profile codes.</returns>
    local procedure ProfilesJson(ForUserId: Code[50]): JsonObject
    var
        Config: Codeunit "BJF MN Emulator Config";
        AllProfiles: List of [Text];
        UserProfiles: List of [Text];
        AllArray: JsonArray;
        AssignedArray: JsonArray;
        ProfileCodeText: Text;
        Profiles: JsonObject;
    begin
        Config.ProfileCodes(ForUserId, AllProfiles, UserProfiles);
        foreach ProfileCodeText in AllProfiles do
            AllArray.Add(ProfileCodeText);
        foreach ProfileCodeText in UserProfiles do
            AssignedArray.Add(ProfileCodeText);

        Profiles.Add('kind', 'profiles');
        Profiles.Add('user', ForUserId);
        Profiles.Add('all', AllArray);
        Profiles.Add('assigned', AssignedArray);
        exit(Profiles);
    end;

    /// <summary>
    /// Reports what a user's settings buffer holds, so a test can prove that a menu build left
    /// nothing behind. Read-only.
    /// </summary>
    /// <param name="ForUserId">The user whose buffer rows and license setup are read.</param>
    /// <returns>JSON with the user, the sorted Query IDs, the row count and the license setup marks.</returns>
    local procedure BufferStateJson(ForUserId: Code[50]): JsonObject
    var
        SettingsBuffer: Record "MobileNAV Settings Buffer";
        MNLicSetup: Record "MobileNAV License Setup";
        QueryIds: List of [Integer];
        QueryIdArray: JsonArray;
        State: JsonObject;
        RowCount: Integer;
        ConfigurationChanged: Boolean;
        LastLoginText: Text;
        QueryId: Integer;
    begin
        SettingsBuffer.SetRange("User ID", ForUserId);
        SettingsBuffer.SetLoadFields("Query ID");
        if SettingsBuffer.FindSet() then
            repeat
                RowCount += 1;
                QueryId := SettingsBuffer."Query ID";
                if not QueryIds.Contains(QueryId) then
                    QueryIds.Add(QueryId);
            until SettingsBuffer.Next() = 0;
        this.SortIntegers(QueryIds);
        foreach QueryId in QueryIds do
            QueryIdArray.Add(QueryId);

        MNLicSetup.SetLoadFields("Configuration Changed", "Last Login Date");
        if MNLicSetup.Get(CompanyName(), MNLicSetup.Type::User, ForUserId) then begin
            ConfigurationChanged := MNLicSetup."Configuration Changed";
            if MNLicSetup."Last Login Date" <> 0DT then
                LastLoginText := Format(MNLicSetup."Last Login Date", 0, 9);
        end;

        State.Add('kind', 'bufferState');
        State.Add('user', ForUserId);
        State.Add('queryIds', QueryIdArray);
        State.Add('rowCount', RowCount);
        State.Add('configurationChanged', ConfigurationChanged);
        State.Add('lastLoginDate', LastLoginText);
        exit(State);
    end;

    /// <summary>Builds the error response that Respond returns.</summary>
    /// <param name="Message">The message of the error.</param>
    /// <param name="FailedKind">The kind of the request that failed, or '' when it has none.</param>
    /// <returns>The error response JSON.</returns>
    local procedure ErrorText(Message: Text; FailedKind: Text): Text
    var
        ErrorObject: JsonObject;
        ErrorBody: Text;
    begin
        ErrorObject.Add('kind', 'error');
        ErrorObject.Add('message', Message);
        ErrorObject.Add('request', FailedKind);
        ErrorObject.WriteTo(ErrorBody);
        exit(ErrorBody);
    end;

    /// <summary>Reads the kind of a request text without raising an error.</summary>
    /// <param name="RequestText">The request text.</param>
    /// <returns>The kind, or '' when the text is not a JSON object with a kind.</returns>
    local procedure KindOf(RequestText: Text): Text
    var
        Request: JsonObject;
    begin
        if not Request.ReadFrom(RequestText) then
            exit('');
        exit(this.TextValue(Request, 'kind', ''));
    end;

    /// <summary>Reads the user of a request, or the user of the session when the request has none.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The user ID.</returns>
    local procedure RequestUser(Request: JsonObject): Code[50]
    var
        UserCode: Code[50];
    begin
        UserCode := CopyStr(this.TextValue(Request, 'user', UserId()), 1, MaxStrLen(UserCode));
        exit(UserCode);
    end;

    /// <summary>Reads the caption language of a request, or the language of the session when the request has none.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The MobileNAV language code.</returns>
    local procedure RequestLanguage(Request: JsonObject): Code[10]
    var
        ScreenRenderer: Codeunit "BJF MN Screen Renderer";
        LanguageCode: Code[10];
    begin
        LanguageCode := CopyStr(this.TextValue(Request, 'language', ScreenRenderer.SessionLanguageCode()), 1, MaxStrLen(LanguageCode));
        exit(LanguageCode);
    end;

    /// <summary>Reads the profile of a menu request, or '' when the request names none.</summary>
    /// <param name="Request">The request JSON object.</param>
    /// <returns>The profile code.</returns>
    local procedure RequestProfile(Request: JsonObject): Code[30]
    var
        ProfileCode: Code[30];
    begin
        ProfileCode := CopyStr(this.TextValue(Request, 'profile', ''), 1, MaxStrLen(ProfileCode));
        exit(ProfileCode);
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
        if not Request.Get(PropertyName, Token) then
            exit(DefaultText);
        if not Token.IsValue() then
            exit(DefaultText);
        if Token.AsValue().IsNull() then
            exit(DefaultText);
        exit(Token.AsValue().AsText());
    end;

    /// <summary>Sorts the values ascending with an insertion sort. The lists are short.</summary>
    /// <param name="Values">The values to sort in place.</param>
    local procedure SortIntegers(var Values: List of [Integer])
    var
        Index: Integer;
        Position: Integer;
        Current: Integer;
        Shifting: Boolean;
    begin
        for Index := 2 to Values.Count() do begin
            Current := Values.Get(Index);
            Position := Index;
            Shifting := Position > 1;
            while Shifting do
                if Values.Get(Position - 1) > Current then begin
                    Values.Set(Position, Values.Get(Position - 1));
                    Position := Position - 1;
                    Shifting := Position > 1;
                end else
                    Shifting := false;
            Values.Set(Position, Current);
        end;
    end;

    var
        InvalidRequestErr: Label 'The emulator request is not a JSON object.';
        MissingKindErr: Label 'The emulator request has no kind. Send a JSON object with a kind, for example menu, list or card.';
        UnknownKindErr: Label 'The emulator request kind %1 is not known. Use menu, profiles, list, card, lookup, bufferState, connection, action, update, dialogAnswer, newCard, create or dialogRun.', Comment = '%1 = the kind the request sent';
        CreateActionLbl: Label 'Create', Locked = true;
        OpenActionLbl: Label 'Open', Locked = true;
        TooLongErr: Label 'The emulator request is longer than %1 characters.', Comment = '%1 = the length the request field holds';
        MissingRowErr: Label 'The menu has no row for the service %1.', Comment = '%1 = Service Name';
        OtherLbl: Label 'Other';
}

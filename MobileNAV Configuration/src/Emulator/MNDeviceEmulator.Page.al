namespace BradFullwood.MobileNAV.Configuration;

using System.Azure.Identity;
using System.Environment.Configuration;
using System.Security.Authentication;
using System.Text;

/// <summary>
/// Sets up the device emulator and shows a chosen user's MobileNAV device screens beside the setup. The Options and Emulator
/// Setup groups sit in the left column, and the phone with the device draws in the right column. The Options group picks the
/// user, the language and the profile, and the device follows them. The Emulator Setup group holds the token source, the Entra
/// app registration and the write switches. The emulator connects when the page opens and after each setup change. When the
/// connection fails, a notification says why and offers Connect, and for the MobileNAV Token source Request MobileNAV Token.
/// The choices of the signed-in user are kept, and the page restores them when it opens. The Emulator help FactBox shows the
/// steps of the selected token source. Buttons, field edits and scans go to the tenant's MobileNAV page services when the
/// emulator setup allows writes.
/// </summary>
page 77700 "BJF MN Device Emulator"
{
    ApplicationArea = All;
    Caption = 'MobileNAV Device Emulator';
    PageType = Card;
    SourceTable = "BJF MN Emulator Setup";
    UsageCategory = Administration;
    AdditionalSearchTerms = 'MobileNAV,emulator,device,menu,tiles,lists,cards,emulator setup,token,connect,app registration,O365';
    DeleteAllowed = false;
    InsertAllowed = false;
    Permissions = tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV User Setup" = r;

    layout
    {
        area(Content)
        {
            group(Columns)
            {
                ShowCaption = false;

                group(LeftColumn)
                {
                    ShowCaption = false;

                    group(Options)
                    {
                        Caption = 'Options';

                        field(UserIdField; this.UserIdValue)
                        {
                            Caption = 'User ID';
                            ToolTip = 'Specifies the Business Central user whose MobileNAV main menu is drawn.';

                            trigger OnValidate()
                            begin
                                this.RememberChoices();
                            end;
                        }
                        field(LanguageField; this.LanguageCode)
                        {
                            Caption = 'Language';
                            ToolTip = 'Specifies the MobileNAV language code the captions are drawn in, for example ENU or DEU.';

                            trigger OnValidate()
                            begin
                                this.RememberChoices();
                            end;
                        }
                        field(ProfileField; this.ProfileValue)
                        {
                            Caption = 'Profile';
                            ToolTip = 'Specifies the MobileNAV profile to emulate. Leave it empty to use the profiles the user has.';

                            trigger OnValidate()
                            begin
                                this.RememberChoices();
                            end;

                            trigger OnLookup(var Text: Text): Boolean
                            var
                                AllProfiles: List of [Text];
                                AssignedProfiles: List of [Text];
                                Options: TextBuilder;
                                ProfileName: Text;
                                Choice: Integer;
                                I: Integer;
                            begin
                                this.Config.ProfileCodes(this.UserIdValue, AllProfiles, AssignedProfiles);
                                if AllProfiles.Count() = 0 then begin
                                    Message(this.NoProfilesLbl);
                                    exit(false);
                                end;

                                for I := 1 to AllProfiles.Count() do begin
                                    AllProfiles.Get(I, ProfileName);
                                    if I > 1 then
                                        Options.Append(',');
                                    Options.Append(ProfileName);
                                    if AssignedProfiles.Contains(ProfileName) then
                                        Options.Append(this.AssignedSuffixLbl);
                                end;

                                Choice := StrMenu(Options.ToText(), 0, this.ChooseProfileLbl);
                                if Choice = 0 then
                                    exit(false);

                                AllProfiles.Get(Choice, ProfileName);
                                this.ProfileValue := CopyStr(ProfileName, 1, MaxStrLen(this.ProfileValue));
                                this.RememberChoices();
                                Text := this.ProfileValue;
                                exit(true);
                            end;
                        }
                    }
                    group(EmulatorSetup)
                    {
                        Caption = 'Emulator Setup';

                        field(ConnectedField; this.ConnectedValue)
                        {
                            Caption = 'Connected';
                            Editable = false;
                            StyleExpr = this.ConnectedStyleTxt;
                            ToolTip = 'Specifies whether the emulator has a token now. When it has none, a notification says why.';
                        }
                        field("Token Source"; Rec."Token Source")
                        {
                            ToolTip = 'Specifies how the emulator gets its token. The help panel shows the steps of the selected source.';

                            trigger OnValidate()
                            begin
                                Rec.Modify(true);
                                this.SourceChanged();
                                CurrPage.Update(false);
                            end;
                        }
                        field("Client ID"; Rec."Client ID")
                        {
                            Visible = this.AppRegistrationSource;

                            trigger OnValidate()
                            begin
                                Rec.Modify(true);
                                this.UpdateConnection();
                                CurrPage.Update(false);
                            end;
                        }
                        field(ClientSecretField; this.ClientSecretValue)
                        {
                            Caption = 'Client Secret';
                            ExtendedDatatype = Masked;
                            Visible = this.AppRegistrationSource;
                            ToolTip = 'Specifies the client secret of the Microsoft Entra app registration. It is stored in isolated storage and shows as *** once saved.';

                            trigger OnValidate()
                            begin
                                if (this.ClientSecretValue = '') or (this.ClientSecretValue = this.MaskLbl) then
                                    exit;
                                Rec.SetClientSecret(SecretStrSubstNo('%1', this.ClientSecretValue));
                                this.ClientSecretValue := this.SecretMask();
                                this.UpdateConnection();
                                CurrPage.Update(false);
                            end;
                        }
                        field(RedirectUriField; this.RedirectUriValue)
                        {
                            Caption = 'Redirect URI';
                            Editable = false;
                            Visible = this.AppRegistrationSource;
                            ToolTip = 'Specifies the redirect URI to register on the Web platform of the app registration.';
                        }
                        field(TenantIdField; this.TenantIdValue)
                        {
                            Caption = 'Entra tenant ID';
                            Editable = false;
                            Visible = this.AppRegistrationSource;
                            ToolTip = 'Specifies the Microsoft Entra tenant ID of this environment.';
                        }
                        field("Allow Writes"; Rec."Allow Writes")
                        {
                            ToolTip = 'Specifies whether the emulator may change data. Buttons, field edits and scans change data only when this is on.';

                            trigger OnValidate()
                            begin
                                Rec.Modify(true);
                            end;
                        }
                        field("Allow Writes in Production"; Rec."Allow Writes in Production")
                        {

                            trigger OnValidate()
                            begin
                                Rec.Modify(true);
                                CurrPage.Update(false);
                            end;
                        }
                        field("Device ID"; Rec."Device ID")
                        {

                            trigger OnValidate()
                            begin
                                Rec.Modify(true);
                            end;
                        }
                        field(HttpClientField; this.HttpClientValue)
                        {
                            Caption = 'Allow HttpClient Requests';
                            Editable = false;
                            ToolTip = 'Specifies whether Allow HttpClient Requests is on for this extension. The emulator needs it to call the page services.';
                        }
                    }
                }
                group(RightColumn)
                {
                    ShowCaption = false;

                    usercontrol(Emulator; "BJF MN Emulator")
                    {
                        trigger ControlReady()
                        begin
                            this.ViewerReady := true;
                            if this.LastResponse <> '' then
                                CurrPage.Emulator.Respond(this.LastResponse);
                            this.SendConnection();
                            if this.StartRequested then begin
                                this.StartRequested := false;
                                this.OpenStart();
                            end else
                                this.SendMenu();
                        end;

                        trigger Request(RequestJson: Text)
                        begin
                            this.Send(RequestJson);
                        end;
                    }
                }
            }
        }

        area(FactBoxes)
        {
            part(Help; "BJF MN Emulator Help")
            {
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(TokenGroup)
            {
                Caption = 'Token';

                action(GetMobileNAVTokenAction)
                {
                    ApplicationArea = All;
                    Caption = 'Get Token from MobileNAV Setup';
                    Image = Link;
                    ToolTip = 'Reads the token that MobileNAV stored for the signed-in user and connects with it. Set the token source to MobileNAV Token. When MobileNAV has no stored token, choose Request MobileNAV Token first.';

                    trigger OnAction()
                    begin
                        Rec.Validate("Token Source", "BJF MN Emulator Token Source"::MobileNAVToken);
                        Rec.Modify(true);
                        this.SourceChanged();
                        CurrPage.Update(false);
                    end;
                }
                action(RequestMobileNAVTokenAction)
                {
                    ApplicationArea = All;
                    Caption = 'Request MobileNAV Token';
                    Image = EncryptionKeys;
                    ToolTip = 'Runs the token request of O365 Self-authorization (MobileNAV) and connects. Sign in with the O365 Auth. Email shown on that page.';

                    trigger OnAction()
                    begin
                        Rec.Validate("Token Source", "BJF MN Emulator Token Source"::MobileNAVToken);
                        Rec.Modify(true);
                        this.ShowSourceFields();
                        CurrPage.Help.Page.SetTokenSource(Rec."Token Source".AsInteger());
                        this.SetConnected(this.Connection.RequestMobileNAVToken());
                        this.SendConnection();
                        CurrPage.Update(false);
                    end;
                }
                action(DownloadPowerShellAction)
                {
                    ApplicationArea = All;
                    Caption = 'Download Emulator Sign-in Script (PowerShell)';
                    Image = Download;
                    ToolTip = 'Downloads a PowerShell sign-in script for this environment. The script signs the user in with the device code flow and gives the token to the emulator. It holds no secret.';

                    trigger OnAction()
                    begin
                        this.Script.DownloadPowerShell();
                    end;
                }
                action(DownloadPythonAction)
                {
                    ApplicationArea = All;
                    Caption = 'Download Emulator Sign-in Script (Python)';
                    Image = Download;
                    ToolTip = 'Downloads a Python sign-in script for this environment. The script signs the user in with the device code flow and gives the token to the emulator. It holds no secret. It needs Python 3.';

                    trigger OnAction()
                    begin
                        this.Script.DownloadPython();
                    end;
                }
            }
            action(RebuildConfigurationAction)
            {
                ApplicationArea = All;
                Caption = 'Rebuild Configuration';
                Image = Refresh;
                ToolTip = 'Builds the chosen user''s MobileNAV configuration again, even when a stored copy matches, and redraws the device screens.';

                trigger OnAction()
                begin
                    this.Config.Rebuild(this.UserIdValue, this.LanguageCode, this.ProfileValue);
                    this.ApplyChoices();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Token)
            {
                Caption = 'Token';

                actionref(GetMobileNAVToken_Promoted; GetMobileNAVTokenAction)
                {
                }
                actionref(RequestMobileNAVToken_Promoted; RequestMobileNAVTokenAction)
                {
                }
                actionref(DownloadPowerShell_Promoted; DownloadPowerShellAction)
                {
                }
                actionref(DownloadPython_Promoted; DownloadPythonAction)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
        this.ShowSourceFields();
        this.ClientSecretValue := this.SecretMask();
        this.LoadReadOnlyValues();
        this.RestoreChoices();
        CurrPage.Help.Page.SetTokenSource(Rec."Token Source".AsInteger());
        this.StartRequested := true;
        this.UpdateConnection();
    end;

    trigger OnAfterGetRecord()
    begin
        this.ShowSourceFields();
    end;

    /// <summary>
    /// Sets the MobileNAV service whose list opens after the menu. The device opens it when the control is ready.
    /// A blank service name opens the menu only.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service whose list opens first, or blank.</param>
    procedure SetStartService(ServiceName: Text)
    begin
        this.StartService := ServiceName;
    end;

    /// <summary>Loads the menu of the chosen user, with the profile and language the page holds, once the control is ready.</summary>
    local procedure SendMenu()
    var
        Request: JsonObject;
        RequestText: Text;
    begin
        Request.Add('kind', 'menu');
        Request.Add('user', this.UserIdValue);
        Request.Add('language', this.LanguageCode);
        Request.Add('profile', this.ProfileValue);
        Request.WriteTo(RequestText);
        this.Send(RequestText);
    end;

    /// <summary>Sends the menu, then the list of the start service when one is set. The list answer replaces the menu on the screen.</summary>
    local procedure OpenStart()
    var
        Request: JsonObject;
        RequestText: Text;
    begin
        this.SendMenu();
        if this.StartService = '' then
            exit;
        Request.Add('kind', 'list');
        Request.Add('service', this.StartService);
        Request.WriteTo(RequestText);
        this.Send(RequestText);
    end;

    /// <summary>Asks the emulator for the connection state and passes the answer to the control. The answer does not replace the screen shown.</summary>
    local procedure SendConnection()
    var
        Request: JsonObject;
        RequestText: Text;
        ResponseText: Text;
    begin
        Request.Add('kind', 'connection');
        Request.WriteTo(RequestText);
        ResponseText := this.Engine.Respond(RequestText);
        if this.ViewerReady then
            CurrPage.Emulator.Respond(ResponseText);
    end;

    /// <summary>Runs one request through the emulator and passes the answer to the control.</summary>
    /// <param name="RequestJson">The request JSON from the control or from this page.</param>
    local procedure Send(RequestJson: Text)
    begin
        this.LastResponse := this.Engine.Respond(RequestJson);
        if this.ViewerReady then
            CurrPage.Emulator.Respond(this.LastResponse);
    end;

    /// <summary>Draws the chosen user, language and profile again, once the control is ready.</summary>
    local procedure ApplyChoices()
    begin
        if this.ViewerReady then begin
            this.SendMenu();
            this.SendConnection();
        end;
    end;

    /// <summary>
    /// Restores the user, the language and the profile that the signed-in user chose last. Each stored value is checked first:
    /// the user must have a MobileNAV User Setup, the language must be a supported MobileNAV language, and the profile must be one
    /// that the chosen user has in MobileNAV. A value that fails its check falls back to its default: the signed-in user, the
    /// session language, or no profile.
    /// </summary>
    local procedure RestoreChoices()
    var
        UserCode: Code[50];
        LanguageValue: Code[10];
        StoredProfile: Code[30];
    begin
        UserCode := CopyStr(UserId(), 1, MaxStrLen(UserCode));
        StoredProfile := '';
        LanguageValue := '';
        if this.Preferences.Restore() then begin
            if this.KnownUser(this.Preferences."Emulated User ID") then
                UserCode := this.Preferences."Emulated User ID";
            if this.SupportedLanguage(this.Preferences."Language Code") then
                LanguageValue := this.Preferences."Language Code";
            StoredProfile := this.Preferences."Profile Code";
        end;
        if LanguageValue = '' then
            LanguageValue := this.ScreenRenderer.SessionLanguageCode();

        this.UserIdValue := UserCode;
        this.LanguageCode := LanguageValue;
        this.ProfileValue := this.AvailableProfile(UserCode, StoredProfile);
    end;

    /// <summary>Stores the user, the language and the profile of the signed-in user, then draws them on the device.</summary>
    local procedure RememberChoices()
    begin
        this.Preferences.Remember(this.UserIdValue, this.LanguageCode, this.ProfileValue);
        this.ApplyChoices();
    end;

    /// <summary>Tells whether the user has a MobileNAV User Setup, which MobileNAV needs before the emulator can draw the user's menu.</summary>
    /// <param name="UserCode">The Business Central user ID to check. A blank ID has no setup.</param>
    /// <returns>True when MobileNAV has a user setup for the user.</returns>
    local procedure KnownUser(UserCode: Code[50]): Boolean
    var
        MNUserSetup: Record "MobileNAV User Setup";
    begin
        if UserCode = '' then
            exit(false);
        MNUserSetup.SetLoadFields("User ID");
        exit(MNUserSetup.Get(UserCode));
    end;

    /// <summary>Tells whether a language code is one of the supported MobileNAV languages.</summary>
    /// <param name="LanguageValue">The MobileNAV language code to check.</param>
    /// <returns>True when MobileNAV lists the language as supported.</returns>
    local procedure SupportedLanguage(LanguageValue: Code[10]): Boolean
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if LanguageValue = '' then
            exit(false);
        MasterData.SetRange(Type, MasterData.Type::SuppLang);
        MasterData.SetRange(Code, LanguageValue);
        exit(not MasterData.IsEmpty());
    end;

    /// <summary>Returns the profile when the chosen user has it in MobileNAV, otherwise a blank profile.</summary>
    /// <param name="UserCode">The Business Central user whose profiles are checked.</param>
    /// <param name="StoredProfile">The stored profile to check.</param>
    /// <returns>The profile, or blank when the user does not have it.</returns>
    local procedure AvailableProfile(UserCode: Code[50]; StoredProfile: Code[30]): Code[30]
    var
        AllProfiles: List of [Text];
        AssignedProfiles: List of [Text];
    begin
        if StoredProfile = '' then
            exit('');
        this.Config.ProfileCodes(UserCode, AllProfiles, AssignedProfiles);
        if AllProfiles.Contains(StoredProfile) then
            exit(StoredProfile);
        exit('');
    end;

    /// <summary>Shows the Client ID, the client secret and the app registration fields only when the token source is App Registration.</summary>
    local procedure ShowSourceFields()
    begin
        this.AppRegistrationSource := Rec."Token Source" = "BJF MN Emulator Token Source"::AppRegistration;
    end;

    /// <summary>After the token source changes: shows its fields and help, then connects with it.</summary>
    local procedure SourceChanged()
    begin
        this.ShowSourceFields();
        CurrPage.Help.Page.SetTokenSource(Rec."Token Source".AsInteger());
        this.UpdateConnection();
    end;

    /// <summary>Connects with the token source of the setup, shows the Connected state, and sends the state to the device.</summary>
    local procedure UpdateConnection()
    begin
        this.SetConnected(this.Connection.Connect());
        this.SendConnection();
    end;

    /// <summary>Stores the Connected state and the colour it is shown in: red when the emulator has no token.</summary>
    /// <param name="Connected">Whether the emulator has a token.</param>
    local procedure SetConnected(Connected: Boolean)
    begin
        this.ConnectedValue := Connected;
        if Connected then
            this.ConnectedStyleTxt := Format(PageStyle::Favorable)
        else
            this.ConnectedStyleTxt := Format(PageStyle::Unfavorable);
    end;

    /// <summary>Reads the values the page shows but does not store: the redirect URI, the tenant ID and the HttpClient setting.</summary>
    local procedure LoadReadOnlyValues()
    var
        RedirectUrl: Text;
    begin
        this.OAuth2.GetDefaultRedirectURL(RedirectUrl);
        this.RedirectUriValue := RedirectUrl;
        this.TenantIdValue := this.AzureADTenant.GetAadTenantId();
        this.HttpClientValue := this.HttpClientSetting();
    end;

    /// <summary>The text the masked secret field shows: *** when a secret is stored, otherwise empty.</summary>
    /// <returns>The mask or an empty text.</returns>
    local procedure SecretMask(): Text[250]
    begin
        if Rec.HasClientSecret() then
            exit(this.MaskLbl);
        exit('');
    end;

    /// <summary>Reads Allow HttpClient Requests from the NAV App Setting record of this extension.</summary>
    /// <returns>Yes or No, or unknown when the record cannot be read.</returns>
    local procedure HttpClientSetting(): Text
    var
        NavAppSetting: Record "NAV App Setting";
        ModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        if not NavAppSetting.ReadPermission() then
            exit(this.UnknownLbl);
        NavAppSetting.SetLoadFields("Allow HttpClient Requests");
        if not NavAppSetting.Get(ModuleInfo.Id()) then
            exit(this.UnknownLbl);
        exit(Format(NavAppSetting."Allow HttpClient Requests"));
    end;

    var
        Preferences: Record "BJF MN Emulator Pref";
        Config: Codeunit "BJF MN Emulator Config";
        Connection: Codeunit "BJF MN Emulator Connect";
        Engine: Codeunit "BJF MN Emulator";
        Script: Codeunit "BJF MN Emulator Script";
        ScreenRenderer: Codeunit "BJF MN Screen Renderer";
        AzureADTenant: Codeunit "Azure AD Tenant";
        OAuth2: Codeunit "OAuth2";
        UserIdValue: Code[50];
        LanguageCode: Code[10];
        ProfileValue: Code[30];
        ClientSecretValue: Text[250];
        ConnectedValue: Boolean;
        ConnectedStyleTxt: Text;
        AppRegistrationSource: Boolean;
        RedirectUriValue: Text;
        TenantIdValue: Text;
        HttpClientValue: Text;
        StartService: Text;
        LastResponse: Text;
        ViewerReady: Boolean;
        StartRequested: Boolean;
        MaskLbl: Label '***', Locked = true;
        AssignedSuffixLbl: Label ' (assigned)';
        ChooseProfileLbl: Label 'Choose the profile to emulate.';
        NoProfilesLbl: Label 'No MobileNAV profiles exist.';
        UnknownLbl: Label 'unknown', Comment = 'Shown when the HttpClient setting cannot be read.';
}

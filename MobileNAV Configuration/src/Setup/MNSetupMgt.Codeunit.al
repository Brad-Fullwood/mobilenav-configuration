namespace BradFullwood.MobileNAV.Configuration;

using System.Environment;
using System.Environment.Configuration;
using System.Security.AccessControl;

/// <summary>
/// Runs MobileNAV's initial setup per company without the UI, for the mobilenavSetups and
/// mobilenavUserSetupRequests APIs. Standard route checked: codeunit "MobileNAV Initialization"
/// (InitializeMobileNAV, which starts the trial when no licence exists, runs the add-on upgrade and
/// imports the base configuration) and the MobileNAV Setup Wizard. The wizard is UI only, so this
/// calls the same public procedures it calls: EnableAllowHttpClientRequests, InitializeMobileNAV,
/// the "O365 App ID" fields of the general master data, the MobileNAV user and profile setup
/// inserts of the Add User step, GenerateUserConfig, and "MobileNAV Assisted Setup".Complete.
/// Every step reads its state first and skips when it is already done. The licence is shared by
/// all companies and an installed licence, for example one installed through the mobilenavLicences
/// API, is kept.
/// </summary>
codeunit 77800 "BJF MN Setup Mgt"
{
    Access = Internal;
    Permissions = tabledata "Company" = r,
                  tabledata "MobileNAV Master Data" = rim,
                  tabledata "MobileNAV Profile Setup" = ri,
                  tabledata "MobileNAV User Setup" = rim,
                  tabledata "NAV App Setting" = r,
                  tabledata User = r;

    /// <summary>Fills one row with the licence, configuration, login and Setup Wizard state of this company.</summary>
    /// <param name="Setup">Returns the row. It is not inserted.</param>
    procedure GetStatus(var Setup: Record "BJF MN Setup" temporary)
    var
        Company: Record Company;
        MasterData: Record "MobileNAV Master Data";
        TempLicence: Record "BJF MN Licence" temporary;
        AssistedSetup: Codeunit "MobileNAV Assisted Setup";
        LicenceTransfer: Codeunit "BJF MN Licence Transfer";
        GuidedExperience: Codeunit "Guided Experience";
    begin
        Setup.Init();
        Company.SetLoadFields(SystemId);
        if Company.Get(CompanyName()) then
            Setup.Validate(Id, Company.SystemId);
        Setup.Validate("Has Licence", AssistedSetup.HasLicense());
        Setup.Validate("Has Config", AssistedSetup.HasConfig());
        if Setup."Has Licence" then begin
            LicenceTransfer.GetLicenceInfo(TempLicence);
            Setup.Validate("Licence Expiry", TempLicence."Expiry Date");
            Setup.Validate("Licensed Devices", TempLicence."Licensed Devices");
        end;
        MasterData.SetLoadFields("Authentication Type", "O365 Tenant ID", "O365 App ID", "O365 Redirect URI", "O365 App ID URI");
        if MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then begin
            Setup.Validate("Authentication Type", Format(MasterData."Authentication Type"));
            Setup.Validate("O365 Tenant Id", MasterData."O365 Tenant ID");
            Setup.Validate("O365 App Id", MasterData."O365 App ID");
            Setup.Validate("O365 Redirect Uri", MasterData."O365 Redirect URI");
            Setup.Validate("O365 App Id Uri", MasterData."O365 App ID URI");
        end;
        Setup.Validate("Setup Completed", GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"MobileNAV Setup Wizard"));
        Setup.Validate("Http Allowed", this.IsHttpAllowed());
    end;

    /// <summary>
    /// Runs the setup steps. The o365 fields of the row are the device login values to set, and are
    /// all optional. On return the row holds the new state and the log.
    /// </summary>
    /// <param name="Setup">The request row. It is overwritten with the new state.</param>
    procedure RunSetup(var Setup: Record "BJF MN Setup" temporary)
    var
        TempInput: Record "BJF MN Setup" temporary;
        Log: TextBuilder;
    begin
        TempInput := Setup;
        this.AllowHttp(Log);
        this.InitialiseMobileNAV(Log);
        this.SetLoginValues(TempInput, Log);
        this.CompleteAssistedSetup(Log);
        this.GetStatus(Setup);
        Setup.Validate(Log, CopyStr(Log.ToText().TrimEnd(), 1, MaxStrLen(Setup.Log)));
    end;

    /// <summary>
    /// Adds the MobileNAV user setup and profile of one Business Central user when missing and
    /// generates the user configuration, as the Add User step of the Setup Wizard does.
    /// </summary>
    /// <param name="Request">The request row. It is filled with the resolved user, profile, language and the log.</param>
    procedure AddUser(var Request: Record "BJF MN User Setup Request" temporary)
    var
        User: Record User;
        MasterData: Record "MobileNAV Master Data";
        UserSetup: Record "MobileNAV User Setup";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
        Log: TextBuilder;
        UserId: Code[50];
        ProfileId: Code[30];
        LanguageCode: Code[10];
    begin
        if Request."User Name" = '' then
            Error(this.NoUserNameErr);
        User.SetLoadFields("User Name");
        User.SetRange("User Name", Request."User Name");
        if not User.FindFirst() then
            Error(this.UserNotFoundErr, Request."User Name");
        UserId := CopyStr(User."User Name", 1, MaxStrLen(UserId));

        ProfileId := CopyStr(UpperCase(Request."Profile Id"), 1, MaxStrLen(ProfileId));
        if ProfileId = '' then
            ProfileId := this.DefaultProfileTok;
        MasterData.SetLoadFields(Code);
        if not MasterData.Get(MasterData.Type::Profile, CopyStr(ProfileId, 1, MaxStrLen(MasterData.Code)), 0, '', MasterData.Area::Normal) then
            Error(this.ProfileNotFoundErr, ProfileId);

        this.EnsureUserSetup(UserId, ProfileId, Request."Language Code", Log);
        this.EnsureProfileSetup(UserId, ProfileId, Log);

        LanguageCode := Request."Language Code";
        if LanguageCode = '' then
            LanguageCode := UserSetup.GetUserLanguageCode(UserId);
        CoreFunctions.GenerateUserConfig(UserId, LanguageCode);
        Log.AppendLine(StrSubstNo(this.ConfigGeneratedMsg, UserId, LanguageCode));

        Request.Validate(Id, CreateGuid());
        Request.Validate("User Name", CopyStr(UserId, 1, MaxStrLen(Request."User Name")));
        Request.Validate("Profile Id", ProfileId);
        Request.Validate("Language Code", LanguageCode);
        Request.Validate(Log, CopyStr(Log.ToText().TrimEnd(), 1, MaxStrLen(Request.Log)));
    end;

    local procedure EnsureUserSetup(UserId: Code[50]; ProfileId: Code[30]; LanguageCode: Code[10]; Log: TextBuilder)
    var
        UserSetup: Record "MobileNAV User Setup";
    begin
        if UserSetup.Get(UserId) then begin
            Log.AppendLine(StrSubstNo(this.UserSetupExistsMsg, UserId));
            exit;
        end;
        UserSetup.Init();
        // Validating User ID adds the MOBILENAVUSER role, which GenerateUserConfig requires.
        UserSetup.Validate("User ID", UserId);
        UserSetup.Insert(false);
        if Format(ProfileId).EndsWith(this.OnlineSuffixTok) then
            UserSetup.Validate("Login Mode", UserSetup."Login Mode"::Online)
        else
            if Format(ProfileId).EndsWith(this.OfflineSuffixTok) then
                UserSetup.Validate("Login Mode", UserSetup."Login Mode"::Offline);
        if LanguageCode <> '' then
            UserSetup.Validate("Default Language Code", LanguageCode);
        UserSetup.Modify(true);
        Log.AppendLine(StrSubstNo(this.UserSetupAddedMsg, UserId));
    end;

    local procedure EnsureProfileSetup(UserId: Code[50]; ProfileId: Code[30]; Log: TextBuilder)
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if ProfileSetup.Get(ProfileSetup."Profile Type"::User, UserId, ProfileId, 0) then begin
            Log.AppendLine(StrSubstNo(this.ProfileExistsMsg, ProfileId, UserId));
            exit;
        end;
        ProfileSetup.Init();
        ProfileSetup.Validate("Profile Type", ProfileSetup."Profile Type"::User);
        ProfileSetup.Validate(ID, UserId);
        ProfileSetup.Validate(Profile, ProfileId);
        ProfileSetup.Insert(false);
        Log.AppendLine(StrSubstNo(this.ProfileAddedMsg, ProfileId, UserId));
    end;

    local procedure AllowHttp(Log: TextBuilder)
    var
        EnvironmentInformation: Codeunit "Environment Information";
        PlatformSpecific: Codeunit "MobileNAV Platform Specific";
    begin
        if not EnvironmentInformation.IsSaaS() then begin
            Log.AppendLine(this.HttpNotSaaSMsg);
            exit;
        end;
        if this.IsHttpAllowed() then begin
            Log.AppendLine(this.HttpAlreadyAllowedMsg);
            exit;
        end;
        PlatformSpecific.EnableAllowHttpClientRequests();
        Log.AppendLine(this.HttpAllowedMsg);
    end;

    local procedure InitialiseMobileNAV(Log: TextBuilder)
    var
        AssistedSetup: Codeunit "MobileNAV Assisted Setup";
        Initialization: Codeunit "MobileNAV Initialization";
        PlatformSpecific: Codeunit "MobileNAV Platform Specific";
        HadLicence: Boolean;
        HadConfig: Boolean;
    begin
        HadLicence := AssistedSetup.HasLicense();
        HadConfig := AssistedSetup.HasConfig();
        if HadLicence and HadConfig then begin
            Log.AppendLine(this.InitSkippedMsg);
            exit;
        end;

        if not GuiAllowed() and PlatformSpecific.IsUserDelegatedAdmin() then begin
            this.InitialiseForDelegatedAdmin(HadLicence, HadConfig, Log);
            exit;
        end;

        // InitializeMobileNAV starts the trial only when no licence exists, runs the add-on upgrade
        // and imports the base configuration only when none exists, then commits.
        Initialization.InitializeMobileNAV();
        this.LogInitialised(HadLicence, HadConfig, Log);
    end;

    local procedure LogInitialised(HadLicence: Boolean; HadConfig: Boolean; Log: TextBuilder)
    var
        AssistedSetup: Codeunit "MobileNAV Assisted Setup";
    begin
        if HadLicence then
            Log.AppendLine(this.LicenceKeptMsg)
        else
            if AssistedSetup.HasLicense() then
                Log.AppendLine(this.TrialStartedMsg);
        if HadConfig then
            Log.AppendLine(this.ConfigKeptMsg)
        else
            if AssistedSetup.HasConfig() then
                Log.AppendLine(this.ConfigImportedMsg)
            else
                Log.AppendLine(this.ConfigMissingMsg);
    end;

    /// <summary>
    /// The first two steps of InitializeMobileNAV, without the configuration import. MobileNAV asks a
    /// delegated administrator to confirm the import (InitializeImport calls CheckUserDelegatedAdmin),
    /// and a web service call cannot answer the dialog, so the import waits for a licensed user.
    /// </summary>
    /// <param name="HadLicence">A licence existed before the setup ran.</param>
    /// <param name="HadConfig">A configuration existed before the setup ran.</param>
    /// <param name="Log">Receives what the step did.</param>
    local procedure InitialiseForDelegatedAdmin(HadLicence: Boolean; HadConfig: Boolean; Log: TextBuilder)
    var
        PlatformSpecific: Codeunit "MobileNAV Platform Specific";
        UpgradeUtils: Codeunit "MobileNAV Upgrade Utils";
    begin
        if HadLicence then
            Log.AppendLine(this.LicenceKeptMsg)
        else begin
            PlatformSpecific.StartTrialPeriod();
            Log.AppendLine(this.TrialStartedMsg);
        end;
        UpgradeUtils.SetHideMessageDialog(true);
        UpgradeUtils.CheckAddOnUpgrade();
        if HadConfig then
            Log.AppendLine(this.ConfigKeptMsg)
        else
            Log.AppendLine(this.ConfigDelegatedMsg);
    end;

    local procedure SetLoginValues(TempInput: Record "BJF MN Setup" temporary; Log: TextBuilder)
    var
        MasterData: Record "MobileNAV Master Data";
        Changes: Integer;
    begin
        if not this.HasLoginValues(TempInput) then begin
            Log.AppendLine(this.NoLoginValuesMsg);
            exit;
        end;

        if not MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then begin
            MasterData.Init();
            MasterData.Validate(Type, MasterData.Type::General);
            MasterData.Insert(true);
        end;
        Changes := this.ApplyTenantId(MasterData, TempInput."O365 Tenant Id") +
                   this.ApplyAppId(MasterData, TempInput."O365 App Id") +
                   this.ApplyRedirectUri(MasterData, TempInput."O365 Redirect Uri") +
                   this.ApplyAppIdUri(MasterData, TempInput."O365 App Id Uri") +
                   this.ApplyAuthenticationType(MasterData);
        if Changes = 0 then begin
            Log.AppendLine(this.LoginUnchangedMsg);
            exit;
        end;
        MasterData.Modify(true);
        Log.AppendLine(this.LoginSetMsg);
    end;

    local procedure HasLoginValues(TempInput: Record "BJF MN Setup" temporary): Boolean
    begin
        exit((TempInput."O365 Tenant Id" <> '') or (TempInput."O365 App Id" <> '') or
             (TempInput."O365 Redirect Uri" <> '') or (TempInput."O365 App Id Uri" <> ''));
    end;

    local procedure ApplyTenantId(var MasterData: Record "MobileNAV Master Data"; Value: Text): Integer
    begin
        if (Value = '') or (MasterData."O365 Tenant ID" = Value) then
            exit(0);
        MasterData.Validate("O365 Tenant ID", CopyStr(Value, 1, MaxStrLen(MasterData."O365 Tenant ID")));
        exit(1);
    end;

    local procedure ApplyAppId(var MasterData: Record "MobileNAV Master Data"; Value: Text): Integer
    begin
        if (Value = '') or (MasterData."O365 App ID" = Value) then
            exit(0);
        MasterData.Validate("O365 App ID", CopyStr(Value, 1, MaxStrLen(MasterData."O365 App ID")));
        exit(1);
    end;

    local procedure ApplyRedirectUri(var MasterData: Record "MobileNAV Master Data"; Value: Text): Integer
    begin
        if (Value = '') or (MasterData."O365 Redirect URI" = Value) then
            exit(0);
        MasterData.Validate("O365 Redirect URI", CopyStr(Value, 1, MaxStrLen(MasterData."O365 Redirect URI")));
        exit(1);
    end;

    local procedure ApplyAppIdUri(var MasterData: Record "MobileNAV Master Data"; Value: Text): Integer
    begin
        if (Value = '') or (MasterData."O365 App ID URI" = Value) then
            exit(0);
        MasterData.Validate("O365 App ID URI", CopyStr(Value, 1, MaxStrLen(MasterData."O365 App ID URI")));
        exit(1);
    end;

    local procedure ApplyAuthenticationType(var MasterData: Record "MobileNAV Master Data"): Integer
    begin
        if MasterData."Authentication Type" = MasterData."Authentication Type"::O365 then
            exit(0);
        MasterData.Validate("Authentication Type", MasterData."Authentication Type"::O365);
        exit(1);
    end;

    local procedure CompleteAssistedSetup(Log: TextBuilder)
    var
        AssistedSetup: Codeunit "MobileNAV Assisted Setup";
        GuidedExperience: Codeunit "Guided Experience";
    begin
        // The wizard's Finish step needs a licence and a configuration.
        if not (AssistedSetup.HasLicense() and AssistedSetup.HasConfig()) then begin
            Log.AppendLine(this.CompleteSkippedMsg);
            exit;
        end;
        if GuidedExperience.IsAssistedSetupComplete(ObjectType::Page, Page::"MobileNAV Setup Wizard") then begin
            Log.AppendLine(this.AlreadyCompleteMsg);
            exit;
        end;
        if AssistedSetup.ExistsAndIsNotComplete() then begin
            AssistedSetup.Complete();
            Log.AppendLine(this.CompletedMsg);
        end else
            Log.AppendLine(this.NotRegisteredMsg);
    end;

    local procedure IsHttpAllowed(): Boolean
    var
        NavAppSetting: Record "NAV App Setting";
        MobileNAVAppId: Guid;
    begin
        Evaluate(MobileNAVAppId, this.MobileNAVAppIdTok);
        NavAppSetting.SetLoadFields("Allow HttpClient Requests");
        if not NavAppSetting.Get(MobileNAVAppId) then
            exit(false);
        exit(NavAppSetting."Allow HttpClient Requests");
    end;

    var
        DefaultProfileTok: Label 'SALES ONLINE', Locked = true;
        OnlineSuffixTok: Label ' ONLINE', Locked = true;
        OfflineSuffixTok: Label ' OFFLINE', Locked = true;
        MobileNAVAppIdTok: Label 'fd09b53c-ff32-4d9c-91ce-6a82a87b8c9c', Locked = true;
        NoUserNameErr: Label 'userName is required.';
        UserNotFoundErr: Label 'No Business Central user has the user name %1.', Comment = '%1 = user name';
        ProfileNotFoundErr: Label 'MobileNAV has no profile %1. Import the MobileNAV configuration first.', Comment = '%1 = profile id';
        HttpNotSaaSMsg: Label 'HttpClient: skipped, not a SaaS environment.';
        HttpAlreadyAllowedMsg: Label 'HttpClient: already allowed for MobileNAV.';
        HttpAllowedMsg: Label 'HttpClient: allowed for MobileNAV.';
        InitSkippedMsg: Label 'Initialise: skipped, a licence and a configuration exist.';
        LicenceKeptMsg: Label 'Licence: kept the installed licence.';
        TrialStartedMsg: Label 'Licence: started the 30 day trial.';
        ConfigKeptMsg: Label 'Configuration: kept the imported configuration.';
        ConfigImportedMsg: Label 'Configuration: imported the base configuration.';
        ConfigDelegatedMsg: Label 'Configuration: not imported. MobileNAV asks a delegated administrator to confirm the import, which an API call cannot answer. Run setup again as a licensed user of the tenant or as a Microsoft Entra application.';
        ConfigMissingMsg: Label 'Configuration: still missing after initialise.';
        NoLoginValuesMsg: Label 'Login: skipped, no login values given.';
        LoginSetMsg: Label 'Login: set the O365 values and Authentication Type O365.';
        LoginUnchangedMsg: Label 'Login: already set.';
        CompleteSkippedMsg: Label 'Assisted setup: skipped, a licence and a configuration are needed first.';
        AlreadyCompleteMsg: Label 'Assisted setup: already complete.';
        CompletedMsg: Label 'Assisted setup: marked complete.';
        NotRegisteredMsg: Label 'Assisted setup: the MobileNAV Setup Wizard is not registered in this company.';
        UserSetupExistsMsg: Label 'User setup: %1 already exists, kept.', Comment = '%1 = user id';
        UserSetupAddedMsg: Label 'User setup: added %1 and assigned the MOBILENAVUSER role.', Comment = '%1 = user id';
        ProfileExistsMsg: Label 'Profile: %1 already assigned to %2, kept.', Comment = '%1 = profile id, %2 = user id';
        ProfileAddedMsg: Label 'Profile: assigned %1 to %2.', Comment = '%1 = profile id, %2 = user id';
        ConfigGeneratedMsg: Label 'User configuration: generated for %1 in language %2.', Comment = '%1 = user id, %2 = language code';
}

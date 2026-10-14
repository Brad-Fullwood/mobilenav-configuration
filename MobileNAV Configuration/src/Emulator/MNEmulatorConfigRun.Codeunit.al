namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Builds one user's MobileNAV configuration for the device emulator and keeps copies of its rows
/// for the caller. A chosen profile can replace the user's profile rows first, so any profile can
/// be emulated. OnRun ends with an error, so the database rolls back everything the build wrote,
/// including the license row it marks and the profile rows it replaces. The build also marks the
/// user's login as finished and clears a later logout date, so a device's unfinished login does not
/// block it. The copies are temporary and survive the rollback. Nothing the emulator does persists,
/// so a real device of that user keeps its own Query ID. Run it with Codeunit.Run from
/// "BJF MN Emulator Config".
/// </summary>
codeunit 77722 "BJF MN Emulator Config Run"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV D. L. Act. L. Buff." = r,
        tabledata "MobileNAV D. L. Action Buff." = r,
        tabledata "MobileNAV D. L. Cond. Buff." = r,
        tabledata "MobileNAV Dynamic Layout Buff." = r,
        tabledata "MobileNAV License Setup" = rm,
        tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Profile Setup" = id,
        tabledata "MobileNAV Sett. Buff. Main" = r,
        tabledata "MobileNAV Settings Buffer" = r;

    trigger OnRun()
    begin
        this.BuildConfiguration();
    end;

    /// <summary>Sets the user and the caption language the build runs for.</summary>
    /// <param name="NewUserId">The Business Central user whose configuration is built.</param>
    /// <param name="NewLanguageCode">MobileNAV language code for the captions, for example ENU.</param>
    procedure SetUser(NewUserId: Code[50]; NewLanguageCode: Code[10])
    begin
        this.UserToBuild := NewUserId;
        this.LanguageCode := NewLanguageCode;
    end;

    /// <summary>Sets the profile to emulate. The build replaces the user's profile rows with this one.</summary>
    /// <param name="NewProfileCode">The MobileNAV profile code, or '' to keep the user's own profile rows.</param>
    procedure SetProfile(NewProfileCode: Code[30])
    begin
        this.ProfileToBuild := NewProfileCode;
    end;

    /// <summary>The error text that ends a build which ran to the end.</summary>
    /// <returns>The marker text.</returns>
    procedure CompletedMarker(): Text
    begin
        exit(this.CompletedTok);
    end;

    /// <summary>
    /// Copies the rows of the last build into the caller's records. Each target is emptied first.
    /// </summary>
    /// <param name="TargetRow">Receives the settings buffer rows, every Line Type.</param>
    /// <param name="TargetExtra">Receives the Sett. Buff. Main rows.</param>
    /// <param name="TargetLayout">Receives the dynamic layout rows.</param>
    /// <param name="TargetCondition">Receives the layout condition rows.</param>
    /// <param name="TargetAction">Receives the layout action rows.</param>
    /// <param name="TargetActionLine">Receives the layout action line rows.</param>
    procedure GetRows(var TargetRow: Record "MobileNAV Settings Buffer" temporary; var TargetExtra: Record "MobileNAV Sett. Buff. Main" temporary; var TargetLayout: Record "MobileNAV Dynamic Layout Buff." temporary; var TargetCondition: Record "MobileNAV D. L. Cond. Buff." temporary; var TargetAction: Record "MobileNAV D. L. Action Buff." temporary; var TargetActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary)
    begin
        this.GetSettingsRows(TargetRow);
        this.GetMainExtraRows(TargetExtra);
        this.GetLayoutRows(TargetLayout);
        this.GetConditionRows(TargetCondition);
        this.GetActionRows(TargetAction);
        this.GetActionLineRows(TargetActionLine);
    end;

    /// <summary>Copies the settings buffer rows of the last build into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="TargetRow">Receives the rows.</param>
    local procedure GetSettingsRows(var TargetRow: Record "MobileNAV Settings Buffer" temporary)
    begin
        TargetRow.Reset();
        TargetRow.DeleteAll(false);
        if this.TempRow.FindSet() then
            repeat
                TargetRow := this.TempRow;
                TargetRow.Insert(false);
            until this.TempRow.Next() = 0;
    end;

    /// <summary>Copies the Sett. Buff. Main rows of the last build into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="TargetExtra">Receives the rows.</param>
    local procedure GetMainExtraRows(var TargetExtra: Record "MobileNAV Sett. Buff. Main" temporary)
    begin
        TargetExtra.Reset();
        TargetExtra.DeleteAll(false);
        if this.TempMainExtra.FindSet() then
            repeat
                TargetExtra := this.TempMainExtra;
                TargetExtra.Insert(false);
            until this.TempMainExtra.Next() = 0;
    end;

    /// <summary>Copies the dynamic layout rows of the last build into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="TargetLayout">Receives the rows.</param>
    local procedure GetLayoutRows(var TargetLayout: Record "MobileNAV Dynamic Layout Buff." temporary)
    begin
        TargetLayout.Reset();
        TargetLayout.DeleteAll(false);
        if this.TempLayout.FindSet() then
            repeat
                TargetLayout := this.TempLayout;
                TargetLayout.Insert(false);
            until this.TempLayout.Next() = 0;
    end;

    /// <summary>Copies the layout condition rows of the last build into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="TargetCondition">Receives the rows.</param>
    local procedure GetConditionRows(var TargetCondition: Record "MobileNAV D. L. Cond. Buff." temporary)
    begin
        TargetCondition.Reset();
        TargetCondition.DeleteAll(false);
        if this.TempCondition.FindSet() then
            repeat
                TargetCondition := this.TempCondition;
                TargetCondition.Insert(false);
            until this.TempCondition.Next() = 0;
    end;

    /// <summary>Copies the layout action rows of the last build into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="TargetAction">Receives the rows.</param>
    local procedure GetActionRows(var TargetAction: Record "MobileNAV D. L. Action Buff." temporary)
    begin
        TargetAction.Reset();
        TargetAction.DeleteAll(false);
        if this.TempAction.FindSet() then
            repeat
                TargetAction := this.TempAction;
                TargetAction.Insert(false);
            until this.TempAction.Next() = 0;
    end;

    /// <summary>Copies the layout action line rows of the last build into the caller's record. The caller's record is emptied first.</summary>
    /// <param name="TargetActionLine">Receives the rows.</param>
    local procedure GetActionLineRows(var TargetActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary)
    begin
        TargetActionLine.Reset();
        TargetActionLine.DeleteAll(false);
        if this.TempActionLine.FindSet() then
            repeat
                TargetActionLine := this.TempActionLine;
                TargetActionLine.Insert(false);
            until this.TempActionLine.Next() = 0;
    end;

    /// <summary>
    /// Rebuilds the user's configuration through MobileNAV's core functions and copies the build's
    /// rows into the temporary copies. Ends with an error to roll back.
    /// </summary>
    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure BuildConfiguration()
    var
        MNLicSetup: Record "MobileNAV License Setup";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
        QueryId: Integer;
    begin
        if this.ProfileToBuild <> '' then
            this.ReplaceUserProfile();
        if MNLicSetup.Get(CompanyName(), MNLicSetup.Type::User, this.UserToBuild) then begin
            MNLicSetup.Validate("Configuration Changed", true);
            // The rollback undoes these. A device's unfinished login must not block the build.
#pragma warning disable PC0037
            MNLicSetup."Last Login Finished" := MNLicSetup."Last Login Date";
            if MNLicSetup."Last Logout Date" > MNLicSetup."Last Login Date" then
                MNLicSetup."Last Logout Date" := 0DT;
#pragma warning restore PC0037
            MNLicSetup.Modify(false);
        end;
        QueryId := CoreFunctions.DoConfigurationChecking(this.UserToBuild, this.LanguageCode, 0);

        this.CopySettingsRows(QueryId);
        this.CopyMainExtraRows(QueryId);
        this.CopyLayoutRows(QueryId);
        this.CopyConditionRows(QueryId);
        this.CopyActionRows(QueryId);
        this.CopyActionLineRows(QueryId);

        Error(this.CompletedTok);
    end;

    /// <summary>
    /// Replaces the user's user-level profile rows with one row for the profile to build. The rows
    /// are the ones MobileNAV's profile wizard writes. The rollback at the end of the build undoes them.
    /// </summary>
    local procedure ReplaceUserProfile()
    var
        MasterData: Record "MobileNAV Master Data";
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        MasterData.SetRange(MasterData.Type, MasterData.Type::Profile);
        MasterData.SetRange("Code", this.ProfileToBuild);
        if MasterData.IsEmpty() then
            Error(this.UnknownProfileErr, this.ProfileToBuild);
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        ProfileSetup.SetRange(ID, this.UserToBuild);
        ProfileSetup.DeleteAll(false);

        ProfileSetup.Reset();
        ProfileSetup.Init();
        ProfileSetup.Validate("Profile Type", ProfileSetup."Profile Type"::User);
        ProfileSetup.Validate(ID, this.UserToBuild);
        ProfileSetup.Validate("Profile", this.ProfileToBuild);
        ProfileSetup.Insert(false);
    end;

    /// <summary>Copies the settings buffer rows of the build, every Line Type, into the temporary copy.</summary>
    /// <param name="QueryId">The Query ID that the build left.</param>
    local procedure CopySettingsRows(QueryId: Integer)
    var
        SettingsBuffer: Record "MobileNAV Settings Buffer";
    begin
        this.TempRow.Reset();
        this.TempRow.DeleteAll(false);
        SettingsBuffer.SetRange("User ID", this.UserToBuild);
        SettingsBuffer.SetRange("Query ID", QueryId);
        if SettingsBuffer.FindSet() then
            repeat
                this.TempRow := SettingsBuffer;
                this.TempRow.Insert(false);
            until SettingsBuffer.Next() = 0;
    end;

    /// <summary>Copies the Sett. Buff. Main rows of the build into the temporary copy.</summary>
    /// <param name="QueryId">The Query ID that the build left.</param>
    local procedure CopyMainExtraRows(QueryId: Integer)
    var
        MainExtra: Record "MobileNAV Sett. Buff. Main";
    begin
        this.TempMainExtra.Reset();
        this.TempMainExtra.DeleteAll(false);
        MainExtra.SetRange("User ID", this.UserToBuild);
        MainExtra.SetRange("Query ID", QueryId);
        if MainExtra.FindSet() then
            repeat
                this.TempMainExtra := MainExtra;
                this.TempMainExtra.Insert(false);
            until MainExtra.Next() = 0;
    end;

    /// <summary>Copies the dynamic layout rows of the build into the temporary copy.</summary>
    /// <param name="QueryId">The Query ID that the build left.</param>
    local procedure CopyLayoutRows(QueryId: Integer)
    var
        Layout: Record "MobileNAV Dynamic Layout Buff.";
    begin
        this.TempLayout.Reset();
        this.TempLayout.DeleteAll(false);
        Layout.SetRange("User ID", this.UserToBuild);
        Layout.SetRange("Query ID", QueryId);
        if Layout.FindSet() then
            repeat
                this.TempLayout := Layout;
                this.TempLayout.Insert(false);
            until Layout.Next() = 0;
    end;

    /// <summary>Copies the layout condition rows of the build into the temporary copy.</summary>
    /// <param name="QueryId">The Query ID that the build left.</param>
    local procedure CopyConditionRows(QueryId: Integer)
    var
        Condition: Record "MobileNAV D. L. Cond. Buff.";
    begin
        this.TempCondition.Reset();
        this.TempCondition.DeleteAll(false);
        Condition.SetRange("User ID", this.UserToBuild);
        Condition.SetRange("Query ID", QueryId);
        if Condition.FindSet() then
            repeat
                this.TempCondition := Condition;
                this.TempCondition.Insert(false);
            until Condition.Next() = 0;
    end;

    /// <summary>Copies the layout action rows of the build into the temporary copy.</summary>
    /// <param name="QueryId">The Query ID that the build left.</param>
    local procedure CopyActionRows(QueryId: Integer)
    var
        LayoutAction: Record "MobileNAV D. L. Action Buff.";
    begin
        this.TempAction.Reset();
        this.TempAction.DeleteAll(false);
        LayoutAction.SetRange("User ID", this.UserToBuild);
        LayoutAction.SetRange("Query ID", QueryId);
        if LayoutAction.FindSet() then
            repeat
                this.TempAction := LayoutAction;
                this.TempAction.Insert(false);
            until LayoutAction.Next() = 0;
    end;

    /// <summary>Copies the layout action line rows of the build into the temporary copy.</summary>
    /// <param name="QueryId">The Query ID that the build left.</param>
    local procedure CopyActionLineRows(QueryId: Integer)
    var
        ActionLine: Record "MobileNAV D. L. Act. L. Buff.";
    begin
        this.TempActionLine.Reset();
        this.TempActionLine.DeleteAll(false);
        ActionLine.SetRange("User ID", this.UserToBuild);
        ActionLine.SetRange("Query ID", QueryId);
        if ActionLine.FindSet() then
            repeat
                this.TempActionLine := ActionLine;
                this.TempActionLine.Insert(false);
            until ActionLine.Next() = 0;
    end;

    var
        TempRow: Record "MobileNAV Settings Buffer" temporary;
        TempMainExtra: Record "MobileNAV Sett. Buff. Main" temporary;
        TempLayout: Record "MobileNAV Dynamic Layout Buff." temporary;
        TempCondition: Record "MobileNAV D. L. Cond. Buff." temporary;
        TempAction: Record "MobileNAV D. L. Action Buff." temporary;
        TempActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary;
        UserToBuild: Code[50];
        LanguageCode: Code[10];
        ProfileToBuild: Code[30];
        CompletedTok: Label 'BJF MN emulator build completed. Rolling back.', Locked = true;
        UnknownProfileErr: Label 'The MobileNAV profile %1 does not exist.', Comment = '%1 = the profile code the emulator was asked to use';
}

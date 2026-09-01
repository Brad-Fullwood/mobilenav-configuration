namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Has what the providers declare actually reached the devices? A construction window left
/// open blocks every device logon; an apply that ran without a GUI never handed over to the
/// devices; and a definition that changed since it was applied is not what the devices show.
/// </summary>
codeunit 77798 "BJF Check Config Apply State" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = r,
        tabledata "BJF MN Config Status" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
    begin
        this.CheckConstructionWindow(Finding);
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.CheckProvider(Finding, TempProvider);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    local procedure CheckConstructionWindow(var Finding: Record "BJF Diagnostic Finding")
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then
            exit;
        if MasterData."Under Construction" then
            Finding.Add(Finding."Check Type"::"Config Apply State", Finding.Severity::Blocker, this.UnderConstructionMsg, MasterData.RecordId());
    end;

    local procedure CheckProvider(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary)
    var
        ConfigurationStatus: Record "BJF MN Config Status";
    begin
        if not ConfigurationStatus.Get(TempProvider."Provider ID") then begin
            Finding.Add(Finding."Check Type"::"Config Apply State", Finding.Severity::Info,
                this.Support.Prefix(TempProvider, this.NeverAppliedMsg));
            exit;
        end;
        if ConfigurationStatus."Device Handover Pending" then
            Finding.Add(Finding."Check Type"::"Config Apply State", Finding.Severity::Warning,
                this.Support.Prefix(TempProvider, this.HandoverPendingMsg), ConfigurationStatus.RecordId());
        if ConfigurationStatus."Content Hash" <> TempProvider."Defined Hash" then
            Finding.Add(Finding."Check Type"::"Config Apply State", Finding.Severity::Warning,
                this.Support.Prefix(TempProvider, this.ChangedSinceApplyMsg), ConfigurationStatus.RecordId());
        if ConfigurationStatus."Manually Outdated" then
            Finding.Add(Finding."Check Type"::"Config Apply State", Finding.Severity::Info,
                this.Support.Prefix(TempProvider, this.ManuallyOutdatedMsg), ConfigurationStatus.RecordId());
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        UnderConstructionMsg: Label 'MobileNAV is "Under Construction", which rejects every device logon. Clear it on MobileNAV General Setup once configuration work is finished.';
        NeverAppliedMsg: Label 'This provider has never been applied. Apply it from "Apply custom MobileNAV config".';
        HandoverPendingMsg: Label 'The last apply ran without a user session, so the configuration is in MobileNAV''s tables but has not been handed over to the devices. Apply again from "Apply custom MobileNAV config".';
        ChangedSinceApplyMsg: Label 'The provider''s definition has changed since it was last applied; devices show the earlier configuration. Apply it again.';
        ManuallyOutdatedMsg: Label 'The provider was marked outdated by an administrator and has not been applied since.';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
}

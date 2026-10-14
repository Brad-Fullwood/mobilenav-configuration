namespace BradFullwood.MobileNAV.Configuration;

using System.Environment.Configuration;

/// <summary>
/// Can the device emulator reach the page services? The emulator calls them through HttpClient, which
/// Business Central blocks for an extension until "Allow HttpClient Requests" is on for it. Reads still
/// work without it, so the finding is a warning. Runs only when the emulator setup row exists.
/// </summary>
codeunit 77738 "BJF Check Emulator Http" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "BJF MN Emulator Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        EmulatorSetup: Record "BJF MN Emulator Setup";
        NavAppSetting: Record "NAV App Setting";
        ModuleInfo: ModuleInfo;
    begin
        EmulatorSetup.SetLoadFields("Primary Key");
        if not EmulatorSetup.FindFirst() then
            exit;

        NavApp.GetCurrentModuleInfo(ModuleInfo);
        if NavAppSetting.ReadPermission() then begin
            NavAppSetting.SetLoadFields("Allow HttpClient Requests");
            if NavAppSetting.Get(ModuleInfo.Id()) and NavAppSetting."Allow HttpClient Requests" then
                exit;
        end;

        // Without read permission the setting cannot be seen, so it is reported as not allowed.
        Finding.AddWithFix(Finding."Check Type"::"Emulator HttpClient", Finding.Severity::Warning,
            this.HttpClientBlockedMsg, EmulatorSetup.RecordId(), this.AllowHttpClientFixLbl);
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        NavAppSetting: Record "NAV App Setting";
        ModuleInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(ModuleInfo);
        if not NavAppSetting.WritePermission() then
            Error(this.AdministratorTurnsOnErr);

        if NavAppSetting.Get(ModuleInfo.Id()) then begin
            NavAppSetting.Validate("Allow HttpClient Requests", true);
            NavAppSetting.Modify(false);
        end else begin
            NavAppSetting.Init();
            NavAppSetting.Validate("App ID", ModuleInfo.Id());
            NavAppSetting.Validate("Allow HttpClient Requests", true);
            NavAppSetting.Insert(false);
        end;
    end;

    var
        HttpClientBlockedMsg: Label 'The device emulator cannot call the page services, because HttpClient requests are not allowed for the MobileNAV Configuration extension. Reads still work. Buttons, edits, scans and live values do not.';
        AllowHttpClientFixLbl: Label 'Allow HttpClient requests for this extension.';
        AdministratorTurnsOnErr: Label 'This user cannot change the HttpClient setting of this extension. An administrator turns on Allow HttpClient Requests for this extension from the Extension Management page (Configure).';
}

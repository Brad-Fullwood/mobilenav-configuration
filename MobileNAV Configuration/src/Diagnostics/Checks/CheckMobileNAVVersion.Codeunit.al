namespace BradFullwood.MobileNAV.Configuration;

using System.Apps;

/// <summary>
/// Is the installed MobileNAV at least the build the generated Page Functions catalog came from?
/// An older build may lack procedures the catalog lists. A newer build gives no finding.
/// </summary>
codeunit 77717 "BJF Check MobileNAV Version" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "NAV App Installed App" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        InstalledVersion: Version;
        VerifiedVersion: Version;
        VerifiedText: Text;
    begin
        if not this.TryInstalledVersion(InstalledVersion) then
            exit;
        VerifiedText := this.VerifiedVersionText();
        VerifiedVersion := Version.Create(VerifiedText);
        // A newer MobileNAV gives no finding. Only an older one can lack procedures the catalog needs.
        if InstalledVersion < VerifiedVersion then
            Finding.Add(
                Enum::"BJF Diagnostic Check Type"::"MobileNAV Version", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(this.OlderMsg, Format(InstalledVersion), VerifiedText));
    end;

    /// <summary>The installed MobileNAV version, for the Doctor page.</summary>
    /// <returns>The version, or a note when MobileNAV is not installed.</returns>
    procedure InstalledVersionText(): Text
    var
        InstalledVersion: Version;
    begin
        if not this.TryInstalledVersion(InstalledVersion) then
            exit(this.NotInstalledTxt);
        exit(Format(InstalledVersion));
    end;

    /// <summary>The MobileNAV version the framework was verified against, for the Doctor page.</summary>
    /// <returns>The version text from the Page Functions catalog.</returns>
    procedure VerifiedVersionText(): Text
    begin
        exit(this.Catalog.VerifiedMobileNAVVersion());
    end;

    local procedure TryInstalledVersion(var InstalledVersion: Version): Boolean
    var
        InstalledApp: Record "NAV App Installed App";
    begin
        InstalledApp.SetLoadFields("Version Major", "Version Minor", "Version Build", "Version Revision");
        InstalledApp.SetRange(Publisher, this.PublisherTxt);
        InstalledApp.SetRange(Name, this.AppNameTxt);
        if not InstalledApp.FindFirst() then
            exit(false);
        InstalledVersion := Version.Create(InstalledApp."Version Major", InstalledApp."Version Minor", InstalledApp."Version Build", InstalledApp."Version Revision");
        exit(true);
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    var
        Catalog: Codeunit "BJF MN Page Function Catalog";
        PublisherTxt: Label 'MULTISOFT KFT', Locked = true;
        AppNameTxt: Label 'MobileNAV', Locked = true;
        NotInstalledTxt: Label 'Not installed';
        OlderMsg: Label 'MobileNAV %1 is installed, but this app was built for MobileNAV %2. Some functions it uses may be missing from the installed MobileNAV. Install MobileNAV %2 or later, then run the Doctor again.', Comment = '%1 = installed version, %2 = verified version';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
}

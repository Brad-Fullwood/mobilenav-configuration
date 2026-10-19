namespace BradFullwood.MobileNAV.Configuration.WMS;

/// <summary>
/// Reads WMS MobileNAV's licence check state and asks for a new check. WMS MobileNAV has no
/// licence key: it asks Multisoft's licence server with the Microsoft Entra tenant id and keeps the
/// result in "MUL WMS License Information". After a failed check, sessions without a client (device
/// sessions) reuse the stored failure, and only a session with a client asks the server again and
/// clears the failure when the licence is valid. Nothing here writes that table, so a stored failure
/// is only cleared by the licence server's answer.
/// </summary>
codeunit 77757 "BJF MN WMS Licence"
{
    Access = Internal;
    Permissions = tabledata "MUL WMS License Information" = r;

    /// <summary>
    /// Runs WMS MobileNAV's licence check. Called from the web client it asks the licence server
    /// and clears a stored failure when the licence is valid. It shows WMS MobileNAV's own message
    /// when the check fails or the grace period is running.
    /// </summary>
    procedure RecheckLicence()
    var
        LicenseFunctions: Codeunit "MUL WMS License Functions";
    begin
        LicenseFunctions.CheckLicense(0);
    end;

    /// <summary>Reads the stored state of the WMS licence check.</summary>
    /// <param name="LicenseInformation">Returns the row for licence type WMS.</param>
    /// <returns>False when WMS MobileNAV has not checked its licence yet.</returns>
    procedure GetState(var LicenseInformation: Record "MUL WMS License Information"): Boolean
    begin
        exit(LicenseInformation.Get(LicenseInformation."License Type"::WMS));
    end;
}

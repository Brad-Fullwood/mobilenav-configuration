namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Reports a stored failure of WMS MobileNAV's licence check. Device sessions reuse the stored
/// failure until a check from the web client succeeds, so devices keep failing after the cause is
/// gone. There is no automatic fix: clearing the failure without the licence server's answer
/// would bypass the licence.
/// </summary>
codeunit 77759 "BJF Check WMS Licence" implements "BJF Diagnostic Check"
{
    Access = Internal;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        LicenseInformation: Record "MUL WMS License Information";
        WMSLicence: Codeunit "BJF MN WMS Licence";
    begin
        if not WMSLicence.GetState(LicenseInformation) then
            exit;
        if LicenseInformation."First Failed License Check" = 0DT then
            exit;
        Finding.Add(Enum::"BJF Diagnostic Check Type"::"WMS Licence", Enum::"BJF Diagnostic Severity"::Blocker,
            StrSubstNo(this.StoredFailureMsg, LicenseInformation."First Failed License Check", LicenseInformation."First Failed License Message"),
            LicenseInformation.RecordId());
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    var
        NoAutomaticFixErr: Label 'This finding has no automatic fix. Open the WMS MobileNAV Licence page and choose Recheck WMS licence.';
        StoredFailureMsg: Label 'The WMS MobileNAV licence check failed on %1 with the message "%2". Device sessions reuse this stored failure and do not ask the licence server again. Open the WMS MobileNAV Licence page and choose Recheck WMS licence: a check from the web client asks the licence server and clears the failure when the licence is valid.', Comment = '%1 = date and time of the first failed check, %2 = stored failure message';
}

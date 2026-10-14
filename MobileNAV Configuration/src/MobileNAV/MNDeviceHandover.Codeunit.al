namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Runs MobileNAV's device handover on its own, so a session without a client (the API) can
/// catch a refusal through Codeunit.Run instead of losing the whole apply.
/// </summary>
codeunit 77706 "BJF MN Device Handover"
{
    Access = Internal;

    trigger OnRun()
    var
        PageManagement: Codeunit "BJF MN Page Mgt.";
    begin
        PageManagement.HandOverToDevices();
    end;
}

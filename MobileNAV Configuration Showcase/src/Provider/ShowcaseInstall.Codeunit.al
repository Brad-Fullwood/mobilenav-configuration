namespace BradFullwood.MobileNAV.Showcase;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Applies the provider on install. Install has no client to answer MobileNAV's dialogs, so
/// the configuration is written but the handover to devices waits for an administrator to
/// apply once more from the MobileNAV Configuration page.
/// </summary>
codeunit 50103 "Showcase Install"
{
    Access = Internal;
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        ConfigurationApplication: Codeunit "BJF MN Config Application";
    begin
        ConfigurationApplication.ApplyProvider(Enum::"BJF MN Config Provider"::Showcase);
    end;
}

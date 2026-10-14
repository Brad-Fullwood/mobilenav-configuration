namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Applies the provider on install. Install has no client to answer MobileNAV's dialogs, so
/// the configuration is written but the handover to devices waits for an administrator to
/// apply once more from the MobileNAV Configuration page. When MobileNAV has not been set up in
/// the company yet, nothing is applied: the provider stays Not Applied on that page until the
/// administrator runs MobileNAV's Setup Wizard and applies it.
/// </summary>
codeunit 50103 "Example Install"
{
    Access = Internal;
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        ConfigurationApplication: Codeunit "BJF MN Config Application";
    begin
        if not ConfigurationApplication.MobileNAVIsConfigured() then
            exit;
        ConfigurationApplication.ApplyProvider(Enum::"BJF MN Config Provider"::Example);
    end;
}

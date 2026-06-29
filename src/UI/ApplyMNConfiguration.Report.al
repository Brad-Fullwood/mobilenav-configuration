namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Applies every MobileNAV setup module registered by installed dependent extensions.
/// </summary>
report 77780 "BJF Apply MN Configuration"
{
    ApplicationArea = All;
    Caption = 'Apply MobileNAV Configuration';
    ProcessingOnly = true;
    UsageCategory = Administration;
    UseRequestPage = false;

    trigger OnPreReport()
    var
        SetupRunner: Codeunit "BJF MobileNAV Setup Runner";
    begin
        SetupRunner.ApplyAll();
        Message(ConfigurationAppliedMsg);
    end;

    var
        ConfigurationAppliedMsg: Label 'All registered MobileNAV configuration modules were applied.';
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// One place to ask "why is this not on the device?": runs the configuration checks against
/// every registered provider and MobileNAV's live data, the general MobileNAV diagnostics, and
/// any checks satellite apps contribute, and applies the fixes that can be automated.
/// </summary>
page 77781 "BJF MN Doctor"
{
    ApplicationArea = All;
    Caption = 'MobileNAV Doctor';
    PageType = Card;
    UsageCategory = Administration;
    AdditionalSearchTerms = 'MobileNAV,diagnostics,doctor,configuration,profile,device';

    layout
    {
        area(Content)
        {
            part(Findings; "BJF Diagnostic Findings Part")
            {
                Caption = 'Findings';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RunConfigChecks)
            {
                ApplicationArea = All;
                Caption = 'Run config checks';
                Image = TestReport;
                ToolTip = 'Compares every registered provider''s declaration with MobileNAV''s live configuration and reports what would keep a control off a device.';

                trigger OnAction()
                begin
                    this.DiagnosticsRunner.Run(this.ConfigCheckTypes());
                    CurrPage.Findings.Page.Update(false);
                end;
            }
            action(RunAll)
            {
                ApplicationArea = All;
                Caption = 'Run all diagnostics';
                Image = Troubleshoot;
                ToolTip = 'Runs the configuration checks together with the general MobileNAV diagnostics and any checks other extensions contribute.';

                trigger OnAction()
                begin
                    this.DiagnosticsRunner.RunAll();
                    CurrPage.Findings.Page.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(RunConfigChecks_Promoted; RunConfigChecks)
                {
                }
                actionref(RunAll_Promoted; RunAll)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.DiagnosticsRunner.Run(this.ConfigCheckTypes());
    end;

    local procedure ConfigCheckTypes() CheckTypes: List of [Enum "BJF Diagnostic Check Type"]
    begin
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Services");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Fields");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Profiles");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Page Rules");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Apply State");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Properties");
    end;

    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
}

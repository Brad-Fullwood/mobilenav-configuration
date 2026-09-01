namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// One place to ask "why is this not on the device?": runs the configuration checks against
/// every registered provider and MobileNAV's live data, the general MobileNAV diagnostics, and
/// any checks satellite apps contribute — and applies the fixes that can be automated.
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
            group(Options)
            {
                Caption = 'Snapshot';
                field(SnapshotProvider; this.SnapshotProvider)
                {
                    Caption = 'Provider';
                    ToolTip = 'Specifies the provider whose live MobileNAV rows "Export live snapshot" dumps.';
                }
            }
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
                    this.DiagnosticsRunner.RunChecks(this.ConfigChecksFilterTok);
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
            action(ExportSnapshot)
            {
                ApplicationArea = All;
                Caption = 'Export live snapshot';
                Image = Export;
                ToolTip = 'Downloads every MobileNAV row the selected provider''s configuration touches, for diffing against another environment or version.';

                trigger OnAction()
                var
                    TempConfigurationLine: Record "BJF MN Config Line" temporary;
                    ProviderCatalog: Codeunit "BJF MN Provider Catalog";
                    ConfigurationSnapshot: Codeunit "BJF MN Config Snapshot";
                    ProviderId: Code[50];
                    ProviderName: Text[100];
                    ProviderDescription: Text[250];
                begin
                    ProviderCatalog.GetMetadata(this.SnapshotProvider, ProviderId, ProviderName, ProviderDescription);
                    ProviderCatalog.BuildDefinition(this.SnapshotProvider, TempConfigurationLine);
                    ConfigurationSnapshot.Download(StrSubstNo(this.SnapshotFileNameTok, ProviderId), TempConfigurationLine);
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
                actionref(ExportSnapshot_Promoted; ExportSnapshot)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.DiagnosticsRunner.RunChecks(this.ConfigChecksFilterTok);
    end;

    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
        SnapshotProvider: Enum "BJF MN Config Provider";
        ConfigChecksFilterTok: Label '200..204', Locked = true;
        SnapshotFileNameTok: Label '%1-mobilenav-snapshot.txt', Locked = true;
}

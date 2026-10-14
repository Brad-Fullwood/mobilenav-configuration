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
    Permissions = tabledata "BJF Doctor Check" = r,
                  tabledata "BJF Doctor Run Log" = r;
    AdditionalSearchTerms = 'MobileNAV,diagnostics,doctor,configuration,profile,device';

    layout
    {
        area(Content)
        {
            group(Status)
            {
                Caption = 'Status';

                field(ScheduleText; this.ScheduleText)
                {
                    Caption = 'Schedule';
                    Editable = false;
                    ToolTip = 'Specifies whether the nightly run is set up in the job queue, and the status of its job queue entry.';
                }
                field(NextScheduledRun; this.NextScheduledRun)
                {
                    Caption = 'Next scheduled run';
                    Editable = false;
                    ToolTip = 'Specifies when the job queue entry runs next.';
                }
                field(LastManualRunAt; this.LastManualRunAt)
                {
                    Caption = 'Last manual run';
                    Editable = false;
                    ToolTip = 'Specifies when a user last ran the Doctor checks from this page. Page opens are not counted.';
                }
                field(LastManualRunBy; this.LastManualRunBy)
                {
                    Caption = 'Last manual run by';
                    Editable = false;
                    ToolTip = 'Specifies the user who ran the Doctor checks last from this page.';
                }
                field(LastScheduledRunAt; this.LastScheduledRunAt)
                {
                    Caption = 'Last scheduled run';
                    Editable = false;
                    ToolTip = 'Specifies when the job queue last ran the Doctor checks.';
                }
                field(IssuesFromLastRun; this.IssuesFromLastRun)
                {
                    Caption = 'Issues from last run';
                    Editable = false;
                    ToolTip = 'Specifies the blockers and warnings from the newest manual or job queue run. Info findings and page opens are not counted.';
                }
                field(ChecksAvailable; this.ChecksAvailable)
                {
                    Caption = 'Checks available';
                    Editable = false;
                    DrillDown = true;
                    ToolTip = 'Specifies how many checks the Doctor can run. Drill down to see each check and what it looks at.';

                    trigger OnDrillDown()
                    begin
                        this.ShowChecks();
                    end;
                }
                field(InstalledVersionText; this.InstalledVersionText)
                {
                    Caption = 'MobileNAV version';
                    Editable = false;
                    ToolTip = 'Specifies the MobileNAV version installed in this environment.';
                }
                field(VerifiedVersionText; this.VerifiedVersionText)
                {
                    Caption = 'Verified against MobileNAV';
                    Editable = false;
                    ToolTip = 'Specifies the MobileNAV version this app was checked against.';
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
                    this.DoctorRunLog.RunChecks(Enum::"BJF Doctor Run Source"::Manual, this.DiagnosticsRunner.ConfigCheckTypes());
                    this.AfterRun();
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
                    this.DoctorRunLog.RunAll(Enum::"BJF Doctor Run Source"::Manual);
                    this.AfterRun();
                end;
            }
            action(RunNow)
            {
                ApplicationArea = All;
                Caption = 'Run';
                Image = Start;
                ToolTip = 'Runs all diagnostics now, as the nightly job does, and sends one telemetry event per finding.';

                trigger OnAction()
                begin
                    this.DoctorJob.RunNow();
                    this.AfterRun();
                end;
            }
            action(Checks)
            {
                Caption = 'Checks';
                Image = List;
                ToolTip = 'Lists every check the Doctor can run, with its area and what it checks.';

                trigger OnAction()
                begin
                    this.ShowChecks();
                end;
            }
            action(ScheduleNightly)
            {
                ApplicationArea = All;
                Caption = 'Schedule';
                Image = Calendar;
                ToolTip = 'Creates or updates a job queue entry that runs all diagnostics every day at 02:00 and sends the findings to telemetry.';

                trigger OnAction()
                begin
                    this.DoctorJob.ScheduleNightly();
                    Message(this.ScheduledMsg);
                    this.RefreshHeader();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(RunNow_Promoted; RunNow)
                {
                }
                actionref(ScheduleNightly_Promoted; ScheduleNightly)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.DoctorRunLog.RunChecks(Enum::"BJF Doctor Run Source"::"Page Open", this.DiagnosticsRunner.ConfigCheckTypes());
        this.RefreshHeader();
    end;

    /// <summary>Refreshes the findings and the header after an action that ran checks or changed the schedule.</summary>
    local procedure AfterRun()
    begin
        CurrPage.Findings.Page.Update(false);
        this.RefreshHeader();
    end;

    /// <summary>Fills the Doctor Check table from the enum, then opens the list of checks. The table is filled first so the list is never empty.</summary>
    local procedure ShowChecks()
    var
        CheckRegistry: Codeunit "BJF MN Doctor Check Registry";
        ChecksPage: Page "BJF MN Doctor Checks";
    begin
        CheckRegistry.Refresh();
        ChecksPage.Run();
    end;

    /// <summary>Reads the schedule, the last runs, the check count and the versions into the header fields.</summary>
    local procedure RefreshHeader()
    var
        DoctorCheck: Record "BJF Doctor Check";
        ManualRun: Record "BJF Doctor Run Log";
        ScheduledRun: Record "BJF Doctor Run Log";
        CheckRegistry: Codeunit "BJF MN Doctor Check Registry";
        VersionCheck: Codeunit "BJF Check MobileNAV Version";
        JobStatus: Text;
    begin
        if this.DoctorJob.ReadSchedule(JobStatus, this.NextScheduledRun) then
            this.ScheduleText := StrSubstNo(this.ScheduledStatusTxt, JobStatus)
        else begin
            this.ScheduleText := this.NotScheduledTxt;
            this.NextScheduledRun := 0DT;
        end;

        // Page open refreshes are left out: they only re-check the configuration.
        ManualRun.SetLoadFields("Entry No.", "Run At", "Run By", Blockers, Warnings);
        ManualRun.SetRange(Source, Enum::"BJF Doctor Run Source"::Manual);
        ScheduledRun.SetLoadFields("Entry No.", "Run At", Blockers, Warnings);
        ScheduledRun.SetRange(Source, Enum::"BJF Doctor Run Source"::"Job Queue");
        this.LastManualRunAt := 0DT;
        this.LastManualRunBy := '';
        this.LastScheduledRunAt := 0DT;
        this.IssuesFromLastRun := 0;

        if ManualRun.FindLast() then begin
            this.LastManualRunAt := ManualRun."Run At";
            this.LastManualRunBy := ManualRun."Run By";
        end;
        if ScheduledRun.FindLast() then
            this.LastScheduledRunAt := ScheduledRun."Run At";

        // The newest of the two manual and job queue rows decides the issue count.
        if ManualRun."Entry No." > ScheduledRun."Entry No." then
            this.IssuesFromLastRun := ManualRun.Blockers + ManualRun.Warnings
        else
            this.IssuesFromLastRun := ScheduledRun.Blockers + ScheduledRun.Warnings;

        CheckRegistry.Refresh();
        this.ChecksAvailable := DoctorCheck.Count();
        this.InstalledVersionText := VersionCheck.InstalledVersionText();
        this.VerifiedVersionText := VersionCheck.VerifiedVersionText();
    end;

    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
        DoctorJob: Codeunit "BJF MN Doctor Job";
        DoctorRunLog: Codeunit "BJF MN Doctor Run Log";
        LastManualRunAt: DateTime;
        LastScheduledRunAt: DateTime;
        NextScheduledRun: DateTime;
        ChecksAvailable: Integer;
        IssuesFromLastRun: Integer;
        InstalledVersionText: Text;
        LastManualRunBy: Text;
        ScheduleText: Text;
        VerifiedVersionText: Text;
        ScheduledMsg: Label 'The nightly run is scheduled for 02:00 every day. See Job Queue Entries.';
        ScheduledStatusTxt: Label 'Set up, job queue status %1', Comment = '%1 = job queue entry status';
        NotScheduledTxt: Label 'Not set up';
}

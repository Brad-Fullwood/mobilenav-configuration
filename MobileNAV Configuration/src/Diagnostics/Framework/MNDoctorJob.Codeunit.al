namespace BradFullwood.MobileNAV.Configuration;

using System.Threading;

/// <summary>
/// Runs every diagnostic check for the company, records the run, and sends the findings to telemetry.
/// Meant for a job queue entry: OnRun runs the checks, then logs one event BJF-MN-0001 per finding and one
/// summary event BJF-MN-0000. Events reach Application Insights when the environment has a connection string.
/// </summary>
codeunit 77716 "BJF MN Doctor Job"
{
    Access = Public;
    Permissions = tabledata "BJF Diagnostic Finding" = r,
                  tabledata "Job Queue Entry" = r;

    trigger OnRun()
    begin
        this.RunDoctor(Enum::"BJF Doctor Run Source"::"Job Queue");
    end;

    /// <summary>Runs every check now, from the Doctor page. The run is logged like a job queue run.</summary>
    procedure RunNow()
    begin
        this.RunDoctor(Enum::"BJF Doctor Run Source"::Manual);
    end;

    local procedure RunDoctor(Source: Enum "BJF Doctor Run Source")
    var
        DoctorRunLog: Codeunit "BJF MN Doctor Run Log";
    begin
        DoctorRunLog.RunAll(Source);
        this.LogFindings();
    end;

    /// <summary>Creates or updates the job queue entry that runs this codeunit every day at 02:00, and enqueues it.</summary>
    procedure ScheduleNightly()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"BJF MN Doctor Job");
        if not JobQueueEntry.FindFirst() then begin
            JobQueueEntry.Init();
            JobQueueEntry.Validate("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
            JobQueueEntry.Validate("Object ID to Run", Codeunit::"BJF MN Doctor Job");
        end;

        JobQueueEntry.Validate(Description, CopyStr(this.JobDescriptionLbl, 1, MaxStrLen(JobQueueEntry.Description)));
        JobQueueEntry.Validate("Recurring Job", true);
        JobQueueEntry.Validate("Run on Mondays", true);
        JobQueueEntry.Validate("Run on Tuesdays", true);
        JobQueueEntry.Validate("Run on Wednesdays", true);
        JobQueueEntry.Validate("Run on Thursdays", true);
        JobQueueEntry.Validate("Run on Fridays", true);
        JobQueueEntry.Validate("Run on Saturdays", true);
        JobQueueEntry.Validate("Run on Sundays", true);
        JobQueueEntry.Validate("Starting Time", 020000T);
        JobQueueEntry.Validate("No. of Minutes between Runs", 0);
        JobQueueEntry.Validate("Earliest Start Date/Time", CreateDateTime(Today(), 020000T));
        Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry);
    end;

    /// <summary>Reads the nightly job queue entry for the Doctor page.</summary>
    /// <param name="StatusText">Receives the entry's status. Blank when the nightly run is not set up.</param>
    /// <param name="NextRun">Receives the entry's earliest start, or 0DT.</param>
    /// <returns>True when the nightly job queue entry exists.</returns>
    procedure ReadSchedule(var StatusText: Text; var NextRun: DateTime): Boolean
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"BJF MN Doctor Job");
        JobQueueEntry.SetLoadFields(Status, "Earliest Start Date/Time");
        if not JobQueueEntry.FindFirst() then begin
            StatusText := '';
            NextRun := 0DT;
            exit(false);
        end;
        StatusText := Format(JobQueueEntry.Status);
        NextRun := JobQueueEntry."Earliest Start Date/Time";
        exit(true);
    end;

    local procedure LogFindings()
    var
        Finding: Record "BJF Diagnostic Finding";
        Dimensions: Dictionary of [Text, Text];
        Total: Integer;
        Blockers: Integer;
        Warnings: Integer;
        Infos: Integer;
        FixableCount: Integer;
    begin
        Finding.SetLoadFields("Check Type", Severity, Message, Fixable);
        Finding.SetRange("User ID", UserId());
        if Finding.FindSet() then
            repeat
                Total += 1;
                case Finding.Severity of
                    Finding.Severity::Blocker:
                        Blockers += 1;
                    Finding.Severity::Warning:
                        Warnings += 1;
                    else
                        Infos += 1;
                end;
                if Finding.Fixable then
                    FixableCount += 1;

                Clear(Dimensions);
                Dimensions.Add('CheckType', Format(Finding."Check Type"));
                Dimensions.Add('Severity', Format(Finding.Severity));
                Dimensions.Add('Fixable', Format(Finding.Fixable, 0, 9));
                Dimensions.Add('Message', Finding.Message);
                Dimensions.Add('Company', CompanyName());
                Session.LogMessage('BJF-MN-0001', this.FindingTelemetryLbl, this.FindingVerbosity(Finding.Severity),
                    DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
            until Finding.Next() = 0;

        Clear(Dimensions);
        Dimensions.Add('Company', CompanyName());
        Dimensions.Add('Findings', Format(Total));
        Dimensions.Add('Blockers', Format(Blockers));
        Dimensions.Add('Warnings', Format(Warnings));
        Dimensions.Add('Infos', Format(Infos));
        Dimensions.Add('Fixable', Format(FixableCount));
        Session.LogMessage('BJF-MN-0000', this.SummaryTelemetryLbl, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    local procedure FindingVerbosity(FindingSeverity: Enum "BJF Diagnostic Severity"): Verbosity
    begin
        if FindingSeverity in [FindingSeverity::Blocker, FindingSeverity::Warning] then
            exit(Verbosity::Warning);
        exit(Verbosity::Normal);
    end;

    var
        FindingTelemetryLbl: Label 'MobileNAV Doctor finding', Locked = true;
        SummaryTelemetryLbl: Label 'MobileNAV Doctor run summary', Locked = true;
        JobDescriptionLbl: Label 'MobileNAV Doctor nightly run';
}

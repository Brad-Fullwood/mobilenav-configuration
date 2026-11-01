namespace BradFullwood.MobileNAV.Configuration;

using System.Threading;

/// <summary>
/// Warns when the MobileNAV BackgroundRefresh job queue entry is not On Hold. An apply refuses to
/// start in that state, so the Doctor says so before the apply is tried. The test and the text come
/// from "BJF MN Background Job Guard", which the apply also calls.
/// </summary>
codeunit 77833 "BJF Check Background Job" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Job Queue Entry" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        if this.Guard.FindNotOnHold(JobQueueEntry) then
            repeat
                Finding.Add(Enum::"BJF Diagnostic Check Type"::"Config Background Job", Enum::"BJF Diagnostic Severity"::Warning,
                    this.Guard.ErrorText(JobQueueEntry), JobQueueEntry.RecordId());
            until JobQueueEntry.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    var
        Guard: Codeunit "BJF MN Background Job Guard";
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
}

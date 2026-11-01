namespace BradFullwood.MobileNAV.Configuration;

using System.Threading;

/// <summary>
/// Finds the MobileNAV BackgroundRefresh job queue entries that are not On Hold. MobileNAV's per-user
/// rebuild refuses to run while that entry is Ready ("Status must be equal to On Hold in Job Queue
/// Entry"). The apply calls CheckOnHold before it changes anything and the Doctor check reports the same text.
/// MobileNAV's own StopBackgroundJQ finds the entry by object type, object id and Recurring Job, so the
/// filter here is the same. No standard Business Central object answers "is this job on hold".
/// </summary>
codeunit 77832 "BJF MN Background Job Guard"
{
    Access = Internal;
    Permissions = tabledata "Job Queue Entry" = r;

    /// <summary>Stops with an error naming the first BackgroundRefresh entry that is not On Hold. Does nothing when there is none.</summary>
    procedure CheckOnHold()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        if this.FindNotOnHold(JobQueueEntry) then
            Error(this.NotOnHoldMsg, JobQueueEntry.ID, JobQueueEntry.Description, JobQueueEntry.Status);
    end;

    /// <summary>Filters the entries to the MobileNAV BackgroundRefresh job that are not On Hold and finds the first.</summary>
    /// <param name="JobQueueEntry">Receives the filtered entries, positioned on the first.</param>
    /// <returns>True when at least one entry is not On Hold.</returns>
    procedure FindNotOnHold(var JobQueueEntry: Record "Job Queue Entry"): Boolean
    begin
        JobQueueEntry.Reset();
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"MobileNAV BackgroundRefresh JQ");
        JobQueueEntry.SetRange("Recurring Job", true);
        JobQueueEntry.SetFilter(Status, '<>%1', JobQueueEntry.Status::"On Hold");
        exit(JobQueueEntry.FindSet());
    end;

    /// <summary>The message for one entry: what it is, its status, and the fix.</summary>
    /// <param name="JobQueueEntry">The entry that is not On Hold.</param>
    /// <returns>The error and warning text.</returns>
    procedure ErrorText(JobQueueEntry: Record "Job Queue Entry"): Text
    begin
        exit(StrSubstNo(this.NotOnHoldMsg, JobQueueEntry.ID, JobQueueEntry.Description, JobQueueEntry.Status));
    end;

    var
        NotOnHoldMsg: Label 'The MobileNAV BackgroundRefresh job queue entry %1 (%2) has status %3. MobileNAV''s rebuild stops with "Status must be equal to On Hold" while it runs. Open Job Queue Entries, set the entry On Hold, run the apply again, then set it back to Ready.', Comment = '%1 = job queue entry id, %2 = description, %3 = status';
}

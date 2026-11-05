namespace BradFullwood.MobileNAV.Configuration;

using System.Threading;

/// <summary>
/// Applies one provider in a job queue session. Business Central cancels an API request after 8 minutes,
/// and MobileNAV's device handover can take longer than that in a company with many profiles and users. A
/// job queue session has no such limit and runs as the user who scheduled it. The standard job queue is
/// used (Job Queue Entry.ScheduleJobQueueEntryWithParameters) so a failure is kept in the Job Queue Log
/// Entries with MobileNAV's error text. The parameter string holds the provider id.
/// </summary>
codeunit 77834 "BJF MN Background Apply"
{
    Access = Internal;
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        TempProviderBuffer: Record "BJF MN Provider Buffer" temporary;
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
    begin
        ProviderCatalog.Populate(TempProviderBuffer);
        if not TempProviderBuffer.Get(CopyStr(Rec."Parameter String", 1, MaxStrLen(TempProviderBuffer."Provider ID"))) then
            Error(this.ProviderNotFoundErr, Rec."Parameter String");
        ConfigurationApplication.ApplyProvider(TempProviderBuffer.Provider, true);
    end;

    /// <summary>Schedules the apply of a provider in a job queue session that starts at once.</summary>
    /// <param name="ProviderId">The provider to apply.</param>
    /// <returns>The id of the job queue entry.</returns>
    procedure Schedule(ProviderId: Code[50]): Guid
    var
        JobQueueEntry: Record "Job Queue Entry";
        PlatformSpecific: Codeunit "MobileNAV Platform Specific";
        EmptyRecordId: RecordId;
    begin
        if PlatformSpecific.IsUserDelegatedAdmin() then begin
            this.StartBackgroundSession(ProviderId);
            exit(JobQueueEntry.ID);
        end;
        JobQueueEntry.ScheduleJobQueueEntryWithParameters(Codeunit::"BJF MN Background Apply", EmptyRecordId, ProviderId);
        exit(JobQueueEntry.ID);
    end;

    /// <summary>
    /// A job queue entry scheduled by a delegated administrator does not run, so for one the apply runs
    /// in a background session started with StartSession instead. The entry passed in is not inserted:
    /// it only carries the provider id to OnRun. The outcome is the provider's state and the Doctor's
    /// apply state check, as there is no Job Queue Log Entry.
    /// </summary>
    /// <param name="ProviderId">The provider to apply.</param>
    local procedure StartBackgroundSession(ProviderId: Code[50])
    var
        TempJobQueueEntry: Record "Job Queue Entry" temporary;
        SessionId: Integer;
    begin
        TempJobQueueEntry."Parameter String" := ProviderId;
        if not Session.StartSession(SessionId, Codeunit::"BJF MN Background Apply", CompanyName(), TempJobQueueEntry) then
            Error(this.SessionNotStartedErr, ProviderId);
    end;

    var
        ProviderNotFoundErr: Label 'No configuration provider with id %1 is registered.', Comment = '%1 = provider id';
        SessionNotStartedErr: Label 'Business Central did not start a background session to apply provider %1.', Comment = '%1 = provider id';
}

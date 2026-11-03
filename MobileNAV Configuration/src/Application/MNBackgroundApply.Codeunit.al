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
        EmptyRecordId: RecordId;
    begin
        JobQueueEntry.ScheduleJobQueueEntryWithParameters(Codeunit::"BJF MN Background Apply", EmptyRecordId, ProviderId);
        exit(JobQueueEntry.ID);
    end;

    var
        ProviderNotFoundErr: Label 'No configuration provider with id %1 is registered.', Comment = '%1 = provider id';
}

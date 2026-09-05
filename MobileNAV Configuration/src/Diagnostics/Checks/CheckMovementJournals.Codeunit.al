namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Foundation.NoSeries;
using Microsoft.Inventory.Journal;

codeunit 77771 "BJF Check Movement Journals" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV User Setup" = r,
        tabledata "Item Journal Batch" = rm,
        tabledata "No. Series" = ri,
        tabledata "No. Series Line" = ri;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        MobileNAVUserSetup: Record "MobileNAV User Setup";
        CheckedBatches: Dictionary of [Text, Boolean];
    begin
        if MobileNAVUserSetup.FindSet() then
            repeat
                this.CheckUserSetup(Finding, MobileNAVUserSetup, CheckedBatches);
            until MobileNAVUserSetup.Next() = 0;
    end;

    local procedure CheckUserSetup(var Finding: Record "BJF Diagnostic Finding"; MobileNAVUserSetup: Record "MobileNAV User Setup"; var CheckedBatches: Dictionary of [Text, Boolean])
    var
        ItemJournalBatch: Record "Item Journal Batch";
    begin
        if MobileNAVUserSetup."Movement Journal Name" = '' then begin
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Movement Journals", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(this.NoMovementJournalMsg, MobileNAVUserSetup."User ID"), MobileNAVUserSetup.RecordId());
            exit;
        end;

        ItemJournalBatch.SetRange(Name, MobileNAVUserSetup."Movement Journal Name");
        ItemJournalBatch.SetRange("Template Type", ItemJournalBatch."Template Type"::Transfer);
        if not ItemJournalBatch.FindFirst() then begin
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Movement Journals", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(this.MovementBatchMissingMsg, MobileNAVUserSetup."Movement Journal Name", MobileNAVUserSetup."User ID"), MobileNAVUserSetup.RecordId());
            exit;
        end;

        // Move Package builds its journal lines with SetUpNewLine, which takes
        // Document No. from the batch's No. Series; without one the line posts
        // with a blank Document No. and fails "Document No. must have a value".
        if (ItemJournalBatch."No. Series" <> '') or
           CheckedBatches.ContainsKey(ItemJournalBatch."Journal Template Name" + '/' + ItemJournalBatch.Name)
        then
            exit;

        CheckedBatches.Add(ItemJournalBatch."Journal Template Name" + '/' + ItemJournalBatch.Name, true);
        Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Movement Journals", Enum::"BJF Diagnostic Severity"::Blocker,
            StrSubstNo(this.NoDocumentSeriesMsg, ItemJournalBatch.Name, ItemJournalBatch."Journal Template Name"), ItemJournalBatch.RecordId(),
            StrSubstNo(this.AssignSeriesFixLbl, this.MovementSeriesCode(), ItemJournalBatch.Name));
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalBatch: Record "Item Journal Batch";
        RecRef: RecordRef;
    begin
        if Finding."Related Record ID".TableNo() <> Database::"Item Journal Batch" then
            Error(this.NoAutomaticFixErr);
        RecRef.Get(Finding."Related Record ID");
        RecRef.SetTable(ItemJournalBatch);
        if ItemJournalBatch."No. Series" <> '' then
            exit;
        ItemJournalBatch.Validate("No. Series", this.EnsureMovementSeries());
        ItemJournalBatch.Modify(true);
    end;

    local procedure EnsureMovementSeries(): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if NoSeries.Get(this.MovementSeriesCode()) then
            exit(NoSeries.Code);

        NoSeries.Init();
        NoSeries.Validate(Code, this.MovementSeriesCode());
        NoSeries.Validate(Description, this.MovementSeriesDescriptionLbl);
        // Only errors when both Default Nos. and Manual Nos. are false; Default Nos. is set true here.
        NoSeries.Validate("Default Nos.", true);
        NoSeries.Insert(true);

        NoSeriesLine.Init();
        NoSeriesLine.Validate("Series Code", NoSeries.Code);
        NoSeriesLine.Validate("Line No.", 10000);
        NoSeriesLine.Validate("Starting No.", this.MovementSeriesStartTok);
        NoSeriesLine.Insert(true);

        exit(NoSeries.Code);
    end;

    local procedure MovementSeriesCode(): Code[20]
    begin
        exit(this.MovementSeriesCodeTok);
    end;

    var
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        MovementSeriesCodeTok: Label 'MNMOVE', Locked = true;
        MovementSeriesStartTok: Label 'MNMOVE000001', Locked = true;
        MovementSeriesDescriptionLbl: Label 'MobileNAV package moves', MaxLength = 100;
        NoMovementJournalMsg: Label 'MobileNAV User Setup for user %1 has no Movement Journal Name. Move/Split Package will fail for this user.', Comment = '%1 = user id';
        MovementBatchMissingMsg: Label 'Item journal batch %1 (user %2) does not exist on any Transfer-type item journal template. Move/Split Package will fail.', Comment = '%1 = batch name, %2 = user id';
        NoDocumentSeriesMsg: Label 'Movement batch %1 (template %2) has no No. Series. Move/Split Package lines get a blank Document No. and posting fails with "Document No. must have a value".', Comment = '%1 = batch name, %2 = template name';
        AssignSeriesFixLbl: Label 'Assign no. series %1 (created if missing) to movement batch %2.', Comment = '%1 = series code, %2 = batch name';
}

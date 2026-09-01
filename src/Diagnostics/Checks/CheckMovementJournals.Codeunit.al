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
        ItemJournalBatch: Record "Item Journal Batch";
        CheckedBatches: Dictionary of [Text, Boolean];
    begin
        if MobileNAVUserSetup.FindSet() then
            repeat
                if MobileNAVUserSetup."Movement Journal Name" = '' then
                    Finding.Add(Enum::"BJF Diagnostic Check Type"::"Movement Journals", Enum::"BJF Diagnostic Severity"::Blocker,
                        StrSubstNo(NoMovementJournalMsg, MobileNAVUserSetup."User ID"), MobileNAVUserSetup.RecordId())
                else begin
                    ItemJournalBatch.SetRange(Name, MobileNAVUserSetup."Movement Journal Name");
                    ItemJournalBatch.SetRange("Template Type", ItemJournalBatch."Template Type"::Transfer);
                    if not ItemJournalBatch.FindFirst() then
                        Finding.Add(Enum::"BJF Diagnostic Check Type"::"Movement Journals", Enum::"BJF Diagnostic Severity"::Blocker,
                            StrSubstNo(MovementBatchMissingMsg, MobileNAVUserSetup."Movement Journal Name", MobileNAVUserSetup."User ID"), MobileNAVUserSetup.RecordId())
                    else
                        // Move Package builds its journal lines with SetUpNewLine, which takes
                        // Document No. from the batch's No. Series; without one the line posts
                        // with a blank Document No. and fails "Document No. must have a value".
                        if (ItemJournalBatch."No. Series" = '') and
                           not CheckedBatches.ContainsKey(ItemJournalBatch."Journal Template Name" + '/' + ItemJournalBatch.Name)
                        then begin
                            CheckedBatches.Add(ItemJournalBatch."Journal Template Name" + '/' + ItemJournalBatch.Name, true);
                            Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Movement Journals", Enum::"BJF Diagnostic Severity"::Blocker,
                                StrSubstNo(NoDocumentSeriesMsg, ItemJournalBatch.Name, ItemJournalBatch."Journal Template Name"), ItemJournalBatch.RecordId(),
                                StrSubstNo(AssignSeriesFixLbl, MovementSeriesCode(), ItemJournalBatch.Name));
                        end;
                end;
            until MobileNAVUserSetup.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalBatch: Record "Item Journal Batch";
        RecRef: RecordRef;
    begin
        if Finding."Related Record ID".TableNo() <> Database::"Item Journal Batch" then
            Error(NoAutomaticFixErr);
        RecRef.Get(Finding."Related Record ID");
        RecRef.SetTable(ItemJournalBatch);
        if ItemJournalBatch."No. Series" <> '' then
            exit;
        ItemJournalBatch.Validate("No. Series", EnsureMovementSeries());
        ItemJournalBatch.Modify(true);
    end;

    local procedure EnsureMovementSeries(): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        if NoSeries.Get(MovementSeriesCode()) then
            exit(NoSeries.Code);

        NoSeries.Init();
        NoSeries.Code := MovementSeriesCode();
        NoSeries.Description := MovementSeriesDescriptionLbl;
        NoSeries."Default Nos." := true;
        NoSeries.Insert(true);

        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := NoSeries.Code;
        NoSeriesLine."Line No." := 10000;
        NoSeriesLine.Validate("Starting No.", MovementSeriesStartTok);
        NoSeriesLine.Insert(true);

        exit(NoSeries.Code);
    end;

    local procedure MovementSeriesCode(): Code[20]
    begin
        exit(MovementSeriesCodeTok);
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

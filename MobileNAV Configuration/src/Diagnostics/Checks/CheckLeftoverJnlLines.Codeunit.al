namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;

codeunit 77773 "BJF Check Leftover Jnl. Lines" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Item Journal Batch" = r,
        tabledata "Item Journal Line" = rd,
        tabledata "Reservation Entry" = rimd,
        tabledata Location = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalLine: Record "Item Journal Line";
        Location: Record Location;
        MovementJournalMgt: Codeunit "BJF Movement Journal Mgt.";
        BinMissing: Boolean;
        FixDescription: Text;
    begin
        CheckOutputBatchLeftovers(Finding);

        MovementJournalMgt.SetMovementLineFilters(ItemJournalLine);
        if ItemJournalLine.FindSet() then
            repeat
                BinMissing := false;
                if Location.Get(ItemJournalLine."Location Code") then
                    BinMissing := Location."Bin Mandatory" and ((ItemJournalLine."New Bin Code" = '') or (ItemJournalLine."Bin Code" = ''));
                FixDescription := StrSubstNo(DeleteLineFixLbl, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.");
                // MobileNAV WMS Move Package posts the entire batch, so any line left here
                // is swept into the next Move Package posting and can block it.
                if BinMissing then
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines", Enum::"BJF Diagnostic Severity"::Blocker,
                        StrSubstNo(BrokenLeftoverLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.", ItemJournalLine."Item No."), ItemJournalLine.RecordId(), FixDescription)
                else
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines", Enum::"BJF Diagnostic Severity"::Warning,
                        StrSubstNo(LeftoverLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.", ItemJournalLine."Item No.", ItemJournalLine.Quantity), ItemJournalLine.RecordId(), FixDescription);
            until ItemJournalLine.Next() = 0;
    end;

    /// <summary>
    /// Flags stale lines in the item journal batch the MobileNAV output card writes to. The
    /// card's OnInsertRecord targets the first non-recurring Output-type batch in the company
    /// and inserts a line every time a device opens the card, so an abandoned card or a failed
    /// posting leaves its line behind. The batch is shared by every device, and posting it
    /// from the BC client would post every stale output again, so leftovers are not cosmetic.
    /// Lines younger than an hour are skipped - they may belong to a wizard in progress.
    /// </summary>
    local procedure CheckOutputBatchLeftovers(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        FixDescription: Text;
    begin
        ItemJournalBatch.SetRange(Recurring, false);
        ItemJournalBatch.SetRange("Template Type", ItemJournalBatch."Template Type"::Output);
        if not ItemJournalBatch.FindFirst() then
            exit;

        ItemJournalLine.SetRange("Journal Template Name", ItemJournalBatch."Journal Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", ItemJournalBatch.Name);
        ItemJournalLine.SetFilter(SystemCreatedAt, '<%1', CurrentDateTime() - InFlightGracePeriod());
        if ItemJournalLine.FindSet() then
            repeat
                FixDescription := StrSubstNo(DeleteLineFixLbl, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.");
                if ItemJournalLine."Item No." = '' then
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines", Enum::"BJF Diagnostic Severity"::Warning,
                        StrSubstNo(AbandonedOutputLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No."), ItemJournalLine.RecordId(), FixDescription)
                else
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines", Enum::"BJF Diagnostic Severity"::Warning,
                        StrSubstNo(StaleOutputLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.", ItemJournalLine."Item No.", ItemJournalLine."Order No."), ItemJournalLine.RecordId(), FixDescription);
            until ItemJournalLine.Next() = 0;
    end;

    local procedure InFlightGracePeriod(): Duration
    begin
        exit(60 * 60 * 1000); // one hour
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalLine: Record "Item Journal Line";
        ReservationManagement: Codeunit "Reservation Management";
        RecRef: RecordRef;
    begin
        if Finding."Related Record ID".TableNo() <> Database::"Item Journal Line" then
            exit;
        if not RecRef.Get(Finding."Related Record ID") then
            exit; // already deleted
        RecRef.SetTable(ItemJournalLine);
        // Leftover lines usually carry item tracking (reservation entries) and table 83's
        // OnDelete refuses to delete the line while they exist. Release them first - the
        // same calls Item Jnl. Line-Reserve.DeleteLine makes after the journal page confirm.
        ReservationManagement.SetReservSource(ItemJournalLine);
        ReservationManagement.SetItemTrackingHandling(1); // Allow deletion
        ReservationManagement.DeleteReservEntries(true, 0);
        ItemJournalLine.Delete(true);
    end;

    var
        BrokenLeftoverLineMsg: Label 'Leftover journal line %1/%2/%3 (item %4) is missing Bin Code or New Bin Code. Move Package posts the whole batch and fails on this line. Delete it.', Comment = '%1 = template, %2 = batch, %3 = line no., %4 = item no.';
        LeftoverLineMsg: Label 'Leftover journal line %1/%2/%3 (item %4, qty %5) sits in a MobileNAV movement batch. The next Move Package will post it together with the move. Delete it if unintended.', Comment = '%1 = template, %2 = batch, %3 = line no., %4 = item no., %5 = quantity';
        DeleteLineFixLbl: Label 'Delete item journal line %1/%2/%3 together with its item tracking.', Comment = '%1 = template, %2 = batch, %3 = line no.';
        AbandonedOutputLineMsg: Label 'Empty journal line %1/%2/%3 was left in the MobileNAV output batch by a card that was opened and abandoned. Delete it.', Comment = '%1 = template, %2 = batch, %3 = line no.';
        StaleOutputLineMsg: Label 'Stale output journal line %1/%2/%3 (item %4, order %5) was left behind by an abandoned or failed MobileNAV output. Posting the batch from the BC client would post it again - delete it.', Comment = '%1 = template, %2 = batch, %3 = line no., %4 = item no., %5 = order no.';
}

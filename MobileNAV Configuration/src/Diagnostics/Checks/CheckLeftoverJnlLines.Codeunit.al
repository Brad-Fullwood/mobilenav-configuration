namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Tracking;

codeunit 77773 "BJF Check Leftover Jnl. Lines" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Item Journal Batch" = r,
        tabledata "Item Journal Line" = rd,
        tabledata "Reservation Entry" = rimd;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    begin
        this.CheckOutputBatchLeftovers(Finding);
    end;

    /// <summary>
    /// Flags stale lines in the item journal batch the MobileNAV output card writes to. The
    /// card's OnInsertRecord targets the first non-recurring Output-type batch in the company
    /// and inserts a line every time a device opens the card, so an abandoned card or a failed
    /// posting leaves its line behind. The batch is shared by every device, and posting it
    /// from the BC client would post every stale output again, so leftovers are not cosmetic.
    /// Lines younger than an hour are skipped - they may belong to a wizard in progress.
    /// </summary>
    /// <param name="Finding">Receives a finding for each stale line.</param>
    local procedure CheckOutputBatchLeftovers(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        FixDescription: Text;
    begin
        ItemJournalBatch.SetRange(Recurring, false);
        ItemJournalBatch.SetRange("Template Type", ItemJournalBatch."Template Type"::Output);
        ItemJournalBatch.SetLoadFields("Journal Template Name", Name);
        if not ItemJournalBatch.FindFirst() then
            exit;

        ItemJournalLine.SetRange("Journal Template Name", ItemJournalBatch."Journal Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", ItemJournalBatch.Name);
        ItemJournalLine.SetFilter(SystemCreatedAt, '<%1', CurrentDateTime() - this.InFlightGracePeriod());
        ItemJournalLine.SetLoadFields("Item No.", "Order No.");
        if ItemJournalLine.FindSet() then
            repeat
                FixDescription := StrSubstNo(this.DeleteLineFixLbl, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.");
                if ItemJournalLine."Item No." = '' then
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines", Enum::"BJF Diagnostic Severity"::Warning,
                        StrSubstNo(this.AbandonedOutputLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No."), ItemJournalLine.RecordId(), FixDescription)
                else
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Journal Lines", Enum::"BJF Diagnostic Severity"::Warning,
                        StrSubstNo(this.StaleOutputLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.", ItemJournalLine."Item No.", ItemJournalLine."Order No."), ItemJournalLine.RecordId(), FixDescription);
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
        DeleteLineFixLbl: Label 'Delete item journal line %1/%2/%3 together with its item tracking.', Comment = '%1 = template, %2 = batch, %3 = line no.';
        AbandonedOutputLineMsg: Label 'Empty journal line %1/%2/%3 was left in the MobileNAV output batch by a card that was opened and abandoned. Delete it.', Comment = '%1 = template, %2 = batch, %3 = line no.';
        StaleOutputLineMsg: Label 'Stale output journal line %1/%2/%3 (item %4, order %5) was left behind by an abandoned or failed MobileNAV output. Posting the batch from the BC client would post it again - delete it.', Comment = '%1 = template, %2 = batch, %3 = line no., %4 = item no., %5 = order no.';
}

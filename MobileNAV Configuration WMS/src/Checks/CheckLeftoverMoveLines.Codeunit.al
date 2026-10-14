namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Tracking;

codeunit 77754 "BJF Check Leftover Move Lines" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Item Journal Line" = rd,
        tabledata Location = r,
        tabledata "Reservation Entry" = rimd;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemJournalLine: Record "Item Journal Line";
        MovementJournalMgt: Codeunit "BJF Movement Journal Mgt.";
    begin
        MovementJournalMgt.SetMovementLineFilters(ItemJournalLine);
        if ItemJournalLine.FindSet() then
            repeat
                this.CheckMovementLine(Finding, ItemJournalLine);
            until ItemJournalLine.Next() = 0;
    end;

    // MobileNAV WMS Move Package posts the entire batch, so any line left here
    // is swept into the next Move Package posting and can block it.
    local procedure CheckMovementLine(var Finding: Record "BJF Diagnostic Finding"; ItemJournalLine: Record "Item Journal Line")
    var
        Location: Record Location;
        BinMissing: Boolean;
        FixDescription: Text;
    begin
        BinMissing := false;
        Location.SetLoadFields("Bin Mandatory");
        if Location.Get(ItemJournalLine."Location Code") then
            BinMissing := Location."Bin Mandatory" and ((ItemJournalLine."New Bin Code" = '') or (ItemJournalLine."Bin Code" = ''));
        FixDescription := StrSubstNo(this.DeleteLineFixLbl, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.");
        if BinMissing then
            Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Move Lines", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(this.BrokenLeftoverLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.", ItemJournalLine."Item No."), ItemJournalLine.RecordId(), FixDescription)
        else
            Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Leftover Move Lines", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(this.LeftoverLineMsg, ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", ItemJournalLine."Line No.", ItemJournalLine."Item No.", ItemJournalLine.Quantity), ItemJournalLine.RecordId(), FixDescription);
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
}

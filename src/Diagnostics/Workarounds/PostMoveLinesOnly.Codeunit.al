namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Setup;

/// <summary>
/// WORKAROUND: MUL WMS PageFunctions.MovePackage2 posts the whole movement batch
/// (Item Jnl.-Post Batch without a Line No. filter), unlike its sibling
/// SplitPackageInternal which correctly filters to the line it created. Any stale line
/// in the batch blocks every Move Package - or worse, posts silently together with it.
///
/// When "MobileNAV Move Posts Only Its Own Lines (Workaround)" is enabled in Inventory
/// Setup, this subscriber narrows non-interactive postings of a MobileNAV movement batch
/// to the lines created in the current session (stamped by tableextension
/// "BJF Item Journal Line"). The stamp is written in the same transaction as the line,
/// so rolled-back attempts leave no stale state. If no line in the batch carries the
/// current session id, the posting is not a Move Package call and is left untouched.
///
/// Delete this workaround once MultiSoft fixes MovePackage2 to filter its own lines.
/// </summary>
codeunit 77777 "BJF Post Move Lines Only"
{
    Access = Internal;
    Permissions = tabledata "Inventory Setup" = r,
        tabledata "Item Journal Line" = r;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Batch", OnBeforeCode, '', false, false)]
    local procedure ItemJnlPostBatchOnBeforeCode(var ItemJournalLine: Record "Item Journal Line"; var ItemLedgerEntry: Record "Item Ledger Entry")
    var
        InventorySetup: Record "Inventory Setup";
        MovementJournalMgt: Codeunit "BJF Movement Journal Mgt.";
    begin
        if GuiAllowed() then
            exit; // interactive journal posting stays untouched
        if ItemJournalLine.GetFilter("Line No.") <> '' then
            exit; // caller already scoped its lines (e.g. Split Package)
        if not InventorySetup.Get() then
            exit;
        if not InventorySetup."BJF MN Move Posts Own Lines" then
            exit;
        if not MovementJournalMgt.IsMovementBatch(ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name") then
            exit;

        ItemJournalLine.SetRange("BJF MN Created Session ID", SessionId());
        if ItemJournalLine.IsEmpty() then
            ItemJournalLine.SetRange("BJF MN Created Session ID"); // not a Move Package call - leave behavior unchanged
    end;
}

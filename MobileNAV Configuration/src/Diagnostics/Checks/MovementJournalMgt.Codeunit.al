namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Journal;

/// <summary>
/// Shared helpers for the item journal batches that MobileNAV uses for package moves/splits
/// (each MobileNAV User Setup "Movement Journal Name" on Transfer-type templates).
/// </summary>
codeunit 77775 "BJF Movement Journal Mgt."
{
    Access = Internal;
    Permissions = tabledata "Item Journal Template" = r,
        tabledata "MobileNAV User Setup" = r;

    /// <summary>
    /// Filters the lines to all MobileNAV movement batches. Nothing should persist in those
    /// batches between device operations; leftovers block or pollute the next Move Package,
    /// which posts the whole batch.
    /// </summary>
    procedure SetMovementLineFilters(var ItemJournalLine: Record "Item Journal Line")
    var
        TemplateFilter: Text;
        BatchFilter: Text;
    begin
        TemplateFilter := this.TransferTemplateFilter();
        BatchFilter := this.MovementBatchFilter();

        // No Transfer templates or no MobileNAV movement batches configured: match nothing.
        if (TemplateFilter = '') or (BatchFilter = '') then begin
            ItemJournalLine.SetRange("Journal Template Name", '');
            ItemJournalLine.SetRange("Journal Batch Name", '');
            exit;
        end;

        ItemJournalLine.SetFilter("Journal Template Name", TemplateFilter);
        ItemJournalLine.SetFilter("Journal Batch Name", BatchFilter);
    end;

    local procedure TransferTemplateFilter(): Text
    var
        ItemJournalTemplate: Record "Item Journal Template";
        TemplateFilter: TextBuilder;
    begin
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Transfer);
        if ItemJournalTemplate.FindSet() then
            repeat
                if TemplateFilter.Length() > 0 then
                    TemplateFilter.Append('|');
                TemplateFilter.Append('''' + ItemJournalTemplate.Name + '''');
            until ItemJournalTemplate.Next() = 0;
        exit(TemplateFilter.ToText());
    end;

    local procedure MovementBatchFilter(): Text
    var
        MobileNAVUserSetup: Record "MobileNAV User Setup";
        BatchFilter: TextBuilder;
    begin
        MobileNAVUserSetup.SetFilter("Movement Journal Name", '<>%1', '');
        if MobileNAVUserSetup.FindSet() then
            repeat
                if not BatchFilter.ToText().Contains('''' + MobileNAVUserSetup."Movement Journal Name" + '''') then begin
                    if BatchFilter.Length() > 0 then
                        BatchFilter.Append('|');
                    BatchFilter.Append('''' + MobileNAVUserSetup."Movement Journal Name" + '''');
                end;
            until MobileNAVUserSetup.Next() = 0;
        exit(BatchFilter.ToText());
    end;

    /// <summary>
    /// True when the batch is one of the MobileNAV movement batches: a batch on a
    /// Transfer-type template that some MobileNAV User Setup uses as Movement Journal Name.
    /// </summary>
    procedure IsMovementBatch(TemplateName: Code[10]; BatchName: Code[10]): Boolean
    var
        ItemJournalTemplate: Record "Item Journal Template";
        MobileNAVUserSetup: Record "MobileNAV User Setup";
    begin
        if not ItemJournalTemplate.Get(TemplateName) then
            exit(false);
        if ItemJournalTemplate.Type <> ItemJournalTemplate.Type::Transfer then
            exit(false);
        MobileNAVUserSetup.SetRange("Movement Journal Name", BatchName);
        exit(not MobileNAVUserSetup.IsEmpty());
    end;
}

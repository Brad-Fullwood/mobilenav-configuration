namespace BradFullwood.MobileNAV.Showcase;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Item;

/// <summary>
/// Handles the device buttons the provider declares. One subscriber, filtered on the page and
/// the control: the framework raises it for every tap on every page, with the tapped record as
/// a RecordRef. No MobileNAV table events, no service names.
/// </summary>
codeunit 50102 "Showcase Button Handler"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Function Router", OnPageFunction, '', false, false)]
    local procedure OnPageFunction(PageId: Integer; ControlName: Text[75]; FunctionRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    var
        Item: Record Item;
    begin
        if (PageId <> Page::"MobileNAV Item") or (ControlName <> this.FlagReorderTok) then
            exit;
        FunctionRecord.SetTable(Item);
        Item.Validate("Showcase Reorder Flagged", true);
        Item.Modify(true);
        // Answer the device: a toast, and a reload so the flag shows.
        FieldControlFactory.FcSetToastMessage(Item, StrSubstNo(this.FlaggedMsg, Item."No."));
        FieldControlFactory.FcRefreshCurrent(Item);
    end;

    var
        FlagReorderTok: Label 'ShowcaseFlagReorder', Locked = true;
        FlaggedMsg: Label 'Item %1 is flagged for reorder.', Comment = '%1 = item no.';
}

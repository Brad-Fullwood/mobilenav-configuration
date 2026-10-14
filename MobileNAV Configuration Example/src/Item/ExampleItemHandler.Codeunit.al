namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Item;

/// <summary>
/// Answers the button the provider declares on MobileNAV's item page. The framework raises one
/// event for every tap on every page, with the tapped record as a RecordRef. Filter on the page
/// and the control, then do the work.
/// </summary>
codeunit 50102 "Example Item Handler"
{
    Access = Internal;
    Permissions = tabledata Item = m;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Function Router", OnPageFunction, '', false, false)]
    local procedure "BJF MN Function Router_OnPageFunction"(PageId: Integer; ControlName: Text[75]; FunctionRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    var
        Item: Record Item;
    begin
        if (PageId <> Page::"MobileNAV Item") or (ControlName <> this.FlagReorderTok) then
            exit;
        FunctionRecord.SetTable(Item);
        Item.Validate("Example Reorder Flagged", true);
        Item.Modify(true);
        // Answer the device: a toast, and a reload so the flag shows.
        FieldControlFactory.FcSetToastMessage(Item, StrSubstNo(this.FlaggedMsg, Item."No."));
        FieldControlFactory.FcRefreshCurrent(Item);
    end;

    var
        FlagReorderTok: Label 'ExampleFlagReorder', Locked = true;
        FlaggedMsg: Label 'Item %1 is flagged for reorder.', Comment = '%1 = item no.';
}

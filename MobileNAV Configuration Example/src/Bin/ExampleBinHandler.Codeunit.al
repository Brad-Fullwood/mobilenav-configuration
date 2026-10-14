namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Warehouse.Structure;

/// <summary>
/// Answers the controls the provider declares on MobileNAV's bin page: the button tap, and the
/// field control that colours the first line of every bin that holds stock.
/// </summary>
codeunit 50104 "Example Bin Handler"
{
    Access = Internal;
    Permissions = tabledata "Bin Content" = r;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Function Router", OnPageFunction, '', false, false)]
    local procedure "BJF MN Function Router_OnPageFunction"(PageId: Integer; ControlName: Text[75]; FunctionRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    var
        Bin: Record Bin;
        BinContent: Record "Bin Content";
    begin
        if (PageId <> Page::"MobileNAV Bin") or (ControlName <> this.BinItemsTok) then
            exit;
        FunctionRecord.SetTable(Bin);
        BinContent.SetRange("Location Code", Bin."Location Code");
        BinContent.SetRange("Bin Code", Bin.Code);
        BinContent.SetFilter(Quantity, '<>0');
        FieldControlFactory.FcSetToastMessage(Bin, StrSubstNo(this.BinItemsMsg, Bin.Code, BinContent.Count()));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Field Control", OnCalculateFieldControl, '', false, false)]
    local procedure "BJF MN Field Control_OnCalculateFieldControl"(PageId: Integer; SourceRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    var
        Bin: Record Bin;
    begin
        if PageId <> Page::"MobileNAV Bin" then
            exit;
        SourceRecord.SetTable(Bin);
        // Green first line (red 0, green 128, blue 0) for a bin that holds stock.
        if not Bin.Empty then
            FieldControlFactory.FcSetFirstLineColor(Bin, 0, 128, 0);
    end;

    var
        BinItemsTok: Label 'ExampleBinItems', Locked = true;
        BinItemsMsg: Label 'Bin %1 holds %2 items.', Comment = '%1 = bin code, %2 = number of items with stock in the bin';
}

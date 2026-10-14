namespace BradFullwood.MobileNAV.Example;

/// <summary>
/// Adds the example's controls to MobileNAV's own item page. This page extension is the only
/// MobileNAV object a developer touches: the fields, and a placeholder control for each button
/// and link. The provider's declaration does the rest.
/// </summary>
pageextension 50100 "Example MobileNAV Item" extends "MobileNAV Item"
{
    layout
    {
        addlast(General)
        {
            field(ExampleNotes; Rec."Example Notes")
            {
                ApplicationArea = All;
            }
            field(ExampleDefaultBin; Rec."Example Default Bin")
            {
                ApplicationArea = All;
            }
            field(ExampleReorderFlagged; Rec."Example Reorder Flagged")
            {
                ApplicationArea = All;
            }
            // A button is a placeholder control. The provider turns it into a device button.
            field(ExampleFlagReorder; '')
            {
                ApplicationArea = All;
                Caption = 'Flag for Reorder';
                ToolTip = 'Specifies the device button that flags the item for reorder. The provider declares it.';
            }
            // A link is a placeholder control too. The provider points it at the stock count page.
            field(ExampleStockCounts; '')
            {
                ApplicationArea = All;
                Caption = 'Stock Counts';
                ToolTip = 'Specifies the device button that opens your stock counts of the item. The provider declares it.';
            }
        }
    }
}

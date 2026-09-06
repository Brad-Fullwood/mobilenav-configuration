namespace BradFullwood.MobileNAV.Showcase;

/// <summary>
/// The count sheet the device shows. Nothing MobileNAV-specific here: a plain card over the
/// table. The control names are what the provider refers to.
/// </summary>
page 50100 "Showcase Stock Count"
{
    ApplicationArea = All;
    Caption = 'Stock Count';
    PageType = Card;
    SourceTable = "Showcase Stock Count";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(Count)
            {
                Caption = 'Count';
                field(UserId; Rec."User ID")
                {
                }
                field(ItemNo; Rec."Item No.")
                {
                }
                field(BinCode; Rec."Bin Code")
                {
                }
                field(CountedQuantity; Rec."Counted Quantity")
                {
                }
                field(LotNo; Rec."Lot No.")
                {
                }
                field(CountedAt; Rec."Counted At")
                {
                }
                field(Posted; Rec.Posted)
                {
                }
            }
        }
    }
}

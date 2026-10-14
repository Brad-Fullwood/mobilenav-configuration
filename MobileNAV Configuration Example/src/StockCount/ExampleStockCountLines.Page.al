namespace BradFullwood.MobileNAV.Example;

/// <summary>
/// The lines of a stock count. A device page is a flat list with a repeater: MobileNAV does not
/// show list parts, so the card reaches its lines through a link to this page instead.
/// </summary>
page 50102 "Example Stock Count Lines"
{
    ApplicationArea = All;
    AutoSplitKey = true;
    Caption = 'Stock Count Lines';
    DelayedInsert = true;
    PageType = List;
    SourceTable = "Example Stock Count Line";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(CountEntryNo; Rec."Count Entry No.")
                {
                }
                field(LineNo; Rec."Line No.")
                {
                    Visible = false;
                }
                field(LotNo; Rec."Lot No.")
                {
                }
                field(Quantity; Rec.Quantity)
                {
                }
            }
        }
    }
}

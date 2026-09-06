namespace BradFullwood.MobileNAV.Showcase;

/// <summary>
/// A dialog: two inputs and a button that runs code of ours. The provider publishes it as a
/// dialog and names the codeunit whose procedure the button runs.
/// </summary>
page 50101 "Showcase Quick Adjust"
{
    ApplicationArea = All;
    Caption = 'Quick Adjust';
    PageType = Card;
    SourceTable = "Showcase Stock Count";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(Adjust)
            {
                Caption = 'Adjust';
                field(UserId; Rec."User ID")
                {
                }
                field(ItemNo; Rec."Item No.")
                {
                }
                field(CountedQuantity; Rec."Counted Quantity")
                {
                }
                // The button. Its procedure on the function codeunit takes ItemNo and
                // CountedQuantity, filled from the controls with the same names.
                field(PostCount; '')
                {
                    Caption = 'Post';
                    ToolTip = 'Posts the count. A device button; the provider declares it.';
                }
            }
        }
    }
}

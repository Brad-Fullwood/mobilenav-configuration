namespace BradFullwood.MobileNAV.Showcase;

/// <summary>
/// Adds the showcase controls to MobileNAV's own item page. This is the only MobileNAV-specific
/// thing a developer does here: a page extension with the fields, and a placeholder control for
/// each button. The framework does the rest from the provider's declaration.
/// </summary>
pageextension 50100 "Showcase MobileNAV Item" extends "MobileNAV Item"
{
    layout
    {
        addlast(General)
        {
            field(ShowcaseNotes; Rec."Showcase Notes")
            {
                ApplicationArea = All;
            }
            field(ShowcaseDefaultBin; Rec."Showcase Default Bin")
            {
                ApplicationArea = All;
            }
            field(ShowcaseReorderFlagged; Rec."Showcase Reorder Flagged")
            {
                ApplicationArea = All;
            }
            // A button is a placeholder control; the provider turns it into a device button.
            field(ShowcaseFlagReorder; '')
            {
                ApplicationArea = All;
                Caption = 'Flag for Reorder';
                ToolTip = 'Flags the item for reorder. A device button; the provider declares it.';
            }
        }
    }
}

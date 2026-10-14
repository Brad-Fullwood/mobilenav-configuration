namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Lists every check the MobileNAV Doctor can run, with its area and what it looks at.</summary>
page 77815 "BJF MN Doctor Checks"
{
    Caption = 'MobileNAV Doctor Checks';
    PageType = List;
    SourceTable = "BJF Doctor Check";
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            repeater(Checks)
            {
                field("Check Type"; Rec."Check Type")
                {
                    ApplicationArea = All;
                }
                field("Check Area"; Rec."Check Area")
                {
                    ApplicationArea = All;
                }
                field("What It Checks"; Rec."What It Checks")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}

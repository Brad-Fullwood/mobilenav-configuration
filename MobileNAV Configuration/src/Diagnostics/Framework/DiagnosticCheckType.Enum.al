namespace BradFullwood.MobileNAV.Configuration;

enum 77762 "BJF Diagnostic Check Type" implements "BJF Diagnostic Check"
{
    Access = Public;
    Caption = 'Diagnostic Check';
    Extensible = true;

    value(0; "Movement Journals")
    {
        Caption = 'Movement Journals';
        Implementation = "BJF Diagnostic Check" = "BJF Check Movement Journals";
    }
    value(1; "Item Tracking Codes")
    {
        Caption = 'Item Tracking Codes';
        Implementation = "BJF Diagnostic Check" = "BJF Check Item Tracking Codes";
    }
    value(2; "Leftover Journal Lines")
    {
        Caption = 'Leftover Journal Lines';
        Implementation = "BJF Diagnostic Check" = "BJF Check Leftover Jnl. Lines";
    }
    value(3; "Page Relations")
    {
        Caption = 'Page Relations';
        Implementation = "BJF Diagnostic Check" = "BJF Check Page Relations";
    }
}

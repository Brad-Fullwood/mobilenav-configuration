namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Registers the checks that need WMS MobileNAV. The diagnostics runner walks the ordinals of
/// the base enum, so these run alongside the built-in checks as soon as this app is installed
/// and simply do not exist when it is not.
/// </summary>
enumextension 77740 "BJF Diagnostic Check Type WMS" extends "BJF Diagnostic Check Type"
{
    value(77740; "Inventory Setup")
    {
        Caption = 'Inventory Setup';
        Implementation = "BJF Diagnostic Check" = "BJF Check Inventory Setup";
    }
    value(77741; "Package Consistency")
    {
        Caption = 'Package Consistency';
        Implementation = "BJF Diagnostic Check" = "BJF Check Package Consistency";
    }
    value(77742; "Split Packages")
    {
        Caption = 'Split Packages';
        Implementation = "BJF Diagnostic Check" = "BJF Check Split Packages";
    }
    value(77743; "Movement Journals")
    {
        Caption = 'Movement Journals';
        Implementation = "BJF Diagnostic Check" = "BJF Check Movement Journals";
    }
    value(77744; "Item Tracking Codes")
    {
        Caption = 'Item Tracking Codes';
        Implementation = "BJF Diagnostic Check" = "BJF Check Item Tracking Codes";
    }
    value(77745; "Leftover Move Lines")
    {
        Caption = 'Leftover Move Lines';
        Implementation = "BJF Diagnostic Check" = "BJF Check Leftover Move Lines";
    }
    value(77746; "WMS Licence")
    {
        Caption = 'WMS Licence';
        Implementation = "BJF Diagnostic Check" = "BJF Check WMS Licence";
    }
}

namespace BradFullwood.MobileNAV.Diagnostics.WMS;

using BradFullwood.MobileNAV.Diagnostics;

/// <summary>
/// Registers the checks that need WMS MobileNAV. The diagnostics runner walks the ordinals of
/// the base enum, so these run alongside the built-in checks as soon as this app is installed
/// and simply do not exist when it is not.
/// </summary>
enumextension 77740 "BJF Diagnostic Check Type WMS" extends "BJF Diagnostic Check Type"
{
    value(100; "Inventory Setup")
    {
        Caption = 'Inventory Setup';
        Implementation = "BJF Diagnostic Check" = "BJF Check Inventory Setup";
    }
    value(101; "Package Consistency")
    {
        Caption = 'Package Consistency';
        Implementation = "BJF Diagnostic Check" = "BJF Check Package Consistency";
    }
    value(102; "Split Packages")
    {
        Caption = 'Split Packages';
        Implementation = "BJF Diagnostic Check" = "BJF Check Split Packages";
    }
}

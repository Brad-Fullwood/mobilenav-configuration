namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Setup;

// Kept as Removed so installs upgraded from 4.3.0.0 keep their column and upgrade
// without ForceSync. The feature moved to the MobileNAV Configuration WMS app.
tableextension 77765 "BJF Inventory Setup" extends "Inventory Setup"
{
    fields
    {
        field(77780; "BJF MN Old Move Posts Own Lines"; Boolean)
        {
            Caption = 'Move Posts Only Its Own Lines (Workaround)';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'Moved to the MobileNAV Configuration WMS app.';
            ObsoleteTag = '4.15.8.1';
        }
    }
}

namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Journal;

// Kept as Removed so installs upgraded from 4.3.0.0 keep their column and upgrade
// without ForceSync. The feature moved to the MobileNAV Configuration WMS app.
tableextension 77764 "BJF Item Journal Line" extends "Item Journal Line"
{
    fields
    {
        field(77780; "BJF MN Old Created Session ID"; Integer)
        {
            Caption = 'Created Session ID';
            DataClassification = SystemMetadata;
            ObsoleteState = Removed;
            ObsoleteReason = 'Moved to the MobileNAV Configuration WMS app.';
            ObsoleteTag = '4.15.8.1';
        }
    }
}

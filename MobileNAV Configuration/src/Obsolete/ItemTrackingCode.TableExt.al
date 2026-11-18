namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Tracking;

// Kept as Removed so installs upgraded from 4.3.0.0 keep their column and upgrade
// without ForceSync. The feature moved to the MobileNAV Configuration WMS app.
tableextension 77763 "BJF Item Tracking Code" extends "Item Tracking Code"
{
    fields
    {
        field(77780; "BJF MN Old Create Pkg Info on Post"; Boolean)
        {
            Caption = 'Create Package Info. on Posting (Workaround)';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteReason = 'Moved to the MobileNAV Configuration WMS app.';
            ObsoleteTag = '4.15.8.1';
        }
    }
}

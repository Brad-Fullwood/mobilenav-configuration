namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Tracking;

pageextension 77762 "BJF Item Tracking Code Card" extends "Item Tracking Code Card"
{
    layout
    {
        addafter("Package Specific Tracking")
        {
            field("BJF MN Create Pkg Info on Post"; Rec."BJF MN Create Pkg Info on Post")
            {
                ApplicationArea = ItemTracking;
                ToolTip = 'WORKAROUND for a Business Central gap: serial and lot numbers have "Create SN/Lot No. Info on Posting" toggles, but packages have no equivalent. When enabled, a missing Package No. Information record is created automatically during posting - including for the New Package No. of a reclassification (e.g. MobileNAV Split Package) - so "Package No. Info. Must Exist" can stay enabled. Remove this workaround once Microsoft adds the standard toggle.';
            }
        }
    }
}

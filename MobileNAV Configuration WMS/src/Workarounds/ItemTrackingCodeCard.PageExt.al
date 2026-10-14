namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Tracking;

pageextension 77746 "BJF Item Tracking Code Card" extends "Item Tracking Code Card"
{
    layout
    {
        addafter("Package Specific Tracking")
        {
            field("BJF MN Create Pkg Info on Post"; Rec."BJF MN Create Pkg Info on Post")
            {
                ApplicationArea = ItemTracking;
            }
        }
    }
}

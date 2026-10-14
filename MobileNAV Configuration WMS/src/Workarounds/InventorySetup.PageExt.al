namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Setup;

pageextension 77749 "BJF Inventory Setup" extends "Inventory Setup"
{
    layout
    {
        // Anchored on a standard control: the toggle sits at the end of the General group.
        addlast(General)
        {
            field("BJF MN Move Posts Own Lines"; Rec."BJF MN Move Posts Own Lines")
            {
                ApplicationArea = All;
            }
        }
    }
}

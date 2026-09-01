namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Setup;

pageextension 77763 "BJF Inventory Setup" extends "Inventory Setup"
{
    layout
    {
        // Anchored on a standard control so the toggle stays reachable whether or not
        // WMS MobileNAV is installed.
        addlast(General)
        {
            field("BJF MN Move Posts Own Lines"; Rec."BJF MN Move Posts Own Lines")
            {
                ApplicationArea = All;
                ToolTip = 'WORKAROUND for MobileNAV WMS: Move Package posts the entire movement journal batch instead of only the lines it created, so stale lines block or silently co-post with every move. When enabled, non-interactive postings of a MobileNAV movement batch are limited to the journal lines created in the same session - exactly the lines the move itself just created. Interactive journal posting is unaffected. Remove once MultiSoft fixes MovePackage2 to filter its own lines.';
            }
        }
    }
}

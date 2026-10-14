namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Setup;

tableextension 77748 "BJF Inventory Setup" extends "Inventory Setup"
{
    fields
    {
        field(77748; "BJF MN Move Posts Own Lines"; Boolean)
        {
            Caption = 'Move Posts Only Its Own Lines (Workaround)';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that non-interactive postings of a MobileNAV movement batch post only the lines created in the same session. Workaround for MobileNAV WMS Move Package, which posts the whole batch.';
        }
    }
}

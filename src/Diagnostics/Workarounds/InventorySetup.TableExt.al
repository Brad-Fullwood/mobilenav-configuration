namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Setup;

tableextension 77765 "BJF Inventory Setup" extends "Inventory Setup"
{
    fields
    {
        field(77780; "BJF MN Move Posts Own Lines"; Boolean)
        {
            Caption = 'Move Posts Only Its Own Lines (Workaround)';
            DataClassification = CustomerContent;
        }
    }
}

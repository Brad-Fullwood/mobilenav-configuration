namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Tracking;

tableextension 77745 "BJF Item Tracking Code" extends "Item Tracking Code"
{
    fields
    {
        field(77745; "BJF MN Create Pkg Info on Post"; Boolean)
        {
            Caption = 'Create Package Info. on Posting (Workaround)';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that a missing Package No. Information record is created during posting, so Package No. Info. Must Exist can stay on. Workaround: packages have no standard toggle.';
        }
    }
}

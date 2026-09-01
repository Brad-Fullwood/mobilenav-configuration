namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Tracking;

tableextension 77763 "BJF Item Tracking Code" extends "Item Tracking Code"
{
    fields
    {
        field(77780; "BJF MN Create Pkg Info on Post"; Boolean)
        {
            Caption = 'Create Package Info. on Posting (Workaround)';
            DataClassification = CustomerContent;
        }
    }
}

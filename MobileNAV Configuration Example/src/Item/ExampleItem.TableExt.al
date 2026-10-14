namespace BradFullwood.MobileNAV.Example;

using Microsoft.Inventory.Item;

/// <summary>What the example adds to the item: a note, a default bin and a reorder flag the device sets.</summary>
tableextension 50100 "Example Item" extends Item
{
    fields
    {
        field(50100; "Example Notes"; Text[100])
        {
            Caption = 'Notes';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies a note for the warehouse.';
        }
        field(50101; "Example Default Bin"; Code[20])
        {
            Caption = 'Default Bin';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the bin the item is normally kept in.';
        }
        field(50102; "Example Reorder Flagged"; Boolean)
        {
            Caption = 'Reorder Flagged';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies whether a device user flagged the item for reorder.';
        }
    }
}

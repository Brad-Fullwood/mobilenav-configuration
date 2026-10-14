namespace BradFullwood.MobileNAV.Example;

using Microsoft.Inventory.Item;
using Microsoft.Warehouse.Structure;

/// <summary>One count taken on a device. The user id is what MineOnly scopes the page by.</summary>
table 50100 "Example Stock Count"
{
    Caption = 'Stock Count';
    DataClassification = CustomerContent;
    Permissions = tabledata "Example Stock Count Line" = d;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AllowInCustomizations = Never;
            AutoIncrement = true;
            ToolTip = 'Specifies the number of the count.';
        }
        field(2; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
            ToolTip = 'Specifies who took the count. The device shows each user only their own counts.';
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
            ToolTip = 'Specifies the item, scanned or typed.';
        }
        field(4; "Bin Code"; Code[20])
        {
            Caption = 'Bin Code';
            TableRelation = Bin.Code;
            ToolTip = 'Specifies the bin the item was counted in.';
        }
        field(5; "Counted Quantity"; Decimal)
        {
            Caption = 'Counted Quantity';
            DecimalPlaces = 0 : 5;
            ToolTip = 'Specifies how many were counted.';
        }
        field(6; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            ToolTip = 'Specifies the lot, scanned or typed.';
        }
        field(7; "Counted At"; DateTime)
        {
            Caption = 'Counted At';
            Editable = false;
            ToolTip = 'Specifies when the count was taken.';
        }
        field(8; Posted; Boolean)
        {
            Caption = 'Posted';
            Editable = false;
            ToolTip = 'Specifies whether the count has been posted.';
        }
        field(9; Photo; Media)
        {
            Caption = 'Photo';
            ToolTip = 'Specifies the photo the device user took of the counted stock.';
        }
        field(10; Signature; Media)
        {
            Caption = 'Signature';
            ToolTip = 'Specifies the signature of the person who confirmed the count.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(User; "User ID", Posted)
        {
        }
    }

    trigger OnInsert()
    begin
        Rec.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(Rec."User ID")));
        Rec.Validate("Counted At", CurrentDateTime());
    end;

    trigger OnDelete()
    var
        StockCountLine: Record "Example Stock Count Line";
    begin
        StockCountLine.SetRange("Count Entry No.", Rec."Entry No.");
        StockCountLine.DeleteAll(true);
    end;
}

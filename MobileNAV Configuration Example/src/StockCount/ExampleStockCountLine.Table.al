namespace BradFullwood.MobileNAV.Example;

/// <summary>
/// One line of a stock count: a lot and the quantity counted of it. The device opens these rows
/// from the stock count card, filtered to that count.
/// </summary>
table 50103 "Example Stock Count Line"
{
    Caption = 'Stock Count Line';
    DataClassification = CustomerContent;
    DrillDownPageId = "Example Stock Count Lines";
    LookupPageId = "Example Stock Count Lines";

    fields
    {
        field(1; "Count Entry No."; Integer)
        {
            Caption = 'Count Entry No.';
            NotBlank = true;
            TableRelation = "Example Stock Count"."Entry No.";
            ToolTip = 'Specifies the stock count the line belongs to.';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
            ToolTip = 'Specifies the number of the line.';
        }
        field(3; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
            ToolTip = 'Specifies the lot that was counted.';
        }
        field(4; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            ToolTip = 'Specifies how many of the lot were counted.';
        }
    }

    keys
    {
        key(PK; "Count Entry No.", "Line No.")
        {
            Clustered = true;
        }
    }
}

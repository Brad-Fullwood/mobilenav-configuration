namespace BradFullwood.MobileNAV.Configuration;

/// <summary>One change an apply would make, as found by the last preview of a provider.</summary>
table 77707 "BJF MN Preview Line"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Preview Line';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
            Caption = 'Entry No.';
        }
        field(2; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
        }
        field(3; Change; Text[20])
        {
            Caption = 'Change';
        }
        field(4; "Table Name"; Text[80])
        {
            Caption = 'Table Name';
        }
        field(5; "Record"; Text[250])
        {
            Caption = 'Record';
        }
        field(6; "Field Name"; Text[80])
        {
            Caption = 'Field Name';
        }
        field(7; "Old Value"; Text[2048])
        {
            Caption = 'Old Value';
        }
        field(8; "New Value"; Text[2048])
        {
            Caption = 'New Value';
        }
        field(9; "Previewed At"; DateTime)
        {
            Caption = 'Previewed At';
        }
        field(10; "Previewed By"; Code[50])
        {
            Caption = 'Previewed By';
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Provider; "Provider ID") { }
    }
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Temporary projection of registered providers and their persisted state.</summary>
table 77782 "BJF MN Provider Buffer"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Provider';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; Selected; Boolean)
        {
            Caption = 'Selected';
        }
        field(3; Provider; Enum "BJF MN Config Provider")
        {
            Caption = 'Provider';
        }
        field(4; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
        }
        field(5; Name; Text[100])
        {
            Caption = 'Name';
        }
        field(6; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(7; "Defined Version"; Integer)
        {
            Caption = 'Defined Version';
        }
        field(8; "Applied Previously"; Boolean)
        {
            Caption = 'Applied Previously';
        }
        field(9; State; Enum "BJF MN Config State")
        {
            Caption = 'State';
        }
        field(10; "Applied Version"; Integer)
        {
            Caption = 'Applied Version';
        }
        field(11; "Applied At"; DateTime)
        {
            Caption = 'Applied At';
        }
        field(12; "Applied By"; Code[50])
        {
            Caption = 'Applied By';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}


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
        field(1; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
        }
        field(2; Provider; Enum "BJF MN Config Provider")
        {
            Caption = 'Provider';
        }
        field(3; Name; Text[100])
        {
            Caption = 'Name';
        }
        field(4; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(5; "Defined Version"; Integer)
        {
            Caption = 'Defined Version';
        }
        field(6; "Applied Previously"; Boolean)
        {
            Caption = 'Applied Previously';
        }
        field(7; State; Enum "BJF MN Config State")
        {
            Caption = 'State';
        }
        field(8; "Applied Version"; Integer)
        {
            Caption = 'Applied Version';
        }
        field(9; "Applied At"; DateTime)
        {
            Caption = 'Applied At';
        }
        field(10; "Applied By"; Code[50])
        {
            Caption = 'Applied By';
        }
    }

    keys
    {
        key(PK; "Provider ID")
        {
            Clustered = true;
        }
    }
}

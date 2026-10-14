namespace BradFullwood.MobileNAV.Configuration;

/// <summary>One row per Doctor run, from the page or the job queue. The Doctor page shows the newest one.</summary>
table 77811 "BJF Doctor Run Log"
{
    Access = Public;
    Caption = 'Doctor Run Log';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            AllowInCustomizations = Never;
        }
        field(2; "Run At"; DateTime)
        {
            Caption = 'Run At';
            Editable = false;
        }
        field(3; Source; Enum "BJF Doctor Run Source")
        {
            Caption = 'Source';
            Editable = false;
        }
        field(4; "Run By"; Code[50])
        {
            Caption = 'Run By';
            Editable = false;
        }
        field(5; Blockers; Integer)
        {
            Caption = 'Blockers';
            Editable = false;
        }
        field(6; Warnings; Integer)
        {
            Caption = 'Warnings';
            Editable = false;
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

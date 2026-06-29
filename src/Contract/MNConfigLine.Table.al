namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Validated intermediate representation produced by a configuration provider.</summary>
table 77780 "BJF MN Config Line"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Line';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; Operation; Enum "BJF MN Config Operation")
        {
            Caption = 'Operation';
        }
        field(3; "Page ID"; Integer)
        {
            Caption = 'Page ID';
        }
        field(4; "Service Name"; Text[100])
        {
            Caption = 'Service Name';
        }
        field(5; "Control Name"; Text[100])
        {
            Caption = 'Control Name';
        }
        field(6; Visible; Boolean)
        {
            Caption = 'Visible';
        }
        field(7; Editable; Boolean)
        {
            Caption = 'Editable';
        }
        field(8; "Display In Menu"; Boolean)
        {
            Caption = 'Display In Menu';
        }
        field(9; "Target Page ID"; Integer)
        {
            Caption = 'Target Page ID';
        }
        field(10; "Target Filter Field"; Text[100])
        {
            Caption = 'Target Filter Field';
        }
        field(11; "Source Field"; Text[100])
        {
            Caption = 'Source Field';
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

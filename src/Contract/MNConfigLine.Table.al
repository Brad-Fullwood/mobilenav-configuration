
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
        field(12; "Mobile Type"; Text[30])
        {
            Caption = 'Mobile Type';
        }
        field(13; "Function Name"; Text[50])
        {
            Caption = 'Function Name';
        }
        field(14; "Function Type"; Text[30])
        {
            Caption = 'Function Type';
        }
        field(15; "Validation Behavior"; Text[50])
        {
            Caption = 'Validation Behavior';
        }
        field(16; "Main Menu Action"; Text[30])
        {
            Caption = 'Main Menu Action';
        }
        field(17; "Auto Next Stage"; Boolean)
        {
            Caption = 'Auto Next Stage';
        }
        field(18; "Back-Next Visible"; Boolean)
        {
            Caption = 'Back-Next Visible';
        }
        field(19; "Stage Id"; Code[100])
        {
            Caption = 'Stage Id';
        }
        field(20; "Stage Enabled"; Boolean)
        {
            Caption = 'Stage Enabled';
        }
        field(21; "Stage Description"; Text[250])
        {
            Caption = 'Stage Description';
        }
        field(22; Importance; Text[30])
        {
            Caption = 'Importance';
        }
        field(23; Filterable; Boolean)
        {
            Caption = 'Filterable';
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

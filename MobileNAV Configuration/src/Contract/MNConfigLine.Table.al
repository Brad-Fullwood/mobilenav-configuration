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
        field(24; "Staging Behavior"; Text[30])
        {
            Caption = 'Staging Behavior';
        }
        field(25; "Stage Restart From"; Boolean)
        {
            Caption = 'Stage Restart From';
        }
        field(26; Profile; Code[30])
        {
            Caption = 'Profile';
            // Empty means every defined profile.
        }
        field(27; "Page Type"; Text[30])
        {
            Caption = 'Page Type';
            // Empty keeps MobileNAV's default for the page object.
        }
        field(28; "Function Codeunit ID"; Integer)
        {
            Caption = 'Function Codeunit ID';
            // Dialog pages only: the codeunit whose procedures the page's buttons run. Zero means
            // the buttons go through MobileNAV's page functions.
        }
        field(29; "Report Service Name"; Text[100])
        {
            Caption = 'Report Service Name';
            // The web service the function codeunit is published under.
        }
        field(30; "Group Code"; Code[20])
        {
            Caption = 'Group Code';
            // Controls: the field group (a MobileNAV category) the control sits in.
        }
        field(31; "Filter Type"; Text[30])
        {
            Caption = 'Filter Type';
            // MobileNAV FilterType member: FIELD, CONST or FILTER.
        }
        field(32; Comparison; Text[30])
        {
            Caption = 'Comparison';
            // MobileNAV Filter Comparsion Type member: Equal, NotEqual, Less, ..., Own, NotOwn.
        }
        field(33; "Filter Value"; Text[250])
        {
            Caption = 'Filter Value';
        }
        field(34; "Filter Scope"; Text[30])
        {
            Caption = 'Filter Scope';
            // MobileNAV Filter Scope member: Online, Offline or Both.
        }
        field(35; "Multi Select"; Boolean)
        {
            Caption = 'Multi Select';
        }
        field(36; "Auto Refresh On Open"; Boolean)
        {
            Caption = 'Auto Refresh On Open';
        }
        field(37; "Propagation Type"; Text[30])
        {
            Caption = 'Propagation Type';
        }
        field(38; "Action Type"; Text[30])
        {
            Caption = 'Action Type';
            // MobileNAV D. L. Action Type member.
        }
        field(39; Color; Text[30])
        {
            Caption = 'Color';
            // MobileNAV color area member.
        }
        field(40; Icon; Code[20])
        {
            Caption = 'Icon';
        }
        field(41; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
        }
        field(42; Disabled; Boolean)
        {
            Caption = 'Disabled';
        }
        field(43; "Search Type"; Text[30])
        {
            Caption = 'Search Type';
            // MobileNAV Search Type member: BeginMatch, Equal or AnyMatch.
        }
        field(44; "Own Filter Set"; Boolean)
        {
            Caption = 'Own Filter Set';
        }
        field(45; "View Type"; Text[30])
        {
            Caption = 'View Type';
            // MobileNAV View Type member: List or Map.
        }
        field(46; "Operation Type"; Text[30])
        {
            Caption = 'Operation Type';
        }
        field(47; "Related Code Field"; Text[100])
        {
            Caption = 'Related Code Field';
        }
        field(48; "Related Description Field"; Text[100])
        {
            Caption = 'Related Description Field';
        }
        field(49; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(50; Picture; Blob)
        {
            Caption = 'Picture';
        }
        field(51; "Picture Extension"; Text[10])
        {
            Caption = 'Picture Extension';
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

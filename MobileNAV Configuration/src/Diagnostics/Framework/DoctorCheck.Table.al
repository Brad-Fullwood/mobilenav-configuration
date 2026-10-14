namespace BradFullwood.MobileNAV.Configuration;

/// <summary>One row per check the Doctor can run. The registry codeunit fills it from the check type enum.</summary>
table 77813 "BJF Doctor Check"
{
    Access = Public;
    Caption = 'Doctor Check';
    DataClassification = SystemMetadata;
    DrillDownPageId = "BJF MN Doctor Checks";
    LookupPageId = "BJF MN Doctor Checks";

    fields
    {
        field(1; "Check Type"; Enum "BJF Diagnostic Check Type")
        {
            Caption = 'Check';
            Editable = false;
            ToolTip = 'Specifies the check. The Doctor runs it with the other checks.';
        }
        field(2; "Check Area"; Text[50])
        {
            Caption = 'Area';
            Editable = false;
            ToolTip = 'Specifies the part of MobileNAV or the app the check belongs to.';
        }
        field(3; "What It Checks"; Text[250])
        {
            Caption = 'What It Checks';
            Editable = false;
            ToolTip = 'Specifies what the check looks at.';
        }
    }

    keys
    {
        key(PK; "Check Type")
        {
            Clustered = true;
        }
    }
}

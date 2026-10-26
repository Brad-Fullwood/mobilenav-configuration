namespace BradFullwood.MobileNAV.Configuration;

/// <summary>The MobileNAV setup state of the company, for the mobilenavSetups API.</summary>
table 77703 "BJF MN Setup"
{
    Access = Internal;
    Caption = 'MobileNAV Setup';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; Id; Guid)
        {
            AllowInCustomizations = Never;
            Caption = 'Id';
        }
        field(2; "Has Licence"; Boolean)
        {
            Caption = 'Has Licence';
            ToolTip = 'Specifies whether a MobileNAV licence, trial or full, is installed.';
        }
        field(3; "Has Config"; Boolean)
        {
            Caption = 'Has Config';
            ToolTip = 'Specifies whether a MobileNAV configuration is imported in this company.';
        }
        field(4; "Licence Expiry"; Date)
        {
            Caption = 'Licence Expiry';
            ToolTip = 'Specifies when the installed MobileNAV licence expires. It is empty when the licence does not expire.';
        }
        field(5; "Licensed Devices"; Integer)
        {
            Caption = 'Licensed Devices';
            ToolTip = 'Specifies how many devices the installed MobileNAV licence allows.';
        }
        field(6; "Authentication Type"; Text[30])
        {
            Caption = 'Authentication Type';
            ToolTip = 'Specifies the device login type set on the MobileNAV general setup.';
        }
        field(7; "O365 Tenant Id"; Text[100])
        {
            Caption = 'O365 Tenant Id';
            ToolTip = 'Specifies the Microsoft Entra tenant id devices sign in to.';
        }
        field(8; "O365 App Id"; Text[100])
        {
            Caption = 'O365 App Id';
            ToolTip = 'Specifies the Microsoft Entra app registration id of the MobileNAV app.';
        }
        field(9; "O365 Redirect Uri"; Text[250])
        {
            Caption = 'O365 Redirect Uri';
            ToolTip = 'Specifies the redirect URI of the MobileNAV app registration.';
        }
        field(10; "O365 App Id Uri"; Text[250])
        {
            Caption = 'O365 App Id Uri';
            ToolTip = 'Specifies the application id URI of the MobileNAV app registration.';
        }
        field(11; "Setup Completed"; Boolean)
        {
            Caption = 'Setup Completed';
            ToolTip = 'Specifies whether the MobileNAV Setup Wizard is marked complete in Assisted Setup.';
        }
        field(12; "Http Allowed"; Boolean)
        {
            Caption = 'Http Allowed';
            ToolTip = 'Specifies whether HttpClient requests are allowed for the MobileNAV app.';
        }
        field(13; Log; Text[2048])
        {
            Caption = 'Log';
            ToolTip = 'Specifies what each setup step did or skipped.';
        }
        field(14; "Run Setup"; Boolean)
        {
            Caption = 'Run Setup';
            ToolTip = 'Specifies that the request runs the setup. A POST needs one field that differs from its default, or the platform never inserts the row and OnInsertRecord does not run.';
        }
    }

    keys
    {
        key(PK; Id)
        {
            Clustered = true;
        }
    }
}

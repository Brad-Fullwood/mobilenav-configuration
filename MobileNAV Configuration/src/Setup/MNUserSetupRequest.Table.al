namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A request to set up one Business Central user for MobileNAV, for the mobilenavUserSetupRequests API.</summary>
table 77704 "BJF MN User Setup Request"
{
    Access = Internal;
    Caption = 'MobileNAV User Setup Request';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; Id; Guid)
        {
            AllowInCustomizations = Never;
            Caption = 'Id';
        }
        field(2; "User Name"; Text[50])
        {
            Caption = 'User Name';
            ToolTip = 'Specifies the Business Central user name to set up for MobileNAV.';
        }
        field(3; "Profile Id"; Code[30])
        {
            Caption = 'Profile Id';
            ToolTip = 'Specifies the MobileNAV profile to assign, for example SALES ONLINE. It defaults to SALES ONLINE, the Setup Wizard default.';
        }
        field(4; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
            ToolTip = 'Specifies the language the user configuration is generated in. It defaults to the language MobileNAV picks for the user.';
        }
        field(5; Log; Text[2048])
        {
            Caption = 'Log';
            ToolTip = 'Specifies what each step did or skipped.';
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

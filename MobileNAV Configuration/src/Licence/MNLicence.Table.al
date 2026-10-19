namespace BradFullwood.MobileNAV.Configuration;

/// <summary>The installed MobileNAV licence, for the MobileNAV Licence page and the mobilenavLicences API.</summary>
table 77702 "BJF MN Licence"
{
    Access = Internal;
    Caption = 'MobileNAV Licence';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; Id; Guid)
        {
            AllowInCustomizations = Never;
            Caption = 'Id';
        }
        field(2; "Licence Id"; Text[50])
        {
            Caption = 'Licence Id';
            ToolTip = 'Specifies the id the installed MobileNAV licence was issued for. In Business Central online this is the Microsoft Entra tenant id.';
        }
        field(3; "Licensed Devices"; Integer)
        {
            Caption = 'Licensed Devices';
            ToolTip = 'Specifies how many devices the installed MobileNAV licence allows.';
        }
        field(4; "Assigned Devices"; Integer)
        {
            Caption = 'Assigned Devices';
            ToolTip = 'Specifies how many devices are active on the MobileNAV License Setup page.';
        }
        field(5; "Expiry Date"; Date)
        {
            Caption = 'Expiry Date';
            ToolTip = 'Specifies when the installed MobileNAV licence expires. It is empty when the licence does not expire.';
        }
        field(6; "Licence String"; Text[2048])
        {
            Caption = 'Licence String';
            ToolTip = 'Specifies the licence string to copy. Install it in another environment of the same tenant with Install licence string, or paste it into Change License on the MobileNAV License Setup page.';
        }
        field(7; "Tenant Licence Id"; Text[50])
        {
            Caption = 'This Tenant''s Licence Id';
            ToolTip = 'Specifies the licence id MobileNAV expects in this environment. A licence string is accepted only when it was issued for this id.';
        }
        field(8; "Licence Installed"; Boolean)
        {
            Caption = 'Licence Installed';
            ToolTip = 'Specifies whether a MobileNAV licence is installed in this environment.';
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

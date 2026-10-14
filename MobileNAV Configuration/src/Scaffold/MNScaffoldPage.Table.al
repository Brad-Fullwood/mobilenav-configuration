namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A MobileNAV page the New provider wizard offers, and whether the new provider uses it.</summary>
table 77721 "BJF MN Scaffold Page"
{
    Caption = 'MobileNAV Scaffold Page';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Page ID"; Integer)
        {
            Caption = 'Page ID';
            ToolTip = 'Specifies the ID of the MobileNAV page.';
        }
        field(2; "Page Name"; Text[30])
        {
            AllowInCustomizations = Never;
            Caption = 'Page Name';
            ToolTip = 'Specifies the name of the MobileNAV page.';
        }
        field(3; "Source Table ID"; Integer)
        {
            AllowInCustomizations = Never;
            Caption = 'Source Table ID';
            ToolTip = 'Specifies the table the page shows.';
        }
        field(4; "Source Table Name"; Text[30])
        {
            Caption = 'Source Table';
            ToolTip = 'Specifies the name of the table the page shows.';
        }
        field(5; Selected; Boolean)
        {
            Caption = 'Selected';
            ToolTip = 'Specifies whether the new provider extends this page.';
        }
        field(6; "Add Controls To"; Text[120])
        {
            Caption = 'Add Controls To';
            ToolTip = 'Specifies the group on the page that the page extension adds its controls to. The default is the page''s first group. Choose the assist button to pick another group of the page.';
        }
    }

    keys
    {
        key(PK; "Page ID")
        {
            Clustered = true;
        }
        key(Name; "Page Name")
        {
        }
        key(SelectedName; Selected, "Page Name")
        {
        }
    }
}

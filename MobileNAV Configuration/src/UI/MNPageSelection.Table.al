namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A MobileNAV page the provider generator can restate, with the user's choice.</summary>
table 77718 "BJF MN Page Selection"
{
    Access = Internal;
    Caption = 'MobileNAV Page Selection';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Service Name"; Text[100])
        {
            Caption = 'Service Name';
            NotBlank = true;
            ToolTip = 'Specifies the MobileNAV service name of the page.';
        }
        field(2; "Page Name"; Text[75])
        {
            AllowInCustomizations = Never;
            Caption = 'Page Name';
            ToolTip = 'Specifies the Business Central page behind the service.';
        }
        field(3; "Page ID"; Integer)
        {
            Caption = 'Page ID';
            ToolTip = 'Specifies the id of the Business Central page behind the service.';
        }
        field(4; "Own Page"; Boolean)
        {
            Caption = 'Own Page';
            ToolTip = 'Specifies whether the page belongs to an app rather than to MobileNAV. The generated provider publishes an own page.';
        }
        field(5; Selected; Boolean)
        {
            Caption = 'Selected';
            ToolTip = 'Specifies whether the generated provider restates this page.';
        }
    }

    keys
    {
        key(PK; "Service Name")
        {
            Clustered = true;
        }
    }
}

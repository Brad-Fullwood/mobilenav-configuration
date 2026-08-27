
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Temporary projection of registered providers and their persisted state.</summary>
table 77782 "BJF MN Provider Buffer"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Provider';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
            NotBlank = true;
            ToolTip = 'Specifies the stable identifier used for application tracking.';
        }
        field(2; Provider; Enum "BJF MN Config Provider")
        {
            AllowInCustomizations = Never;
            Caption = 'Provider';
        }
        field(3; Name; Text[100])
        {
            Caption = 'Name';
            ToolTip = 'Specifies the provider name.';
        }
        field(4; Description; Text[250])
        {
            Caption = 'Description';
            ToolTip = 'Specifies the configuration owned by this provider.';
        }
        field(5; "Defined Version"; Integer)
        {
            Caption = 'Defined Version';
            ToolTip = 'Specifies the version currently declared by the provider.';
        }
        field(6; "Applied Previously"; Boolean)
        {
            Caption = 'Applied Previously';
            ToolTip = 'Specifies whether this provider has been applied successfully before.';
        }
        field(7; State; Enum "BJF MN Config State")
        {
            Caption = 'State';
            ToolTip = 'Specifies whether the provider has never been applied, is current, or is outdated.';
        }
        field(8; "Applied Version"; Integer)
        {
            Caption = 'Applied Version';
            ToolTip = 'Specifies the last successfully applied provider version.';
        }
        field(9; "Applied At"; DateTime)
        {
            Caption = 'Applied At';
            ToolTip = 'Specifies when the provider was last applied successfully.';
        }
        field(10; "Applied By"; Code[50])
        {
            Caption = 'Applied By';
            ToolTip = 'Specifies who last applied the provider.';
        }
    }

    keys
    {
        key(PK; "Provider ID")
        {
            Clustered = true;
        }
    }
}

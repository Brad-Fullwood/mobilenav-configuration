#if BJF_MN_CONFIG_SOURCE
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Per-company application state for each stable provider id.</summary>
table 77781 "BJF MN Config Status"
{
    Caption = 'MobileNAV Configuration Status';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
        }
        field(2; "Provider Name"; Text[100])
        {
            Caption = 'Provider Name';
        }
        field(3; "Applied Version"; Integer)
        {
            Caption = 'Applied Version';
        }
        field(4; "Applied At"; DateTime)
        {
            Caption = 'Applied At';
        }
        field(5; "Applied By"; Code[50])
        {
            Caption = 'Applied By';
        }
        field(6; "Manually Outdated"; Boolean)
        {
            Caption = 'Manually Outdated';
        }
        field(7; "Outdated At"; DateTime)
        {
            Caption = 'Outdated At';
        }
        field(8; "Outdated By"; Code[50])
        {
            Caption = 'Outdated By';
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
#endif

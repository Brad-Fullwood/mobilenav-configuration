namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The provider details of the Generate MobileNAV Provider card. The card holds one temporary row, so the
/// details stay put while the user works in the page list.
/// </summary>
table 77800 "BJF MN Generator Header"
{
    Access = Internal;
    Caption = 'MobileNAV Provider Generator Header';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AllowInCustomizations = Never;
            Caption = 'Entry No.';
            ToolTip = 'Specifies the key of the one row the card holds.';
        }
        field(2; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
            ToolTip = 'Specifies the id the provider returns from GetId(), for example AUK-WAREHOUSE.';
        }
        field(3; "Object ID"; Integer)
        {
            BlankZero = true;
            Caption = 'Object ID';
            MinValue = 0;
            ToolTip = 'Specifies the id of the codeunit and the enum extension. Empty means 50100.';
        }
        field(4; "Object Name"; Text[30])
        {
            Caption = 'Object Name';
            ToolTip = 'Specifies the codeunit name, which also names the zip file. Empty means the provider id in title case followed by MN Provider.';
        }
        field(5; "Namespace Name"; Text[250])
        {
            Caption = 'Namespace';
            ToolTip = 'Specifies the namespace of the generated file. Empty writes no namespace line.';
        }
        field(6; "Include Profiles"; Boolean)
        {
            Caption = 'Include Profiles';
            ToolTip = 'Specifies whether the provider declares the per-profile overrides. Without them every control is declared for every profile.';
        }
        field(7; "Include Hidden Fields"; Boolean)
        {
            Caption = 'Include Hidden Fields';
            ToolTip = 'Specifies whether the provider declares the hidden fields of MobileNAV''s own pages as well.';
        }
        field(8; "Include All Captions"; Boolean)
        {
            Caption = 'Include All Captions';
            ToolTip = 'Specifies whether the provider declares control captions too. MobileNAV regenerates them from page metadata.';
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

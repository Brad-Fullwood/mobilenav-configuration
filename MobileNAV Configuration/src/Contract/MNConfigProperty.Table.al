namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// One MobileNAV Service Setup field a provider wants set to a value: on a page's Main row
/// (empty Control Name) or on a control's field row. The many one-field page and control
/// settings (toolbar buttons, list limit, quick edit, decimal places, ...) travel this way,
/// and one writer, one check and one fix serve them all.
/// </summary>
table 77783 "BJF MN Config Property"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Property';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Page ID"; Integer)
        {
            Caption = 'Page ID';
        }
        field(3; "Control Name"; Text[100])
        {
            Caption = 'Control Name';
            // Empty targets the page's Main row.
        }
        field(4; "Field No."; Integer)
        {
            Caption = 'Field No.';
            // Field number on MobileNAV Service Setup.
        }
        field(5; Value; Text[250])
        {
            Caption = 'Value';
            // Option members by name; booleans and numbers in XML format (Format(..., 0, 9)).
        }
        field(6; "Value Kind"; Enum "BJF MN Property Value")
        {
            Caption = 'Value Kind';
        }
        field(7; Validate; Boolean)
        {
            Caption = 'Validate';
            // Whether the writer runs the field's OnValidate; off for fields whose trigger
            // misbehaves in an unattended apply.
        }
        field(8; Setting; Text[50])
        {
            Caption = 'Setting';
            // The builder verb that produced the property, for messages.
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

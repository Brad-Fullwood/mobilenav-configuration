namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// A field or a button the New provider wizard offers on a MobileNAV page. Field rows come from
/// the page's controls and its source table's fields. Button rows are typed in by the user.
/// </summary>
table 77722 "BJF MN Field Pick"
{
    Caption = 'MobileNAV Field Pick';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Line No."; Integer)
        {
            AllowInCustomizations = Never;
            Caption = 'Line No.';
            ToolTip = 'Specifies the order of the row.';
        }
        field(2; "Page ID"; Integer)
        {
            AllowInCustomizations = Never;
            Caption = 'Page ID';
            ToolTip = 'Specifies the ID of the MobileNAV page.';
        }
        field(3; "Page Name"; Text[30])
        {
            Caption = 'Page';
            ToolTip = 'Specifies the MobileNAV page.';
        }
        field(4; "Is Button"; Boolean)
        {
            AllowInCustomizations = Never;
            Caption = 'Is Button';
            ToolTip = 'Specifies whether the row is a device button rather than a field.';
        }
        field(5; "Field No."; Integer)
        {
            AllowInCustomizations = Never;
            Caption = 'Field No.';
            ToolTip = 'Specifies the number of the source table field, or 0 for a page control that is not bound to a table field.';
        }
        field(6; "Field Name"; Text[30])
        {
            Caption = 'Field Name';
            ToolTip = 'Specifies the name of the source table field.';
        }
        field(7; "Control Name"; Text[120])
        {
            Caption = 'Control Name';
            ToolTip = 'Specifies the control name the provider declares. For a field already on the page it is the page''s own control. For a new field or a button it is the prefix followed by the name.';
        }
        field(8; Caption; Text[80])
        {
            Caption = 'Caption';
            ToolTip = 'Specifies the field caption, or the text the device shows on the button.';
        }
        field(9; "On Page"; Boolean)
        {
            Caption = 'On Page';
            ToolTip = 'Specifies whether the page already has a control for the field. When it does not, the page extension adds one.';
        }
        field(10; Selected; Boolean)
        {
            Caption = 'Selected';
            ToolTip = 'Specifies whether the new provider declares this field.';
        }
        field(11; Editable; Boolean)
        {
            Caption = 'Editable';
            ToolTip = 'Specifies whether the device user can change the field.';

            trigger OnValidate()
            begin
                if Rec.Editable then
                    Rec.Validate(Selected, true);
            end;
        }
        field(12; Filterable; Boolean)
        {
            Caption = 'Filterable';
            ToolTip = 'Specifies whether the device user can filter the page on the field.';

            trigger OnValidate()
            begin
                if Rec.Filterable then
                    Rec.Validate(Selected, true);
            end;
        }
    }

    keys
    {
        key(PK; "Line No.")
        {
            Clustered = true;
        }
        key(PageOrder; "Page ID", "Is Button", "Line No.")
        {
        }
    }
}

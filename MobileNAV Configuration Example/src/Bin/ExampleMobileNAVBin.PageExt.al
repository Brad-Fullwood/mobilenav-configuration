namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Adds a button and a field control to MobileNAV's own bin page. The button is a placeholder
/// control, as on the item page. The field control is the hidden field that carries colours,
/// toasts and dialogs to the device. These lines are all the wiring it needs.
/// </summary>
pageextension 50101 "Example MobileNAV Bin" extends "MobileNAV Bin"
{
    layout
    {
        addlast(Group)
        {
            field(ExampleBinItems; '')
            {
                ApplicationArea = All;
                Caption = 'Items in Bin';
                ToolTip = 'Specifies the device button that tells the user how many items the bin holds. The provider declares it.';
            }
            field(FieldControl; FieldControlText)
            {
                ApplicationArea = All;
                Caption = 'FieldControl';
                ToolTip = 'Specifies the MobileNAV field control value. Not for use in the client.';
                Visible = false;

                trigger OnValidate()
                begin
                    FieldControl.Answer(Page::"MobileNAV Bin", Rec, FieldControlText);
                    if Rec.Find() then; // Reread the record the handlers may have changed. A deleted record needs nothing more.
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FieldControlText := FieldControl.Calculate(Page::"MobileNAV Bin", Rec);
    end;

    var
        FieldControl: Codeunit "BJF MN Field Control";
        FieldControlText: Text;
}

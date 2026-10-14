namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The fields the New provider wizard offers on one MobileNAV page: the page's own controls first,
/// then the source table fields that are not on the page yet.
/// </summary>
page 77723 "BJF MN Field Pick Part"
{
    ApplicationArea = All;
    Caption = 'Fields';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = ListPart;
    SourceTable = "BJF MN Field Pick";
    SourceTableTemporary = true;
    SourceTableView = sorting("Page ID", "Is Button", "Line No.");

    layout
    {
        area(Content)
        {
            repeater(Fields)
            {
                field(Selected; Rec.Selected)
                {
                }
                field("Control Name"; Rec."Control Name")
                {
                    Editable = false;
                }
                field("Field Name"; Rec."Field Name")
                {
                    Editable = false;
                }
                field(Caption; Rec.Caption)
                {
                    Editable = false;
                }
                field("On Page"; Rec."On Page")
                {
                    Editable = false;
                }
                field(Editable; Rec.Editable)
                {
                }
                field(Filterable; Rec.Filterable)
                {
                }
                field("Page Name"; Rec."Page Name")
                {
                    Editable = false;
                    Visible = false;
                }
            }
        }
    }

    /// <summary>Shows the wizard's field rows. Edits go straight to the wizard's rows.</summary>
    /// <param name="TempFieldPick">The wizard's field and button rows.</param>
    procedure SetRows(var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        Rec.Copy(TempFieldPick, true);
    end;

    /// <summary>Shows the field rows of one page.</summary>
    /// <param name="PageId">The MobileNAV page.</param>
    procedure ShowPage(PageId: Integer)
    begin
        Rec.FilterGroup(2);
        Rec.SetRange("Page ID", PageId);
        Rec.SetRange("Is Button", false);
        Rec.FilterGroup(0);
        CurrPage.Update(false);
    end;
}

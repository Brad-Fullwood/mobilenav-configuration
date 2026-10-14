namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// The MobileNAV pages the Generate MobileNAV Provider card offers. The user selects the pages the provider restates.
/// The rows are shared with the card, which reads the selected rows when it downloads.
/// </summary>
page 77801 "BJF MN Page Selection Part"
{
    ApplicationArea = All;
    Caption = 'MobileNAV Pages';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = ListPart;
    Permissions = tabledata AllObjWithCaption = r;
    SourceTable = "BJF MN Page Selection";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            group(SearchGroup)
            {
                ShowCaption = false;

                field(SearchField; this.SearchText)
                {
                    Caption = 'Search';
                    ToolTip = 'Specifies the text to find. The list shows the pages whose name, caption or page ID contains it.';

                    trigger OnValidate()
                    begin
                        this.ApplySearch();
                    end;
                }
            }
            repeater(Pages)
            {
                field(Selected; Rec.Selected)
                {
                }
                field("Service Name"; Rec."Service Name")
                {
                    Editable = false;
                }
                field(PageCaptionField; this.RowPageCaption)
                {
                    Caption = 'Page';
                    Editable = false;
                    ToolTip = 'Specifies the caption of the Business Central page behind the service.';
                }
                field("Page ID"; Rec."Page ID")
                {
                    Editable = false;
                }
                field("Own Page"; Rec."Own Page")
                {
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.RowPageCaption := this.CaptionOfPage(Rec."Page ID", Rec."Page Name");
    end;

    /// <summary>Shows the card's page rows. Edits go straight to the card's rows.</summary>
    /// <param name="TempPageSelection">The card's page rows.</param>
    internal procedure SetPages(var TempPageSelection: Record "BJF MN Page Selection" temporary)
    begin
        Rec.Copy(TempPageSelection, true);
        CurrPage.Update(false);
    end;

    /// <summary>Returns the service names of the rows the user selected.</summary>
    /// <param name="ServiceNames">Receives the service names. Cleared first.</param>
    procedure SelectedServiceNames(var ServiceNames: List of [Text])
    var
        TempSelected: Record "BJF MN Page Selection" temporary;
    begin
        Clear(ServiceNames);
        TempSelected.Copy(Rec, true);
        TempSelected.Reset();
        TempSelected.SetRange(Selected, true);
        if TempSelected.FindSet() then
            repeat
                ServiceNames.Add(TempSelected."Service Name");
            until TempSelected.Next() = 0;
    end;

    /// <summary>
    /// Shows the pages whose name, caption or page ID contains the search text, the way a list search does. An
    /// empty search shows every page.
    /// </summary>
    local procedure ApplySearch()
    var
        Needle: Text;
    begin
        Needle := LowerCase(this.SearchText);
        Rec.MarkedOnly(false);
        Rec.ClearMarks();
        if Needle <> '' then begin
            if Rec.FindSet() then
                repeat
                    Rec.Mark(this.PageMatches(Rec."Page ID", Rec."Page Name", Needle));
                until Rec.Next() = 0;
            Rec.MarkedOnly(true);
        end;
        CurrPage.Update(false);
    end;

    local procedure PageMatches(PageId: Integer; PageName: Text; Needle: Text): Boolean
    begin
        exit((StrPos(LowerCase(PageName), Needle) > 0) or (StrPos(LowerCase(this.CaptionOfPage(PageId, PageName)), Needle) > 0) or (StrPos(Format(PageId), Needle) > 0));
    end;

    /// <summary>Returns the caption of a Business Central page, as the user sees it.</summary>
    /// <param name="PageId">The page id.</param>
    /// <param name="FallbackName">The name to show when the page has no caption.</param>
    /// <returns>The page caption.</returns>
    local procedure CaptionOfPage(PageId: Integer; FallbackName: Text): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        AllObjWithCaption.SetLoadFields("Object Caption");
        if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Page, PageId) then
            if AllObjWithCaption."Object Caption" <> '' then
                exit(AllObjWithCaption."Object Caption");
        exit(FallbackName);
    end;

    var
        RowPageCaption: Text;
        SearchText: Text[100];
}

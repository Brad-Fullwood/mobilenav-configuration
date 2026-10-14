namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>The MobileNAV pages the New provider wizard offers. The user selects the pages the provider extends.</summary>
page 77722 "BJF MN Scaffold Pages Part"
{
    ApplicationArea = All;
    Caption = 'MobileNAV Pages';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = ListPart;
    SourceTable = "BJF MN Scaffold Page";
    SourceTableTemporary = true;
    SourceTableView = sorting("Page Name");

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
                field(PageCaptionField; this.RowPageCaption)
                {
                    Caption = 'Page';
                    Editable = false;
                    ToolTip = 'Specifies the caption of the Business Central page.';
                }
                field("Page ID"; Rec."Page ID")
                {
                    Editable = false;
                }
                field("Source Table Name"; Rec."Source Table Name")
                {
                    Editable = false;
                }
                field("Add Controls To"; Rec."Add Controls To")
                {
                    ToolTip = 'Specifies the group on the page that the page extension adds its controls to. Choose the assist button to pick one of the page''s groups.';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(this.ChooseGroup(Text));
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.RowPageCaption := this.CaptionOfPage(Rec."Page ID", Rec."Page Name");
    end;

    /// <summary>Shows the wizard's page rows. Edits go straight to the wizard's rows.</summary>
    /// <param name="TempScaffoldPage">The wizard's page rows.</param>
    procedure SetPages(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary)
    begin
        Rec.Copy(TempScaffoldPage, true);
        Rec.SetCurrentKey("Page Name");
        CurrPage.Update(false);
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

    /// <summary>
    /// Offers the groups of the row's page. A page that is not in the group list keeps free text: the lookup
    /// does nothing and the user types the group.
    /// </summary>
    /// <param name="GroupName">Receives the group the user picked.</param>
    /// <returns>True when the user picked a group.</returns>
    local procedure ChooseGroup(var GroupName: Text): Boolean
    var
        GroupNames: List of [Text];
        Captions: List of [Text];
        Choice: Integer;
    begin
        if not this.ScaffoldWriter.PageGroups(Rec."Page ID", GroupNames, Captions) then
            exit(false);
        Choice := StrMenu(this.GroupMenu(GroupNames, Captions));
        if Choice = 0 then
            exit(false);
        GroupName := GroupNames.Get(Choice);
        exit(true);
    end;

    /// <summary>Returns the menu of the groups: each name, with its caption when the caption adds to it.</summary>
    /// <param name="GroupNames">The group names.</param>
    /// <param name="Captions">The captions, one per name.</param>
    /// <returns>The options, separated by commas.</returns>
    local procedure GroupMenu(GroupNames: List of [Text]; Captions: List of [Text]): Text
    var
        Menu: Text;
        MenuItem: Text;
        Index: Integer;
    begin
        for Index := 1 to GroupNames.Count() do begin
            MenuItem := GroupNames.Get(Index);
            // StrMenu splits its options at commas, so a caption with a comma stays out of the menu.
            if (Captions.Get(Index) <> '') and (Captions.Get(Index) <> MenuItem) and (StrPos(Captions.Get(Index), ',') = 0) then
                MenuItem := StrSubstNo(this.GroupWithCaptionTok, MenuItem, Captions.Get(Index));
            if Menu <> '' then
                Menu += ',';
            Menu += MenuItem;
        end;
        exit(Menu);
    end;

    var
        ScaffoldWriter: Codeunit "BJF MN Scaffold Writer";
        RowPageCaption: Text;
        SearchText: Text[100];
        GroupWithCaptionTok: Label '%1 (%2)', Locked = true;
}

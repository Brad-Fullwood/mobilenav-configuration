namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The device buttons the New provider wizard declares. Each row is a page, a caption and a
/// control name. The page extension adds a placeholder control with that name and the handler
/// codeunit answers the tap.
/// </summary>
page 77724 "BJF MN Button Pick Part"
{
    ApplicationArea = All;
    AutoSplitKey = false;
    Caption = 'Buttons';
    DelayedInsert = true;
    PageType = ListPart;
    SourceTable = "BJF MN Field Pick";
    SourceTableTemporary = true;
    SourceTableView = sorting("Page ID", "Is Button", "Line No.");

    layout
    {
        area(Content)
        {
            repeater(Buttons)
            {
                field("Page Name"; Rec."Page Name")
                {
                    ShowMandatory = true;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        PageName: Text;
                    begin
                        PageName := this.ChoosePage();
                        if PageName = '' then
                            exit(false);
                        Text := PageName;
                        exit(true);
                    end;

                    trigger OnValidate()
                    begin
                        this.ValidatePageName();
                    end;
                }
                field(Caption; Rec.Caption)
                {
                    ShowMandatory = true;

                    trigger OnValidate()
                    begin
                        if (Rec."Control Name" = '') or (Rec."Control Name" = this.ControlNameFor(xRec.Caption)) then
                            Rec.Validate("Control Name", CopyStr(this.ControlNameFor(Rec.Caption), 1, MaxStrLen(Rec."Control Name")));
                    end;
                }
                field("Control Name"; Rec."Control Name")
                {
                }
            }
        }
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    var
        TempLastFieldPick: Record "BJF MN Field Pick" temporary;
    begin
        TempLastFieldPick.Copy(Rec, true);
        TempLastFieldPick.Reset();
        if TempLastFieldPick.FindLast() then
            Rec.Validate("Line No.", TempLastFieldPick."Line No." + 10000)
        else
            Rec.Validate("Line No.", 10000);
        Rec.Validate("Is Button", true);
        Rec.Validate(Selected, true);
        if this.TempScaffoldPage.Count() = 1 then
            if this.TempScaffoldPage.FindFirst() then begin
                Rec.Validate("Page ID", this.TempScaffoldPage."Page ID");
                Rec.Validate("Page Name", this.TempScaffoldPage."Page Name");
            end;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        if Rec."Page ID" = 0 then
            Error(this.PageRequiredErr);
        exit(true);
    end;

    /// <summary>Shows the wizard's button rows and offers the selected pages. Edits go straight to the wizard's rows.</summary>
    /// <param name="TempFieldPick">The wizard's field and button rows.</param>
    /// <param name="TempSelectedPage">The wizard's page rows.</param>
    /// <param name="NewPrefix">The prefix new control names start with.</param>
    procedure SetRows(var TempFieldPick: Record "BJF MN Field Pick" temporary; var TempSelectedPage: Record "BJF MN Scaffold Page" temporary; NewPrefix: Text)
    begin
        Rec.Copy(TempFieldPick, true);
        Rec.FilterGroup(2);
        Rec.SetRange("Is Button", true);
        Rec.FilterGroup(0);
        this.TempScaffoldPage.Copy(TempSelectedPage, true);
        this.TempScaffoldPage.SetCurrentKey(Selected, "Page Name");
        this.TempScaffoldPage.SetRange(Selected, true);
        this.Prefix := NewPrefix;
        CurrPage.Update(false);
    end;

    local procedure ChoosePage(): Text
    var
        PageNames: List of [Text];
        Choice: Integer;
    begin
        PageNames := this.SelectedPageNames();
        Choice := StrMenu(this.PageMenu(PageNames));
        if Choice = 0 then
            exit('');
        exit(PageNames.Get(Choice));
    end;

    local procedure ValidatePageName()
    begin
        if Rec."Page Name" = '' then begin
            Rec.Validate("Page ID", 0);
            exit;
        end;
        this.TempScaffoldPage.SetRange("Page Name", Rec."Page Name");
        if not this.TempScaffoldPage.FindFirst() then begin
            this.TempScaffoldPage.SetRange("Page Name");
            Error(this.PageNotSelectedErr, Rec."Page Name");
        end;
        this.TempScaffoldPage.SetRange("Page Name");
        Rec.Validate("Page ID", this.TempScaffoldPage."Page ID");
    end;

    local procedure SelectedPageNames(): List of [Text]
    var
        PageNames: List of [Text];
    begin
        if this.TempScaffoldPage.FindSet() then
            repeat
                PageNames.Add(this.TempScaffoldPage."Page Name");
            until this.TempScaffoldPage.Next() = 0;
        exit(PageNames);
    end;

    local procedure PageMenu(PageNames: List of [Text]): Text
    var
        Menu: Text;
        PageName: Text;
    begin
        foreach PageName in PageNames do begin
            if Menu <> '' then
                Menu += ',';
            Menu += PageName;
        end;
        exit(Menu);
    end;

    local procedure ControlNameFor(ButtonCaption: Text): Text
    begin
        if ButtonCaption = '' then
            exit('');
        exit(this.ScaffoldWriter.NewControlName(this.Prefix, ButtonCaption));
    end;

    var
        TempScaffoldPage: Record "BJF MN Scaffold Page" temporary;
        ScaffoldWriter: Codeunit "BJF MN Scaffold Writer";
        Prefix: Text;
        PageRequiredErr: Label 'Choose the page the button belongs to.';
        PageNotSelectedErr: Label '%1 is not one of the selected pages.', Comment = '%1 = page name';
}

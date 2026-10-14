namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Checks the files the New provider wizard writes, through "BJF MN Scaffold Writer". The input is
/// one page with one new field and one button. Rendering reads no metadata, so the test needs no
/// MobileNAV data.
/// </summary>
codeunit 50152 "New Provider Scaffold Test"
{
    Subtype = Test;
    Access = Internal;

    /// <summary>The provider declares the button, and the page extension adds its placeholder and the new field.</summary>
    [Test]
    procedure RendersButtonAndPlaceholders()
    var
        TempScaffoldPage: Record "BJF MN Scaffold Page" temporary;
        TempFieldPick: Record "BJF MN Field Pick" temporary;
        ScaffoldWriter: Codeunit "BJF MN Scaffold Writer";
        FilePaths: List of [Text];
        FileTexts: List of [Text];
        ProviderText: Text;
        PageExtensionText: Text;
        HandlerText: Text;
    begin
        // [GIVEN] The MobileNAV Item page with the new field Notes and the button Flag
        this.AddPage(TempScaffoldPage);
        this.AddField(TempFieldPick);
        this.AddButton(TempFieldPick);
        ScaffoldWriter.SetAppDetails(this.PrefixTok, this.NamespaceTok, this.PublisherTok, this.AppNameTok, 50100);
        ScaffoldWriter.SetProvider('', '', '');

        // [WHEN] The files are rendered
        ScaffoldWriter.Render(TempScaffoldPage, TempFieldPick, FilePaths, FileTexts);

        // [THEN] The provider declares the field and the button, the page extension adds both controls, and the handler answers the button
        ProviderText := this.FileText(FilePaths, FileTexts, this.ProviderPathTok);
        PageExtensionText := this.FileText(FilePaths, FileTexts, this.PageExtensionPathTok);
        HandlerText := this.FileText(FilePaths, FileTexts, this.HandlerPathTok);
        this.AssertContains(ProviderText, this.ButtonLineTok, this.ProviderPathTok);
        this.AssertContains(ProviderText, this.FieldLineTok, this.ProviderPathTok);
        this.AssertContains(PageExtensionText, this.ButtonPlaceholderTok, this.PageExtensionPathTok);
        this.AssertContains(PageExtensionText, this.FieldControlTok, this.PageExtensionPathTok);
        this.AssertContains(PageExtensionText, this.AnchorTok, this.PageExtensionPathTok);
        this.AssertContains(HandlerText, this.HandlerLabelTok, this.HandlerPathTok);
    end;

    local procedure AddPage(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary)
    begin
        TempScaffoldPage.Init();
        TempScaffoldPage.Validate("Page ID", this.PageId());
        TempScaffoldPage.Validate("Page Name", this.PageNameTok);
        TempScaffoldPage.Validate(Selected, true);
        TempScaffoldPage.Validate("Add Controls To", this.GroupTok);
        TempScaffoldPage.Insert(false);
    end;

    local procedure AddField(var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        TempFieldPick.Init();
        TempFieldPick.Validate("Line No.", 10000);
        TempFieldPick.Validate("Page ID", this.PageId());
        TempFieldPick.Validate("Page Name", this.PageNameTok);
        TempFieldPick.Validate("Field Name", this.FieldNameTok);
        TempFieldPick.Validate("On Page", false);
        TempFieldPick.Validate(Editable, true);
        TempFieldPick.Insert(false);
    end;

    local procedure AddButton(var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        TempFieldPick.Init();
        TempFieldPick.Validate("Line No.", 20000);
        TempFieldPick.Validate("Page ID", this.PageId());
        TempFieldPick.Validate("Page Name", this.PageNameTok);
        TempFieldPick.Validate("Is Button", true);
        TempFieldPick.Validate(Caption, this.ButtonCaptionTok);
        TempFieldPick.Insert(false);
    end;

    /// <summary>Any page number. Rendering does not look the page up.</summary>
    /// <returns>The page number.</returns>
    local procedure PageId(): Integer
    begin
        exit(42012901);
    end;

    local procedure FileText(FilePaths: List of [Text]; FileTexts: List of [Text]; FilePath: Text): Text
    var
        FileIndex: Integer;
    begin
        FileIndex := FilePaths.IndexOf(FilePath);
        if FileIndex = 0 then
            Error(this.FileMissingErr, FilePath);
        exit(FileTexts.Get(FileIndex));
    end;

    local procedure AssertContains(Actual: Text; Expected: Text; FilePath: Text)
    begin
        if not Actual.Contains(Expected) then
            Error(this.TextMissingErr, FilePath, Expected, Actual);
    end;

    var
        PageNameTok: Label 'MobileNAV Item', Locked = true;
        GroupTok: Label 'General', Locked = true;
        FieldNameTok: Label 'Notes', Locked = true;
        ButtonCaptionTok: Label 'Flag', Locked = true;
        PrefixTok: Label 'TST', Locked = true;
        NamespaceTok: Label 'Test.Scaffold', Locked = true;
        PublisherTok: Label 'Test Publisher', Locked = true;
        AppNameTok: Label 'Test App', Locked = true;
        ProviderPathTok: Label 'src/Provider/TSTMNProvider.Codeunit.al', Locked = true;
        PageExtensionPathTok: Label 'src/Item/TSTMobileNAVItem.PageExt.al', Locked = true;
        HandlerPathTok: Label 'src/Provider/TSTMNHandler.Codeunit.al', Locked = true;
        ButtonLineTok: Label '            .Button(''TSTFlag'');', Locked = true;
        FieldLineTok: Label '            .Field(''TSTNotes'').Editable()', Locked = true;
        ButtonPlaceholderTok: Label '            field(TSTFlag; '''')', Locked = true;
        FieldControlTok: Label '            field(TSTNotes; Rec."Notes")', Locked = true;
        AnchorTok: Label '        addlast(General)', Locked = true;
        HandlerLabelTok: Label '        ItemFlagTok: Label ''TSTFlag'', Locked = true;', Locked = true;
        FileMissingErr: Label 'The scaffold has no file %1.', Comment = '%1 = file path';
        TextMissingErr: Label '%1 does not contain "%2". It reads:\%3', Comment = '%1 = file path, %2 = expected text, %3 = file text';
}

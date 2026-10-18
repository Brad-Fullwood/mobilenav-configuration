namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The example provider: everything the device shows for this app, declared in one place, level
/// by level from three lines to a full flow. Read it top to bottom. Each level works on its
/// own, and together they are one provider.
///
/// You do not write MobileNAV service names, profile rows, importance, page update flags,
/// companion web services, control ids, stage masks or relation rows here. The framework knows
/// those rules and applies them. The MobileNAV Doctor checks them afterwards and repairs them.
/// </summary>
codeunit 50100 "Example MN Provider" implements "BJF MN Config Provider"
{
    Access = Internal;

    procedure GetId(): Code[50]
    begin
        exit(this.ProviderIdTok);
    end;

    procedure GetName(): Text[100]
    begin
        exit(this.ProviderNameLbl);
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(this.ProviderDescriptionLbl);
    end;

    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        this.LevelOneThreeLines(Configuration);
        this.LevelTwoAButtonWithCodeBehind(Configuration);
        this.LevelThreeLookupsGroupsAndALayout(Configuration);
        this.LevelFourAPageOfYourOwn(Configuration);
        this.LevelFiveADialogWithYourOwnFunction(Configuration);
        this.LevelSixProfilesCategoriesAndPolish(Configuration);
        this.LevelSevenAButtonOnAnyMobileNAVPage(Configuration);
        this.LevelEightColourALine(Configuration);
        this.LevelNineAPageMobileNAVAlreadyLinksTo(Configuration);
        this.LevelTenASecondLineInTheList(Configuration);
        this.LevelTwelveAPhotoOnTheCount(Configuration);
        this.LevelThirteenASignatureOnTheCount(Configuration);
        this.LevelFourteenChildRows(Configuration);
        this.LevelFifteenAPrintToPdf(Configuration);
    end;

    /// <summary>
    /// Level 1. The device gets three fields on MobileNAV's own item page: the item category,
    /// the inventory (also offered in the filter pane) and an editable note.
    /// You did not have to know: that MobileNAV hides a new field behind "show more" unless its
    /// importance is set, that every profile needs its own row for the field, that the page only
    /// accepts changes with Page Update on, or that the page metadata must be refreshed.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelOneThreeLines(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Field('Item Category Code')
            .Field('Inventory').Filterable()
            .Field('ExampleNotes').Editable();
    end;

    /// <summary>
    /// Level 2. The device gets a Flag for Reorder button on the item page. A tap runs
    /// "Example Item Handler" in Business Central, which sets the flag, shows a toast and reloads
    /// the record. The page extension has a placeholder control named ExampleFlagReorder.
    /// You did not have to know: which MobileNAV function serves the item table, the companion
    /// web service the tap travels through, or MobileNAV's per-table events.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelTwoAButtonWithCodeBehind(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Field('ExampleReorderFlagged')
            .Button('ExampleFlagReorder');
    end;

    /// <summary>
    /// Level 3. The device gets a richer item page: a lookup that picks the default bin from the
    /// bin page, a group with a heading, the declared fields first, a list that shows inventory
    /// items only, a location filter in the filter pane, and two layout rules. The reorder button
    /// only shows while the item is out of stock, and the quantity turns red.
    /// You did not have to know: relation rows, group marker rows, MobileNAV's Order numbering,
    /// filter row numbering, or the dynamic layout tables.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelThreeLookupsGroupsAndALayout(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration
            .Category(this.ExampleCategoryTok, this.ExampleCategoryLbl)
            .Page(Page::"MobileNAV Item")
                .OrderAsDeclared()
                .Group(this.ExampleCategoryTok)
                    .Lookup('ExampleDefaultBin', Page::"MobileNAV Bin", 'Code', 'Description').RefreshOnOpen()
                .EndGroup()
                .PageFilterExpression('Type', 'Inventory')
                .FlowFilter('Location Filter')
                .Layout(this.InStockLayoutTok, this.InStockLayoutLbl)
                    .WhenValue('Inventory', Enum::"BJF MN Comparison"::Greater, '0')
                    .HidesField('ExampleFlagReorder')
                .Layout(this.NoStockColorLayoutTok, this.NoStockColorLayoutLbl)
                    .WhenValue('Inventory', Enum::"BJF MN Comparison"::LessOrEqual, '0')
                    .ValueColor('Inventory', Enum::"BJF MN Color"::CardMandatoryCaption);
    end;

    /// <summary>
    /// Level 4. The device gets a page of your own: a stock count sheet with a home menu tile.
    /// Each device user sees only their own counts, and the tile opens a new count. The sheet has
    /// a scan input, a bin lookup, a quantity with plus and minus buttons, and runs as a two-stage
    /// wizard that moves on by itself once the item is scanned. The item page gets a Stock Counts
    /// button that opens the sheet filtered to that item.
    /// You did not have to know: web service publishing, the Own filter that scopes a page to the
    /// device user, stage rows and stage masks, the category codes behind stage captions, or the
    /// profile Parent Page rows a link needs before the device draws it.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelFourAPageOfYourOwn(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Example Stock Count")
            .Publish(this.StockCountServiceTok)
            .ShowInMenu()
            .MineOnly('UserId')
            .MainMenuAction(Enum::"BJF MN Main Menu Action"::Create)
            .Insertable()
            .Scan('ItemNo').Validation(Enum::"BJF MN Validation Behavior"::ScanOrManualEntry)
            .Lookup('BinCode', Page::"MobileNAV Bin", 'Code', 'Description')
            .Field('CountedQuantity').Editable().Quantity(1)
            .Scan('LotNo')
            .Field('CountedAt')
            .Field('Posted').Hidden()
            .Wizard().AutoNext()
                .Stage(this.ScanStageTok, this.ScanStageLbl)
                    .Show('ItemNo')
                    .Show('BinCode')
                .Stage(this.CountStageTok, this.CountStageLbl)
                    .ShowReadOnly('ItemNo')
                    .Show('CountedQuantity')
                    .Show('LotNo');

        Configuration.Page(Page::"MobileNAV Item")
            .Link('ExampleStockCounts', Page::"Example Stock Count", 'ItemNo', 'No.');
    end;

    /// <summary>
    /// Level 5. The device gets a Quick Adjust dialog with a home menu tile: two inputs and a Post
    /// button that runs PostCount on "Example Count Functions". MobileNAV fills the procedure's
    /// parameters from the dialog controls with the same names. Use this route for a table
    /// MobileNAV has no function for.
    /// You did not have to know: report-type pages, function codeunit web services, or the Main
    /// row field that points the dialog at your codeunit.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelFiveADialogWithYourOwnFunction(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Example Quick Adjust")
            .PublishAsDialog(this.QuickAdjustServiceTok)
            .ShowInMenu()
            .Functions(Codeunit::"Example Count Functions", this.CountFunctionsServiceTok)
            .MineOnly('UserId')
            .MainMenuAction(Enum::"BJF MN Main Menu Action"::Create)
            .Insertable()
            .Scan('ItemNo')
            .Field('CountedQuantity').Editable()
            .Button('PostCount').FunctionName(this.PostCountTok);
    end;

    /// <summary>
    /// Level 6. The device gets the polish that usually needs a MobileNAV administrator: a
    /// profile of its own, both tiles under an Example menu heading with a German translation,
    /// the stock count and the item notes captioned in every language from the app's own translations, the card's navigate button hidden, an Out of stock
    /// saved filter on the item list, and Unit Price shown in every profile except the Example
    /// profile, so stock counters do not see prices.
    /// You did not have to know: master data rows, the caption table, saved filter row numbering,
    /// or profile field rows.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelSixProfilesCategoriesAndPolish(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration
            .Profile(this.ExampleProfileTok, this.ExampleProfileLbl)
            .CategoryTranslation(this.ExampleCategoryTok, this.GermanTok, this.ExampleCategoryDeuLbl)
            .Page(Page::"Example Stock Count")
                .MenuCategory(this.ExampleCategoryTok)
                .TranslatedCaptions()
                .HideButton(Enum::"BJF MN Toolbar Button"::CardNavigate)
            .Page(Page::"Example Quick Adjust")
                .MenuCategory(this.ExampleCategoryTok)
            .Page(Page::"MobileNAV Item")
                .Control('ExampleNotes').TranslatedCaptions()
                .SavedFilter(this.OutOfStockFilterLbl)
                    .Where('Inventory', Enum::"BJF MN Search Type"::Equal, '0')
                .Field('Unit Price').ExceptInProfile(this.ExampleProfileTok);
    end;

    /// <summary>
    /// Level 7. The device gets an Items in Bin button on MobileNAV's own bin page. A tap runs
    /// "Example Bin Handler", which counts the items with stock in the bin and shows a toast. The
    /// declaration is the same one line as on the item page, although MobileNAV has no page
    /// function for the Bin table.
    /// You did not have to know: that MobileNAV Page Functions serves 40 tables and Bin is not one
    /// of them, or that the framework registers its own companion codeunit,
    /// "BJF MN Table Functions", for the 78 other tables MobileNAV pages show.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelSevenAButtonOnAnyMobileNAVPage(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Bin")
            .Button('ExampleBinItems');
    end;

    /// <summary>
    /// Level 8. The device shows the first line of every bin that holds stock in green. The page
    /// extension adds a hidden FieldControl field wired to "BJF MN Field Control", and
    /// "Example Bin Handler" picks the colour. The same channel carries toasts, dialogs and
    /// refreshes.
    /// You did not have to know: MobileNAV's FieldControl mobile type, the encoded text it
    /// carries, or that the field must be hidden and editable at the same time.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelEightColourALine(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Bin")
            .FieldControl('FieldControl');
    end;

    /// <summary>
    /// Level 9. The device gets Zone Code in the filter pane of MobileNAV's bin content page. The
    /// declaration publishes that page without a tile and without a link of its own: MobileNAV's
    /// own pages already open it, and the administrator's tiles for it stay as they are.
    /// You did not have to know: that a page with no tile must be reachable from another page,
    /// that MobileNAV's own relations count for that, or that taking over the page's tiles would
    /// make MobileNAV delete the root rows of other pages.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelNineAPageMobileNAVAlreadyLinksTo(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV BinContent")
            .Publish(this.BinContentServiceTok)
            .Field('Zone Code').Filterable();
    end;

    /// <summary>
    /// Level 10. Every row of the item list gets a second line: "Inventory: 12, CHAIRS", the
    /// inventory with its caption, then the item category.
    /// You did not have to know: MobileNAV's Line Format table, that a line is one row per caption,
    /// value or separator, or that MobileNAV turns a misspelt field into plain text instead of
    /// failing.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelTenASecondLineInTheList(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .LineFormat(2)
                .ShowCaption('Inventory').Separator(': ').Show('Inventory')
                .Separator(', ').Show('Item Category Code')
            .EndLineFormat();
    end;


    /// <summary>
    /// Level 12. The stock count gets a Photo control: the device user takes a picture of the
    /// counted stock and sees it on the card. The picture is stored in the Photo Media field. The
    /// page has a placeholder control named Photo and a hidden Photo_Size field, and the procedure
    /// StockCountPhoto on "Example Stock Count Functions" reads and writes the picture through
    /// MobileNAV's HandleBase64EncodedData. The level adds a wizard stage for the photo, because
    /// on a wizard page a control shows only in the stages that show it.
    /// You did not have to know: that binding the Media field to the control gives "No file
    /// specified" on the device, that the device asks the size field whether there is a picture,
    /// MobileNAV's BLOB function shape with its EXP, IMP, DEL and LEN actions, or how a codeunit
    /// of yours becomes an operation of the page's web service.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelTwelveAPhotoOnTheCount(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Example Stock Count")
            .PageFunctions(Codeunit::"Example Stock Count Functions")
            .Button('Photo')
                .MobileType(Enum::"BJF MN Mobile Type"::Image)
                .FunctionName(this.PhotoFunctionTok)
                .FunctionType(Enum::"BJF MN Function Type"::BLOB)
            .Field('Photo_Size').Hidden()
            .Stage(this.PhotoStageTok, this.PhotoStageLbl)
                .Show('Photo');
    end;

    /// <summary>
    /// Level 13. The stock count gets a signature pad. The device user signs the count on the
    /// screen, and the signature is stored in the Signature Media field. The pattern is the photo's,
    /// with mobile type Signature: a placeholder control, a hidden Signature_Size field and the
    /// procedure StockCountSignature.
    /// You did not have to know: that a signature is an image control of another mobile type, or
    /// that a read-only signature draws only an icon on Android, so the control stays editable.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelThirteenASignatureOnTheCount(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Example Stock Count")
            .PageFunctions(Codeunit::"Example Stock Count Functions")
            .Button('Signature')
                .MobileType(Enum::"BJF MN Mobile Type"::Signature)
                .FunctionName(this.SignatureFunctionTok)
                .FunctionType(Enum::"BJF MN Function Type"::BLOB)
            .Field('Signature_Size').Hidden()
            .Stage(this.SignStageTok, this.SignStageLbl)
                .Show('Signature');
    end;

    /// <summary>
    /// Level 14. The stock count card gets a Lines button that opens the count's lines: the lot
    /// and quantity of each, from the "Example Stock Count Line" table. The lines page is a plain
    /// list page, published without a tile and reached only through the link, and it shows only
    /// the lines of the count that opened it.
    /// You did not have to know: that MobileNAV does not show list parts, so child rows are a
    /// page of their own, that a page without a tile must have a link or MobileNAV drops its
    /// profile rows, or the profile Parent Page rows that make the link drawn.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelFourteenChildRows(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Example Stock Count Lines")
            .Publish(this.StockCountLinesServiceTok)
            .FilterByParent()
            .Field('LotNo')
            .Field('Quantity');

        Configuration.Page(Page::"Example Stock Count")
            .Link('ExampleCountLines', Page::"Example Stock Count Lines", 'CountEntryNo', 'EntryNo')
            .Stage(this.LinesStageTok, this.LinesStageLbl)
                .Show('ExampleCountLines');
    end;

    /// <summary>
    /// Level 15. The stock count gets a Print button. A tap runs the "Example Stock Count" report
    /// for the count in Business Central, and the device opens the PDF. The procedure
    /// StockCountPrint saves the report as a PDF and returns it as base64.
    /// You did not have to know: that a file comes back through a function of type Generated
    /// BLOB, that mobile type PDF makes the device open it, or the result text MobileNAV wraps
    /// the file in.
    /// </summary>
    /// <param name="Configuration">The builder that collects the declarations.</param>
    local procedure LevelFifteenAPrintToPdf(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Example Stock Count")
            .PageFunctions(Codeunit::"Example Stock Count Functions")
            .Button('PrintCount')
                .MobileType(Enum::"BJF MN Mobile Type"::PDF)
                .FunctionName(this.PrintFunctionTok)
                .FunctionType(Enum::"BJF MN Function Type"::"Generated BLOB")
            .Stage(this.PrintStageTok, this.PrintStageLbl)
                .Show('PrintCount');
    end;

    var
        ProviderIdTok: Label 'EXAMPLE', Locked = true;
        ProviderNameLbl: Label 'MobileNAV Configuration Example', MaxLength = 100;
        ProviderDescriptionLbl: Label 'Item and bin pages, a stock count sheet and a quick adjust dialog, in fifteen levels: the example to copy into a customer app.', MaxLength = 250;
        ExampleCategoryTok: Label 'EXAMPLE', Locked = true;
        ExampleCategoryLbl: Label 'Example', MaxLength = 250;
        ExampleCategoryDeuLbl: Label 'Beispiel', MaxLength = 250;
        ExampleProfileTok: Label 'EXAMPLE', Locked = true;
        ExampleProfileLbl: Label 'Example profile', MaxLength = 250;
        StockCountServiceTok: Label 'MNExampleStockCount', Locked = true;
        QuickAdjustServiceTok: Label 'MNExampleQuickAdjust', Locked = true;
        CountFunctionsServiceTok: Label 'MNExampleCountFunctions', Locked = true;
        BinContentServiceTok: Label 'MNBinContent', Locked = true;
        PostCountTok: Label 'PostCount', Locked = true;
        InStockLayoutTok: Label 'INSTOCK', Locked = true;
        InStockLayoutLbl: Label 'Hide the reorder button while there is stock', MaxLength = 100;
        NoStockColorLayoutTok: Label 'NOSTOCK', Locked = true;
        NoStockColorLayoutLbl: Label 'Colour the quantity while out of stock', MaxLength = 100;
        ScanStageTok: Label 'EXAMPLE-SCAN', Locked = true;
        ScanStageLbl: Label 'Scan the item', MaxLength = 250;
        CountStageTok: Label 'EXAMPLE-COUNT', Locked = true;
        CountStageLbl: Label 'Count it', MaxLength = 250;
        GermanTok: Label 'DEU', Locked = true;
        OutOfStockFilterLbl: Label 'Out of stock', MaxLength = 100;
        StockCountLinesServiceTok: Label 'MNExampleStockCountLines', Locked = true;
        PhotoFunctionTok: Label 'StockCountPhoto', Locked = true;
        SignatureFunctionTok: Label 'StockCountSignature', Locked = true;
        PrintFunctionTok: Label 'StockCountPrint', Locked = true;
        PhotoStageTok: Label 'EXAMPLE-PHOTO', Locked = true;
        PhotoStageLbl: Label 'Take a photo', MaxLength = 250;
        SignStageTok: Label 'EXAMPLE-SIGN', Locked = true;
        SignStageLbl: Label 'Sign the count', MaxLength = 250;
        LinesStageTok: Label 'EXAMPLE-LINES', Locked = true;
        LinesStageLbl: Label 'Lines', MaxLength = 250;
        PrintStageTok: Label 'EXAMPLE-PRINT', Locked = true;
        PrintStageLbl: Label 'Print', MaxLength = 250;
}

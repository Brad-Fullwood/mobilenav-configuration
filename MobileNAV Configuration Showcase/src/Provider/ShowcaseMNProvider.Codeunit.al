namespace BradFullwood.MobileNAV.Showcase;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The showcase provider: everything the device shows for this app, declared in one place, in
/// six levels from three lines to a full flow. Read it top to bottom. Each level is a normal
/// provider on its own; together they are one.
///
/// What you never write here: MobileNAV service names, profile rows, importance, page update
/// flags, companion web services, control ids, stage masks, relation rows. The framework knows
/// those rules and applies them; the MobileNAV Doctor checks them afterwards and repairs them.
/// </summary>
codeunit 50100 "Showcase MN Provider" implements "BJF MN Config Provider"
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
    end;

    /// <summary>
    /// Level 1. Three fields on MobileNAV's own item page. That is the whole job: the fields
    /// become visible on every profile, in the card's main section, the page becomes updatable
    /// because one field is editable, and Inventory appears in the filter pane.
    /// </summary>
    local procedure LevelOneThreeLines(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Field('Item Category Code')
            .Field('Inventory').Filterable()
            .Field('ShowcaseNotes').Editable();
    end;

    /// <summary>
    /// Level 2. A button. The page extension has a placeholder control named
    /// ShowcaseFlagReorder; declaring it as a Button makes the device draw it and call
    /// Business Central when tapped. "Showcase Button Handler" answers the tap. The framework
    /// works out which MobileNAV function serves the item table and registers the web service
    /// the tap travels through.
    /// </summary>
    local procedure LevelTwoAButtonWithCodeBehind(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Field('ShowcaseReorderFlagged')
            .Button('ShowcaseFlagReorder');
    end;

    /// <summary>
    /// Level 3. The item page gets fancier without getting harder to read:
    /// a lookup that picks the default bin from the bin page, a group with a heading around
    /// the showcase fields, the declared fields first, a filter so the list only shows
    /// inventory items, a flow filter in the filter pane, and a layout rule that only offers
    /// the reorder button while the item is out of stock and colors the quantity red.
    /// </summary>
    local procedure LevelThreeLookupsGroupsAndALayout(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration
            .Category(this.ShowcaseCategoryTok, this.ShowcaseCategoryLbl)
            .Page(Page::"MobileNAV Item")
                .OrderAsDeclared()
                .Group(this.ShowcaseCategoryTok)
                    .Lookup('ShowcaseDefaultBin', Page::"MobileNAV Bin", 'Code', 'Description').RefreshOnOpen()
                .EndGroup()
                .PageFilterExpression('Type', 'Inventory')
                .FlowFilter('Location Filter')
                .Layout(this.OutOfStockLayoutTok, this.OutOfStockLayoutLbl)
                    .WhenValue('Inventory', Enum::"BJF MN Comparison"::Greater, '0')
                    .HidesField('ShowcaseFlagReorder')
                .Layout(this.NoStockColorLayoutTok, this.NoStockColorLayoutLbl)
                    .WhenValue('Inventory', Enum::"BJF MN Comparison"::LessOrEqual, '0')
                    .ValueColor('Inventory', Enum::"BJF MN Color"::CardMandatoryCaption);
    end;

    /// <summary>
    /// Level 4. A page of our own: the stock count sheet. Publish gives it a tile and a web
    /// service; MineOnly shows each device user only their own counts; the tile opens a new
    /// count. The controls are a scan input, a quantity with steppers and a lookup, and the
    /// whole thing runs as a two-stage wizard that moves on by itself once the item is scanned.
    /// </summary>
    local procedure LevelFourAPageOfYourOwn(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Showcase Stock Count")
            .Publish(this.StockCountServiceTok)
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
    end;

    /// <summary>
    /// Level 5. A dialog: inputs plus a button that runs code of ours. The page is published
    /// as a dialog, the codeunit is published as its function service, and the button names
    /// the procedure. MobileNAV fills the procedure's parameters from the controls with the
    /// same names. This is the route for a table MobileNAV has no page function for.
    /// </summary>
    local procedure LevelFiveADialogWithYourOwnFunction(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"Showcase Quick Adjust")
            .PublishAsDialog(this.QuickAdjustServiceTok)
            .Functions(Codeunit::"Showcase Count Functions", this.CountFunctionsServiceTok)
            .MineOnly('UserId')
            .MainMenuAction(Enum::"BJF MN Main Menu Action"::Create)
            .Insertable()
            .Scan('ItemNo')
            .Field('CountedQuantity').Editable()
            .Button('PostCount').FunctionName(this.PostCountTok);
    end;

    /// <summary>
    /// Level 6. Polish that usually needs an administrator: a profile of its own, the tiles
    /// under a menu heading, a caption per language, a saved filter the list offers, and one
    /// field kept off a profile. Each is one line; each is checked by the doctor.
    /// </summary>
    local procedure LevelSixProfilesCategoriesAndPolish(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration
            .Profile(this.ShowcaseProfileTok, this.ShowcaseProfileLbl)
            .CategoryTranslation(this.ShowcaseCategoryTok, this.GermanTok, this.ShowcaseCategoryDeuLbl)
            .Page(Page::"Showcase Stock Count")
                .MenuCategory(this.ShowcaseCategoryTok)
                .Caption(this.EnglishTok, this.StockCountCaptionLbl)
                .Caption(this.GermanTok, this.StockCountCaptionDeuLbl)
                .HideButton(Enum::"BJF MN Toolbar Button"::CardNavigate)
            .Page(Page::"Showcase Quick Adjust")
                .MenuCategory(this.ShowcaseCategoryTok)
            .Page(Page::"MobileNAV Item")
                .SavedFilter(this.OutOfStockFilterLbl)
                    .Where('Inventory', Enum::"BJF MN Search Type"::Equal, '0')
                .Field('Item Category Code').ExceptInProfile(this.ShowcaseProfileTok);
    end;

    var
        ProviderIdTok: Label 'SHOWCASE', Locked = true;
        ProviderNameLbl: Label 'MobileNAV Configuration Showcase', MaxLength = 100;
        ProviderDescriptionLbl: Label 'Six levels on the item page, a stock count sheet and a quick-adjust dialog: the reference for what a provider can declare.', MaxLength = 250;
        ShowcaseCategoryTok: Label 'SHOWCASE', Locked = true;
        ShowcaseCategoryLbl: Label 'Showcase', MaxLength = 250;
        ShowcaseCategoryDeuLbl: Label 'Vorführung', MaxLength = 250;
        ShowcaseProfileTok: Label 'SHOWCASE', Locked = true;
        ShowcaseProfileLbl: Label 'Showcase profile', MaxLength = 250;
        StockCountServiceTok: Label 'MNShowcaseStockCount', Locked = true;
        QuickAdjustServiceTok: Label 'MNShowcaseQuickAdjust', Locked = true;
        CountFunctionsServiceTok: Label 'MNShowcaseCountFunctions', Locked = true;
        PostCountTok: Label 'PostCount', Locked = true;
        OutOfStockLayoutTok: Label 'INSTOCK', Locked = true;
        OutOfStockLayoutLbl: Label 'Hide the reorder button while there is stock', MaxLength = 100;
        NoStockColorLayoutTok: Label 'NOSTOCK', Locked = true;
        NoStockColorLayoutLbl: Label 'Color the quantity while out of stock', MaxLength = 100;
        ScanStageTok: Label 'SCAN', Locked = true;
        ScanStageLbl: Label 'Scan the item', MaxLength = 250;
        CountStageTok: Label 'COUNT', Locked = true;
        CountStageLbl: Label 'Count it', MaxLength = 250;
        EnglishTok: Label 'ENU', Locked = true;
        GermanTok: Label 'DEU', Locked = true;
        StockCountCaptionLbl: Label 'Stock Count', MaxLength = 250;
        StockCountCaptionDeuLbl: Label 'Inventur', MaxLength = 250;
        OutOfStockFilterLbl: Label 'Out of stock', MaxLength = 100;
}

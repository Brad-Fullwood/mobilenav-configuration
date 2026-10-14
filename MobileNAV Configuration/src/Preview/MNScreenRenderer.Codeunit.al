namespace BradFullwood.MobileNAV.Configuration;

using System.Globalization;
using System.IO;
using System.Reflection;

/// <summary>
/// Draws the device pages a provider declares as one HTML document with inline CSS: a phone
/// frame per view, the list with its rows, filters and saved filters, the card with its
/// importance sections, groups, scan inputs, lookups and menu, one card per wizard stage, and
/// the layout rules. The provider's definition is laid over MobileNAV's live Service Setup rows
/// for the same pages, so the drawing shows what a device gets once the provider is applied.
/// The command line counterpart is mnconfig_screen.py in the mobilenav-config tool.
///
/// The controls of the page being drawn are kept in a temporary "BJF MN Config Line": Control
/// Name holds the name MobileNAV stores, Description the caption, Action Type how the control
/// is drawn (field, scan, lookup, button, ...), Service Name the page a link or lookup opens,
/// and Stage Id MobileNAV's stage mask of a live row.
/// </summary>
codeunit 77725 "BJF MN Screen Renderer"
{
    Access = Public;
    Permissions = tabledata "MobileNAV CaptionML Admin." = r,
        tabledata "MobileNAV Category Transl." = r,
        tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Service Setup" = r;

    /// <summary>Builds the HTML for a provider's device pages, with captions in one MobileNAV language.</summary>
    /// <param name="ProviderType">The provider to draw.</param>
    /// <param name="LanguageCode">MobileNAV language code for captions, for example ENU or DEU. Empty means ENU.</param>
    /// <returns>A complete HTML document with inline CSS. The screens are slides of one CSS carousel: slide 1 is the home screen, then one slide per declared page.</returns>
    procedure Render(ProviderType: Enum "BJF MN Config Provider"; LanguageCode: Code[10]): Text
    var
        Html: TextBuilder;
        Slides: TextBuilder;
        PageIds: List of [Integer];
        PageId: Integer;
        SlideNo: Integer;
        SlideCount: Integer;
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
    begin
        this.LoadTheme();
        this.ProviderCatalog.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        this.ProviderCatalog.BuildDefinition(ProviderType, this.TempDefinitionLine, this.TempDefinitionProperty);
        this.CaptionLanguage := LanguageCode;
        if this.CaptionLanguage = '' then
            this.CaptionLanguage := this.EnglishTok;
        this.ElementSeq := 0;
        PageIds := this.DeclaredPages();
        SlideCount := PageIds.Count() + 1;
        Html.Append(StrSubstNo(this.DocumentStartTok, this.Escape(StrSubstNo(this.DocumentTitleLbl, ProviderId)), this.Css() + this.DeckCss(SlideCount)));
        if PageIds.Count() = 0 then begin
            Html.Append(StrSubstNo(this.ErrorBoxTok, this.Escape(this.NoPagesLbl)));
            Html.Append(this.DocumentEndTok);
            exit(Html.ToText());
        end;
        this.CollectHome(PageIds);
        Slides.Append(this.HomeSlideHtml(1, SlideCount));
        SlideNo := 1;
        foreach PageId in PageIds do begin
            SlideNo += 1;
            this.AppendPage(Slides, PageId, SlideNo, SlideCount);
        end;
        Html.Append(this.DeckStartTok);
        for SlideNo := 1 to SlideCount do
            if SlideNo = 1 then
                Html.Append(StrSubstNo(this.RadioTok, SlideNo, this.CheckedAttrTok))
            else
                Html.Append(StrSubstNo(this.RadioTok, SlideNo, ''));
        Html.Append(this.ViewerStartTok);
        Html.Append(Slides.ToText());
        Html.Append(this.DivEndTok);
        Html.Append(this.DivEndTok);
        Html.Append(this.DocumentEndTok);
        exit(Html.ToText());
    end;

    /// <summary>The MobileNAV language code of the session language, for example ENU; ENU when the language has no code.</summary>
    /// <returns>The language code.</returns>
    procedure SessionLanguageCode(): Code[10]
    var
        Language: Record Language;
    begin
        Language.SetRange("Windows Language ID", GlobalLanguage());
        Language.SetLoadFields(Code);
        if Language.FindFirst() then
            exit(Language.Code);
        exit(this.EnglishTok);
    end;

    // ---- Pages --------------------------------------------------------------------------

    local procedure DeclaredPages(): List of [Integer]
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        TempLine.Copy(this.TempDefinitionLine, true);
        exit(TempLine.DeclaredPageIds());
    end;

    local procedure AppendPage(var Html: TextBuilder; PageId: Integer; SlideNo: Integer; SlideCount: Integer)
    begin
        this.LoadPage(PageId);
        Html.Append(this.SlideStart(SlideNo, SlideCount, this.CurrentTitle));
        Html.Append(StrSubstNo(this.SummaryTok, this.Escape(this.PageOverview())));
        Html.Append(this.ChangesHtml());
        Html.Append(this.PhonesStartTok);
        if not this.IsDialog() then
            Html.Append(this.ListView());
        this.AppendCardViews(Html);
        this.CloseCardSource();
        Html.Append(this.DivEndTok);
        Html.Append(this.SlideEndTok);
    end;

    /// <summary>Closes the card's source record once the page's cards are drawn, so the next page can open its own.</summary>
    local procedure CloseCardSource()
    begin
        this.HasCardRecord := false;
        if this.CardSource.Number() <> 0 then
            this.CardSource.Close();
    end;

    local procedure LoadPage(PageId: Integer)
    begin
        this.LoadMainValues(PageId);
        this.LoadCaptions();
        this.LoadSourceFields();
        this.LoadControls();
        this.LoadCardRecord();
        this.AddRuleChanges();
        this.LoadStages();
        this.CurrentTitle := this.PageCaption(PageId);
    end;

    /// <summary>Loads the Main row values of a page: the live row first, then what the provider declares for it.</summary>
    /// <param name="PageId">The page object ID.</param>
    local procedure LoadMainValues(PageId: Integer)
    var
        LiveMain: Record "MobileNAV Service Setup";
    begin
        this.CurrentPageId := PageId;
        this.CurrentServiceName := this.ServiceNameOf(PageId);
        this.HasLiveRows := this.ServiceLookup.FindMainRow(this.CurrentServiceName, LiveMain);
        this.LoadPageValues(LiveMain);
    end;

    /// <summary>The service MobileNAV has for the page, else the name the provider publishes it under.</summary>
    /// <param name="PageId">The page object ID.</param>
    /// <returns>The service name, or the page ID as text when the page has neither.</returns>
    local procedure ServiceNameOf(PageId: Integer): Text[100]
    var
        TempLine: Record "BJF MN Config Line" temporary;
        ServiceName: Text[100];
    begin
        ServiceName := this.ServiceLookup.GetServiceName(PageId);
        if ServiceName <> '' then
            exit(ServiceName);
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Published Page", PageId) then
            exit(TempLine."Service Name");
        exit(CopyStr(Format(PageId), 1, 100));
    end;

    /// <summary>The Main row values the drawing needs: the live row first, then what the provider declares.</summary>
    /// <param name="LiveMain">The live Main row, when HasLiveRows.</param>
    local procedure LoadPageValues(var LiveMain: Record "MobileNAV Service Setup")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
        MainRow: RecordRef;
        FieldNo: Integer;
    begin
        Clear(this.PageValues);
        if this.HasLiveRows then begin
            MainRow.GetTable(LiveMain);
            foreach FieldNo in this.PageFieldNos() do
                this.PageValues.Set(FieldNo, this.FieldText(MainRow.Field(FieldNo)));
        end;
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Published Page", this.CurrentPageId) then
            this.OverlayPublishedPage(TempLine);
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::Staging, this.CurrentPageId) then
            this.PageValues.Set(LiveMain.FieldNo("Auto Next Stage"), Format(TempLine."Auto Next Stage", 0, 9));

        TempProperty.Copy(this.TempDefinitionProperty, true);
        TempProperty.Reset();
        TempProperty.SetRange("Page ID", this.CurrentPageId);
        TempProperty.SetRange("Control Name", '');
        if TempProperty.FindSet() then
            repeat
                this.PageValues.Set(TempProperty."Field No.", TempProperty.Value);
            until TempProperty.Next() = 0;
    end;

    local procedure OverlayPublishedPage(PublishedLine: Record "BJF MN Config Line" temporary)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if PublishedLine."Page Type" <> '' then
            this.PageValues.Set(ServiceSetup.FieldNo("Page Type"), PublishedLine."Page Type");
        if PublishedLine."Main Menu Action" <> '' then
            this.PageValues.Set(ServiceSetup.FieldNo("Main Menu Action"), PublishedLine."Main Menu Action");
        if PublishedLine."Show In Menu" then
            this.PageValues.Set(ServiceSetup.FieldNo(DisplayInMenu), Format(true, 0, 9));
    end;

    local procedure PageFieldNos() FieldNos: List of [Integer]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        FieldNos.Add(ServiceSetup.FieldNo("Page Type"));
        FieldNos.Add(ServiceSetup.FieldNo("Page Insert"));
        FieldNos.Add(ServiceSetup.FieldNo(DisplayInMenu));
        FieldNos.Add(ServiceSetup.FieldNo(Category));
        FieldNos.Add(ServiceSetup.FieldNo("Auto Next Stage"));
        FieldNos.Add(ServiceSetup.FieldNo("Main Menu Action"));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnCardRefresh));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnCardNavigate));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnListSort));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnListFilter));
    end;

    local procedure PageValue(FieldNo: Integer): Text
    var
        Value: Text;
    begin
        if this.PageValues.Get(FieldNo, Value) then
            exit(Value);
        exit('');
    end;

    local procedure PageFlag(FieldNo: Integer): Boolean
    begin
        exit(this.PageValue(FieldNo) = Format(true, 0, 9));
    end;

    local procedure IsDialog(): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        exit(this.PageValue(ServiceSetup.FieldNo("Page Type")) = this.Vocabulary.ReportPageTypeName());
    end;

    /// <summary>A field value as the provider spells it: option member names, booleans and numbers in XML format.</summary>
    /// <param name="FieldReference">The field.</param>
    /// <returns>The value as text.</returns>
    local procedure FieldText(FieldReference: FieldRef): Text
    var
        Ordinal: Integer;
    begin
        if FieldReference.Type() <> FieldType::Option then
            exit(Format(FieldReference.Value(), 0, 9));
        Ordinal := FieldReference.Value();
        exit(SelectStr(Ordinal + 1, FieldReference.OptionMembers()).Trim());
    end;

    // ---- Captions -----------------------------------------------------------------------

    local procedure LoadCaptions()
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        Clear(this.DeclaredCaptions);
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::Caption, this.CurrentPageId) then
            repeat
                if (TempLine."Language Code" = this.CaptionLanguage) and (TempLine."Control Name" <> '') then
                    this.DeclaredCaptions.Set(this.NameKey(TempLine."Control Name"), TempLine.Description);
            until TempLine.Next() = 0;
        this.LoadMobileNAVCaptions();
        this.LoadMetadataCaptions();
    end;

    /// <summary>MobileNAV's captions of the page's controls in the caption language, by control ID.</summary>
    local procedure LoadMobileNAVCaptions()
    var
        CaptionAdmin: Record "MobileNAV CaptionML Admin.";
    begin
        Clear(this.MobileNAVCaptions);
        CaptionAdmin.SetRange("Page ID", this.CurrentPageId);
        CaptionAdmin.SetFilter("Control ID", '>0');
        CaptionAdmin.SetRange("Language Code", this.CaptionLanguage);
        CaptionAdmin.SetLoadFields("Caption ML");
        if CaptionAdmin.FindSet() then
            repeat
                this.MobileNAVCaptions.Add(CaptionAdmin."Control ID", CaptionAdmin."Caption ML");
            until CaptionAdmin.Next() = 0;
    end;

    /// <summary>
    /// The captions of the page's bound controls from Business Central metadata, in the caption
    /// language. A session that cannot read Page Control Field gets none and falls back to
    /// MobileNAV's names.
    /// </summary>
    local procedure LoadMetadataCaptions()
    var
        PageControlField: Record "Page Control Field";
        TableField: Record Field;
        CaptionKey: Text;
    begin
        Clear(this.MetadataCaptions);
        if not PageControlField.ReadPermission() then
            exit;
        this.UseCaptionLanguage();
        PageControlField.SetRange(PageNo, this.CurrentPageId);
        PageControlField.SetFilter(FieldNo, '<>0');
        PageControlField.SetLoadFields(ControlName, TableNo, FieldNo);
        TableField.SetLoadFields("Field Caption");
        if PageControlField.FindSet() then
            repeat
                CaptionKey := this.NameKey(PageControlField.ControlName);
                if not this.MetadataCaptions.ContainsKey(CaptionKey) then
                    if TableField.Get(PageControlField.TableNo, PageControlField.FieldNo) then
                        this.MetadataCaptions.Add(CaptionKey, TableField."Field Caption");
            until PageControlField.Next() = 0;
        this.TranslationHelper.RestoreGlobalLanguage();
    end;

    /// <summary>Switches the session to the caption language for metadata captions. RestoreGlobalLanguage switches back.</summary>
    local procedure UseCaptionLanguage()
    var
        Language: Record Language;
    begin
        Language.SetLoadFields("Windows Language ID");
        if Language.Get(this.CaptionLanguage) and (Language."Windows Language ID" <> 0) then
            this.TranslationHelper.SetGlobalLanguageById(Language."Windows Language ID")
        else
            this.TranslationHelper.SetGlobalLanguageById(GlobalLanguage());
    end;

    /// <summary>
    /// A control's caption: the provider's Caption for the language, MobileNAV's caption for the
    /// language, the Business Central caption, MobileNAV's localized name, the stored name.
    /// </summary>
    /// <param name="StoredName">The name MobileNAV stores for the control.</param>
    /// <param name="ControlId">MobileNAV's control ID, 0 when the control has no live row.</param>
    /// <param name="LocalizedName">MobileNAV's localized field name, empty when the control has no live row.</param>
    /// <returns>The caption.</returns>
    local procedure ControlCaption(StoredName: Text; ControlId: Integer; LocalizedName: Text): Text
    var
        Caption: Text;
    begin
        if this.DeclaredCaptions.Get(LowerCase(StoredName), Caption) then
            exit(Caption);
        if this.MobileNAVCaptions.Get(ControlId, Caption) then
            if Caption <> '' then
                exit(Caption);
        if this.MetadataCaptions.Get(LowerCase(StoredName), Caption) then
            exit(Caption);
        if LocalizedName <> '' then
            exit(LocalizedName);
        exit(this.Humanize(StoredName));
    end;

    /// <summary>MobileNAV's caption for a page (its control 0 row), in the caption language.</summary>
    /// <param name="PageId">The page object ID.</param>
    /// <returns>The caption, empty when MobileNAV has none.</returns>
    local procedure MobileNAVPageCaption(PageId: Integer): Text
    var
        CaptionAdmin: Record "MobileNAV CaptionML Admin.";
    begin
        CaptionAdmin.SetLoadFields("Caption ML");
        if CaptionAdmin.Get(PageId, 0, this.CaptionLanguage) then
            exit(CaptionAdmin."Caption ML");
        exit('');
    end;

    /// <summary>The caption of a drawn control, or of a control the page does not draw.</summary>
    /// <param name="ControlName">The control name as declared or stored.</param>
    /// <returns>The caption.</returns>
    local procedure CaptionOf(ControlName: Text): Text
    var
        Caption: Text;
    begin
        if this.ControlCaptions.Get(this.NameKey(ControlName), Caption) then
            exit(Caption);
        exit(this.ControlCaption(this.ServiceLookup.StoredFieldName(ControlName), 0, ''));
    end;

    local procedure PageCaption(PageId: Integer) Caption: Text
    begin
        Caption := this.DeclaredPageCaption(PageId);
        if Caption = '' then
            Caption := this.MobileNAVPageCaption(PageId);
        if Caption = '' then
            Caption := this.MetadataPageCaption(PageId);
        if Caption = '' then
            Caption := Format(PageId);
    end;

    local procedure DeclaredPageCaption(PageId: Integer): Text
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::Caption, PageId, '') then
            repeat
                if TempLine."Language Code" = this.CaptionLanguage then
                    exit(TempLine.Description);
            until TempLine.Next() = 0;
        exit('');
    end;

    local procedure MetadataPageCaption(PageId: Integer): Text
    var
        PageMetadata: Record "Page Metadata";
        Caption: Text;
    begin
        if not PageMetadata.ReadPermission() then
            exit('');
        this.UseCaptionLanguage();
        PageMetadata.SetLoadFields(Caption);
        if PageMetadata.Get(PageId) then
            Caption := PageMetadata.Caption;
        this.TranslationHelper.RestoreGlobalLanguage();
        exit(Caption);
    end;

    /// <summary>
    /// A category's caption: the translation for the caption language (the provider's, then
    /// MobileNAV's), the provider's description, MobileNAV's description, the code.
    /// </summary>
    /// <param name="CategoryCode">The category code.</param>
    /// <returns>The caption.</returns>
    local procedure CategoryCaption(CategoryCode: Code[100]) Caption: Text
    begin
        Caption := this.CategoryTranslation(CategoryCode);
        if Caption = '' then
            Caption := this.DeclaredCategoryDescription(CategoryCode);
        if Caption = '' then
            Caption := this.MobileNAVCategoryDescription(CategoryCode);
        if Caption = '' then
            Caption := CategoryCode;
    end;

    local procedure DeclaredCategoryDescription(CategoryCode: Code[100]): Text
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::Category, 0, CategoryCode) then
            exit(TempLine.Description);
        exit('');
    end;

    local procedure MobileNAVCategoryDescription(CategoryCode: Code[100]): Text
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if StrLen(CategoryCode) > MaxStrLen(MasterData.Code) then
            exit('');
        MasterData.SetRange(Type, MasterData.Type::Category);
        MasterData.SetRange(Code, CategoryCode);
        MasterData.SetLoadFields(Description);
        if MasterData.FindFirst() then
            exit(MasterData.Description);
        exit('');
    end;

    local procedure CategoryTranslation(CategoryCode: Code[100]): Text
    var
        CategoryTransl: Record "MobileNAV Category Transl.";
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Category Translation", 0, CategoryCode) then
            repeat
                if TempLine."Language Code" = this.CaptionLanguage then
                    exit(TempLine.Description);
            until TempLine.Next() = 0;
        if StrLen(CategoryCode) > MaxStrLen(CategoryTransl.Category) then
            exit('');
        CategoryTransl.SetRange(Category, CategoryCode);
        CategoryTransl.SetRange("Language Code", this.CaptionLanguage);
        CategoryTransl.SetLoadFields(Description);
        if CategoryTransl.FindFirst() then
            exit(CategoryTransl.Description);
        exit('');
    end;

    // ---- Controls -----------------------------------------------------------------------

    local procedure LoadControls()
    begin
        this.TempControl.Reset();
        this.TempControl.DeleteAll(false);
        Clear(this.ControlEntries);
        Clear(this.ControlCaptions);
        Clear(this.ControlChanges);
        Clear(this.ChangeDetails);
        Clear(this.DeclaredOrder);
        Clear(this.FilterPaneCaptions);
        Clear(this.ChangeKinds);
        Clear(this.ChangeWheres);
        Clear(this.ChangeItems);
        Clear(this.ChangeDetailTexts);
        this.NextControlEntryNo := 0;
        if this.HasLiveRows then
            this.LoadLiveControls();
        this.OverlayDeclaredControls();
        if this.HasDeclared(Enum::"BJF MN Config Operation"::"Field Order") then
            this.OrderAsDeclared();
    end;

    local procedure LoadLiveControls()
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        Relations: Dictionary of [Integer, Text];
        CodeFields: Dictionary of [Integer, Text];
        GroupCode: Code[20];
    begin
        this.LoadLiveRelations(Relations, CodeFields);
        ServiceSetup.SetCurrentKey("Service Name", "Line Type", "Order");
        ServiceSetup.SetRange("Service Name", this.CurrentServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.SetLoadFields(FieldClass, Category, FieldName, ControlID, LocalizedFieldName, Visible, Editable, DisplayInMenu, "Visible as Filter",
            MobileType, Mandatory, "Validation Behavior", "Function Name", Stage, FieldType);
        if ServiceSetup.FindSet() then
            repeat
                if not this.IsLiveGroupMarker(ServiceSetup, GroupCode) then
                    this.AddLiveControl(ServiceSetup, GroupCode, Relations, CodeFields);
            until ServiceSetup.Next() = 0;
    end;

    local procedure LoadLiveRelations(var Relations: Dictionary of [Integer, Text]; var CodeFields: Dictionary of [Integer, Text])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Service Name", this.CurrentServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Relation);
        ServiceSetup.SetFilter(RelatedPageName, '<>%1', '');
        ServiceSetup.SetLoadFields("Page Line No.", RelatedPageName, RelatedPgCodeFldName);
        if ServiceSetup.FindSet() then
            repeat
                if not Relations.ContainsKey(ServiceSetup."Page Line No.") then begin
                    Relations.Add(ServiceSetup."Page Line No.", ServiceSetup.RelatedPageName);
                    CodeFields.Add(ServiceSetup."Page Line No.", ServiceSetup.RelatedPgCodeFldName);
                end;
            until ServiceSetup.Next() = 0;
    end;

    /// <summary>Whether the row opens or closes a field group. Older rows mark a group by name only: _CODE_Start and _CODE_End.</summary>
    /// <param name="ServiceSetup">The live field row.</param>
    /// <param name="GroupCode">The open group, updated by a marker row.</param>
    /// <returns>True for a group marker row.</returns>
    local procedure IsLiveGroupMarker(ServiceSetup: Record "MobileNAV Service Setup"; var GroupCode: Code[20]): Boolean
    var
        FieldName: Text;
    begin
        if ServiceSetup.FieldClass = ServiceSetup.FieldClass::GroupStart then begin
            GroupCode := ServiceSetup.Category;
            exit(true);
        end;
        if ServiceSetup.FieldClass = ServiceSetup.FieldClass::GroupEnd then begin
            GroupCode := '';
            exit(true);
        end;
        FieldName := ServiceSetup.FieldName;
        if not FieldName.StartsWith('_') then
            exit(false);
        if FieldName.EndsWith(this.GroupStartSuffixTok) and (StrLen(FieldName) > StrLen(this.GroupStartSuffixTok) + 1) then begin
            GroupCode := CopyStr(FieldName.Substring(2, StrLen(FieldName) - StrLen(this.GroupStartSuffixTok) - 1), 1, MaxStrLen(GroupCode));
            exit(true);
        end;
        if FieldName.EndsWith(this.GroupEndSuffixTok) then begin
            GroupCode := '';
            exit(true);
        end;
        exit(false);
    end;

    local procedure AddLiveControl(ServiceSetup: Record "MobileNAV Service Setup"; GroupCode: Code[20]; Relations: Dictionary of [Integer, Text]; CodeFields: Dictionary of [Integer, Text])
    var
        LiveRow: RecordRef;
        Caption: Text;
        TargetService: Text;
        CodeField: Text;
        MobileType: Text;
    begin
        Caption := this.ControlCaption(ServiceSetup.FieldName, ServiceSetup.ControlID, ServiceSetup.LocalizedFieldName);
        if (ServiceSetup.FieldClass = ServiceSetup.FieldClass::FlowFilter) or (ServiceSetup.ControlID < 0) then begin
            if ServiceSetup.Visible then
                this.FilterPaneCaptions.Add(Caption);
            exit;
        end;
        LiveRow.GetTable(ServiceSetup);
        MobileType := this.FieldText(LiveRow.Field(ServiceSetup.FieldNo(MobileType)));
        if Relations.Get(ServiceSetup."Page Line No.", TargetService) then
            CodeField := CodeFields.Get(ServiceSetup."Page Line No.");

        this.InsertControl(ServiceSetup.FieldName, Caption);
        this.TempControl.Validate(Visible, ServiceSetup.Visible);
        this.TempControl.Validate(Editable, ServiceSetup.Editable);
        this.TempControl.Validate("Display In Menu", ServiceSetup.DisplayInMenu);
        this.TempControl.Validate(Filterable, ServiceSetup."Visible as Filter");
        this.TempControl.Validate(Importance, CopyStr(this.FieldText(LiveRow.Field(ServiceSetup.FieldNo(Mandatory))), 1, MaxStrLen(this.TempControl.Importance)));
        this.TempControl.Validate("Mobile Type", CopyStr(MobileType, 1, MaxStrLen(this.TempControl."Mobile Type")));
        this.TempControl.Validate("Validation Behavior", CopyStr(this.FieldText(LiveRow.Field(ServiceSetup.FieldNo("Validation Behavior"))), 1, MaxStrLen(this.TempControl."Validation Behavior")));
        this.TempControl.Validate("Function Name", ServiceSetup."Function Name");
        this.TempControl.Validate("Group Code", GroupCode);
        this.TempControl.Validate("Stage Id", ServiceSetup.Stage);
        this.TempControl.Validate("Service Name", CopyStr(TargetService, 1, MaxStrLen(this.TempControl."Service Name")));
        this.TempControl.Validate("Related Code Field", CopyStr(CodeField, 1, MaxStrLen(this.TempControl."Related Code Field")));
        this.TempControl.Validate("Action Type", this.LiveKind(ServiceSetup, MobileType, TargetService <> '', CodeField <> ''));
        this.TempControl.Modify(false);
    end;

    /// <summary>Inserts a control at the end of the page and makes it the current one.</summary>
    /// <param name="StoredName">The name MobileNAV stores for the control.</param>
    /// <param name="Caption">The control's caption.</param>
    local procedure InsertControl(StoredName: Text; Caption: Text)
    begin
        this.NextControlEntryNo += 1;
        this.TempControl.Init();
        this.TempControl.Validate("Entry No.", this.NextControlEntryNo);
        this.TempControl.Validate(Operation, Enum::"BJF MN Config Operation"::Field);
        this.TempControl.Validate("Page ID", this.CurrentPageId);
        this.TempControl.Validate("Control Name", CopyStr(StoredName, 1, MaxStrLen(this.TempControl."Control Name")));
        this.TempControl.Validate(Description, CopyStr(Caption, 1, MaxStrLen(this.TempControl.Description)));
        this.TempControl.Validate(Importance, this.StandardImportanceTok);
        this.TempControl.Insert(false);
        this.ControlEntries.Set(LowerCase(StoredName), this.TempControl."Entry No.");
        this.ControlCaptions.Set(LowerCase(StoredName), Caption);
    end;

    local procedure LiveKind(ServiceSetup: Record "MobileNAV Service Setup"; MobileType: Text; HasRelation: Boolean; HasCodeField: Boolean): Text[30]
    var
        Kind: Text[30];
    begin
        if ServiceSetup.FieldName = this.FieldControlTok then
            exit(this.ChannelKindTok);
        Kind := this.ValueKind(MobileType);
        if Kind in [this.ChannelKindTok, this.MediaKindTok] then
            exit(Kind);
        if this.Vocabulary.IsPrintMobileType(MobileType) then
            exit(this.PrintKindTok);
        if ServiceSetup.FieldType = ServiceSetup.FieldType::"None" then
            exit(this.ActionKind(HasRelation));
        if HasRelation then
            exit(this.RelationKind(ServiceSetup, HasCodeField));
        exit(Kind);
    end;

    /// <summary>A control with no value: a link when it opens a page, else a button.</summary>
    /// <param name="HasRelation">Whether the control opens another page.</param>
    /// <returns>The drawing kind.</returns>
    local procedure ActionKind(HasRelation: Boolean): Text[30]
    begin
        if HasRelation then
            exit(this.LinkKindTok);
        exit(this.ButtonKindTok);
    end;

    /// <summary>A value with a related page: a lookup when the device picks the value there, else a drill down.</summary>
    /// <param name="ServiceSetup">The live field row.</param>
    /// <param name="HasCodeField">Whether the relation names the field the pick returns.</param>
    /// <returns>The drawing kind.</returns>
    local procedure RelationKind(ServiceSetup: Record "MobileNAV Service Setup"; HasCodeField: Boolean): Text[30]
    begin
        if HasCodeField then
            exit(this.LookupKindTok);
        if ServiceSetup.Editable and (ServiceSetup.FieldType in [ServiceSetup.FieldType::Code, ServiceSetup.FieldType::Text]) then
            exit(this.LookupKindTok);
        exit(this.DrillDownKindTok);
    end;

    /// <summary>How a value control is drawn, from its MobileNAV mobile type.</summary>
    /// <param name="MobileType">MobileNAV Mobile Type member name.</param>
    /// <returns>The drawing kind.</returns>
    local procedure ValueKind(MobileType: Text): Text[30]
    begin
        if this.Vocabulary.IsMobileType(MobileType, Enum::"BJF MN Mobile Type"::FieldControl) then
            exit(this.ChannelKindTok);
        if this.Vocabulary.IsMediaMobileType(MobileType) then
            exit(this.MediaKindTok);
        if MobileType = this.Vocabulary.BarcodeMobileTypeName() then
            exit(this.ScanKindTok);
        if this.Vocabulary.IsMobileType(MobileType, Enum::"BJF MN Mobile Type"::Quantity) then
            exit(this.QuantityKindTok);
        exit(this.FieldKindTok);
    end;

    local procedure OverlayDeclaredControls()
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        TempLine.Copy(this.TempDefinitionLine, true);
        TempLine.Reset();
        TempLine.SetRange("Page ID", this.CurrentPageId);
        TempLine.SetControlFilter();
        if TempLine.FindSet() then
            repeat
                this.OverlayControl(TempLine);
            until TempLine.Next() = 0;

        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Flow Filter", this.CurrentPageId) then
            repeat
                this.FilterPaneCaptions.Add(this.CaptionOf(TempLine."Control Name"));
            until TempLine.Next() = 0;
    end;

    /// <summary>Lays one declared control over its live row, or adds it when MobileNAV has no row for it yet.</summary>
    /// <param name="DeclaredLine">The declared control.</param>
    local procedure OverlayControl(DeclaredLine: Record "BJF MN Config Line" temporary)
    var
        TempBefore: Record "BJF MN Config Line" temporary;
        StoredName: Text;
        EntryNo: Integer;
        IsNew: Boolean;
    begin
        StoredName := this.ServiceLookup.StoredFieldName(DeclaredLine."Control Name");
        IsNew := not this.ControlEntries.Get(LowerCase(StoredName), EntryNo);
        if IsNew then
            this.InsertControl(StoredName, this.ControlCaption(StoredName, 0, ''))
        else
            if not this.TempControl.Get(EntryNo) then
                exit;
        TempBefore := this.TempControl;
        this.ApplyDeclaration(DeclaredLine);
        this.TempControl.Modify(false);

        if not this.DeclaredOrder.Contains(this.TempControl."Entry No.") then
            this.DeclaredOrder.Add(this.TempControl."Entry No.");
        if IsNew then begin
            this.ControlChanges.Set(LowerCase(StoredName), this.InsertChangeTok);
            this.AddedChange(this.TempControl);
        end else
            if this.Differs(TempBefore, this.TempControl) then begin
                this.ControlChanges.Set(LowerCase(StoredName), this.ModifyChangeTok);
                this.RecordSettingChanges(TempBefore, this.TempControl);
            end;
    end;

    local procedure ApplyDeclaration(DeclaredLine: Record "BJF MN Config Line" temporary)
    begin
        this.TempControl.Validate(Visible, DeclaredLine.Visible);
        this.TempControl.Validate(Editable, DeclaredLine.Editable);
        this.TempControl.Validate("Display In Menu", DeclaredLine."Display In Menu");
        this.TempControl.Validate(Filterable, DeclaredLine.Filterable);
        if DeclaredLine.Importance <> '' then
            this.TempControl.Validate(Importance, DeclaredLine.Importance);
        if DeclaredLine."Mobile Type" <> '' then
            this.TempControl.Validate("Mobile Type", DeclaredLine."Mobile Type");
        if DeclaredLine."Validation Behavior" <> '' then
            this.TempControl.Validate("Validation Behavior", DeclaredLine."Validation Behavior");
        if DeclaredLine."Function Name" <> '' then
            this.TempControl.Validate("Function Name", DeclaredLine."Function Name");
        if DeclaredLine."Group Code" <> '' then
            this.TempControl.Validate("Group Code", DeclaredLine."Group Code");
        if DeclaredLine."Target Page ID" <> 0 then begin
            this.TempControl.Validate("Target Page ID", DeclaredLine."Target Page ID");
            this.TempControl.Validate("Service Name", this.ServiceNameOf(DeclaredLine."Target Page ID"));
            this.TempControl.Validate("Related Code Field", DeclaredLine."Related Code Field");
        end;
        this.TempControl.Validate("Action Type", this.DeclaredKind(DeclaredLine, this.TempControl."Action Type"));
    end;

    local procedure DeclaredKind(DeclaredLine: Record "BJF MN Config Line" temporary; CurrentKind: Text[30]): Text[30]
    begin
        case DeclaredLine.Operation of
            Enum::"BJF MN Config Operation"::"Function Field":
                exit(this.ButtonKind(DeclaredLine."Mobile Type"));
            Enum::"BJF MN Config Operation"::"Linked Field":
                exit(this.LinkKindTok);
            Enum::"BJF MN Config Operation"::"Scan Field":
                exit(this.ScanKindTok);
            Enum::"BJF MN Config Operation"::"Lookup Field":
                exit(this.LookupKindTok);
        end;
        if DeclaredLine."Mobile Type" <> '' then
            exit(this.ValueKind(DeclaredLine."Mobile Type"));
        if CurrentKind <> '' then
            exit(CurrentKind);
        exit(this.FieldKindTok);
    end;

    local procedure ButtonKind(MobileType: Text): Text[30]
    begin
        if this.Vocabulary.IsMediaMobileType(MobileType) then
            exit(this.MediaKindTok);
        if this.Vocabulary.IsPrintMobileType(MobileType) then
            exit(this.PrintKindTok);
        exit(this.ButtonKindTok);
    end;

    local procedure Differs(Before: Record "BJF MN Config Line" temporary; After: Record "BJF MN Config Line" temporary): Boolean
    begin
        exit(this.DrawnSettings(Before) <> this.DrawnSettings(After));
    end;

    /// <summary>The settings of a control that change its drawing, as one text to compare.</summary>
    /// <param name="Control">The control.</param>
    /// <returns>The settings.</returns>
    local procedure DrawnSettings(Control: Record "BJF MN Config Line" temporary): Text
    begin
        exit(StrSubstNo(this.DrawnSettingsTok, Control.Visible, Control.Editable, Control.Filterable, Control."Display In Menu",
            Control."Group Code", Control.Importance, Control."Mobile Type", Control."Function Name"));
    end;

    /// <summary>OrderAsDeclared: the declared controls first, in declaration order, then the others in MobileNAV's order.</summary>
    local procedure OrderAsDeclared()
    var
        TempOrdered: Record "BJF MN Config Line" temporary;
        EntryNo: Integer;
        NewEntryNo: Integer;
    begin
        foreach EntryNo in this.DeclaredOrder do
            if this.TempControl.Get(EntryNo) then
                this.CopyControl(TempOrdered, NewEntryNo);
        this.TempControl.Reset();
        if this.TempControl.FindSet() then
            repeat
                if not this.DeclaredOrder.Contains(this.TempControl."Entry No.") then
                    this.CopyControl(TempOrdered, NewEntryNo);
            until this.TempControl.Next() = 0;
        this.ReplaceControls(TempOrdered);
    end;

    local procedure ReplaceControls(var TempOrdered: Record "BJF MN Config Line" temporary)
    begin
        this.TempControl.DeleteAll(false);
        Clear(this.ControlEntries);
        TempOrdered.Reset();
        if TempOrdered.FindSet() then
            repeat
                this.TempControl := TempOrdered;
                this.TempControl.Insert(false);
                this.ControlEntries.Set(LowerCase(this.TempControl."Control Name"), this.TempControl."Entry No.");
            until TempOrdered.Next() = 0;
    end;

    local procedure CopyControl(var TempOrdered: Record "BJF MN Config Line" temporary; var NewEntryNo: Integer)
    begin
        NewEntryNo += 1;
        TempOrdered := this.TempControl;
        TempOrdered.Validate("Entry No.", NewEntryNo);
        TempOrdered.Insert(false);
    end;

    // ---- Stages -------------------------------------------------------------------------

    /// <summary>The wizard stages: the provider's when it declares a wizard for the page, else MobileNAV's live ones.</summary>
    local procedure LoadStages()
    begin
        Clear(this.StageCodes);
        Clear(this.StageCaptions);
        Clear(this.StageShows);
        this.WizardDeclared := this.HasDeclared(Enum::"BJF MN Config Operation"::Staging);
        if this.WizardDeclared then
            this.LoadDeclaredStages()
        else
            if this.HasLiveRows then
                this.LoadLiveStages();
    end;

    local procedure LoadDeclaredStages()
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::Stage, this.CurrentPageId) then
            repeat
                this.AddStage(TempLine."Stage Id", TempLine."Stage Description");
            until TempLine.Next() = 0;
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Stage Field", this.CurrentPageId) then
            repeat
                this.StageShows.Set(this.StageKey(TempLine."Stage Id", TempLine."Control Name"), this.StageManagement.ExpectedToken(TempLine));
            until TempLine.Next() = 0;
    end;

    local procedure LoadLiveStages()
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Service Name", this.CurrentServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Stage);
        ServiceSetup.SetLoadFields(Stage);
        if ServiceSetup.FindSet() then
            repeat
                this.AddStage(ServiceSetup.Stage, '');
            until ServiceSetup.Next() = 0;
    end;

    local procedure AddStage(StageCode: Code[100]; Description: Text)
    var
        Caption: Text;
    begin
        this.StageCodes.Add(StageCode);
        Caption := this.CategoryTranslation(StageCode);
        if Caption = '' then
            Caption := Description;
        if Caption = '' then
            Caption := this.CategoryCaption(StageCode);
        this.StageCaptions.Add(Caption);
    end;

    local procedure StageKey(StageCode: Text; ControlName: Text): Text
    begin
        exit(StrSubstNo(this.StageKeyTok, UpperCase(StageCode), this.NameKey(ControlName)));
    end;

    /// <summary>The control's entry in a stage: empty when shown, R read-only, H hidden. A declared wizard hides the controls it does not list.</summary>
    /// <param name="Control">The control.</param>
    /// <param name="StageIndex">The stage, from 1.</param>
    /// <returns>The stage token.</returns>
    local procedure StageToken(Control: Record "BJF MN Config Line" temporary; StageIndex: Integer): Text
    var
        Token: Text;
    begin
        if not this.WizardDeclared then
            exit(this.StageManagement.TokenAt(Control."Stage Id", StageIndex));
        if this.StageShows.Get(this.StageKey(this.StageCodes.Get(StageIndex), Control."Control Name"), Token) then
            exit(Token);
        exit(this.StageManagement.HiddenToken());
    end;

    // ---- Layout rules -------------------------------------------------------------------

    /// <summary>The marks the page's layout rules put on a control: the outline and class of a hidden or colored control, and caption and value colors.</summary>
    /// <param name="ControlName">The control or stage the rules target.</param>
    /// <param name="Classes">Receives the CSS classes, each with a leading space.</param>
    /// <param name="CaptionStyle">Receives the caption color style.</param>
    /// <param name="ValueStyle">Receives the value color style.</param>
    local procedure RuleMarks(ControlName: Text; var Classes: Text; var CaptionStyle: Text; var ValueStyle: Text)
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if not this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Layout Action", this.CurrentPageId) then
            exit;
        repeat
            if this.TargetsControl(TempLine, ControlName) then
                this.AddRuleMark(TempLine, Classes, CaptionStyle, ValueStyle);
        until TempLine.Next() = 0;
    end;

    local procedure TargetsControl(ActionLine: Record "BJF MN Config Line" temporary; ControlName: Text): Boolean
    begin
        exit((ActionLine."Target Filter Field" <> '') and (this.NameKey(ActionLine."Target Filter Field") = this.NameKey(ControlName)));
    end;

    local procedure AddRuleMark(ActionLine: Record "BJF MN Config Line" temporary; var Classes: Text; var CaptionStyle: Text; var ValueStyle: Text)
    begin
        case ActionLine."Action Type" of
            this.HideFieldActionTok:
                Classes += ' ' + this.RemovedClassTok + ' ' + this.RemovedChangeClassTok;
            this.FieldValueColorActionTok:
                begin
                    ValueStyle := StrSubstNo(this.ColorStyleTok, this.ColorCss(ActionLine.Color));
                    Classes += ' ' + this.ChangedChangeClassTok;
                end;
            this.FieldCaptionColorActionTok:
                begin
                    CaptionStyle := StrSubstNo(this.ColorStyleTok, this.ColorCss(ActionLine.Color));
                    Classes += ' ' + this.ChangedChangeClassTok;
                end;
        end;
    end;

    local procedure ConditionText(ConditionLine: Record "BJF MN Config Line" temporary): Text
    var
        Value: Text;
    begin
        if ConditionLine."Filter Type" = this.FilterFilterTypeTok then
            exit(StrSubstNo(this.MatchesLbl, this.CaptionOf(ConditionLine."Target Filter Field"), ConditionLine."Filter Value"));
        if ConditionLine."Filter Type" = this.FieldFilterTypeTok then
            Value := StrSubstNo(this.FieldReferenceTok, this.CaptionOf(ConditionLine."Source Field"))
        else
            Value := ConditionLine."Filter Value";
        exit(StrSubstNo(this.ComparisonTok, this.CaptionOf(ConditionLine."Target Filter Field"), this.ComparisonSymbol(ConditionLine.Comparison), Value));
    end;

    local procedure ComparisonSymbol(Comparison: Text): Text
    begin
        case Comparison of
            'Equal', '':
                exit('=');
            'NotEqual':
                exit('<>');
            'Less':
                exit('<');
            'LessOrEqual':
                exit('<=');
            'Greater':
                exit('>');
            'GreaterOrEqual':
                exit('>=');
        end;
        exit(Comparison);
    end;

    /// <summary>The CSS color of a MobileNAV color area, from the theme of the MobileNAV configuration.</summary>
    /// <param name="ColorName">MobileNAV color area member name.</param>
    /// <returns>The CSS color, a hex value.</returns>
    procedure ColorCss(ColorName: Text): Text
    begin
        if this.ThemeColors.Count() = 0 then
            this.LoadTheme();
        if this.ThemeColors.ContainsKey(ColorName) then
            exit(this.ThemeColors.Get(ColorName));
        exit(this.DefaultColorTok);
    end;

    /// <summary>Loads the colour of every MobileNAV color area: the theme rows of MobileNAV Master Data over the MobileNAV defaults.</summary>
    local procedure LoadTheme()
    var
        Config: Codeunit "BJF MN Emulator Config";
        Theme: JsonObject;
        Token: JsonToken;
        AreaName: Text;
    begin
        Clear(this.ThemeColors);
        foreach AreaName in this.AreaNamesTok.Split(',') do
            this.ThemeColors.Set(AreaName, this.DefaultAreaColor(AreaName));
        Theme := Config.ThemeJson();
        foreach AreaName in Theme.Keys() do
            if this.ThemeColors.ContainsKey(AreaName) then begin
                Theme.Get(AreaName, Token);
                this.ThemeColors.Set(AreaName, Token.AsValue().AsText());
            end;
        // The toolbar colours copy the title colours when the theme has no row for them.
        if not Theme.Contains(this.TitleToolbarBackgroundTok) then
            this.ThemeColors.Set(this.TitleToolbarBackgroundTok, this.ThemeColors.Get(this.ButtonTitleBackgroundTok));
        if not Theme.Contains(this.TitleToolbarForegroundTok) then
            this.ThemeColors.Set(this.TitleToolbarForegroundTok, this.ThemeColors.Get(this.ButtonTitleForegroundTok));
    end;

    /// <summary>The MobileNAV default colour of a color area, used when the theme has no row for it.</summary>
    /// <param name="AreaName">MobileNAV color area member name.</param>
    /// <returns>The hex color. Custom1 to Custom10 get the palette, other unknown names get the fallback color.</returns>
    local procedure DefaultAreaColor(AreaName: Text): Text
    var
        Colors: List of [Text];
        Pair: Text;
        Parts: List of [Text];
        Index: Integer;
    begin
        if AreaName.StartsWith(this.CustomColorPrefixTok) then begin
            Colors := this.CustomColorsTok.Split(',');
            if Evaluate(Index, AreaName.Substring(StrLen(this.CustomColorPrefixTok) + 1)) then
                if (Index >= 1) and (Index <= Colors.Count()) then
                    exit(Colors.Get(Index));
            exit(this.DefaultColorTok);
        end;
        foreach Pair in this.AreaDefaultsTok.Split(',') do begin
            Parts := Pair.Split('=');
            if Parts.Get(1) = AreaName then
                exit(Parts.Get(2));
        end;
        exit(this.DefaultColorTok);
    end;

    /// <summary>The CSS custom properties of the colour areas, one per area, named --mn-Area.</summary>
    /// <returns>A :root rule with one property per colour area.</returns>
    local procedure ThemeCss(): Text
    var
        Vars: TextBuilder;
        AreaName: Text;
    begin
        foreach AreaName in this.AreaNamesTok.Split(',') do
            Vars.Append(StrSubstNo(this.ThemeVarTok, AreaName, this.ThemeColors.Get(AreaName)));
        exit(StrSubstNo(this.ThemeRootTok, Vars.ToText()));
    end;

    // ---- List view ----------------------------------------------------------------------

    local procedure ListView(): Text
    var
        Body: TextBuilder;
        SheetId: Text;
        SheetRows: Text;
    begin
        Body.Append(this.ListRows());
        Body.Append(this.ListNotes());
        SheetId := this.NextElementId();
        SheetRows := this.FilterSheet();
        exit(this.Phone(this.CurrentTitle, this.ListLbl, Body.ToText(), '', this.ShowsCreateButton(), this.MenuDotHtml(), SheetId, SheetRows));
    end;

    /// <summary>The dot on the menu icon of the list: its color is the strongest change in the sort, filter and saved filter sheet. Empty when the sheet changes nothing.</summary>
    /// <returns>The dot HTML, empty for none.</returns>
    local procedure MenuDotHtml(): Text
    var
        Mark: Text;
    begin
        Mark := this.FilterSheetMark();
        if Mark = '' then
            exit('');
        exit(StrSubstNo(this.DotTok, Mark));
    end;

    /// <summary>The strongest change among the rows that touch the sort or the filters: removed, then changed, then added.</summary>
    /// <returns>The CSS kind, empty when no row touches them.</returns>
    local procedure FilterSheetMark(): Text
    var
        Index: Integer;
        Rank: Integer;
        Strongest: Integer;
    begin
        Strongest := 0;
        for Index := 1 to this.ChangeKinds.Count() do
            if this.ChangeWheres.Get(Index) in [this.WhereFilterTok, this.WhereSortTok] then begin
                Rank := this.KindRank(this.ChangeKinds.Get(Index));
                if Rank > Strongest then
                    Strongest := Rank;
            end;
        case Strongest of
            3:
                exit(this.RemovedClassTok);
            2:
                exit(this.ChangedClassTok);
            1:
                exit(this.AddedClassTok);
        end;
        exit('');
    end;

    local procedure KindRank(Kind: Text): Integer
    begin
        case Kind of
            this.KindRemoveTok:
                exit(3);
            this.KindChangeTok:
                exit(2);
            this.KindAddTok:
                exit(1);
        end;
        exit(0);
    end;

    local procedure ShowsCreateButton(): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        exit((this.PageValue(ServiceSetup.FieldNo("Main Menu Action")) = this.CreateActionTok) and this.PageFlag(ServiceSetup.FieldNo("Page Insert")));
    end;

    /// <summary>The sort, the filter pane and the saved filters of the list, as the rows of the sheet under the menu icon.</summary>
    /// <returns>The sheet HTML, empty when the list has none of them.</returns>
    local procedure FilterSheet(): Text
    var
        Rows: TextBuilder;
        SavedChips: TextBuilder;
        SortNames: Text;
        FilterChips: Text;
    begin
        SortNames := this.PrimaryKeyCaptions();
        if SortNames <> '' then
            Rows.Append(StrSubstNo(this.FilterRowTok, this.Escape(this.SortRowLbl), StrSubstNo(this.SortChipTok, this.Escape(StrSubstNo(this.SortedByLbl, SortNames)))));
        FilterChips := this.FilterPaneChips();
        if FilterChips <> '' then
            Rows.Append(StrSubstNo(this.FilterRowTok, this.Escape(this.FilterPaneRowLbl), FilterChips));
        this.AppendDeclaredSavedFilters(SavedChips);
        this.AppendLiveSavedFilters(SavedChips);
        if SavedChips.Length() > 0 then
            Rows.Append(StrSubstNo(this.FilterRowTok, this.Escape(this.SavedFiltersRowLbl), SavedChips.ToText()));
        if Rows.Length() = 0 then
            exit('');
        exit(Rows.ToText());
    end;

    /// <summary>The filter pane's fields as chips: the visible, filterable fields and the flow filters, each name once. A changed field carries its marker.</summary>
    /// <returns>The chip HTML, empty when the page has no filter pane.</returns>
    local procedure FilterPaneChips(): Text
    var
        Names: List of [Text];
        Chips: TextBuilder;
    begin
        this.AppendFilterPaneFields(Names, Chips);
        this.AppendFilterPaneCaptions(Names, Chips);
        exit(Chips.ToText());
    end;

    local procedure AppendFilterPaneFields(var Names: List of [Text]; var Chips: TextBuilder)
    var
        TempIter: Record "BJF MN Config Line" temporary;
    begin
        TempIter.Copy(this.TempControl, true);
        TempIter.Reset();
        TempIter.SetRange(Visible, true);
        TempIter.SetRange(Filterable, true);
        if TempIter.FindSet() then
            repeat
                if (TempIter.Description <> '') and (not Names.Contains(TempIter.Description)) then begin
                    Names.Add(TempIter.Description);
                    Chips.Append(StrSubstNo(this.FieldChipTok, this.ChangeClass(TempIter."Control Name"), this.Escape(TempIter.Description)));
                end;
            until TempIter.Next() = 0;
    end;

    local procedure AppendFilterPaneCaptions(var Names: List of [Text]; var Chips: TextBuilder)
    var
        Name: Text;
    begin
        foreach Name in this.FilterPaneCaptions do
            if (Name <> '') and (not Names.Contains(Name)) then begin
                Names.Add(Name);
                Chips.Append(StrSubstNo(this.FieldChipTok, '', this.Escape(Name)));
            end;
    end;

    local procedure AppendDeclaredSavedFilters(var Chips: TextBuilder)
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if not this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Saved Filter", this.CurrentPageId) then
            exit;
        repeat
            this.AppendSavedFilterChip(Chips, TempLine."Control Name", this.SavedFilterConditions(TempLine), this.NewChangeClassTok);
        until TempLine.Next() = 0;
    end;

    /// <summary>The conditions of a declared saved filter, as one text.</summary>
    /// <param name="SavedFilter">The saved filter line.</param>
    /// <returns>The conditions, empty when the filter has none.</returns>
    local procedure SavedFilterConditions(SavedFilter: Record "BJF MN Config Line" temporary): Text
    var
        TempField: Record "BJF MN Config Line" temporary;
        Conditions: TextBuilder;
    begin
        if SavedFilter."Own Filter Set" then
            Conditions.Append(this.OwnRecordsLbl);
        if this.FindDeclared(TempField, Enum::"BJF MN Config Operation"::"Saved Filter Field", this.CurrentPageId, SavedFilter."Control Name") then
            repeat
                this.AppendCondition(Conditions, StrSubstNo(this.ComparisonTok, this.CaptionOf(TempField."Target Filter Field"), TempField."Search Type", TempField."Filter Value"));
            until TempField.Next() = 0;
        exit(Conditions.ToText());
    end;

    local procedure AppendLiveSavedFilters(var Chips: TextBuilder)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.HasLiveRows then
            exit;
        ServiceSetup.SetRange("Service Name", this.CurrentServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::SavedFilter);
        ServiceSetup.SetRange("Line No.", 0);
        ServiceSetup.SetLoadFields(Name);
        if ServiceSetup.FindSet() then
            repeat
                if not this.HasDeclaredSavedFilter(ServiceSetup.Name) then
                    this.AppendSavedFilterChip(Chips, ServiceSetup.Name, '', '');
            until ServiceSetup.Next() = 0;
    end;

    local procedure HasDeclaredSavedFilter(Name: Text): Boolean
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Saved Filter", this.CurrentPageId) then
            repeat
                if LowerCase(TempLine."Control Name") = LowerCase(Name) then
                    exit(true);
            until TempLine.Next() = 0;
        exit(false);
    end;

    local procedure AppendSavedFilterChip(var Chips: TextBuilder; Name: Text; Conditions: Text; Classes: Text)
    begin
        Chips.Append(StrSubstNo(this.SavedFilterChipTok, Classes, this.Escape(Name), this.Escape(Conditions)));
    end;

    local procedure AppendCondition(var Conditions: TextBuilder; Condition: Text)
    begin
        if Conditions.Length() > 0 then
            Conditions.Append(', ');
        Conditions.Append(Condition);
    end;

    /// <summary>The first rows of the page's source table, read in process and filtered as the device filters them. An empty or unreadable table draws one row of field captions.</summary>
    /// <returns>The row HTML.</returns>
    local procedure ListRows(): Text
    var
        Source: RecordRef;
        Rows: TextBuilder;
        RowClasses: Text;
    begin
        RowClasses := '';
        if this.LineFormatNumbers.Count() > 0 then
            RowClasses := this.ChangedChangeClassTok;
        Clear(this.InvalidFilters);
        this.ListReadable := this.OpenSourceOf(Source);
        Rows.Append(this.RecordRows(Source, RowClasses));
        if not this.ListHasRows then
            Rows.Append(this.RowHtml(Source, RowClasses + ' empty', false));
        if Source.Number() <> 0 then
            Source.Close();
        exit(Rows.ToText());
    end;

    /// <summary>The rows of the source table's first three records, in table order.</summary>
    /// <param name="Source">The source table.</param>
    /// <param name="RowClasses">The CSS classes of each row.</param>
    /// <returns>The row HTML, empty when the table has no rows or cannot be read.</returns>
    local procedure RecordRows(var Source: RecordRef; RowClasses: Text): Text
    var
        Rows: TextBuilder;
        RowCount: Integer;
    begin
        this.ListHasRows := false;
        if not this.ListReadable then
            exit('');
        if not this.TryReadRows(Source, RowClasses, Rows, RowCount) then begin
            this.ListReadable := false;
            exit('');
        end;
        this.ListHasRows := RowCount > 0;
        exit(Rows.ToText());
    end;

    // Reads the first three rows. A read that fails returns false, so the preview shows no rows instead of an error.
    [TryFunction]
    local procedure TryReadRows(var Source: RecordRef; RowClasses: Text; var Rows: TextBuilder; var RowCount: Integer)
    begin
        if not Source.FindSet() then
            exit;
        repeat
            RowCount += 1;
            Rows.Append(this.RowHtml(Source, RowClasses, true));
        until (RowCount >= 3) or (Source.Next() = 0);
    end;

    /// <summary>Opens the page's source table with the page's filters applied, when the table is known.</summary>
    /// <param name="Source">Receives the table.</param>
    /// <returns>False when the table is unknown or the session cannot read it.</returns>
    local procedure OpenSourceOf(var Source: RecordRef): Boolean
    begin
        if this.CurrentTableNo = 0 then
            exit(false);
        if Source.Number() <> 0 then
            Source.Close();
        Source.Open(this.CurrentTableNo);
        if not Source.ReadPermission() then
            exit(false);
        this.ApplyPageFilters(Source);
        exit(true);
    end;

    /// <summary>Applies the provider's page filters, its user scope and MobileNAV's live filters to the source table.</summary>
    /// <param name="Source">The source table.</param>
    local procedure ApplyPageFilters(var Source: RecordRef)
    begin
        this.ApplyDeclaredFilters(Source);
        this.ApplyLiveFilters(Source);
    end;

    local procedure ApplyDeclaredFilters(var Source: RecordRef)
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Page Filter", this.CurrentPageId) then
            repeat
                this.ApplyPageFilter(Source, TempLine);
            until TempLine.Next() = 0;
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"User Scope", this.CurrentPageId) then
            this.ApplyUserScope(Source, TempLine."Control Name");
    end;

    local procedure ApplyPageFilter(var Source: RecordRef; PageFilter: Record "BJF MN Config Line" temporary)
    var
        FieldNo: Integer;
        Expression: Text;
    begin
        if not this.FieldNoOf(PageFilter."Control Name", FieldNo) then
            exit;
        if PageFilter."Filter Type" = this.FilterFilterTypeTok then
            Expression := PageFilter."Filter Value"
        else
            Expression := this.FilterExpression(PageFilter.Comparison, PageFilter."Filter Value");
        if not this.TrySetFilter(Source, FieldNo, Expression) then
            this.InvalidFilters.Set(this.PageFilterText(PageFilter), Expression);
    end;

    // A filter expression that is not valid fails here, so the caller can note it instead of raising an error.
    [TryFunction]
    local procedure TrySetFilter(var Source: RecordRef; FieldNo: Integer; Expression: Text)
    begin
        Source.Field(FieldNo).SetFilter(Expression);
    end;

    local procedure ApplyUserScope(var Source: RecordRef; ControlName: Text)
    var
        FieldNo: Integer;
    begin
        if this.FieldNoOf(ControlName, FieldNo) then
            Source.Field(FieldNo).SetRange(UserId());
    end;

    /// <summary>Applies MobileNAV's own page filters. Relation rows are left out: they apply only when the device opens the page from a parent record.</summary>
    /// <param name="Source">The source table.</param>
    local procedure ApplyLiveFilters(var Source: RecordRef)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.HasLiveRows then
            exit;
        ServiceSetup.SetRange("Service Name", this.CurrentServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Filter);
        ServiceSetup.SetRange("Page Line No.", 0);
        ServiceSetup.SetRange("Relation No.", 0);
        if ServiceSetup.FindSet() then
            repeat
                this.ApplyLiveFilter(Source, ServiceSetup);
            until ServiceSetup.Next() = 0;
    end;

    local procedure ApplyLiveFilter(var Source: RecordRef; ServiceSetup: Record "MobileNAV Service Setup")
    var
        LiveRow: RecordRef;
        FieldNo: Integer;
        Comparison: Text;
    begin
        if not this.FieldNoOf(this.FirstNonEmpty(ServiceSetup.SourceFieldName, ServiceSetup.DestFieldName, ServiceSetup.FieldName), FieldNo) then
            exit;
        LiveRow.GetTable(ServiceSetup);
        Comparison := this.FieldText(LiveRow.Field(ServiceSetup.FieldNo("Filter Comparsion Type")));
        if Comparison = this.OwnComparisonTok then begin
            Source.Field(FieldNo).SetRange(UserId());
            exit;
        end;
        if Comparison = this.NotOwnComparisonTok then begin
            Source.Field(FieldNo).SetFilter(StrSubstNo(this.NotEqualTok, UserId()));
            exit;
        end;
        Source.Field(FieldNo).SetFilter(this.FilterExpression(Comparison, ServiceSetup.FilterValue));
    end;

    /// <summary>A comparison as a record filter expression. NotEqual gives the value with the not-equal symbol in front.</summary>
    /// <param name="Comparison">The comparison, as MobileNAV stores it.</param>
    /// <param name="Value">The value to compare with.</param>
    /// <returns>The filter expression.</returns>
    local procedure FilterExpression(Comparison: Text; Value: Text): Text
    var
        Symbol: Text;
    begin
        Symbol := this.ComparisonSymbol(Comparison);
        if not (Symbol in [this.EqualSymbolTok, this.NotEqualSymbolTok, this.LessSymbolTok, this.LessOrEqualSymbolTok, this.GreaterSymbolTok, this.GreaterOrEqualSymbolTok]) then
            exit(Value);
        if Symbol = this.EqualSymbolTok then
            exit(Value);
        exit(Symbol + Value);
    end;

    /// <summary>The source table field number of a control, by its stored name.</summary>
    /// <param name="ControlName">The control name, declared or stored.</param>
    /// <param name="FieldNo">Receives the field number.</param>
    /// <returns>True when the source table has the field.</returns>
    local procedure FieldNoOf(ControlName: Text; var FieldNo: Integer): Boolean
    begin
        exit(this.SourceFieldNos.Get(LowerCase(this.ServiceLookup.StoredFieldName(ControlName)), FieldNo));
    end;

    /// <summary>The HTML of one row: the page's line format, with the first line from the first visible fields when the format starts at line two, else the first visible value fields.</summary>
    /// <param name="Source">The source table, positioned on the row when HasRecord.</param>
    /// <param name="Classes">The row's CSS classes.</param>
    /// <param name="HasRecord">False draws the field captions instead of values.</param>
    /// <returns>The row HTML.</returns>
    local procedure RowHtml(var Source: RecordRef; Classes: Text; HasRecord: Boolean): Text
    var
        Lines: TextBuilder;
        LineNo: Integer;
    begin
        if this.LineFormatNumbers.Count() = 0 then
            exit(this.DefaultRowHtml(Source, Classes, HasRecord));
        if not this.LineFormatNumbers.Contains(1) then
            Lines.Append(this.LineHtml(1, this.FirstLineText(Source, HasRecord)));
        for LineNo := 1 to 8 do
            if this.LineFormatNumbers.Contains(LineNo) then
                Lines.Append(this.LineHtml(LineNo, this.LineText(LineNo, Source, HasRecord)));
        exit(StrSubstNo(this.RowTok, Classes, Lines.ToText()));
    end;

    /// <summary>The bold first line of a row, from the first two visible value fields, as the device draws it.</summary>
    /// <param name="Source">The source table, positioned on the row when HasRecord.</param>
    /// <param name="HasRecord">False takes the captions.</param>
    /// <returns>The line text, not escaped.</returns>
    local procedure FirstLineText(var Source: RecordRef; HasRecord: Boolean): Text
    var
        Cells: List of [Text];
    begin
        this.DefaultCells(Source, HasRecord, Cells);
        if Cells.Count() = 0 then
            exit('');
        if Cells.Count() = 1 then
            exit(Cells.Get(1));
        exit(StrSubstNo(this.TwoValuesTok, Cells.Get(1), Cells.Get(2)));
    end;

    /// <summary>Without a line format the device shows the first visible value field on the first line and the next two on the second.</summary>
    /// <param name="Source">The source table.</param>
    /// <param name="Classes">The row's CSS classes.</param>
    /// <param name="HasRecord">False draws the field captions instead of values.</param>
    /// <returns>The row HTML.</returns>
    local procedure DefaultRowHtml(var Source: RecordRef; Classes: Text; HasRecord: Boolean): Text
    var
        Cells: List of [Text];
        Lines: TextBuilder;
    begin
        this.DefaultCells(Source, HasRecord, Cells);
        if Cells.Count() >= 1 then
            Lines.Append(this.LineHtml(1, Cells.Get(1)));
        if Cells.Count() = 2 then
            Lines.Append(this.LineHtml(2, Cells.Get(2)));
        if Cells.Count() = 3 then
            Lines.Append(this.LineHtml(2, StrSubstNo(this.TwoValuesTok, Cells.Get(2), Cells.Get(3))));
        exit(StrSubstNo(this.RowTok, Classes, Lines.ToText()));
    end;

    /// <summary>The first three visible value fields of the page, as values or as captions.</summary>
    /// <param name="Source">The source table.</param>
    /// <param name="HasRecord">False takes the captions.</param>
    /// <param name="Cells">Receives the cells.</param>
    local procedure DefaultCells(var Source: RecordRef; HasRecord: Boolean; var Cells: List of [Text])
    var
        TempIter: Record "BJF MN Config Line" temporary;
    begin
        TempIter.Copy(this.TempControl, true);
        TempIter.Reset();
        TempIter.SetRange(Visible, true);
        if TempIter.FindSet() then
            repeat
                if this.IsValueKind(TempIter."Action Type") then
                    Cells.Add(this.DefaultCellText(Source, TempIter, HasRecord));
            until (Cells.Count() >= 3) or (TempIter.Next() = 0);
    end;

    /// <summary>The text of one default cell: the field value, or the caption when there is no record.</summary>
    /// <param name="Source">The source table.</param>
    /// <param name="Control">The control.</param>
    /// <param name="HasRecord">False takes the caption.</param>
    /// <returns>The cell text.</returns>
    local procedure DefaultCellText(var Source: RecordRef; Control: Record "BJF MN Config Line" temporary; HasRecord: Boolean): Text
    begin
        if not HasRecord then
            exit(Control.Description);
        exit(this.FieldValueText(Source, Control."Control Name"));
    end;

    local procedure IsValueKind(Kind: Text): Boolean
    begin
        exit(Kind in [this.FieldKindTok, this.ScanKindTok, this.QuantityKindTok, this.LookupKindTok, this.DrillDownKindTok]);
    end;

    /// <summary>The text of one line of a row: its line format elements, in declaration order.</summary>
    /// <param name="LineNo">The line format number.</param>
    /// <param name="Source">The source table, positioned on the row when HasRecord.</param>
    /// <param name="HasRecord">False uses the captions in place of values.</param>
    /// <returns>The line text.</returns>
    local procedure LineText(LineNo: Integer; var Source: RecordRef; HasRecord: Boolean): Text
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Cell: Text;
        Cells: TextBuilder;
    begin
        if not this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Line Format", this.CurrentPageId) then
            exit('');
        repeat
            if TempLine."Line Format No." = LineNo then begin
                case TempLine."Filter Type" of
                    this.SeparatorElementTok:
                        Cell := TempLine."Filter Value";
                    this.CaptionElementTok:
                        Cell := this.CaptionOf(TempLine."Control Name");
                    else
                        if HasRecord then
                            Cell := this.FieldValueText(Source, TempLine."Control Name")
                        else
                            Cell := this.CaptionOf(TempLine."Control Name");
                end;
                Cells.Append(Cell);
            end;
        until TempLine.Next() = 0;
        exit(Cells.ToText());
    end;

    local procedure LineHtml(LineNo: Integer; Cell: Text): Text
    begin
        if LineNo = 1 then
            exit(StrSubstNo(this.FirstLineTok, this.Escape(this.LineCellName(LineNo)), this.Escape(Cell)));
        exit(StrSubstNo(this.OtherLineTok, this.Escape(this.LineCellName(LineNo)), this.Escape(Cell)));
    end;

    /// <summary>The field number of a flow field of the source table, by stored name.</summary>
    /// <param name="ControlName">The control name, declared or stored.</param>
    /// <param name="FieldNo">Receives the field number.</param>
    /// <returns>True when the source table has the flow field.</returns>
    local procedure FlowFieldNoOf(ControlName: Text; var FieldNo: Integer): Boolean
    begin
        exit(this.FlowFieldNos.Get(LowerCase(this.ServiceLookup.StoredFieldName(ControlName)), FieldNo));
    end;

    /// <summary>The field number of a control's value: a normal field or a flow field of the source table.</summary>
    /// <param name="ControlName">The control name, declared or stored.</param>
    /// <param name="FieldNo">Receives the field number.</param>
    /// <returns>True when the source table has the field.</returns>
    local procedure DisplayFieldNoOf(ControlName: Text; var FieldNo: Integer): Boolean
    begin
        if this.FieldNoOf(ControlName, FieldNo) then
            exit(true);
        exit(this.FlowFieldNoOf(ControlName, FieldNo));
    end;

    /// <summary>A field value of the source table as the device spells it. A flow field is calculated before it is read.</summary>
    /// <param name="Source">The source table, positioned on the row.</param>
    /// <param name="ControlName">The control name of the field.</param>
    /// <returns>The value, empty when the page control has no field in the table.</returns>
    local procedure FieldValueText(var Source: RecordRef; ControlName: Text): Text
    var
        FieldReference: FieldRef;
        FieldNo: Integer;
    begin
        if not this.DisplayFieldNoOf(ControlName, FieldNo) then
            exit('');
        FieldReference := Source.Field(FieldNo);
        if FieldReference.Class() = FieldClass::FlowField then
            FieldReference.CalcField();
        exit(this.FieldText(FieldReference));
    end;

    /// <summary>Reads the first record the list shows, with the page's filters, so the card draws the same values.</summary>
    local procedure LoadCardRecord()
    var
        Found: Boolean;
    begin
        this.HasCardRecord := false;
        if not this.OpenSourceOf(this.CardSource) then
            exit;
        if not this.TryReadFirst(this.CardSource, Found) then
            exit;
        this.HasCardRecord := Found;
    end;

    // Reads the first record of the source. A read that fails leaves the card with the field captions.
    [TryFunction]
    local procedure TryReadFirst(var Source: RecordRef; var Found: Boolean)
    begin
        Found := Source.FindSet();
    end;

    /// <summary>The value the card draws for a control: the first record's value, when the page has a record and the table has the field.</summary>
    /// <param name="Control">The control.</param>
    /// <param name="Value">Receives the value.</param>
    /// <returns>True when the card draws a record value.</returns>
    local procedure CardValueOf(Control: Record "BJF MN Config Line" temporary; var Value: Text): Boolean
    var
        FieldNo: Integer;
    begin
        Value := '';
        if not this.HasCardRecord then
            exit(false);
        if not this.DisplayFieldNoOf(Control."Control Name", FieldNo) then
            exit(false);
        exit(this.TryFieldValue(this.CardSource, Control."Control Name", Value));
    end;

    // Reads one field of the card's record. A field that fails to read draws the placeholder instead of an error.
    [TryFunction]
    local procedure TryFieldValue(var Source: RecordRef; ControlName: Text; var Value: Text)
    begin
        Value := this.FieldValueText(Source, ControlName);
    end;

    /// <summary>The escaped text to draw: the value when the card has one, else the placeholder.</summary>
    /// <param name="Value">The value.</param>
    /// <param name="HasValue">Whether the value is a record value.</param>
    /// <param name="Placeholder">The text to draw without a record value.</param>
    /// <returns>The HTML text.</returns>
    local procedure ShownText(Value: Text; HasValue: Boolean; Placeholder: Text): Text
    begin
        if HasValue then
            exit(this.Escape(Value));
        exit(this.Escape(Placeholder));
    end;

    local procedure LineCellName(LineNo: Integer): Text
    begin
        exit(SelectStr(LineNo, this.LineCellNamesLbl));
    end;

    /// <summary>The primary key fields of the source table, by caption, for the sort chip.</summary>
    /// <returns>The captions, separated by commas. Empty when the table is unknown.</returns>
    local procedure PrimaryKeyCaptions(): Text
    var
        Source: RecordRef;
        KeyField: FieldRef;
        PrimaryKey: KeyRef;
        Names: Text;
        Index: Integer;
    begin
        if this.CurrentTableNo = 0 then
            exit('');
        Source.Open(this.CurrentTableNo);
        PrimaryKey := Source.KeyIndex(1);
        for Index := 1 to PrimaryKey.FieldCount() do begin
            KeyField := PrimaryKey.FieldIndex(Index);
            if Names <> '' then
                Names += ', ';
            Names += this.CaptionOf(KeyField.Name());
        end;
        Source.Close();
        exit(Names);
    end;

    /// <summary>The notes under the rows: a filter the device cannot apply, whether the table has rows, and MobileNAV's own filters.</summary>
    /// <returns>The note HTML.</returns>
    local procedure ListNotes(): Text
    var
        Notes: TextBuilder;
        Note: Text;
        FilterNote: Text;
        Expression: Text;
    begin
        if not this.ListReadable then
            Notes.Append(StrSubstNo(this.NoteTok, '', this.Escape(this.NotReadableLbl)))
        else
            if not this.ListHasRows then
                Notes.Append(StrSubstNo(this.NoteTok, '', this.Escape(this.NoRecordsLbl)));
        foreach FilterNote in this.InvalidFilters.Keys() do begin
            this.InvalidFilters.Get(FilterNote, Expression);
            Notes.Append(StrSubstNo(this.NoteTok, this.InvalidClassTok, this.Escape(StrSubstNo(this.InvalidFilterLbl, Expression))));
        end;
        foreach Note in this.PageFilterNotes() do
            Notes.Append(StrSubstNo(this.NoteTok, '', this.Escape(StrSubstNo(this.ListShowsLbl, Note))));
        exit(Notes.ToText());
    end;

    /// <summary>MobileNAV's own record filters of the page that the provider does not declare, one text each. The provider's filters are rows of the change table.</summary>
    /// <returns>One text per filter, each once.</returns>
    local procedure PageFilterNotes() Notes: List of [Text]
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        Clear(this.DeclaredFilterCaptions);
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Page Filter", this.CurrentPageId) then
            repeat
                this.DeclaredFilterCaptions.Add(this.CaptionOf(TempLine."Control Name"));
            until TempLine.Next() = 0;
        this.AddLiveFilterNotes(Notes);
    end;

    /// <summary>A declared page filter as the note reads it.</summary>
    /// <param name="PageFilter">The page filter line.</param>
    /// <returns>The note text.</returns>
    local procedure PageFilterText(PageFilter: Record "BJF MN Config Line" temporary): Text
    begin
        if PageFilter."Filter Type" = this.FilterFilterTypeTok then
            exit(StrSubstNo(this.MatchesLbl, this.CaptionOf(PageFilter."Control Name"), PageFilter."Filter Value"));
        exit(StrSubstNo(this.ComparisonTok, this.CaptionOf(PageFilter."Control Name"), this.ComparisonSymbol(PageFilter.Comparison), PageFilter."Filter Value"));
    end;

    local procedure AddLiveFilterNotes(var Notes: List of [Text])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        FieldName: Text;
    begin
        if not this.HasLiveRows then
            exit;
        ServiceSetup.SetRange("Service Name", this.CurrentServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Filter);
        ServiceSetup.SetRange("Page Line No.", 0);
        ServiceSetup.SetRange("Relation No.", 0);
        if ServiceSetup.FindSet() then
            repeat
                FieldName := this.FirstNonEmpty(ServiceSetup.SourceFieldName, ServiceSetup.DestFieldName, ServiceSetup.FieldName);
                if not this.DeclaredFilterCaptions.Contains(this.CaptionOf(FieldName)) then
                    this.AddUniqueNote(Notes, this.LiveFilterText(ServiceSetup, FieldName));
            until ServiceSetup.Next() = 0;
    end;

    local procedure LiveFilterText(ServiceSetup: Record "MobileNAV Service Setup"; FieldName: Text): Text
    var
        LiveRow: RecordRef;
        Comparison: Text;
    begin
        LiveRow.GetTable(ServiceSetup);
        Comparison := this.FieldText(LiveRow.Field(ServiceSetup.FieldNo("Filter Comparsion Type")));
        if Comparison in [this.OwnComparisonTok, this.NotOwnComparisonTok] then
            exit(StrSubstNo(this.OwnRecordsOfLbl, this.CaptionOf(FieldName)));
        exit(StrSubstNo(this.ComparisonTok, this.CaptionOf(FieldName), this.ComparisonSymbol(Comparison), ServiceSetup.FilterValue));
    end;

    local procedure AddUniqueNote(var Notes: List of [Text]; Note: Text)
    begin
        if not Notes.Contains(Note) then
            Notes.Add(Note);
    end;

    local procedure FirstNonEmpty(First: Text; Second: Text; Third: Text): Text
    begin
        if First <> '' then
            exit(First);
        if Second <> '' then
            exit(Second);
        exit(Third);
    end;

    /// <summary>Finds the source table of the page and the field numbers of its normal and flow fields, by stored name. Flow filter fields are left out.</summary>
    local procedure LoadSourceFields()
    var
        TableField: Record Field;
    begin
        Clear(this.SourceFieldNos);
        Clear(this.FlowFieldNos);
        this.CurrentTableNo := 0;
        if not this.ServiceLookup.GetServiceTableNo(this.CurrentServiceName, this.CurrentTableNo) then
            exit;
        TableField.SetLoadFields(FieldName, "No.", Class);
        TableField.SetRange(TableNo, this.CurrentTableNo);
        if TableField.FindSet() then
            repeat
                case TableField.Class of
                    TableField.Class::Normal:
                        this.SourceFieldNos.Set(LowerCase(this.ServiceLookup.StoredFieldName(TableField.FieldName)), TableField."No.");
                    TableField.Class::FlowField:
                        this.FlowFieldNos.Set(LowerCase(this.ServiceLookup.StoredFieldName(TableField.FieldName)), TableField."No.");
                end;
            until TableField.Next() = 0;
    end;

    /// <summary>Loads the line format numbers the provider declares for the page.</summary>
    local procedure LoadLineFormatNumbers()
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        Clear(this.LineFormatNumbers);
        if not this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Line Format", this.CurrentPageId) then
            exit;
        repeat
            if not this.LineFormatNumbers.Contains(TempLine."Line Format No.") then
                this.LineFormatNumbers.Add(TempLine."Line Format No.");
        until TempLine.Next() = 0;
    end;

    /// <summary>Adds the rows for the provider's saved filters, filters, scope, toolbar buttons, layout rules and line formats. The control rows come from OverlayControl.</summary>
    local procedure AddRuleChanges()
    begin
        this.AddSavedFilterChanges();
        this.AddFilterRules();
        this.AddToolbarChanges();
        this.AddLayoutRuleChanges();
        this.AddLineFormatChanges();
    end;

    local procedure AddSavedFilterChanges()
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Saved Filter", this.CurrentPageId) then
            repeat
                this.AddChange(this.KindAddTok, this.WhereFilterTok, TempLine."Control Name", this.SavedFilterDetail(TempLine), '');
            until TempLine.Next() = 0;
    end;

    /// <summary>The detail sentence for a declared saved filter.</summary>
    /// <param name="SavedFilter">The saved filter line.</param>
    /// <returns>The sentence.</returns>
    local procedure SavedFilterDetail(SavedFilter: Record "BJF MN Config Line" temporary): Text
    var
        Conditions: Text;
    begin
        Conditions := this.SavedFilterConditions(SavedFilter);
        if Conditions = '' then
            exit(this.SavedFilterPlainLbl);
        exit(StrSubstNo(this.SavedFilterWithLbl, Conditions));
    end;

    local procedure AddFilterRules()
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Page Filter", this.CurrentPageId) then
            repeat
                this.AddChange(this.KindChangeTok, this.WhereFilterTok, this.CaptionOf(TempLine."Control Name"), StrSubstNo(this.RuleFilterLbl, this.PageFilterText(TempLine)), '');
            until TempLine.Next() = 0;
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"User Scope", this.CurrentPageId) then
            this.AddChange(this.KindChangeTok, this.WhereFilterTok, this.CaptionOf(TempLine."Control Name"), this.OwnOnlyLbl, '');
    end;

    /// <summary>Adds the rows for the toolbar buttons the provider hides. Each one is removed from the device.</summary>
    local procedure AddToolbarChanges()
    begin
        this.AddToolbarChange(Enum::"BJF MN Toolbar Button"::CardNavigate, this.WhereCardTok, this.CardNavigateLbl);
        this.AddToolbarChange(Enum::"BJF MN Toolbar Button"::CardRefresh, this.WhereCardTok, this.CardRefreshLbl);
        this.AddToolbarChange(Enum::"BJF MN Toolbar Button"::ListFilter, this.WhereFilterTok, this.ListFilterLbl);
        this.AddToolbarChange(Enum::"BJF MN Toolbar Button"::ListSort, this.WhereSortTok, this.ListSortLbl);
    end;

    /// <summary>Adds the row for one toolbar button when the provider hides it.</summary>
    /// <param name="ToolbarButton">The toolbar button.</param>
    /// <param name="PlaceWhere">The place token of the button.</param>
    /// <param name="ButtonName">The caption of the button.</param>
    local procedure AddToolbarChange(ToolbarButton: Enum "BJF MN Toolbar Button"; PlaceWhere: Text; ButtonName: Text)
    var
        TempProperty: Record "BJF MN Config Property" temporary;
        FieldNo: Integer;
    begin
        FieldNo := this.Vocabulary.ToolbarButtonFieldNo(ToolbarButton);
        TempProperty.Copy(this.TempDefinitionProperty, true);
        TempProperty.Reset();
        TempProperty.SetRange("Page ID", this.CurrentPageId);
        TempProperty.SetRange("Control Name", '');
        TempProperty.SetRange("Field No.", FieldNo);
        if TempProperty.FindFirst() and (TempProperty.Value = Format(true, 0, 9)) then
            this.AddChange(this.KindRemoveTok, PlaceWhere, ButtonName, this.HiddenOnDeviceLbl, '');
    end;

    /// <summary>Adds one row per action of a layout rule. A rule that hides a control is a removal, a colour is a change.</summary>
    local procedure AddLayoutRuleChanges()
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Target: Text;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Layout Action", this.CurrentPageId) then
            repeat
                Kind := this.KindChangeTok;
                if TempLine."Action Type" = this.HideFieldActionTok then
                    Kind := this.KindRemoveTok;
                Target := TempLine."Target Filter Field";
                if Target = '' then
                    this.AddChange(Kind, this.WhereRuleTok, TempLine."Control Name", this.LayoutActionDetail(TempLine), '')
                else
                    this.AddChange(Kind, this.WhereRuleTok, this.CaptionOf(Target), this.LayoutActionDetail(TempLine), Target);
            until TempLine.Next() = 0;
    end;

    /// <summary>The sentence for one layout rule action, with its condition.</summary>
    /// <param name="ActionLine">The layout action line.</param>
    /// <returns>The sentence.</returns>
    local procedure LayoutActionDetail(ActionLine: Record "BJF MN Config Line" temporary): Text
    var
        ActionText: Text;
        Conditions: Text;
    begin
        case ActionLine."Action Type" of
            this.HideFieldActionTok:
                ActionText := this.HidesLbl;
            this.FieldValueColorActionTok:
                ActionText := StrSubstNo(this.ValueColorLbl, this.Humanize(ActionLine.Color));
            this.FieldCaptionColorActionTok:
                ActionText := StrSubstNo(this.CaptionColorLbl, this.Humanize(ActionLine.Color));
            else
                ActionText := StrSubstNo(this.OtherActionLbl, this.Humanize(ActionLine."Action Type"));
        end;
        Conditions := this.RuleConditions(ActionLine."Control Name");
        if Conditions = this.AlwaysLbl then
            exit(ActionText);
        exit(StrSubstNo(this.ActionWhenLbl, ActionText, Conditions));
    end;

    local procedure AddLineFormatChanges()
    var
        Source: RecordRef;
        LineNo: Integer;
    begin
        this.LoadLineFormatNumbers();
        for LineNo := 1 to 8 do
            if this.LineFormatNumbers.Contains(LineNo) then
                this.AddChange(this.KindChangeTok, this.WhereListTok, StrSubstNo(this.LineItemLbl, SelectStr(LineNo, this.OrdinalsLbl)),
                    StrSubstNo(this.LineShowsLbl, this.LineText(LineNo, Source, false)), '');
    end;

    /// <summary>Adds one row to the change table for each setting the provider changes on a control that MobileNAV already has.</summary>
    /// <param name="Before">The control before the declaration.</param>
    /// <param name="After">The control after the declaration.</param>
    local procedure RecordSettingChanges(Before: Record "BJF MN Config Line" temporary; After: Record "BJF MN Config Line" temporary)
    begin
        this.VisibilityChanges(Before, After);
        this.FlagChanges(Before, After);
        this.ValueChanges(Before, After);
    end;

    /// <summary>The rows for a control that the provider shows, hides, or moves in or out of the menu.</summary>
    /// <param name="Before">The control before the declaration.</param>
    /// <param name="After">The control after the declaration.</param>
    local procedure VisibilityChanges(Before: Record "BJF MN Config Line" temporary; After: Record "BJF MN Config Line" temporary)
    var
        Name: Text;
    begin
        Name := this.ChangeName(After);
        if Before.Visible <> After.Visible then
            if After.Visible then
                this.AddChange(this.KindChangeTok, this.WhereOf(After), Name, this.ShownOnDeviceLbl, After."Control Name")
            else begin
                this.ControlChanges.Set(LowerCase(After."Control Name"), this.RemoveChangeTok);
                this.AddChange(this.KindRemoveTok, this.WhereOf(After), Name, this.HiddenOnDeviceLbl, After."Control Name");
            end;
        if Before."Display In Menu" <> After."Display In Menu" then
            if After."Display In Menu" then
                this.AddChange(this.KindChangeTok, this.WhereMenuTok, Name, this.InMenuLbl, After."Control Name")
            else
                this.AddChange(this.KindRemoveTok, this.WhereMenuTok, Name, this.OutOfMenuLbl, After."Control Name");
    end;

    /// <summary>The rows for the editable and filter pane settings of a control.</summary>
    /// <param name="Before">The control before the declaration.</param>
    /// <param name="After">The control after the declaration.</param>
    local procedure FlagChanges(Before: Record "BJF MN Config Line" temporary; After: Record "BJF MN Config Line" temporary)
    var
        Name: Text;
    begin
        Name := this.ChangeName(After);
        if Before.Editable <> After.Editable then
            if After.Editable then
                this.AddChange(this.KindChangeTok, this.WhereOf(After), Name, this.EditableLbl, After."Control Name")
            else
                this.AddChange(this.KindChangeTok, this.WhereOf(After), Name, this.ReadOnlyDetailLbl, After."Control Name");
        if Before.Filterable <> After.Filterable then
            if After.Filterable then
                this.AddChange(this.KindChangeTok, this.WhereFilterTok, Name, this.FilterPaneOnLbl, After."Control Name")
            else
                this.AddChange(this.KindChangeTok, this.WhereFilterTok, Name, this.FilterPaneOffLbl, After."Control Name");
    end;

    /// <summary>The rows for the group, importance, device type and function of a control.</summary>
    /// <param name="Before">The control before the declaration.</param>
    /// <param name="After">The control after the declaration.</param>
    local procedure ValueChanges(Before: Record "BJF MN Config Line" temporary; After: Record "BJF MN Config Line" temporary)
    var
        Name: Text;
        PlaceWhere: Text;
    begin
        Name := this.ChangeName(After);
        PlaceWhere := this.WhereOf(After);
        if Before."Group Code" <> After."Group Code" then
            if After."Group Code" = '' then
                this.AddChange(this.KindChangeTok, PlaceWhere, Name, this.GroupLeaveLbl, After."Control Name")
            else
                this.AddChange(this.KindChangeTok, PlaceWhere, Name, StrSubstNo(this.GroupMoveLbl, After."Group Code"), After."Control Name");
        if Before.Importance <> After.Importance then
            this.AddChange(this.KindChangeTok, PlaceWhere, Name, StrSubstNo(this.ImportanceLbl, After.Importance), After."Control Name");
        if Before."Mobile Type" <> After."Mobile Type" then
            this.AddChange(this.KindChangeTok, PlaceWhere, Name, StrSubstNo(this.MobileTypeLbl, After."Mobile Type"), After."Control Name");
        if Before."Function Name" <> After."Function Name" then
            this.AddChange(this.KindChangeTok, PlaceWhere, Name, StrSubstNo(this.FunctionLbl, After."Function Name"), After."Control Name");
    end;

    /// <summary>Adds one row to the change table.</summary>
    /// <param name="Kind">The change: Added, Changed or Removed.</param>
    /// <param name="PlaceWhere">The place: list, card, menu, bottom bar, filter, sort or rule.</param>
    /// <param name="ItemText">The caption of the item the change touches.</param>
    /// <param name="Detail">A plain sentence on the change.</param>
    /// <param name="StoredName">The control the row belongs to, empty for a row that belongs to no control. The detail also shows as the control's tooltip.</param>
    local procedure AddChange(Kind: Text; PlaceWhere: Text; ItemText: Text; Detail: Text; StoredName: Text)
    var
        KeyText: Text;
        Existing: Text;
    begin
        this.ChangeKinds.Add(Kind);
        this.ChangeWheres.Add(PlaceWhere);
        this.ChangeItems.Add(ItemText);
        this.ChangeDetailTexts.Add(Detail);
        if StoredName = '' then
            exit;
        KeyText := this.NameKey(StoredName);
        if this.ChangeDetails.Get(KeyText, Existing) then
            this.ChangeDetails.Set(KeyText, Existing + ' ' + Detail)
        else
            this.ChangeDetails.Set(KeyText, Detail);
    end;

    /// <summary>The place a control's change shows in: the bottom bar for an action, the menu for a menu tile, else the card.</summary>
    /// <param name="Control">The control.</param>
    /// <returns>The place token.</returns>
    local procedure WhereOf(Control: Record "BJF MN Config Line" temporary): Text
    begin
        if Control."Action Type" in [this.ButtonKindTok, this.LinkKindTok, this.PrintKindTok] then
            exit(this.WhereBottomTok);
        if Control."Display In Menu" then
            exit(this.WhereMenuTok);
        exit(this.WhereCardTok);
    end;

    /// <summary>Adds the row for a control the provider adds.</summary>
    /// <param name="Control">The new control.</param>
    local procedure AddedChange(Control: Record "BJF MN Config Line" temporary)
    begin
        this.AddChange(this.KindAddTok, this.WhereOf(Control), this.ChangeName(Control), this.AddedDetail(Control), Control."Control Name");
    end;

    /// <summary>The detail sentence for a control the provider adds.</summary>
    /// <param name="Control">The new control.</param>
    /// <returns>The sentence.</returns>
    local procedure AddedDetail(Control: Record "BJF MN Config Line" temporary): Text
    begin
        if (Control."Action Type" = this.LookupKindTok) and (Control."Service Name" <> '') then
            exit(StrSubstNo(this.AddedPickedLbl, this.TargetTitle(Control)));
        case Control."Action Type" of
            this.LinkKindTok:
                exit(StrSubstNo(this.AddedLinkLbl, this.TargetTitle(Control)));
            this.PrintKindTok:
                exit(this.AddedPrintLbl);
            this.ButtonKindTok:
                exit(this.AddedButtonLbl);
        end;
        if Control."Display In Menu" then
            exit(this.AddedMenuLbl);
        exit(this.AddedFieldLbl);
    end;

    /// <summary>The name a change sentence uses for a control: its caption, else its stored name, spaced.</summary>
    /// <param name="Control">The control.</param>
    /// <returns>The name.</returns>
    local procedure ChangeName(Control: Record "BJF MN Config Line" temporary): Text
    begin
        if Control.Description <> '' then
            exit(Control.Description);
        exit(this.Humanize(Control."Control Name"));
    end;

    /// <summary>The CSS classes of the marker a control the provider adds, changes or removes, with a leading space. Empty for the others.</summary>
    /// <param name="StoredName">The stored control name.</param>
    /// <returns>The classes.</returns>
    local procedure ChangeClass(StoredName: Text): Text
    var
        Change: Text;
    begin
        if not this.ControlChanges.Get(LowerCase(StoredName), Change) then
            exit('');
        case Change of
            this.InsertChangeTok:
                exit(' ' + this.NewChangeClassTok);
            this.RemoveChangeTok:
                exit(' ' + this.RemovedChangeClassTok + ' ' + this.RemovedClassTok);
        end;
        exit(' ' + this.ChangedChangeClassTok);
    end;

    /// <summary>Whether the provider hides a control that MobileNAV shows. The device draws it greyed inside a red outline.</summary>
    /// <param name="StoredName">The stored control name.</param>
    /// <returns>True for a removed control.</returns>
    local procedure IsRemoved(StoredName: Text): Boolean
    var
        Change: Text;
    begin
        if not this.ControlChanges.Get(LowerCase(StoredName), Change) then
            exit(false);
        exit(Change = this.RemoveChangeTok);
    end;

    /// <summary>The change detail of a control, which the tooltip of the control shows.</summary>
    /// <param name="StoredName">The stored control name.</param>
    /// <returns>The detail, empty when nothing changes the control.</returns>
    local procedure ChangeDetailOf(StoredName: Text): Text
    var
        Detail: Text;
    begin
        if this.ChangeDetails.Get(this.NameKey(StoredName), Detail) then
            exit(Detail);
        exit('');
    end;

    /// <summary>A title attribute that shows a tooltip, empty when there is no text.</summary>
    /// <param name="Detail">The tooltip text.</param>
    /// <returns>The attribute with a leading space, or empty.</returns>
    local procedure TitleAttr(Detail: Text): Text
    begin
        if Detail = '' then
            exit('');
        exit(StrSubstNo(this.TitleAttrTok, this.Escape(Detail)));
    end;

    /// <summary>The number of rows in the change table, which is the change count on the summary.</summary>
    /// <returns>The number of changes.</returns>
    local procedure ChangeCount(): Integer
    begin
        exit(this.ChangeKinds.Count());
    end;

    /// <summary>The table of what the provider changes on the page. Its rows run added, changed, removed.</summary>
    /// <returns>The section HTML, empty when the provider changes nothing on the page.</returns>
    local procedure ChangesHtml(): Text
    begin
        exit(this.ChangeTableHtml(this.ChangeKinds, this.ChangeWheres, this.ChangeItems, this.ChangeDetailTexts, this.ChangesHeadLbl));
    end;

    /// <summary>A change table under a heading. The rows run added, changed, removed.</summary>
    /// <param name="Kinds">The kind of each change: Added, Changed or Removed.</param>
    /// <param name="Wheres">Where each change shows.</param>
    /// <param name="Items">The item each change touches.</param>
    /// <param name="Details">What each change does.</param>
    /// <param name="Heading">The heading above the table.</param>
    /// <returns>The table HTML, empty when there are no changes.</returns>
    local procedure ChangeTableHtml(Kinds: List of [Text]; Wheres: List of [Text]; Items: List of [Text]; Details: List of [Text]; Heading: Text): Text
    var
        Html: TextBuilder;
        Rows: TextBuilder;
    begin
        this.AppendChangeRows(Rows, Kinds, Wheres, Items, Details, this.KindAddTok);
        this.AppendChangeRows(Rows, Kinds, Wheres, Items, Details, this.KindChangeTok);
        this.AppendChangeRows(Rows, Kinds, Wheres, Items, Details, this.KindRemoveTok);
        if Rows.Length() = 0 then
            exit('');
        Html.Append(StrSubstNo(this.ChangesStartTok, Heading));
        Html.Append(StrSubstNo(this.ChangeTableTok, this.Escape(this.ChangeHeadKindLbl), this.Escape(this.ChangeHeadWhereLbl),
            this.Escape(this.ChangeHeadItemLbl), this.Escape(this.ChangeHeadDetailLbl), Rows.ToText()));
        Html.Append(this.DivEndTok);
        exit(Html.ToText());
    end;

    /// <summary>Appends the rows of one kind of change to the table.</summary>
    /// <param name="Rows">Receives the rows.</param>
    /// <param name="Kinds">The kind of each change.</param>
    /// <param name="Wheres">Where each change shows.</param>
    /// <param name="Items">The item each change touches.</param>
    /// <param name="Details">What each change does.</param>
    /// <param name="WantedKind">The kind to append: Added, Changed or Removed.</param>
    local procedure AppendChangeRows(var Rows: TextBuilder; Kinds: List of [Text]; Wheres: List of [Text]; Items: List of [Text]; Details: List of [Text]; WantedKind: Text)
    var
        Index: Integer;
    begin
        for Index := 1 to Kinds.Count() do
            if Kinds.Get(Index) = WantedKind then
                Rows.Append(this.ChangeRowHtml(Kinds.Get(Index), Wheres.Get(Index), Items.Get(Index), Details.Get(Index)));
    end;

    /// <summary>One row of the change table.</summary>
    /// <param name="Kind">Added, Changed or Removed.</param>
    /// <param name="PlaceWhere">The place token of the change.</param>
    /// <param name="ItemText">The item the change touches.</param>
    /// <param name="Detail">What the change does.</param>
    /// <returns>The row HTML.</returns>
    local procedure ChangeRowHtml(Kind: Text; PlaceWhere: Text; ItemText: Text; Detail: Text): Text
    var
        WhereText: Text;
    begin
        WhereText := this.WhereLabel(PlaceWhere);
        if PlaceWhere = this.WhereHomeTok then
            WhereText := this.WhereHomeLbl;
        exit(StrSubstNo(this.ChangeRowTok, LowerCase(Kind), this.Escape(this.KindLabel(Kind)), this.Escape(WhereText),
            this.Escape(ItemText), this.Escape(Detail)));
    end;

    local procedure KindLabel(Kind: Text): Text
    begin
        case Kind of
            this.KindAddTok:
                exit(this.KindAddLbl);
            this.KindChangeTok:
                exit(this.KindChangeLbl);
        end;
        exit(this.KindRemoveLbl);
    end;

    local procedure WhereLabel(PlaceWhere: Text): Text
    begin
        case PlaceWhere of
            this.WhereListTok:
                exit(this.WhereListLbl);
            this.WhereCardTok:
                exit(this.WhereCardLbl);
            this.WhereMenuTok:
                exit(this.WhereMenuLbl);
            this.WhereBottomTok:
                exit(this.WhereBottomLbl);
            this.WhereFilterTok:
                exit(this.WhereFilterLbl);
            this.WhereSortTok:
                exit(this.WhereSortLbl);
        end;
        exit(this.WhereRuleLbl);
    end;

    /// <summary>The page type in words, for example List and card for ListCard.</summary>
    /// <param name="PageType">The page type option member.</param>
    /// <returns>The words.</returns>
    local procedure PageTypeWords(PageType: Text): Text
    var
        Words: Text;
        Piece: Text;
        Index: Integer;
    begin
        if PageType = this.ListCardTypeTok then
            exit(this.ListAndCardLbl);
        if PageType = this.OfflineTypeTok then
            exit(this.OfflineListLbl);
        for Index := 1 to StrLen(PageType) do begin
            Piece := CopyStr(PageType, Index, 1);
            if (Index > 1) and (Piece <> LowerCase(Piece)) then
                Words += ' ';
            Words += LowerCase(Piece);
        end;
        exit(UpperCase(CopyStr(Words, 1, 1)) + CopyStr(Words, 2));
    end;

    // ---- Card views ---------------------------------------------------------------------

    local procedure AppendCardViews(var Html: TextBuilder)
    var
        StageIndex: Integer;
    begin
        if this.IsDialog() then begin
            Html.Append(this.Phone(this.CurrentTitle, this.DialogLbl, this.CardBody(0), this.MenuHtml(0), false, '', '', ''));
            exit;
        end;
        if this.StageCodes.Count() = 0 then begin
            Html.Append(this.Phone(this.CurrentTitle, this.CardLbl, this.CardBody(0), this.MenuHtml(0), false, '', '', ''));
            exit;
        end;
        for StageIndex := 1 to this.StageCodes.Count() do
            Html.Append(this.Phone(this.CurrentTitle, StrSubstNo(this.CardStageLbl, StageIndex), this.StageHead(StageIndex) + this.CardBody(StageIndex),
                this.MenuHtml(StageIndex), false, '', '', ''));
    end;

    local procedure StageHead(StageIndex: Integer): Text
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        AutoNote: Text;
    begin
        if (StageIndex = 1) and this.PageFlag(ServiceSetup.FieldNo("Auto Next Stage")) then
            AutoNote := this.Escape(this.MovesOnLbl);
        exit(StrSubstNo(this.StageHeadTok, this.Escape(this.StageCodes.Get(StageIndex)),
            this.Escape(StrSubstNo(this.StageOfLbl, StageIndex, this.StageCodes.Count())),
            this.Escape(this.StageCaptions.Get(StageIndex)), AutoNote));
    end;

    local procedure CardBody(StageIndex: Integer): Text
    var
        Body: TextBuilder;
    begin
        this.AppendSection(Body, this.MandatorySectionTok, StageIndex);
        this.AppendSection(Body, this.StandardSectionTok, StageIndex);
        this.AppendSection(Body, this.AdditionalSectionTok, StageIndex);
        exit(Body.ToText());
    end;

    /// <summary>One importance section of the card. Only the additional section gets a heading, the Show more divider the device draws.</summary>
    /// <param name="Body">Receives the section.</param>
    /// <param name="Section">The section's CSS class.</param>
    /// <param name="StageIndex">The stage drawn, 0 for a card without stages.</param>
    local procedure AppendSection(var Body: TextBuilder; Section: Text; StageIndex: Integer)
    var
        TempIter: Record "BJF MN Config Line" temporary;
        Items: TextBuilder;
        LastGroup: Code[20];
        Token: Text;
    begin
        LastGroup := '';
        TempIter.Copy(this.TempControl, true);
        TempIter.Reset();
        if TempIter.FindSet() then
            repeat
                if this.OnCard(TempIter, StageIndex, Token) and (this.SectionOf(TempIter) = Section) then begin
                    if TempIter."Group Code" <> LastGroup then
                        Items.Append(this.GroupHeading(TempIter."Group Code"));
                    LastGroup := TempIter."Group Code";
                    Items.Append(this.ControlHtml(TempIter, Token));
                end;
            until TempIter.Next() = 0;
        if Items.Length() = 0 then
            exit;
        Body.Append(this.SectionHeading(Section));
        Body.Append(Items.ToText());
    end;

    /// <summary>The heading above a section. Only the additional section has one.</summary>
    /// <param name="Section">The section's CSS class.</param>
    /// <returns>The heading's HTML, empty for the mandatory and standard sections.</returns>
    local procedure SectionHeading(Section: Text): Text
    begin
        if Section <> this.AdditionalSectionTok then
            exit('');
        exit(StrSubstNo(this.SectionHeadTok, Section, this.Escape(this.AdditionalSectionLbl)));
    end;

    local procedure GroupHeading(GroupCode: Code[20]): Text
    begin
        if (GroupCode = '') or (UpperCase(GroupCode) = this.StandardGroupTok) then
            exit(this.GroupEndTok);
        exit(StrSubstNo(this.GroupHeadTok, this.Escape(GroupCode), this.Escape(this.CategoryCaption(GroupCode))));
    end;

    local procedure OnCard(Control: Record "BJF MN Config Line" temporary; StageIndex: Integer; var Token: Text): Boolean
    begin
        Token := '';
        if this.IsMenuEntry(Control) then
            exit(false);
        exit(this.ShownInStage(Control, StageIndex, Token));
    end;

    local procedure ShownInStage(Control: Record "BJF MN Config Line" temporary; StageIndex: Integer; var Token: Text): Boolean
    begin
        Token := '';
        if Control."Action Type" = this.ChannelKindTok then
            exit(false);
        if (not Control.Visible) and (not this.IsRemoved(Control."Control Name")) then
            exit(false);
        if StageIndex = 0 then
            exit(true);
        Token := this.StageToken(Control, StageIndex);
        exit(Token <> this.StageManagement.HiddenToken());
    end;

    local procedure IsMenuEntry(Control: Record "BJF MN Config Line" temporary): Boolean
    begin
        exit(Control."Display In Menu" or (Control."Action Type" in [this.ButtonKindTok, this.LinkKindTok, this.PrintKindTok]));
    end;

    local procedure SectionOf(Control: Record "BJF MN Config Line" temporary): Text
    begin
        if Control.Importance in [this.MandatorySectionTok, this.RequiredForInsertTok] then
            exit(this.MandatorySectionTok);
        if Control.Importance = this.AdditionalSectionTok then
            exit(this.AdditionalSectionTok);
        exit(this.StandardSectionTok);
    end;

    /// <summary>One card control. The stage token makes it read-only when R.</summary>
    /// <param name="Control">The control.</param>
    /// <param name="Token">The control's entry in the stage drawn.</param>
    /// <returns>The control's HTML.</returns>
    local procedure ControlHtml(Control: Record "BJF MN Config Line" temporary; Token: Text): Text
    var
        Classes: Text;
        CaptionStyle: Text;
        ValueStyle: Text;
        ReadOnlyTag: Text;
        IsEditable: Boolean;
    begin
        IsEditable := Control.Editable and (Token <> this.StageManagement.ReadOnlyToken());
        this.RuleMarks(Control."Control Name", Classes, CaptionStyle, ValueStyle);
        Classes += this.ChangeClass(Control."Control Name");
        if (not IsEditable) and (Control."Action Type" <> this.MediaKindTok) then
            ReadOnlyTag := StrSubstNo(this.TagTok, this.ReadOnlyClassTok, this.Escape(this.ReadOnlyLbl));
        exit(StrSubstNo(this.ControlTok, this.SectionOf(Control), Classes, this.Escape(Control."Control Name"), CaptionStyle,
            this.Escape(Control.Description), ReadOnlyTag, this.ValueHtml(Control, IsEditable, ValueStyle),
            this.TitleAttr(this.ChangeDetailOf(Control."Control Name"))));
    end;

    local procedure ValueHtml(Control: Record "BJF MN Config Line" temporary; IsEditable: Boolean; ValueStyle: Text): Text
    var
        Value: Text;
        HasValue: Boolean;
    begin
        HasValue := this.CardValueOf(Control, Value);
        case Control."Action Type" of
            this.ScanKindTok:
                exit(this.ScanValueHtml(Control, Value, HasValue));
            this.QuantityKindTok:
                exit(StrSubstNo(this.QuantityValueTok, ValueStyle, this.DecreaseIconTok, this.IncreaseIconTok, this.ShownText(Value, HasValue, '0')));
            this.LookupKindTok:
                exit(StrSubstNo(this.LookupValueTok, this.EditClass(IsEditable), ValueStyle, this.DrillIconTok,
                    this.ShownText(Value, HasValue, StrSubstNo(this.PickFromLbl, this.TargetTitle(Control))), this.Escape(Control."Service Name")));
            this.DrillDownKindTok:
                exit(StrSubstNo(this.DrillDownValueTok, ValueStyle, this.ShownText(Value, HasValue, this.Sample(Control.Description)), this.DrillIconTok, this.Escape(this.TargetTitle(Control))));
            this.MediaKindTok:
                exit(this.MediaValueHtml(Control));
        end;
        exit(StrSubstNo(this.PlainValueTok, this.EditClass(IsEditable), ValueStyle, this.ShownText(Value, HasValue, this.Sample(Control.Description))));
    end;

    /// <summary>A scan field: its value on the left and a small scan icon on the right.</summary>
    /// <param name="Control">The scan control.</param>
    /// <param name="Value">The first record's value.</param>
    /// <param name="HasValue">Whether the value is a record value.</param>
    /// <returns>The value HTML.</returns>
    local procedure ScanValueHtml(Control: Record "BJF MN Config Line" temporary; Value: Text; HasValue: Boolean): Text
    var
        Hint: Text;
    begin
        Hint := this.ScanLbl;
        if Control."Validation Behavior" <> '' then
            Hint := StrSubstNo(this.ScanWithBehaviorLbl, Control."Validation Behavior");
        exit(StrSubstNo(this.ScanValueTok, this.TitleAttr(Hint), this.ShownText(Value, HasValue, this.Sample(Control.Description)), this.ScanIconTok));
    end;

    local procedure MediaValueHtml(Control: Record "BJF MN Config Line" temporary): Text
    begin
        if Control."Mobile Type" = this.SignatureMobileTypeTok then
            exit(StrSubstNo(this.MediaValueTok, this.SignatureIconTok, this.Escape(this.SignatureLbl)));
        exit(StrSubstNo(this.MediaValueTok, this.CameraIconTok, this.Escape(LowerCase(Control."Mobile Type"))));
    end;

    local procedure EditClass(IsEditable: Boolean): Text
    begin
        if IsEditable then
            exit(' ' + this.EditClassTok);
        exit('');
    end;

    local procedure TargetTitle(Control: Record "BJF MN Config Line" temporary): Text
    var
        TargetPageId: Integer;
    begin
        TargetPageId := Control."Target Page ID";
        if (TargetPageId = 0) and (Control."Service Name" <> '') then
            TargetPageId := this.ServiceLookup.GetPageId(Control."Service Name");
        if TargetPageId <> 0 then
            exit(this.PageCaption(TargetPageId));
        exit(Control."Service Name");
    end;

    /// <summary>The card's bottom bar. Up to four actions show as buttons. With more, the first three show and Show more opens the rest as a sheet.</summary>
    /// <param name="StageIndex">The stage drawn, 0 for a card without stages.</param>
    /// <returns>The bottom bar HTML, empty when the card has no buttons, links or prints.</returns>
    local procedure MenuHtml(StageIndex: Integer): Text
    var
        TempIter: Record "BJF MN Config Line" temporary;
        Buttons: TextBuilder;
        Sheet: TextBuilder;
        Token: Text;
        EntryCount: Integer;
        EntryNo: Integer;
        MoreId: Text;
    begin
        EntryCount := this.MenuEntryCount(StageIndex);
        if EntryCount = 0 then
            exit('');
        TempIter.Copy(this.TempControl, true);
        TempIter.Reset();
        if TempIter.FindSet() then
            repeat
                if this.IsMenuEntry(TempIter) and this.ShownInStage(TempIter, StageIndex, Token) then begin
                    EntryNo += 1;
                    this.AppendMenuEntry(Buttons, Sheet, TempIter, EntryNo, this.BottomButtonCount(EntryCount));
                end;
            until TempIter.Next() = 0;
        if EntryCount <= 4 then
            exit(StrSubstNo(this.BottomBarTok, Buttons.ToText()));
        // The Show more row sits above the bar. A checkbox, toggled by the Show more label, shows it.
        MoreId := this.NextElementId();
        Buttons.Append(StrSubstNo(this.ShowMoreTok, MoreId, this.MoreIconTok, this.Escape(this.ShowMoreLbl), this.Escape(this.ShowLessLbl)));
        exit(StrSubstNo(this.CheckTok, MoreId) + StrSubstNo(this.MoreRowTok, Sheet.ToText()) + StrSubstNo(this.BottomBarTok, Buttons.ToText()));
    end;

    /// <summary>How many actions show as bottom bar buttons: all of them up to four, otherwise three.</summary>
    /// <param name="EntryCount">The number of actions in the stage.</param>
    /// <returns>The number of buttons.</returns>
    local procedure BottomButtonCount(EntryCount: Integer): Integer
    begin
        if EntryCount <= 4 then
            exit(EntryCount);
        exit(3);
    end;

    /// <summary>Puts one action on the bottom bar, or in the Show more row when the bar is full.</summary>
    /// <param name="Buttons">Receives the bottom bar buttons.</param>
    /// <param name="Sheet">Receives the buttons of the Show more row.</param>
    /// <param name="Control">The action.</param>
    /// <param name="EntryNo">The action's place among the stage's actions, from 1.</param>
    /// <param name="ButtonCount">How many actions go on the bar as buttons.</param>
    local procedure AppendMenuEntry(var Buttons: TextBuilder; var Sheet: TextBuilder; Control: Record "BJF MN Config Line" temporary; EntryNo: Integer; ButtonCount: Integer)
    begin
        if EntryNo <= ButtonCount then
            Buttons.Append(this.BottomButtonHtml(Control))
        else
            Sheet.Append(this.BottomButtonHtml(Control));
    end;

    local procedure MenuEntryCount(StageIndex: Integer): Integer
    var
        TempIter: Record "BJF MN Config Line" temporary;
        Token: Text;
        Count: Integer;
    begin
        TempIter.Copy(this.TempControl, true);
        TempIter.Reset();
        if TempIter.FindSet() then
            repeat
                if this.IsMenuEntry(TempIter) and this.ShownInStage(TempIter, StageIndex, Token) then
                    Count += 1;
            until TempIter.Next() = 0;
        exit(Count);
    end;

    local procedure BottomButtonHtml(Control: Record "BJF MN Config Line" temporary): Text
    var
        Classes: Text;
        CaptionStyle: Text;
        ValueStyle: Text;
    begin
        this.RuleMarks(Control."Control Name", Classes, CaptionStyle, ValueStyle);
        Classes += this.ChangeClass(Control."Control Name");
        exit(StrSubstNo(this.BottomButtonTok, Classes, this.Escape(Control."Control Name"), this.ActionIconSvg(Control), this.Escape(Control.Description),
            this.TitleAttr(this.ChangeDetailOf(Control."Control Name"))));
    end;

    local procedure ActionIconSvg(Control: Record "BJF MN Config Line" temporary): Text
    begin
        if Control."Action Type" = this.LinkKindTok then
            exit(this.DocumentIconTok);
        if Control."Action Type" = this.PrintKindTok then
            exit(this.PrintIconTok);
        exit(this.ActionIconTok);
    end;

    /// <summary>The overview on a page's collapsed entry: the page type in words, the field count and the change count.</summary>
    /// <returns>The overview text.</returns>
    local procedure PageOverview(): Text
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        PageType: Text;
    begin
        PageType := this.PageValue(ServiceSetup.FieldNo("Page Type"));
        if PageType = '' then
            PageType := this.TypeUnknownLbl
        else
            PageType := this.PageTypeWords(PageType);
        exit(StrSubstNo(this.OverviewLbl, PageType,
            this.Counted(this.FieldCount(), this.FieldOneLbl, this.FieldManyLbl),
            this.Counted(this.ChangeCount(), this.ChangeOneLbl, this.ChangeManyLbl)));
    end;

    /// <summary>The visible fields of the page, without the buttons, links and prints that the card shows in its bottom bar.</summary>
    /// <returns>The number of fields.</returns>
    local procedure FieldCount(): Integer
    var
        TempIter: Record "BJF MN Config Line" temporary;
        Count: Integer;
    begin
        TempIter.Copy(this.TempControl, true);
        TempIter.Reset();
        if TempIter.FindSet() then
            repeat
                if TempIter.Visible and (not this.IsMenuEntry(TempIter)) then
                    Count += 1;
            until TempIter.Next() = 0;
        exit(Count);
    end;

    local procedure Counted(Count: Integer; OneLbl: Text; ManyLbl: Text): Text
    begin
        if Count = 1 then
            exit(StrSubstNo(OneLbl, Count));
        exit(StrSubstNo(ManyLbl, Count));
    end;

    // ---- Carousel and home screen -------------------------------------------------------

    /// <summary>The rules that show one slide of the carousel: slide N shows while radio N is checked.</summary>
    /// <param name="SlideCount">The number of slides.</param>
    /// <returns>The CSS rules.</returns>
    local procedure DeckCss(SlideCount: Integer): Text
    var
        Rules: TextBuilder;
        SlideNo: Integer;
    begin
        for SlideNo := 1 to SlideCount do
            Rules.Append(StrSubstNo(this.SlideShowTok, SlideNo));
        exit(Rules.ToText());
    end;

    /// <summary>The top of a slide: the arrows to the neighbouring slides and the slide title, for example 2 of 6: Items.</summary>
    /// <param name="SlideNo">The slide, from 1.</param>
    /// <param name="SlideCount">The number of slides.</param>
    /// <param name="Caption">The caption of the slide.</param>
    /// <returns>The slide's opening tags and top bar.</returns>
    local procedure SlideStart(SlideNo: Integer; SlideCount: Integer; Caption: Text): Text
    var
        PreviousArrow: Text;
        NextArrow: Text;
    begin
        PreviousArrow := this.ArrowSpaceTok;
        if SlideNo > 1 then
            PreviousArrow := StrSubstNo(this.ArrowTok, SlideNo - 1, this.Escape(this.PreviousLbl), this.PrevGlyphTok);
        NextArrow := this.ArrowSpaceTok;
        if SlideNo < SlideCount then
            NextArrow := StrSubstNo(this.ArrowTok, SlideNo + 1, this.Escape(this.NextLbl), this.NextGlyphTok);
        exit(StrSubstNo(this.SlideStartTok, SlideNo, PreviousArrow, this.Escape(StrSubstNo(this.SlideTitleTok, SlideNo, SlideCount, Caption)), NextArrow));
    end;

    /// <summary>The home screen slide: the profile's home screen as the device shows it, then the table of its changes.</summary>
    /// <param name="SlideNo">The slide number, 1.</param>
    /// <param name="SlideCount">The number of slides.</param>
    /// <returns>The slide HTML.</returns>
    local procedure HomeSlideHtml(SlideNo: Integer; SlideCount: Integer): Text
    var
        Html: TextBuilder;
    begin
        Html.Append(this.SlideStart(SlideNo, SlideCount, this.HomeScreenLbl));
        Html.Append(StrSubstNo(this.SummaryTok, this.Escape(this.HomeOverview())));
        Html.Append(this.PhonesStartTok);
        Html.Append(this.HomePhone());
        Html.Append(this.DivEndTok);
        Html.Append(this.ChangeTableHtml(this.HomeKinds, this.HomeWheres, this.HomeItems, this.HomeDetails, this.HomeChangesHeadLbl));
        Html.Append(this.SlideEndTok);
        exit(Html.ToText());
    end;

    /// <summary>The summary line of the home screen: its tile count and its change count.</summary>
    /// <returns>The summary text.</returns>
    local procedure HomeOverview(): Text
    begin
        exit(StrSubstNo(this.HomeOverviewLbl, this.Counted(this.HomeServices.Count(), this.TileOneLbl, this.TileManyLbl),
            this.Counted(this.HomeKinds.Count(), this.ChangeOneLbl, this.ChangeManyLbl)));
    end;

    /// <summary>The home screen phone: the menu groups with their headers, each with its tile grid.</summary>
    /// <returns>The phone HTML.</returns>
    local procedure HomePhone(): Text
    var
        Body: TextBuilder;
        GroupCodes: List of [Text];
        GroupCode: Text;
        Index: Integer;
    begin
        for Index := 1 to this.HomeServices.Count() do
            if not GroupCodes.Contains(this.HomeGroups.Get(Index)) then
                GroupCodes.Add(this.HomeGroups.Get(Index));
        if this.HomeServices.Count() = 0 then
            Body.Append(StrSubstNo(this.EmptyNoteTok, this.Escape(this.NoHomeTilesLbl)));
        foreach GroupCode in GroupCodes do
            Body.Append(this.HomeGroupHtml(GroupCode));
        exit(this.Phone(this.HomeScreenLbl, '', Body.ToText(), '', false, '', '', ''));
    end;

    /// <summary>One menu group of the home screen: its header when it has a name, and its tiles.</summary>
    /// <param name="GroupCode">The group code, empty for the tiles outside a group.</param>
    /// <returns>The group HTML.</returns>
    local procedure HomeGroupHtml(GroupCode: Text): Text
    var
        Html: TextBuilder;
        Tiles: Text;
        Index: Integer;
    begin
        if GroupCode <> '' then
            Html.Append(StrSubstNo(this.GroupHeadTok, this.Escape(GroupCode), this.Escape(this.CategoryCaption(CopyStr(GroupCode, 1, 100)))));
        for Index := 1 to this.HomeServices.Count() do
            if this.HomeGroups.Get(Index) = GroupCode then
                Tiles += this.HomeTileHtml(Index);
        Html.Append(StrSubstNo(this.TilesTok, Tiles));
        exit(Html.ToText());
    end;

    /// <summary>One tile of the home screen, outlined when the provider adds, moves or takes it off.</summary>
    /// <param name="Index">The tile, from 1.</param>
    /// <returns>The tile HTML.</returns>
    local procedure HomeTileHtml(Index: Integer): Text
    begin
        exit(StrSubstNo(this.HomeTileTok, this.HomeClass(this.HomeStates.Get(Index)), this.Escape(this.HomeServices.Get(Index)),
            this.TitleAttr(this.HomeTitles.Get(Index)), this.ActionIconTok, this.Escape(this.HomeCaptions.Get(Index))));
    end;

    /// <summary>The outline class of a tile for its kind of change.</summary>
    /// <param name="State">Added, Changed, Removed, or empty for a tile the provider leaves alone.</param>
    /// <returns>The CSS class, empty for none.</returns>
    local procedure HomeClass(State: Text): Text
    begin
        case State of
            this.KindAddTok:
                exit(this.AddedChangeClassTok);
            this.KindChangeTok:
                exit(this.ChangedChangeClassTok);
            this.KindRemoveTok:
                exit(this.RemovedChangeClassTok);
        end;
        exit('');
    end;

    /// <summary>The name of a menu group in a sentence: its caption, or no group.</summary>
    /// <param name="GroupCode">The group code, empty for no group.</param>
    /// <returns>The name.</returns>
    local procedure GroupName(GroupCode: Text): Text
    begin
        if GroupCode = '' then
            exit(this.NoGroupLbl);
        exit(this.CategoryCaption(CopyStr(GroupCode, 1, 100)));
    end;

    /// <summary>Collects the home screen. MobileNAV's live menu tiles come first, then the declared pages that are not in the live menu. A tile is marked when the provider adds it, moves it to another group or takes it off, and each mark is a row of the home change table.</summary>
    /// <param name="PageIds">The declared pages of the provider.</param>
    local procedure CollectHome(PageIds: List of [Integer])
    var
        ServiceName: Text;
    begin
        Clear(this.HomeServices);
        Clear(this.HomeStates);
        Clear(this.HomeGroups);
        Clear(this.HomeCaptions);
        Clear(this.HomeTitles);
        Clear(this.HomeKinds);
        Clear(this.HomeWheres);
        Clear(this.HomeItems);
        Clear(this.HomeDetails);
        Clear(this.HomeLiveServices);
        Clear(this.HomeServiceNames);
        Clear(this.HomeLiveGroup);
        Clear(this.HomeAfterGroup);
        Clear(this.HomeLiveObject);
        Clear(this.HomeDeclaredPage);
        this.LoadLiveMenu();
        this.OverlayDeclaredPages(PageIds);
        foreach ServiceName in this.HomeServiceNames do
            this.AddHomeTile(ServiceName);
    end;

    /// <summary>Reads the tiles MobileNAV shows in the menu now: the Main rows of the pages in the menu.</summary>
    local procedure LoadLiveMenu()
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        ServiceName: Text;
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        ServiceSetup.SetRange(DisplayInMenu, true);
        ServiceSetup.SetLoadFields("Service Name", "Object ID", Category);
        if ServiceSetup.FindSet() then
            repeat
                ServiceName := ServiceSetup."Service Name";
                if not this.HomeLiveGroup.ContainsKey(ServiceName) then begin
                    this.HomeLiveServices.Add(ServiceName);
                    this.HomeLiveGroup.Add(ServiceName, Format(ServiceSetup.Category));
                    this.HomeAfterGroup.Add(ServiceName, Format(ServiceSetup.Category));
                    this.HomeLiveObject.Add(ServiceName, ServiceSetup."Object ID");
                end;
            until ServiceSetup.Next() = 0;
        this.HomeServiceNames := this.HomeLiveServices;
    end;

    /// <summary>Lays the declared pages over the live menu: a declared page is in the menu when the provider shows it there, and it takes the group the provider gives it.</summary>
    /// <param name="PageIds">The declared pages of the provider.</param>
    local procedure OverlayDeclaredPages(PageIds: List of [Integer])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        PageId: Integer;
        ServiceName: Text;
    begin
        foreach PageId in PageIds do begin
            this.LoadMainValues(PageId);
            ServiceName := this.CurrentServiceName;
            if not this.HomeDeclaredPage.ContainsKey(ServiceName) then
                this.HomeDeclaredPage.Add(ServiceName, PageId);
            if not this.HomeServiceNames.Contains(ServiceName) then
                this.HomeServiceNames.Add(ServiceName);
            if this.PageFlag(ServiceSetup.FieldNo(DisplayInMenu)) then
                this.HomeAfterGroup.Set(ServiceName, this.PageValue(ServiceSetup.FieldNo(Category)))
            else
                if this.HomeAfterGroup.ContainsKey(ServiceName) then
                    this.HomeAfterGroup.Remove(ServiceName);
        end;
    end;

    /// <summary>Adds one tile to the home screen, with its state, and a change row when the provider changes it.</summary>
    /// <param name="ServiceName">The service of the tile.</param>
    local procedure AddHomeTile(ServiceName: Text)
    var
        LiveGroup: Text;
        AfterGroup: Text;
        TileGroup: Text;
        State: Text;
        Caption: Text;
        Detail: Text;
        LiveShown: Boolean;
        AfterShown: Boolean;
    begin
        LiveShown := this.HomeLiveGroup.ContainsKey(ServiceName);
        AfterShown := this.HomeAfterGroup.ContainsKey(ServiceName);
        if (not LiveShown) and (not AfterShown) then
            exit;
        if LiveShown then
            this.HomeLiveGroup.Get(ServiceName, LiveGroup);
        if AfterShown then
            this.HomeAfterGroup.Get(ServiceName, AfterGroup);
        State := this.HomeTileState(LiveShown, AfterShown, LiveGroup, AfterGroup);
        Caption := this.TileCaption(ServiceName);
        TileGroup := LiveGroup;
        if AfterShown then
            TileGroup := AfterGroup;
        Detail := this.HomeTileDetail(State, LiveGroup, AfterGroup);
        this.HomeServices.Add(ServiceName);
        this.HomeStates.Add(State);
        this.HomeGroups.Add(TileGroup);
        this.HomeCaptions.Add(Caption);
        this.HomeTitles.Add(Detail);
        if State <> '' then begin
            this.HomeKinds.Add(State);
            this.HomeWheres.Add(this.WhereHomeTok);
            this.HomeItems.Add(Caption);
            this.HomeDetails.Add(Detail);
        end;
    end;

    /// <summary>The caption of a tile: the declared caption of a declared page, else the MobileNAV caption of the live page.</summary>
    /// <param name="ServiceName">The service of the tile.</param>
    /// <returns>The caption.</returns>
    local procedure TileCaption(ServiceName: Text): Text
    var
        PageId: Integer;
    begin
        if this.HomeDeclaredPage.ContainsKey(ServiceName) then begin
            this.HomeDeclaredPage.Get(ServiceName, PageId);
            exit(this.PageCaption(PageId));
        end;
        this.HomeLiveObject.Get(ServiceName, PageId);
        exit(this.PageCaption(PageId));
    end;

    /// <summary>The state of a tile: added, removed, changed when its group changes, else empty.</summary>
    /// <param name="LiveShown">The tile is in the live menu.</param>
    /// <param name="AfterShown">The tile is in the menu after the provider.</param>
    /// <param name="LiveGroup">The group in the live menu.</param>
    /// <param name="AfterGroup">The group after the provider.</param>
    /// <returns>Added, Removed, Changed, or empty.</returns>
    local procedure HomeTileState(LiveShown: Boolean; AfterShown: Boolean; LiveGroup: Text; AfterGroup: Text): Text
    begin
        if not LiveShown then
            exit(this.KindAddTok);
        if not AfterShown then
            exit(this.KindRemoveTok);
        if LiveGroup <> AfterGroup then
            exit(this.KindChangeTok);
        exit('');
    end;

    /// <summary>What a tile change does, in words for the home change table.</summary>
    /// <param name="State">Added, Removed, Changed, or empty.</param>
    /// <param name="LiveGroup">The group in the live menu.</param>
    /// <param name="AfterGroup">The group after the provider.</param>
    /// <returns>The detail text, empty when the tile does not change.</returns>
    local procedure HomeTileDetail(State: Text; LiveGroup: Text; AfterGroup: Text): Text
    begin
        if State = this.KindAddTok then begin
            if AfterGroup = '' then
                exit(this.HomeAddedNoGroupLbl);
            exit(StrSubstNo(this.HomeAddedLbl, this.GroupName(AfterGroup)));
        end;
        if State = this.KindChangeTok then
            exit(StrSubstNo(this.HomeMovedLbl, this.GroupName(LiveGroup), this.GroupName(AfterGroup)));
        if State = this.KindRemoveTok then
            exit(this.HomeHiddenLbl);
        exit('');
    end;

    local procedure RuleConditions(LayoutCode: Text): Text
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Conditions: TextBuilder;
    begin
        if this.FindDeclared(TempLine, Enum::"BJF MN Config Operation"::"Layout Condition", this.CurrentPageId, LayoutCode) then
            repeat
                if Conditions.Length() > 0 then
                    Conditions.Append(this.AndLbl);
                Conditions.Append(this.ConditionText(TempLine));
            until TempLine.Next() = 0;
        if Conditions.Length() = 0 then
            exit(this.AlwaysLbl);
        exit(Conditions.ToText());
    end;

    // ---- HTML helpers -------------------------------------------------------------------

    /// <summary>One phone screen: the top bar, the scrolling body, the create button and the bottom bar. A list also gets a sheet under the menu icon, opened by a checkbox.</summary>
    /// <param name="PageTitle">The page caption, in bold in the top bar.</param>
    /// <param name="ViewName">The view name, in small text in the top bar.</param>
    /// <param name="Body">The screen content.</param>
    /// <param name="Bottom">The bottom bar HTML, empty for none.</param>
    /// <param name="ShowCreate">True draws the create button.</param>
    /// <param name="MenuDot">The dot HTML on the menu icon, empty for none.</param>
    /// <param name="SheetId">The element ID of the sheet's checkbox, used when there is a sheet.</param>
    /// <param name="SheetRows">The rows of the sheet, empty for no sheet.</param>
    /// <returns>The phone HTML.</returns>
    local procedure Phone(PageTitle: Text; ViewName: Text; Body: Text; Bottom: Text; ShowCreate: Boolean; MenuDot: Text; SheetId: Text; SheetRows: Text): Text
    var
        Fab: Text;
        ScreenClass: Text;
        CheckBox: Text;
        MenuElement: Text;
        Sheet: Text;
    begin
        if ShowCreate then begin
            Fab := this.FabTok;
            ScreenClass := ' withfab';
        end;
        if SheetRows = '' then
            MenuElement := StrSubstNo(this.MenuSpanTok, this.MenuIconTok, MenuDot)
        else begin
            CheckBox := StrSubstNo(this.CheckTok, SheetId);
            MenuElement := StrSubstNo(this.MenuLabelTok, SheetId, this.Escape(this.FilterSheetLbl), this.MenuIconTok, MenuDot);
            Sheet := StrSubstNo(this.SheetLayerTok, this.Escape(this.FilterSheetLbl), SheetRows);
        end;
        exit(StrSubstNo(this.PhoneTok, CheckBox, this.BackIconTok, this.Escape(PageTitle), this.Escape(ViewName), MenuElement,
            ScreenClass, Body, Fab, Bottom, Sheet));
    end;

    /// <summary>An element ID for a checkbox or a radio button of the drawing. The IDs are unique in one document.</summary>
    /// <returns>The ID.</returns>
    local procedure NextElementId(): Text
    begin
        this.ElementSeq += 1;
        exit(StrSubstNo(this.ElementIdTok, this.ElementSeq));
    end;

    local procedure Sample(Caption: Text): Text
    begin
        exit(StrSubstNo(this.SampleTok, Caption));
    end;

    local procedure Escape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace('''', '&#39;'));
    end;

    local procedure Humanize(StoredName: Text): Text
    var
        Result: Text;
    begin
        Result := StoredName.Replace('_', ' ');
        while Result.Contains('  ') do
            Result := Result.Replace('  ', ' ');
        exit(Result.Trim());
    end;

    local procedure NameKey(ControlName: Text): Text
    begin
        if ControlName = '' then
            exit('');
        exit(LowerCase(this.ServiceLookup.StoredFieldName(ControlName)));
    end;

    local procedure FindDeclared(var TempLine: Record "BJF MN Config Line" temporary; LineOperation: Enum "BJF MN Config Operation"; PageId: Integer): Boolean
    begin
        TempLine.Copy(this.TempDefinitionLine, true);
        TempLine.Reset();
        TempLine.SetRange(Operation, LineOperation);
        TempLine.SetRange("Page ID", PageId);
        exit(TempLine.FindSet());
    end;

    /// <summary>The provider's lines of one operation on a page for one control, in declaration order.</summary>
    /// <param name="TempLine">Receives the lines, positioned on the first.</param>
    /// <param name="LineOperation">The operation.</param>
    /// <param name="PageId">The page object ID, 0 for lines that belong to no page.</param>
    /// <param name="ControlName">The control name as declared, empty for the page's own lines.</param>
    /// <returns>True when the provider declares such a line.</returns>
    local procedure FindDeclared(var TempLine: Record "BJF MN Config Line" temporary; LineOperation: Enum "BJF MN Config Operation"; PageId: Integer; ControlName: Text): Boolean
    begin
        TempLine.Copy(this.TempDefinitionLine, true);
        TempLine.Reset();
        TempLine.SetRange(Operation, LineOperation);
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange("Control Name", ControlName);
        exit(TempLine.FindSet());
    end;

    local procedure HasDeclared(LineOperation: Enum "BJF MN Config Operation"): Boolean
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        exit(this.FindDeclared(TempLine, LineOperation, this.CurrentPageId));
    end;

    local procedure Css(): Text
    var
        Style: TextBuilder;
    begin
        Style.Append(this.ThemeCss());
        Style.Append(this.CssPageTok);
        Style.Append(this.CssPhoneTok);
        Style.Append(this.CssListTok);
        Style.Append(this.CssCardTok);
        Style.Append(this.CssControlTok);
        Style.Append(this.CssBottomTok);
        Style.Append(this.CssChangeTok);
        Style.Append(this.CssMarkTok);
        exit(Style.ToText());
    end;

    var
        TempDefinitionLine: Record "BJF MN Config Line" temporary;
        TempDefinitionProperty: Record "BJF MN Config Property" temporary;
        TempControl: Record "BJF MN Config Line" temporary;
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ServiceLookup: Codeunit "BJF MN Service Lookup";
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        TranslationHelper: Codeunit "Translation Helper";
        Vocabulary: Codeunit "BJF MN Vocabulary";
        CardSource: RecordRef;
        ThemeColors: Dictionary of [Text, Text];
        CaptionLanguage: Code[10];
        CurrentPageId: Integer;
        CurrentServiceName: Text[100];
        CurrentTitle: Text;
        HasLiveRows: Boolean;
        WizardDeclared: Boolean;
        NextControlEntryNo: Integer;
        PageValues: Dictionary of [Integer, Text];
        DeclaredCaptions: Dictionary of [Text, Text];
        MetadataCaptions: Dictionary of [Text, Text];
        MobileNAVCaptions: Dictionary of [Integer, Text];
        ControlEntries: Dictionary of [Text, Integer];
        ControlCaptions: Dictionary of [Text, Text];
        ControlChanges: Dictionary of [Text, Text];
        DeclaredOrder: List of [Integer];
        FilterPaneCaptions: List of [Text];
        StageCodes: List of [Text];
        StageCaptions: List of [Text];
        StageShows: Dictionary of [Text, Text];
        LineFormatNumbers: List of [Integer];
        DeclaredFilterCaptions: List of [Text];
        ChangeKinds: List of [Text];
        ChangeWheres: List of [Text];
        ChangeItems: List of [Text];
        ChangeDetailTexts: List of [Text];
        ChangeDetails: Dictionary of [Text, Text];
        FlowFieldNos: Dictionary of [Text, Integer];
        HasCardRecord: Boolean;
        SourceFieldNos: Dictionary of [Text, Integer];
        CurrentTableNo: Integer;
        ListHasRows: Boolean;
        ListReadable: Boolean;
        InvalidFilters: Dictionary of [Text, Text];
        ElementSeq: Integer;
        HomeServices: List of [Text];
        HomeStates: List of [Text];
        HomeGroups: List of [Text];
        HomeCaptions: List of [Text];
        HomeTitles: List of [Text];
        HomeKinds: List of [Text];
        HomeWheres: List of [Text];
        HomeItems: List of [Text];
        HomeDetails: List of [Text];
        HomeLiveServices: List of [Text];
        HomeServiceNames: List of [Text];
        HomeLiveGroup: Dictionary of [Text, Text];
        HomeAfterGroup: Dictionary of [Text, Text];
        HomeLiveObject: Dictionary of [Text, Integer];
        HomeDeclaredPage: Dictionary of [Text, Integer];
        EnglishTok: Label 'ENU', Locked = true;
#pragma warning disable LC0086
        StandardImportanceTok: Label 'None', Locked = true;
        RequiredForInsertTok: Label 'RequiredForInsert', Locked = true;
        MandatorySectionTok: Label 'Mandatory', Locked = true;
        StandardSectionTok: Label 'Standard', Locked = true;
#pragma warning restore LC0086
        AdditionalSectionTok: Label 'Additional', Locked = true;
        FieldControlTok: Label 'FieldControl', Locked = true;
        SignatureMobileTypeTok: Label 'Signature', Locked = true;
        CreateActionTok: Label 'Create', Locked = true;
        OwnComparisonTok: Label 'Own', Locked = true;
        NotOwnComparisonTok: Label 'NotOwn', Locked = true;
        FieldFilterTypeTok: Label 'FIELD', Locked = true;
        FilterFilterTypeTok: Label 'FILTER', Locked = true;
        SeparatorElementTok: Label 'Separator', Locked = true;
        CaptionElementTok: Label 'Caption', Locked = true;
        HideFieldActionTok: Label 'HideField', Locked = true;
        FieldValueColorActionTok: Label 'FieldValueColor', Locked = true;
        FieldCaptionColorActionTok: Label 'FieldCaptionColor', Locked = true;
        GroupStartSuffixTok: Label '_Start', Locked = true;
        GroupEndSuffixTok: Label '_End', Locked = true;
        FieldKindTok: Label 'field', Locked = true;
        ButtonKindTok: Label 'button', Locked = true;
        LinkKindTok: Label 'link', Locked = true;
        LookupKindTok: Label 'lookup', Locked = true;
        DrillDownKindTok: Label 'drilldown', Locked = true;
        ScanKindTok: Label 'scan', Locked = true;
        QuantityKindTok: Label 'quantity', Locked = true;
        MediaKindTok: Label 'media', Locked = true;
        PrintKindTok: Label 'print', Locked = true;
        ChannelKindTok: Label 'channel', Locked = true;
        InsertChangeTok: Label 'Insert', Locked = true;
        ModifyChangeTok: Label 'Modify', Locked = true;
        StageKeyTok: Label '%1|%2', Locked = true, Comment = '%1 = stage code, %2 = control name';
        CustomColorPrefixTok: Label 'Custom', Locked = true;
        CustomColorsTok: Label '#d81b60,#8e24aa,#3949ab,#00897b,#7cb342,#fb8c00,#6d4c41,#546e7a,#c0ca33,#00acc1', Locked = true;
        DefaultColorTok: Label '#e65100', Locked = true;
        AreaNamesTok: Label 'ButtonTitleBackground,ButtonTitleForeground,HighlightBackground,HighlightForeground,DialogBorder,Separator,GroupSeparator,WindowBackground,WindowForeground,DisabledButtonBackground,DisabledButtonForeground,CardDisabledCaption,CardMandatoryCaption,CardValidatedCaption,PageBackground,PageForeground,TitleToolbarBackground,TitleToolbarForeground,HomeTileBackground,CardAdditionalCaption,ToolbarAdditionalCaption,Custom1,Custom2,Custom3,Custom4,Custom5,Custom6,Custom7,Custom8,Custom9,Custom10', Locked = true;
        AreaDefaultsTok: Label 'ButtonTitleBackground=#33A4E3,ButtonTitleForeground=#FFFFFF,HighlightBackground=#227DAF,HighlightForeground=#FFFFFF,DialogBorder=#11567B,Separator=#E0E0E0,GroupSeparator=#FFFFFF,WindowBackground=#E1F2FB,WindowForeground=#000000,DisabledButtonBackground=#AAAAAA,DisabledButtonForeground=#FFFFFF,CardDisabledCaption=#AAAAAA,CardMandatoryCaption=#A60D14,CardValidatedCaption=#008000,PageBackground=#FFFFFF,PageForeground=#000000,TitleToolbarBackground=#33A4E3,TitleToolbarForeground=#FFFFFF,HomeTileBackground=#FFFFFF,CardAdditionalCaption=#3F3F3F,ToolbarAdditionalCaption=#3F3F3F', Locked = true;
        ButtonTitleBackgroundTok: Label 'ButtonTitleBackground', Locked = true;
        ButtonTitleForegroundTok: Label 'ButtonTitleForeground', Locked = true;
        TitleToolbarBackgroundTok: Label 'TitleToolbarBackground', Locked = true;
        TitleToolbarForegroundTok: Label 'TitleToolbarForeground', Locked = true;
        ThemeRootTok: Label ':root{%1}', Locked = true, Comment = '%1 = the colour variables';
        ThemeVarTok: Label '--mn-%1:%2;', Locked = true, Comment = '%1 = colour area name, %2 = CSS color';
        DrawnSettingsTok: Label '%1|%2|%3|%4|%5|%6|%7|%8', Locked = true, Comment = '%1 = visible, %2 = editable, %3 = filterable, %4 = in menu, %5 = group, %6 = importance, %7 = mobile type, %8 = function name';
        TwoValuesTok: Label '%1 - %2', Locked = true, Comment = '%1 = first value, %2 = second value';
        ColorStyleTok: Label 'color:%1;font-weight:700', Locked = true, Comment = '%1 = CSS color';
        ReadOnlyClassTok: Label 'ro', Locked = true;
        ChangedClassTok: Label 'changed', Locked = true;
        EditClassTok: Label 'edit', Locked = true;
        InvalidClassTok: Label 'invalid', Locked = true;
        DocumentStartTok: Label '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%1</title><style>%2</style></head><body>', Locked = true, Comment = '%1 = title, %2 = CSS';
        DocumentEndTok: Label '</body></html>', Locked = true;
        ErrorBoxTok: Label '<div class="err" role="alert">%1</div>', Locked = true, Comment = '%1 = message';
        PhonesStartTok: Label '<div class="phones">', Locked = true;
        KindAddTok: Label 'Added', Locked = true;
        KindChangeTok: Label 'Changed', Locked = true;
        KindRemoveTok: Label 'Removed', Locked = true;
        WhereListTok: Label 'list', Locked = true;
        WhereCardTok: Label 'card', Locked = true;
        WhereMenuTok: Label 'menu', Locked = true;
        WhereBottomTok: Label 'bottom bar', Locked = true;
        WhereFilterTok: Label 'filter', Locked = true;
        WhereSortTok: Label 'sort', Locked = true;
        WhereRuleTok: Label 'rule', Locked = true;
        RemoveChangeTok: Label 'Remove', Locked = true;
        RemovedClassTok: Label 'removed', Locked = true;
        RemovedChangeClassTok: Label 'chg-removed', Locked = true;
        AddedClassTok: Label 'added', Locked = true;
        ChangeTableTok: Label '<table class="chgt"><thead><tr><th>%1</th><th>%2</th><th>%3</th><th>%4</th></tr></thead><tbody>%5</tbody></table>', Locked = true, Comment = '%1 = Change, %2 = Where, %3 = Item, %4 = Detail, %5 = rows';
        ChangeRowTok: Label '<tr><td><span class="kind %1">%2</span></td><td>%3</td><td>%4</td><td>%5</td></tr>', Locked = true, Comment = '%1 = change class, %2 = change, %3 = where, %4 = item, %5 = detail';
        DotTok: Label '<span class="dot %1"></span>', Locked = true, Comment = '%1 = change class';
        FilterRowTok: Label '<div class="frow"><b>%1</b><div class="fchips">%2</div></div>', Locked = true, Comment = '%1 = heading, %2 = chips';
        FieldChipTok: Label '<span class="chip%1">%2</span>', Locked = true, Comment = '%1 = classes with a leading space, %2 = name';
        TitleAttrTok: Label ' title="%1"', Locked = true, Comment = '%1 = tooltip text';
        ScanIconTok: Label '<svg viewBox="0 0 24 24"><path d="M3 9V5a2 2 0 0 1 2-2h4v2H5v4H3zm0 6h2v4h4v2H5a2 2 0 0 1-2-2v-4zm16-6V5h-4V3h4a2 2 0 0 1 2 2v4h-2zm0 6v4a2 2 0 0 1-2 2h-4v-2h4v-4h2zM7 11h10v2H7z"/></svg>', Locked = true;
        PhoneTok: Label '<div class="phone">%1<div class="bar"><span class="ic">%2</span><span class="ttl"><b>%3</b><span class="sm">%4</span></span>%5</div><div class="screen%6">%7%8</div>%9%10</div>', Locked = true, Comment = '%1 = sheet checkbox, %2 = back icon, %3 = page caption, %4 = view name, %5 = menu icon element, %6 = screen class, %7 = body, %8 = create button, %9 = bottom bar, %10 = sheet';
        FabTok: Label '<div class="fab" aria-hidden="true">+</div>', Locked = true;
        SavedFilterChipTok: Label '<span class="chip %1" title="%3">Filter: %2</span>', Locked = true, Comment = '%1 = classes, %2 = name, %3 = conditions';
        RowTok: Label '<div class="row %1">%2</div>', Locked = true, Comment = '%1 = classes, %2 = lines';
        FirstLineTok: Label '<div class="l1" title="%1">%2</div>', Locked = true, Comment = '%1 = cell name, %2 = text';
        OtherLineTok: Label '<div class="l2" title="%1">%2</div>', Locked = true, Comment = '%1 = cell name, %2 = text';
        NoteTok: Label '<div class="note %1">%2</div>', Locked = true, Comment = '%1 = classes, %2 = note';
        SampleTok: Label '‹%1›', Locked = true, Comment = '%1 = caption';
        ComparisonTok: Label '%1 %2 %3', Locked = true, Comment = '%1 = field, %2 = comparison, %3 = value';
        FieldReferenceTok: Label '[%1]', Locked = true, Comment = '%1 = field';
        SectionHeadTok: Label '<div class="sect %1">%2</div>', Locked = true, Comment = '%1 = section, %2 = title';
        GroupHeadTok: Label '<div class="grp" data-group="%1">%2</div>', Locked = true, Comment = '%1 = group code, %2 = caption';
        GroupEndTok: Label '<div class="grpend"></div>', Locked = true;
        ControlTok: Label '<div class="ctl %1 %2" data-control="%3"%8><div class="cap" style="%4">%5%6</div>%7<div class="name">%3</div></div>', Locked = true, Comment = '%1 = section, %2 = classes, %3 = stored name, %4 = caption style, %5 = caption, %6 = read-only tag, %7 = value, %8 = title attribute';
        TagTok: Label '<span class="tag %1">%2</span>', Locked = true, Comment = '%1 = class, %2 = text';
        PlainValueTok: Label '<div class="val%1" style="%2">%3</div>', Locked = true, Comment = '%1 = edit class, %2 = style, %3 = sample';
        ScanValueTok: Label '<div class="val scan edit"%1><span class="sv">%2</span><span class="scanic">%3</span></div>', Locked = true, Comment = '%1 = title attribute, %2 = value, %3 = scan icon';
        QuantityValueTok: Label '<div class="val qty"><span class="b">%2</span><span style="%1">%4</span><span class="b">%3</span></div>', Locked = true, Comment = '%1 = style, %2 = decrease icon, %3 = increase icon, %4 = value';
        LookupValueTok: Label '<div class="val lookup%1 dd" style="%2"><span class="vt">%4 <span class="name">%5</span></span><span class="lookup">%3</span></div>', Locked = true, Comment = '%1 = edit class, %2 = style, %3 = search icon, %4 = target, %5 = service';
        DrillDownValueTok: Label '<div class="val dd" style="%1"><span class="vt">%2</span><span class="lookup">%3 <span class="name">%4</span></span></div>', Locked = true, Comment = '%1 = style, %2 = sample, %3 = drill-down icon, %4 = target';
        MediaValueTok: Label '<div class="val media">%1 %2</div>', Locked = true, Comment = '%1 = icon, %2 = kind';
        SignatureIconTok: Label '<svg viewBox="0 0 24 24"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>', Locked = true;
        CameraIconTok: Label '<svg viewBox="0 0 24 24"><path d="M12 12m-3.2 0a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0-6.4 0M9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z"/></svg>', Locked = true;
        BottomBarTok: Label '<div class="bottom">%1</div>', Locked = true, Comment = '%1 = buttons';
        BottomButtonTok: Label '<div class="bb %1" data-control="%2"%5>%3<span class="bl">%4</span></div>', Locked = true, Comment = '%1 = classes, %2 = stored name, %3 = icon markup, %4 = caption, %5 = title attribute';
        ShowMoreTok: Label '<label class="bb more" for="%1">%2<span class="bl mo">%3</span><span class="bl ml">%4</span></label>', Locked = true, Comment = '%1 = element ID of the checkbox, %2 = icon markup, %3 = Show more, %4 = Show less';
        BackIconTok: Label '<svg viewBox="0 0 24 24"><path d="M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12z"/></svg>', Locked = true;
        MenuIconTok: Label '<svg viewBox="0 0 24 24"><path d="M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z"/></svg>', Locked = true;
        MoreIconTok: Label '<svg viewBox="0 0 48 48"><path d="M10.4 26.4q-1 0-1.7-.7T8 24q0-1 .7-1.7t1.7-.7q1 0 1.7.7t.7 1.7q0 1-.7 1.7t-1.7.7Zm13.6 0q-1 0-1.7-.7t-.7-1.7q0-1 .7-1.7t1.7-.7q1 0 1.7.7t.7 1.7q0 1-.7 1.7t-1.7.7Zm13.6 0q-1 0-1.7-.7t-.7-1.7q0-1 .7-1.7t1.7-.7q1 0 1.7.7T40 24q0 1-.7 1.7t-1.7.7Z"/></svg>', Locked = true;
        DrillIconTok: Label '<svg viewBox="0 0 48 48"><path d="m18.75 36-2.15-2.15 9.9-9.9-9.9-9.9 2.15-2.15L30.8 23.95Z"/></svg>', Locked = true;
        IncreaseIconTok: Label '<svg viewBox="131 -131 512 512"><path d="M412.8-2.6H362V100H259.4v50.9H362v102.6h50.9V150.8h102.6V100H412.8V-2.6z M387-131 c-141.3,0-256,114.7-256,256s114.7,256,256,256s256-114.7,256-256S528.3-131,387-131z M387,329.3c-113.1,0-204.3-91.3-204.3-204.3 S273.9-79.3,387-79.3S591.3,11.9,591.3,125S500.1,329.3,387,329.3z"/></svg>', Locked = true;
        DecreaseIconTok: Label '<svg viewBox="0 0 512 512"><path d="M256,488.7V512c141.4,0,256-114.6,256-256C512,114.6,397.4,0,256,0C114.6,0,0,114.6,0,256c0,141.4,114.6,256,256,256V488.7 v-23.3c-57.9,0-110.1-23.4-148.1-61.3C70,366.1,46.6,313.9,46.5,256c0-57.9,23.4-110.1,61.3-148.1c38-37.9,90.2-61.3,148.1-61.3 c57.9,0,110.1,23.4,148.1,61.3c37.9,38,61.3,90.2,61.3,148.1c0,57.9-23.4,110.1-61.3,148.1c-38,37.9-90.2,61.3-148.1,61.3V488.7z M116.4,279.3h279.3v-46.5H116.4V279.3z"/></svg>', Locked = true;
        DocumentIconTok: Label '<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>', Locked = true;
        PrintIconTok: Label '<svg viewBox="0 0 24 24"><path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/></svg>', Locked = true;
        ActionIconTok: Label '<svg viewBox="0 0 24 24"><path d="M7 2v11h3v9l7-12h-4l4-8z"/></svg>', Locked = true;
        ElementIdTok: Label 'el%1', Locked = true, Comment = '%1 = element number';
        DeckStartTok: Label '<div class="deck">', Locked = true;
        ViewerStartTok: Label '<div class="viewer">', Locked = true;
        RadioTok: Label '<input type="radio" name="deck" id="s%1" class="ri"%2>', Locked = true, Comment = '%1 = slide number, %2 = checked attribute';
        CheckedAttrTok: Label ' checked', Locked = true;
        SlideShowTok: Label '#s%1:checked ~ .viewer .k%1{display:block}', Locked = true, Comment = '%1 = slide number';
        SlideStartTok: Label '<section class="slide k%1"><div class="top">%2<h2>%3</h2>%4</div>', Locked = true, Comment = '%1 = slide number, %2 = previous arrow, %3 = slide title, %4 = next arrow';
        SlideEndTok: Label '</section>', Locked = true;
        ArrowTok: Label '<label class="arrow" for="s%1" title="%2">%3</label>', Locked = true, Comment = '%1 = slide number, %2 = tooltip, %3 = arrow glyph';
        ArrowSpaceTok: Label '<span class="arrow"></span>', Locked = true;
        PrevGlyphTok: Label '&#8249;', Locked = true;
        NextGlyphTok: Label '&#8250;', Locked = true;
        SlideTitleTok: Label '%1 of %2: %3', Locked = true, Comment = '%1 = slide number, %2 = slide count, %3 = caption';
        SummaryTok: Label '<p class="sum">%1</p>', Locked = true, Comment = '%1 = summary text';
        CheckTok: Label '<input type="checkbox" id="%1" class="hchk">', Locked = true, Comment = '%1 = element ID';
        MenuSpanTok: Label '<span class="ic menuic">%1%2</span>', Locked = true, Comment = '%1 = menu icon, %2 = dot';
        MenuLabelTok: Label '<label class="ic menuic" for="%1" title="%2">%3%4</label>', Locked = true, Comment = '%1 = element ID, %2 = tooltip, %3 = menu icon, %4 = dot';
        SheetLayerTok: Label '<div class="sheetlayer"><div class="shead">%1</div>%2</div>', Locked = true, Comment = '%1 = heading, %2 = rows';
        MoreRowTok: Label '<div class="moreRow">%1</div>', Locked = true, Comment = '%1 = buttons';
        TilesTok: Label '<div class="tiles">%1</div>', Locked = true, Comment = '%1 = tiles';
        HomeTileTok: Label '<div class="tile %1" data-service="%2"%3><span class="tic">%4</span><span class="tn">%5</span></div>', Locked = true, Comment = '%1 = change class, %2 = service name, %3 = title attribute, %4 = icon markup, %5 = caption';
        EmptyNoteTok: Label '<p class="empty">%1</p>', Locked = true, Comment = '%1 = text';
        AddedChangeClassTok: Label 'chg-new', Locked = true;
        ChangedChangeClassTok: Label 'chg-changed', Locked = true;
        StandardGroupTok: Label 'STANDARD', Locked = true;
        WhereHomeTok: Label 'home', Locked = true;
        CssChangeTok: Label '.changes{margin:0 0 16px;padding-top:12px;border-top:1px solid #e0e0e0} .changes h3{font-size:14px;font-weight:600;margin:0 0 8px;color:#323130} .chgt{width:100%;border-collapse:collapse;font-size:12px;table-layout:auto;word-break:normal;overflow-wrap:normal;hyphens:none} .chgt th{text-align:left;font-size:12px;font-weight:600;color:#323130;padding:4px 8px 4px 0;border-bottom:1px solid #edebe9;vertical-align:bottom} .chgt td{vertical-align:top;padding:6px 8px 6px 0;border-bottom:1px solid #edebe9;color:#323130} .chgt th:nth-child(-n+2),.chgt td:nth-child(-n+2){white-space:nowrap} .kind{font-weight:400} .kind.added{color:#107c10} .kind.changed{color:#c25e00} .kind.removed{color:#a4262c}', Locked = true;
        HomeScreenLbl: Label 'Home screen', Comment = 'Title of the home screen slide and its phone';
        HomeChangesHeadLbl: Label 'What this provider changes on the home screen', Comment = 'Heading of the table of changes on the home screen';
        HomeOverviewLbl: Label '%1, %2', Comment = '%1 = tile count, %2 = change count';
        TileOneLbl: Label '%1 tile', Comment = '%1 = number of tiles';
        TileManyLbl: Label '%1 tiles', Comment = '%1 = number of tiles';
        NoHomeTilesLbl: Label 'The home screen shows no tiles.', Comment = 'Shown on the home screen when the device shows no tiles';
        NoGroupLbl: Label 'no group', Comment = 'Name of the tiles outside a menu group';
        HomeAddedLbl: Label 'Shown on the home screen in the group %1', Comment = '%1 = group caption';
        HomeAddedNoGroupLbl: Label 'Shown on the home screen', Comment = 'A tile the provider adds outside a menu group';
        HomeMovedLbl: Label 'Moves from %1 to %2', Comment = '%1 = old group, %2 = new group';
        HomeHiddenLbl: Label 'Taken off the home screen', Comment = 'A tile the provider takes off the home screen';
        WhereHomeLbl: Label 'Home screen', Comment = 'Where column: the home screen';
        PreviousLbl: Label 'Previous screen', Comment = 'Tooltip of the arrow to the previous screen';
        NextLbl: Label 'Next screen', Comment = 'Tooltip of the arrow to the next screen';
        StageHeadTok: Label '<div class="stagehead" data-stage="%1">%2 <b>%3</b> %4</div>', Locked = true, Comment = '%1 = stage code, %2 = stage number, %3 = caption, %4 = auto next note';
        DivEndTok: Label '</div>', Locked = true;
        CssPageTok: Label '*,*::before,*::after{box-sizing:border-box} body{font:13px/1.45 "Segoe UI",system-ui,sans-serif;background:#fff;color:#323130;margin:0;padding:16px;-webkit-font-smoothing:antialiased} h2{font-size:14px;font-weight:600;line-height:1.3;margin:0;color:#323130} p{margin:0} .ri{display:none} .slide{display:none} .top{display:flex;align-items:center;gap:8px;padding:0 0 8px;margin:0 0 8px;border-bottom:1px solid #e0e0e0} .top h2{flex:1;min-width:0;text-align:center;overflow-wrap:normal} .arrow{flex:none;width:32px;height:32px;display:flex;align-items:center;justify-content:center;font-size:20px;color:#323130;cursor:pointer;user-select:none} .arrow:hover{background:#f3f2f1} .sum{font-size:12px;color:#605e5c;margin:0 0 12px;overflow-wrap:normal} .phones{display:flex;flex-direction:column;align-items:center;gap:16px;width:100%} .err{border-left:3px solid #a4262c;padding:8px 10px;font-size:13px;color:#323130;margin-bottom:12px} .empty{font-size:13px;color:#605e5c;padding:12px} @media(prefers-reduced-motion:reduce){*,*::before,*::after{transition:none!important;animation:none!important}}', Locked = true;
        CssPhoneTok: Label '.phone{width:100%;max-width:292px;height:560px;border:6px solid #323130;border-radius:22px;background:var(--mn-PageBackground);overflow:hidden;position:relative;display:flex;flex-direction:column;flex:none} .bar{flex:none;display:flex;align-items:center;justify-content:space-between;gap:6px;min-height:42px;padding:0 6px;background:var(--mn-TitleToolbarBackground);color:var(--mn-TitleToolbarForeground);border-bottom:1px solid var(--mn-ButtonTitleBackground)} .bar .ic{flex:none;width:28px;height:28px;display:flex;align-items:center;justify-content:center;color:var(--mn-TitleToolbarForeground);position:relative} .bar .ic svg{width:22px;height:22px;fill:currentColor;display:block} label.menuic{cursor:pointer} .ttl{flex:1;min-width:0;text-align:center;line-height:1.2;display:flex;flex-direction:column} .sm{order:-1;display:block;font-size:10.5px;font-weight:400;color:var(--mn-TitleToolbarForeground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis} .bar b{display:block;font-size:16px;font-weight:400;color:var(--mn-TitleToolbarForeground);white-space:nowrap;overflow:hidden;text-overflow:ellipsis} .screen{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden;position:relative;font-size:14px;color:var(--mn-PageForeground);background:var(--mn-PageBackground)} .fab{position:absolute;right:12px;bottom:12px;width:46px;height:46px;border-radius:50%;background:var(--mn-ButtonTitleBackground);color:var(--mn-ButtonTitleForeground);font-size:26px;line-height:44px;text-align:center} .hchk{display:none} .sheetlayer{display:none;position:absolute;left:0;right:0;top:43px;bottom:0;overflow-y:auto;background:var(--mn-PageBackground);color:var(--mn-PageForeground);padding:12px 14px;z-index:5} .hchk:checked ~ .sheetlayer{display:block} .shead{font-size:14px;font-weight:600;margin:0 0 10px}', Locked = true;
        CssListTok: Label '.row{min-height:48px;padding:6px 12px;background:var(--mn-PageBackground);color:var(--mn-PageForeground);font-size:14px;line-height:1.3} .row:nth-child(even){background:var(--mn-WindowBackground);color:var(--mn-WindowForeground)} .row .l1{font-size:14px;font-weight:700;color:inherit;overflow:hidden;text-overflow:ellipsis;white-space:nowrap} .row .l2{font-size:13px;color:inherit;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-top:1px} .note{font-size:12px;color:#605e5c;padding:6px 12px;line-height:1.35;overflow-wrap:normal} .note.invalid{color:#a4262c;font-weight:600} .row.empty .l1,.row.empty .l2{color:#888;font-weight:400;font-style:italic} .frow{margin:0 0 14px} .frow>b{display:block;font-size:12px;font-weight:600;color:#323130;margin:0 0 6px} .fchips{display:flex;flex-wrap:wrap;gap:6px} .chip{display:inline-block;max-width:100%;padding:2px 6px;border:1px solid #c8c6c4;font-size:12px;color:#323130;overflow:hidden;text-overflow:ellipsis;white-space:nowrap} .tiles{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;padding:10px 12px} .tile{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;aspect-ratio:1/1;min-width:0;padding:6px 4px;background:var(--mn-HomeTileBackground);color:var(--mn-PageForeground);text-align:center;font-size:12px;line-height:1.2} .tile .tic svg{width:36px;height:36px;fill:var(--mn-PageForeground);display:block} .tile .tn{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;max-width:100%;overflow-wrap:normal}', Locked = true;
        CssCardTok: Label '.sect{font-size:12px;font-weight:600;color:#323130;padding:12px 12px 4px} .grp{display:flex;align-items:center;min-height:42px;padding:6px 12px;background:var(--mn-GroupSeparator);color:var(--mn-PageForeground);font-size:16px;font-weight:400;border-bottom:1px solid var(--mn-Separator);overflow-wrap:normal} .grpend{height:4px;background:var(--mn-PageBackground)} .stagehead{padding:8px 12px;font-size:12px;color:#605e5c;line-height:1.35;border-bottom:1px solid #edebe9} .stagehead b{font-size:13px;font-weight:600;color:#323130}', Locked = true;
        CssControlTok: Label '.ctl{min-height:52px;padding:8px 12px;background:transparent;position:relative} .cap{display:flex;flex-wrap:wrap;align-items:center;gap:3px;font-size:14px;font-weight:400;color:var(--mn-PageForeground);line-height:1.25;overflow-wrap:normal} .ctl.Mandatory .cap{color:var(--mn-CardMandatoryCaption)} .val{min-height:20px;margin-top:2px;padding-left:12px;font-size:14px;color:var(--mn-PageForeground);line-height:1.3;overflow:hidden;text-overflow:ellipsis;white-space:nowrap} .ctl .val.edit{border-bottom:1px solid var(--mn-HighlightBackground);padding-bottom:1px} .val.dd{display:flex;align-items:center;justify-content:space-between;gap:8px} .val.dd .vt{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap} .ctl .name,.val .name{display:none} .tag{display:inline;font-size:11px;color:#605e5c;margin-left:4px} .qty{display:flex;align-items:center;gap:10px} .qty .b{display:inline-flex;width:24px;height:24px} .qty .b svg{width:24px;height:24px;fill:var(--mn-PageForeground);display:block} .lookup{color:var(--mn-PageForeground);font-size:13px} .lookup svg{width:15px;height:15px;fill:currentColor;vertical-align:-2px} .media{height:44px;margin-top:4px;border:1px dashed #a19f9d;display:flex;align-items:center;justify-content:center;gap:6px;color:#605e5c;font-size:12px} .media svg{width:20px;height:20px;fill:currentColor;display:block} .scan{display:flex;align-items:center;justify-content:space-between;gap:8px} .scan .sv{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap} .scanic{flex:none;display:flex} .scanic svg{width:18px;height:18px;fill:var(--mn-PageForeground);display:block}', Locked = true;
        CssBottomTok: Label '.bottom{flex:none;position:relative;display:flex;align-items:stretch;min-height:56px;border-top:1px solid var(--mn-Separator);background:var(--mn-TitleToolbarBackground);color:var(--mn-TitleToolbarForeground)} .bb{flex:1 1 0;min-width:0;min-height:56px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;padding:4px 2px;color:var(--mn-TitleToolbarForeground);font-size:11px;text-align:center;cursor:default} .bb svg{width:24px;height:24px;fill:currentColor;display:block} .bb .bl{display:block;max-width:100%;color:var(--mn-TitleToolbarForeground);line-height:1.1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap} .more{cursor:pointer} .more:hover{background:rgba(0,0,0,.06)} .more .ml{display:none} .moreRow{display:none;flex:none;grid-template-columns:repeat(4,minmax(0,1fr));background:var(--mn-TitleToolbarBackground);color:var(--mn-TitleToolbarForeground);border-top:1px solid var(--mn-Separator)} .hchk:checked ~ .moreRow{display:grid} .hchk:checked ~ .bottom .more .ml{display:block} .hchk:checked ~ .bottom .more .mo{display:none}', Locked = true;
        CssMarkTok: Label '.chg-new{outline:2px solid #107c10;outline-offset:-2px} .chg-changed{outline:2px solid #c25e00;outline-offset:-2px} .chg-removed{outline:2px solid #a4262c;outline-offset:-2px} .removed{opacity:.5} .removed .cap{color:#605e5c} .screen.withfab{padding-bottom:64px} .bar .ic{position:relative} .dot{position:absolute;top:0;right:0;width:9px;height:9px;border-radius:50%;border:2px solid var(--mn-TitleToolbarBackground)} .dot.added{background:#107c10} .dot.changed{background:#c25e00} .dot.removed{background:#a4262c}', Locked = true;
        DocumentTitleLbl: Label '%1: device screens', Comment = '%1 = provider id';
        OverviewLbl: Label '%1, %2, %3', Comment = '%1 = page type, %2 = field count, %3 = change count';
        FieldOneLbl: Label '%1 field', Comment = '%1 = number of fields';
        FieldManyLbl: Label '%1 fields', Comment = '%1 = number of fields';
        ChangeOneLbl: Label '%1 change', Comment = '%1 = number of changes';
        ChangeManyLbl: Label '%1 changes', Comment = '%1 = number of changes';
        ShowMoreLbl: Label 'Show more';
        ShowLessLbl: Label 'Show less';
        InvalidFilterLbl: Label 'The filter %1 is not valid.', Comment = '%1 = filter expression';
        NoPagesLbl: Label 'The provider declares no pages.';
        TypeUnknownLbl: Label 'type unknown';
        ListLbl: Label 'List';
        CardLbl: Label 'Card';
        DialogLbl: Label 'Dialog';
        CardStageLbl: Label 'Card, stage %1', Comment = '%1 = stage number';
        StageOfLbl: Label 'Stage %1 of %2:', Comment = '%1 = stage number, %2 = number of stages';
        MovesOnLbl: Label '(moves on by itself)';
        AdditionalSectionLbl: Label 'Show more';
        ReadOnlyLbl: Label 'read-only';
        PickFromLbl: Label 'pick from %1', Comment = '%1 = page caption';
        ScanLbl: Label 'scan';
        ScanWithBehaviorLbl: Label 'scan (%1)', Comment = '%1 = validation behavior';
        SignatureLbl: Label 'signature';
        MatchesLbl: Label '%1 matches %2', Comment = '%1 = field, %2 = filter expression';
        ListShowsLbl: Label 'List shows %1', Comment = '%1 = filter';
        OwnRecordsLbl: Label 'only the device user''s own records';
        OwnRecordsOfLbl: Label 'only the device user''s own records (%1)', Comment = '%1 = field';
        LineCellNamesLbl: Label 'First line,Second line,Top left,Middle left,Bottom left,Top right,Middle right,Bottom right', Comment = 'Comma-separated, one per list cell';
        ChangesHeadLbl: Label 'What this provider changes', Comment = 'Heading of the table of provider changes on a page';
        KindAddLbl: Label 'Added', Comment = 'Change column: the provider adds a field, button, link, filter or menu tile';
        KindChangeLbl: Label 'Changed', Comment = 'Change column: the provider changes a setting MobileNAV already has';
        KindRemoveLbl: Label 'Removed', Comment = 'Change column: the provider hides or removes something from the device';
        WhereListLbl: Label 'list', Comment = 'Where column: the list of rows';
        WhereCardLbl: Label 'card', Comment = 'Where column: the card with its fields';
        WhereMenuLbl: Label 'menu', Comment = 'Where column: the menu tiles';
        WhereBottomLbl: Label 'bottom bar', Comment = 'Where column: the buttons at the bottom of the screen';
        WhereFilterLbl: Label 'filter', Comment = 'Where column: the filter pane, saved filters and record filters';
        WhereSortLbl: Label 'sort', Comment = 'Where column: the sort of the list';
        WhereRuleLbl: Label 'rule', Comment = 'Where column: a layout rule';
        ChangeHeadKindLbl: Label 'Change', Comment = 'Column heading of the change table';
        ChangeHeadWhereLbl: Label 'Where', Comment = 'Column heading of the change table';
        ChangeHeadItemLbl: Label 'Item', Comment = 'Column heading of the change table';
        ChangeHeadDetailLbl: Label 'Detail', Comment = 'Column heading of the change table';
        AddedFieldLbl: Label 'New field on the card.';
        AddedPickedLbl: Label 'New field, picked from %1.', Comment = '%1 = page caption';
        AddedLinkLbl: Label 'New link on the bottom bar, opens %1.', Comment = '%1 = page caption';
        AddedPrintLbl: Label 'New print button on the bottom bar.';
        AddedButtonLbl: Label 'New button on the bottom bar.';
        AddedMenuLbl: Label 'New menu tile.';
        ShownOnDeviceLbl: Label 'Shown on the device.';
        HiddenOnDeviceLbl: Label 'Hidden on the device.';
        EditableLbl: Label 'Editable.';
        ReadOnlyDetailLbl: Label 'Read-only.';
        FilterPaneOnLbl: Label 'In the filter pane.';
        FilterPaneOffLbl: Label 'Out of the filter pane.';
        InMenuLbl: Label 'In the menu.';
        OutOfMenuLbl: Label 'Out of the menu.';
        OwnOnlyLbl: Label 'Shows only the device user''s own records.';
        SavedFilterPlainLbl: Label 'Saved filter on the list.';
        SavedFilterWithLbl: Label 'Saved filter, with %1.', Comment = '%1 = conditions';
        HidesLbl: Label 'Hides the control.';
        ValueColorLbl: Label 'Sets the value colour to %1.', Comment = '%1 = colour name';
        CaptionColorLbl: Label 'Sets the caption colour to %1.', Comment = '%1 = colour name';
        OtherActionLbl: Label 'Applies %1.', Comment = '%1 = action name';
        ActionWhenLbl: Label '%1 when %2.', Comment = '%1 = what the rule does, %2 = conditions';
        LineItemLbl: Label '%1 line', Comment = '%1 = ordinal, for example second';
        SortRowLbl: Label 'Sort', Comment = 'Row heading in the filter sheet';
        FilterPaneRowLbl: Label 'Filter pane', Comment = 'Row heading in the filter sheet';
        SavedFiltersRowLbl: Label 'Saved filters', Comment = 'Row heading in the filter sheet';
        FilterSheetLbl: Label 'Sort, filter and saved filters', Comment = 'Heading of the sheet under the menu icon of the list';
        GroupMoveLbl: Label 'Moves to group %1.', Comment = '%1 = group code';
        GroupLeaveLbl: Label 'Out of its group.';
        ImportanceLbl: Label 'Importance set to %1.', Comment = '%1 = importance';
        MobileTypeLbl: Label 'Device type set to %1.', Comment = '%1 = device type';
        FunctionLbl: Label 'Function set to %1.', Comment = '%1 = function name';
        RuleFilterLbl: Label 'Shows only records where %1.', Comment = '%1 = filter, for example Type matches Inventory';
        LineShowsLbl: Label 'Shows %1.', Comment = '%1 = the line text';
        OrdinalsLbl: Label 'first,second,third,fourth,fifth,sixth,seventh,eighth', Comment = 'Comma-separated ordinal words for lines 1 to 8';
        SortedByLbl: Label 'Sorted by %1', Comment = '%1 = field captions';
        NoRecordsLbl: Label 'No records match the page''s filters, so field names are shown.', Comment = 'Note under the rows of a page when no record passes the filters the device applies';
        NotReadableLbl: Label 'Records are not readable in this session, field names shown.', Comment = 'Note under the rows when the table cannot be read';
        ListAndCardLbl: Label 'List and card', Comment = 'Page type: a list with a card';
        OfflineListLbl: Label 'Offline list', Comment = 'Page type: an offline list';
        SortChipTok: Label '<span class="chip">%1</span>', Locked = true, Comment = '%1 = text';
        ChangesStartTok: Label '<div class="changes"><h3>%1</h3>', Locked = true, Comment = '%1 = heading';
        NewChangeClassTok: Label 'chg-new', Locked = true;
        ListCardTypeTok: Label 'ListCard', Locked = true;
        OfflineTypeTok: Label 'Offline', Locked = true;
        EqualSymbolTok: Label '=', Locked = true;
        NotEqualSymbolTok: Label '<>', Locked = true;
        LessSymbolTok: Label '<', Locked = true;
        LessOrEqualSymbolTok: Label '<=', Locked = true;
        GreaterSymbolTok: Label '>', Locked = true;
        GreaterOrEqualSymbolTok: Label '>=', Locked = true;
        NotEqualTok: Label '<>%1', Locked = true, Comment = '%1 = value';
        AndLbl: Label ' and ';
        AlwaysLbl: Label 'always';
        CardNavigateLbl: Label 'Card navigate';
        CardRefreshLbl: Label 'Card refresh';
        ListFilterLbl: Label 'List filter';
        ListSortLbl: Label 'List sort';
}
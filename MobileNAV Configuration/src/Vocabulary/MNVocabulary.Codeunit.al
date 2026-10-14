namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The one place that knows MobileNAV's option-member spellings. The public API speaks in the
/// framework's enums; the MobileNAV layer resolves option fields by member name at apply time
/// ("BJF MN Field Mgt.".SetOptionField), so every enum is translated here and nowhere else.
/// Most enum value names are MobileNAV's own, so the translation is the value name itself; the
/// two exceptions are spelled out.
/// </summary>
codeunit 77783 "BJF MN Vocabulary"
{
    Access = Internal;

    procedure ImportanceName(Importance: Enum "BJF MN Importance"): Text[30]
    begin
        // MobileNAV calls the standard section 'None'; the framework calls it Standard so the
        // developer is not left wondering whether 'None' hides the control.
        if Importance = Enum::"BJF MN Importance"::Standard then
            exit(this.StandardImportanceTok);
        exit(this.ValueName(Importance.Names(), Importance.Ordinals(), Importance.AsInteger()));
    end;

    procedure MobileTypeName(MobileType: Enum "BJF MN Mobile Type"): Text[30]
    begin
        exit(this.ValueName(MobileType.Names(), MobileType.Ordinals(), MobileType.AsInteger()));
    end;

    procedure FunctionTypeName(FunctionType: Enum "BJF MN Function Type"): Text[30]
    begin
        exit(this.ValueName(FunctionType.Names(), FunctionType.Ordinals(), FunctionType.AsInteger()));
    end;

    /// <summary>Empty for Default: the MobileNAV layer leaves the option untouched for an empty name.</summary>
    /// <param name="ValidationBehavior">The validation behaviour to name.</param>
    /// <returns>The MobileNAV name, or an empty text for Default.</returns>
    procedure ValidationBehaviorName(ValidationBehavior: Enum "BJF MN Validation Behavior"): Text[50]
    begin
        if ValidationBehavior = Enum::"BJF MN Validation Behavior"::Default then
            exit('');
        exit(CopyStr(this.ValueName(ValidationBehavior.Names(), ValidationBehavior.Ordinals(), ValidationBehavior.AsInteger()), 1, 50));
    end;

    procedure MainMenuActionName(MainMenuAction: Enum "BJF MN Main Menu Action"): Text[30]
    begin
        exit(this.ValueName(MainMenuAction.Names(), MainMenuAction.Ordinals(), MainMenuAction.AsInteger()));
    end;

    procedure StagingBehaviorName(StagingBehavior: Enum "BJF MN Staging Behavior"): Text[30]
    begin
        exit(this.ValueName(StagingBehavior.Names(), StagingBehavior.Ordinals(), StagingBehavior.AsInteger()));
    end;

    procedure PageTypeName(PageType: Enum "BJF MN Page Type"): Text[30]
    begin
        exit(this.ValueName(PageType.Names(), PageType.Ordinals(), PageType.AsInteger()));
    end;

    procedure MineFilterName(MineFilter: Enum "BJF MN Mine Filter"): Text[30]
    begin
        exit(this.ValueName(MineFilter.Names(), MineFilter.Ordinals(), MineFilter.AsInteger()));
    end;

    procedure AssignToMeName(AssignToMe: Enum "BJF MN Assign To Me"): Text[30]
    begin
        exit(this.ValueName(AssignToMe.Names(), AssignToMe.Ordinals(), AssignToMe.AsInteger()));
    end;

    procedure FieldCategoryName(FieldCategory: Enum "BJF MN Field Category"): Text[30]
    begin
        exit(this.ValueName(FieldCategory.Names(), FieldCategory.Ordinals(), FieldCategory.AsInteger()));
    end;

    procedure ComparisonName(Comparison: Enum "BJF MN Comparison"): Text[30]
    begin
        exit(this.ValueName(Comparison.Names(), Comparison.Ordinals(), Comparison.AsInteger()));
    end;

    procedure FilterScopeName(FilterScope: Enum "BJF MN Filter Scope"): Text[30]
    begin
        exit(this.ValueName(FilterScope.Names(), FilterScope.Ordinals(), FilterScope.AsInteger()));
    end;

    procedure PropagationName(Propagation: Enum "BJF MN Propagation"): Text[30]
    begin
        exit(this.ValueName(Propagation.Names(), Propagation.Ordinals(), Propagation.AsInteger()));
    end;

    procedure SearchTypeName(SearchType: Enum "BJF MN Search Type"): Text[30]
    begin
        exit(this.ValueName(SearchType.Names(), SearchType.Ordinals(), SearchType.AsInteger()));
    end;

    procedure OperationTypeName(OperationType: Enum "BJF MN Operation Type"): Text[30]
    begin
        exit(this.ValueName(OperationType.Names(), OperationType.Ordinals(), OperationType.AsInteger()));
    end;

    procedure ColorName(Color: Enum "BJF MN Color"): Text[30]
    begin
        exit(this.ValueName(Color.Names(), Color.Ordinals(), Color.AsInteger()));
    end;

    /// <summary>MobileNAV's dynamic-layout action type that colors the given area.</summary>
    /// <param name="LayoutArea">The layout area to color.</param>
    /// <returns>The action type name, with the colour suffix.</returns>
    procedure LayoutAreaActionName(LayoutArea: Enum "BJF MN Layout Area"): Text[30]
    begin
        exit(CopyStr(this.ValueName(LayoutArea.Names(), LayoutArea.Ordinals(), LayoutArea.AsInteger()) + this.ColorSuffixTok, 1, 30));
    end;

    /// <summary>MobileNAV's MobileType for the barcode-scannable input a Scan control renders as.</summary>
    /// <returns>The MobileType name.</returns>
    procedure BarcodeMobileTypeName(): Text[30]
    begin
        exit(this.MobileTypeName(Enum::"BJF MN Mobile Type"::Barcode));
    end;

    /// <summary>Whether a MobileNAV mobile type name is the given member. The comparison is case-sensitive.</summary>
    /// <param name="MemberName">MobileNAV Mobile Type member name.</param>
    /// <param name="MobileType">The member to compare with.</param>
    /// <returns>True when the name is that member's.</returns>
    procedure IsMobileType(MemberName: Text; MobileType: Enum "BJF MN Mobile Type"): Boolean
    begin
        exit(MemberName = this.MobileTypeName(MobileType));
    end;

    /// <summary>
    /// Whether the mobile type shows or captures a picture or a document: Image, Signature, PDF,
    /// File, Excel and their Cacheable forms. The comparison is case-sensitive.
    /// </summary>
    /// <param name="MemberName">MobileNAV Mobile Type member name.</param>
    /// <returns>True for a media type.</returns>
    procedure IsMediaMobileType(MemberName: Text): Boolean
    var
        MediaTypes: List of [Enum "BJF MN Mobile Type"];
    begin
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::Image);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::Signature);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::PDF);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::File);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::CacheableImage);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::CacheablePDF);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::CacheableFile);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::Excel);
        MediaTypes.Add(Enum::"BJF MN Mobile Type"::CacheableExcel);
        exit(this.IsAnyMobileType(MemberName, MediaTypes));
    end;

    /// <summary>Whether the mobile type prints from a template: ZPLTemplate or HTMLTemplate. The comparison is case-sensitive.</summary>
    /// <param name="MemberName">MobileNAV Mobile Type member name.</param>
    /// <returns>True for a print type.</returns>
    procedure IsPrintMobileType(MemberName: Text): Boolean
    var
        PrintTypes: List of [Enum "BJF MN Mobile Type"];
    begin
        PrintTypes.Add(Enum::"BJF MN Mobile Type"::ZPLTemplate);
        PrintTypes.Add(Enum::"BJF MN Mobile Type"::HTMLTemplate);
        exit(this.IsAnyMobileType(MemberName, PrintTypes));
    end;

    /// <summary>
    /// Whether a button of this mobile type is drawn on the card itself rather than in the
    /// page's menu. Image, Signature and File are capture controls. The comparison ignores case.
    /// </summary>
    /// <param name="MemberName">MobileNAV Mobile Type member name.</param>
    /// <returns>True when the button is drawn on the card.</returns>
    procedure RendersInline(MemberName: Text): Boolean
    begin
        exit(UpperCase(MemberName) in [
            UpperCase(this.MobileTypeName(Enum::"BJF MN Mobile Type"::Image)),
            UpperCase(this.MobileTypeName(Enum::"BJF MN Mobile Type"::Signature)),
            UpperCase(this.MobileTypeName(Enum::"BJF MN Mobile Type"::File))]);
    end;

    /// <summary>The MobileNAV Service Setup Hide* field that removes the toolbar button.</summary>
    /// <param name="ToolbarButton">The toolbar button.</param>
    /// <returns>The field number.</returns>
    procedure ToolbarButtonFieldNo(ToolbarButton: Enum "BJF MN Toolbar Button"): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        FieldNos: List of [Integer];
    begin
        // In the enum's order: ordinal 0 is the first entry.
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnCardRefresh));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnCardHideFields));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnCardFlowFilters));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnCardNavigate));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnListSort));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnListRefresh));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnListFilter));
        FieldNos.Add(ServiceSetup.FieldNo(HideBtnListFlowFilters));
        FieldNos.Add(ServiceSetup.FieldNo("Hide List Full Screen"));
        FieldNos.Add(ServiceSetup.FieldNo("Hide List Multi-Select"));
        FieldNos.Add(ServiceSetup.FieldNo("Hide List Hide Filters"));
        FieldNos.Add(ServiceSetup.FieldNo("Hide Longer Toolbar Caption"));
        exit(FieldNos.Get(ToolbarButton.AsInteger() + 1));
    end;

    /// <summary>The MobileNAV Service Setup AutoRefresh* field for the moment.</summary>
    /// <param name="Moment">When the device reloads the page data.</param>
    /// <returns>The field number.</returns>
    procedure AutoRefreshFieldNo(Moment: Enum "BJF MN Auto Refresh"): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        case Moment of
            Enum::"BJF MN Auto Refresh"::OnOpen:
                exit(ServiceSetup.FieldNo(AutoRefreshOnOpen));
            Enum::"BJF MN Auto Refresh"::CardOnChildUpdate:
                exit(ServiceSetup.FieldNo(AutoRefreshCardOnChildUpdate));
            Enum::"BJF MN Auto Refresh"::ListOnChildUpdate:
                exit(ServiceSetup.FieldNo(AutoRefreshListOnChildUpdate));
            Enum::"BJF MN Auto Refresh"::ListOnUpdate:
                exit(ServiceSetup.FieldNo(AutoRefreshListOnUpdate));
        end;
    end;

    /// <summary>The MobileNAV Service Setup HidePrefix* field that removes the title prefix.</summary>
    /// <param name="Prefix">The title prefix.</param>
    /// <returns>The field number.</returns>
    procedure TitlePrefixFieldNo(Prefix: Enum "BJF MN Title Prefix"): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        case Prefix of
            Enum::"BJF MN Title Prefix"::New:
                exit(ServiceSetup.FieldNo(HidePrefixNew));
            Enum::"BJF MN Title Prefix"::PageNameOnCard:
                exit(ServiceSetup.FieldNo(HidePrefixPageNameOnCard));
            Enum::"BJF MN Title Prefix"::ParentOnDrillDown:
                exit(ServiceSetup.FieldNo(HidePrefixParentOnDrillDown));
        end;
    end;

    /// <summary>MobileNAV's Page Type for the action-dialog pattern a PublishAsDialog page uses.</summary>
    /// <returns>The Page Type name.</returns>
    procedure ReportPageTypeName(): Text[30]
    begin
        exit(this.ReportPageTypeTok);
    end;

    local procedure IsAnyMobileType(MemberName: Text; MobileTypes: List of [Enum "BJF MN Mobile Type"]): Boolean
    var
        MobileType: Enum "BJF MN Mobile Type";
    begin
        foreach MobileType in MobileTypes do
            if this.IsMobileType(MemberName, MobileType) then
                exit(true);
        exit(false);
    end;

    local procedure ValueName(Names: List of [Text]; Ordinals: List of [Integer]; Ordinal: Integer): Text[30]
    begin
        exit(CopyStr(Names.Get(Ordinals.IndexOf(Ordinal)), 1, 30));
    end;

    var
#pragma warning disable LC0086
        StandardImportanceTok: Label 'None', Locked = true;
#pragma warning restore LC0086
        ColorSuffixTok: Label 'Color', Locked = true;
        ReportPageTypeTok: Label 'Report', Locked = true;
}

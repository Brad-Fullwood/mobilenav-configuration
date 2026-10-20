namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The facts of each setting a builder verb writes: its Setting text, the MobileNAV Service Setup
/// field, whether the field's OnValidate runs, the value kind and the control kinds it applies to.
/// The builder writes the rows from these facts and the provider writer reads the kinds from them,
/// so each fact is written in one place.
/// </summary>
codeunit 77719 "BJF MN Property Catalog"
{
    Access = Internal;

    #pragma warning disable LC0010 // One branch per setting, so each row of the catalog stays one line.
    /// <summary>The Setting text MobileNAV reads for the setting.</summary>
    /// <param name="Property">The setting.</param>
    /// <returns>The Setting text.</returns>
    procedure Setting(Property: Enum "BJF MN Property"): Text[50]
    begin
        case Property of
            Enum::"BJF MN Property"::PageType:
                exit(this.PageTypeTok);
            Enum::"BJF MN Property"::Insertable:
                exit(this.InsertableTok);
            Enum::"BJF MN Property"::Updatable:
                exit(this.UpdatableTok);
            Enum::"BJF MN Property"::Deletable:
                exit(this.DeletableTok);
            Enum::"BJF MN Property"::ListLimit:
                exit(this.ListLimitTok);
            Enum::"BJF MN Property"::DefaultDrillDown:
                exit(this.DefaultDrillDownTok);
            Enum::"BJF MN Property"::OnOpen:
                exit(this.OnOpenTok);
            Enum::"BJF MN Property"::OnClose:
                exit(this.OnCloseTok);
            Enum::"BJF MN Property"::HideButton:
                exit(this.HideButtonTok);
            Enum::"BJF MN Property"::HideTitlePrefix:
                exit(this.HideTitlePrefixTok);
            Enum::"BJF MN Property"::AutoRefresh:
                exit(this.AutoRefreshTok);
            Enum::"BJF MN Property"::AutoOpenSingleRecord:
                exit(this.AutoOpenSingleRecordTok);
            Enum::"BJF MN Property"::ShowFilterPanel:
                exit(this.ShowFilterPanelTok);
            Enum::"BJF MN Property"::ShowUnreadCount:
                exit(this.ShowUnreadCountTok);
            Enum::"BJF MN Property"::MineFilter:
                exit(this.MineFilterTok);
            Enum::"BJF MN Property"::AssignToMeCard, Enum::"BJF MN Property"::AssignToMeList:
                exit(this.AssignToMeTok);
            Enum::"BJF MN Property"::Style:
                exit(this.StyleTok);
            Enum::"BJF MN Property"::FilterByParent:
                exit(this.FilterByParentTok);
            Enum::"BJF MN Property"::ChunkSize:
                exit(this.ChunkSizeTok);
            Enum::"BJF MN Property"::CheckForChanges:
                exit(this.CheckForChangesTok);
            Enum::"BJF MN Property"::MenuCategory:
                exit(this.MenuCategoryTok);
            Enum::"BJF MN Property"::DecimalPlaces:
                exit(this.DecimalPlacesTok);
            Enum::"BJF MN Property"::Quantity:
                exit(this.QuantityTok);
            Enum::"BJF MN Property"::Increases:
                exit(this.IncreasesTok);
            Enum::"BJF MN Property"::RangeMin, Enum::"BJF MN Property"::RangeMax:
                exit(this.RangeTok);
            Enum::"BJF MN Property"::QuickEdit:
                exit(this.QuickEditTok);
            Enum::"BJF MN Property"::PromotedOnGroupHeader:
                exit(this.PromotedOnGroupHeaderTok);
            Enum::"BJF MN Property"::AllowSkip:
                exit(this.AllowSkipTok);
            Enum::"BJF MN Property"::RegExPattern, Enum::"BJF MN Property"::RegExResults:
                exit(this.RegExTok);
            Enum::"BJF MN Property"::NoRegExPattern, Enum::"BJF MN Property"::NoRegExResults, Enum::"BJF MN Property"::NoRegExInherited:
                exit(this.NoRegExTok);
            Enum::"BJF MN Property"::FieldCategory:
                exit(this.FieldCategoryTok);
            Enum::"BJF MN Property"::HideDrillDown:
                exit(this.HideDrillDownTok);
            Enum::"BJF MN Property"::ValidateAlways:
                exit(this.ValidateAlwaysTok);
            Enum::"BJF MN Property"::FieldVisible:
                exit(this.VisibleTok);
            Enum::"BJF MN Property"::FieldEditable:
                exit(this.EditableTok);
            Enum::"BJF MN Property"::FieldDisplayInMenu:
                exit(this.DisplayInMenuTok);
            Enum::"BJF MN Property"::FieldFilterable:
                exit(this.FilterableTok);
            Enum::"BJF MN Property"::FieldImportance:
                exit(this.ImportanceTok);
            Enum::"BJF MN Property"::FieldMobileType:
                exit(this.MobileTypeTok);
            Enum::"BJF MN Property"::FieldFunctionType:
                exit(this.FunctionTypeTok);
            Enum::"BJF MN Property"::FieldValidationBehavior:
                exit(this.ValidationBehaviorTok);
        end;
    end;
    #pragma warning restore LC0010

    #pragma warning disable LC0010 // One branch per setting, so each row of the catalog stays one line.
    /// <summary>The MobileNAV Service Setup field the setting writes.</summary>
    /// <remarks>Zero for HideButton, HideTitlePrefix and AutoRefresh, whose field depends on the value and comes from the Vocabulary.</remarks>
    /// <param name="Property">The setting.</param>
    /// <returns>The field number, or zero.</returns>
    procedure FieldNo(Property: Enum "BJF MN Property"): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        case Property of
            Enum::"BJF MN Property"::PageType:
                exit(ServiceSetup.FieldNo("Page Type"));
            Enum::"BJF MN Property"::Insertable:
                exit(ServiceSetup.FieldNo("Page Insert"));
            Enum::"BJF MN Property"::Updatable:
                exit(ServiceSetup.FieldNo("Page Update"));
            Enum::"BJF MN Property"::Deletable:
                exit(ServiceSetup.FieldNo("Page Delete"));
            Enum::"BJF MN Property"::ListLimit:
                exit(ServiceSetup.FieldNo("List Display Limit"));
            Enum::"BJF MN Property"::DefaultDrillDown:
                exit(ServiceSetup.FieldNo("Default DrillDown"));
            Enum::"BJF MN Property"::OnOpen:
                exit(ServiceSetup.FieldNo("OnOpen Function Name"));
            Enum::"BJF MN Property"::OnClose:
                exit(ServiceSetup.FieldNo("OnClose Function Name"));
            Enum::"BJF MN Property"::HideButton, Enum::"BJF MN Property"::HideTitlePrefix, Enum::"BJF MN Property"::AutoRefresh:
                exit(0);
            Enum::"BJF MN Property"::AutoOpenSingleRecord:
                exit(ServiceSetup.FieldNo("AutoOpenSingleListItemOnOpen"));
            Enum::"BJF MN Property"::ShowFilterPanel:
                exit(ServiceSetup.FieldNo("ShowFilterPanelAutomatically"));
            Enum::"BJF MN Property"::ShowUnreadCount:
                exit(ServiceSetup.FieldNo("Show Unread Record Count"));
            Enum::"BJF MN Property"::MineFilter:
                exit(ServiceSetup.FieldNo("Mine Filter Type"));
            Enum::"BJF MN Property"::AssignToMeCard:
                exit(ServiceSetup.FieldNo("Card Assign to me"));
            Enum::"BJF MN Property"::AssignToMeList:
                exit(ServiceSetup.FieldNo("List Assign to me"));
            Enum::"BJF MN Property"::Style:
                exit(ServiceSetup.FieldNo("Page Style"));
            Enum::"BJF MN Property"::FilterByParent:
                exit(ServiceSetup.FieldNo("Filter By Parent Enabled"));
            Enum::"BJF MN Property"::ChunkSize:
                exit(ServiceSetup.FieldNo("Chunk Size"));
            Enum::"BJF MN Property"::CheckForChanges:
                exit(ServiceSetup.FieldNo("Check for Changes Period"));
            Enum::"BJF MN Property"::MenuCategory:
                exit(ServiceSetup.FieldNo("Category"));
            Enum::"BJF MN Property"::DecimalPlaces:
                exit(ServiceSetup.FieldNo("Decimal Places"));
            Enum::"BJF MN Property"::Quantity:
                exit(ServiceSetup.FieldNo("Quantity Increment"));
            Enum::"BJF MN Property"::Increases:
                exit(ServiceSetup.FieldNo("Field to Increase"));
            Enum::"BJF MN Property"::RangeMin:
                exit(ServiceSetup.FieldNo("Min. Value Dec"));
            Enum::"BJF MN Property"::RangeMax:
                exit(ServiceSetup.FieldNo("Max. Value Dec"));
            Enum::"BJF MN Property"::QuickEdit:
                exit(ServiceSetup.FieldNo("Quick Edit/Action"));
            Enum::"BJF MN Property"::PromotedOnGroupHeader:
                exit(ServiceSetup.FieldNo("PromotedOnGroupHeader"));
            Enum::"BJF MN Property"::AllowSkip:
                exit(ServiceSetup.FieldNo("Allow Skip"));
            Enum::"BJF MN Property"::RegExPattern, Enum::"BJF MN Property"::NoRegExPattern:
                exit(ServiceSetup.FieldNo("RegExText"));
            Enum::"BJF MN Property"::RegExResults, Enum::"BJF MN Property"::NoRegExResults:
                exit(ServiceSetup.FieldNo("RegExResults"));
            Enum::"BJF MN Property"::NoRegExInherited:
                exit(ServiceSetup.FieldNo("RegEx Inherited"));
            Enum::"BJF MN Property"::FieldCategory:
                exit(ServiceSetup.FieldNo("Field Category"));
            Enum::"BJF MN Property"::HideDrillDown:
                exit(ServiceSetup.FieldNo("Hide Card DrillDown"));
            Enum::"BJF MN Property"::ValidateAlways:
                exit(ServiceSetup.FieldNo("Validate if not Changed"));
            Enum::"BJF MN Property"::FieldVisible:
                exit(ServiceSetup.FieldNo(Visible));
            Enum::"BJF MN Property"::FieldEditable:
                exit(ServiceSetup.FieldNo(Editable));
            Enum::"BJF MN Property"::FieldDisplayInMenu:
                exit(ServiceSetup.FieldNo(DisplayInMenu));
            Enum::"BJF MN Property"::FieldFilterable:
                exit(ServiceSetup.FieldNo("Visible as Filter"));
            Enum::"BJF MN Property"::FieldImportance:
                exit(ServiceSetup.FieldNo(Mandatory));
            Enum::"BJF MN Property"::FieldMobileType:
                exit(ServiceSetup.FieldNo(MobileType));
            Enum::"BJF MN Property"::FieldFunctionType:
                exit(ServiceSetup.FieldNo("Function Type"));
            Enum::"BJF MN Property"::FieldValidationBehavior:
                exit(ServiceSetup.FieldNo("Validation Behavior"));
        end;
    end;
    #pragma warning restore LC0010

    /// <summary>Whether the field's OnValidate trigger runs when the setting is written.</summary>
    /// <remarks>
    /// Some settings are written without Validate on purpose. Editable silently reverts and shows a
    /// Message, DisplayInMenu rewrites Category and Order, and "Visible as Filter" raises a Confirm
    /// and can delete sibling rows. Those settings are assigned directly.
    /// </remarks>
    /// <param name="Property">The setting.</param>
    /// <returns>True when the setting validates.</returns>
    procedure RunValidate(Property: Enum "BJF MN Property"): Boolean
    begin
        case Property of
            Enum::"BJF MN Property"::Insertable,
            Enum::"BJF MN Property"::Updatable,
            Enum::"BJF MN Property"::Deletable,
            Enum::"BJF MN Property"::ListLimit,
            Enum::"BJF MN Property"::DefaultDrillDown,
            Enum::"BJF MN Property"::OnOpen,
            Enum::"BJF MN Property"::OnClose,
            Enum::"BJF MN Property"::ShowUnreadCount,
            Enum::"BJF MN Property"::Style,
            Enum::"BJF MN Property"::CheckForChanges,
            Enum::"BJF MN Property"::Quantity,
            Enum::"BJF MN Property"::QuickEdit,
            Enum::"BJF MN Property"::AllowSkip,
            Enum::"BJF MN Property"::RegExPattern,
            Enum::"BJF MN Property"::RegExResults,
            Enum::"BJF MN Property"::FieldCategory,
            Enum::"BJF MN Property"::ValidateAlways,
            Enum::"BJF MN Property"::FieldVisible:
                exit(true);
        end;
        exit(false);
    end;

    /// <summary>The kind of value the setting writes, which sets how its Value text is resolved.</summary>
    /// <param name="Property">The setting.</param>
    /// <returns>The value kind.</returns>
    procedure ValueKind(Property: Enum "BJF MN Property"): Enum "BJF MN Property Value"
    begin
        case Property of
            Enum::"BJF MN Property"::DefaultDrillDown:
                exit(Enum::"BJF MN Property Value"::"Control Name");
            Enum::"BJF MN Property"::Increases:
                exit(Enum::"BJF MN Property Value"::"Control Line No.");
        end;
        exit(Enum::"BJF MN Property Value"::Literal);
    end;

    /// <summary>
    /// Whether the setting is one of the field settings of a Field, Function Field or Scan Field
    /// line. The builder writes them as rows of their own, and the apply writes them through the
    /// field writer rather than as plain properties.
    /// </summary>
    /// <param name="Property">The setting.</param>
    /// <returns>True for the eight field settings.</returns>
    procedure IsFieldSetting(Property: Enum "BJF MN Property"): Boolean
    begin
        case Property of
            Enum::"BJF MN Property"::FieldVisible,
            Enum::"BJF MN Property"::FieldEditable,
            Enum::"BJF MN Property"::FieldDisplayInMenu,
            Enum::"BJF MN Property"::FieldFilterable,
            Enum::"BJF MN Property"::FieldImportance,
            Enum::"BJF MN Property"::FieldMobileType,
            Enum::"BJF MN Property"::FieldFunctionType,
            Enum::"BJF MN Property"::FieldValidationBehavior:
                exit(true);
        end;
        exit(false);
    end;

    /// <summary>How serious a finding on the setting is.</summary>
    /// <remarks>A field setting that does not match the configuration blocks the apply. Every other setting is a warning.</remarks>
    /// <param name="Property">The setting.</param>
    /// <returns>Blocker for a field setting, Warning for any other.</returns>
    procedure Severity(Property: Enum "BJF MN Property"): Enum "BJF Diagnostic Severity"
    begin
        if this.IsFieldSetting(Property) then
            exit(Enum::"BJF Diagnostic Severity"::Blocker);
        exit(Enum::"BJF Diagnostic Severity"::Warning);
    end;

    #pragma warning disable LC0010 // One branch per setting, so each setting's kinds stay in one place.
    /// <summary>The control kinds a control setting applies to, in the order the builder states them.</summary>
    /// <param name="Property">The setting.</param>
    /// <returns>The control kinds. Empty for a page setting.</returns>
    procedure ControlKinds(Property: Enum "BJF MN Property") Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        case Property of
            Enum::"BJF MN Property"::DecimalPlaces,
            Enum::"BJF MN Property"::Quantity,
            Enum::"BJF MN Property"::RangeMin,
            Enum::"BJF MN Property"::RangeMax,
            Enum::"BJF MN Property"::QuickEdit,
            Enum::"BJF MN Property"::PromotedOnGroupHeader,
            Enum::"BJF MN Property"::HideDrillDown:
                Kinds.Add(Enum::"BJF MN Config Operation"::Field);
            Enum::"BJF MN Property"::Increases:
                begin
                    Kinds.Add(Enum::"BJF MN Config Operation"::Field);
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
                end;
            Enum::"BJF MN Property"::AllowSkip,
            Enum::"BJF MN Property"::FieldValidationBehavior:
                begin
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
                end;
            Enum::"BJF MN Property"::RegExPattern,
            Enum::"BJF MN Property"::RegExResults,
            Enum::"BJF MN Property"::NoRegExPattern,
            Enum::"BJF MN Property"::NoRegExResults,
            Enum::"BJF MN Property"::NoRegExInherited:
                begin
                    Kinds.Add(Enum::"BJF MN Config Operation"::Field);
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
                end;
            Enum::"BJF MN Property"::FieldCategory,
            Enum::"BJF MN Property"::ValidateAlways:
                begin
                    Kinds.Add(Enum::"BJF MN Config Operation"::Field);
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
                end;
            Enum::"BJF MN Property"::FieldVisible,
            Enum::"BJF MN Property"::FieldEditable,
            Enum::"BJF MN Property"::FieldDisplayInMenu,
            Enum::"BJF MN Property"::FieldImportance:
                begin
                    Kinds.Add(Enum::"BJF MN Config Operation"::Field);
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
                end;
            Enum::"BJF MN Property"::FieldMobileType:
                begin
                    Kinds.Add(Enum::"BJF MN Config Operation"::Field);
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
                    Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
                end;
            Enum::"BJF MN Property"::FieldFilterable:
                Kinds.Add(Enum::"BJF MN Config Operation"::Field);
            Enum::"BJF MN Property"::FieldFunctionType:
                Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        end;
        exit(Kinds);
    end;
    #pragma warning restore LC0010

    /// <summary>The control kinds of the setting as the provider writer names them, comma separated.</summary>
    /// <param name="Property">The setting.</param>
    /// <returns>For example Field,Button,Scan. Empty for a page setting.</returns>
    procedure WriterKinds(Property: Enum "BJF MN Property"): Text
    var
        Kind: Enum "BJF MN Config Operation";
        KindNames: Text;
    begin
        foreach Kind in this.ControlKinds(Property) do begin
            if KindNames <> '' then
                KindNames += ',';
            KindNames += this.WriterKindName(Kind);
        end;
        exit(KindNames);
    end;

    local procedure WriterKindName(Kind: Enum "BJF MN Config Operation"): Text
    begin
        case Kind of
            Enum::"BJF MN Config Operation"::Field:
                exit(this.FieldKindTok);
            Enum::"BJF MN Config Operation"::"Function Field":
                exit(this.ButtonKindTok);
            Enum::"BJF MN Config Operation"::"Scan Field":
                exit(this.ScanKindTok);
            Enum::"BJF MN Config Operation"::"Lookup Field":
                exit(this.LookupKindTok);
            Enum::"BJF MN Config Operation"::"Linked Field":
                exit(this.LinkKindTok);
            else
                Error(this.UnknownKindErr, Format(Kind));
        end;
    end;

    var
        PageTypeTok: Label 'PageType', Locked = true;
        InsertableTok: Label 'Insertable', Locked = true;
        UpdatableTok: Label 'Updatable', Locked = true;
        DeletableTok: Label 'Deletable', Locked = true;
        ListLimitTok: Label 'ListLimit', Locked = true;
        DefaultDrillDownTok: Label 'DefaultDrillDown', Locked = true;
        OnOpenTok: Label 'OnOpen', Locked = true;
        OnCloseTok: Label 'OnClose', Locked = true;
        HideButtonTok: Label 'HideButton', Locked = true;
        HideTitlePrefixTok: Label 'HideTitlePrefix', Locked = true;
        AutoRefreshTok: Label 'AutoRefresh', Locked = true;
        AutoOpenSingleRecordTok: Label 'AutoOpenSingleRecord', Locked = true;
        ShowFilterPanelTok: Label 'ShowFilterPanel', Locked = true;
        ShowUnreadCountTok: Label 'ShowUnreadCount', Locked = true;
        MineFilterTok: Label 'MineFilter', Locked = true;
        AssignToMeTok: Label 'AssignToMe', Locked = true;
        StyleTok: Label 'Style', Locked = true;
        FilterByParentTok: Label 'FilterByParent', Locked = true;
        ChunkSizeTok: Label 'ChunkSize', Locked = true;
        CheckForChangesTok: Label 'CheckForChanges', Locked = true;
        MenuCategoryTok: Label 'MenuCategory', Locked = true;
        DecimalPlacesTok: Label 'DecimalPlaces', Locked = true;
        QuantityTok: Label 'Quantity', Locked = true;
        IncreasesTok: Label 'Increases', Locked = true;
        RangeTok: Label 'Range', Locked = true;
        QuickEditTok: Label 'QuickEdit', Locked = true;
        PromotedOnGroupHeaderTok: Label 'PromotedOnGroupHeader', Locked = true;
        AllowSkipTok: Label 'AllowSkip', Locked = true;
        RegExTok: Label 'RegEx', Locked = true;
        NoRegExTok: Label 'NoRegEx', Locked = true;
        FieldCategoryTok: Label 'FieldCategory', Locked = true;
        HideDrillDownTok: Label 'HideDrillDown', Locked = true;
        ValidateAlwaysTok: Label 'ValidateAlways', Locked = true;
        VisibleTok: Label 'Visible', Locked = true;
        EditableTok: Label 'Editable', Locked = true;
        DisplayInMenuTok: Label 'DisplayInMenu', Locked = true;
        FilterableTok: Label 'Filterable', Locked = true;
        ImportanceTok: Label 'Importance', Locked = true;
        MobileTypeTok: Label 'MobileType', Locked = true;
        FunctionTypeTok: Label 'FunctionType', Locked = true;
        ValidationBehaviorTok: Label 'ValidationBehavior', Locked = true;
        FieldKindTok: Label 'Field', Locked = true;
        ButtonKindTok: Label 'Button', Locked = true;
        ScanKindTok: Label 'Scan', Locked = true;
        LookupKindTok: Label 'Lookup', Locked = true;
        LinkKindTok: Label 'Link', Locked = true;
        UnknownKindErr: Label 'The control kind %1 has no name for the provider writer.', Comment = '%1 = control kind';
}

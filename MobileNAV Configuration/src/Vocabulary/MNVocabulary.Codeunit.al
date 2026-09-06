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

    /// <summary>MobileNAV's MobileType for the barcode-scannable input a Scan control renders as.</summary>
    procedure BarcodeMobileTypeName(): Text[30]
    begin
        exit(this.BarcodeTok);
    end;

    /// <summary>MobileNAV's Page Type for the action-dialog pattern a PublishAsDialog page uses.</summary>
    procedure ReportPageTypeName(): Text[30]
    begin
        exit(this.ReportPageTypeTok);
    end;

    local procedure ValueName(Names: List of [Text]; Ordinals: List of [Integer]; Ordinal: Integer): Text[30]
    begin
        exit(CopyStr(Names.Get(Ordinals.IndexOf(Ordinal)), 1, 30));
    end;

    var
#pragma warning disable LC0086
        StandardImportanceTok: Label 'None', Locked = true;
#pragma warning restore LC0086
        BarcodeTok: Label 'Barcode', Locked = true;
        ReportPageTypeTok: Label 'Report', Locked = true;
}

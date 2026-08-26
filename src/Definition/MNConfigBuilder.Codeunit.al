
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Constrained builder used by providers to declare supported MobileNAV configuration.
/// It records intent only; it cannot apply configuration.
/// </summary>
codeunit 77781 "BJF MN Config Builder"
{
    /// <summary>Registers, refreshes, and publishes a MobileNAV page web service.</summary>
    procedure AddPublishedPage(PageId: Integer; PreferredServiceName: Text[100])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Published Page", PageId);
        TempConfigurationLine."Service Name" := PreferredServiceName;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Adds an explicit field configuration for an existing MobileNAV page, placing the field
    /// in MobileNAV's standard section and leaving it out of the device filter pane. Use the
    /// Importance/Filterable overload to place a field elsewhere or make it filterable.
    /// </summary>
    procedure AddField(PageId: Integer; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean)
    begin
        this.AddField(PageId, ControlName, Visible, Editable, DisplayInMenu, StandardImportanceTok, false);
    end;

    /// <summary>
    /// Adds an explicit field configuration for an existing MobileNAV page and controls where
    /// the device draws it and whether it can be filtered on. Importance follows MobileNAV's
    /// vocabulary: 'None' places the field in the standard section, 'RequiredForInsert' and
    /// 'Mandatory' mark it as required, and 'Additional' hides it behind the card's additional
    /// fields section (MobileNAV's own default for a new field). Filterable true also offers
    /// the field in the device's filter pane. Filter Scope is left at MobileNAV's default.
    /// </summary>
    procedure AddField(PageId: Integer; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean; Importance: Text[30]; Filterable: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Field, PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine.Visible := Visible;
        TempConfigurationLine.Editable := Editable;
        TempConfigurationLine."Display In Menu" := DisplayInMenu;
        TempConfigurationLine.Importance := Importance;
        TempConfigurationLine.Filterable := Filterable;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Makes a field visible on the page in MobileNAV's standard section and sets its
    /// editability.
    ///
    /// Display in Menu is deliberately not set. In MobileNAV that flag marks a field as an
    /// entry in the page's menu — which is what a drill-down button is — rather than a value
    /// drawn on the card, so setting it on an ordinary field keeps that field off the card.
    /// Use AddLinkedField for drill-downs, or AddField if a caller genuinely needs the flag.
    /// </summary>
    procedure AddVisibleField(PageId: Integer; ControlName: Text[100]; Editable: Boolean)
    begin
        this.AddField(PageId, ControlName, true, Editable, false, StandardImportanceTok, false);
    end;

    /// <summary>
    /// Makes a field visible in MobileNAV's standard section, sets its editability, and offers
    /// it in the device's filter pane. Filter Scope is left at MobileNAV's default, so the
    /// filter applies wherever that default allows.
    /// </summary>
    procedure AddFilterableField(PageId: Integer; ControlName: Text[100]; Editable: Boolean)
    begin
        this.AddField(PageId, ControlName, true, Editable, false, StandardImportanceTok, true);
    end;

    /// <summary>
    /// Makes a field visible and binds it to a target MobileNAV page using one FIELD filter.
    /// The target page can be declared with AddPublishedPage or already exist in MobileNAV.
    /// </summary>
    procedure AddLinkedField(PageId: Integer; ControlName: Text[100]; TargetPageId: Integer; TargetFilterField: Text[100]; SourceField: Text[100])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Linked Field", PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine."Target Page ID" := TargetPageId;
        TempConfigurationLine."Target Filter Field" := TargetFilterField;
        TempConfigurationLine."Source Field" := SourceField;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Makes a field visible and binds it to a MobileNAV page function so the device renders
    /// it as a special control (for example a Signature pad bound to a BLOB function).
    /// Editable false shows the control read-only, for example a captured signature on a
    /// posted document. Names are matched against MobileNAV's own option members at apply
    /// time, so they follow MobileNAV's vocabulary: MobileType (for example 'Signature',
    /// 'Image'), FunctionType (for example 'BLOB', 'BLOB with GPS'), and ValidationBehavior
    /// (for example 'Mandatory'; empty leaves the field optional).
    /// </summary>
    procedure AddFunctionField(PageId: Integer; ControlName: Text[100]; Editable: Boolean; MobileType: Text[30]; FunctionName: Text[50]; FunctionType: Text[30]; ValidationBehavior: Text[50])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Function Field", PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine.Editable := Editable;
        TempConfigurationLine."Mobile Type" := MobileType;
        TempConfigurationLine."Function Name" := FunctionName;
        TempConfigurationLine."Function Type" := FunctionType;
        TempConfigurationLine."Validation Behavior" := ValidationBehavior;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Registers, refreshes, and publishes a MobileNAV page web service and sets its main menu
    /// action. MainMenuAction follows MobileNAV's vocabulary ('Create' opens the page straight
    /// onto a new record from the home tile, 'Open' opens the single existing record). When a
    /// Main row for the page already exists under a different service name, a second,
    /// independently configured service is created for this one.
    /// </summary>
    procedure AddPublishedPage(PageId: Integer; PreferredServiceName: Text[100]; MainMenuAction: Text[30])
    begin
        this.AddPublishedPage(PageId, PreferredServiceName);
        TempConfigurationLine."Main Menu Action" := MainMenuAction;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Makes a field visible and editable and renders it as a barcode-scannable control.
    /// ValidationBehavior follows MobileNAV's vocabulary (for example 'ScanOrManualEntry';
    /// empty leaves the default behavior).
    /// </summary>
    procedure AddScanField(PageId: Integer; ControlName: Text[100]; ValidationBehavior: Text[50])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Scan Field", PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine."Mobile Type" := 'Barcode';
        TempConfigurationLine."Validation Behavior" := ValidationBehavior;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Turns the page into a staged wizard (staging behavior 'Always from scratch'). Declare
    /// this before any AddStage or AddStageField call for the same page; stages render in the
    /// order they are added.
    /// </summary>
    procedure EnableStaging(PageId: Integer; AutoNext: Boolean; BackNextVisible: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Staging, PageId);
        TempConfigurationLine."Auto Next Stage" := AutoNext;
        TempConfigurationLine."Back-Next Visible" := BackNextVisible;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Adds a wizard stage to a page declared with EnableStaging. The description becomes the
    /// stage's caption (a MobileNAV category record); fields not assigned to a stage via
    /// AddStageField stay hidden while that stage is active.
    /// </summary>
    procedure AddStage(PageId: Integer; StageId: Code[100]; Description: Text[250])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Stage, PageId);
        TempConfigurationLine."Stage Id" := StageId;
        TempConfigurationLine."Stage Description" := Description;
        TempConfigurationLine.Modify();
    end;

    /// <summary>
    /// Shows a field while the given stage is active. FieldEnabled=true lets the user edit or
    /// tap it; false shows it read-only for context. Declare the stage with AddStage first.
    /// </summary>
    procedure AddStageField(PageId: Integer; StageId: Code[100]; ControlName: Text[100]; FieldEnabled: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Stage Field", PageId);
        TempConfigurationLine."Stage Id" := StageId;
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine."Stage Enabled" := FieldEnabled;
        TempConfigurationLine.Modify();
    end;

    internal procedure GetLines(var Target: Record "BJF MN Config Line" temporary)
    begin
        Target.Copy(TempConfigurationLine, true);
    end;

    local procedure AddLine(Operation: Enum "BJF MN Config Operation"; PageId: Integer)
    begin
        NextEntryNo += 1;
        TempConfigurationLine.Init();
        TempConfigurationLine."Entry No." := NextEntryNo;
        TempConfigurationLine.Operation := Operation;
        TempConfigurationLine."Page ID" := PageId;
        TempConfigurationLine.Insert();
    end;

    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        NextEntryNo: Integer;
        StandardImportanceTok: Label 'None', Locked = true;
}

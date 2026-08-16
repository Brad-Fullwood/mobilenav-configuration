
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

    /// <summary>Adds an explicit field configuration for an existing MobileNAV page.</summary>
    procedure AddField(PageId: Integer; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Field, PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine.Visible := Visible;
        TempConfigurationLine.Editable := Editable;
        TempConfigurationLine."Display In Menu" := DisplayInMenu;
        TempConfigurationLine.Modify();
    end;

    /// <summary>Makes a field visible, displays it in the menu, and sets its editability.</summary>
    procedure AddVisibleField(PageId: Integer; ControlName: Text[100]; Editable: Boolean)
    begin
        this.AddField(PageId, ControlName, true, Editable, true);
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
}

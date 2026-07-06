
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
        AddLine(Enum::"BJF MN Config Operation"::"Published Page", PageId);
        TempConfigurationLine."Service Name" := PreferredServiceName;
        TempConfigurationLine.Modify();
    end;

    /// <summary>Adds an explicit field configuration for an existing MobileNAV page.</summary>
    procedure AddField(PageId: Integer; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean)
    begin
        AddLine(Enum::"BJF MN Config Operation"::Field, PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine.Visible := Visible;
        TempConfigurationLine.Editable := Editable;
        TempConfigurationLine."Display In Menu" := DisplayInMenu;
        TempConfigurationLine.Modify();
    end;

    /// <summary>Makes a field visible, displays it in the menu, and sets its editability.</summary>
    procedure AddVisibleField(PageId: Integer; ControlName: Text[100]; Editable: Boolean)
    begin
        AddField(PageId, ControlName, true, Editable, true);
    end;

    /// <summary>
    /// Makes a field visible and binds it to a target MobileNAV page using one FIELD filter.
    /// The target page can be declared with AddPublishedPage or already exist in MobileNAV.
    /// </summary>
    procedure AddLinkedField(PageId: Integer; ControlName: Text[100]; TargetPageId: Integer; TargetFilterField: Text[100]; SourceField: Text[100])
    begin
        AddLine(Enum::"BJF MN Config Operation"::"Linked Field", PageId);
        TempConfigurationLine."Control Name" := ControlName;
        TempConfigurationLine."Target Page ID" := TargetPageId;
        TempConfigurationLine."Target Filter Field" := TargetFilterField;
        TempConfigurationLine."Source Field" := SourceField;
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

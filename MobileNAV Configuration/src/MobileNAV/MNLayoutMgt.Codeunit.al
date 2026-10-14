namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes dynamic layouts: MobileNAV rules that change a page's look while their conditions
/// hold. A layout's conditions, actions and action lines are rebuilt from the definition on
/// every apply and written the way MobileNAV's own import writes them.
/// </summary>
codeunit 77764 "BJF MN Layout Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV D. L. Action" = rid,
        tabledata "MobileNAV D. L. Action Line" = id,
        tabledata "MobileNAV D. L. Condition" = id,
        tabledata "MobileNAV Dynamic Layout" = rim;

    procedure ApplyLayout(ServiceName: Text[100]; var LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        DynamicLayout: Record "MobileNAV Dynamic Layout";
        Condition: Record "MobileNAV D. L. Condition";
        LayoutAction: Record "MobileNAV D. L. Action";
        ActionLine: Record "MobileNAV D. L. Action Line";
    begin
        this.WriteLayout(ServiceName, LayoutLine, TempLine, DynamicLayout, Condition, LayoutAction, ActionLine);
    end;

    /// <summary>Writes the layout with its conditions, actions and action lines: the real tables on apply, temporary copies when the Doctor compares.</summary>
    /// <param name="ServiceName">The service the layout belongs to.</param>
    /// <param name="LayoutLine">The layout line from the definition.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="DynamicLayout">Receives the layout row.</param>
    /// <param name="Condition">Receives the condition rows.</param>
    /// <param name="LayoutAction">Receives the action rows.</param>
    /// <param name="ActionLine">Receives the action line rows.</param>
    procedure WriteLayout(ServiceName: Text[100]; var LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var DynamicLayout: Record "MobileNAV Dynamic Layout"; var Condition: Record "MobileNAV D. L. Condition"; var LayoutAction: Record "MobileNAV D. L. Action"; var ActionLine: Record "MobileNAV D. L. Action Line")
    begin
        this.UpsertLayout(ServiceName, LayoutLine, DynamicLayout);
        this.DeleteRules(DynamicLayout, Condition, LayoutAction, ActionLine);
        this.InsertConditions(DynamicLayout, LayoutLine, TempLine, Condition);
        this.InsertActions(DynamicLayout, LayoutLine, TempLine, LayoutAction, ActionLine);
    end;

    procedure FindLayout(ServiceName: Text[100]; LayoutCode: Code[50]; var DynamicLayout: Record "MobileNAV Dynamic Layout"): Boolean
    begin
        exit(DynamicLayout.Get(ServiceName, LayoutCode));
    end;

    local procedure UpsertLayout(ServiceName: Text[100]; LayoutLine: Record "BJF MN Config Line" temporary; var DynamicLayout: Record "MobileNAV Dynamic Layout")
    var
        LastLayout: Record "MobileNAV Dynamic Layout";
        IsNew: Boolean;
    begin
        IsNew := not DynamicLayout.Get(ServiceName, CopyStr(LayoutLine."Control Name", 1, MaxStrLen(DynamicLayout.Code)));
        // Written as MobileNAV's import writes layouts: assigned directly, triggers off.
#pragma warning disable PC0037
        if IsNew then begin
            DynamicLayout.Init();
            DynamicLayout."Service Name" := ServiceName;
            DynamicLayout.Code := CopyStr(LayoutLine."Control Name", 1, MaxStrLen(DynamicLayout.Code));
            // Order is MobileNAV's own append-to-end step.
            LastLayout.SetLoadFields(Order);
            LastLayout.SetCurrentKey("Service Name", Order);
            LastLayout.SetRange("Service Name", ServiceName);
            if LastLayout.FindLast() then
                DynamicLayout.Order := LastLayout.Order + 10000
            else
                DynamicLayout.Order := 10000;
        end;
        DynamicLayout.Description := CopyStr(LayoutLine.Description, 1, MaxStrLen(DynamicLayout.Description));
        DynamicLayout.Disabled := LayoutLine.Disabled;
#pragma warning restore PC0037
        if IsNew then
            DynamicLayout.Insert(false)
        else
            DynamicLayout.Modify(false);
    end;

    local procedure DeleteRules(DynamicLayout: Record "MobileNAV Dynamic Layout"; var Condition: Record "MobileNAV D. L. Condition"; var LayoutAction: Record "MobileNAV D. L. Action"; var ActionLine: Record "MobileNAV D. L. Action Line")
    begin
        Condition.SetRange("Service Name", DynamicLayout."Service Name");
        Condition.SetRange("Layout Code", DynamicLayout.Code);
        Condition.DeleteAll(false);
        Condition.Reset();
        ActionLine.SetRange("Service Name", DynamicLayout."Service Name");
        ActionLine.SetRange("Layout Code", DynamicLayout.Code);
        ActionLine.DeleteAll(false);
        ActionLine.Reset();
        LayoutAction.SetRange("Service Name", DynamicLayout."Service Name");
        LayoutAction.SetRange("Layout Code", DynamicLayout.Code);
        LayoutAction.DeleteAll(false);
        LayoutAction.Reset();
    end;

    local procedure InsertConditions(DynamicLayout: Record "MobileNAV Dynamic Layout"; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var Condition: Record "MobileNAV D. L. Condition")
    var
        ConditionRef: RecordRef;
        LineNo: Integer;
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", LayoutLine."Page ID");
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Layout Condition");
        TempLine.SetRange("Control Name", LayoutLine."Control Name");
        if TempLine.FindSet() then
            repeat
                LineNo += 10000;
#pragma warning disable PC0037
                Condition.Init();
                Condition."Service Name" := DynamicLayout."Service Name";
                Condition."Layout Code" := DynamicLayout.Code;
                Condition."Line No." := LineNo;
                Condition.DestFieldName := this.Lookup.StoredFieldName(TempLine."Target Filter Field");
                ConditionRef.GetTable(Condition);
                this.Lookup.SetOption(ConditionRef, Condition.FieldNo(ConditionType), TempLine."Filter Type");
                this.Lookup.SetOption(ConditionRef, Condition.FieldNo("Comparsion Type"), TempLine.Comparison);
                ConditionRef.SetTable(Condition);
                if TempLine."Source Field" <> '' then
                    Condition.SourceFieldName := this.Lookup.StoredFieldName(TempLine."Source Field")
                else
                    Condition.ConditionValue := TempLine."Filter Value";
#pragma warning restore PC0037
                Condition.Insert(false);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    /// <summary>One action row per action type; a field or stage target becomes an action line under it.</summary>
    /// <param name="DynamicLayout">The layout the actions belong to.</param>
    /// <param name="LayoutLine">The layout line from the definition.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="LayoutAction">Receives the action rows.</param>
    /// <param name="ActionLine">Receives the action line rows.</param>
    local procedure InsertActions(DynamicLayout: Record "MobileNAV Dynamic Layout"; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var LayoutAction: Record "MobileNAV D. L. Action"; var ActionLine: Record "MobileNAV D. L. Action Line")
    var
        ActionLineRef: RecordRef;
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", LayoutLine."Page ID");
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Layout Action");
        TempLine.SetRange("Control Name", LayoutLine."Control Name");
        if TempLine.FindSet() then
            repeat
                this.EnsureAction(DynamicLayout, TempLine, LayoutAction);
                if TempLine."Target Filter Field" <> '' then begin
                    // A line's Caption, Color and Icon triggers would blank the action's shared values.
                    // MobileNAV's Color option has no blank member: an action without a colour keeps Normal.
#pragma warning disable PC0037
                    ActionLine.Init();
                    ActionLine."Service Name" := DynamicLayout."Service Name";
                    ActionLine."Layout Code" := DynamicLayout.Code;
                    ActionLine."Action Type" := LayoutAction.Type;
                    ActionLine."Related Page Name" := '';
                    ActionLine.Name := this.TargetName(TempLine);
                    ActionLine.Caption := this.CaptionOf(TempLine);
                    if TempLine.Color <> '' then begin
                        ActionLineRef.GetTable(ActionLine);
                        this.Lookup.SetOption(ActionLineRef, ActionLine.FieldNo(Color), TempLine.Color);
                        ActionLineRef.SetTable(ActionLine);
                    end;
                    ActionLine.Icon := TempLine.Icon;
#pragma warning restore PC0037
                    ActionLine.Insert(false);
                end;
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure EnsureAction(DynamicLayout: Record "MobileNAV Dynamic Layout"; ActionLineDefinition: Record "BJF MN Config Line" temporary; var LayoutAction: Record "MobileNAV D. L. Action")
    var
        ActionRef: RecordRef;
    begin
#pragma warning disable PC0037
        LayoutAction.Init();
        LayoutAction."Service Name" := DynamicLayout."Service Name";
        LayoutAction."Layout Code" := DynamicLayout.Code;
        ActionRef.GetTable(LayoutAction);
        this.Lookup.SetOption(ActionRef, LayoutAction.FieldNo(Type), ActionLineDefinition."Action Type");
        ActionRef.SetTable(LayoutAction);
        if LayoutAction.Find() then
            exit;
        // Page-wide actions carry their caption, color and icon on the action itself.
        if ActionLineDefinition."Target Filter Field" = '' then begin
            LayoutAction.Caption := this.CaptionOf(ActionLineDefinition);
            if ActionLineDefinition.Color <> '' then begin
                ActionRef.GetTable(LayoutAction);
                this.Lookup.SetOption(ActionRef, LayoutAction.FieldNo(Color), ActionLineDefinition.Color);
                ActionRef.SetTable(LayoutAction);
            end;
            LayoutAction.Icon := ActionLineDefinition.Icon;
        end;
#pragma warning restore PC0037
        LayoutAction.Insert(false);
    end;

    /// <summary>Stage actions name the stage as declared; field actions name the field as MobileNAV stores it.</summary>
    /// <param name="ActionLineDefinition">The action line from the definition.</param>
    /// <returns>The stage name or the stored field name.</returns>
    local procedure TargetName(ActionLineDefinition: Record "BJF MN Config Line" temporary): Text[75]
    begin
        if ActionLineDefinition."Action Type" in [this.HideStageTok, this.StageValidatedTok] then
            exit(CopyStr(ActionLineDefinition."Target Filter Field", 1, 75));
        exit(this.Lookup.StoredFieldName(ActionLineDefinition."Target Filter Field"));
    end;

    local procedure CaptionOf(ActionLineDefinition: Record "BJF MN Config Line" temporary): Text[250]
    begin
        exit(ActionLineDefinition."Group Code");
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        HideStageTok: Label 'HideStage', Locked = true;
        StageValidatedTok: Label 'StageValidated', Locked = true;
}

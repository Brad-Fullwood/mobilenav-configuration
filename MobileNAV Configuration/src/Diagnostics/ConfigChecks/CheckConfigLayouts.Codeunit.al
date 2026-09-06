namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every declared dynamic layout exist with its conditions, actions and action lines?
/// Compared with what "BJF MN Layout Mgt." would write; the fix rewrites the layout.
/// </summary>
codeunit 77703 "BJF Check Config Layouts" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Dynamic Layout" = r,
        tabledata "MobileNAV D. L. Condition" = r,
        tabledata "MobileNAV D. L. Action" = r,
        tabledata "MobileNAV D. L. Action Line" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
        TempLayoutLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                TempLayoutLine.Copy(TempLine, true);
                TempLayoutLine.Reset();
                TempLayoutLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Layout);
                if TempLayoutLine.FindSet() then
                    repeat
                        this.CheckLayout(Finding, TempProvider, TempLayoutLine, TempLine);
                    until TempLayoutLine.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempLayoutLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        PageId: Integer;
        ServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.LayoutFixTok then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(PageId, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        TempLayoutLine.Copy(TempLine, true);
        TempLayoutLine.Reset();
        TempLayoutLine.SetRange("Page ID", PageId);
        TempLayoutLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Layout);
        TempLayoutLine.SetRange("Control Name", CopyStr(Args.Get(3), 1, 100));
        if not TempLayoutLine.FindFirst() then
            Error(this.LayoutGoneErr);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        this.LayoutManagement.ApplyLayout(ServiceName, TempLayoutLine, TempLine);
    end;

    local procedure CheckLayout(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        DynamicLayout: Record "MobileNAV Dynamic Layout";
        MainRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        Problem: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Lookup.GetServiceName(LayoutLine."Page ID");
        if ServiceName = '' then
            exit;
        if not this.LayoutManagement.FindLayout(ServiceName, CopyStr(LayoutLine."Control Name", 1, 50), DynamicLayout) then
            Problem := this.MissingLbl
        else
            Problem := this.HeadProblem(DynamicLayout, LayoutLine);
        if Problem = '' then
            Problem := this.ConditionProblem(DynamicLayout, LayoutLine, TempLine);
        if Problem = '' then
            Problem := this.ActionProblem(DynamicLayout, LayoutLine, TempLine);
        if Problem = '' then
            exit;
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(LayoutLine."Page ID", 0, 9));
        Args.Add(LayoutLine."Control Name");
        if this.Lookup.FindMainRow(ServiceName, MainRow) then;
        Finding.AddWithFix(Finding."Check Type"::"Config Layouts", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.LayoutMsg, LayoutLine."Control Name", ServiceName, Problem)),
            MainRow.RecordId(), StrSubstNo(this.FixMsg, LayoutLine."Control Name", ServiceName),
            this.Support.PackFix(this.LayoutFixTok, Args));
    end;

    local procedure HeadProblem(DynamicLayout: Record "MobileNAV Dynamic Layout"; LayoutLine: Record "BJF MN Config Line" temporary): Text
    begin
        if DynamicLayout.Description <> LayoutLine.Description then
            exit(this.DescriptionLbl);
        if DynamicLayout.Disabled <> LayoutLine.Disabled then
            exit(this.DisabledLbl);
        exit('');
    end;

    local procedure ConditionProblem(DynamicLayout: Record "MobileNAV Dynamic Layout"; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Text
    var
        Condition: Record "MobileNAV D. L. Condition";
        ConditionRef: RecordRef;
        Expected: List of [Text];
        Index: Integer;
    begin
        Expected := this.ExpectedConditions(LayoutLine, TempLine);
        Condition.SetRange("Service Name", DynamicLayout."Service Name");
        Condition.SetRange("Layout Code", DynamicLayout.Code);
        if Condition.Count() <> Expected.Count() then
            exit(StrSubstNo(this.CountLbl, this.ConditionsLbl, Expected.Count(), Condition.Count()));
        if Condition.FindSet() then
            repeat
                Index += 1;
                ConditionRef.GetTable(Condition);
                if this.Join(Condition.DestFieldName, UpperCase(this.OptionMemberName(ConditionRef, Condition.FieldNo(ConditionType))) + this.SeparatorTok + UpperCase(this.OptionMemberName(ConditionRef, Condition.FieldNo("Comparsion Type"))), Condition.SourceFieldName + this.SeparatorTok + Condition.ConditionValue) <> Expected.Get(Index) then
                    exit(StrSubstNo(this.RowLbl, this.ConditionsLbl, Index));
            until Condition.Next() = 0;
        exit('');
    end;

    local procedure ExpectedConditions(LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary) Expected: List of [Text]
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", LayoutLine."Page ID");
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Layout Condition");
        TempLine.SetRange("Control Name", LayoutLine."Control Name");
        if TempLine.FindSet() then
            repeat
                Expected.Add(this.Join(this.Lookup.StoredFieldName(TempLine."Target Filter Field"), UpperCase(TempLine."Filter Type") + this.SeparatorTok + UpperCase(TempLine.Comparison), this.Lookup.StoredFieldName(TempLine."Source Field") + this.SeparatorTok + TempLine."Filter Value"));
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    /// <summary>One action row per declared action type; each targeted action as an action line under it.</summary>
    local procedure ActionProblem(DynamicLayout: Record "MobileNAV Dynamic Layout"; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Text
    var
        LayoutAction: Record "MobileNAV D. L. Action";
        ActionLine: Record "MobileNAV D. L. Action Line";
        ActionTypes: List of [Text];
        Problem: Text;
        TargetedCount: Integer;
    begin
        Problem := this.DeclaredActions(DynamicLayout, LayoutLine, TempLine, ActionTypes, TargetedCount);
        if Problem <> '' then
            exit(Problem);

        LayoutAction.SetRange("Service Name", DynamicLayout."Service Name");
        LayoutAction.SetRange("Layout Code", DynamicLayout.Code);
        if LayoutAction.Count() <> ActionTypes.Count() then
            exit(StrSubstNo(this.CountLbl, this.ActionsLbl, ActionTypes.Count(), LayoutAction.Count()));
        ActionLine.SetRange("Service Name", DynamicLayout."Service Name");
        ActionLine.SetRange("Layout Code", DynamicLayout.Code);
        if ActionLine.Count() <> TargetedCount then
            exit(StrSubstNo(this.CountLbl, this.ActionLinesLbl, TargetedCount, ActionLine.Count()));
        exit('');
    end;

    /// <summary>Walks the declared actions, collecting their distinct types and how many name a target; returns the first action that differs.</summary>
    local procedure DeclaredActions(DynamicLayout: Record "MobileNAV Dynamic Layout"; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var ActionTypes: List of [Text]; var TargetedCount: Integer) Problem: Text
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", LayoutLine."Page ID");
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Layout Action");
        TempLine.SetRange("Control Name", LayoutLine."Control Name");
        if TempLine.FindSet() then
            repeat
                if not ActionTypes.Contains(UpperCase(TempLine."Action Type")) then
                    ActionTypes.Add(UpperCase(TempLine."Action Type"));
                if TempLine."Target Filter Field" <> '' then
                    TargetedCount += 1;
                if Problem = '' then
                    Problem := this.ActionLineProblem(DynamicLayout, TempLine);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure ActionLineProblem(DynamicLayout: Record "MobileNAV Dynamic Layout"; ActionDefinition: Record "BJF MN Config Line" temporary): Text
    var
        LayoutAction: Record "MobileNAV D. L. Action";
        ActionLine: Record "MobileNAV D. L. Action Line";
        ActionRef: RecordRef;
        LineRef: RecordRef;
    begin
        LayoutAction.SetRange("Service Name", DynamicLayout."Service Name");
        LayoutAction.SetRange("Layout Code", DynamicLayout.Code);
        ActionRef.GetTable(LayoutAction);
        if not this.FindByMember(ActionRef, LayoutAction.FieldNo(Type), ActionDefinition."Action Type") then
            exit(StrSubstNo(this.NoActionLbl, ActionDefinition."Action Type"));
        ActionRef.SetTable(LayoutAction);
        if ActionDefinition."Target Filter Field" = '' then begin
            if not this.ValuesMatch(ActionRef, LayoutAction.FieldNo(Color), LayoutAction.Caption, LayoutAction.Icon, ActionDefinition) then
                exit(StrSubstNo(this.ActionValuesLbl, ActionDefinition."Action Type"));
            exit('');
        end;
        ActionLine.SetRange("Service Name", DynamicLayout."Service Name");
        ActionLine.SetRange("Layout Code", DynamicLayout.Code);
        ActionLine.SetRange("Action Type", LayoutAction.Type);
        ActionLine.SetRange("Related Page Name", '');
        ActionLine.SetRange(Name, this.TargetName(ActionDefinition));
        if not ActionLine.FindFirst() then
            exit(StrSubstNo(this.NoActionLineLbl, ActionDefinition."Action Type", ActionDefinition."Target Filter Field"));
        LineRef.GetTable(ActionLine);
        if not this.ValuesMatch(LineRef, ActionLine.FieldNo(Color), ActionLine.Caption, ActionLine.Icon, ActionDefinition) then
            exit(StrSubstNo(this.ActionLineValuesLbl, ActionDefinition."Action Type", ActionDefinition."Target Filter Field"));
        exit('');
    end;

    local procedure ValuesMatch(var TargetRef: RecordRef; ColorFieldNo: Integer; LiveCaption: Text; LiveIcon: Text; ActionDefinition: Record "BJF MN Config Line" temporary): Boolean
    begin
        if (LiveCaption <> ActionDefinition."Group Code") or (LiveIcon <> ActionDefinition.Icon) then
            exit(false);
        exit(UpperCase(this.OptionMemberName(TargetRef, ColorFieldNo)) = UpperCase(this.ColorOrNormal(ActionDefinition.Color)));
    end;

    local procedure TargetName(ActionDefinition: Record "BJF MN Config Line" temporary): Text[75]
    begin
        if UpperCase(ActionDefinition."Action Type") in [this.HideStageTok, this.StageValidatedTok] then
            exit(CopyStr(ActionDefinition."Target Filter Field", 1, 75));
        exit(this.Lookup.StoredFieldName(ActionDefinition."Target Filter Field"));
    end;

    local procedure ColorOrNormal(Color: Text): Text
    begin
        if Color = '' then
            exit(this.NormalTok);
        exit(Color);
    end;

    /// <summary>Positions the filtered set on the row whose option field has the named member.</summary>
    local procedure FindByMember(var TargetRef: RecordRef; FieldNo: Integer; MemberName: Text): Boolean
    begin
        if TargetRef.FindSet() then
            repeat
                if UpperCase(this.OptionMemberName(TargetRef, FieldNo)) = UpperCase(MemberName) then
                    exit(true);
            until TargetRef.Next() = 0;
        exit(false);
    end;

    local procedure OptionMemberName(var TargetRef: RecordRef; FieldNo: Integer): Text
    var
        OptionFieldRef: FieldRef;
        Ordinal: Integer;
        MemberIndex: Integer;
    begin
        OptionFieldRef := TargetRef.Field(FieldNo);
        Ordinal := OptionFieldRef.Value();
        for MemberIndex := 1 to OptionFieldRef.EnumValueCount() do
            if OptionFieldRef.GetEnumValueOrdinal(MemberIndex) = Ordinal then
                exit(OptionFieldRef.GetEnumValueName(MemberIndex));
        exit('');
    end;

    local procedure Join(First: Text; Second: Text; Third: Text): Text
    begin
        exit(First + this.SeparatorTok + Second + this.SeparatorTok + Third);
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        LayoutManagement: Codeunit "BJF MN Layout Mgt.";
        LayoutMsg: Label 'Layout %1 on %2 does not match MobileNAV: %3', Comment = '%1 = layout code, %2 = service name, %3 = what differs';
        FixMsg: Label 'Rewrite layout %1 of %2 with its conditions and actions.', Comment = '%1 = layout code, %2 = service name';
        MissingLbl: Label 'the layout is missing.';
        DescriptionLbl: Label 'the description differs.';
        DisabledLbl: Label 'the disabled switch differs.';
        CountLbl: Label '%1: %2 declared, %3 found.', Comment = '%1 = row kind, %2 = declared count, %3 = live count';
        RowLbl: Label '%1: row %2 differs.', Comment = '%1 = row kind, %2 = row position';
        NoActionLbl: Label 'action %1 is missing.', Comment = '%1 = action type';
        ActionValuesLbl: Label 'action %1 carries other values.', Comment = '%1 = action type';
        NoActionLineLbl: Label 'action %1 on %2 is missing.', Comment = '%1 = action type, %2 = target';
        ActionLineValuesLbl: Label 'action %1 on %2 carries other values.', Comment = '%1 = action type, %2 = target';
        ConditionsLbl: Label 'conditions';
        ActionsLbl: Label 'actions';
        ActionLinesLbl: Label 'action lines';
        LayoutGoneErr: Label 'The provider no longer declares this layout.';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        LayoutFixTok: Label 'LAYOUT', Locked = true;
        HideStageTok: Label 'HIDESTAGE', Locked = true;
        StageValidatedTok: Label 'STAGEVALIDATED', Locked = true;
        NormalTok: Label 'Normal', Locked = true;
        SeparatorTok: Label '|', Locked = true;
}

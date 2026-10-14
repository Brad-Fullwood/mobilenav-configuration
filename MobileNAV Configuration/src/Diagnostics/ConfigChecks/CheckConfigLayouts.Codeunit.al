namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every declared dynamic layout exist with its conditions, actions and action lines?
/// The writer builds the declared rows into temporary records, and those rows are compared
/// with the live rows. The fix rewrites the layout.
/// </summary>
codeunit 77703 "BJF Check Config Layouts" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV D. L. Action" = r,
        tabledata "MobileNAV D. L. Action Line" = r,
        tabledata "MobileNAV D. L. Condition" = r;

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
        PageId: Integer;
        ServiceName: Text[100];
    begin
        this.Support.ReadProviderFix(Finding, this.LayoutFixTok, Kind, Args, TempLine);
        Evaluate(PageId, Args.Get(1));
        TempLayoutLine.Copy(TempLine, true);
        TempLayoutLine.Reset();
        TempLayoutLine.SetRange("Page ID", PageId);
        TempLayoutLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Layout);
        TempLayoutLine.SetRange("Control Name", CopyStr(Args.Get(2), 1, 100));
        if not TempLayoutLine.FindFirst() then
            Error(this.LayoutGoneErr);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        this.LayoutManagement.ApplyLayout(ServiceName, TempLayoutLine, TempLine);
    end;

    local procedure CheckLayout(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        ServiceName: Text[100];
        Problem: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(LayoutLine."Page ID");
        if ServiceName = '' then
            exit;
        Problem := this.LayoutProblem(ServiceName, LayoutLine, TempLine);
        if Problem = '' then
            exit;
        Args.Add(Format(LayoutLine."Page ID", 0, 9));
        Args.Add(LayoutLine."Control Name");
        this.Support.AddProviderFinding(Finding, Finding."Check Type"::"Config Layouts", Finding.Severity::Blocker, TempProvider,
            StrSubstNo(this.LayoutMsg, LayoutLine."Control Name", ServiceName, Problem), this.Support.MainRowId(ServiceName),
            StrSubstNo(this.FixMsg, LayoutLine."Control Name", ServiceName), this.LayoutFixTok, Args);
    end;

    /// <summary>Builds the declared layout rows and compares them with the live layout.</summary>
    /// <param name="ServiceName">The service the layout belongs to.</param>
    /// <param name="LayoutLine">The declared layout line.</param>
    /// <param name="TempLine">The provider's definition.</param>
    /// <returns>A description of the first difference, or empty when the layout matches.</returns>
    local procedure LayoutProblem(ServiceName: Text[100]; LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Text
    var
        DynamicLayout: Record "MobileNAV Dynamic Layout";
        TempLayout: Record "MobileNAV Dynamic Layout" temporary;
        TempCondition: Record "MobileNAV D. L. Condition" temporary;
        TempAction: Record "MobileNAV D. L. Action" temporary;
        TempActionLine: Record "MobileNAV D. L. Action Line" temporary;
        Problem: Text;
    begin
        if not this.TryWriteLayout(ServiceName, LayoutLine, TempLine, TempLayout, TempCondition, TempAction, TempActionLine) then
            exit(GetLastErrorText());
        if not this.LayoutManagement.FindLayout(ServiceName, TempLayout.Code, DynamicLayout) then
            exit(this.MissingLbl);
        Problem := this.HeadProblem(DynamicLayout, TempLayout);
        if Problem = '' then
            Problem := this.ConditionProblem(ServiceName, TempLayout.Code, TempCondition);
        if Problem = '' then
            Problem := this.ActionsProblem(ServiceName, TempLayout.Code, TempAction);
        if Problem = '' then
            Problem := this.ActionLinesProblem(ServiceName, TempLayout.Code, TempActionLine);
        exit(Problem);
    end;

    // The writer raises the same error the apply would. A failure becomes the finding text.
    [TryFunction]
    local procedure TryWriteLayout(ServiceName: Text[100]; var LayoutLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var TempLayout: Record "MobileNAV Dynamic Layout" temporary; var TempCondition: Record "MobileNAV D. L. Condition" temporary; var TempAction: Record "MobileNAV D. L. Action" temporary; var TempActionLine: Record "MobileNAV D. L. Action Line" temporary)
    begin
        this.LayoutManagement.WriteLayout(ServiceName, LayoutLine, TempLine, TempLayout, TempCondition, TempAction, TempActionLine);
    end;

    local procedure HeadProblem(DynamicLayout: Record "MobileNAV Dynamic Layout"; TempLayout: Record "MobileNAV Dynamic Layout" temporary): Text
    begin
        if DynamicLayout.Description <> TempLayout.Description then
            exit(this.DescriptionLbl);
        if DynamicLayout.Disabled <> TempLayout.Disabled then
            exit(this.DisabledLbl);
        exit('');
    end;

    local procedure ConditionProblem(ServiceName: Text[100]; LayoutCode: Code[50]; var TempConditions: Record "MobileNAV D. L. Condition" temporary): Text
    var
        LiveConditions: Record "MobileNAV D. L. Condition";
    begin
        TempConditions.SetRange("Service Name", ServiceName);
        TempConditions.SetRange("Layout Code", LayoutCode);
        LiveConditions.SetRange("Service Name", ServiceName);
        LiveConditions.SetRange("Layout Code", LayoutCode);
        exit(this.Support.FirstDifference(this.ConditionsLbl, this.ConditionSignatures(TempConditions), this.ConditionSignatures(LiveConditions)));
    end;

    /// <summary>Lists one signature per condition row of the filtered set, in primary key order.</summary>
    /// <param name="Conditions">The filtered condition rows.</param>
    /// <returns>The signatures.</returns>
    local procedure ConditionSignatures(var Conditions: Record "MobileNAV D. L. Condition"): List of [Text]
    var
        ConditionRef: RecordRef;
        Signatures: List of [Text];
    begin
        if Conditions.FindSet() then
            repeat
                ConditionRef.GetTable(Conditions);
                Signatures.Add(this.Support.Signature(Conditions.DestFieldName, UpperCase(this.Lookup.OptionName(ConditionRef, Conditions.FieldNo(ConditionType))), UpperCase(this.Lookup.OptionName(ConditionRef, Conditions.FieldNo("Comparsion Type"))), Conditions.SourceFieldName, Conditions.ConditionValue));
            until Conditions.Next() = 0;
        exit(Signatures);
    end;

    local procedure ActionsProblem(ServiceName: Text[100]; LayoutCode: Code[50]; var TempActions: Record "MobileNAV D. L. Action" temporary): Text
    var
        LiveActions: Record "MobileNAV D. L. Action";
    begin
        TempActions.SetRange("Service Name", ServiceName);
        TempActions.SetRange("Layout Code", LayoutCode);
        LiveActions.SetRange("Service Name", ServiceName);
        LiveActions.SetRange("Layout Code", LayoutCode);
        exit(this.Support.FirstDifference(this.ActionsLbl, this.ActionSignatures(TempActions), this.ActionSignatures(LiveActions)));
    end;

    /// <summary>Lists one signature per action row of the filtered set, in primary key order.</summary>
    /// <param name="ActionRows">The filtered action rows.</param>
    /// <returns>The signatures.</returns>
    local procedure ActionSignatures(var ActionRows: Record "MobileNAV D. L. Action"): List of [Text]
    var
        ActionRef: RecordRef;
        Signatures: List of [Text];
    begin
        if ActionRows.FindSet() then
            repeat
                ActionRef.GetTable(ActionRows);
                Signatures.Add(this.Support.Signature(UpperCase(this.Lookup.OptionName(ActionRef, ActionRows.FieldNo(Type))), ActionRows.Caption, UpperCase(this.Lookup.OptionName(ActionRef, ActionRows.FieldNo(Color))), ActionRows.Icon, ''));
            until ActionRows.Next() = 0;
        exit(Signatures);
    end;

    local procedure ActionLinesProblem(ServiceName: Text[100]; LayoutCode: Code[50]; var TempActionLines: Record "MobileNAV D. L. Action Line" temporary): Text
    var
        LiveActionLines: Record "MobileNAV D. L. Action Line";
    begin
        TempActionLines.SetRange("Service Name", ServiceName);
        TempActionLines.SetRange("Layout Code", LayoutCode);
        LiveActionLines.SetRange("Service Name", ServiceName);
        LiveActionLines.SetRange("Layout Code", LayoutCode);
        exit(this.Support.FirstDifference(this.ActionLinesLbl, this.ActionLineSignatures(TempActionLines), this.ActionLineSignatures(LiveActionLines)));
    end;

    /// <summary>Lists one signature per action line of the filtered set, in primary key order. The related page is always empty and left out.</summary>
    /// <param name="ActionLines">The filtered action line rows.</param>
    /// <returns>The signatures.</returns>
    local procedure ActionLineSignatures(var ActionLines: Record "MobileNAV D. L. Action Line"): List of [Text]
    var
        ActionLineRef: RecordRef;
        Signatures: List of [Text];
    begin
        if ActionLines.FindSet() then
            repeat
                ActionLineRef.GetTable(ActionLines);
                Signatures.Add(this.Support.Signature(UpperCase(this.Lookup.OptionName(ActionLineRef, ActionLines.FieldNo("Action Type"))), ActionLines.Name, ActionLines.Caption, UpperCase(this.Lookup.OptionName(ActionLineRef, ActionLines.FieldNo(Color))), ActionLines.Icon));
            until ActionLines.Next() = 0;
        exit(Signatures);
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
        ConditionsLbl: Label 'conditions';
        ActionsLbl: Label 'actions';
        ActionLinesLbl: Label 'action lines';
        LayoutGoneErr: Label 'The provider no longer declares this layout.';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        LayoutFixTok: Label 'LAYOUT', Locked = true;
}

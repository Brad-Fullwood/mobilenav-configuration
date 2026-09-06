namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does a declared wizard exist on the live page as declared? The Main row's staging switches,
/// the Stage rows in order with their restart flag, and each Show/ShowReadOnly's token in
/// the field's stage mask are compared. The fix rewrites the page's whole staging.
/// </summary>
codeunit 77769 "BJF Check Config Staging" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
        StagedPageIds: List of [Integer];
        PageId: Integer;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                Clear(StagedPageIds);
                TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
                if TempLine.FindSet() then
                    repeat
                        StagedPageIds.Add(TempLine."Page ID");
                    until TempLine.Next() = 0;
                foreach PageId in StagedPageIds do
                    this.CheckPage(Finding, TempProvider, TempLine, PageId);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        PageId: Integer;
        ServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.StagingFixTok then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(PageId, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        StageManagement.ApplyPageStaging(ServiceName, TempLine, PageId);
    end;

    local procedure CheckPage(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        MainRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        StageIds: List of [Text];
        Problem: Text;
    begin
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            exit; // Reported by the services check.
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            exit;

        TempLine.Reset();
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
        TempLine.FindFirst();
        Problem := this.SwitchProblem(MainRow, TempLine);
        if Problem = '' then
            Problem := this.StageRowProblem(ServiceName, TempLine, StageIds);
        if Problem = '' then
            Problem := this.MaskProblem(ServiceName, TempLine, StageIds);
        TempLine.Reset();
        if Problem = '' then
            exit;
        this.Report(Finding, TempProvider, PageId, ServiceName, MainRow, Problem);
    end;

    local procedure SwitchProblem(MainRow: Record "MobileNAV Service Setup"; StagingLine: Record "BJF MN Config Line" temporary): Text
    begin
        if not MainRow."Enable Staging" then
            exit(this.NotEnabledLbl);
        if MainRow."Auto Next Stage" <> StagingLine."Auto Next Stage" then
            exit(StrSubstNo(this.SwitchLbl, MainRow.FieldCaption("Auto Next Stage"), StagingLine."Auto Next Stage"));
        if MainRow."Back-Next Visible" <> StagingLine."Back-Next Visible" then
            exit(StrSubstNo(this.SwitchLbl, MainRow.FieldCaption("Back-Next Visible"), StagingLine."Back-Next Visible"));
        if (StagingLine."Staging Behavior" <> '') and
           (UpperCase(this.Lookup.OptionName(MainRow, MainRow.FieldNo("Staging Behavior"))) <> UpperCase(StagingLine."Staging Behavior"))
        then
            exit(StrSubstNo(this.SwitchLbl, MainRow.FieldCaption("Staging Behavior"), StagingLine."Staging Behavior"));
        exit('');
    end;

    /// <summary>Stage rows must match the declared stages in order, with the restart flag on the declared one.</summary>
    local procedure StageRowProblem(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; var StageIds: List of [Text]): Text
    var
        StageRow: Record "MobileNAV Service Setup";
        RestartFrom: List of [Boolean];
        Index: Integer;
    begin
        this.CollectDeclaredStages(TempLine, StageIds, RestartFrom);
        StageRow.SetRange("Service Name", ServiceName);
        StageRow.SetRange("Line Type", StageRow."Line Type"::Stage);
        if StageRow.Count() <> StageIds.Count() then
            exit(StrSubstNo(this.StageCountLbl, StageIds.Count(), StageRow.Count()));
        if StageRow.FindSet() then
            repeat
                Index += 1;
                if UpperCase(StageRow.Stage) <> UpperCase(StageIds.Get(Index)) then
                    exit(StrSubstNo(this.StageOrderLbl, Index, StageIds.Get(Index), StageRow.Stage));
                if StageRow."Staging Restart From" <> RestartFrom.Get(Index) then
                    exit(StrSubstNo(this.RestartLbl, StageRow.Stage));
            until StageRow.Next() = 0;
        exit('');
    end;

    local procedure CollectDeclaredStages(var TempLine: Record "BJF MN Config Line" temporary; var StageIds: List of [Text]; var RestartFrom: List of [Boolean])
    begin
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Stage);
        if TempLine.FindSet() then
            repeat
                StageIds.Add(TempLine."Stage Id");
                RestartFrom.Add(TempLine."Stage Restart From");
            until TempLine.Next() = 0;
    end;

    /// <summary>Each Show/ShowReadOnly must appear as the matching token in the field's stage mask.</summary>
    local procedure MaskProblem(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; StageIds: List of [Text]): Text
    var
        FieldRow: Record "MobileNAV Service Setup";
        Tokens: List of [Text];
        Mask: Text;
        Expected: Text;
        StageIndex: Integer;
    begin
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Stage Field");
        if TempLine.FindSet() then
            repeat
                if not this.Lookup.FindFieldRow(ServiceName, TempLine."Control Name", FieldRow) then
                    exit(StrSubstNo(this.FieldMissingLbl, TempLine."Control Name"));
                StageIndex := StageIds.IndexOf(TempLine."Stage Id");
                Mask := FieldRow.Stage;
                Tokens := Mask.Split(',');
                if TempLine."Stage Enabled" then
                    Expected := ''
                else
                    Expected := this.ReadOnlyTok;
                if (Tokens.Count() < StageIndex) or (Tokens.Get(StageIndex) <> Expected) then
                    exit(StrSubstNo(this.MaskLbl, TempLine."Control Name", TempLine."Stage Id"));
            until TempLine.Next() = 0;
        exit('');
    end;

    local procedure Report(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; PageId: Integer; ServiceName: Text[100]; MainRow: Record "MobileNAV Service Setup"; Problem: Text)
    var
        Args: List of [Text];
    begin
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(PageId, 0, 9));
        Finding.AddWithFix(Finding."Check Type"::"Config Staging", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.WizardMsg, ServiceName, Problem)),
            MainRow.RecordId(), StrSubstNo(this.FixMsg, ServiceName),
            this.Support.PackFix(this.StagingFixTok, Args));
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        WizardMsg: Label 'The wizard declared on %1 does not match MobileNAV: %2', Comment = '%1 = service name, %2 = what differs';
        FixMsg: Label 'Rewrite the wizard stages and stage masks of %1.', Comment = '%1 = service name';
        NotEnabledLbl: Label 'staging is not enabled on the page.';
        SwitchLbl: Label '%1 is not %2.', Comment = '%1 = field caption, %2 = declared value';
        StageCountLbl: Label '%1 stages are declared but the page has %2.', Comment = '%1 = declared count, %2 = live count';
        StageOrderLbl: Label 'stage %1 should be %2 but is %3.', Comment = '%1 = position, %2 = declared stage id, %3 = live stage id';
        RestartLbl: Label 'the restart-from flag on stage %1 is wrong.', Comment = '%1 = stage id';
        FieldMissingLbl: Label 'control %1 has no field row.', Comment = '%1 = control name';
        MaskLbl: Label 'control %1 is not shown as declared in stage %2.', Comment = '%1 = control name, %2 = stage id';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        StagingFixTok: Label 'STAGING', Locked = true;
        ReadOnlyTok: Label 'R', Locked = true;
}

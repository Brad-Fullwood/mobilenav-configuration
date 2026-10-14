namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every link and lookup exist on the live page as declared? The relation row and the
/// rows under it (filters, conditions, additional code fields, propagated fields, parent
/// actions) are compared with what "BJF MN Relation Mgt." would write; the fix rewrites them.
/// </summary>
codeunit 77700 "BJF Check Config Relations" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
        TempControlLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                TempControlLine.Copy(TempLine, true);
                TempControlLine.Reset();
                TempControlLine.SetRelationFilter();
                if TempControlLine.FindSet() then
                    repeat
                        this.CheckControl(Finding, TempProvider, TempControlLine, TempLine);
                    until TempControlLine.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempControlLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        PageId: Integer;
        ServiceName: Text[100];
        TargetServiceName: Text[100];
    begin
        this.Support.ReadProviderFix(Finding, this.RelationFixTok, Kind, Args, TempLine);
        Evaluate(PageId, Args.Get(1));
        TempControlLine.Copy(TempLine, true);
        TempControlLine.Reset();
        TempControlLine.SetRange("Page ID", PageId);
        TempControlLine.SetRange("Control Name", CopyStr(Args.Get(2), 1, 100));
        TempControlLine.SetRelationFilter();
        if not TempControlLine.FindFirst() then
            Error(this.LineGoneErr);
        ServiceName := this.Lookup.GetServiceName(PageId);
        TargetServiceName := this.Lookup.GetServiceName(TempControlLine."Target Page ID");
        if (ServiceName = '') or (TargetServiceName = '') then
            Error(this.PageGoneErr, PageId);
        if TempControlLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
            this.RelationManagement.ConfigureLink(ServiceName, TargetServiceName, TempControlLine, TempLine)
        else
            this.RelationManagement.ConfigureLookup(ServiceName, TargetServiceName, TempControlLine, TempLine);
    end;

    local procedure CheckControl(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        FieldRow: Record "MobileNAV Service Setup";
        RelationRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        TargetServiceName: Text[100];
        Problem: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(ControlLine."Page ID");
        TargetServiceName := this.Support.GetServiceName(ControlLine."Target Page ID");
        if (ServiceName = '') or (TargetServiceName = '') then
            exit; // Reported by the services check.
        if not this.Lookup.FindFieldRow(ServiceName, ControlLine."Control Name", FieldRow) then
            exit; // Reported by the field check.

        Problem := this.RelationProblem(FieldRow, TargetServiceName, ControlLine, RelationRow);
        if Problem = '' then
            Problem := this.DetailProblem(FieldRow, RelationRow, ControlLine, TempLine);
        if Problem = '' then
            exit;
        Args.Add(Format(ControlLine."Page ID", 0, 9));
        Args.Add(ControlLine."Control Name");
        this.Support.AddProviderFinding(Finding, Finding."Check Type"::"Config Relations", Finding.Severity::Blocker, TempProvider,
            StrSubstNo(this.RelationMsg, ControlLine."Control Name", ServiceName, Problem),
            FieldRow.RecordId(), StrSubstNo(this.FixMsg, ControlLine."Control Name", ServiceName),
            this.RelationFixTok, Args);
    end;

    local procedure RelationProblem(FieldRow: Record "MobileNAV Service Setup"; TargetServiceName: Text[100]; ControlLine: Record "BJF MN Config Line" temporary; var RelationRow: Record "MobileNAV Service Setup"): Text
    var
        IsLookup: Boolean;
    begin
        IsLookup := ControlLine.Operation = Enum::"BJF MN Config Operation"::"Lookup Field";
        if this.PlacementProblem(FieldRow, IsLookup) <> '' then
            exit(this.PlacementProblem(FieldRow, IsLookup));
        if not this.RelationManagement.FindRelation(FieldRow, RelationRow) then
            exit(this.NoRelationLbl);
        if RelationRow.RelatedPageName <> TargetServiceName then
            exit(StrSubstNo(this.TargetLbl, TargetServiceName, RelationRow.RelatedPageName));
        if IsLookup then
            exit(this.BindingProblem(RelationRow, ControlLine));
        if RelationRow.RelatedPgCodeFldName <> '' then
            exit(this.LookupBindingLbl);
        exit(this.SwitchProblem(RelationRow, ControlLine));
    end;

    local procedure PlacementProblem(FieldRow: Record "MobileNAV Service Setup"; IsLookup: Boolean): Text
    begin
        if FieldRow.DisplayInMenu = IsLookup then
            exit(this.MenuPlacementLbl);
        if IsLookup and not FieldRow.Editable then
            exit(this.NotEditableLbl);
        exit('');
    end;

    local procedure BindingProblem(RelationRow: Record "MobileNAV Service Setup"; ControlLine: Record "BJF MN Config Line" temporary): Text
    begin
        if RelationRow.RelatedPgCodeFldName <> this.Lookup.StoredFieldName(ControlLine."Related Code Field") then
            exit(this.CodeFieldLbl);
        if RelationRow.RelatedPgDescFldName <> this.Lookup.StoredFieldName(ControlLine."Related Description Field") then
            exit(this.DescriptionFieldLbl);
        exit(this.SwitchProblem(RelationRow, ControlLine));
    end;

    local procedure SwitchProblem(RelationRow: Record "MobileNAV Service Setup"; ControlLine: Record "BJF MN Config Line" temporary): Text
    begin
        if RelationRow.MultiSelect <> ControlLine."Multi Select" then
            exit(this.MultiSelectLbl);
        if RelationRow.AutoRefreshOnOpen <> ControlLine."Auto Refresh On Open" then
            exit(this.RefreshOnOpenLbl);
        exit('');
    end;

    /// <summary>Compares the relation's detail rows with the rows the writer builds for the declared link or lookup.</summary>
    /// <param name="FieldRow">The live field row the relation hangs from.</param>
    /// <param name="RelationRow">The live relation row the writer copies into the detail rows.</param>
    /// <param name="ControlLine">The declared link or lookup.</param>
    /// <param name="TempLine">The provider's definition. Filters are reset on exit.</param>
    /// <returns>A description of the first difference, or empty when the details match.</returns>
    local procedure DetailProblem(FieldRow: Record "MobileNAV Service Setup"; RelationRow: Record "MobileNAV Service Setup"; ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Text
    var
        TempDetailRow: Record "MobileNAV Service Setup" temporary;
        Problem: Text;
    begin
        if not this.TryBuildDetails(ControlLine, TempLine, FieldRow, RelationRow, TempDetailRow) then
            exit(GetLastErrorText());
        Problem := this.CompareRows(FieldRow, TempDetailRow, FieldRow."Line Type"::Filter, this.FiltersLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, TempDetailRow, FieldRow."Line Type"::Condition, this.ConditionsLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, TempDetailRow, FieldRow."Line Type"::AdditionalCodeField, this.AdditionalCodesLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, TempDetailRow, FieldRow."Line Type"::PropagatedField, this.PropagatedLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, TempDetailRow, FieldRow."Line Type"::ParentAction, this.ParentActionsLbl);
        exit(Problem);
    end;

    // Writes the declared rows into TempDetailRow. A writer error, such as a missing button, comes back in GetLastErrorText.
    [TryFunction]
    local procedure TryBuildDetails(ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; FieldRow: Record "MobileNAV Service Setup"; RelationRow: Record "MobileNAV Service Setup"; var TempDetailRow: Record "MobileNAV Service Setup" temporary)
    begin
        this.RelationManagement.BuildDetails(FieldRow, RelationRow, ControlLine, TempLine, TempDetailRow);
    end;

    local procedure RowSignature(DetailRow: Record "MobileNAV Service Setup"): Text
    begin
        case DetailRow."Line Type" of
            DetailRow."Line Type"::Filter:
                if DetailRow.FilterType = DetailRow.FilterType::FIELD then
                    exit(this.Support.Signature(this.FieldTypeTok, DetailRow.DestFieldName, DetailRow.SourceFieldName))
                else
                    exit(this.Support.Signature(UpperCase(this.Lookup.OptionName(DetailRow, DetailRow.FieldNo(FilterType))), DetailRow.DestFieldName, DetailRow.FilterValue));
            DetailRow."Line Type"::Condition:
                exit(this.Support.Signature(DetailRow.SourceFieldName, DetailRow.FilterValue, ''));
            DetailRow."Line Type"::AdditionalCodeField:
                exit(this.Support.Signature(DetailRow.SourceFieldName, DetailRow.DestFieldName, ''));
            DetailRow."Line Type"::PropagatedField:
                exit(this.Support.Signature(UpperCase(this.Lookup.OptionName(DetailRow, DetailRow.FieldNo("Propagation Type"))), DetailRow.DestFieldName, ''));
            DetailRow."Line Type"::ParentAction:
                exit(this.Support.Signature(DetailRow.Name, '', ''));
        end;
        exit('');
    end;

#pragma warning disable LC0088 // Mirrors the Line Type option of MobileNAV Service Setup.
    /// <summary>Compares one kind of detail row: the written rows against the live rows, both in primary key order.</summary>
    /// <param name="FieldRow">The live field row the relation hangs from.</param>
    /// <param name="TempDetailRow">The temporary copy of the written rows.</param>
    /// <param name="LineType">The MobileNAV Service Setup Line Type to compare.</param>
    /// <param name="KindName">The name of the kind, for the finding text.</param>
    /// <returns>A description of the first difference, or empty when the kind matches.</returns>
    local procedure CompareRows(FieldRow: Record "MobileNAV Service Setup"; var TempDetailRow: Record "MobileNAV Service Setup" temporary; LineType: Option; KindName: Text): Text
    var
        DetailRow: Record "MobileNAV Service Setup";
    begin
        this.RelationManagement.SetDetailFilter(FieldRow, LineType, DetailRow);
        this.RelationManagement.SetDetailFilter(FieldRow, LineType, TempDetailRow);
        exit(this.Support.FirstDifference(KindName, this.Signatures(TempDetailRow), this.Signatures(DetailRow)));
    end;

    local procedure Signatures(var Rows: Record "MobileNAV Service Setup") Signature: List of [Text]
    begin
        if Rows.FindSet() then
            repeat
                Signature.Add(this.RowSignature(Rows));
            until Rows.Next() = 0;
        exit(Signature);
    end;
#pragma warning restore LC0088

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        RelationManagement: Codeunit "BJF MN Relation Mgt.";
        RelationMsg: Label 'Link or lookup %1 on %2 does not match MobileNAV: %3', Comment = '%1 = control name, %2 = service name, %3 = what differs';
        FixMsg: Label 'Rewrite the relation of %1 on %2 with its filters, conditions and other details.', Comment = '%1 = control name, %2 = service name';
        MenuPlacementLbl: Label 'a link must be a menu entry and a lookup a card field.';
        NotEditableLbl: Label 'the lookup field is not editable.';
        NoRelationLbl: Label 'the relation row is missing.';
        TargetLbl: Label 'it should open %1 but opens %2.', Comment = '%1 = declared target service, %2 = live target service';
        CodeFieldLbl: Label 'the lookup picks a different code field.';
        DescriptionFieldLbl: Label 'the lookup shows a different description field.';
        LookupBindingLbl: Label 'the link carries a lookup binding, so it is drawn as a lookup rather than a button.';
        MultiSelectLbl: Label 'multi-select is not as declared.';
        RefreshOnOpenLbl: Label 'refresh-on-open is not as declared.';
        FiltersLbl: Label 'filters';
        ConditionsLbl: Label 'conditions';
        AdditionalCodesLbl: Label 'additional code fields';
        PropagatedLbl: Label 'propagated fields';
        ParentActionsLbl: Label 'parent actions';
        LineGoneErr: Label 'The provider no longer declares this link or lookup.';
        PageGoneErr: Label 'Page %1 or its target is no longer registered in MobileNAV.', Comment = '%1 = page id';
        RelationFixTok: Label 'RELATION', Locked = true;
        FieldTypeTok: Label 'FIELD', Locked = true;
}

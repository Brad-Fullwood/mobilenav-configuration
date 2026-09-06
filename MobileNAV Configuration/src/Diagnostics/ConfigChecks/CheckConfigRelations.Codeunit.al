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
                TempControlLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Lookup Field");
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
        Ordinal: Integer;
        PageId: Integer;
        ServiceName: Text[100];
        TargetServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.RelationFixTok then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(PageId, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        TempControlLine.Copy(TempLine, true);
        TempControlLine.Reset();
        TempControlLine.SetRange("Page ID", PageId);
        TempControlLine.SetRange("Control Name", CopyStr(Args.Get(3), 1, 100));
        TempControlLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Lookup Field");
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
        ServiceName: Text[100];
        TargetServiceName: Text[100];
        Problem: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Lookup.GetServiceName(ControlLine."Page ID");
        TargetServiceName := this.Lookup.GetServiceName(ControlLine."Target Page ID");
        if (ServiceName = '') or (TargetServiceName = '') then
            exit; // Reported by the services check.
        if not this.Lookup.FindFieldRow(ServiceName, ControlLine."Control Name", FieldRow) then
            exit; // Reported by the field check.

        Problem := this.RelationProblem(FieldRow, TargetServiceName, ControlLine);
        if Problem = '' then
            Problem := this.DetailProblem(FieldRow, ControlLine, TempLine);
        if Problem = '' then
            exit;
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(ControlLine."Page ID", 0, 9));
        Args.Add(ControlLine."Control Name");
        Finding.AddWithFix(Finding."Check Type"::"Config Relations", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.RelationMsg, ControlLine."Control Name", ServiceName, Problem)),
            FieldRow.RecordId(), StrSubstNo(this.FixMsg, ControlLine."Control Name", ServiceName),
            this.Support.PackFix(this.RelationFixTok, Args));
    end;

    local procedure RelationProblem(FieldRow: Record "MobileNAV Service Setup"; TargetServiceName: Text[100]; ControlLine: Record "BJF MN Config Line" temporary): Text
    var
        RelationRow: Record "MobileNAV Service Setup";
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

    /// <summary>Compares each kind of detail row with the declared lines of that kind, in order.</summary>
    local procedure DetailProblem(FieldRow: Record "MobileNAV Service Setup"; ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Text
    var
        Expected: List of [Text];
        Problem: Text;
    begin
        this.ExpectedFilters(ControlLine, TempLine, Expected);
        Problem := this.CompareRows(FieldRow, FieldRow."Line Type"::Filter, Expected, this.FiltersLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, FieldRow."Line Type"::Condition, this.ExpectedDetails(ControlLine, TempLine, Enum::"BJF MN Config Operation"::"Relation Condition"), this.ConditionsLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, FieldRow."Line Type"::AdditionalCodeField, this.ExpectedDetails(ControlLine, TempLine, Enum::"BJF MN Config Operation"::"Additional Code Field"), this.AdditionalCodesLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, FieldRow."Line Type"::PropagatedField, this.ExpectedDetails(ControlLine, TempLine, Enum::"BJF MN Config Operation"::"Propagated Field"), this.PropagatedLbl);
        if Problem = '' then
            Problem := this.CompareRows(FieldRow, FieldRow."Line Type"::ParentAction, this.ExpectedDetails(ControlLine, TempLine, Enum::"BJF MN Config Operation"::"Parent Action"), this.ParentActionsLbl);
        exit(Problem);
    end;

    local procedure ExpectedFilters(ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var Expected: List of [Text])
    begin
        if ControlLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
            Expected.Add(this.FilterSignature(this.FieldTypeTok, ControlLine."Target Filter Field", ControlLine."Source Field", ''));
        Expected.AddRange(this.ExpectedDetails(ControlLine, TempLine, Enum::"BJF MN Config Operation"::"Relation Filter"));
    end;

    local procedure ExpectedDetails(ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; DetailOperation: Enum "BJF MN Config Operation") Expected: List of [Text]
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", ControlLine."Page ID");
        TempLine.SetRange("Control Name", ControlLine."Control Name");
        TempLine.SetRange(Operation, DetailOperation);
        if TempLine.FindSet() then
            repeat
                Expected.Add(this.LineSignature(TempLine, ControlLine."Page ID"));
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure LineSignature(DetailLine: Record "BJF MN Config Line" temporary; PageId: Integer): Text
    var
        ButtonRow: Record "MobileNAV Service Setup";
    begin
        case DetailLine.Operation of
            Enum::"BJF MN Config Operation"::"Relation Filter":
                exit(this.FilterSignature(DetailLine."Filter Type", DetailLine."Target Filter Field", DetailLine."Source Field", DetailLine."Filter Value"));
            Enum::"BJF MN Config Operation"::"Relation Condition":
                exit(this.Join(this.Lookup.StoredFieldName(DetailLine."Source Field"), DetailLine."Filter Value", ''));
            Enum::"BJF MN Config Operation"::"Additional Code Field":
                exit(this.Join(this.Lookup.StoredFieldName(DetailLine."Source Field"), this.Lookup.StoredFieldName(DetailLine."Target Filter Field"), ''));
            Enum::"BJF MN Config Operation"::"Propagated Field":
                exit(this.Join(UpperCase(DetailLine."Propagation Type"), this.Lookup.StoredFieldName(DetailLine."Target Filter Field"), ''));
            Enum::"BJF MN Config Operation"::"Parent Action":
                if this.Lookup.FindFieldRow(this.Lookup.GetServiceName(PageId), DetailLine."Source Field", ButtonRow) then
                    exit(this.Join(ButtonRow.FieldName, '', ''));
        end;
        exit('');
    end;

    local procedure FilterSignature(FilterType: Text; TargetField: Text[100]; SourceField: Text[100]; Value: Text): Text
    begin
        if UpperCase(FilterType) = this.FieldTypeTok then
            exit(this.Join(this.FieldTypeTok, this.Lookup.StoredFieldName(TargetField), this.Lookup.StoredFieldName(SourceField)));
        exit(this.Join(UpperCase(FilterType), this.Lookup.StoredFieldName(TargetField), Value));
    end;

    local procedure RowSignature(DetailRow: Record "MobileNAV Service Setup"): Text
    begin
        case DetailRow."Line Type" of
            DetailRow."Line Type"::Filter:
                if DetailRow.FilterType = DetailRow.FilterType::FIELD then
                    exit(this.Join(this.FieldTypeTok, DetailRow.DestFieldName, DetailRow.SourceFieldName))
                else
                    exit(this.Join(UpperCase(this.Lookup.OptionName(DetailRow, DetailRow.FieldNo(FilterType))), DetailRow.DestFieldName, DetailRow.FilterValue));
            DetailRow."Line Type"::Condition:
                exit(this.Join(DetailRow.SourceFieldName, DetailRow.FilterValue, ''));
            DetailRow."Line Type"::AdditionalCodeField:
                exit(this.Join(DetailRow.SourceFieldName, DetailRow.DestFieldName, ''));
            DetailRow."Line Type"::PropagatedField:
                exit(this.Join(UpperCase(this.Lookup.OptionName(DetailRow, DetailRow.FieldNo("Propagation Type"))), DetailRow.DestFieldName, ''));
            DetailRow."Line Type"::ParentAction:
                exit(this.Join(DetailRow.Name, '', ''));
        end;
        exit('');
    end;

    local procedure CompareRows(FieldRow: Record "MobileNAV Service Setup"; LineType: Option; Expected: List of [Text]; KindName: Text): Text
    var
        DetailRow: Record "MobileNAV Service Setup";
        Index: Integer;
    begin
        this.RelationManagement.SetDetailFilter(FieldRow, LineType, DetailRow);
        if DetailRow.Count() <> Expected.Count() then
            exit(StrSubstNo(this.CountLbl, KindName, Expected.Count(), DetailRow.Count()));
        if DetailRow.FindSet() then
            repeat
                Index += 1;
                if this.RowSignature(DetailRow) <> Expected.Get(Index) then
                    exit(StrSubstNo(this.RowLbl, KindName, Index));
            until DetailRow.Next() = 0;
        exit('');
    end;

    local procedure Join(First: Text; Second: Text; Third: Text): Text
    begin
        exit(First + this.SeparatorTok + Second + this.SeparatorTok + Third);
    end;

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
        CountLbl: Label '%1: %2 declared, %3 found.', Comment = '%1 = row kind, %2 = declared count, %3 = live count';
        RowLbl: Label '%1: row %2 differs.', Comment = '%1 = row kind, %2 = row position';
        FiltersLbl: Label 'filters';
        ConditionsLbl: Label 'conditions';
        AdditionalCodesLbl: Label 'additional code fields';
        PropagatedLbl: Label 'propagated fields';
        ParentActionsLbl: Label 'parent actions';
        LineGoneErr: Label 'The provider no longer declares this link or lookup.';
        PageGoneErr: Label 'Page %1 or its target is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        RelationFixTok: Label 'RELATION', Locked = true;
        FieldTypeTok: Label 'FIELD', Locked = true;
        SeparatorTok: Label '|', Locked = true;
}

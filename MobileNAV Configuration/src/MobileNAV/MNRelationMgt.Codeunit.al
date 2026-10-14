namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes a control's relation to another page (a link that opens it, or a lookup that picks
/// from it) and the rows hanging off the relation: filters, conditions, additional code
/// fields, propagated fields and parent actions. Detail rows are rebuilt from scratch on
/// every apply, numbered the way MobileNAV's own import numbers them.
///
/// The relation family is written as MobileNAV's import writes it: assigned directly and
/// inserted without triggers. RelatedPageName's trigger would delete the detail rows it is
/// about to get, and RelatedPgCodeFldName's would unset MultiSelect; the rows arrive whole.
/// </summary>
codeunit 77766 "BJF MN Relation Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rimd;

    /// <summary>
    /// A link: a menu entry that opens the target page filtered to the current record.
    /// RelatedPgCodeFldName stays empty on purpose: set, it turns the relation into a lookup
    /// binding, and an empty read-only lookup is not drawn at all.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="TargetServiceName">The service name of the page the control relates to.</param>
    /// <param name="ControlLine">The control line from the definition.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureLink(ServiceName: Text[100]; TargetServiceName: Text[100]; var ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Boolean
    var
        FieldSetup: Record "MobileNAV Service Setup";
        RelationSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlLine."Control Name", FieldSetup) then
            exit(false);
        FieldSetup.Validate(Visible, true);
#pragma warning disable PC0037
        FieldSetup.DisplayInMenu := true;
#pragma warning restore PC0037
        this.Lookup.SetOptionField(FieldSetup, FieldSetup.FieldNo(Mandatory), ControlLine.Importance);
        FieldSetup.Modify(true);

        this.UpsertRelation(FieldSetup, TargetServiceName, ControlLine, '', '', RelationSetup);
        this.RebuildDetails(FieldSetup, RelationSetup, ControlLine, TempLine);
        exit(true);
    end;

    /// <summary>A lookup: an editable field filled by picking a record from the target page.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="TargetServiceName">The service name of the page the control relates to.</param>
    /// <param name="ControlLine">The control line from the definition.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureLookup(ServiceName: Text[100]; TargetServiceName: Text[100]; var ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary): Boolean
    var
        FieldSetup: Record "MobileNAV Service Setup";
        RelationSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlLine."Control Name", FieldSetup) then
            exit(false);
        FieldSetup.Validate(Visible, true);
#pragma warning disable PC0037
        FieldSetup.Editable := true;
        FieldSetup.DisplayInMenu := false;
#pragma warning restore PC0037
        this.Lookup.SetOptionField(FieldSetup, FieldSetup.FieldNo(Mandatory), ControlLine.Importance);
        FieldSetup.Modify(true);
        this.FieldManagement.EnsurePageUpdatable(ServiceName);

        this.UpsertRelation(
            FieldSetup, TargetServiceName, ControlLine,
            this.Lookup.StoredFieldName(ControlLine."Related Code Field"),
            this.Lookup.StoredFieldName(ControlLine."Related Description Field"), RelationSetup);
        this.RebuildDetails(FieldSetup, RelationSetup, ControlLine, TempLine);
        exit(true);
    end;

    /// <summary>Forgets the pages the lookups confirmed updatable. See "BJF MN Field Mgt.".ForgetUpdatablePages.</summary>
    procedure ForgetUpdatablePages()
    begin
        this.FieldManagement.ForgetUpdatablePages();
    end;

    /// <summary>Finds the control's relation row (a control has one, Relation No. 1).</summary>
    /// <param name="FieldSetup">The control row the relation belongs to.</param>
    /// <param name="RelationSetup">The relation row.</param>
    /// <returns>True when the relation row was found.</returns>
    procedure FindRelation(FieldSetup: Record "MobileNAV Service Setup"; var RelationSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        exit(this.FindChildRow(FieldSetup, RelationSetup."Line Type"::Relation, 1, 0, RelationSetup));
    end;

#pragma warning disable LC0088 // Mirrors the Line Type option of MobileNAV Service Setup.
    /// <summary>The relation's detail rows of one kind, in Line No. order.</summary>
    /// <param name="FieldSetup">The control row the relation belongs to.</param>
    /// <param name="LineType">The MobileNAV Service Setup Line Type.</param>
    /// <param name="DetailRow">The detail row to filter.</param>
    procedure SetDetailFilter(FieldSetup: Record "MobileNAV Service Setup"; LineType: Option; var DetailRow: Record "MobileNAV Service Setup")
    begin
        DetailRow.Reset();
        DetailRow.SetRange("Object Type", FieldSetup."Object Type");
        DetailRow.SetRange("Service Name", FieldSetup."Service Name");
        DetailRow.SetRange("Line Type", LineType);
        DetailRow.SetRange("Page Line No.", FieldSetup."Page Line No.");
        DetailRow.SetRange("Relation No.", 1);
    end;
#pragma warning restore LC0088

    local procedure UpsertRelation(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[100]; ControlLine: Record "BJF MN Config Line" temporary; CodeField: Text[75]; DescriptionField: Text[75]; var RelationSetup: Record "MobileNAV Service Setup")
    var
        RelatedTableNo: Integer;
        IsNew: Boolean;
    begin
        if not this.Lookup.GetServiceTableNo(TargetServiceName, RelatedTableNo) then
            Error(this.TargetServiceMissingErr, TargetServiceName);
        IsNew := not this.FindRelation(FieldSetup, RelationSetup);
        if IsNew then
            this.InitChildRow(RelationSetup, FieldSetup, RelationSetup."Line Type"::Relation, 1, 0);
#pragma warning disable PC0037
        RelationSetup."Object ID" := FieldSetup."Object ID";
        RelationSetup.ControlID := FieldSetup.ControlID;
        RelationSetup.FieldName := FieldSetup.FieldName;
        RelationSetup.RelatedPageName := CopyStr(TargetServiceName, 1, MaxStrLen(RelationSetup.RelatedPageName));
        RelationSetup."Related Table No." := RelatedTableNo;
        RelationSetup.RelatedPgCodeFldName := CodeField;
        RelationSetup.RelatedPgDescFldName := DescriptionField;
        RelationSetup.MultiSelect := ControlLine."Multi Select";
        RelationSetup.AutoRefreshOnOpen := ControlLine."Auto Refresh On Open";
#pragma warning restore PC0037
        if IsNew then
            RelationSetup.Insert(false)
        else
            RelationSetup.Modify(false);
    end;

    /// <summary>Deletes the relation's detail rows and writes the declared ones: a link's own filter first, then the details in declaration order.</summary>
    /// <param name="FieldSetup">The control row the relation belongs to.</param>
    /// <param name="RelationSetup">The relation row.</param>
    /// <param name="ControlLine">The control line from the definition.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    local procedure RebuildDetails(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; var ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        DetailRow: Record "MobileNAV Service Setup";
        BuiltRow: Record "MobileNAV Service Setup";
    begin
        DetailRow.SetRange("Service Name", FieldSetup."Service Name");
        DetailRow.SetFilter("Line Type", '%1|%2|%3|%4|%5',
            DetailRow."Line Type"::Filter, DetailRow."Line Type"::Condition, DetailRow."Line Type"::AdditionalCodeField,
            DetailRow."Line Type"::PropagatedField, DetailRow."Line Type"::ParentAction);
        DetailRow.SetRange("Page Line No.", FieldSetup."Page Line No.");
        DetailRow.SetRange("Relation No.", 1);
        DetailRow.DeleteAll(false);

        this.BuildDetails(FieldSetup, RelationSetup, ControlLine, TempLine, BuiltRow);
    end;

    /// <summary>Writes the relation's detail rows into DetailRow: the real table on apply, a temporary copy when the Doctor compares.</summary>
    /// <param name="FieldSetup">The control row the relation belongs to.</param>
    /// <param name="RelationSetup">The relation row.</param>
    /// <param name="ControlLine">The control line from the definition.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="DetailRow">The table the rows are inserted into.</param>
    procedure BuildDetails(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; var ControlLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary; var DetailRow: Record "MobileNAV Service Setup")
    var
        LineNos: Dictionary of [Integer, Integer];
    begin
        if ControlLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
            this.InsertFilter(FieldSetup, RelationSetup, this.FieldTypeTok, ControlLine."Target Filter Field", ControlLine."Source Field", '', this.NextLineNo(LineNos, DetailRow."Line Type"::Filter), DetailRow);

        TempLine.Reset();
        TempLine.SetRange("Page ID", ControlLine."Page ID");
        TempLine.SetRange("Control Name", ControlLine."Control Name");
        TempLine.SetFilter(Operation, '%1|%2|%3|%4|%5',
            Enum::"BJF MN Config Operation"::"Relation Filter", Enum::"BJF MN Config Operation"::"Relation Condition",
            Enum::"BJF MN Config Operation"::"Additional Code Field", Enum::"BJF MN Config Operation"::"Propagated Field",
            Enum::"BJF MN Config Operation"::"Parent Action");
        if TempLine.FindSet() then
            repeat
                this.InsertDetail(FieldSetup, RelationSetup, TempLine, LineNos, DetailRow);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure InsertDetail(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; DetailLine: Record "BJF MN Config Line" temporary; var LineNos: Dictionary of [Integer, Integer]; var DetailRow: Record "MobileNAV Service Setup")
    begin
        case DetailLine.Operation of
            Enum::"BJF MN Config Operation"::"Relation Filter":
                this.InsertFilter(FieldSetup, RelationSetup, DetailLine."Filter Type", DetailLine."Target Filter Field", DetailLine."Source Field", DetailLine."Filter Value", this.NextLineNo(LineNos, DetailRow."Line Type"::Filter), DetailRow);
            Enum::"BJF MN Config Operation"::"Relation Condition":
                this.InsertCondition(FieldSetup, DetailLine, this.NextLineNo(LineNos, DetailRow."Line Type"::Condition), DetailRow);
            Enum::"BJF MN Config Operation"::"Additional Code Field":
                this.InsertAdditionalCode(FieldSetup, RelationSetup, DetailLine, this.NextLineNo(LineNos, DetailRow."Line Type"::AdditionalCodeField), DetailRow);
            Enum::"BJF MN Config Operation"::"Propagated Field":
                this.InsertPropagated(FieldSetup, RelationSetup, DetailLine, this.NextLineNo(LineNos, DetailRow."Line Type"::PropagatedField), DetailRow);
            Enum::"BJF MN Config Operation"::"Parent Action":
                this.InsertParentAction(FieldSetup, RelationSetup, DetailLine, DetailRow);
        end;
    end;

    local procedure InsertFilter(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; FilterType: Text; TargetField: Text[100]; SourceField: Text[100]; Value: Text[250]; LineNo: Integer; var FilterRow: Record "MobileNAV Service Setup")
    begin
        this.InitChildRow(FilterRow, FieldSetup, FilterRow."Line Type"::Filter, 1, LineNo);
#pragma warning disable PC0037
        FilterRow.RelatedPageName := RelationSetup.RelatedPageName;
        FilterRow."Related Table No." := RelationSetup."Related Table No.";
        FilterRow.DestFieldName := this.Lookup.StoredFieldName(TargetField);
        FilterRow."Filter Comparsion Type" := FilterRow."Filter Comparsion Type"::Equal;
        if FilterType = this.FieldTypeTok then
            FilterRow.SourceFieldName := this.Lookup.StoredFieldName(SourceField)
        else
            FilterRow.FilterValue := Value;
#pragma warning restore PC0037
        this.Lookup.SetOptionField(FilterRow, FilterRow.FieldNo(FilterType), FilterType);
        FilterRow.Insert(false);
    end;

    local procedure InsertCondition(FieldSetup: Record "MobileNAV Service Setup"; DetailLine: Record "BJF MN Config Line" temporary; LineNo: Integer; var ConditionRow: Record "MobileNAV Service Setup")
    begin
        this.InitChildRow(ConditionRow, FieldSetup, ConditionRow."Line Type"::Condition, 1, LineNo);
#pragma warning disable PC0037
        ConditionRow.FilterType := ConditionRow.FilterType::CONST;
        ConditionRow."Filter Comparsion Type" := ConditionRow."Filter Comparsion Type"::Equal;
        ConditionRow.SourceFieldName := this.Lookup.StoredFieldName(DetailLine."Source Field");
        ConditionRow.FilterValue := DetailLine."Filter Value";
#pragma warning restore PC0037
        ConditionRow.Insert(false);
    end;

    local procedure InsertAdditionalCode(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; DetailLine: Record "BJF MN Config Line" temporary; LineNo: Integer; var CodeRow: Record "MobileNAV Service Setup")
    begin
        this.InitChildRow(CodeRow, FieldSetup, CodeRow."Line Type"::AdditionalCodeField, 1, LineNo);
#pragma warning disable PC0037
        CodeRow.RelatedPageName := RelationSetup.RelatedPageName;
        CodeRow."Related Table No." := RelationSetup."Related Table No.";
        CodeRow.SourceFieldName := this.Lookup.StoredFieldName(DetailLine."Source Field");
        CodeRow.DestFieldName := this.Lookup.StoredFieldName(DetailLine."Target Filter Field");
#pragma warning restore PC0037
        CodeRow.Insert(false);
    end;

    local procedure InsertPropagated(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; DetailLine: Record "BJF MN Config Line" temporary; LineNo: Integer; var PropagatedRow: Record "MobileNAV Service Setup")
    begin
        this.InitChildRow(PropagatedRow, FieldSetup, PropagatedRow."Line Type"::PropagatedField, 1, LineNo);
#pragma warning disable PC0037
        PropagatedRow.RelatedPageName := RelationSetup.RelatedPageName;
        PropagatedRow."Related Table No." := RelationSetup."Related Table No.";
        PropagatedRow.DestFieldName := this.Lookup.StoredFieldName(DetailLine."Target Filter Field");
#pragma warning restore PC0037
        this.Lookup.SetOptionField(PropagatedRow, PropagatedRow.FieldNo("Propagation Type"), DetailLine."Propagation Type");
        PropagatedRow.Insert(false);
    end;

    /// <summary>Line No. is the button's own Page Line No., as MobileNAV's import keys parent actions.</summary>
    /// <param name="FieldSetup">The control row the relation belongs to.</param>
    /// <param name="RelationSetup">The relation row.</param>
    /// <param name="DetailLine">The detail line from the definition.</param>
    /// <param name="ActionRow">The row the parent action is inserted into.</param>
    local procedure InsertParentAction(FieldSetup: Record "MobileNAV Service Setup"; RelationSetup: Record "MobileNAV Service Setup"; DetailLine: Record "BJF MN Config Line" temporary; var ActionRow: Record "MobileNAV Service Setup")
    var
        ButtonRow: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(FieldSetup."Service Name", DetailLine."Source Field", ButtonRow) then
            Error(this.ButtonMissingErr, DetailLine."Source Field", FieldSetup."Service Name");
        this.InitChildRow(ActionRow, FieldSetup, ActionRow."Line Type"::ParentAction, 1, ButtonRow."Page Line No.");
#pragma warning disable PC0037
        ActionRow."Object Type" := ButtonRow."Object Type";
        ActionRow.Name := ButtonRow.FieldName;
        ActionRow.RelatedPageName := RelationSetup.RelatedPageName;
        ActionRow.Order := ButtonRow.Order;
#pragma warning restore PC0037
        // OnInsert marks the configuration changed, which a temporary copy must not do.
        ActionRow.Insert(not ActionRow.IsTemporary());
    end;

    local procedure NextLineNo(var LineNos: Dictionary of [Integer, Integer]; LineType: Integer): Integer
    var
        LineNo: Integer;
    begin
        if not LineNos.Get(LineType, LineNo) then
            LineNo := 0;
        LineNo += 10000;
        LineNos.Set(LineType, LineNo);
        exit(LineNo);
    end;

#pragma warning disable LC0088 // Mirrors the Line Type option of MobileNAV Service Setup.
    local procedure FindChildRow(FieldSetup: Record "MobileNAV Service Setup"; LineType: Option; RelationNo: Integer; LineNo: Integer; var ChildRow: Record "MobileNAV Service Setup"): Boolean
    begin
        ChildRow.Reset();
        ChildRow.SetRange("Object Type", FieldSetup."Object Type");
        ChildRow.SetRange("Service Name", FieldSetup."Service Name");
        ChildRow.SetRange("Line Type", LineType);
        ChildRow.SetRange("Page Line No.", FieldSetup."Page Line No.");
        ChildRow.SetRange("Relation No.", RelationNo);
        ChildRow.SetRange("Line No.", LineNo);
        exit(ChildRow.FindFirst());
    end;
#pragma warning restore LC0088

#pragma warning disable LC0088 // Mirrors the Line Type option of MobileNAV Service Setup.
    /// <summary>A row under the field's Page Line No., keyed and stamped the way MobileNAV's import stamps it.</summary>
    /// <param name="ChildRow">The child row to initialize.</param>
    /// <param name="FieldSetup">The control row the relation belongs to.</param>
    /// <param name="LineType">The MobileNAV Service Setup Line Type.</param>
    /// <param name="RelationNo">The relation number.</param>
    /// <param name="LineNo">The line number.</param>
    local procedure InitChildRow(var ChildRow: Record "MobileNAV Service Setup"; FieldSetup: Record "MobileNAV Service Setup"; LineType: Option; RelationNo: Integer; LineNo: Integer)
    begin
        ChildRow.Init();
        ChildRow.Validate("Object Type", FieldSetup."Object Type");
        ChildRow.Validate("Service Name", FieldSetup."Service Name");
        ChildRow.Validate("Line Type", LineType);
        ChildRow.Validate("Page Line No.", FieldSetup."Page Line No.");
        ChildRow.Validate("Relation No.", RelationNo);
        ChildRow.Validate("Line No.", LineNo);
#pragma warning disable PC0037
        ChildRow."Object ID" := FieldSetup."Object ID";
#pragma warning restore PC0037
        ChildRow.Validate(ControlID, FieldSetup.ControlID);
        ChildRow.Validate(FieldName, FieldSetup.FieldName);
    end;
#pragma warning restore LC0088

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        FieldTypeTok: Label 'FIELD', Locked = true;
        TargetServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
        ButtonMissingErr: Label 'Parent action %1 was not found on MobileNAV service %2.', Comment = '%1 = button control name, %2 = service name';
}

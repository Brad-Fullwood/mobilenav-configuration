namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Works out the dynamic layout effects of one record for the device emulator. A layout matches when
/// all its conditions hold for the record. The matching layouts set captions, colours, icons, hidden
/// and read-only fields, validated fields and stages. The device's own evaluation is not available to
/// the emulator, so a rule the recon marks as inferred is the emulator's reading, and a comment says so.
/// Nothing is written.
/// </summary>
codeunit 77734 "BJF MN Emulator Layouts"
{
    Access = Internal;

    var
        TempLayout: Record "MobileNAV Dynamic Layout Buff." temporary;
        TempCondition: Record "MobileNAV D. L. Cond. Buff." temporary;
        TempCachedAction: Record "MobileNAV D. L. Action Buff." temporary;
        TempCachedActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary;
        Config: Codeunit "BJF MN Emulator Config";
        Records: Codeunit "BJF MN Emulator Records";
        ScreenRenderer: Codeunit "BJF MN Screen Renderer";
        CacheIsFilled: Boolean;
        CachedServiceName: Text;
        CachedUserId: Code[50];
        CachedLanguage: Code[10];
        CachedProfile: Code[30];
        Settings: Dictionary of [Text, Text];
        MatchedLayouts: List of [Text];
        TouchedFields: List of [Text];
        HiddenStages: List of [Text];
        ValidatedStages: List of [Text];
        Warnings: List of [Text];
        FieldMissingTxt: Label 'Field %1 is not on the page.', Comment = '%1 = the field name of a condition';
        ConditionFailedTxt: Label 'The condition on %1 could not be applied: %2', Comment = '%1 = the field the condition filters on, %2 = the reason';
        BlankNonTextErr: Label 'the value is blank, and only a text field can be filtered on a blank value';
        BlankOwnValueTok: Label '###', Locked = true;
        EmptyTextFilterTok: Label '''''', Locked = true;

    /// <summary>
    /// Returns the layout effects of one record. The layouts of the service apply in their Order. A layout
    /// matches when all its conditions hold, and a layout without conditions matches every record. The
    /// actions of every matching layout apply in layout order, and the first layout that sets a property
    /// wins. The layout rows of the service are copied once and kept by this instance, so callers keep one
    /// instance for a list. The rows are copied again only when the service or the loaded configuration
    /// (user, language or profile) differs from the copy.
    /// </summary>
    /// <param name="ServiceName">The Service Name whose layouts apply.</param>
    /// <param name="FieldRows">The rows of the service. Its filters are reset on exit.</param>
    /// <param name="SourceRef">The open source table, positioned on the record. Its record, key and filters are kept.</param>
    /// <returns>The effects: the matched layouts, the page colours and icons, the field and stage effects, and the warnings.</returns>
    procedure Evaluate(ServiceName: Text; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef): JsonObject
    var
        Position: Text;
    begin
        this.ClearState();
        if this.CacheNeedsCopy(ServiceName) then
            this.CopyLayoutCache(ServiceName);
        TempLayout.Reset();
        TempLayout.SetRange("Service Name", ServiceName);
        TempLayout.SetCurrentKey("User ID", "Query ID", "Service Name", "Order");
        Position := this.Records.Position(SourceRef);

        if TempLayout.FindSet() then
            repeat
                if not TempLayout."StopCollection" then
                    if this.LayoutMatches(TempLayout, TempCondition, FieldRows, SourceRef, Position) then begin
                        this.MatchedLayouts.Add(TempLayout."Code");
                        this.ApplyLayout(TempLayout, TempCachedAction, TempCachedActionLine);
                    end;
            until TempLayout.Next() = 0;

        exit(this.BuildEffects());
    end;

    /// <summary>
    /// Tells whether the layout rows in the cache must be copied again for a call.
    /// </summary>
    /// <param name="ServiceName">The Service Name of the call.</param>
    /// <returns>True when nothing is cached, or the cache holds another service or another loaded configuration.</returns>
    local procedure CacheNeedsCopy(ServiceName: Text): Boolean
    begin
        if not this.CacheIsFilled then
            exit(true);
        if this.CachedServiceName <> ServiceName then
            exit(true);
        exit((this.CachedUserId <> this.Config.LoadedUserId()) or (this.CachedLanguage <> this.Config.LoadedLanguage()) or (this.CachedProfile <> this.Config.LoadedProfile()));
    end;

    /// <summary>
    /// Copies the layout rows of one service from the configuration cache into this instance, and records
    /// which service and configuration the copy belongs to.
    /// </summary>
    /// <param name="ServiceName">The Service Name to copy.</param>
    local procedure CopyLayoutCache(ServiceName: Text)
    begin
        this.Config.CopyLayouts(ServiceName, this.TempLayout, this.TempCondition, this.TempCachedAction, this.TempCachedActionLine);
        this.CachedServiceName := ServiceName;
        this.CachedUserId := this.Config.LoadedUserId();
        this.CachedLanguage := this.Config.LoadedLanguage();
        this.CachedProfile := this.Config.LoadedProfile();
        this.CacheIsFilled := true;
    end;

    /// <summary>
    /// Returns the CSS colour of a MobileNAV colour area, the colour the screen renderer draws.
    /// </summary>
    /// <param name="ColorName">The colour area member name, for example FirstLine or Custom1.</param>
    /// <returns>The CSS colour.</returns>
    procedure ColorCss(ColorName: Text): Text
    begin
        exit(this.ScreenRenderer.ColorCss(ColorName));
    end;

    /// <summary>
    /// Tells whether a layout matches the record. The conditions that filter the record run first, on a
    /// copy of the record, and one Find tests them together. The field conditions compare two fields of
    /// that copy after the Find.
    /// </summary>
    /// <param name="Layout">The layout to test.</param>
    /// <param name="Conditions">The condition rows. Its filters are reset and set by this procedure.</param>
    /// <param name="FieldRows">The rows of the service.</param>
    /// <param name="SourceRef">The open source table, positioned on the record.</param>
    /// <param name="Position">The position of the record, from Records.Position.</param>
    /// <returns>True when every condition holds, or the layout has no conditions.</returns>
    local procedure LayoutMatches(var Layout: Record "MobileNAV Dynamic Layout Buff." temporary; var Conditions: Record "MobileNAV D. L. Cond. Buff." temporary; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; Position: Text): Boolean
    var
        TestRef: RecordRef;
    begin
        Conditions.Reset();
        Conditions.SetRange("Service Name", Layout."Service Name");
        Conditions.SetRange("Layout Code", Layout."Code");
        // Emulator reading (inferred, recon-behaviour.md 2.5): a layout without conditions matches every record.
        if Conditions.IsEmpty() then
            exit(true);

        TestRef.Open(SourceRef.Number());
        if not this.FiltersHold(Conditions, FieldRows, SourceRef, TestRef) then
            exit(false);
        if not this.Records.FindByPosition(TestRef, Position) then
            exit(false);
        exit(this.FieldConditionsHold(Conditions, FieldRows, SourceRef, TestRef));
    end;

    /// <summary>
    /// Applies the CONST and FILTER conditions of a layout to the copy of the record, in filter group 10,
    /// so that one Find tests them together.
    /// </summary>
    /// <param name="Conditions">The condition rows of the layout. Its filters are reset and set by this procedure.</param>
    /// <param name="FieldRows">The rows of the service.</param>
    /// <param name="SourceRef">The open source table, used to resolve the field names.</param>
    /// <param name="TestRef">The copy of the record that the filters are set on.</param>
    /// <returns>True when every filter condition was applied.</returns>
    local procedure FiltersHold(var Conditions: Record "MobileNAV D. L. Cond. Buff." temporary; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var TestRef: RecordRef): Boolean
    var
        AllApplied: Boolean;
    begin
        TestRef.FilterGroup(10);
        AllApplied := true;
        if Conditions.FindSet() then
            repeat
                if Conditions."ConditionType" <> Conditions."ConditionType"::"FIELD" then
                    if not this.ApplyFilterCondition(Conditions, FieldRows, SourceRef, TestRef) then
                        AllApplied := false;
            until Conditions.Next() = 0;
        exit(AllApplied);
    end;

    /// <summary>
    /// Tells whether every FIELD condition of a layout holds for the positioned copy of the record.
    /// </summary>
    /// <param name="Conditions">The condition rows of the layout.</param>
    /// <param name="FieldRows">The rows of the service.</param>
    /// <param name="SourceRef">The open source table, used to resolve the field names.</param>
    /// <param name="TestRef">The copy of the record, positioned on the record.</param>
    /// <returns>True when every FIELD condition holds, or there is none.</returns>
    local procedure FieldConditionsHold(var Conditions: Record "MobileNAV D. L. Cond. Buff." temporary; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var TestRef: RecordRef): Boolean
    begin
        if Conditions.FindSet() then
            repeat
                if Conditions."ConditionType" = Conditions."ConditionType"::"FIELD" then
                    if not this.FieldConditionHolds(Conditions, FieldRows, SourceRef, TestRef) then
                        exit(false);
            until Conditions.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// Sets the filter of a CONST or FILTER condition on the copy of the record. A CONST value is taken
    /// literally. A FILTER value is a filter expression when the comparison is Equal, and a literal
    /// value otherwise. A value that the filter rejects, or a blank value on a field that is not text,
    /// makes the condition fail with a warning.
    /// </summary>
    /// <param name="Condition">The condition row.</param>
    /// <param name="FieldRows">The rows of the service.</param>
    /// <param name="SourceRef">The open source table, used to resolve the field name.</param>
    /// <param name="TestRef">The copy of the record that the filter is set on, in filter group 10.</param>
    /// <returns>True when the filter was set.</returns>
    local procedure ApplyFilterCondition(var Condition: Record "MobileNAV D. L. Cond. Buff." temporary; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var TestRef: RecordRef): Boolean
    var
        FieldRef: FieldRef;
        FieldNumber: Integer;
        Index: Integer;
        Applied: Boolean;
    begin
        FieldNumber := this.Records.FieldNo(FieldRows, SourceRef, Condition."DestFieldName");
        if FieldNumber = 0 then begin
            this.AddWarning(StrSubstNo(this.FieldMissingTxt, Condition."DestFieldName"));
            exit(false);
        end;

        FieldRef := TestRef.Field(FieldNumber);
        Index := this.ComparisonIndex(Condition);
        if Condition."ConditionType" = Condition."ConditionType"::"CONST" then
            Applied := this.TrySetLiteralFilter(FieldRef, this.Records.ComparisonPrefix(Index), this.ConstValue(Condition."ConditionValue"))
        else
            Applied := this.SetFilterValue(FieldRef, Index, Condition."ConditionValue");

        if not Applied then begin
            this.AddWarning(StrSubstNo(this.ConditionFailedTxt, Condition."DestFieldName", GetLastErrorText()));
            exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Sets the filter of a FILTER condition. The Equal comparison takes the value as a filter expression,
    /// and every other comparison takes it literally.
    /// </summary>
    /// <param name="FieldRef">The field to filter.</param>
    /// <param name="Index">The index from ComparisonIndex.</param>
    /// <param name="Value">The ConditionValue of the row.</param>
    /// <returns>True when the filter was set.</returns>
    local procedure SetFilterValue(var FieldRef: FieldRef; Index: Integer; Value: Text): Boolean
    begin
        if Index = 0 then
            exit(this.TrySetRawFilter(FieldRef, Value));
        exit(this.TrySetLiteralFilter(FieldRef, this.Records.ComparisonPrefix(Index), Value));
    end;

    /// <summary>
    /// Returns the value of a CONST condition. The blank own value ### stands for the empty value.
    /// </summary>
    /// <param name="Value">The ConditionValue of the row.</param>
    /// <returns>The value to match.</returns>
    local procedure ConstValue(Value: Text): Text
    begin
        if Value = this.BlankOwnValueTok then
            exit('');
        exit(Value);
    end;

    /// <summary>
    /// Compares two fields of the copy of the record. Two numbers compare as decimals, two dates as dates,
    /// and anything else as text without case. Own and NotOwn compare as Equal and NotEqual.
    /// </summary>
    /// <param name="Condition">The FIELD condition row. DestFieldName is the left side and SourceFieldName the right side.</param>
    /// <param name="FieldRows">The rows of the service.</param>
    /// <param name="SourceRef">The open source table, used to resolve the field names.</param>
    /// <param name="TestRef">The copy of the record, positioned on the record.</param>
    /// <returns>True when the comparison holds.</returns>
    local procedure FieldConditionHolds(var Condition: Record "MobileNAV D. L. Cond. Buff." temporary; var FieldRows: Record "MobileNAV Settings Buffer" temporary; var SourceRef: RecordRef; var TestRef: RecordRef): Boolean
    var
        LeftRef: FieldRef;
        RightRef: FieldRef;
        LeftNumber: Integer;
        RightNumber: Integer;
    begin
        LeftNumber := this.Records.FieldNo(FieldRows, SourceRef, Condition."DestFieldName");
        if LeftNumber = 0 then begin
            this.AddWarning(StrSubstNo(this.FieldMissingTxt, Condition."DestFieldName"));
            exit(false);
        end;
        RightNumber := this.Records.FieldNo(FieldRows, SourceRef, Condition."SourceFieldName");
        if RightNumber = 0 then begin
            this.AddWarning(StrSubstNo(this.FieldMissingTxt, Condition."SourceFieldName"));
            exit(false);
        end;

        LeftRef := TestRef.Field(LeftNumber);
        RightRef := TestRef.Field(RightNumber);
        if LeftRef.Class() = FieldClass::FlowField then
            LeftRef.CalcField();
        if RightRef.Class() = FieldClass::FlowField then
            RightRef.CalcField();
        exit(this.ComparisonHolds(this.ComparisonIndex(Condition), this.CompareValues(LeftRef, RightRef)));
    end;

    /// <summary>
    /// Compares the values of two fields of one record.
    /// </summary>
    /// <param name="LeftRef">The left field.</param>
    /// <param name="RightRef">The right field.</param>
    /// <returns>-1 when the left value is lower, 0 when they are equal and 1 when it is higher.</returns>
    local procedure CompareValues(var LeftRef: FieldRef; var RightRef: FieldRef): Integer
    begin
        if this.IsNumber(LeftRef) and this.IsNumber(RightRef) then
            exit(this.CompareNumbers(LeftRef, RightRef));
        if (LeftRef.Type() = FieldType::Date) and (RightRef.Type() = FieldType::Date) then
            exit(this.CompareDates(LeftRef, RightRef));
        exit(this.CompareTexts(LeftRef, RightRef));
    end;

    /// <summary>
    /// Compares two numeric fields as decimals.
    /// </summary>
    /// <param name="LeftRef">The left field.</param>
    /// <param name="RightRef">The right field.</param>
    /// <returns>-1, 0 or 1.</returns>
    local procedure CompareNumbers(var LeftRef: FieldRef; var RightRef: FieldRef): Integer
    var
        LeftNumber: Decimal;
        RightNumber: Decimal;
    begin
        LeftNumber := LeftRef.Value();
        RightNumber := RightRef.Value();
        exit(this.SignOf(LeftNumber - RightNumber));
    end;

    /// <summary>
    /// Compares two date fields.
    /// </summary>
    /// <param name="LeftRef">The left field.</param>
    /// <param name="RightRef">The right field.</param>
    /// <returns>-1, 0 or 1.</returns>
    local procedure CompareDates(var LeftRef: FieldRef; var RightRef: FieldRef): Integer
    var
        LeftDate: Date;
        RightDate: Date;
    begin
        LeftDate := LeftRef.Value();
        RightDate := RightRef.Value();
        exit(this.SignOf(LeftDate - RightDate));
    end;

    /// <summary>
    /// Compares two fields as text, without case.
    /// </summary>
    /// <param name="LeftRef">The left field.</param>
    /// <param name="RightRef">The right field.</param>
    /// <returns>-1, 0 or 1.</returns>
    local procedure CompareTexts(var LeftRef: FieldRef; var RightRef: FieldRef): Integer
    var
        LeftText: Text;
        RightText: Text;
    begin
        LeftText := UpperCase(Format(LeftRef.Value(), 0, 9));
        RightText := UpperCase(Format(RightRef.Value(), 0, 9));
        if LeftText < RightText then
            exit(-1);
        if LeftText > RightText then
            exit(1);
        exit(0);
    end;

    /// <summary>
    /// Returns the sign of a difference.
    /// </summary>
    /// <param name="Difference">The difference of two values.</param>
    /// <returns>-1, 0 or 1.</returns>
    local procedure SignOf(Difference: Decimal): Integer
    begin
        if Difference < 0 then
            exit(-1);
        if Difference > 0 then
            exit(1);
        exit(0);
    end;

    /// <summary>
    /// Tells whether a field holds a number: an integer, a decimal or a big integer.
    /// </summary>
    /// <param name="FieldRef">The field to test.</param>
    /// <returns>True for a numeric field.</returns>
    local procedure IsNumber(var FieldRef: FieldRef): Boolean
    begin
        exit((FieldRef.Type() = FieldType::Integer) or (FieldRef.Type() = FieldType::Decimal) or (FieldRef.Type() = FieldType::BigInteger));
    end;

    /// <summary>
    /// Maps the comparison type of a condition to the index of Records.ComparisonPrefix. Own maps to
    /// Equal and NotOwn to NotEqual, because the build already gives them the device's own meaning.
    /// </summary>
    /// <param name="Condition">The condition row.</param>
    /// <returns>0 Equal, 1 NotEqual, 2 Less, 3 LessOrEqual, 4 Greater or 5 GreaterOrEqual.</returns>
    local procedure ComparisonIndex(var Condition: Record "MobileNAV D. L. Cond. Buff." temporary): Integer
    begin
        case Condition."Comparsion Type" of
            Condition."Comparsion Type"::Equal, Condition."Comparsion Type"::Own:
                exit(0);
            Condition."Comparsion Type"::NotEqual, Condition."Comparsion Type"::NotOwn:
                exit(1);
            Condition."Comparsion Type"::Less:
                exit(2);
            Condition."Comparsion Type"::LessOrEqual:
                exit(3);
            Condition."Comparsion Type"::Greater:
                exit(4);
            Condition."Comparsion Type"::GreaterOrEqual:
                exit(5);
        end;
        exit(0);
    end;

    /// <summary>
    /// Tells whether a comparison of two values holds.
    /// </summary>
    /// <param name="Index">The index from ComparisonIndex.</param>
    /// <param name="Difference">The result of CompareValues: -1, 0 or 1.</param>
    /// <returns>True when the comparison holds.</returns>
    local procedure ComparisonHolds(Index: Integer; Difference: Integer): Boolean
    begin
        case Index of
            0:
                exit(Difference = 0);
            1:
                exit(Difference <> 0);
            2:
                exit(Difference < 0);
            3:
                exit(Difference <= 0);
            4:
                exit(Difference > 0);
        end;
        exit(Difference >= 0);
    end;

    /// <summary>
    /// Sets a filter expression on a field, as the device reads it. Used for a FILTER condition with the
    /// Equal comparison.
    /// </summary>
    /// <param name="FieldRef">The field to filter.</param>
    /// <param name="FilterText">The filter expression.</param>
    /// <returns>True when the filter was set.</returns>
    [TryFunction]
    local procedure TrySetRawFilter(var FieldRef: FieldRef; FilterText: Text)
    begin
        FieldRef.SetFilter(FilterText);
    end;

    /// <summary>
    /// Sets a filter that holds one literal value. A text or code field takes the value as typed, so no
    /// character in it is read as a filter operator. Other fields take the value as a filter expression.
    /// </summary>
    /// <param name="FieldRef">The field to filter.</param>
    /// <param name="Prefix">The comparison operator, from Records.ComparisonPrefix. '' for Equal.</param>
    /// <param name="Value">The value to match.</param>
    /// <returns>True when the filter was set.</returns>
    [TryFunction]
    local procedure TrySetLiteralFilter(var FieldRef: FieldRef; Prefix: Text; Value: Text)
    begin
        if (FieldRef.Type() = FieldType::Text) or (FieldRef.Type() = FieldType::Code) then begin
            if Value <> '' then
                FieldRef.SetFilter(Prefix + '%1', Value)
            else
                if Prefix = '' then
                    FieldRef.SetRange('')
                else
                    FieldRef.SetFilter(Prefix + this.EmptyTextFilterTok);
        end else begin
            if Value = '' then
                Error(this.BlankNonTextErr);
            FieldRef.SetFilter(Prefix + Value);
        end;
    end;

    /// <summary>
    /// Applies the page-level and field-level actions of one matching layout.
    /// </summary>
    /// <param name="Layout">The matching layout.</param>
    /// <param name="TempAction">The action rows of the service.</param>
    /// <param name="TempActionLine">The action line rows of the service.</param>
    local procedure ApplyLayout(var Layout: Record "MobileNAV Dynamic Layout Buff." temporary; var TempAction: Record "MobileNAV D. L. Action Buff." temporary; var TempActionLine: Record "MobileNAV D. L. Act. L. Buff." temporary)
    begin
        TempAction.Reset();
        TempAction.SetRange("Service Name", Layout."Service Name");
        TempAction.SetRange("Layout Code", Layout."Code");
        if TempAction.FindSet() then
            repeat
                this.ApplyPageAction(TempAction);
            until TempAction.Next() = 0;

        TempActionLine.Reset();
        TempActionLine.SetRange("Service Name", Layout."Service Name");
        TempActionLine.SetRange("Layout Code", Layout."Code");
        if TempActionLine.FindSet() then
            repeat
                this.ApplyLine(TempActionLine, TempAction);
            until TempActionLine.Next() = 0;
    end;

    /// <summary>
    /// Applies one page-level action row: a read-only page, a line colour, the background colour or an icon.
    /// </summary>
    /// <param name="ActionRow">The action row.</param>
    local procedure ApplyPageAction(var ActionRow: Record "MobileNAV D. L. Action Buff." temporary)
    begin
        case ActionRow."Type" of
            ActionRow."Type"::PageReadOnly:
                this.SetFirst('page|readOnly', 'true');
            ActionRow."Type"::RowIcon:
                this.SetFirst('icon|row', ActionRow."Icon");
            ActionRow."Type"::ToolbarIcon:
                this.SetFirst('icon|toolbar', ActionRow."Icon");
            else
                this.ApplyPageColor(ActionRow);
        end;
    end;

    /// <summary>
    /// Applies a page-level colour action of the first line, the second line or the left cells.
    /// </summary>
    /// <param name="ActionRow">The action row.</param>
    local procedure ApplyPageColor(var ActionRow: Record "MobileNAV D. L. Action Buff." temporary)
    begin
        case ActionRow."Type" of
            ActionRow."Type"::FirstLineColor:
                this.SetFirst('color|firstLine', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::SecondLineColor:
                this.SetFirst('color|secondLine', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::TopLeftColor:
                this.SetFirst('color|topLeft', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::MiddleLeftColor:
                this.SetFirst('color|middleLeft', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::BottomLeftColor:
                this.SetFirst('color|bottomLeft', this.ColorOf(Format(ActionRow."Color")));
            else
                this.ApplyOtherPageColor(ActionRow);
        end;
    end;

    /// <summary>
    /// Applies a page-level colour action of the right cells or the background.
    /// </summary>
    /// <param name="ActionRow">The action row.</param>
    local procedure ApplyOtherPageColor(var ActionRow: Record "MobileNAV D. L. Action Buff." temporary)
    begin
        case ActionRow."Type" of
            ActionRow."Type"::TopRightColor:
                this.SetFirst('color|topRight', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::MiddleRightColor:
                this.SetFirst('color|middleRight', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::BottomRightColor:
                this.SetFirst('color|bottomRight', this.ColorOf(Format(ActionRow."Color")));
            ActionRow."Type"::BackgroundColor:
                this.SetFirst('color|background', this.ColorOf(Format(ActionRow."Color")));
        end;
    end;

    /// <summary>
    /// Applies one action line: a field effect, or a stage effect. A blank caption, colour or icon takes
    /// the value of the action row of the same type. The Color option has no blank member, so Normal
    /// stands for blank on an action line.
    /// </summary>
    /// <param name="LineRow">The action line row.</param>
    /// <param name="TempAction">The action rows of the service. Its filters are set by this procedure.</param>
    local procedure ApplyLine(var LineRow: Record "MobileNAV D. L. Act. L. Buff." temporary; var TempAction: Record "MobileNAV D. L. Action Buff." temporary)
    var
        HasActionRow: Boolean;
    begin
        TempAction.Reset();
        TempAction.SetRange("Service Name", LineRow."Service Name");
        TempAction.SetRange("Layout Code", LineRow."Layout Code");
        TempAction.SetRange("Type", LineRow."Action Type");
        HasActionRow := TempAction.FindFirst();

        case LineRow."Action Type" of
            LineRow."Action Type"::HideStage:
                this.AddUnique(this.HiddenStages, LineRow."Name");
            LineRow."Action Type"::StageValidated:
                this.AddUnique(this.ValidatedStages, LineRow."Name");
            else
                this.ApplyFieldLine(LineRow, TempAction, HasActionRow);
        end;
        TempAction.Reset();
    end;

    /// <summary>
    /// Applies one field action line: a read-only, hidden or validated field, or a caption or colour.
    /// </summary>
    /// <param name="LineRow">The action line row.</param>
    /// <param name="TempAction">The action rows of the service, for the fallback values.</param>
    /// <param name="HasActionRow">True when the action row of the same type exists.</param>
    local procedure ApplyFieldLine(var LineRow: Record "MobileNAV D. L. Act. L. Buff." temporary; var TempAction: Record "MobileNAV D. L. Action Buff." temporary; HasActionRow: Boolean)
    begin
        case LineRow."Action Type" of
            LineRow."Action Type"::FieldReadOnly:
                this.SetFieldSetting(LineRow."Name", 'readOnly', 'true');
            LineRow."Action Type"::HideField:
                this.SetFieldSetting(LineRow."Name", 'hidden', 'true');
            LineRow."Action Type"::FieldCaption:
                this.SetFieldSetting(LineRow."Name", 'caption', this.LineCaption(LineRow, TempAction, HasActionRow));
            LineRow."Action Type"::FieldCaptionColor:
                this.SetFieldSetting(LineRow."Name", 'captionColor', this.ColorOf(this.LineColorName(LineRow, TempAction, HasActionRow)));
            LineRow."Action Type"::FieldValueColor:
                this.SetFieldSetting(LineRow."Name", 'valueColor', this.ColorOf(this.LineColorName(LineRow, TempAction, HasActionRow)));
            LineRow."Action Type"::FieldValidated:
                this.SetFieldSetting(LineRow."Name", 'validated', 'true');
        end;
    end;

    /// <summary>
    /// Returns the caption of an action line, with the fallback to its action row when the line has none.
    /// </summary>
    /// <param name="LineRow">The action line row.</param>
    /// <param name="ActionRow">The action row of the same type.</param>
    /// <param name="HasActionRow">True when the action row exists.</param>
    /// <returns>The caption, or '' when neither has one.</returns>
    local procedure LineCaption(var LineRow: Record "MobileNAV D. L. Act. L. Buff." temporary; var ActionRow: Record "MobileNAV D. L. Action Buff." temporary; HasActionRow: Boolean): Text
    begin
        if (LineRow."Caption" = '') and HasActionRow then
            exit(ActionRow."Caption");
        exit(LineRow."Caption");
    end;

    /// <summary>
    /// Returns the colour name of an action line, with the fallback to its action row.
    /// </summary>
    /// <param name="LineRow">The action line row.</param>
    /// <param name="ActionRow">The action row of the same type.</param>
    /// <param name="HasActionRow">True when the action row exists.</param>
    /// <returns>The colour member name, or '' when the colour is unset.</returns>
    local procedure LineColorName(var LineRow: Record "MobileNAV D. L. Act. L. Buff." temporary; var ActionRow: Record "MobileNAV D. L. Action Buff." temporary; HasActionRow: Boolean): Text
    begin
        if LineRow."Color" <> LineRow."Color"::Normal then
            exit(Format(LineRow."Color"));
        if HasActionRow and (ActionRow."Color" <> ActionRow."Color"::Normal) then
            exit(Format(ActionRow."Color"));
        exit('');
    end;

    /// <summary>
    /// Returns the CSS colour of a colour name, or '' when the name is blank.
    /// </summary>
    /// <param name="ColorName">The colour member name, or ''.</param>
    /// <returns>The CSS colour, or ''.</returns>
    local procedure ColorOf(ColorName: Text): Text
    begin
        if ColorName = '' then
            exit('');
        exit(this.ColorCss(ColorName));
    end;

    /// <summary>
    /// Sets a property unless it is already set by an earlier layout. A blank value sets nothing.
    /// </summary>
    /// <param name="PropertyKey">The property key.</param>
    /// <param name="Value">The value. '' sets nothing.</param>
    local procedure SetFirst(PropertyKey: Text; Value: Text)
    begin
        if Value = '' then
            exit;
        if this.Settings.ContainsKey(PropertyKey) then
            exit;
        this.Settings.Add(PropertyKey, Value);
    end;

    /// <summary>
    /// Sets one effect of a field, and records that a matching layout touches the field.
    /// </summary>
    /// <param name="FieldName">The field name, as the Name of the action line.</param>
    /// <param name="Prop">The property: hidden, readOnly, caption, captionColor, valueColor or validated.</param>
    /// <param name="Value">The value to set.</param>
    local procedure SetFieldSetting(FieldName: Text; Prop: Text; Value: Text)
    begin
        this.TouchField(FieldName);
        this.SetFirst(this.FieldKey(FieldName, Prop), Value);
    end;

    /// <summary>Records that a matching layout touches a field, once.</summary>
    /// <param name="FieldName">The field name.</param>
    local procedure TouchField(FieldName: Text)
    begin
        this.AddUnique(this.TouchedFields, FieldName);
    end;

    /// <summary>Returns the settings key of one property of a field.</summary>
    /// <param name="FieldName">The field name.</param>
    /// <param name="Prop">The property name.</param>
    /// <returns>The key.</returns>
    local procedure FieldKey(FieldName: Text; Prop: Text): Text
    begin
        exit('field|' + FieldName + '|' + Prop);
    end;

    /// <summary>Adds an item to a list unless the list holds it already.</summary>
    /// <param name="Items">The list.</param>
    /// <param name="Item">The item.</param>
    local procedure AddUnique(var Items: List of [Text]; Item: Text)
    begin
        if not Items.Contains(Item) then
            Items.Add(Item);
    end;

    /// <summary>Adds a warning once.</summary>
    /// <param name="WarningText">The warning text.</param>
    local procedure AddWarning(WarningText: Text)
    begin
        this.AddUnique(this.Warnings, WarningText);
    end;

    /// <summary>Tells whether a property is set.</summary>
    /// <param name="PropertyKey">The property key.</param>
    /// <returns>True when a matching layout set the property.</returns>
    local procedure IsSet(PropertyKey: Text): Boolean
    begin
        exit(this.Settings.ContainsKey(PropertyKey));
    end;

    /// <summary>Returns the value of a property.</summary>
    /// <param name="PropertyKey">The property key.</param>
    /// <returns>The value, or '' when no layout set it.</returns>
    local procedure SettingOf(PropertyKey: Text): Text
    begin
        if this.Settings.ContainsKey(PropertyKey) then
            exit(this.Settings.Get(PropertyKey));
        exit('');
    end;

    /// <summary>The colour keys of the effects, in the order of the JSON.</summary>
    /// <returns>The keys.</returns>
    local procedure ColorNames(): List of [Text]
    var
        Names: List of [Text];
    begin
        Names.Add('firstLine');
        Names.Add('secondLine');
        Names.Add('topLeft');
        Names.Add('middleLeft');
        Names.Add('bottomLeft');
        Names.Add('topRight');
        Names.Add('middleRight');
        Names.Add('bottomRight');
        Names.Add('background');
        exit(Names);
    end;

    /// <summary>Builds the effects object of the layouts that matched.</summary>
    /// <returns>The effects, with every key present.</returns>
    local procedure BuildEffects(): JsonObject
    var
        Effects: JsonObject;
        Colors: JsonObject;
        Fields: JsonObject;
        MatchedArray: JsonArray;
        HiddenArray: JsonArray;
        ValidatedArray: JsonArray;
        WarningArray: JsonArray;
        LayoutCode: Text;
        ColorKey: Text;
        FieldName: Text;
        StageName: Text;
        WarningText: Text;
    begin
        foreach LayoutCode in this.MatchedLayouts do
            MatchedArray.Add(LayoutCode);
        foreach ColorKey in this.ColorNames() do
            Colors.Add(ColorKey, this.SettingOf('color|' + ColorKey));
        foreach FieldName in this.TouchedFields do
            Fields.Add(FieldName, this.FieldJson(FieldName));
        foreach StageName in this.HiddenStages do
            HiddenArray.Add(StageName);
        foreach StageName in this.ValidatedStages do
            ValidatedArray.Add(StageName);
        foreach WarningText in this.Warnings do
            WarningArray.Add(WarningText);

        Effects.Add('matched', MatchedArray);
        Effects.Add('pageReadOnly', this.IsSet('page|readOnly'));
        Effects.Add('colors', Colors);
        Effects.Add('rowIcon', this.SettingOf('icon|row'));
        Effects.Add('toolbarIcon', this.SettingOf('icon|toolbar'));
        Effects.Add('fields', Fields);
        Effects.Add('hiddenStages', HiddenArray);
        Effects.Add('validatedStages', ValidatedArray);
        Effects.Add('warnings', WarningArray);
        exit(Effects);
    end;

    /// <summary>Builds the effect object of one field.</summary>
    /// <param name="FieldName">The field name.</param>
    /// <returns>The field object with every key present.</returns>
    local procedure FieldJson(FieldName: Text): JsonObject
    var
        FieldObj: JsonObject;
    begin
        FieldObj.Add('hidden', this.IsSet(this.FieldKey(FieldName, 'hidden')));
        FieldObj.Add('readOnly', this.IsSet(this.FieldKey(FieldName, 'readOnly')));
        FieldObj.Add('caption', this.SettingOf(this.FieldKey(FieldName, 'caption')));
        FieldObj.Add('captionColor', this.SettingOf(this.FieldKey(FieldName, 'captionColor')));
        FieldObj.Add('valueColor', this.SettingOf(this.FieldKey(FieldName, 'valueColor')));
        FieldObj.Add('validated', this.IsSet(this.FieldKey(FieldName, 'validated')));
        exit(FieldObj);
    end;

    /// <summary>Empties the state of the previous call.</summary>
    local procedure ClearState()
    begin
        Clear(this.Settings);
        Clear(this.MatchedLayouts);
        Clear(this.TouchedFields);
        Clear(this.HiddenStages);
        Clear(this.ValidatedStages);
        Clear(this.Warnings);
    end;
}

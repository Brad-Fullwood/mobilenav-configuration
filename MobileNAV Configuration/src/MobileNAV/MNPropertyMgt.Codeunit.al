namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes and reads the one-field settings a definition carries as properties, on a page's
/// Main row or a control's field row. Options are resolved by member name; other values
/// arrive in XML format and are converted to the field's type.
/// </summary>
codeunit 77779 "BJF MN Property Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rm;

    /// <summary>Writes the property. Errors when the page or control has no row.</summary>
    procedure Apply(ServiceName: Text[100]; TempProperty: Record "BJF MN Config Property" temporary)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        SetupRecordRef: RecordRef;
        TargetFieldRef: FieldRef;
    begin
        if not this.FindTargetRow(ServiceName, TempProperty, ServiceSetup) then
            Error(this.TargetMissingErr, TempProperty.Setting, TempProperty."Control Name", ServiceName);
        SetupRecordRef.GetTable(ServiceSetup);
        TargetFieldRef := SetupRecordRef.Field(TempProperty."Field No.");
        this.SetValue(TargetFieldRef, this.ExpectedValue(ServiceName, TempProperty), TempProperty.Validate);
        SetupRecordRef.Modify(true);
    end;

    /// <summary>The value the property asks for, resolved and in the form LiveValue returns.</summary>
    procedure ExpectedValue(ServiceName: Text[100]; TempProperty: Record "BJF MN Config Property" temporary): Text
    var
        ControlRow: Record "MobileNAV Service Setup";
    begin
        case TempProperty."Value Kind" of
            Enum::"BJF MN Property Value"::"Control Name":
                exit(this.Lookup.StoredFieldName(TempProperty.Value));
            Enum::"BJF MN Property Value"::"Control Line No.":
                begin
                    if not this.Lookup.FindFieldRow(ServiceName, CopyStr(TempProperty.Value, 1, 100), ControlRow) then
                        Error(this.ReferencedControlMissingErr, TempProperty.Setting, TempProperty.Value, ServiceName);
                    exit(Format(ControlRow."Page Line No.", 0, 9));
                end;
        end;
        exit(TempProperty.Value);
    end;

    /// <summary>The field's current value in the same form as ExpectedValue; false when the row does not exist.</summary>
    procedure LiveValue(ServiceName: Text[100]; TempProperty: Record "BJF MN Config Property" temporary; var Value: Text): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        SetupRecordRef: RecordRef;
        TargetFieldRef: FieldRef;
    begin
        if not this.FindTargetRow(ServiceName, TempProperty, ServiceSetup) then
            exit(false);
        SetupRecordRef.GetTable(ServiceSetup);
        TargetFieldRef := SetupRecordRef.Field(TempProperty."Field No.");
        if TargetFieldRef.Type() = FieldType::Option then
            Value := this.Lookup.OptionName(ServiceSetup, TempProperty."Field No.")
        else
            Value := Format(TargetFieldRef.Value(), 0, 9);
        exit(true);
    end;

    /// <summary>The caption of the MobileNAV field a property targets, for messages.</summary>
    procedure FieldCaption(FieldNo: Integer): Text
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        SetupRecordRef: RecordRef;
    begin
        SetupRecordRef.GetTable(ServiceSetup);
        exit(SetupRecordRef.Field(FieldNo).Caption());
    end;

    local procedure FindTargetRow(ServiceName: Text[100]; TempProperty: Record "BJF MN Config Property" temporary; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        if TempProperty."Control Name" = '' then
            exit(this.Lookup.FindMainRow(ServiceName, ServiceSetup));
        exit(this.Lookup.FindFieldRow(ServiceName, TempProperty."Control Name", ServiceSetup));
    end;

    local procedure SetValue(var TargetFieldRef: FieldRef; Value: Text; RunValidate: Boolean)
    var
        BooleanValue: Boolean;
        IntegerValue: Integer;
        DecimalValue: Decimal;
    begin
        case TargetFieldRef.Type() of
            FieldType::Option:
                this.Lookup.SetOptionMember(TargetFieldRef, Value);
            FieldType::Boolean:
                begin
                    Evaluate(BooleanValue, Value, 9);
                    this.Write(TargetFieldRef, BooleanValue, RunValidate);
                end;
            FieldType::Integer:
                begin
                    Evaluate(IntegerValue, Value, 9);
                    this.Write(TargetFieldRef, IntegerValue, RunValidate);
                end;
            FieldType::Decimal:
                begin
                    Evaluate(DecimalValue, Value, 9);
                    this.Write(TargetFieldRef, DecimalValue, RunValidate);
                end;
            else
                this.Write(TargetFieldRef, CopyStr(Value, 1, TargetFieldRef.Length()), RunValidate);
        end;
    end;

    local procedure Write(var TargetFieldRef: FieldRef; Value: Variant; RunValidate: Boolean)
    begin
        if RunValidate then
            TargetFieldRef.Validate(Value)
        else
            TargetFieldRef.Value := Value;
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        TargetMissingErr: Label '%1 could not be applied: control %2 was not found on MobileNAV service %3.', Comment = '%1 = setting, %2 = control name (empty for the page), %3 = service name';
        ReferencedControlMissingErr: Label '%1 refers to control %2, which was not found on MobileNAV service %3.', Comment = '%1 = setting, %2 = control name, %3 = service name';
}

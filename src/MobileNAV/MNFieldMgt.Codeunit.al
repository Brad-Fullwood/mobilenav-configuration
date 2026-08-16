
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Owns MobileNAV field state and linked-page relation/filter persistence.</summary>
codeunit 77789 "BJF MN Field Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rim;

    procedure ConfigureField(ServiceName: Text[100]; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, Visible);
        ServiceSetup.Editable := Editable;
        ServiceSetup.DisplayInMenu := DisplayInMenu;
        ServiceSetup.Modify(true);
        exit(true);
    end;

    procedure ConfigureLinkedField(ServiceName: Text[100]; ControlName: Text[100]; TargetServiceName: Text[75]; TargetFilterField: Text[100]; SourceField: Text[100]): Boolean
    var
        FieldSetup: Record "MobileNAV Service Setup";
        RelatedTableNo: Integer;
    begin
        if not this.FindField(ServiceName, ControlName, FieldSetup) then
            exit(false);
        if not PageManagement.GetServiceTableNo(TargetServiceName, RelatedTableNo) then
            Error(TargetServiceMissingErr, TargetServiceName);

        FieldSetup.Validate(Visible, true);
        FieldSetup.DisplayInMenu := true;
        FieldSetup.Modify(true);

        this.UpsertRelation(FieldSetup, TargetServiceName, TargetFilterField, RelatedTableNo);
        this.UpsertFilter(FieldSetup, TargetServiceName, TargetFilterField, SourceField, RelatedTableNo);
        exit(true);
    end;

    /// <summary>
    /// Binds a field to a MobileNAV page function and mobile control type, making it visible,
    /// editable, and shown in the menu. Option values arrive as text and are resolved against
    /// the option members of the MobileNAV Service Setup fields, so this codeunit never has to
    /// track MobileNAV's option lists. Function Name is validated through MobileNAV's own
    /// table procedure, which also coerces the field class for BLOB function types.
    /// </summary>
    procedure ConfigureFunctionField(ServiceName: Text[100]; ControlName: Text[100]; Editable: Boolean; MobileType: Text[30]; FunctionName: Text[50]; FunctionType: Text[30]; ValidationBehavior: Text[50]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, true);
        ServiceSetup.Editable := Editable;
        ServiceSetup.DisplayInMenu := true;
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), MobileType);
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Function Type"), FunctionType);
        ServiceSetup.ValidateFunctionName(FunctionName, false);
        if ValidationBehavior <> '' then
            this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Validation Behavior"), ValidationBehavior);
        ServiceSetup.Modify(true);
        exit(true);
    end;

    local procedure SetOptionField(var ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer; ValueName: Text)
    var
        SetupRecordRef: RecordRef;
        OptionFieldRef: FieldRef;
        MemberIndex: Integer;
    begin
        SetupRecordRef.GetTable(ServiceSetup);
        OptionFieldRef := SetupRecordRef.Field(FieldNumber);
        for MemberIndex := 1 to OptionFieldRef.EnumValueCount() do
            if UpperCase(OptionFieldRef.GetEnumValueName(MemberIndex)) = UpperCase(ValueName) then begin
                OptionFieldRef.Value := OptionFieldRef.GetEnumValueOrdinal(MemberIndex);
                SetupRecordRef.SetTable(ServiceSetup);
                exit;
            end;
        Error(UnknownOptionValueErr, ValueName, OptionFieldRef.Caption());
    end;

    local procedure FindField(ServiceName: Text[100]; ControlName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.SetRange(FieldName, this.ConvertFieldName(ControlName));
        exit(ServiceSetup.FindFirst());
    end;

    local procedure UpsertRelation(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[75]; TargetFilterField: Text[100]; RelatedTableNo: Integer)
    var
        RelationSetup: Record "MobileNAV Service Setup";
        IsNew: Boolean;
    begin
        RelationSetup.SetRange("Object Type", FieldSetup."Object Type");
        RelationSetup.SetRange("Service Name", FieldSetup."Service Name");
        RelationSetup.SetRange("Line Type", RelationSetup."Line Type"::Relation);
        RelationSetup.SetRange("Page Line No.", FieldSetup."Page Line No.");
        RelationSetup.SetRange("Relation No.", 1);
        IsNew := not RelationSetup.FindFirst();

        if IsNew then begin
            RelationSetup.Init();
            RelationSetup."Object Type" := FieldSetup."Object Type";
            RelationSetup."Service Name" := FieldSetup."Service Name";
            RelationSetup."Line Type" := RelationSetup."Line Type"::Relation;
            RelationSetup."Page Line No." := FieldSetup."Page Line No.";
            RelationSetup."Relation No." := 1;
            RelationSetup."Line No." := 0;
        end;

        RelationSetup."Object ID" := FieldSetup."Object ID";
        RelationSetup.ControlID := FieldSetup.ControlID;
        RelationSetup.FieldName := FieldSetup.FieldName;
        RelationSetup.RelatedPageName := TargetServiceName;
        RelationSetup."Related Table No." := RelatedTableNo;
        RelationSetup.RelatedPgCodeFldName := this.ConvertFieldName(TargetFilterField);

        if IsNew then
            RelationSetup.Insert(true)
        else
            RelationSetup.Modify(true);
    end;

    local procedure UpsertFilter(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[75]; TargetFilterField: Text[100]; SourceField: Text[100]; RelatedTableNo: Integer)
    var
        FilterSetup: Record "MobileNAV Service Setup";
        IsNew: Boolean;
    begin
        FilterSetup.SetRange("Object Type", FieldSetup."Object Type");
        FilterSetup.SetRange("Service Name", FieldSetup."Service Name");
        FilterSetup.SetRange("Line Type", FilterSetup."Line Type"::Filter);
        FilterSetup.SetRange("Page Line No.", FieldSetup."Page Line No.");
        FilterSetup.SetRange("Relation No.", 1);
        FilterSetup.SetRange("Line No.", 10000);
        IsNew := not FilterSetup.FindFirst();

        if IsNew then begin
            FilterSetup.Init();
            FilterSetup."Object Type" := FieldSetup."Object Type";
            FilterSetup."Service Name" := FieldSetup."Service Name";
            FilterSetup."Line Type" := FilterSetup."Line Type"::Filter;
            FilterSetup."Page Line No." := FieldSetup."Page Line No.";
            FilterSetup."Relation No." := 1;
            FilterSetup."Line No." := 10000;
        end;

        FilterSetup."Object ID" := FieldSetup."Object ID";
        FilterSetup.ControlID := FieldSetup.ControlID;
        FilterSetup.FieldName := FieldSetup.FieldName;
        FilterSetup.RelatedPageName := TargetServiceName;
        FilterSetup."Related Table No." := RelatedTableNo;
        FilterSetup.FilterType := FilterSetup.FilterType::FIELD;
        FilterSetup."Filter Comparsion Type" := FilterSetup."Filter Comparsion Type"::Equal;
        FilterSetup.DestFieldName := this.ConvertFieldName(TargetFilterField);
        FilterSetup.SourceFieldName := this.ConvertFieldName(SourceField);

        if IsNew then
            FilterSetup.Insert(true)
        else
            FilterSetup.Modify(true);
    end;

    local procedure ConvertFieldName(OriginalName: Text): Text[75]
    begin
        exit(CopyStr(WebServiceHandling.ConvertFieldName(OriginalName), 1, 75));
    end;

    var
        PageManagement: Codeunit "BJF MN Page Mgt.";
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        TargetServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
        UnknownOptionValueErr: Label '%1 is not a valid value for %2 in this MobileNAV version.', Comment = '%1 = requested option value, %2 = field caption';
}

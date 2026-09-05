namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes a control's service-level configuration: field, button, scan input, link and the
/// per-user scope.
///
/// Several MobileNAV Service Setup fields are assigned directly rather than validated, on
/// purpose. Their OnValidate triggers are written for an administrator at the keyboard, not
/// for an unattended apply: Editable silently reverts and shows a Message; DisplayInMenu
/// rewrites Category and Order; "Visible as Filter" raises a Confirm and can delete sibling
/// rows; "Object ID" rebuilds the page's metadata; the relation and filter fields
/// (RelatedPageName, "Related Table No.", FilterType, "Filter Comparsion Type",
/// SourceFieldName, DestFieldName) delete child rows, clear each other or error on
/// half-written state. Each direct assignment is marked with a PC0037 pragma.
/// </summary>
codeunit 77789 "BJF MN Field Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rim;

    /// <summary>
    /// Configures a plain field. Importance is written on every apply because MobileNAV
    /// initializes it to Additional, which hides the field behind the card's "show more".
    /// </summary>
    /// <param name="Importance">MobileNAV Mandatory member name, for example 'None'.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureField(ServiceName: Text[100]; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean; Importance: Text[30]; Filterable: Boolean): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, Visible);
#pragma warning disable PC0037
        ServiceSetup.Editable := Editable;
        ServiceSetup.DisplayInMenu := DisplayInMenu;
        ServiceSetup."Visible as Filter" := Filterable;
#pragma warning restore PC0037
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(Mandatory), Importance);
        ServiceSetup.Modify(true);
        if Editable then
            this.EnsurePageUpdatable(ServiceName);
        exit(true);
    end;

    /// <summary>
    /// Configures a button: a field bound to a MobileNAV page function and a mobile control
    /// type. Function Name goes through MobileNAV's own validation, which also coerces the
    /// field class for BLOB function types.
    /// </summary>
    /// <param name="ValidationBehavior">MobileNAV Validation Behavior member name; empty keeps the default.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureFunctionField(ServiceName: Text[100]; ControlName: Text[100]; Editable: Boolean; MobileType: Text[30]; FunctionName: Text[50]; FunctionType: Text[30]; ValidationBehavior: Text[50]; Importance: Text[30]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, true);
#pragma warning disable PC0037
        ServiceSetup.Editable := Editable;
        // A capture control (image, signature, file) is drawn on the card with its own camera or
        // upload menu; the Android client draws a capture control placed in the menu nowhere at
        // all. Every other button is a menu entry.
        ServiceSetup.DisplayInMenu := not this.RendersInline(MobileType);
#pragma warning restore PC0037
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(Mandatory), Importance);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), MobileType);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Function Type"), FunctionType);
        if ValidationBehavior <> '' then
            this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Validation Behavior"), ValidationBehavior);
        ServiceSetup.ValidateFunctionName(FunctionName, false);
        ServiceSetup.Modify(true);
        if Editable then
            this.EnsurePageUpdatable(ServiceName);
        exit(true);
    end;

    /// <summary>Configures an editable input the device fills from its scanner.</summary>
    /// <param name="ValidationBehavior">MobileNAV Validation Behavior member name; empty keeps the default.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureScanField(ServiceName: Text[100]; ControlName: Text[100]; MobileType: Text[30]; ValidationBehavior: Text[50]; Importance: Text[30]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, true);
#pragma warning disable PC0037
        ServiceSetup.Editable := true;
#pragma warning restore PC0037
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(Mandatory), Importance);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), MobileType);
        if ValidationBehavior <> '' then
            this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Validation Behavior"), ValidationBehavior);
        ServiceSetup.Modify(true);
        exit(true);
    end;

    /// <summary>
    /// Configures a control that opens another page filtered to the current record: the field
    /// row becomes a menu entry, and a relation row plus a filter row bind it to the target.
    /// </summary>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureLinkedField(ServiceName: Text[100]; ControlName: Text[100]; TargetServiceName: Text[75]; TargetFilterField: Text[100]; SourceField: Text[100]; Importance: Text[30]): Boolean
    var
        FieldSetup: Record "MobileNAV Service Setup";
        RelatedTableNo: Integer;
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, FieldSetup) then
            exit(false);
        if not this.Lookup.GetServiceTableNo(TargetServiceName, RelatedTableNo) then
            Error(this.TargetServiceMissingErr, TargetServiceName);

        FieldSetup.Validate(Visible, true);
#pragma warning disable PC0037
        FieldSetup.DisplayInMenu := true;
#pragma warning restore PC0037
        this.Lookup.SetOptionField(FieldSetup, FieldSetup.FieldNo(Mandatory), Importance);
        FieldSetup.Modify(true);

        this.UpsertRelation(FieldSetup, TargetServiceName, RelatedTableNo);
        this.UpsertFilter(FieldSetup, TargetServiceName, TargetFilterField, SourceField, RelatedTableNo);
        exit(true);
    end;

    /// <summary>
    /// Scopes a page to the signed-in device user through MobileNAV's "Mine" mechanism: the
    /// control is marked as the page's user identity (MobileType UserID) and a page-level
    /// filter with comparison Own is written over it. MobileNAV replaces Own with an equality
    /// against the device user when it builds the configuration, so a shared per-user table
    /// shows exactly one row on each device.
    /// </summary>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureUserScope(ServiceName: Text[100]; ControlName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        FilterSetup: Record "MobileNAV Service Setup";
        IsNew: Boolean;
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        // Own only validates against a field marked as a per-user value, so the mark goes first.
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), this.UserIdMobileTypeTok);
        ServiceSetup.Modify(true);

        FilterSetup.SetRange("Object Type", ServiceSetup."Object Type");
        FilterSetup.SetRange("Service Name", ServiceSetup."Service Name");
        FilterSetup.SetRange("Line Type", FilterSetup."Line Type"::Filter);
        FilterSetup.SetRange("Page Line No.", 0);
        FilterSetup.SetRange("Relation No.", 0);
        FilterSetup.SetRange(SourceFieldName, ServiceSetup.FieldName);
        IsNew := not FilterSetup.FindFirst();
        if IsNew then
            this.InitChildRow(FilterSetup, ServiceSetup, FilterSetup."Line Type"::Filter, 0, 0, 10000);

#pragma warning disable PC0037
        FilterSetup."Object ID" := ServiceSetup."Object ID";
        FilterSetup.FilterType := FilterSetup.FilterType::FIELD;
        FilterSetup."Filter Comparsion Type" := FilterSetup."Filter Comparsion Type"::Own;
        FilterSetup.SourceFieldName := ServiceSetup.FieldName;
        FilterSetup.DestFieldName := ServiceSetup.FieldName;
        FilterSetup.FilterValue := '';
#pragma warning restore PC0037
        this.Save(FilterSetup, IsNew);
        exit(true);
    end;

    /// <summary>
    /// Whether a button of this mobile type is drawn on the card itself rather than in the
    /// page's menu. Image, Signature and File are capture controls.
    /// </summary>
    procedure RendersInline(MobileType: Text): Boolean
    begin
        exit(UpperCase(MobileType) in [
            UpperCase(this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::Image)),
            UpperCase(this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::Signature)),
            UpperCase(this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::File))]);
    end;

    /// <summary>
    /// Page Update gates whether the device may write anything back; with it off every field
    /// is drawn read-only regardless of its own configuration.
    /// </summary>
    local procedure EnsurePageUpdatable(ServiceName: Text[100])
    var
        MainRow: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            exit;
        if MainRow."Page Update" then
            exit;
        MainRow.Validate("Page Update", true);
        MainRow.Modify(true);
    end;

    /// <summary>
    /// The relation row that makes the control open the target page. RelatedPgCodeFldName stays
    /// empty on purpose: set, it turns the relation into a lookup binding, and an empty
    /// read-only lookup is not drawn at all. MobileNAV's own action-style relations leave it
    /// blank and let the filter rows carry the binding.
    /// </summary>
    local procedure UpsertRelation(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[75]; RelatedTableNo: Integer)
    var
        RelationSetup: Record "MobileNAV Service Setup";
        IsNew: Boolean;
    begin
        IsNew := not this.FindChildRow(FieldSetup, RelationSetup."Line Type"::Relation, 1, 0, RelationSetup);
        if IsNew then
            this.InitChildRow(RelationSetup, FieldSetup, RelationSetup."Line Type"::Relation, FieldSetup."Page Line No.", 1, 0);

#pragma warning disable PC0037
        RelationSetup."Object ID" := FieldSetup."Object ID";
        RelationSetup.RelatedPageName := TargetServiceName;
        RelationSetup."Related Table No." := RelatedTableNo;
        RelationSetup.RelatedPgCodeFldName := '';
#pragma warning restore PC0037
        RelationSetup.Validate(ControlID, FieldSetup.ControlID);
        RelationSetup.Validate(FieldName, FieldSetup.FieldName);
        this.Save(RelationSetup, IsNew);
    end;

    local procedure UpsertFilter(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[75]; TargetFilterField: Text[100]; SourceField: Text[100]; RelatedTableNo: Integer)
    var
        FilterSetup: Record "MobileNAV Service Setup";
        IsNew: Boolean;
    begin
        IsNew := not this.FindChildRow(FieldSetup, FilterSetup."Line Type"::Filter, 1, 10000, FilterSetup);
        if IsNew then
            this.InitChildRow(FilterSetup, FieldSetup, FilterSetup."Line Type"::Filter, FieldSetup."Page Line No.", 1, 10000);

#pragma warning disable PC0037
        FilterSetup."Object ID" := FieldSetup."Object ID";
        FilterSetup.RelatedPageName := TargetServiceName;
        FilterSetup."Related Table No." := RelatedTableNo;
        FilterSetup.FilterType := FilterSetup.FilterType::FIELD;
        FilterSetup."Filter Comparsion Type" := FilterSetup."Filter Comparsion Type"::Equal;
        FilterSetup.DestFieldName := this.Lookup.StoredFieldName(TargetFilterField);
        FilterSetup.SourceFieldName := this.Lookup.StoredFieldName(SourceField);
#pragma warning restore PC0037
        FilterSetup.Validate(ControlID, FieldSetup.ControlID);
        FilterSetup.Validate(FieldName, FieldSetup.FieldName);
        this.Save(FilterSetup, IsNew);
    end;

    local procedure FindChildRow(FieldSetup: Record "MobileNAV Service Setup"; LineType: Option; RelationNo: Integer; LineNo: Integer; var ChildRow: Record "MobileNAV Service Setup"): Boolean
    begin
        ChildRow.SetRange("Object Type", FieldSetup."Object Type");
        ChildRow.SetRange("Service Name", FieldSetup."Service Name");
        ChildRow.SetRange("Line Type", LineType);
        ChildRow.SetRange("Page Line No.", FieldSetup."Page Line No.");
        ChildRow.SetRange("Relation No.", RelationNo);
        if LineNo <> 0 then
            ChildRow.SetRange("Line No.", LineNo);
        exit(ChildRow.FindFirst());
    end;

    local procedure InitChildRow(var ChildRow: Record "MobileNAV Service Setup"; ParentRow: Record "MobileNAV Service Setup"; LineType: Option; PageLineNo: Integer; RelationNo: Integer; LineNo: Integer)
    begin
        ChildRow.Init();
        ChildRow.Validate("Object Type", ParentRow."Object Type");
        ChildRow.Validate("Service Name", ParentRow."Service Name");
        ChildRow.Validate("Line Type", LineType);
        ChildRow.Validate("Page Line No.", PageLineNo);
        ChildRow.Validate("Relation No.", RelationNo);
        ChildRow.Validate("Line No.", LineNo);
    end;

    local procedure Save(var ServiceSetup: Record "MobileNAV Service Setup"; IsNew: Boolean)
    begin
        if IsNew then
            ServiceSetup.Insert(true)
        else
            ServiceSetup.Modify(true);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        Vocabulary: Codeunit "BJF MN Vocabulary";
        UserIdMobileTypeTok: Label 'UserID', Locked = true;
        TargetServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
}

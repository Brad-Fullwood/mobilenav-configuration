
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Owns MobileNAV field state and linked-page relation/filter persistence.</summary>
codeunit 77789 "BJF MN Field Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rim;

    /// <summary>
    /// Sets a field's visibility, editability, menu flag, placement, and filter availability.
    /// Importance is MobileNAV's Mandatory field (caption Importance) and is resolved against
    /// its option members, so this codeunit never has to track MobileNAV's option list. It
    /// must be written on every apply: MobileNAV initializes it to Additional, which hides an
    /// otherwise visible field behind the card's additional fields section. Filter Scope is
    /// deliberately left at MobileNAV's default.
    /// </summary>
    /// <param name="ServiceName">MobileNAV service the field belongs to.</param>
    /// <param name="ControlName">Field's control name on the page.</param>
    /// <param name="Visible">Whether the field is shown.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    /// <param name="DisplayInMenu">Whether the field appears in the field menu.</param>
    /// <param name="Importance">MobileNAV Mandatory option member name (for example Additional).</param>
    /// <param name="Filterable">Whether the field is available as a filter.</param>
    /// <returns>True when the field was found and configured; false when it does not exist.</returns>
    procedure ConfigureField(ServiceName: Text[100]; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean; Importance: Text[30]; Filterable: Boolean): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, Visible);
        // Editable: OnValidate silently reverts the value and shows a Message() when the
        // underlying field is not editable on the page or is a NoSeries field.
        // DisplayInMenu: OnValidate branches on "Line Type"/"Page Type" and writes "Quick Edit/Action"
        // or clears Category/Order.
#pragma warning disable PC0037
        ServiceSetup.Editable := Editable;
        ServiceSetup.DisplayInMenu := DisplayInMenu;
#pragma warning restore PC0037
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(Mandatory), Importance);
        if Editable then
            this.EnsurePageUpdatable(ServiceName);
        // Visible as Filter: OnValidate raises a Confirm() dialog and can DeleteAll the page's flow
        // filters and sibling setup rows.
#pragma warning disable PC0037
        ServiceSetup."Visible as Filter" := Filterable;
#pragma warning restore PC0037
        ServiceSetup.Modify(true);
        exit(true);
    end;

    procedure ConfigureLinkedField(ServiceName: Text[100]; ControlName: Text[100]; TargetServiceName: Text[75]; TargetFilterField: Text[100]; SourceField: Text[100]; Importance: Text[30]): Boolean
    var
        FieldSetup: Record "MobileNAV Service Setup";
        RelatedTableNo: Integer;
    begin
        if not this.FindField(ServiceName, ControlName, FieldSetup) then
            exit(false);
        if not this.PageManagement.GetServiceTableNo(TargetServiceName, RelatedTableNo) then
            Error(this.TargetServiceMissingErr, TargetServiceName);

        FieldSetup.Validate(Visible, true);
        // A linked field renders as the button that opens the target page, so MobileNAV's
        // Additional default hides the only way in to that page. See ConfigureFunctionField.
        if Importance <> '' then
            this.SetOptionField(FieldSetup, FieldSetup.FieldNo(Mandatory), Importance);
        // DisplayInMenu: OnValidate branches on "Line Type"/"Page Type" and writes "Quick Edit/Action"
        // or clears Category/Order.
#pragma warning disable PC0037
        FieldSetup.DisplayInMenu := true;
#pragma warning restore PC0037
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
    /// <param name="ServiceName">MobileNAV service the field belongs to.</param>
    /// <param name="ControlName">Field's control name on the page.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    /// <param name="MobileType">MobileNAV mobile control type option member name.</param>
    /// <param name="FunctionName">Page function name, validated through MobileNAV's own table procedure.</param>
    /// <param name="FunctionType">MobileNAV Function Type option member name.</param>
    /// <param name="ValidationBehavior">MobileNAV Validation Behavior option member name; empty keeps the default.</param>
    /// <param name="Importance">MobileNAV Mandatory option member name; empty keeps MobileNAV's default.</param>
    /// <returns>True when the field was found and configured; false when it does not exist.</returns>
    procedure ConfigureFunctionField(ServiceName: Text[100]; ControlName: Text[100]; Editable: Boolean; MobileType: Text[30]; FunctionName: Text[50]; FunctionType: Text[30]; ValidationBehavior: Text[50]; Importance: Text[30]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, true);
        // Importance has to be written here for the same reason ConfigureField writes it:
        // MobileNAV initializes a new field to Additional, which hides the control behind the
        // card's additional fields section. A function control hidden there is a button the
        // device user cannot find, so the button silently does nothing for them.
        if Importance <> '' then
            this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(Mandatory), Importance);
        // Editable: OnValidate silently reverts the value and shows a Message() when the underlying
        // field is not editable on the page or is a NoSeries field.
        // DisplayInMenu: OnValidate branches on "Line Type"/"Page Type" and writes "Quick Edit/Action"
        // or clears Category/Order.
#pragma warning disable PC0037
        ServiceSetup.Editable := Editable;
        ServiceSetup.DisplayInMenu := true;
#pragma warning restore PC0037
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), MobileType);
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Function Type"), FunctionType);
        ServiceSetup.ValidateFunctionName(FunctionName, false);
        if Editable then
            this.EnsurePageUpdatable(ServiceName);
        if ValidationBehavior <> '' then
            this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Validation Behavior"), ValidationBehavior);
        ServiceSetup.Modify(true);
        exit(true);
    end;

    /// <summary>
    /// Makes a field visible and editable and renders it as a barcode-scannable control with
    /// the given validation behavior (MobileNAV vocabulary, for example 'ScanOrManualEntry';
    /// empty keeps the default). Values are resolved against the option members of the
    /// MobileNAV Service Setup fields, matching how MobileNAV's own config import writes them.
    /// </summary>
    /// <param name="ServiceName">MobileNAV service the field belongs to.</param>
    /// <param name="ControlName">Field's control name on the page.</param>
    /// <param name="MobileType">MobileNAV mobile control type option member name.</param>
    /// <param name="ValidationBehavior">MobileNAV Validation Behavior option member name; empty keeps the default.</param>
    /// <param name="Importance">MobileNAV Mandatory option member name; empty keeps MobileNAV's default.</param>
    /// <returns>True when the field was found and configured; false when it does not exist.</returns>
    procedure ConfigureScanField(ServiceName: Text[100]; ControlName: Text[100]; MobileType: Text[30]; ValidationBehavior: Text[50]; Importance: Text[30]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, true);
        // See ConfigureFunctionField: MobileNAV's Additional default would hide the scan control.
        if Importance <> '' then
            this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(Mandatory), Importance);
        // Editable: OnValidate silently reverts the value and shows a Message() when the underlying
        // field is not editable on the page or is a NoSeries field.
#pragma warning disable PC0037
        ServiceSetup.Editable := true;
#pragma warning restore PC0037
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), MobileType);
        if ValidationBehavior <> '' then
            this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Validation Behavior"), ValidationBehavior);
        ServiceSetup.Modify(true);
        exit(true);
    end;

    /// <summary>
    /// Resolves a MobileNAV option value by member name and assigns it without running
    /// validation, matching how MobileNAV's own config XML import writes option fields.
    /// Shared with the page and stage management codeunits.
    /// </summary>
    /// <param name="ServiceSetup">Record whose option field is set.</param>
    /// <param name="FieldNumber">Field number of the option field to set.</param>
    /// <param name="ValueName">Option member name to resolve and assign.</param>
    procedure SetOptionField(var ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer; ValueName: Text)
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
        Error(this.UnknownOptionValueErr, ValueName, OptionFieldRef.Caption());
    end;

    /// <summary>
    /// Scopes a page to the signed-in device user through MobileNAV's own "Mine" mechanism.
    ///
    /// The control is marked as the page's user identity (MobileType UserID) and a page-level
    /// filter with comparison Own is written over it. At config build time MobileNAV replaces
    /// Own with an equality against the MobileNAV user, so every device sees only its own
    /// rows. This is how a shared parameter table — one row per user — presents exactly one
    /// row on each device, which is also what makes a card over it uniquely resolvable.
    /// </summary>
    /// <param name="ServiceName">MobileNAV service the page is registered under.</param>
    /// <param name="ControlName">Control on the page carrying the user id.</param>
    /// <returns>True when the control exists and the scope was written.</returns>
    procedure ConfigureUserScope(ServiceName: Text[100]; ControlName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        FilterSetup: Record "MobileNAV Service Setup";
        IsNew: Boolean;
    begin
        if not this.FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        // The Own comparison only validates against a field whose MobileType names a per-user
        // value, so the identity mark goes on first.
        this.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), 'UserID');
        ServiceSetup.Modify(true);

        FilterSetup.SetRange("Object Type", ServiceSetup."Object Type");
        FilterSetup.SetRange("Service Name", ServiceSetup."Service Name");
        FilterSetup.SetRange("Line Type", FilterSetup."Line Type"::Filter);
        FilterSetup.SetRange("Page Line No.", 0);
        FilterSetup.SetRange("Relation No.", 0);
        FilterSetup.SetRange(SourceFieldName, ServiceSetup.FieldName);
        IsNew := not FilterSetup.FindFirst();

        if IsNew then begin
            FilterSetup.Init();
            FilterSetup.Validate("Object Type", ServiceSetup."Object Type");
            FilterSetup.Validate("Service Name", ServiceSetup."Service Name");
            FilterSetup.Validate("Line Type", FilterSetup."Line Type"::Filter);
            FilterSetup.Validate("Page Line No.", 0);
            FilterSetup.Validate("Relation No.", 0);
            FilterSetup.Validate("Line No.", 10000);
        end;

        // Object ID: OnValidate TestFields "Object Type" and calls RefreshPage(true).
        // FilterType: OnValidate clears the field names. "Filter Comparsion Type": OnValidate
        // silently reverts when the sibling field row's MobileType does not qualify — which the
        // UserID mark above guarantees it does, so direct assignment keeps this apply-safe.
#pragma warning disable PC0037
        FilterSetup."Object ID" := ServiceSetup."Object ID";
        FilterSetup.FilterType := FilterSetup.FilterType::FIELD;
        FilterSetup."Filter Comparsion Type" := FilterSetup."Filter Comparsion Type"::Own;
        FilterSetup.SourceFieldName := ServiceSetup.FieldName;
        FilterSetup.DestFieldName := ServiceSetup.FieldName;
        FilterSetup.FilterValue := '';
#pragma warning restore PC0037

        if IsNew then
            FilterSetup.Insert(true)
        else
            FilterSetup.Modify(true);
        exit(true);
    end;

    /// <summary>
    /// Ensures the page's Main row allows record updates. A field's Editable flag only takes
    /// effect on a page the device may write back to; with "Page Update" off the device draws
    /// every field read-only regardless of the field configuration, which silently undoes an
    /// editable declaration. Called whenever a field is configured editable.
    /// </summary>
    local procedure EnsurePageUpdatable(ServiceName: Text[100])
    var
        MainRow: Record "MobileNAV Service Setup";
    begin
        if not MainRow.Get(ServiceName, MainRow."Line Type"::Main) then
            exit;
        if MainRow."Page Update" then
            exit;
        MainRow.Validate("Page Update", true);
        MainRow.Modify(true);
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
            RelationSetup.Validate("Object Type", FieldSetup."Object Type");
            RelationSetup.Validate("Service Name", FieldSetup."Service Name");
            RelationSetup.Validate("Line Type", RelationSetup."Line Type"::Relation);
            RelationSetup.Validate("Page Line No.", FieldSetup."Page Line No.");
            RelationSetup.Validate("Relation No.", 1);
            RelationSetup.Validate("Line No.", 0);
        end;

        // Object ID (MobileNAV Service Setup): OnValidate TestFields "Object Type", can Error, and
        // calls RefreshPage(true) which rebuilds the page's whole field metadata.
#pragma warning disable PC0037
        RelationSetup."Object ID" := FieldSetup."Object ID";
#pragma warning restore PC0037
        RelationSetup.Validate(ControlID, FieldSetup.ControlID);
        RelationSetup.Validate(FieldName, FieldSetup.FieldName);
        // RelatedPageName: OnValidate can Error, and DeleteAlls child filter and propagated-field
        // rows when the value changes. "Related Table No.": OnValidate clears related-page fields
        // on every sibling field row of the service.
        //
        // RelatedPgCodeFldName is deliberately NOT set. It turns the relation from an action
        // button into a lookup binding — the control then renders as a code field showing the
        // related record's value, and an empty read-only lookup is not drawn at all, so the
        // device shows nothing where the button should be. Every one of MobileNAV's own
        // action-style relations leaves it blank; the filter rows alone carry the binding.
#pragma warning disable PC0037
        RelationSetup.RelatedPageName := TargetServiceName;
        RelationSetup."Related Table No." := RelatedTableNo;
        RelationSetup.RelatedPgCodeFldName := '';
#pragma warning restore PC0037

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
            FilterSetup.Validate("Object Type", FieldSetup."Object Type");
            FilterSetup.Validate("Service Name", FieldSetup."Service Name");
            FilterSetup.Validate("Line Type", FilterSetup."Line Type"::Filter);
            FilterSetup.Validate("Page Line No.", FieldSetup."Page Line No.");
            FilterSetup.Validate("Relation No.", 1);
            FilterSetup.Validate("Line No.", 10000);
        end;

        // Object ID (MobileNAV Service Setup): OnValidate TestFields "Object Type", can Error, and
        // calls RefreshPage(true) which rebuilds the page's whole field metadata.
#pragma warning disable PC0037
        FilterSetup."Object ID" := FieldSetup."Object ID";
#pragma warning restore PC0037
        FilterSetup.Validate(ControlID, FieldSetup.ControlID);
        FilterSetup.Validate(FieldName, FieldSetup.FieldName);
        // RelatedPageName: OnValidate can Error, and DeleteAlls child filter and propagated-field
        // rows when the value changes.
        // "Related Table No.": OnValidate clears related-page fields on every sibling field row of
        // the service.
        // FilterType: OnValidate clears DestFieldName/SourceFieldName/FilterValue.
        // "Filter Comparsion Type": OnValidate silently reverts the assignment if the sibling field
        // row does not match.
        // DestFieldName / SourceFieldName: OnValidate can Error on unmatched field names and
        // propagation-type conflicts.
#pragma warning disable PC0037
        FilterSetup.RelatedPageName := TargetServiceName;
        FilterSetup."Related Table No." := RelatedTableNo;
        FilterSetup.FilterType := FilterSetup.FilterType::FIELD;
        FilterSetup."Filter Comparsion Type" := FilterSetup."Filter Comparsion Type"::Equal;
        FilterSetup.DestFieldName := this.ConvertFieldName(TargetFilterField);
        FilterSetup.SourceFieldName := this.ConvertFieldName(SourceField);
#pragma warning restore PC0037

        if IsNew then
            FilterSetup.Insert(true)
        else
            FilterSetup.Modify(true);
    end;

    local procedure ConvertFieldName(OriginalName: Text): Text[75]
    begin
        exit(CopyStr(this.WebServiceHandling.ConvertFieldName(OriginalName), 1, 75));
    end;

    var
        PageManagement: Codeunit "BJF MN Page Mgt.";
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        TargetServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
        UnknownOptionValueErr: Label '%1 is not a valid value for %2 in this MobileNAV version.', Comment = '%1 = requested option value, %2 = field caption';
}

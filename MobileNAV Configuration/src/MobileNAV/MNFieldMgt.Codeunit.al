namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes a control's service-level configuration: field, button, scan input and the
/// per-user identity mark. Links and lookups are "BJF MN Relation Mgt.".
///
/// Several MobileNAV Service Setup fields are assigned directly rather than validated, on
/// purpose. Their OnValidate triggers are written for an administrator at the keyboard, not
/// for an unattended apply: Editable silently reverts and shows a Message; DisplayInMenu
/// rewrites Category and Order; "Visible as Filter" raises a Confirm and can delete sibling
/// rows; "Object ID" rebuilds the page's metadata. Each direct assignment is marked with a
/// PC0037 pragma.
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
    /// Marks the control as the page's user identity (MobileType UserID), the first half of
    /// MobileNAV's "Mine" mechanism; the page-level Own filter over it is written with the
    /// page's other filters by "BJF MN Filter Mgt.". MobileNAV replaces Own with an equality
    /// against the device user when it builds the configuration, so a shared per-user table
    /// shows exactly one row on each device.
    /// </summary>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureUserScope(ServiceName: Text[100]; ControlName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo(MobileType), this.UserIdMobileTypeTok);
        ServiceSetup.Modify(true);
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
    procedure EnsurePageUpdatable(ServiceName: Text[100])
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

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        Vocabulary: Codeunit "BJF MN Vocabulary";
        UserIdMobileTypeTok: Label 'UserID', Locked = true;
}

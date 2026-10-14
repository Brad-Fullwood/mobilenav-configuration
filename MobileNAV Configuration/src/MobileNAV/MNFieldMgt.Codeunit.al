namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes a control's service-level configuration: the field row of a plain field, function
/// field or scan field, the per-user identity mark and the page's Page Update flag. The field
/// settings come from the provider's property rows, written by "BJF MN Property Mgt.". Which
/// of them run OnValidate, and why the rest do not, is in the Validate column of
/// "BJF MN Property Catalog". Links and lookups are "BJF MN Relation Mgt.".
/// </summary>
codeunit 77789 "BJF MN Field Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = m;

    /// <summary>
    /// Configures a control's field row from the property rows the provider declares for it. The
    /// settings are written in Entry No. order, the function name is validated against the function
    /// type just written, the row is saved, and an editable control makes its page updatable.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ControlName">The control name on the page.</param>
    /// <param name="TempProperty">The provider's property rows, filtered to the page.</param>
    /// <param name="FunctionName">The page function the field calls. Empty leaves the function name alone.</param>
    /// <param name="MakePageUpdatable">True when the control is editable, so the page must accept writes.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureControl(ServiceName: Text[100]; ControlName: Text[100]; var TempProperty: Record "BJF MN Config Property" temporary; FunctionName: Text[50]; MakePageUpdatable: Boolean): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        this.PropertyManagement.SetControlSettings(ServiceName, TempProperty, ControlName, ServiceSetup);
        if FunctionName <> '' then
            ServiceSetup.ValidateFunctionName(FunctionName, false);
        ServiceSetup.Modify(true);
        if MakePageUpdatable then
            this.EnsurePageUpdatable(ServiceName);
        exit(true);
    end;

    /// <summary>
    /// Marks the control as the page's user identity (MobileType UserID), the first half of
    /// MobileNAV's "Mine" mechanism; the page-level Own filter over it is written with the
    /// page's other filters by "BJF MN Filter Mgt.". MobileNAV replaces Own with an equality
    /// against the device user when it builds the configuration, so a shared per-user table
    /// shows exactly one row on each device.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ControlName">The control name on the page.</param>
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
    /// Page Update gates whether the device may write anything back; with it off every field
    /// is drawn read-only regardless of its own configuration. A page confirmed updatable is
    /// remembered until ForgetUpdatablePages, so its Main row is read once per apply.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    procedure EnsurePageUpdatable(ServiceName: Text[100])
    var
        MainRow: Record "MobileNAV Service Setup";
    begin
        if this.UpdatableServices.Contains(ServiceName) then
            exit;
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            exit;
        if not MainRow."Page Update" then begin
            MainRow.Validate("Page Update", true);
            MainRow.Modify(true);
        end;
        this.UpdatableServices.Add(ServiceName);
    end;

    /// <summary>
    /// Forgets the pages EnsurePageUpdatable confirmed. Call it at the start of every apply: between
    /// applies the Main row can be rebuilt or rolled back, or an administrator can turn Page Update off.
    /// </summary>
    procedure ForgetUpdatablePages()
    begin
        Clear(this.UpdatableServices);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        PropertyManagement: Codeunit "BJF MN Property Mgt.";
        UpdatableServices: List of [Text];
        UserIdMobileTypeTok: Label 'UserID', Locked = true;
}

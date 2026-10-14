namespace BradFullwood.MobileNAV.Configuration;

using System.Apps;
using System.Integration;
using System.Reflection;

/// <summary>
/// The read-side of MobileNAV's service setup: how a page id, a service name and a control name
/// resolve to the rows MobileNAV keeps for them. Every other codeunit that needs a Main row, a
/// field row or an option member goes through here, so the resolution rules live in one place.
/// </summary>
codeunit 77778 "BJF MN Service Lookup"
{
    Access = Internal;
    Permissions = tabledata AllObjWithCaption = r,
        tabledata Field = r,
        tabledata "MobileNAV Service Setup" = r,
        tabledata "Tenant Web Service" = r;

    /// <summary>
    /// Whether MobileNAV holds any configuration in this company. MobileNAV's Setup Wizard imports
    /// the base configuration; until then there are no Main rows to declare pages against. The
    /// same test MobileNAV's own assisted setup uses.
    /// </summary>
    /// <returns>True when at least one Main row other than MobileNAV's key service exists.</returns>
    procedure HasConfiguration(): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        ServiceSetup.SetRange("System Object", false);
        ServiceSetup.SetFilter("Service Name", '<>%1', this.KeyServiceTok);
        exit(not ServiceSetup.IsEmpty());
    end;

    /// <summary>Finds the Main row of a service.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ServiceSetup">The MobileNAV Service Setup row.</param>
    /// <returns>True when the Main row was found.</returns>
    procedure FindMainRow(ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        this.FilterMainRow(ServiceName, ServiceSetup);
        exit(ServiceSetup.FindFirst());
    end;

    local procedure FilterMainRow(ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
    end;

    /// <summary>Finds the Main row of the service a page object is registered under.</summary>
    /// <param name="PageId">The page object ID.</param>
    /// <param name="ServiceSetup">The MobileNAV Service Setup row.</param>
    /// <returns>True when the Main row was found.</returns>
    procedure FindMainRowByPage(PageId: Integer; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        this.FilterMainRowByPage(PageId, ServiceSetup);
        exit(ServiceSetup.FindFirst());
    end;

    local procedure FilterMainRowByPage(PageId: Integer; var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
    end;

    /// <summary>The service name a page object is registered under; empty when it is not registered.</summary>
    /// <param name="PageId">The page object ID.</param>
    /// <returns>The service name, or empty when the page is not registered.</returns>
    procedure GetServiceName(PageId: Integer): Text[100]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        // Filtered here instead of through FindMainRowByPage, whose Reset would clear the load fields.
        this.FilterMainRowByPage(PageId, ServiceSetup);
        ServiceSetup.SetLoadFields("Service Name");
        if not ServiceSetup.FindFirst() then
            exit('');
        exit(ServiceSetup."Service Name");
    end;

    /// <summary>The page object registered under a service name; 0 when the service is not registered.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <returns>The page ID, or 0 when the service is not registered.</returns>
    procedure GetPageId(ServiceName: Text[100]): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.FilterMainRow(ServiceName, ServiceSetup);
        ServiceSetup.SetLoadFields("Object ID");
        if not ServiceSetup.FindFirst() then
            exit(0);
        exit(ServiceSetup."Object ID");
    end;

    /// <summary>
    /// Whether the page is one of MobileNAV's own. Its menu tiles and profile rows belong to the
    /// MobileNAV administrator, so publishing it does not take them over.
    /// </summary>
    /// <param name="PageId">The page object ID.</param>
    /// <returns>True when the page belongs to the MobileNAV app.</returns>
    procedure IsMobileNAVPage(PageId: Integer): Boolean
    var
        AllObj: Record AllObj;
        PackageId: Guid;
    begin
        AllObj.SetLoadFields("App Runtime Package ID", "App Package ID");
        if not AllObj.Get(AllObj."Object Type"::Page, PageId) then
            exit(false);
        PackageId := this.MobileNAVPackageId();
        if IsNullGuid(PackageId) then
            exit(false);
        exit((AllObj."App Runtime Package ID" = PackageId) or (AllObj."App Package ID" = PackageId));
    end;

    // The package id of the installed MobileNAV app, read once per instance of this codeunit. A null id means MobileNAV is not installed.
    local procedure MobileNAVPackageId(): Guid
    var
        InstalledApp: Record "NAV App Installed App";
        MobileNAVAppId: Guid;
    begin
        if this.MobileNAVPackageIdRead then
            exit(this.CachedMobileNAVPackageId);
        Evaluate(MobileNAVAppId, this.MobileNAVAppIdTok);
        InstalledApp.SetLoadFields("Package ID");
        InstalledApp.SetRange("App ID", MobileNAVAppId);
        if InstalledApp.FindFirst() then
            this.CachedMobileNAVPackageId := InstalledApp."Package ID";
        this.MobileNAVPackageIdRead := true;
        exit(this.CachedMobileNAVPackageId);
    end;

    /// <summary>
    /// Whether a registered page is the app's own, as opposed to one MobileNAV ships: MobileNAV's
    /// pages are named MobileNAV ... and have ids from 42010000 to 42019999. Unlike IsMobileNAVPage,
    /// this reads only the name and id stored on the Main row.
    /// </summary>
    /// <param name="PageName">The page name on the Main row.</param>
    /// <param name="PageId">The page object ID.</param>
    /// <returns>True when the page is the app's own.</returns>
    procedure IsOwnServicePage(PageName: Text; PageId: Integer): Boolean
    begin
        if PageName.StartsWith(this.MobileNAVPagePrefixTok) then
            exit(false);
        exit((PageId < 42010000) or (PageId >= 42020000));
    end;

    /// <summary>The name of the codeunit published as a web service under a service name; empty when there is none.</summary>
    /// <param name="WebServiceName">The web service name.</param>
    /// <returns>The codeunit's object name.</returns>
    procedure CodeunitNameOfService(WebServiceName: Text): Text
    var
        TenantWebService: Record "Tenant Web Service";
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        TenantWebService.SetLoadFields("Object ID");
        if not TenantWebService.Get(TenantWebService."Object Type"::Codeunit, CopyStr(WebServiceName, 1, MaxStrLen(TenantWebService."Service Name"))) then
            exit('');
        exit(this.ObjectNameOf(AllObjWithCaption."Object Type"::Codeunit, TenantWebService."Object ID"));
    end;

    /// <summary>The name of a table field; empty when the field does not exist.</summary>
    /// <param name="SourceTableNo">The table number.</param>
    /// <param name="SourceFieldNo">The field number.</param>
    /// <returns>The field name.</returns>
    procedure FieldNameOf(SourceTableNo: Integer; SourceFieldNo: Integer): Text
    var
        TableField: Record Field;
    begin
        TableField.SetLoadFields(FieldName);
        if not TableField.Get(SourceTableNo, SourceFieldNo) then
            exit('');
        exit(TableField.FieldName);
    end;

#pragma warning disable LC0088 // Takes the Object Type option of AllObjWithCaption.
    /// <summary>The name of an object; empty when the object does not exist.</summary>
    /// <param name="ObjectType">The object type, as AllObjWithCaption's Object Type.</param>
    /// <param name="ObjectId">The object ID.</param>
    /// <returns>The object name.</returns>
    procedure ObjectNameOf(ObjectType: Option; ObjectId: Integer): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        AllObjWithCaption.SetLoadFields("Object Name");
        if not AllObjWithCaption.Get(ObjectType, ObjectId) then
            exit('');
        exit(AllObjWithCaption."Object Name");
    end;
#pragma warning restore LC0088

    /// <summary>The services whose fields MobileNAV relates to the given service, the pages a device opens it from.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <returns>The service names that relate to the given service.</returns>
    procedure RelationSources(ServiceName: Text[100]) Sources: List of [Text]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Relation);
        ServiceSetup.SetRange(RelatedPageName, CopyStr(ServiceName, 1, MaxStrLen(ServiceSetup.RelatedPageName)));
        ServiceSetup.SetFilter("Service Name", '<>%1', ServiceName);
        ServiceSetup.SetLoadFields("Service Name");
        if ServiceSetup.FindSet() then
            repeat
                if not Sources.Contains(ServiceSetup."Service Name") then
                    Sources.Add(ServiceSetup."Service Name");
            until ServiceSetup.Next() = 0;
        exit(Sources);
    end;

    /// <summary>The source table of a service; false when the service is not registered.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="TableNo">Returns the source table number.</param>
    /// <returns>True when the service is registered.</returns>
    procedure GetServiceTableNo(ServiceName: Text[100]; var TableNo: Integer): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.FilterMainRow(ServiceName, ServiceSetup);
        ServiceSetup.SetLoadFields("Table No.");
        if not ServiceSetup.FindFirst() then
            exit(false);
        TableNo := ServiceSetup."Table No.";
        exit(true);
    end;

    /// <summary>Finds the service-level field row for a page control, by the name MobileNAV stores it under.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ControlName">The control name on the page.</param>
    /// <param name="ServiceSetup">The MobileNAV Service Setup row.</param>
    /// <returns>True when the field row was found.</returns>
    procedure FindFieldRow(ServiceName: Text[100]; ControlName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.SetRange(FieldName, this.StoredFieldName(ControlName));
        exit(ServiceSetup.FindFirst());
    end;

    /// <summary>The name MobileNAV stores a page control under in its field rows.</summary>
    /// <param name="ControlName">The control name on the page.</param>
    /// <returns>The stored field name.</returns>
    procedure StoredFieldName(ControlName: Text): Text[75]
    begin
        exit(CopyStr(this.WebServiceHandling.ConvertFieldName(ControlName), 1, 75));
    end;

    /// <summary>
    /// Assigns an option field by member name, the way MobileNAV's own configuration import
    /// does. Resolving by name means this app never carries MobileNAV's option lists.
    /// </summary>
    /// <param name="ServiceSetup">The MobileNAV Service Setup row.</param>
    /// <param name="FieldNumber">The MobileNAV Service Setup field number.</param>
    /// <param name="ValueName">The option member name.</param>
    procedure SetOptionField(var ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer; ValueName: Text)
    var
        SetupRecordRef: RecordRef;
    begin
        SetupRecordRef.GetTable(ServiceSetup);
        this.SetOption(SetupRecordRef, FieldNumber, ValueName);
        SetupRecordRef.SetTable(ServiceSetup);
    end;

    /// <summary>Assigns an option field of any MobileNAV table by member name.</summary>
    /// <param name="TargetRef">The record that holds the field.</param>
    /// <param name="FieldNumber">The option field number.</param>
    /// <param name="ValueName">The option member name.</param>
    procedure SetOption(var TargetRef: RecordRef; FieldNumber: Integer; ValueName: Text)
    var
        OptionFieldRef: FieldRef;
    begin
        OptionFieldRef := TargetRef.Field(FieldNumber);
        this.SetOptionMember(OptionFieldRef, ValueName);
    end;

    /// <summary>Assigns an option field by member name.</summary>
    /// <param name="OptionFieldRef">The option field to read or assign.</param>
    /// <param name="ValueName">The option member name.</param>
    procedure SetOptionMember(var OptionFieldRef: FieldRef; ValueName: Text)
    var
        MemberIndex: Integer;
    begin
        for MemberIndex := 1 to OptionFieldRef.EnumValueCount() do
            if UpperCase(OptionFieldRef.GetEnumValueName(MemberIndex)) = UpperCase(ValueName) then begin
                OptionFieldRef.Value(OptionFieldRef.GetEnumValueOrdinal(MemberIndex));
                exit;
            end;
        Error(this.UnknownOptionValueErr, ValueName, OptionFieldRef.Caption());
    end;

    /// <summary>The member name of an option field's current value.</summary>
    /// <param name="ServiceSetup">The MobileNAV Service Setup row.</param>
    /// <param name="FieldNumber">The MobileNAV Service Setup field number.</param>
    /// <returns>The option member name.</returns>
    procedure OptionName(ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer): Text
    var
        SetupRecordRef: RecordRef;
    begin
        SetupRecordRef.GetTable(ServiceSetup);
        exit(this.OptionName(SetupRecordRef, FieldNumber));
    end;

    /// <summary>The member name of the current value of an option field of any MobileNAV table.</summary>
    /// <param name="TargetRef">The record that holds the field.</param>
    /// <param name="FieldNumber">The option field number.</param>
    /// <returns>The option member name, or empty when the value has no member.</returns>
    procedure OptionName(var TargetRef: RecordRef; FieldNumber: Integer): Text
    begin
        exit(this.OptionName(TargetRef.Field(FieldNumber)));
    end;

    /// <summary>The member name of an option field's current value.</summary>
    /// <param name="OptionFieldRef">The option field.</param>
    /// <returns>The option member name, or empty when the value has no member.</returns>
    procedure OptionName(OptionFieldRef: FieldRef): Text
    var
        Ordinal: Integer;
        MemberIndex: Integer;
    begin
        Ordinal := OptionFieldRef.Value();
        for MemberIndex := 1 to OptionFieldRef.EnumValueCount() do
            if OptionFieldRef.GetEnumValueOrdinal(MemberIndex) = Ordinal then
                exit(OptionFieldRef.GetEnumValueName(MemberIndex));
        exit('');
    end;

    var
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        CachedMobileNAVPackageId: Guid;
        MobileNAVPackageIdRead: Boolean;
        KeyServiceTok: Label 'MobileNAVKey', Locked = true;
        MobileNAVPagePrefixTok: Label 'MobileNAV ', Locked = true;
        MobileNAVAppIdTok: Label 'fd09b53c-ff32-4d9c-91ce-6a82a87b8c9c', Locked = true;
        UnknownOptionValueErr: Label '%1 is not a valid value for %2 in this MobileNAV version.', Comment = '%1 = requested option value, %2 = field caption';
}

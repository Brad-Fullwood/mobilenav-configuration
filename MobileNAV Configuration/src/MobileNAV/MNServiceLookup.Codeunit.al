namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The read-side of MobileNAV's service setup: how a page id, a service name and a control name
/// resolve to the rows MobileNAV keeps for them. Every other codeunit that needs a Main row, a
/// field row or an option member goes through here, so the resolution rules live in one place.
/// </summary>
codeunit 77778 "BJF MN Service Lookup"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    /// <summary>Finds the Main row of a service.</summary>
    procedure FindMainRow(ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        exit(ServiceSetup.FindFirst());
    end;

    /// <summary>Finds the Main row of the service a page object is registered under.</summary>
    procedure FindMainRowByPage(PageId: Integer; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        exit(ServiceSetup.FindFirst());
    end;

    /// <summary>The service name a page object is registered under; empty when it is not registered.</summary>
    procedure GetServiceName(PageId: Integer): Text[100]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindMainRowByPage(PageId, ServiceSetup) then
            exit('');
        exit(ServiceSetup."Service Name");
    end;

    /// <summary>The page object registered under a service name; 0 when the service is not registered.</summary>
    procedure GetPageId(ServiceName: Text[100]): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindMainRow(ServiceName, ServiceSetup) then
            exit(0);
        exit(ServiceSetup."Object ID");
    end;

    /// <summary>The source table of a service; false when the service is not registered.</summary>
    procedure GetServiceTableNo(ServiceName: Text[100]; var TableNo: Integer): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.FindMainRow(ServiceName, ServiceSetup) then
            exit(false);
        TableNo := ServiceSetup."Table No.";
        exit(true);
    end;

    /// <summary>Finds the service-level field row for a page control, by the name MobileNAV stores it under.</summary>
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
    procedure StoredFieldName(ControlName: Text): Text[75]
    begin
        exit(CopyStr(this.WebServiceHandling.ConvertFieldName(ControlName), 1, 75));
    end;

    /// <summary>
    /// Assigns an option field by member name, the way MobileNAV's own configuration import
    /// does. Resolving by name means this app never carries MobileNAV's option lists.
    /// </summary>
    procedure SetOptionField(var ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer; ValueName: Text)
    var
        SetupRecordRef: RecordRef;
        OptionFieldRef: FieldRef;
    begin
        SetupRecordRef.GetTable(ServiceSetup);
        OptionFieldRef := SetupRecordRef.Field(FieldNumber);
        this.SetOptionMember(OptionFieldRef, ValueName);
        SetupRecordRef.SetTable(ServiceSetup);
    end;

    /// <summary>Assigns an option field by member name.</summary>
    procedure SetOptionMember(var OptionFieldRef: FieldRef; ValueName: Text)
    var
        MemberIndex: Integer;
    begin
        for MemberIndex := 1 to OptionFieldRef.EnumValueCount() do
            if UpperCase(OptionFieldRef.GetEnumValueName(MemberIndex)) = UpperCase(ValueName) then begin
                OptionFieldRef.Value := OptionFieldRef.GetEnumValueOrdinal(MemberIndex);
                exit;
            end;
        Error(this.UnknownOptionValueErr, ValueName, OptionFieldRef.Caption());
    end;

    /// <summary>The member name of an option field's current value.</summary>
    procedure OptionName(ServiceSetup: Record "MobileNAV Service Setup"; FieldNumber: Integer): Text
    var
        SetupRecordRef: RecordRef;
        OptionFieldRef: FieldRef;
        Ordinal: Integer;
        MemberIndex: Integer;
    begin
        SetupRecordRef.GetTable(ServiceSetup);
        OptionFieldRef := SetupRecordRef.Field(FieldNumber);
        Ordinal := OptionFieldRef.Value();
        for MemberIndex := 1 to OptionFieldRef.EnumValueCount() do
            if OptionFieldRef.GetEnumValueOrdinal(MemberIndex) = Ordinal then
                exit(OptionFieldRef.GetEnumValueName(MemberIndex));
        exit('');
    end;

    var
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        UnknownOptionValueErr: Label '%1 is not a valid value for %2 in this MobileNAV version.', Comment = '%1 = requested option value, %2 = field caption';
}

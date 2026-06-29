namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>
/// Public, idempotent operations for configuring MobileNAV from AL.
/// Consumers keep their app-specific setup in separate setup-module codeunits.
/// </summary>
codeunit 77780 "BJF MobileNAV Configurator"
{
    Permissions = tabledata "MobileNAV Service Setup" = rim,
        tabledata "Tenant Web Service" = rim;

    /// <summary>
    /// Publishes a page as a tenant web service, or repairs the page id and published state
    /// of an existing service with the same name.
    /// </summary>
    procedure PublishPageWebService(PageId: Integer; ServiceName: Text[240])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        CheckPageId(PageId);
        CheckServiceName(ServiceName);

        if not TenantWebService.Get(TenantWebService."Object Type"::Page, ServiceName) then begin
            TenantWebService.Init();
            TenantWebService."Object Type" := TenantWebService."Object Type"::Page;
            TenantWebService."Object ID" := PageId;
            TenantWebService."Service Name" := ServiceName;
            TenantWebService.Published := true;
            TenantWebService.Insert(true);
            exit;
        end;

        if (TenantWebService."Object ID" = PageId) and TenantWebService.Published then
            exit;

        TenantWebService."Object ID" := PageId;
        TenantWebService.Published := true;
        TenantWebService.Modify(true);
    end;

    /// <summary>
    /// Ensures a page has a MobileNAV Main row and refreshes its metadata. If the page is
    /// already registered under another service name, that existing name is retained.
    /// </summary>
    procedure EnsurePage(PageId: Integer; PreferredServiceName: Text[100]; var ServiceName: Text[100])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        CheckPageId(PageId);
        CheckServiceName(PreferredServiceName);

        if not FindMainPage(PageId, ServiceSetup) then begin
            ServiceSetup.Init();
            ServiceSetup."Object Type" := ServiceSetup."Object Type"::Page;
            ServiceSetup."Object ID" := PageId;
            ServiceSetup."Service Name" := PreferredServiceName;
            ServiceSetup."Line Type" := ServiceSetup."Line Type"::Main;
            ServiceSetup.Insert(true);
        end;

        RefreshPageMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
    end;

    /// <summary>
    /// Ensures a page has a MobileNAV Main row, refreshes its metadata, and publishes the
    /// page using the actual MobileNAV service name.
    /// </summary>
    procedure EnsurePublishedPage(PageId: Integer; PreferredServiceName: Text[100]; var ServiceName: Text[100])
    begin
        EnsurePage(PageId, PreferredServiceName, ServiceName);
        PublishPageWebService(PageId, ServiceName);
    end;

    /// <summary>
    /// Refreshes metadata for an existing MobileNAV page registration.
    /// Returns false when the page has not been registered in MobileNAV.
    /// </summary>
    procedure RefreshConfiguredPage(PageId: Integer; var ServiceName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        CheckPageId(PageId);

        if not FindMainPage(PageId, ServiceSetup) then
            exit(false);

        RefreshPageMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
        exit(true);
    end;

    /// <summary>
    /// Makes a metadata field visible in MobileNAV and explicitly sets its editability.
    /// Returns false when the field was not found after metadata refresh.
    /// </summary>
    procedure ShowField(ServiceName: Text[100]; ControlName: Text; Editable: Boolean): Boolean
    begin
        exit(ConfigureField(ServiceName, ControlName, true, Editable, true));
    end;

    /// <summary>
    /// Applies the supplied visibility, editability, and menu settings to a metadata field.
    /// Returns false when the field was not found.
    /// </summary>
    procedure ConfigureField(ServiceName: Text[100]; ControlName: Text; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        CheckServiceName(ServiceName);
        if ControlName = '' then
            Error(ControlNameRequiredErr);

        if not FindField(ServiceName, ControlName, ServiceSetup) then
            exit(false);

        ServiceSetup.Validate(Visible, Visible);
        ServiceSetup.Editable := Editable;
        ServiceSetup.DisplayInMenu := DisplayInMenu;
        ServiceSetup.Modify(true);
        exit(true);
    end;

    /// <summary>
    /// Makes a field visible and upserts a single-field open-page relation and filter.
    /// Returns false when the source field was not found. The target page must already have
    /// a MobileNAV Main row, normally created by EnsurePage().
    /// </summary>
    procedure ShowLinkedField(ServiceName: Text[100]; ControlName: Text; TargetServiceName: Text[75]; TargetFilterField: Text; SourceField: Text): Boolean
    var
        FieldSetup: Record "MobileNAV Service Setup";
        RelatedTableNo: Integer;
    begin
        CheckServiceName(ServiceName);
        CheckServiceName(TargetServiceName);
        if ControlName = '' then
            Error(ControlNameRequiredErr);
        if TargetFilterField = '' then
            Error(TargetFilterFieldRequiredErr);
        if SourceField = '' then
            Error(SourceFieldRequiredErr);

        if not FindField(ServiceName, ControlName, FieldSetup) then
            exit(false);
        if not GetServiceTableNo(TargetServiceName, RelatedTableNo) then
            Error(TargetServiceMissingErr, TargetServiceName);

        FieldSetup.Validate(Visible, true);
        FieldSetup.DisplayInMenu := true;
        FieldSetup.Modify(true);

        UpsertRelation(FieldSetup, TargetServiceName, TargetFilterField, RelatedTableNo);
        UpsertFieldFilter(FieldSetup, TargetServiceName, TargetFilterField, SourceField, RelatedTableNo);
        exit(true);
    end;

    /// <summary>Returns MobileNAV's normalized representation of an AL control or field name.</summary>
    procedure ConvertFieldName(OriginalName: Text): Text[75]
    begin
        exit(CopyStr(WebServiceHandling.ConvertFieldName(OriginalName), 1, 75));
    end;

    local procedure RefreshPageMetadata(var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        MetadataProcessing.RefreshPageByMetadata(ServiceSetup, true, '');
        CoreFunctions.AddMissingFlowFilters(ServiceSetup."Service Name");
        CoreFunctions.SetZeroFieldOrder(ServiceSetup."Service Name");
        ServiceSetup.Modify(true);
    end;

    local procedure FindMainPage(PageId: Integer; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        exit(ServiceSetup.FindFirst());
    end;

    local procedure FindField(ServiceName: Text[100]; ControlName: Text; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.SetRange(FieldName, ConvertFieldName(ControlName));
        exit(ServiceSetup.FindFirst());
    end;

    local procedure GetServiceTableNo(ServiceName: Text[100]; var TableNo: Integer): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        ServiceSetup.SetLoadFields("Table No.");
        if not ServiceSetup.FindFirst() then
            exit(false);

        TableNo := ServiceSetup."Table No.";
        exit(true);
    end;

    local procedure UpsertRelation(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[75]; TargetFilterField: Text; RelatedTableNo: Integer)
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
        RelationSetup.RelatedPgCodeFldName := ConvertFieldName(TargetFilterField);

        if IsNew then
            RelationSetup.Insert(true)
        else
            RelationSetup.Modify(true);
    end;

    local procedure UpsertFieldFilter(FieldSetup: Record "MobileNAV Service Setup"; TargetServiceName: Text[75]; TargetFilterField: Text; SourceField: Text; RelatedTableNo: Integer)
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
        FilterSetup.DestFieldName := ConvertFieldName(TargetFilterField);
        FilterSetup.SourceFieldName := ConvertFieldName(SourceField);

        if IsNew then
            FilterSetup.Insert(true)
        else
            FilterSetup.Modify(true);
    end;

    local procedure CheckPageId(PageId: Integer)
    begin
        if PageId <= 0 then
            Error(PageIdRequiredErr);
    end;

    local procedure CheckServiceName(ServiceName: Text)
    begin
        if ServiceName = '' then
            Error(ServiceNameRequiredErr);
    end;

    var
        MetadataProcessing: Codeunit "MobileNAV Metadata Processing";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        PageIdRequiredErr: Label 'A positive page object id is required.';
        ServiceNameRequiredErr: Label 'A service name is required.';
        ControlNameRequiredErr: Label 'A control name is required.';
        TargetFilterFieldRequiredErr: Label 'A target filter field is required.';
        SourceFieldRequiredErr: Label 'A source field is required.';
        TargetServiceMissingErr: Label 'MobileNAV service %1 is not registered. Call EnsurePage before configuring a link to it.', Comment = '%1 = MobileNAV service name';
}

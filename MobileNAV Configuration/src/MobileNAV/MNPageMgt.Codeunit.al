namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>
/// Registers pages with MobileNAV, publishes the web services devices call, and opens and
/// closes MobileNAV's construction window around an apply.
/// </summary>
codeunit 77788 "BJF MN Page Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = rm,
        tabledata "MobileNAV Service Setup" = rim,
        tabledata "Tenant Web Service" = rim;

    /// <summary>
    /// Registers the page under the preferred service name and refreshes its metadata. MobileNAV
    /// allows one service per page object: its metadata refresh renames the Main row back to the
    /// existing service, so a second name over an already registered page does not survive.
    /// </summary>
    /// <param name="ServiceName">Returns the service name the page is registered under.</param>
    procedure EnsurePage(PageId: Integer; PreferredServiceName: Text[100]; var ServiceName: Text[100])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if this.Lookup.FindMainRow(PreferredServiceName, ServiceSetup) then begin
            if ServiceSetup."Object ID" <> PageId then
                Error(this.ServiceNameTakenErr, PreferredServiceName, ServiceSetup."Object ID", PageId);
        end else begin
            ServiceSetup.Init();
            ServiceSetup.Validate("Object Type", ServiceSetup."Object Type"::Page);
            // Object ID's OnValidate rebuilds the page's metadata; RefreshMetadata does that once.
#pragma warning disable PC0037
            ServiceSetup."Object ID" := PageId;
#pragma warning restore PC0037
            ServiceSetup.Validate("Service Name", PreferredServiceName);
            ServiceSetup.Validate("Line Type", ServiceSetup."Line Type"::Main);
            ServiceSetup.Insert(true);
        end;

        this.RefreshMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
    end;

    /// <summary>Refreshes the metadata of a page MobileNAV already knows.</summary>
    /// <param name="ServiceName">Returns the service name the page is registered under.</param>
    procedure RefreshConfiguredPage(PageId: Integer; var ServiceName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindMainRowByPage(PageId, ServiceSetup) then
            exit(false);
        this.RefreshMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
        exit(true);
    end;

    /// <summary>Publishes the page web service devices open the page through.</summary>
    procedure PublishPage(PageId: Integer; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        this.EnsureWebService(TenantWebService."Object Type"::Page, PageId, ServiceName, true);
    end;

    /// <summary>
    /// Registers the companion codeunit web service a page's buttons are called through.
    /// MobileNAV's SOAP transport calls a page's functions on a codeunit service registered under
    /// the page's own service name, resolving to MobileNAV's Page Functions codeunit, and its
    /// config generator only marks the functions callable when that registration exists. Without
    /// it the button renders but every tap fails on the device with 'Method "…" is invalid!'.
    /// MobileNAV's own import creates the registration unpublished; existence is what counts.
    /// </summary>
    procedure PublishFunctionCompanion(ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        this.EnsureWebService(TenantWebService."Object Type"::Codeunit, Codeunit::"MobileNAV Page Functions", ServiceName, false);
    end;

    /// <summary>
    /// Publishes the codeunit a dialog page's buttons run through. Unlike the companion this one
    /// is called directly over OData as ServiceName_Procedure, so it must be published.
    /// </summary>
    procedure PublishFunctionService(CodeunitId: Integer; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        this.EnsureWebService(TenantWebService."Object Type"::Codeunit, CodeunitId, ServiceName, true);
    end;

    /// <summary>
    /// Points a dialog page at the codeunit service its buttons run through. MobileNAV keeps the
    /// name in the Main row's OptionValues2; empty means its own report-function codeunit.
    /// </summary>
    procedure SetReportService(ServiceName: Text[100]; ReportServiceName: Text[100])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainRow(ServiceName, ServiceSetup);
#pragma warning disable PC0037
        ServiceSetup.OptionValues2 := CopyStr(ReportServiceName, 1, MaxStrLen(ServiceSetup.OptionValues2));
#pragma warning restore PC0037
        ServiceSetup.Modify(true);
    end;

    /// <summary>
    /// Sets the MobileNAV page type. A link renders as a toolbar action only when its target is a
    /// Report-type page (MobileNAV's action dialog); a link to a List page becomes a lookup
    /// binding, which an empty read-only card does not draw.
    /// </summary>
    /// <param name="PageType">MobileNAV Page Type member name, for example 'Report'.</param>
    procedure SetPageType(ServiceName: Text[100]; PageType: Text[30])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainRow(ServiceName, ServiceSetup);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Page Type"), PageType);
        ServiceSetup.Modify(true);
    end;

    /// <param name="ActionName">MobileNAV Main Menu Action member name: 'Create' or 'Open'.</param>
    procedure SetMainMenuAction(ServiceName: Text[100]; ActionName: Text[30])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainRow(ServiceName, ServiceSetup);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Main Menu Action"), ActionName);
        ServiceSetup.Modify(true);
    end;

    /// <summary>
    /// Turns the page into a staged wizard. Enable Staging is validated so MobileNAV propagates
    /// it to the existing profile rows.
    /// </summary>
    /// <param name="StagingBehavior">MobileNAV Staging Behavior member name; empty keeps Always.</param>
    procedure SetStaging(ServiceName: Text[100]; AutoNext: Boolean; BackNextVisible: Boolean; StagingBehavior: Text[30])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainRow(ServiceName, ServiceSetup);
        ServiceSetup.Validate("Enable Staging", true);
        if StagingBehavior = '' then
            ServiceSetup.Validate("Staging Behavior", ServiceSetup."Staging Behavior"::Always)
        else
            this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Staging Behavior"), StagingBehavior);
        ServiceSetup.Validate("Auto Next Stage", AutoNext);
        ServiceSetup.Validate("Back-Next Visible", BackNextVisible);
        ServiceSetup.Modify(true);
    end;

    /// <summary>
    /// Opens MobileNAV's construction window. MobileNAV only carries configuration through to
    /// devices for changes made inside it; writes made outside land in the setup tables and
    /// stop there.
    /// </summary>
    procedure BeginConfigurationChange()
    begin
        if GuiAllowed() then
            this.SetConstructionWindow(true);
    end;

    /// <summary>
    /// Hands the applied configuration to MobileNAV: rebuilds the profile hierarchy, regenerates
    /// the page templates devices render from, tells devices to reload, and closes the window.
    /// MobileNAV's routines can confirm with the user, so this only runs in a session with a
    /// client; install and upgrade have none and leave the handover to an administrator.
    /// </summary>
    /// <returns>True when the handover ran; false when there was no session to run it in.</returns>
    procedure PublishConfigurationToDevices(): Boolean
    begin
        if not GuiAllowed() then
            exit(false);
        this.CoreFunctions.SetPageHierarchyChanged();
        this.CoreFunctions.SetEnforcedMajorConfigChanged();
        this.CoreFunctions.RunPostConfigurationProcess();
        this.SetConstructionWindow(false);
        exit(true);
    end;

    /// <summary>
    /// Creates the web service, or corrects the object it points at. A service that is already
    /// published is never unpublished.
    /// </summary>
    local procedure EnsureWebService(ObjectType: Option; ObjectId: Integer; ServiceName: Text[100]; Publish: Boolean)
    var
        TenantWebService: Record "Tenant Web Service";
        IsNew: Boolean;
    begin
        IsNew := not TenantWebService.Get(ObjectType, ServiceName);
        if not IsNew and this.WebServiceIsCorrect(TenantWebService, ObjectId, Publish) then
            exit;

        // Tenant Web Service is a platform table; Insert/Modify(true) run its triggers.
#pragma warning disable PC0037
        if IsNew then begin
            TenantWebService.Init();
            TenantWebService."Object Type" := ObjectType;
            TenantWebService."Service Name" := ServiceName;
        end;
        TenantWebService."Object ID" := ObjectId;
        TenantWebService.Published := TenantWebService.Published or Publish;
#pragma warning restore PC0037
        if IsNew then
            TenantWebService.Insert(true)
        else
            TenantWebService.Modify(true);
    end;

    /// <summary>An existing registration already points at the object and is published if required.</summary>
    local procedure WebServiceIsCorrect(TenantWebService: Record "Tenant Web Service"; ObjectId: Integer; Publish: Boolean): Boolean
    begin
        exit((TenantWebService."Object ID" = ObjectId) and (TenantWebService.Published or not Publish));
    end;

    local procedure SetConstructionWindow(Open: Boolean)
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then
            exit;
        if MasterData."Under Construction" = Open then
            exit;
        // Under Construction's OnValidate starts or stops a background job and clears the change
        // flags on its own; the flags are managed explicitly here instead.
#pragma warning disable PC0037
        MasterData."Under Construction" := Open;
#pragma warning restore PC0037
        if not Open then begin
            MasterData.Validate("Page Hierarchy Changed", false);
            MasterData.Validate("Enforced Major Config Change", false);
        end;
        MasterData.Modify(false);
    end;

    local procedure GetMainRow(ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        if not this.Lookup.FindMainRow(ServiceName, ServiceSetup) then
            Error(this.ServiceMissingErr, ServiceName);
    end;

    local procedure RefreshMetadata(var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        this.MetadataProcessing.RefreshPageByMetadata(ServiceSetup, true, '');
        this.CoreFunctions.AddMissingFlowFilters(ServiceSetup."Service Name");
        this.CoreFunctions.SetZeroFieldOrder(ServiceSetup."Service Name");
        ServiceSetup.Modify(true);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        MetadataProcessing: Codeunit "MobileNAV Metadata Processing";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
        ServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
        ServiceNameTakenErr: Label 'MobileNAV service %1 is registered for page %2, so page %3 cannot be published under that name.', Comment = '%1 = service name, %2 = registered page id, %3 = requested page id';
}

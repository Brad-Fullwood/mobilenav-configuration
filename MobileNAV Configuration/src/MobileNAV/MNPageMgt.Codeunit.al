namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;
using System.Reflection;

/// <summary>
/// Registers pages with MobileNAV, publishes the web services devices call, and opens and
/// closes MobileNAV's construction window around an apply.
/// </summary>
codeunit 77788 "BJF MN Page Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = rm,
        tabledata "MobileNAV Service Setup" = im,
        tabledata "Tenant Web Service" = rim;

    /// <summary>Publishes declared endpoints without refreshing metadata. The caller must commit before WSDL reads.</summary>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <returns>True when any web service was created or changed.</returns>
    procedure PublishDeclaredServices(var TempLine: Record "BJF MN Config Line" temporary) Changed: Boolean
    begin
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempLine.FindSet() then
            repeat
                if this.PublishDeclaredLine(TempLine) then
                    Changed := true;
            until TempLine.Next() = 0;
        TempLine.Reset();
        exit(Changed);
    end;

    /// <summary>Publishes one Published Page line: the page, then its function companion when it declares one.</summary>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <returns>True when a web service was created or changed.</returns>
    local procedure PublishDeclaredLine(var TempLine: Record "BJF MN Config Line" temporary) Changed: Boolean
    var
        TenantWebService: Record "Tenant Web Service";
        ServiceName: Text[100];
    begin
        ServiceName := this.ResolvePublicationName(TempLine."Page ID", TempLine."Service Name");
        Changed := this.EnsureWebService(TenantWebService."Object Type"::Page, TempLine."Page ID", ServiceName, true);
        if TempLine."Function Codeunit ID" = 0 then
            exit(Changed);
        if this.PublishDeclaredCompanion(TempLine, ServiceName) then
            Changed := true;
        exit(Changed);
    end;

    /// <summary>A report companion is published under its own service name, any other under the page's.</summary>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <returns>True when a web service was created or changed.</returns>
    local procedure PublishDeclaredCompanion(var TempLine: Record "BJF MN Config Line" temporary; ServiceName: Text[100]): Boolean
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        if TempLine."Report Service Name" = '' then
            exit(this.EnsureWebService(TenantWebService."Object Type"::Codeunit, TempLine."Function Codeunit ID", ServiceName, false, true));
        exit(this.EnsureWebService(TenantWebService."Object Type"::Codeunit, TempLine."Function Codeunit ID", TempLine."Report Service Name", true));
    end;

    local procedure ResolvePublicationName(PageId: Integer; PreferredServiceName: Text[100]): Text[100]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if this.Lookup.FindMainRow(PreferredServiceName, ServiceSetup) then
            if ServiceSetup."Object ID" <> PageId then
                Error(this.ServiceNameTakenErr, PreferredServiceName, ServiceSetup."Object ID", PageId);
        // MobileNAV supports one Main service per page and refresh resolves this same row.
        // Reuse it before publication rather than creating a second endpoint alias.
        if this.Lookup.FindMainRowByPage(PageId, ServiceSetup) then
            exit(ServiceSetup."Service Name");
        exit(PreferredServiceName);
    end;

    /// <summary>
    /// Registers the page under the preferred service name and refreshes its metadata. MobileNAV
    /// allows one service per page object: its metadata refresh renames the Main row back to the
    /// existing service, so a second name over an already registered page does not survive.
    /// </summary>
    /// <param name="PageId">The page object ID.</param>
    /// <param name="PreferredServiceName">The service name to register the page under when it has none yet.</param>
    /// <param name="ServiceName">Returns the service name the page is registered under.</param>
    procedure EnsurePage(PageId: Integer; PreferredServiceName: Text[100]; var ServiceName: Text[100])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        PreferredServiceName := this.ResolvePublicationName(PageId, PreferredServiceName);
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
    /// <param name="PageId">The page object ID.</param>
    /// <param name="ServiceName">Returns the service name the page is registered under.</param>
    /// <returns>True when the page is registered and was refreshed.</returns>
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
    /// <param name="PageId">The page object ID.</param>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
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
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    procedure PublishFunctionCompanion(ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        this.EnsureWebService(TenantWebService."Object Type"::Codeunit, Codeunit::"MobileNAV Page Functions", ServiceName, false);
    end;

    /// <summary>
    /// Registers the standard companion for a page: MobileNAV Page Functions, or "BJF MN Table
    /// Functions" for a table Page Functions does not serve. The second may replace a Page
    /// Functions registration, which has nothing to offer that page.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="CompanionCodeunitId">The ID of the companion codeunit.</param>
    procedure PublishStandardCompanion(ServiceName: Text[100]; CompanionCodeunitId: Integer)
    var
        TenantWebService: Record "Tenant Web Service";
        ReplacesPageFunctions: Boolean;
    begin
        TenantWebService.SetLoadFields("Object ID");
        if CompanionCodeunitId = Codeunit::"BJF MN Table Functions" then
            if TenantWebService.Get(TenantWebService."Object Type"::Codeunit, ServiceName) then
                ReplacesPageFunctions := TenantWebService."Object ID" = Codeunit::"MobileNAV Page Functions";
        this.EnsureWebService(TenantWebService."Object Type"::Codeunit, CompanionCodeunitId, ServiceName, false, ReplacesPageFunctions);
    end;

    /// <summary>Registers a custom unpublished companion under its page's service name.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="CodeunitId">The ID of the companion codeunit.</param>
    procedure PublishFunctionCompanion(ServiceName: Text[100]; CodeunitId: Integer)
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        // Replaces MobileNAV's standard same-name companion when the provider declares its own.
        this.EnsureWebService(TenantWebService."Object Type"::Codeunit, CodeunitId, ServiceName, false, true);
    end;

    /// <summary>
    /// Publishes the codeunit a dialog page's buttons run through. Unlike the companion this one
    /// is called directly over OData as ServiceName_Procedure, so it must be published.
    /// </summary>
    /// <param name="CodeunitId">The ID of the companion codeunit.</param>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
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
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ReportServiceName">The service name for the report companion.</param>
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
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="PageType">MobileNAV Page Type member name, for example 'Report'.</param>
    procedure SetPageType(ServiceName: Text[100]; PageType: Text[30])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainRow(ServiceName, ServiceSetup);
        this.Lookup.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Page Type"), PageType);
        ServiceSetup.Modify(true);
    end;

    /// <summary>Shows or hides the page's tile on the device home menu.</summary>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="Show">True to list the page on the home menu.</param>
    procedure SetDisplayInMenu(ServiceName: Text[100]; Show: Boolean)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainRow(ServiceName, ServiceSetup);
        if ServiceSetup.DisplayInMenu = Show then
            exit;
        ServiceSetup.Validate(DisplayInMenu, Show);
        ServiceSetup.Modify(true);
    end;

    /// <summary>Sets what tapping the page's menu tile does.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
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
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="AutoNext">Whether stages advance on their own.</param>
    /// <param name="BackNextVisible">Whether the Back and Next buttons show.</param>
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
    /// <param name="Unattended">True when the caller has no client but will run the handover (the API).</param>
    procedure BeginConfigurationChange(Unattended: Boolean)
    begin
        if GuiAllowed() or Unattended then
            this.SetConstructionWindow(true);
    end;

    /// <summary>Closes the construction window as the device handover would. Used by the preview, which skips the handover.</summary>
    internal procedure EndConfigurationChangeWithoutHandover()
    begin
        this.SetConstructionWindow(false);
    end;

    /// <summary>
    /// Hands the applied configuration to MobileNAV: rebuilds the profile hierarchy, regenerates
    /// the page templates devices render from, tells devices to reload, and closes the window.
    /// MobileNAV's routines can confirm with the user, so this only runs in a session with a
    /// client, or unattended (the API) where a refusal closes the window and is kept in
    /// LastHandoverError. Install and upgrade are neither and leave the handover to an administrator.
    /// Unattended commits the applied rows before the handover runs.
    /// </summary>
    /// <param name="Unattended">True when the caller has no client but wants the handover run anyway.</param>
    /// <returns>True when the handover ran; false when it was skipped or refused.</returns>
    procedure PublishConfigurationToDevices(Unattended: Boolean): Boolean
    begin
        this.HandoverError := '';
        if GuiAllowed() then begin
            this.HandOverToDevices();
            exit(true);
        end;
        if not Unattended then
            exit(false);
        Commit(); // Codeunit.Run with a return value needs a committed transaction; the applied rows are kept if the handover is refused.
        if Codeunit.Run(Codeunit::"BJF MN Device Handover") then
            exit(true);
        this.HandoverError := GetLastErrorText();
        this.SetConstructionWindow(false);
        exit(false);
    end;

    /// <summary>
    /// Rebuilds the profile hierarchy and page templates, tells devices to reload, and closes the
    /// window. MobileNAV's per-user rebuild refuses to run while its background refresh and trigger
    /// subscription job queue entries are Ready ("Status must be equal to 'On Hold' in Job Queue
    /// Entry"), so the jobs are put on hold first and released after, as MobileNAV's own
    /// configuration page does.
    /// </summary>
    procedure HandOverToDevices()
    begin
        this.OfflineFunctions.StopBackgroundJQ();
        this.OfflineFunctions.StopByTriggerJQ();
        this.CoreFunctions.SetPageHierarchyChanged();
        this.CoreFunctions.SetEnforcedMajorConfigChanged();
        this.CoreFunctions.RunPostConfigurationProcess();
        this.OfflineFunctions.StartBackgroundJQ();
        this.OfflineFunctions.StartByTriggerJQ();
        this.SetConstructionWindow(false);
    end;

    /// <summary>The error MobileNAV raised when the last unattended handover was refused.</summary>
    /// <returns>The error text, or empty when the handover ran or was not attempted.</returns>
    procedure LastHandoverError(): Text
    begin
        exit(this.HandoverError);
    end;

#pragma warning disable LC0088 // Mirrors the Object Type option of Tenant Web Service.
    /// <summary>
    /// Creates or publishes the web service; rejects names owned by another object.
    /// A service that is already published is never unpublished. Returns whether it changed.
    /// </summary>
    /// <param name="ObjectType">The Tenant Web Service object type.</param>
    /// <param name="ObjectId">The ID of the object the service points at.</param>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Publish">True to publish the service.</param>
    /// <returns>True when the web service was created or changed.</returns>
    local procedure EnsureWebService(ObjectType: Option; ObjectId: Integer; ServiceName: Text[100]; Publish: Boolean): Boolean
    begin
        exit(this.EnsureWebService(ObjectType, ObjectId, ServiceName, Publish, false));
    end;

    /// <summary>Creates or updates a web service, optionally replacing a page's function companion.</summary>
    /// <param name="ObjectType">The Tenant Web Service object type.</param>
    /// <param name="ObjectId">The ID of the object the service points at.</param>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Publish">True to publish the service.</param>
    /// <param name="AllowObjectChange">True to let the registration point at a different object.</param>
    /// <returns>True when the web service was created or changed.</returns>
    local procedure EnsureWebService(ObjectType: Option; ObjectId: Integer; ServiceName: Text[100]; Publish: Boolean; AllowObjectChange: Boolean): Boolean
    var
        TenantWebService: Record "Tenant Web Service";
        IsNew: Boolean;
    begin
        IsNew := not TenantWebService.Get(ObjectType, ServiceName);
        if not IsNew and not AllowObjectChange then
            this.ErrorIfRegisteredToOtherObject(TenantWebService, ObjectType, ObjectId, ServiceName);
        if not IsNew and this.WebServiceIsCorrect(TenantWebService, ObjectId, Publish) then
            exit(false);
        if this.PreviewRecorder.IsActive() then
            this.PreviewRecorder.WebServiceChanged(ServiceName, this.WebServiceObjectTypeName(ObjectType), IsNew,
                TenantWebService."Object ID", ObjectId, TenantWebService.Published, TenantWebService.Published or Publish);
        this.WriteWebService(TenantWebService, IsNew, ObjectType, ObjectId, ServiceName, Publish);
        exit(true);
    end;

    local procedure ErrorIfRegisteredToOtherObject(TenantWebService: Record "Tenant Web Service"; ObjectType: Option; ObjectId: Integer; ServiceName: Text[100])
    begin
        if TenantWebService."Object ID" <> ObjectId then
            Error(this.ServiceConflictErr, ServiceName, this.WebServiceObjectTypeName(ObjectType), TenantWebService."Object ID",
                this.RegisteredObjectName(ObjectType, TenantWebService."Object ID"), ObjectId, this.RegisteredObjectName(ObjectType, ObjectId));
    end;

    local procedure WriteWebService(var TenantWebService: Record "Tenant Web Service"; IsNew: Boolean; ObjectType: Option; ObjectId: Integer; ServiceName: Text[100]; Publish: Boolean)
    begin
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

    local procedure WebServiceObjectTypeName(ObjectType: Option): Text
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        if ObjectType = TenantWebService."Object Type"::Codeunit then
            exit(this.CodeunitTok);
        exit(this.PageTok);
    end;

    local procedure RegisteredObjectName(ObjectType: Option; ObjectId: Integer): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
        TenantWebService: Record "Tenant Web Service";
    begin
        if ObjectType = TenantWebService."Object Type"::Codeunit then
            exit(this.Lookup.ObjectNameOf(AllObjWithCaption."Object Type"::Codeunit, ObjectId));
        exit(this.Lookup.ObjectNameOf(AllObjWithCaption."Object Type"::Page, ObjectId));
    end;
#pragma warning restore LC0088

    /// <summary>An existing registration already points at the object and is published if required.</summary>
    /// <param name="TenantWebService">The Tenant Web Service row.</param>
    /// <param name="ObjectId">The ID of the object the service points at.</param>
    /// <param name="Publish">True to publish the service.</param>
    /// <returns>True when no change is needed.</returns>
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
        OfflineFunctions: Codeunit "MobileNAV Offline Functions";
        PreviewRecorder: Codeunit "BJF MN Preview Recorder";
        HandoverError: Text;
        CodeunitTok: Label 'Codeunit', Locked = true;
        PageTok: Label 'Page', Locked = true;
        ServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
        ServiceConflictErr: Label 'Web service %1 (%2) already points at object %3 %4, and this configuration needs it to point at %5 %6. Another app or an administrator registered it, so the apply leaves it alone. If %3 does not serve these buttons, run the MobileNAV Doctor and apply its fix to repoint the service. If it does, declare PageFunctions(%3) on the page.', Comment = '%1 = service name, %2 = object type, %3 = current object id, %4 = current object name, %5 = needed object id, %6 = needed object name';
        ServiceNameTakenErr: Label 'MobileNAV service %1 is registered for page %2, so page %3 cannot be published under that name.', Comment = '%1 = service name, %2 = registered page id, %3 = requested page id';
}

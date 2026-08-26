
namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>Owns MobileNAV page registration, publication, lookup, and metadata refresh.</summary>
codeunit 77788 "BJF MN Page Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rim,
        tabledata "MobileNAV Master Data" = rm,
        tabledata "Tenant Web Service" = rim;

    procedure PublishPage(PageId: Integer; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
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
    /// Registers the page under the preferred service name and refreshes its metadata. The
    /// lookup is keyed on page id AND service name so a mismatch is caught here rather than
    /// silently adopting an existing row. Note that MobileNAV allows only ONE service per
    /// page object: RefreshPageByMetadata resolves the service name from the page object id
    /// and renames the Main row to it, so declaring a second service over a page that already
    /// has one does not survive the refresh — to reshape a stock page, target its existing
    /// service name.
    /// </summary>
    procedure EnsurePage(PageId: Integer; PreferredServiceName: Text[100]; var ServiceName: Text[100])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not FindMainPageByService(PageId, PreferredServiceName, ServiceSetup) then begin
            ServiceSetup.Init();
            ServiceSetup."Object Type" := ServiceSetup."Object Type"::Page;
            ServiceSetup."Object ID" := PageId;
            ServiceSetup."Service Name" := PreferredServiceName;
            ServiceSetup."Line Type" := ServiceSetup."Line Type"::Main;
            ServiceSetup.Insert(true);
        end;

        this.RefreshMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
    end;

    procedure RefreshConfiguredPage(PageId: Integer; var ServiceName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not FindMainPage(PageId, ServiceSetup) then
            exit(false);

        this.RefreshMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
        exit(true);
    end;

    procedure GetServiceTableNo(ServiceName: Text[100]; var TableNo: Integer): Boolean
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

    local procedure FindMainPage(PageId: Integer; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        exit(ServiceSetup.FindFirst());
    end;

    local procedure FindMainPageByService(PageId: Integer; ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup"): Boolean
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        exit(ServiceSetup.FindFirst());
    end;

    /// <summary>Sets the page's main menu action ('Create' or 'Open', MobileNAV vocabulary).</summary>
    procedure SetMainMenuAction(ServiceName: Text[100]; ActionName: Text[30])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainPageByService(ServiceName, ServiceSetup);
        FieldManagement.SetOptionField(ServiceSetup, ServiceSetup.FieldNo("Main Menu Action"), ActionName);
        ServiceSetup.Modify(true);
    end;

    /// <summary>
    /// Turns the page into a staged wizard. Enable Staging is validated (not assigned) so
    /// MobileNAV propagates the flag to existing profile rows; staging behavior is fixed to
    /// 'Always from scratch', which restarts the wizard on every record.
    /// </summary>
    procedure SetStaging(ServiceName: Text[100]; AutoNext: Boolean; BackNextVisible: Boolean)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        this.GetMainPageByService(ServiceName, ServiceSetup);
        ServiceSetup.Validate("Enable Staging", true);
        ServiceSetup."Staging Behavior" := ServiceSetup."Staging Behavior"::Always;
        ServiceSetup."Auto Next Stage" := AutoNext;
        ServiceSetup."Back-Next Visible" := BackNextVisible;
        ServiceSetup.Modify(true);
    end;

    local procedure GetMainPageByService(ServiceName: Text[100]; var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if not ServiceSetup.FindFirst() then
            Error(ServiceMissingErr, ServiceName);
    end;

    /// <summary>
    /// Opens MobileNAV's construction window before the configuration is written. MobileNAV
    /// only carries configuration through to devices for changes made inside this window: its
    /// post-configuration process is a no-op while the window is closed, so changes written
    /// outside it reach the setup tables and stop there.
    /// </summary>
    procedure BeginConfigurationChange()
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not GuiAllowed() then
            exit;
        if not MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then
            exit;
        if MasterData."Under Construction" then
            exit;

        MasterData."Under Construction" := true;
        MasterData.Modify(false);
    end;

    /// <summary>
    /// Hands the applied configuration over to MobileNAV so it reaches devices. Writing the
    /// service setup rows is not enough on its own: users log in against a profile, and a
    /// newly configured field only appears on a device once the profile hierarchy has been
    /// rebuilt to include it, MobileNAV has regenerated the configuration it derives from
    /// the setup tables, and devices have been told to reload rather than reuse the
    /// configuration they already hold.
    ///
    /// MobileNAV does this work through routines that can confirm with the user, so they only
    /// run in a session that has a client to answer them. Install and upgrade have none, and
    /// a confirmation raised there fails the whole deployment, so the handover is skipped and
    /// left for an administrator to complete from the administration page.
    /// </summary>
    /// <returns>True when the handover ran; false when there was no session to run it in.</returns>
    procedure PublishConfigurationToDevices(): Boolean
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not GuiAllowed() then
            exit(false);
        if not MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then
            exit(false);

        // Flag what changed, then run the post-configuration process while the window is
        // still open. It rebuilds the profile hierarchy so the new fields reach the profiles
        // users log in against, and regenerates the page templates devices render from —
        // without that regeneration a device keeps drawing its previous version of the page.
        CoreFunctions.SetPageHierarchyChanged();
        CoreFunctions.SetEnforcedMajorConfigChanged();
        CoreFunctions.RunPostConfigurationProcess();

        // Close the window and clear the flags it consumed, as MobileNAV does when an
        // administrator turns construction off by hand.
        MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal);
        MasterData."Under Construction" := false;
        MasterData."Page Hierarchy Changed" := false;
        MasterData."Enforced Major Config Change" := false;
        MasterData.Modify(false);
        exit(true);
    end;

    local procedure RefreshMetadata(var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        MetadataProcessing.RefreshPageByMetadata(ServiceSetup, true, '');
        CoreFunctions.AddMissingFlowFilters(ServiceSetup."Service Name");
        CoreFunctions.SetZeroFieldOrder(ServiceSetup."Service Name");
        ServiceSetup.Modify(true);
    end;

    var
        MetadataProcessing: Codeunit "MobileNAV Metadata Processing";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        ServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = MobileNAV service name';
}

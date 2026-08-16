
namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>Owns MobileNAV page registration, publication, lookup, and metadata refresh.</summary>
codeunit 77788 "BJF MN Page Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rim,
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

    procedure EnsurePage(PageId: Integer; PreferredServiceName: Text[100]; var ServiceName: Text[100])
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not FindMainPage(PageId, ServiceSetup) then begin
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
    begin
        if not GuiAllowed() then
            exit(false);

        CoreFunctions.RebuildProfileHierarchy();
        CoreFunctions.RunPostConfigurationProcess();
        CoreFunctions.SetEnforcedMajorConfigChanged();
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
}

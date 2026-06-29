#if BJF_MN_CONFIG_SOURCE
namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>Owns tenant web-service publication only.</summary>
codeunit 77787 "BJF MN Web Service Mgt."
{
    Access = Internal;
    Permissions = tabledata "Tenant Web Service" = rim;

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
}
#endif

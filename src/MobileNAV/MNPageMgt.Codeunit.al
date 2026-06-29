namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Owns MobileNAV page registration, lookup, and metadata refresh.</summary>
codeunit 77788 "BJF MN Page Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rim;

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

        RefreshMetadata(ServiceSetup);
        ServiceName := ServiceSetup."Service Name";
    end;

    procedure RefreshConfiguredPage(PageId: Integer; var ServiceName: Text[100]): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not FindMainPage(PageId, ServiceSetup) then
            exit(false);

        RefreshMetadata(ServiceSetup);
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

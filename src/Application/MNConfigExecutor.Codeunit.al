namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Executes a validated definition in deterministic dependency order.</summary>
codeunit 77786 "BJF MN Config Executor"
{
    Access = Internal;

    procedure Execute(var ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        PageServices: Dictionary of [Integer, Text];
    begin
        PreparePublishedPages(ConfigurationLine, PageServices);
        PrepareReferencedPages(ConfigurationLine, PageServices);
        ApplyFields(ConfigurationLine, PageServices);
        ApplyLinkedFields(ConfigurationLine, PageServices);
        ConfigurationLine.Reset();
    end;

    local procedure PreparePublishedPages(var ConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if ConfigurationLine.FindSet() then
            repeat
                PageManagement.EnsurePage(
                    ConfigurationLine."Page ID", ConfigurationLine."Service Name", ServiceName);
                WebServiceManagement.PublishPage(ConfigurationLine."Page ID", ServiceName);
                PageServices.Add(ConfigurationLine."Page ID", ServiceName);
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure PrepareReferencedPages(var ConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Field);
        if ConfigurationLine.FindSet() then
            repeat
                ResolvePage(ConfigurationLine."Page ID", PageServices);
            until ConfigurationLine.Next() = 0;

        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Linked Field");
        if ConfigurationLine.FindSet() then
            repeat
                ResolvePage(ConfigurationLine."Page ID", PageServices);
                ResolvePage(ConfigurationLine."Target Page ID", PageServices);
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure ApplyFields(var ConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Field);
        if ConfigurationLine.FindSet() then
            repeat
                PageServices.Get(ConfigurationLine."Page ID", ServiceName);
                if not FieldManagement.ConfigureField(
                    CopyStr(ServiceName, 1, 100), ConfigurationLine."Control Name",
                    ConfigurationLine.Visible, ConfigurationLine.Editable,
                    ConfigurationLine."Display In Menu")
                then
                    Error(FieldMissingErr, ConfigurationLine."Control Name", ServiceName);
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure ApplyLinkedFields(var ConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
        TargetServiceName: Text;
    begin
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Linked Field");
        if ConfigurationLine.FindSet() then
            repeat
                PageServices.Get(ConfigurationLine."Page ID", ServiceName);
                PageServices.Get(ConfigurationLine."Target Page ID", TargetServiceName);
                if not FieldManagement.ConfigureLinkedField(
                    CopyStr(ServiceName, 1, 100), ConfigurationLine."Control Name",
                    CopyStr(TargetServiceName, 1, 75), ConfigurationLine."Target Filter Field",
                    ConfigurationLine."Source Field")
                then
                    Error(FieldMissingErr, ConfigurationLine."Control Name", ServiceName);
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure ResolvePage(PageId: Integer; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        if PageServices.ContainsKey(PageId) then
            exit;
        if not PageManagement.RefreshConfiguredPage(PageId, ServiceName) then
            Error(PageMissingErr, PageId);
        PageServices.Add(PageId, ServiceName);
    end;

    var
        PageManagement: Codeunit "BJF MN Page Mgt.";
        WebServiceManagement: Codeunit "BJF MN Web Service Mgt.";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        PageMissingErr: Label 'Page %1 has not been registered in MobileNAV.', Comment = '%1 = page object id';
        FieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 after metadata refresh.', Comment = '%1 = control name, %2 = MobileNAV service name';
}

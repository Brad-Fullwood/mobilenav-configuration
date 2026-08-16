namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Validates and applies one provider definition in deterministic dependency order,
/// then records success in the same transaction.
/// </summary>
codeunit 77784 "BJF MN Config Application"
{
    Permissions = tabledata "BJF MN Config Status" = rim;

    procedure ApplyProvider(ProviderType: Enum "BJF MN Config Provider")
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        ConfigurationBuilder: Codeunit "BJF MN Config Builder";
        Provider: Interface "BJF MN Config Provider";
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ProviderVersion: Integer;
        DeviceHandoverCompleted: Boolean;
    begin
        ProviderCatalog.GetMetadata(
            ProviderType, ProviderId, ProviderName, ProviderDescription, ProviderVersion);

        Provider := ProviderType;
        Provider.DefineConfiguration(ConfigurationBuilder);
        ConfigurationBuilder.GetLines(TempConfigurationLine);

        ConfigurationValidator.Validate(TempConfigurationLine);
        DeviceHandoverCompleted := this.Execute(TempConfigurationLine);
        ConfigurationStatus.RecordApplied(
            ProviderId, ProviderName, ProviderVersion, not DeviceHandoverCompleted);
    end;

    local procedure Execute(var TempConfigurationLine: Record "BJF MN Config Line" temporary) DeviceHandoverCompleted: Boolean
    var
        PageServices: Dictionary of [Integer, Text];
    begin
        // MobileNAV only carries configuration through to devices for changes made while its
        // construction window is open, so the whole apply runs inside one.
        PageManagement.BeginConfigurationChange();
        this.PreparePublishedPages(TempConfigurationLine, PageServices);
        this.PrepareReferencedPages(TempConfigurationLine, PageServices);
        this.ApplyFields(TempConfigurationLine, PageServices);
        this.ApplyFunctionFields(TempConfigurationLine, PageServices);
        this.ApplyScanFields(TempConfigurationLine, PageServices);
        this.ApplyLinkedFields(TempConfigurationLine, PageServices);
        // Staging runs last: the per-field stage masks span every visible field row, so all
        // field configuration must be in place before the masks are written.
        this.ApplyStaging(TempConfigurationLine, PageServices);
        TempConfigurationLine.Reset();
        exit(PageManagement.PublishConfigurationToDevices());
    end;

    local procedure PreparePublishedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                PageManagement.EnsurePage(
                    TempConfigurationLine."Page ID", TempConfigurationLine."Service Name", ServiceName);
                PageManagement.PublishPage(TempConfigurationLine."Page ID", ServiceName);
                if TempConfigurationLine."Main Menu Action" <> '' then
                    PageManagement.SetMainMenuAction(ServiceName, TempConfigurationLine."Main Menu Action");
                PageServices.Add(TempConfigurationLine."Page ID", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure PrepareReferencedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetFilter(Operation, '<>%1', Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                ResolvePage(TempConfigurationLine."Page ID", PageServices);
                if TempConfigurationLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
                    ResolvePage(TempConfigurationLine."Target Page ID", PageServices);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Field);
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                if not FieldManagement.ConfigureField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine.Visible, TempConfigurationLine.Editable,
                    TempConfigurationLine."Display In Menu")
                then
                    Error(FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyFunctionFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Function Field");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                if not FieldManagement.ConfigureFunctionField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine.Editable,
                    TempConfigurationLine."Mobile Type", TempConfigurationLine."Function Name",
                    TempConfigurationLine."Function Type", TempConfigurationLine."Validation Behavior")
                then
                    Error(FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyScanFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Scan Field");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                if not FieldManagement.ConfigureScanField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine."Mobile Type", TempConfigurationLine."Validation Behavior")
                then
                    Error(FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyStaging(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        StagedPageIds: List of [Integer];
        ServiceName: Text;
        PageId: Integer;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
        if TempConfigurationLine.FindSet() then
            repeat
                StagedPageIds.Add(TempConfigurationLine."Page ID");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();

        // ApplyPageStaging refilters the shared temporary record, so the page ids are
        // collected first rather than iterated in place.
        foreach PageId in StagedPageIds do begin
            PageServices.Get(PageId, ServiceName);
            StageManagement.ApplyPageStaging(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
        end;
    end;

    local procedure ApplyLinkedFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
        TargetServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Linked Field");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                PageServices.Get(TempConfigurationLine."Target Page ID", TargetServiceName);
                if not FieldManagement.ConfigureLinkedField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    CopyStr(TargetServiceName, 1, 75), TempConfigurationLine."Target Filter Field",
                    TempConfigurationLine."Source Field")
                then
                    Error(FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
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
        ConfigurationStatus: Record "BJF MN Config Status";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationValidator: Codeunit "BJF MN Config Validator";
        PageManagement: Codeunit "BJF MN Page Mgt.";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        PageMissingErr: Label 'Page %1 has not been registered in MobileNAV.', Comment = '%1 = page object id';
        FieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 after metadata refresh.', Comment = '%1 = control name, %2 = MobileNAV service name';
}

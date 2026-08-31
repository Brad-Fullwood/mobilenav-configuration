namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Validates and applies one provider definition in deterministic dependency order,
/// then records success in the same transaction.
/// </summary>
codeunit 77784 "BJF MN Config Application"
{
    /// <summary>Validates the given provider's declared configuration, applies it, and records that it was applied.</summary>
    /// <param name="ProviderType">The configuration provider to validate and apply.</param>
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
        this.ProviderCatalog.GetMetadata(
            ProviderType, ProviderId, ProviderName, ProviderDescription, ProviderVersion);

        Provider := ProviderType;
        Provider.DefineConfiguration(ConfigurationBuilder);
        ConfigurationBuilder.GetLines(TempConfigurationLine);

        this.ConfigurationValidator.Validate(TempConfigurationLine);
        DeviceHandoverCompleted := this.Execute(TempConfigurationLine);
        this.ConfigurationStatus.RecordApplied(
            ProviderId, ProviderName, ProviderVersion, not DeviceHandoverCompleted);
    end;

    local procedure Execute(var TempConfigurationLine: Record "BJF MN Config Line" temporary): Boolean
    var
        PageServices: Dictionary of [Integer, Text];
    begin
        // MobileNAV only carries configuration through to devices for changes made while its
        // construction window is open, so the whole apply runs inside one.
        this.PageManagement.BeginConfigurationChange();
        this.PreparePublishedPages(TempConfigurationLine, PageServices);
        this.PrepareReferencedPages(TempConfigurationLine, PageServices);
        this.ApplyFields(TempConfigurationLine, PageServices);
        this.ApplyFunctionFields(TempConfigurationLine, PageServices);
        this.ApplyScanFields(TempConfigurationLine, PageServices);
        this.ApplyLinkedFields(TempConfigurationLine, PageServices);
        this.ApplyUserScopes(TempConfigurationLine, PageServices);
        // Profile rows override the service-level field rows on the device, so they are written
        // after every field operation and read the Control IDs those operations settled.
        this.ApplyProfilePages(TempConfigurationLine, PageServices);
        // After the pages exist in the profiles, and before the field rows: a linked field's
        // target has to be reachable from the page the control sits on or the control is not
        // drawn at all. See "BJF MN Profile Mgt.".LinkPageToParent.
        this.ApplyProfilePageParents(TempConfigurationLine, PageServices);
        this.ApplyProfileFields(TempConfigurationLine, PageServices);
        // Staging runs last: the per-field stage masks span every visible field row, so all
        // field configuration must be in place before the masks are written.
        this.ApplyStaging(TempConfigurationLine, PageServices);
        TempConfigurationLine.Reset();
        exit(this.PageManagement.PublishConfigurationToDevices());
    end;

    local procedure PreparePublishedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                this.PageManagement.EnsurePage(
                    TempConfigurationLine."Page ID", TempConfigurationLine."Service Name", ServiceName);
                this.PageManagement.PublishPage(TempConfigurationLine."Page ID", ServiceName);
                if TempConfigurationLine."Page Type" <> '' then
                    this.PageManagement.SetPageType(ServiceName, CopyStr(TempConfigurationLine."Page Type", 1, 30));
                if TempConfigurationLine."Main Menu Action" <> '' then
                    this.PageManagement.SetMainMenuAction(ServiceName, TempConfigurationLine."Main Menu Action");
                PageServices.Add(TempConfigurationLine."Page ID", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure PrepareReferencedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetFilter(Operation, '<>%1', Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                this.ResolvePage(TempConfigurationLine."Page ID", PageServices);
                if TempConfigurationLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
                    this.ResolvePage(TempConfigurationLine."Target Page ID", PageServices);
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
                if not this.FieldManagement.ConfigureField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine.Visible, TempConfigurationLine.Editable,
                    TempConfigurationLine."Display In Menu", TempConfigurationLine.Importance,
                    TempConfigurationLine.Filterable)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
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
                if not this.FieldManagement.ConfigureFunctionField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine.Editable,
                    TempConfigurationLine."Mobile Type", TempConfigurationLine."Function Name",
                    TempConfigurationLine."Function Type", TempConfigurationLine."Validation Behavior",
                    TempConfigurationLine.Importance)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
                // Without the companion registration the button renders but every tap dies
                // client-side as 'Method "…" is invalid!'. See PublishFunctionCompanion.
                this.PageManagement.PublishFunctionCompanion(CopyStr(ServiceName, 1, 100));
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
                if not this.FieldManagement.ConfigureScanField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine."Mobile Type", TempConfigurationLine."Validation Behavior",
                    TempConfigurationLine.Importance)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyUserScopes(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"User Scope");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                if not this.FieldManagement.ConfigureUserScope(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name")
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>
    /// Clears the profile exclusion on every page this plan touches.
    ///
    /// A page MobileNAV does not collect for a user is not merely absent: it also force-hides
    /// any control whose job is to open it, because a relation button is only drawn when its
    /// target page is among the collected pages. Running this for every page in the plan means a
    /// declared page and the control that opens it cannot disagree. See "BJF MN Profile Mgt.".
    /// </summary>
    local procedure ApplyProfilePages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        // Only the pages this plan publishes. A provider that publishes a page is asking for it
        // to be usable, whereas the other pages here are MobileNAV's own and already belong to
        // whichever profiles their administrator chose.
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                this.ProfileManagement.IncludePageInProfiles(CopyStr(ServiceName, 1, 100), '');
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>
    /// Makes every linked field's target page a child of the page the control sits on.
    ///
    /// Declaring a linked field is a statement that the control opens the target from this
    /// page, and MobileNAV only draws such a control once the target is reachable from that
    /// page in the profile hierarchy. Deriving the hierarchy from the links the provider
    /// already declared keeps the two from disagreeing.
    /// </summary>
    local procedure ApplyProfilePageParents(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ParentService: Text;
        ChildService: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Linked Field");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ParentService);
                PageServices.Get(TempConfigurationLine."Target Page ID", ChildService);
                this.ProfileManagement.LinkPageToParent(
                    CopyStr(ChildService, 1, 100), CopyStr(ParentService, 1, 100), '');
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyProfileFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Field");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                if not this.ProfileManagement.ConfigureProfileField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine.Profile,
                    TempConfigurationLine.Visible, TempConfigurationLine.Editable)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
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
            this.StageManagement.ApplyPageStaging(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
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
                if not this.FieldManagement.ConfigureLinkedField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    CopyStr(TargetServiceName, 1, 75), TempConfigurationLine."Target Filter Field",
                    TempConfigurationLine."Source Field", TempConfigurationLine.Importance)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ResolvePage(PageId: Integer; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        if PageServices.ContainsKey(PageId) then
            exit;
        if not this.PageManagement.RefreshConfiguredPage(PageId, ServiceName) then
            Error(this.PageMissingErr, PageId);
        PageServices.Add(PageId, ServiceName);
    end;

    var
        ConfigurationStatus: Record "BJF MN Config Status";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationValidator: Codeunit "BJF MN Config Validator";
        PageManagement: Codeunit "BJF MN Page Mgt.";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        ProfileManagement: Codeunit "BJF MN Profile Mgt.";
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        PageMissingErr: Label 'Page %1 has not been registered in MobileNAV.', Comment = '%1 = page object id';
        FieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 after metadata refresh.', Comment = '%1 = control name, %2 = MobileNAV service name';
}

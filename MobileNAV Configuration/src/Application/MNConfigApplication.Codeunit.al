namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Validates and applies one provider definition in deterministic dependency order,
/// then records success — with the definition's fingerprint — in the same transaction.
/// </summary>
codeunit 77784 "BJF MN Config Application"
{
    Access = Public;

    /// <summary>Validates the given provider's declared configuration, applies it, and records that it was applied.</summary>
    /// <param name="ProviderType">The configuration provider to validate and apply.</param>
    procedure ApplyProvider(ProviderType: Enum "BJF MN Config Provider")
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ContentHash: Text[64];
        DeviceHandoverCompleted: Boolean;
    begin
        this.ProviderCatalog.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        this.ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
        ContentHash := this.ConfigurationHash.Compute(TempConfigurationLine, TempConfigurationProperty);

        this.ConfigurationValidator.Validate(TempConfigurationLine, TempConfigurationProperty);
        DeviceHandoverCompleted := this.Execute(TempConfigurationLine, TempConfigurationProperty);
        this.ConfigurationStatus.RecordApplied(
            ProviderId, ProviderName, ContentHash, not DeviceHandoverCompleted);
    end;

    local procedure Execute(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary): Boolean
    var
        PageServices: Dictionary of [Integer, Text];
    begin
        // MobileNAV only carries configuration through to devices for changes made while its
        // construction window is open, so the whole apply runs inside one.
        this.PageManagement.BeginConfigurationChange();
        this.ApplyMasterData(TempConfigurationLine);
        this.PreparePublishedPages(TempConfigurationLine, PageServices);
        this.PrepareReferencedPages(TempConfigurationLine, TempConfigurationProperty, PageServices);
        // Page settings first: a page type change resets list-only field settings.
        this.ApplyProperties(TempConfigurationProperty, PageServices, true);
        this.ApplyFields(TempConfigurationLine, PageServices);
        this.ApplyFunctionFields(TempConfigurationLine, PageServices);
        this.ApplyScanFields(TempConfigurationLine, PageServices);
        this.ApplyRelations(TempConfigurationLine, PageServices);
        this.ApplyProperties(TempConfigurationProperty, PageServices, false);
        this.ApplyUserScopes(TempConfigurationLine, PageServices);
        this.ApplyPageRows(TempConfigurationLine, PageServices);
        // Groups and order last among the field rows: flow filters add rows of their own.
        this.ApplyGroupsAndOrder(TempConfigurationLine, PageServices);
        this.ApplyAppearance(TempConfigurationLine, PageServices);
        // Profile rows override the service-level field rows on the device, so they are written
        // after every field operation and read the Control IDs those operations settled.
        this.ApplyProfilePages(TempConfigurationLine, PageServices);
        // After the pages exist in the profiles, and before the field rows: a linked field's
        // target has to be reachable from the page the control sits on or the control is not
        // drawn at all. See "BJF MN Profile Mgt.".LinkPageToParent.
        this.ApplyProfilePageParents(TempConfigurationLine, PageServices);
        this.ApplyProfilePageSettings(TempConfigurationLine, PageServices);
        this.ApplyProfileFields(TempConfigurationLine, PageServices);
        // Staging runs after the fields: the per-field stage masks span every visible field row.
        this.ApplyStaging(TempConfigurationLine, PageServices);
        this.ApplyLayouts(TempConfigurationLine, PageServices);
        TempConfigurationLine.Reset();
        exit(this.PageManagement.PublishConfigurationToDevices());
    end;

    local procedure ApplyMasterData(var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        TempConfigurationLine.SetFilter(Operation, '%1|%2|%3',
            Enum::"BJF MN Config Operation"::Category, Enum::"BJF MN Config Operation"::"Category Translation",
            Enum::"BJF MN Config Operation"::Profile);
        if TempConfigurationLine.FindSet() then
            repeat
                case TempConfigurationLine.Operation of
                    Enum::"BJF MN Config Operation"::Category:
                        this.MasterDataManagement.EnsureCategory(CopyStr(TempConfigurationLine."Control Name", 1, 20), TempConfigurationLine.Description);
                    Enum::"BJF MN Config Operation"::"Category Translation":
                        this.MasterDataManagement.EnsureCategoryTranslation(CopyStr(TempConfigurationLine."Control Name", 1, 20), TempConfigurationLine."Language Code", TempConfigurationLine.Description);
                    Enum::"BJF MN Config Operation"::Profile:
                        this.MasterDataManagement.EnsureProfile(TempConfigurationLine.Profile, TempConfigurationLine.Description);
                end;
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
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
                if TempConfigurationLine."Function Codeunit ID" <> 0 then begin
                    this.PageManagement.PublishFunctionService(
                        TempConfigurationLine."Function Codeunit ID", TempConfigurationLine."Report Service Name");
                    this.PageManagement.SetReportService(ServiceName, TempConfigurationLine."Report Service Name");
                end;
                PageServices.Add(TempConfigurationLine."Page ID", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure PrepareReferencedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetFilter(Operation, '<>%1', Enum::"BJF MN Config Operation"::"Published Page");
        TempConfigurationLine.SetFilter("Page ID", '<>%1', 0);
        if TempConfigurationLine.FindSet() then
            repeat
                this.ResolvePage(TempConfigurationLine."Page ID", PageServices);
                if TempConfigurationLine."Target Page ID" <> 0 then
                    this.ResolvePage(TempConfigurationLine."Target Page ID", PageServices);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();

        TempConfigurationProperty.Reset();
        if TempConfigurationProperty.FindSet() then
            repeat
                this.ResolvePage(TempConfigurationProperty."Page ID", PageServices);
            until TempConfigurationProperty.Next() = 0;
    end;

    /// <param name="PageLevel">True writes the page (Main row) properties, false the control properties.</param>
    local procedure ApplyProperties(var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text]; PageLevel: Boolean)
    var
        ServiceName: Text;
    begin
        TempConfigurationProperty.Reset();
        if PageLevel then
            TempConfigurationProperty.SetRange("Control Name", '')
        else
            TempConfigurationProperty.SetFilter("Control Name", '<>%1', '');
        if TempConfigurationProperty.FindSet() then
            repeat
                PageServices.Get(TempConfigurationProperty."Page ID", ServiceName);
                this.PropertyManagement.Apply(CopyStr(ServiceName, 1, 100), TempConfigurationProperty);
            until TempConfigurationProperty.Next() = 0;
        TempConfigurationProperty.Reset();
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
        FunctionName: Text[50];
        UsesFunctionCodeunit: Boolean;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Function Field");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                // A function codeunit runs the button as one of its own procedures: the name is
                // the procedure's, and the page-function companion is not what the device calls.
                UsesFunctionCodeunit := this.HasFunctionCodeunit(TempConfigurationLine, TempConfigurationLine."Page ID");
                if UsesFunctionCodeunit then begin
                    if TempConfigurationLine."Function Name" = '' then
                        Error(this.ProcedureNameRequiredErr, TempConfigurationLine."Control Name", ServiceName);
                    FunctionName := TempConfigurationLine."Function Name";
                end else
                    FunctionName := this.ResolveFunctionName(TempConfigurationLine, CopyStr(ServiceName, 1, 100));
                if not this.FieldManagement.ConfigureFunctionField(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name",
                    TempConfigurationLine.Editable,
                    TempConfigurationLine."Mobile Type", FunctionName,
                    TempConfigurationLine."Function Type", TempConfigurationLine."Validation Behavior",
                    TempConfigurationLine.Importance)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
                if not UsesFunctionCodeunit then
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
        TempConfigurationLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Lookup Field");
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

    local procedure ApplyRelations(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        TempControlLine: Record "BJF MN Config Line" temporary;
        ServiceName: Text;
        TargetServiceName: Text;
        Configured: Boolean;
    begin
        TempControlLine.Copy(TempConfigurationLine, true);
        TempControlLine.Reset();
        TempControlLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Lookup Field");
        if TempControlLine.FindSet() then
            repeat
                PageServices.Get(TempControlLine."Page ID", ServiceName);
                PageServices.Get(TempControlLine."Target Page ID", TargetServiceName);
                if TempControlLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
                    Configured := this.RelationManagement.ConfigureLink(CopyStr(ServiceName, 1, 100), CopyStr(TargetServiceName, 1, 100), TempControlLine, TempConfigurationLine)
                else
                    Configured := this.RelationManagement.ConfigureLookup(CopyStr(ServiceName, 1, 100), CopyStr(TargetServiceName, 1, 100), TempControlLine, TempConfigurationLine);
                if not Configured then
                    Error(this.FieldMissingErr, TempControlLine."Control Name", ServiceName);
            until TempControlLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>Page filters, flow filters, saved filters and operations, per page that declares any.</summary>
    local procedure ApplyPageRows(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
        PageId: Integer;
    begin
        foreach PageId in this.PagesWith(TempConfigurationLine, Enum::"BJF MN Config Operation"::"User Scope", Enum::"BJF MN Config Operation"::"Page Filter") do begin
            PageServices.Get(PageId, ServiceName);
            this.FilterManagement.ApplyPageFilters(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
        end;
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Flow Filter");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                this.FilterManagement.ApplyFlowFilter(CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
        foreach PageId in this.PagesWith(TempConfigurationLine, Enum::"BJF MN Config Operation"::"Saved Filter", Enum::"BJF MN Config Operation"::"Saved Filter") do begin
            PageServices.Get(PageId, ServiceName);
            this.FilterManagement.ApplySavedFilters(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
        end;
        foreach PageId in this.PagesWith(TempConfigurationLine, Enum::"BJF MN Config Operation"::Operation, Enum::"BJF MN Config Operation"::Operation) do begin
            PageServices.Get(PageId, ServiceName);
            this.FilterManagement.ApplyOperations(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
        end;
    end;

    local procedure ApplyGroupsAndOrder(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
        PageId: Integer;
    begin
        foreach PageId in this.PagesWith(TempConfigurationLine, Enum::"BJF MN Config Operation"::"Field Order", Enum::"BJF MN Config Operation"::"Field Order") do begin
            PageServices.Get(PageId, ServiceName);
            this.GroupManagement.ApplyDeclaredOrder(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
        end;
        foreach PageId in this.PagesWith(TempConfigurationLine, Enum::"BJF MN Config Operation"::Group, Enum::"BJF MN Config Operation"::Group) do begin
            PageServices.Get(PageId, ServiceName);
            this.GroupManagement.ApplyGroups(CopyStr(ServiceName, 1, 100), TempConfigurationLine, PageId);
        end;
    end;

    local procedure ApplyAppearance(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::Caption, Enum::"BJF MN Config Operation"::"Menu Picture");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                if TempConfigurationLine.Operation = Enum::"BJF MN Config Operation"::Caption then
                    this.AppearanceManagement.SetCaption(CopyStr(ServiceName, 1, 100), TempConfigurationLine."Control Name", TempConfigurationLine."Language Code", TempConfigurationLine.Description)
                else
                    this.AppearanceManagement.SetMenuPicture(CopyStr(ServiceName, 1, 100), TempConfigurationLine);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyProfilePageSettings(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Page");
        if TempConfigurationLine.FindSet() then
            repeat
                PageServices.Get(TempConfigurationLine."Page ID", ServiceName);
                this.ProfileManagement.ConfigureProfilePage(
                    CopyStr(ServiceName, 1, 100), TempConfigurationLine.Profile,
                    TempConfigurationLine.Disabled, TempConfigurationLine."Auto Refresh On Open", TempConfigurationLine."Multi Select");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyLayouts(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        TempLayoutLine: Record "BJF MN Config Line" temporary;
        ServiceName: Text;
    begin
        TempLayoutLine.Copy(TempConfigurationLine, true);
        TempLayoutLine.Reset();
        TempLayoutLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Layout);
        if TempLayoutLine.FindSet() then
            repeat
                PageServices.Get(TempLayoutLine."Page ID", ServiceName);
                this.LayoutManagement.ApplyLayout(CopyStr(ServiceName, 1, 100), TempLayoutLine, TempConfigurationLine);
            until TempLayoutLine.Next() = 0;
    end;

    /// <summary>The distinct pages that have a line of either operation, in first-declared order.</summary>
    local procedure PagesWith(var TempConfigurationLine: Record "BJF MN Config Line" temporary; FirstOperation: Enum "BJF MN Config Operation"; SecondOperation: Enum "BJF MN Config Operation") PageIds: List of [Integer]
    begin
        TempConfigurationLine.Reset();
        TempConfigurationLine.SetFilter(Operation, '%1|%2', FirstOperation, SecondOperation);
        if TempConfigurationLine.FindSet() then
            repeat
                if not PageIds.Contains(TempConfigurationLine."Page ID") then
                    PageIds.Add(TempConfigurationLine."Page ID");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>
    /// A button declared without FunctionName() is served by whichever of MobileNAV's page
    /// functions handles the page's source table; the table is only known once the service
    /// exists, so the name is resolved here rather than in the builder.
    /// </summary>
    local procedure ResolveFunctionName(ConfigurationLine: Record "BJF MN Config Line" temporary; ServiceName: Text[100]): Text[50]
    var
        TableNo: Integer;
        DispatcherName: Text[50];
    begin
        if ConfigurationLine."Function Name" <> '' then
            exit(ConfigurationLine."Function Name");
        if not this.Lookup.GetServiceTableNo(ServiceName, TableNo) then
            Error(this.PageMissingErr, ConfigurationLine."Page ID");
        if not this.FunctionRouter.TryGetDispatcher(TableNo, DispatcherName) then
            Error(this.NoDispatcherErr, ConfigurationLine."Control Name", ServiceName, TableNo);
        exit(DispatcherName);
    end;

    /// <summary>Whether the page was published with a function codeunit (Functions() in the builder).</summary>
    local procedure HasFunctionCodeunit(var TempConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer): Boolean
    var
        TempPublishedLine: Record "BJF MN Config Line" temporary;
    begin
        TempPublishedLine.Copy(TempConfigurationLine, true);
        TempPublishedLine.Reset();
        TempPublishedLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        TempPublishedLine.SetRange("Page ID", PageId);
        TempPublishedLine.SetFilter("Function Codeunit ID", '<>%1', 0);
        exit(not TempPublishedLine.IsEmpty());
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
        ConfigurationHash: Codeunit "BJF MN Config Hash";
        Lookup: Codeunit "BJF MN Service Lookup";
        FunctionRouter: Codeunit "BJF MN Function Router";
        PageManagement: Codeunit "BJF MN Page Mgt.";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        ProfileManagement: Codeunit "BJF MN Profile Mgt.";
        PropertyManagement: Codeunit "BJF MN Property Mgt.";
        RelationManagement: Codeunit "BJF MN Relation Mgt.";
        FilterManagement: Codeunit "BJF MN Filter Mgt.";
        GroupManagement: Codeunit "BJF MN Group Mgt.";
        AppearanceManagement: Codeunit "BJF MN Appearance Mgt.";
        MasterDataManagement: Codeunit "BJF MN Master Data Mgt.";
        LayoutManagement: Codeunit "BJF MN Layout Mgt.";
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        PageMissingErr: Label 'Page %1 has not been registered in MobileNAV.', Comment = '%1 = page object id';
        FieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 after metadata refresh.', Comment = '%1 = control name, %2 = MobileNAV service name';
        ProcedureNameRequiredErr: Label 'Button %1 on %2 needs FunctionName(): the page runs its buttons through a function codeunit, so the procedure name cannot be derived.', Comment = '%1 = control name, %2 = service name';
        NoDispatcherErr: Label 'Button %1 on MobileNAV service %2 cannot be served automatically: MobileNAV has no page function for table %3. Name the function to call with FunctionName().', Comment = '%1 = control name, %2 = MobileNAV service name, %3 = table number';
}

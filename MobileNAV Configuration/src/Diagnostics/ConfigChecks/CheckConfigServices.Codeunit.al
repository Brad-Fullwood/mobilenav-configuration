namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>
/// Are the pages a provider declares registered and reachable? A page needs a MobileNAV Main
/// row, a published page web service, and, once it carries a button, the companion codeunit
/// web service under the same name that MobileNAV's SOAP transport calls functions through.
/// Each button's live function name must also be the one that serves the page's table.
/// </summary>
codeunit 77794 "BJF Check Config Services" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Tenant Web Service" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.CheckProvider(Finding, TempProvider);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        PageManagement: Codeunit "BJF MN Page Mgt.";
        Kind: Text;
        Args: List of [Text];
        CodeunitId: Integer;
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        case Kind of
            this.CompanionFixTok:
                if Args.Count() > 1 then begin
                    Evaluate(CodeunitId, Args.Get(2));
                    PageManagement.PublishFunctionCompanion(CopyStr(Args.Get(1), 1, 100), CodeunitId);
                end else
                    PageManagement.PublishFunctionCompanion(CopyStr(Args.Get(1), 1, 100));
            this.FunctionServiceFixTok:
                begin
                    Evaluate(CodeunitId, Args.Get(3));
                    PageManagement.PublishFunctionService(CodeunitId, CopyStr(Args.Get(2), 1, 100));
                    PageManagement.SetReportService(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100));
                end;
            else
                Error(this.NoAutomaticFixErr);
        end;
    end;

    local procedure CheckProvider(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary)
    var
        TempLine: Record "BJF MN Config Line" temporary;
        CheckedPages: List of [Integer];
    begin
        this.Support.BuildDefinition(TempProvider.Provider, TempLine);
        if TempLine.FindSet() then
            repeat
                this.CheckPageOnce(Finding, TempProvider, TempLine, TempLine."Page ID", CheckedPages);
                this.CheckPageOnce(Finding, TempProvider, TempLine, TempLine."Target Page ID", CheckedPages);
            until TempLine.Next() = 0;
    end;

    local procedure CheckPageOnce(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; var CheckedPages: List of [Integer])
    begin
        if (PageId = 0) or CheckedPages.Contains(PageId) then
            exit;
        CheckedPages.Add(PageId);
        this.CheckPage(Finding, TempProvider, TempLine, PageId);
    end;

    local procedure CheckPage(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        TempPageLine: Record "BJF MN Config Line" temporary;
        ServiceName: Text[100];
        UsesExplicitFunctionService: Boolean;
    begin
        ServiceName := this.Support.GetServiceName(PageId);
        if ServiceName = '' then begin
            Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.PageNotRegisteredMsg, PageId)));
            exit;
        end;

        TempPageLine.Copy(TempLine, true);
        TempPageLine.SetRange("Page ID", PageId);
        TempPageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempPageLine.FindFirst() then
            UsesExplicitFunctionService := this.CheckPublishedPage(Finding, TempProvider, ServiceName, TempPageLine);

        TempPageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Page Functions");
        if TempPageLine.FindFirst() then begin
            UsesExplicitFunctionService := true;
            this.CheckCompanion(Finding, TempProvider, ServiceName, TempPageLine."Function Codeunit ID");
        end;

        TempPageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Function Field");
        this.CheckFunctionFields(Finding, TempProvider, ServiceName, TempPageLine, UsesExplicitFunctionService);
    end;

    /// <summary>Checks a published page's web service, its menu tile and the function codeunit it declares.</summary>
    /// <param name="Finding">Receives a finding for each problem.</param>
    /// <param name="TempProvider">The provider that declared the page.</param>
    /// <param name="ServiceName">The service the page is registered as.</param>
    /// <param name="PageLine">The published page line.</param>
    /// <returns>True when the page declares a function codeunit of its own.</returns>
    local procedure CheckPublishedPage(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; PageLine: Record "BJF MN Config Line" temporary): Boolean
    begin
        this.CheckPublished(Finding, TempProvider, ServiceName);
        this.CheckMenuVisibility(Finding, TempProvider, ServiceName, PageLine);
        if PageLine."Function Codeunit ID" = 0 then
            exit(false);
        if PageLine."Report Service Name" = '' then
            this.CheckCompanion(Finding, TempProvider, ServiceName, PageLine."Function Codeunit ID")
        else
            this.CheckFunctionService(Finding, TempProvider, ServiceName, PageLine);
        exit(true);
    end;

    local procedure CheckFunctionFields(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; var TempPageLine: Record "BJF MN Config Line" temporary; UsesExplicitFunctionService: Boolean)
    begin
        if not TempPageLine.FindSet() then
            exit;
        // Dialogs with Functions() dispatch through their declared codeunit, checked
        // above. They do not require the ordinary MobileNAV Page Functions companion.
        if not UsesExplicitFunctionService then
            this.CheckStandardCompanion(Finding, TempProvider, ServiceName);
        repeat
            this.CheckFunctionName(Finding, TempProvider, ServiceName, TempPageLine, UsesExplicitFunctionService);
        until TempPageLine.Next() = 0;
    end;

    /// <summary>A published page is on the home menu exactly when it is declared ShowInMenu.</summary>
    /// <param name="Finding">Receives a finding when the tile differs.</param>
    /// <param name="TempProvider">The provider that declared the page.</param>
    /// <param name="ServiceName">The service the page is registered as.</param>
    /// <param name="PageLine">The published page line.</param>
    local procedure CheckMenuVisibility(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; PageLine: Record "BJF MN Config Line" temporary)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindMainRow(ServiceName, ServiceSetup) then
            exit;
        if not PageLine."Show In Menu" and this.Lookup.IsMobileNAVPage(PageLine."Page ID") then
            exit; // The administrator's tiles stay, see "BJF MN Config Application".KeepsAdministratorProfiles.
        if ServiceSetup.DisplayInMenu = PageLine."Show In Menu" then
            exit;
        Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Warning,
            this.Support.Prefix(TempProvider, StrSubstNo(this.MenuVisibilityMsg, ServiceName, Format(PageLine."Show In Menu"), Format(ServiceSetup.DisplayInMenu))), ServiceSetup.RecordId());
    end;

    local procedure CheckPublished(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        TenantWebService.SetLoadFields(Published);
        if TenantWebService.Get(TenantWebService."Object Type"::Page, ServiceName) and TenantWebService.Published then
            exit;
        Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NotPublishedMsg, ServiceName)));
    end;

    /// <summary>A dialog's function codeunit must be published under its service name, and the Main row must point at it.</summary>
    /// <param name="Finding">Receives a finding when the service is wrong.</param>
    /// <param name="TempProvider">The provider that declared the dialog.</param>
    /// <param name="ServiceName">The service the dialog is registered as.</param>
    /// <param name="PageLine">The published page line naming the function codeunit and its service.</param>
    local procedure CheckFunctionService(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; PageLine: Record "BJF MN Config Line" temporary)
    var
        TenantWebService: Record "Tenant Web Service";
        MainRow: Record "MobileNAV Service Setup";
        Args: List of [Text];
        Healthy: Boolean;
    begin
        TenantWebService.SetLoadFields(Published, "Object ID");
        Healthy := TenantWebService.Get(TenantWebService."Object Type"::Codeunit, PageLine."Report Service Name") and
            TenantWebService.Published and (TenantWebService."Object ID" = PageLine."Function Codeunit ID");
        if Healthy and this.Lookup.FindMainRow(ServiceName, MainRow) then
            Healthy := MainRow.OptionValues2 = PageLine."Report Service Name";
        if Healthy then
            exit;
        Args.Add(ServiceName);
        Args.Add(PageLine."Report Service Name");
        Args.Add(Format(PageLine."Function Codeunit ID", 0, 9));
        Finding.AddWithFix(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NoFunctionServiceMsg, ServiceName, PageLine."Report Service Name", PageLine."Function Codeunit ID")),
            Finding."Related Record ID", StrSubstNo(this.FunctionServiceFixMsg, PageLine."Report Service Name", ServiceName),
            this.Support.PackFix(this.FunctionServiceFixTok, Args));
    end;

    local procedure CompanionHasFunction(CompanionCodeunitId: Integer; TableNo: Integer; FunctionName: Text[50]; DefaultName: Text[50]): Boolean
    var
        PageFunctionCatalog: Codeunit "BJF MN Page Function Catalog";
    begin
        if CompanionCodeunitId = Codeunit::"MobileNAV Page Functions" then
            exit(PageFunctionCatalog.Contains(TableNo, FunctionName));
        exit(FunctionName = DefaultName);
    end;

    /// <summary>A page without a function codeunit of its own needs the companion its table's standard route uses.</summary>
    /// <param name="Finding">Receives a finding when the companion is missing.</param>
    /// <param name="TempProvider">The provider that declared the page.</param>
    /// <param name="ServiceName">The service the page is registered as.</param>
    local procedure CheckStandardCompanion(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100])
    var
        FunctionRouter: Codeunit "BJF MN Function Router";
        CompanionCodeunitId: Integer;
        TableNo: Integer;
        FunctionName: Text[50];
    begin
        if not this.Lookup.GetServiceTableNo(ServiceName, TableNo) then
            exit;
        if not FunctionRouter.TryGetStandardRoute(TableNo, CompanionCodeunitId, FunctionName) then
            exit; // CheckFunctionName reports the button.
        this.CheckCompanion(Finding, TempProvider, ServiceName, CompanionCodeunitId);
    end;

    local procedure CheckCompanion(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; ExpectedCodeunitId: Integer)
    var
        TenantWebService: Record "Tenant Web Service";
        Args: List of [Text];
    begin
        TenantWebService.SetLoadFields("Object ID");
        if TenantWebService.Get(TenantWebService."Object Type"::Codeunit, ServiceName) and
            (TenantWebService."Object ID" = ExpectedCodeunitId)
        then
            exit;
        Args.Add(ServiceName);
        Args.Add(Format(ExpectedCodeunitId, 0, 9));
        Finding.AddWithFix(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NoCompanionMsg, ServiceName)),
            Finding."Related Record ID", StrSubstNo(this.CompanionFixMsg, ServiceName),
            this.Support.PackFix(this.CompanionFixTok, Args));
    end;

    local procedure CheckFunctionName(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; ButtonLine: Record "BJF MN Config Line" temporary; UsesFunctionCodeunit: Boolean)
    var
        FieldRow: Record "MobileNAV Service Setup";
        Expected: Text[50];
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ButtonLine."Control Name", FieldRow) then
            exit; // Reported by the field check.
        Expected := ButtonLine."Function Name";
        if not UsesFunctionCodeunit then
            if not this.ResolveStandardFunctionName(Finding, TempProvider, ServiceName, ButtonLine, FieldRow, Expected) then
                exit;
        if FieldRow."Function Name" <> Expected then
            Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.FunctionMismatchMsg, ButtonLine."Control Name", ServiceName, FieldRow."Function Name", Expected)), FieldRow.RecordId());
    end;

    /// <summary>Works out the function a button on a page without its own function codeunit must call, through its table's standard route.</summary>
    /// <param name="Finding">Receives a finding when the table has no route or the companion lacks the named function.</param>
    /// <param name="TempProvider">The provider that declared the button.</param>
    /// <param name="ServiceName">The service the page is registered as.</param>
    /// <param name="ButtonLine">The declared button.</param>
    /// <param name="FieldRow">The button's live field row.</param>
    /// <param name="Expected">The declared function name. Set to the route's default name when blank.</param>
    /// <returns>True when the live function name should be compared with Expected.</returns>
    local procedure ResolveStandardFunctionName(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; ButtonLine: Record "BJF MN Config Line" temporary; FieldRow: Record "MobileNAV Service Setup"; var Expected: Text[50]): Boolean
    var
        FunctionRouter: Codeunit "BJF MN Function Router";
        DefaultName: Text[50];
        TableNo: Integer;
        CompanionCodeunitId: Integer;
    begin
        if not this.Lookup.GetServiceTableNo(ServiceName, TableNo) then
            exit(false);
        if not FunctionRouter.TryGetStandardRoute(TableNo, CompanionCodeunitId, DefaultName) then begin
            Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.NoDispatcherMsg, ButtonLine."Control Name", ServiceName, TableNo)), FieldRow.RecordId());
            exit(false);
        end;
        if Expected = '' then begin
            Expected := DefaultName;
            exit(true);
        end;
        if this.CompanionHasFunction(CompanionCodeunitId, TableNo, Expected, DefaultName) then
            exit(true);
        Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.FunctionNotOnCompanionMsg, ButtonLine."Control Name", ServiceName, Expected)), FieldRow.RecordId());
        exit(false);
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        PageNotRegisteredMsg: Label 'Page %1 is declared but MobileNAV has no configuration for it. Apply the provider.', Comment = '%1 = page id';
        MenuVisibilityMsg: Label 'Page %1 is declared with Display In Menu %2 but MobileNAV has %3. Apply the provider.', Comment = '%1 = service name, %2 = declared value, %3 = live value';
        NotPublishedMsg: Label 'Service %1 is declared as published but its page web service is missing or unpublished. Apply the provider.', Comment = '%1 = service name';
        FunctionNotOnCompanionMsg: Label 'Button %1 on %2 names function %3, which the page''s companion codeunit does not have, so every tap fails on the device.', Comment = '%1 = control name, %2 = service name, %3 = function name';
        NoCompanionMsg: Label 'Service %1 carries a button but does not have the expected companion codeunit, so every tap fails on the device with ''Method is invalid''.', Comment = '%1 = service name';
        CompanionFixMsg: Label 'Register the expected companion codeunit web service for %1.', Comment = '%1 = service name';
        NoDispatcherMsg: Label 'Button %1 on %2 has no MobileNAV function for table %3. Name one with FunctionName() in the provider.', Comment = '%1 = control, %2 = service, %3 = table no.';
        FunctionMismatchMsg: Label 'Button %1 on %2 calls function ''%3'' but the provider expects ''%4''. Apply the provider.', Comment = '%1 = control, %2 = service, %3 = live name, %4 = expected name';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        NoFunctionServiceMsg: Label 'Dialog %1 should run its buttons through codeunit %3 published as %2, but that service is missing, unpublished, points elsewhere, or the page does not name it.', Comment = '%1 = service name, %2 = function service name, %3 = codeunit id';
        FunctionServiceFixMsg: Label 'Publish the function codeunit as %1 and point %2 at it.', Comment = '%1 = function service name, %2 = service name';
        CompanionFixTok: Label 'COMPANION', Locked = true;
        FunctionServiceFixTok: Label 'FUNCTIONSERVICE', Locked = true;
}

namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;

/// <summary>
/// Are the pages a provider declares registered and reachable? A page needs a MobileNAV Main
/// row, a published page web service, and — once it carries a button — the companion codeunit
/// web service under the same name that MobileNAV's SOAP transport calls functions through.
/// Each button's live function name must also be the one that serves the page's table.
/// </summary>
codeunit 77794 "BJF Check Config Services" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r,
        tabledata "Tenant Web Service" = r;

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
                if not CheckedPages.Contains(TempLine."Page ID") then begin
                    CheckedPages.Add(TempLine."Page ID");
                    this.CheckPage(Finding, TempProvider, TempLine, TempLine."Page ID");
                end;
                if (TempLine."Target Page ID" <> 0) and not CheckedPages.Contains(TempLine."Target Page ID") then begin
                    CheckedPages.Add(TempLine."Target Page ID");
                    this.CheckPage(Finding, TempProvider, TempLine, TempLine."Target Page ID");
                end;
            until TempLine.Next() = 0;
    end;

    local procedure CheckPage(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        TempPageLine: Record "BJF MN Config Line" temporary;
        ServiceName: Text[100];
    begin
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then begin
            Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.PageNotRegisteredMsg, PageId)));
            exit;
        end;

        TempPageLine.Copy(TempLine, true);
        TempPageLine.SetRange("Page ID", PageId);
        TempPageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempPageLine.FindFirst() then begin
            this.CheckPublished(Finding, TempProvider, ServiceName);
            if TempPageLine."Function Codeunit ID" <> 0 then
                this.CheckFunctionService(Finding, TempProvider, ServiceName, TempPageLine);
        end;

        TempPageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Function Field");
        if TempPageLine.FindSet() then begin
            this.CheckCompanion(Finding, TempProvider, ServiceName);
            repeat
                this.CheckFunctionName(Finding, TempProvider, ServiceName, TempPageLine);
            until TempPageLine.Next() = 0;
        end;
    end;

    local procedure CheckPublished(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        if TenantWebService.Get(TenantWebService."Object Type"::Page, ServiceName) and TenantWebService.Published then
            exit;
        Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NotPublishedMsg, ServiceName)));
    end;

    /// <summary>A dialog's function codeunit must be published under its service name, and the Main row must point at it.</summary>
    local procedure CheckFunctionService(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; PageLine: Record "BJF MN Config Line" temporary)
    var
        TenantWebService: Record "Tenant Web Service";
        MainRow: Record "MobileNAV Service Setup";
        Args: List of [Text];
        Healthy: Boolean;
    begin
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

    local procedure CheckCompanion(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
        Args: List of [Text];
    begin
        if TenantWebService.Get(TenantWebService."Object Type"::Codeunit, ServiceName) then
            exit;
        Args.Add(ServiceName);
        Finding.AddWithFix(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NoCompanionMsg, ServiceName)),
            Finding."Related Record ID", StrSubstNo(this.CompanionFixMsg, ServiceName),
            this.Support.PackFix(this.CompanionFixTok, Args));
    end;

    local procedure CheckFunctionName(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; ButtonLine: Record "BJF MN Config Line" temporary)
    var
        FieldRow: Record "MobileNAV Service Setup";
        FunctionRouter: Codeunit "BJF MN Function Router";
        Expected: Text[50];
        TableNo: Integer;
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ButtonLine."Control Name", FieldRow) then
            exit; // Reported by the field check.
        Expected := ButtonLine."Function Name";
        if Expected = '' then begin
            if not this.Lookup.GetServiceTableNo(ServiceName, TableNo) then
                exit;
            if not FunctionRouter.TryGetDispatcher(TableNo, Expected) then begin
                Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                    this.Support.Prefix(TempProvider, StrSubstNo(this.NoDispatcherMsg, ButtonLine."Control Name", ServiceName, TableNo)), FieldRow.RecordId());
                exit;
            end;
        end;
        if FieldRow."Function Name" <> Expected then
            Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.FunctionMismatchMsg, ButtonLine."Control Name", ServiceName, FieldRow."Function Name", Expected)), FieldRow.RecordId());
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        PageNotRegisteredMsg: Label 'Page %1 is declared but MobileNAV has no configuration for it. Apply the provider.', Comment = '%1 = page id';
        NotPublishedMsg: Label 'Service %1 is declared as published but its page web service is missing or unpublished. Apply the provider.', Comment = '%1 = service name';
        NoCompanionMsg: Label 'Service %1 carries a button but has no companion codeunit web service, so every tap fails on the device with ''Method is invalid''.', Comment = '%1 = service name';
        CompanionFixMsg: Label 'Register the companion codeunit web service for %1.', Comment = '%1 = service name';
        NoDispatcherMsg: Label 'Button %1 on %2 has no MobileNAV function for table %3. Name one with FunctionName() in the provider.', Comment = '%1 = control, %2 = service, %3 = table no.';
        FunctionMismatchMsg: Label 'Button %1 on %2 calls function ''%3'' but the provider expects ''%4''. Apply the provider.', Comment = '%1 = control, %2 = service, %3 = live name, %4 = expected name';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        NoFunctionServiceMsg: Label 'Dialog %1 should run its buttons through codeunit %3 published as %2, but that service is missing, unpublished, points elsewhere, or the page does not name it.', Comment = '%1 = service name, %2 = function service name, %3 = codeunit id';
        FunctionServiceFixMsg: Label 'Publish the function codeunit as %1 and point %2 at it.', Comment = '%1 = function service name, %2 = service name';
        CompanionFixTok: Label 'COMPANION', Locked = true;
        FunctionServiceFixTok: Label 'FUNCTIONSERVICE', Locked = true;
}

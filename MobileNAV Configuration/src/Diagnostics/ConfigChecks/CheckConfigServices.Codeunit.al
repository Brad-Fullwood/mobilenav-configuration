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
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.CompanionFixTok then
            Error(this.NoAutomaticFixErr);
        PageManagement.PublishFunctionCompanion(CopyStr(Args.Get(1), 1, 100));
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
        ServiceName := this.Support.GetServiceName(PageId);
        if ServiceName = '' then begin
            Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.PageNotRegisteredMsg, PageId)));
            exit;
        end;

        TempPageLine.Copy(TempLine, true);
        TempPageLine.SetRange("Page ID", PageId);
        TempPageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if not TempPageLine.IsEmpty() then
            this.CheckPublished(Finding, TempProvider, ServiceName);

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
        if this.Support.HasWebService(TenantWebService."Object Type"::Page, ServiceName, TenantWebService) then
            if TenantWebService.Published then
                exit;
        Finding.Add(Finding."Check Type"::"Config Services", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.NotPublishedMsg, ServiceName)));
    end;

    local procedure CheckCompanion(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100])
    var
        TenantWebService: Record "Tenant Web Service";
        Args: List of [Text];
    begin
        if this.Support.HasWebService(TenantWebService."Object Type"::Codeunit, ServiceName, TenantWebService) then
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
        PageManagement: Codeunit "BJF MN Page Mgt.";
        FunctionMap: Codeunit "BJF MN Function Map";
        Expected: Text[50];
        TableNo: Integer;
    begin
        if not this.Support.FindFieldRow(ServiceName, ButtonLine."Control Name", FieldRow) then
            exit; // Reported by the field check.
        Expected := ButtonLine."Function Name";
        if Expected = '' then begin
            if not PageManagement.GetServiceTableNo(ServiceName, TableNo) then
                exit;
            if not FunctionMap.TryGetDispatcher(TableNo, Expected) then begin
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
        PageNotRegisteredMsg: Label 'Page %1 is declared but MobileNAV has no configuration for it. Apply the provider.', Comment = '%1 = page id';
        NotPublishedMsg: Label 'Service %1 is declared as published but its page web service is missing or unpublished. Apply the provider.', Comment = '%1 = service name';
        NoCompanionMsg: Label 'Service %1 carries a button but has no companion codeunit web service, so every tap fails on the device with ''Method is invalid''.', Comment = '%1 = service name';
        CompanionFixMsg: Label 'Register the companion codeunit web service for %1.', Comment = '%1 = service name';
        NoDispatcherMsg: Label 'Button %1 on %2 has no MobileNAV function for table %3. Name one with FunctionName() in the provider.', Comment = '%1 = control, %2 = service, %3 = table no.';
        FunctionMismatchMsg: Label 'Button %1 on %2 calls function ''%3'' but the provider expects ''%4''. Apply the provider.', Comment = '%1 = control, %2 = service, %3 = live name, %4 = expected name';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        CompanionFixTok: Label 'COMPANION', Locked = true;
}

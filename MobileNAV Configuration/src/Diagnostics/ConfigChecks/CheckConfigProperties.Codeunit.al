namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every page and control setting a provider declares hold on the live row? Each property
/// names one MobileNAV field and the value it should have; the fix rewrites that one field.
/// </summary>
codeunit 77787 "BJF Check Config Properties" implements "BJF Diagnostic Check"
{
    Access = Internal;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine, TempProperty);
                if TempProperty.FindSet() then
                    repeat
                        this.CheckProperty(Finding, TempProvider, TempProperty);
                    until TempProperty.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
        ProviderType: Enum "BJF MN Config Provider";
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        PageId: Integer;
        FieldNo: Integer;
        ServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.PropertyFixTok then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(PageId, Args.Get(2));
        Evaluate(FieldNo, Args.Get(4));
        ProviderType := Enum::"BJF MN Config Provider".FromInteger(Ordinal);
        this.Support.BuildDefinition(ProviderType, TempLine, TempProperty);
        TempProperty.SetRange("Page ID", PageId);
        TempProperty.SetRange("Control Name", CopyStr(Args.Get(3), 1, 100));
        TempProperty.SetRange("Field No.", FieldNo);
        if not TempProperty.FindFirst() then
            Error(this.PropertyGoneErr);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        this.PropertyManagement.Apply(ServiceName, TempProperty);
    end;

    local procedure CheckProperty(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; TempProperty: Record "BJF MN Config Property" temporary)
    var
        ServiceName: Text[100];
        Expected: Text;
        Live: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Lookup.GetServiceName(TempProperty."Page ID");
        if ServiceName = '' then
            exit; // Reported by the services check.
        if not this.PropertyManagement.LiveValue(ServiceName, TempProperty, Live) then
            exit; // Reported by the field check.
        Expected := this.PropertyManagement.ExpectedValue(ServiceName, TempProperty);
        if UpperCase(Live) = UpperCase(Expected) then
            exit;

        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(TempProperty."Page ID", 0, 9));
        Args.Add(TempProperty."Control Name");
        Args.Add(Format(TempProperty."Field No.", 0, 9));
        Finding.AddWithFix(Finding."Check Type"::"Config Properties", Finding.Severity::Warning,
            this.Support.Prefix(TempProvider, StrSubstNo(this.MismatchMsg, TempProperty.Setting, this.Target(TempProperty, ServiceName), this.PropertyManagement.FieldCaption(TempProperty."Field No."), Expected, Live)),
            Finding."Related Record ID", StrSubstNo(this.FixMsg, this.PropertyManagement.FieldCaption(TempProperty."Field No."), Expected, this.Target(TempProperty, ServiceName)),
            this.Support.PackFix(this.PropertyFixTok, Args));
    end;

    local procedure Target(TempProperty: Record "BJF MN Config Property" temporary; ServiceName: Text[100]): Text
    begin
        if TempProperty."Control Name" = '' then
            exit(StrSubstNo(this.PageTargetLbl, ServiceName));
        exit(StrSubstNo(this.ControlTargetLbl, TempProperty."Control Name", ServiceName));
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        PropertyManagement: Codeunit "BJF MN Property Mgt.";
        MismatchMsg: Label '%1() on %2: MobileNAV field %3 is declared %4 but has %5.', Comment = '%1 = setting, %2 = page or control, %3 = MobileNAV field caption, %4 = declared value, %5 = live value';
        FixMsg: Label 'Set %1 to %2 on %3.', Comment = '%1 = MobileNAV field caption, %2 = value, %3 = page or control';
        PageTargetLbl: Label 'page %1', Comment = '%1 = service name';
        ControlTargetLbl: Label 'control %1 of %2', Comment = '%1 = control name, %2 = service name';
        PropertyGoneErr: Label 'The provider no longer declares this setting.';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        PropertyFixTok: Label 'PROPERTY', Locked = true;
}

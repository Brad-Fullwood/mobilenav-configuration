namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;
using System.Utilities;

/// <summary>
/// Dumps the live MobileNAV rows a provider's definition touches — every Service Setup line of
/// each service, every Profile Setup row for it, and the tenant web services under its name —
/// in primary-key order with every user field, so two snapshots can be diffed line by line.
/// Used to prove that a rewritten provider or framework produces the same configuration.
/// </summary>
codeunit 77793 "BJF MN Config Snapshot"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r,
        tabledata "MobileNAV Profile Setup" = r,
        tabledata "Tenant Web Service" = r;

    procedure Export(var TempConfigurationLine: Record "BJF MN Config Line" temporary): Text
    var
        Output: TextBuilder;
        ServiceNames: List of [Text];
        ServiceName: Text;
    begin
        this.CollectServiceNames(TempConfigurationLine, ServiceNames);
        foreach ServiceName in ServiceNames do begin
            this.AppendServiceSetup(Output, ServiceName);
            this.AppendProfileSetup(Output, ServiceName);
            this.AppendWebServices(Output, ServiceName);
        end;
        exit(Output.ToText());
    end;

    procedure Download(FileName: Text; var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
    begin
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(this.Export(TempConfigurationLine));
        TempBlob.CreateInStream(InStream, TextEncoding::UTF8);
        DownloadFromStream(InStream, '', '', '', FileName);
    end;

    local procedure CollectServiceNames(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var ServiceNames: List of [Text])
    var
        PageIds: List of [Integer];
        PageId: Integer;
        ServiceName: Text;
    begin
        TempConfigurationLine.Reset();
        if TempConfigurationLine.FindSet() then
            repeat
                if not PageIds.Contains(TempConfigurationLine."Page ID") then
                    PageIds.Add(TempConfigurationLine."Page ID");
                if (TempConfigurationLine."Target Page ID" <> 0) and not PageIds.Contains(TempConfigurationLine."Target Page ID") then
                    PageIds.Add(TempConfigurationLine."Target Page ID");
            until TempConfigurationLine.Next() = 0;
        foreach PageId in PageIds do
            if this.TryGetServiceName(PageId, ServiceName) then
                if not ServiceNames.Contains(ServiceName) then
                    ServiceNames.Add(ServiceName);
    end;

    local procedure TryGetServiceName(PageId: Integer; var ServiceName: Text): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if not ServiceSetup.FindFirst() then
            exit(false);
        ServiceName := ServiceSetup."Service Name";
        exit(true);
    end;

    local procedure AppendServiceSetup(var Output: TextBuilder; ServiceName: Text)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        RecRef: RecordRef;
    begin
        ServiceSetup.SetRange("Service Name", ServiceName);
        if ServiceSetup.FindSet() then
            repeat
                RecRef.GetTable(ServiceSetup);
                this.AppendRow(Output, RecRef);
            until ServiceSetup.Next() = 0;
    end;

    local procedure AppendProfileSetup(var Output: TextBuilder; ServiceName: Text)
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        RecRef: RecordRef;
    begin
        ProfileSetup.SetRange(ID, ServiceName);
        if ProfileSetup.FindSet() then
            repeat
                RecRef.GetTable(ProfileSetup);
                this.AppendRow(Output, RecRef);
            until ProfileSetup.Next() = 0;
    end;

    local procedure AppendWebServices(var Output: TextBuilder; ServiceName: Text)
    var
        TenantWebService: Record "Tenant Web Service";
        RecRef: RecordRef;
    begin
        TenantWebService.SetRange("Service Name", ServiceName);
        if TenantWebService.FindSet() then
            repeat
                RecRef.GetTable(TenantWebService);
                this.AppendRow(Output, RecRef);
            until TenantWebService.Next() = 0;
    end;

    local procedure AppendRow(var Output: TextBuilder; var RecRef: RecordRef)
    var
        FieldRef: FieldRef;
        FieldIndex: Integer;
    begin
        Output.Append(RecRef.Name);
        for FieldIndex := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(FieldIndex);
            // System fields (ids, timestamps, audit columns) differ between any two runs.
            if (FieldRef.Number < 2000000000) and (FieldRef.Class = FieldClass::Normal) then begin
                Output.Append(this.FieldSeparatorTok);
                Output.Append(FieldRef.Name);
                Output.Append(this.ValueSeparatorTok);
                Output.Append(Format(FieldRef.Value(), 0, 9));
            end;
        end;
        Output.AppendLine();
    end;

    var
        FieldSeparatorTok: Label '|', Locked = true;
        ValueSeparatorTok: Label '=', Locked = true;
}

namespace BradFullwood.MobileNAV.Configuration;

using System.Integration;
using System.Utilities;

/// <summary>
/// Dumps the live MobileNAV rows a provider's definition touches, in primary-key order with
/// every user field, so two environments or two versions can be diffed line by line.
/// </summary>
codeunit 77793 "BJF MN Config Snapshot"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r,
        tabledata "MobileNAV Profile Setup" = r,
        tabledata "Tenant Web Service" = r;

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

    procedure Export(var TempConfigurationLine: Record "BJF MN Config Line" temporary): Text
    var
        Output: TextBuilder;
        ServiceName: Text;
    begin
        foreach ServiceName in this.ServiceNames(TempConfigurationLine) do begin
            this.AppendServiceSetup(Output, ServiceName);
            this.AppendProfileSetup(Output, ServiceName);
            this.AppendWebServices(Output, ServiceName);
        end;
        exit(Output.ToText());
    end;

    local procedure ServiceNames(var TempConfigurationLine: Record "BJF MN Config Line" temporary) Names: List of [Text]
    var
        PageIds: List of [Integer];
        PageId: Integer;
        ServiceName: Text;
    begin
        TempConfigurationLine.Reset();
        if TempConfigurationLine.FindSet() then
            repeat
                this.AddUnique(PageIds, TempConfigurationLine."Page ID");
                this.AddUnique(PageIds, TempConfigurationLine."Target Page ID");
            until TempConfigurationLine.Next() = 0;
        foreach PageId in PageIds do begin
            ServiceName := this.Lookup.GetServiceName(PageId);
            if (ServiceName <> '') and not Names.Contains(ServiceName) then
                Names.Add(ServiceName);
        end;
    end;

    local procedure AddUnique(var PageIds: List of [Integer]; PageId: Integer)
    begin
        if (PageId <> 0) and not PageIds.Contains(PageId) then
            PageIds.Add(PageId);
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
        Output.Append(RecRef.Name());
        for FieldIndex := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(FieldIndex);
            if this.IsUserField(FieldRef) then begin
                Output.Append(this.FieldSeparatorTok);
                Output.Append(FieldRef.Name());
                Output.Append(this.ValueSeparatorTok);
                Output.Append(Format(FieldRef.Value(), 0, 9));
            end;
        end;
        Output.AppendLine();
    end;

    /// <summary>System fields (ids, timestamps, audit columns) differ between any two runs.</summary>
    local procedure IsUserField(FieldRef: FieldRef): Boolean
    begin
        exit((FieldRef.Number() < 2000000000) and (FieldRef.Class() = FieldClass::Normal));
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        FieldSeparatorTok: Label '|', Locked = true;
        ValueSeparatorTok: Label '=', Locked = true;
}

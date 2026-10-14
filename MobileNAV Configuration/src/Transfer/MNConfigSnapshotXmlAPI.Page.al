namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// One configuration snapshot's XML, base64 encoded, ready to import in another company or
/// environment through configImports. Read one snapshot at a time: the XML is returned only when the
/// request selects exactly one snapshot, by id or by a filter on code.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/configSnapshotContents({id}), or
/// configSnapshotContents?$filter=code eq '{code}'.
/// </summary>
page 77782 "BJF MN Config Snapshot XML API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Configuration Snapshot XML';
    DataAccessIntent = ReadOnly;
    DelayedInsert = true;
    DeleteAllowed = false;
    Editable = false;
    EntityCaption = 'MobileNAV Configuration Snapshot XML';
    EntityName = 'configSnapshotContent';
    EntitySetCaption = 'MobileNAV Configuration Snapshot XML';
    EntitySetName = 'configSnapshotContents';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Master Data" = r;
    SourceTable = "MobileNAV Master Data";
    SourceTableView = sorting(Type, "Order") where(Type = const(ConfigSnapshot));

    layout
    {
        area(Content)
        {
            repeater(Snapshots)
            {
                field(id; Rec.SystemId) { }
                field("code"; Rec."Code") { }
                field(description; Rec.Description) { }
                field(configHash; Rec."Config Hash") { }
                field(configXmlBase64; this.ConfigXmlBase64) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        // The XML of one snapshot is megabytes, so a request that lists several snapshots gets no XML.
        if Rec.Count() = 1 then
            this.ConfigXmlBase64 := this.ConfigTransfer.SnapshotXmlBase64(Rec)
        else
            this.ConfigXmlBase64 := '';
    end;

    var
        ConfigTransfer: Codeunit "BJF MN Config Transfer";
        ConfigXmlBase64: Text;
}

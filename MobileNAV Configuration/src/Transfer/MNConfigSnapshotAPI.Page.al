namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// MobileNAV's configuration snapshots, the rows of the MobileNAV Configuration Handling page.
/// GET lists them. POST with an optional description takes a snapshot of the current
/// configuration and returns it, with its code. Read a snapshot's XML from configSnapshotContents.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/configSnapshots({id}), or filter on code.
/// </summary>
page 77799 "BJF MN Config Snapshot API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Configuration Snapshot';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Configuration Snapshot';
    EntityName = 'configSnapshot';
    EntitySetCaption = 'MobileNAV Configuration Snapshots';
    EntitySetName = 'configSnapshots';
    Extensible = false;
    InsertAllowed = true;
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
                field(id; Rec.SystemId)
                {
                    Editable = false;
                }
                field("code"; Rec."Code")
                {
                    Editable = false;
                }
                field(description; Rec.Description) { }
                field(created; Rec.Created)
                {
                    Editable = false;
                }
                field(loaded; Rec.Loaded)
                {
                    Editable = false;
                }
                field(dirty; Rec.Dirty)
                {
                    Editable = false;
                }
                field(configHash; Rec."Config Hash")
                {
                    Editable = false;
                }
                field(baseConfigVersion; Rec.ConfigVersion)
                {
                    Editable = false;
                }
                field(baseConfig; Rec."Base Config")
                {
                    Editable = false;
                }
                field(parent; Rec.Parent)
                {
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Editable = false;
                }
            }
        }
    }

    /// <summary>
    /// Takes the snapshot through MobileNAV and answers with the row MobileNAV inserted, so the
    /// response carries the new code. The posted record itself is not inserted.
    /// </summary>
    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        Snapshot: Record "MobileNAV Master Data";
        ConfigTransfer: Codeunit "BJF MN Config Transfer";
    begin
        ConfigTransfer.TakeSnapshot(Rec.Description, Snapshot);
        Rec := Snapshot;
        exit(false);
    end;
}

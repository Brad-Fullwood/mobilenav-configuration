namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Imports a MobileNAV configuration XML as a custom configuration, with the effect of Import
/// Custom Configuration on the MobileNAV Configuration Handling page. POST configXmlBase64 (the XML
/// file, base64 encoded). The import takes a backup snapshot of the current configuration first
/// and answers with its code, the code of the snapshot holding the imported configuration, and
/// the XML's kind and description. Nothing is stored here: a GET returns no rows.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/configImports.
/// </summary>
page 77783 "BJF MN Config Import API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Configuration Import';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Configuration Import';
    EntityName = 'configImport';
    EntitySetCaption = 'MobileNAV Configuration Imports';
    EntitySetName = 'configImports';
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    ODataKeyFields = Id;
    PageType = API;
    SourceTable = "BJF MN Config Import";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Imports)
            {
                field(id; Rec.Id)
                {
                    Editable = false;
                }
                field(configXmlBase64; this.ConfigXmlBase64) { }
                field(backupSnapshotCode; Rec."Backup Snapshot Code")
                {
                    Editable = false;
                }
                field(importedSnapshotCode; Rec."Imported Snapshot Code")
                {
                    Editable = false;
                }
                field(configKind; Rec."Config Kind")
                {
                    Editable = false;
                }
                field(configDescription; Rec."Config Description")
                {
                    Editable = false;
                }
                field(baseConfigVersion; Rec."Base Config Version")
                {
                    Editable = false;
                }
                field(importedAt; Rec."Imported At")
                {
                    Editable = false;
                }
                field(importedBy; Rec."Imported By")
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

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        ConfigTransfer: Codeunit "BJF MN Config Transfer";
    begin
        Rec.Validate(Id, CreateGuid());
        ConfigTransfer.ImportConfiguration(this.ConfigXmlBase64, Rec);
        this.ConfigXmlBase64 := ''; // The response would otherwise repeat the whole XML.
        exit(true);
    end;

    var
        ConfigXmlBase64: Text;
}

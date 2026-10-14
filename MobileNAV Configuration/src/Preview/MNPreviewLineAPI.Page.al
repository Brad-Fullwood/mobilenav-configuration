namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The changes the last preview of each provider found. Run the preview action on
/// configProviders first. Route: api/bjf/mobilenav/v1.0/companies({id})/configPreviewLines,
/// filtered with $filter=providerId eq '{providerId}'.
/// </summary>
page 77707 "BJF MN Preview Line API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Configuration Preview Line';
    DelayedInsert = true;
    DeleteAllowed = false;
    Editable = false;
    EntityCaption = 'MobileNAV Configuration Preview Line';
    EntityName = 'configPreviewLine';
    EntitySetCaption = 'MobileNAV Configuration Preview Lines';
    EntitySetName = 'configPreviewLines';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "BJF MN Preview Line";
    SourceTableView = sorting("Entry No.");

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(entryNo; Rec."Entry No.") { }
                field(providerId; Rec."Provider ID") { }
                field(change; Rec.Change) { }
                field(tableName; Rec."Table Name") { }
                field(recordName; Rec."Record") { }
                field(fieldName; Rec."Field Name") { }
                field(oldValue; Rec."Old Value") { }
                field(newValue; Rec."New Value") { }
                field(previewedAt; Rec."Previewed At") { }
                field(previewedBy; Rec."Previewed By") { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
            }
        }
    }
}

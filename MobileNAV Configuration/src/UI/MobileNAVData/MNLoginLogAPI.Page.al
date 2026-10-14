namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's login log, read-only: the server side of a device login, step by step with
/// timings, for working out why a device fails to log in or takes long to. Newest first
/// with $orderby=entryNo desc; filter on userId.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/loginLogEntries.
/// </summary>
page 77798 "BJF MN Login Log API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Login Log Entry';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Login Log Entry';
    EntityName = 'loginLogEntry';
    EntitySetCaption = 'MobileNAV Login Log Entries';
    EntitySetName = 'loginLogEntries';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Login Log" = r;
    SourceTable = "MobileNAV Login Log";

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(entryNo; Rec."Entry No.") { }
                field(userId; Rec."User ID") { }
                field(entryDateTime; Rec."Entry DateTime") { }
                field(logMessage; Rec."Log Message") { }
                field(logMessage2; Rec."Log Message 2") { }
                field(elapsedSeconds; Rec."Elapsed Time (sec.)") { }
                field(clientType; Rec."Client Type") { }
                field(processId; Rec."Process ID") { }
            }
        }
    }
}

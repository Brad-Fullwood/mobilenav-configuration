namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's user setup, read-only: the per-user warehouse settings devices depend on
/// (location, movement journal and worksheet), login mode and freeze status. A user's profile
/// is a profileSetupLines row with profileType User.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/userSetups.
/// </summary>
page 77797 "BJF MN User Setup API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV User Setup';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV User Setup';
    EntityName = 'userSetup';
    EntitySetCaption = 'MobileNAV User Setups';
    EntitySetName = 'userSetups';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV User Setup" = r;
    SourceTable = "MobileNAV User Setup";

    layout
    {
        area(Content)
        {
            repeater(Users)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(userId; Rec."User ID") { }
                field(locationCode; Rec."Location Code") { }
                field(movementJournalName; Rec."Movement Journal Name") { }
                field(movementWorksheetName; Rec."Movement Worksheet Name") { }
                field(jobJournalTemplate; Rec."Job Journal Template") { }
                field(jobJournalBatch; Rec."Job Journal Batch") { }
                field(employeeNo; Rec."Employee No.") { }
                field(salespersonCode; Rec."Salesperson Code") { }
                field(defaultLanguageCode; Rec."Default Language Code") { }
                field(loginMode; Rec."Login Mode") { }
                field(backgroundSynchronization; Rec."Background Synchronization") { }
                field(companyFilter; Rec."Company Filter") { }
                field(freezeStatus; Rec."Freeze Status") { }
                field(firstLoginDate; Rec."First Login Date") { }
                field(lastLoginDate; Rec."Last Login Date") { }
                field(logLoginProcess; Rec."Log Login Process") { }
            }
        }
    }
}

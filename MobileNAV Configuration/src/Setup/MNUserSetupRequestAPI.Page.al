namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Sets up a Business Central user for MobileNAV as the Add User step of the MobileNAV Setup Wizard
/// does. POST {"userName": "...", "profileId": "SALES ONLINE", "languageCode": "ENU"} adds the
/// MobileNAV user setup and profile when missing and generates the user configuration. profileId and
/// languageCode are optional. It is insert only, and a repeat POST for the same user changes nothing
/// except regenerating the configuration. The answer lists what was done.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/mobilenavUserSetupRequests.
/// </summary>
page 77709 "BJF MN User Setup Request API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV User Setup Request';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV User Setup Request';
    EntityName = 'mobilenavUserSetupRequest';
    EntitySetCaption = 'MobileNAV User Setup Requests';
    EntitySetName = 'mobilenavUserSetupRequests';
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    ODataKeyFields = Id;
    PageType = API;
    SourceTable = "BJF MN User Setup Request";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Requests)
            {
                field(id; Rec.Id)
                {
                    Editable = false;
                }
                field(userName; Rec."User Name") { }
                field(profileId; Rec."Profile Id") { }
                field(languageCode; Rec."Language Code") { }
                field(log; Rec.Log)
                {
                    Editable = false;
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        this.SetupMgt.AddUser(Rec);
        Rec.Insert(false);
        exit(false);
    end;

    var
        SetupMgt: Codeunit "BJF MN Setup Mgt";
}

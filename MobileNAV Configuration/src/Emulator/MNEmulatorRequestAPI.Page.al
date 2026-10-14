namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// Sends one request to the device emulator and returns its response. POST a request text with
/// its kind, and read the response from the same call. Nothing is stored. A request that fails
/// comes back as {"kind":"error","message":...} and the call still succeeds.
/// Kinds: menu (user, language, profile), profiles (user), list (service, parent, search,
/// savedFilter, filters, sortKey, ascending, skip, top), card (service, position), bufferState (user).
/// List, card and profiles load the configuration for the user, language and profile they name.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/emulatorRequests.
/// Body: {"request": "{\"kind\":\"menu\",\"user\":\"ADMIN\"}"}.
/// </summary>
page 77701 "BJF MN Emulator Request API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Emulator Request';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Emulator Request';
    EntityName = 'emulatorRequest';
    EntitySetCaption = 'MobileNAV Emulator Requests';
    EntitySetName = 'emulatorRequests';
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    ODataKeyFields = "Entry No.";
    PageType = API;
    SourceTable = "BJF MN Emulator Request";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Requests)
            {
                field(entryNo; Rec."Entry No.") { }
                field(request; Rec.Request) { }
                field(response; this.ResponseText)
                {
                    Editable = false;
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        if Rec."Entry No." = 0 then
            Rec.Validate("Entry No.", 1);
        this.ResponseText := this.Emulator.Respond(Rec.Request);
        exit(true);
    end;

    var
        Emulator: Codeunit "BJF MN Emulator";
        ResponseText: Text;
}

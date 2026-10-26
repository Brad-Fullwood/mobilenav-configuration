namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The MobileNAV setup of the company as one row. GET returns the licence, configuration, login
/// and Setup Wizard state. POST runs the setup the MobileNAV Setup Wizard does, without the UI:
/// allow HttpClient for MobileNAV, start the trial when no licence is installed, import the base
/// configuration when none exists, set the device login values and mark the wizard complete.
/// Each step checks its state first, so a repeat POST changes nothing. The optional
/// o365TenantId, o365AppId, o365RedirectUri and o365AppIdUri in the POST are the device login
/// values. The answer is the GET row plus a log of what each step did.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/mobilenavSetups.
/// </summary>
page 77708 "BJF MN Setup API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Setup';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Setup';
    EntityName = 'mobilenavSetup';
    EntitySetCaption = 'MobileNAV Setups';
    EntitySetName = 'mobilenavSetups';
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    ODataKeyFields = Id;
    PageType = API;
    SourceTable = "BJF MN Setup";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Setups)
            {
                field(id; Rec.Id)
                {
                    Editable = false;
                }
                field(hasLicense; Rec."Has Licence")
                {
                    Editable = false;
                }
                field(hasConfig; Rec."Has Config")
                {
                    Editable = false;
                }
                field(licenceExpiry; Rec."Licence Expiry")
                {
                    Editable = false;
                }
                field(licensedDevices; Rec."Licensed Devices")
                {
                    Editable = false;
                }
                field(authenticationType; Rec."Authentication Type")
                {
                    Editable = false;
                }
                field(o365TenantId; Rec."O365 Tenant Id") { }
                field(o365AppId; Rec."O365 App Id") { }
                field(o365RedirectUri; Rec."O365 Redirect Uri") { }
                field(o365AppIdUri; Rec."O365 App Id Uri") { }
                field(setupCompleted; Rec."Setup Completed")
                {
                    Editable = false;
                }
                field(httpAllowed; Rec."Http Allowed")
                {
                    Editable = false;
                }
                field(runSetup; Rec."Run Setup") { }
                field(log; Rec.Log)
                {
                    Editable = false;
                }
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    begin
        if not this.Loaded then
            this.Load();
        exit(Rec.Find(Which));
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        this.SetupMgt.RunSetup(Rec);
        // Rec is temporary: insert it here and return false so the platform does not insert the request row again.
        Rec.Insert(false);
        this.Loaded := true;
        exit(false);
    end;

    local procedure Load()
    var
        TempSetup: Record "BJF MN Setup" temporary;
    begin
        // Assignment keeps the filters the request put on Rec.
        this.SetupMgt.GetStatus(TempSetup);
        Rec := TempSetup;
        Rec.Insert(false);
        this.Loaded := true;
    end;

    var
        SetupMgt: Codeunit "BJF MN Setup Mgt";
        Loaded: Boolean;
}

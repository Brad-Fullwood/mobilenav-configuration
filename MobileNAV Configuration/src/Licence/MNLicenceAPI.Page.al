namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The installed MobileNAV licence as one row. GET returns the licence id, the licensed and
/// assigned device counts, the expiry date and licenceString. POST {"licenceString": "..."}, or a
/// PATCH of licenceString on the row, installs the string as Change License on the MobileNAV
/// License Setup page does, and answers with the new licence. A string issued for another tenant
/// is refused. The licence is shared by all companies, so the company in the route does not matter.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/mobilenavLicences.
/// </summary>
page 77705 "BJF MN Licence API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Licence';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Licence';
    EntityName = 'mobilenavLicence';
    EntitySetCaption = 'MobileNAV Licences';
    EntitySetName = 'mobilenavLicences';
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = true;
    ODataKeyFields = Id;
    PageType = API;
    SourceTable = "BJF MN Licence";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Licences)
            {
                field(id; Rec.Id)
                {
                    Editable = false;
                }
                field(licenceId; Rec."Licence Id")
                {
                    Editable = false;
                }
                field(licensedDevices; Rec."Licensed Devices")
                {
                    Editable = false;
                }
                field(assignedDevices; Rec."Assigned Devices")
                {
                    Editable = false;
                }
                field(expiryDate; Rec."Expiry Date")
                {
                    Editable = false;
                }
                field(licenceString; Rec."Licence String") { }
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
        this.LicenceTransfer.InstallLicenceString(Rec."Licence String");
        Rec.Reset();
        Rec.DeleteAll(false);
        this.LicenceTransfer.GetLicenceInfo(Rec);
        this.Loaded := true;
        exit(true);
    end;

    trigger OnModifyRecord(): Boolean
    var
        TempInstalled: Record "BJF MN Licence" temporary;
    begin
        this.LicenceTransfer.GetLicenceInfo(TempInstalled);
        if Rec."Licence String" <> TempInstalled."Licence String" then
            this.LicenceTransfer.InstallLicenceString(Rec."Licence String");
        this.LicenceTransfer.GetLicenceInfo(Rec);
        exit(true);
    end;

    local procedure Load()
    var
        TempLicence: Record "BJF MN Licence" temporary;
    begin
        // Assignment keeps the filters the request put on Rec.
        this.LicenceTransfer.GetLicenceInfo(TempLicence);
        Rec := TempLicence;
        Rec.Insert(false);
        this.Loaded := true;
    end;

    var
        LicenceTransfer: Codeunit "BJF MN Licence Transfer";
        Loaded: Boolean;
}

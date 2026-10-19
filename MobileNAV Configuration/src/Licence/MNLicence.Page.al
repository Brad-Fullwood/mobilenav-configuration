namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Shows the installed MobileNAV licence and its licence string, and installs a licence string
/// copied from another environment of the same tenant.
/// </summary>
page 77702 "BJF MN Licence"
{
    AdditionalSearchTerms = 'MobileNAV Licence Transfer,MobileNAV License,licence string,license key';
    ApplicationArea = All;
    Caption = 'MobileNAV Licence';
    DeleteAllowed = false;
    Editable = false;
    Extensible = false;
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "BJF MN Licence";
    SourceTableTemporary = true;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Licence Installed"; Rec."Licence Installed") { }
                field("Licence Id"; Rec."Licence Id") { }
                field("Tenant Licence Id"; Rec."Tenant Licence Id") { }
                field("Licensed Devices"; Rec."Licensed Devices") { }
                field("Assigned Devices"; Rec."Assigned Devices") { }
                field("Expiry Date"; Rec."Expiry Date") { }
            }
            group(Transfer)
            {
                Caption = 'Licence String';

                field("Licence String"; Rec."Licence String")
                {
                    MultiLine = true;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(InstallLicenceString)
            {
                Caption = 'Install licence string';
                Image = Import;
                ToolTip = 'Installs a licence string copied from another environment of this tenant. It replaces the installed licence, and with it the number of licensed devices. A string issued for another tenant is refused.';

                trigger OnAction()
                var
                    Dialog: Page "BJF MN Licence String Dialog";
                begin
                    if Dialog.RunModal() <> Action::OK then
                        exit;
                    this.LicenceTransfer.InstallLicenceString(Dialog.GetLicenceString());
                    this.Refresh();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(InstallLicenceString_Promoted; InstallLicenceString) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.Refresh();
    end;

    local procedure Refresh()
    begin
        Rec.Reset();
        Rec.DeleteAll(false);
        this.LicenceTransfer.GetLicenceInfo(Rec);
        Rec.Insert(false);
    end;

    var
        LicenceTransfer: Codeunit "BJF MN Licence Transfer";
}

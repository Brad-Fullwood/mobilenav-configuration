namespace BradFullwood.MobileNAV.Configuration.WMS;

/// <summary>Shows the state of WMS MobileNAV's licence check and asks the licence server again.</summary>
page 77758 "BJF MN WMS Licence"
{
    AdditionalSearchTerms = 'WMS MobileNAV licence,WMS license,licence check';
    ApplicationArea = All;
    Caption = 'WMS MobileNAV Licence';
    DeleteAllowed = false;
    Editable = false;
    Extensible = false;
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "MUL WMS License Information";
    SourceTableTemporary = true;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Last License Check"; Rec."Last License Check")
                {
                    ToolTip = 'Specifies when WMS MobileNAV last asked the licence server.';
                }
                field("Last Successful License Check"; Rec."Last Successful License Check")
                {
                    ToolTip = 'Specifies when the licence server last confirmed the WMS licence.';
                }
                field("First Failed License Check"; Rec."First Failed License Check")
                {
                    Style = Unfavorable;
                    StyleExpr = this.HasFailure;
                    ToolTip = 'Specifies when the licence check first failed. While this is set, device sessions reuse the stored failure without asking the licence server. The grace period of one month counts from this date.';
                }
                field("First Failed License Message"; Rec."First Failed License Message")
                {
                    MultiLine = true;
                    ToolTip = 'Specifies the message of the first failed licence check, which device sessions show while the failure is stored.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RecheckLicence)
            {
                Caption = 'Recheck WMS licence';
                Image = Refresh;
                ToolTip = 'Device sessions reuse a stored failure. A recheck from the web client asks the licence server again and clears the failure when the licence is valid.';

                trigger OnAction()
                begin
                    this.WMSLicence.RecheckLicence();
                    this.Refresh();
                    CurrPage.Update(false);
                    if not this.HasFailure then
                        Message(this.LicenceValidMsg);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                actionref(RecheckLicence_Promoted; RecheckLicence) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.Refresh();
    end;

    local procedure Refresh()
    var
        LicenseInformation: Record "MUL WMS License Information";
    begin
        Rec.Reset();
        Rec.DeleteAll(false);
        if this.WMSLicence.GetState(LicenseInformation) then
            Rec := LicenseInformation;
        Rec.Insert(false);
        this.HasFailure := Rec."First Failed License Check" <> 0DT;
    end;

    var
        WMSLicence: Codeunit "BJF MN WMS Licence";
        HasFailure: Boolean;
        LicenceValidMsg: Label 'The licence server confirmed the WMS MobileNAV licence.';
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Explains what the emulator does, and how to get the token of the selected token source, step by step. It is a
/// FactBox beside the device on the MobileNAV Device Emulator page. Each paragraph and each step is its own field, so BC
/// wraps every one in full. The page holds no record and writes nothing.
/// </summary>
page 77760 "BJF MN Emulator Help"
{
    ApplicationArea = All;
    Caption = 'Emulator help';
    PageType = CardPart;

    layout
    {
        area(Content)
        {
            group(AboutGroup)
            {
                Caption = 'About the emulator';

                field(AboutField; this.AboutTxt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(AppRegistrationGroup)
            {
                Caption = 'App Registration, step by step';
                Visible = this.AppRegistrationSource;

                field(AppRegistrationStep1Field; this.AppRegistrationStep1Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(AppRegistrationStep2Field; this.AppRegistrationStep2Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(AppRegistrationStep3Field; this.AppRegistrationStep3Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(AppRegistrationStep4Field; this.AppRegistrationStep4Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(AppRegistrationStep5Field; this.AppRegistrationStep5Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(MobileNAVTokenGroup)
            {
                Caption = 'MobileNAV Token, step by step';
                Visible = this.MobileNAVSource;

                field(MobileNAVStep1Field; this.MobileNAVStep1Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(MobileNAVStep2Field; this.MobileNAVStep2Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(MobileNAVStep3Field; this.MobileNAVStep3Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
            group(SuppliedTokenGroup)
            {
                Caption = 'Supplied Token, step by step';
                Visible = this.SuppliedSource;

                field(SuppliedStep1Field; this.SuppliedStep1Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(SuppliedStep2Field; this.SuppliedStep2Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(SuppliedStep3Field; this.SuppliedStep3Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
                field(SuppliedStep4Field; this.SuppliedStep4Txt)
                {
                    ShowCaption = false;
                    Editable = false;
                    MultiLine = true;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.AppRegistrationStep1Txt := this.AppRegistrationStep1Lbl;
        this.AppRegistrationStep2Txt := this.AppRegistrationStep2Lbl;
        this.AppRegistrationStep3Txt := this.AppRegistrationStep3Lbl;
        this.AppRegistrationStep4Txt := this.AppRegistrationStep4Lbl;
        this.AppRegistrationStep5Txt := this.AppRegistrationStep5Lbl;
        this.MobileNAVStep1Txt := this.MobileNAVStep1Lbl;
        this.MobileNAVStep2Txt := this.MobileNAVStep2Lbl;
        this.MobileNAVStep3Txt := this.MobileNAVStep3Lbl;
        this.SuppliedStep1Txt := this.SuppliedStep1Lbl;
        this.SuppliedStep2Txt := this.SuppliedStep2Lbl;
        this.SuppliedStep3Txt := this.SuppliedStep3Lbl;
        this.SuppliedStep4Txt := this.SuppliedStep4Lbl;
        this.AboutTxt := this.Texts.AboutText();
    end;

    /// <summary>Shows the steps of the token source the page passes in, and hides the other two.</summary>
    /// <param name="Source">The ordinal of the token source that the emulator setup selects: 0 App Registration, 1 MobileNAV Token, 2 Supplied Token.</param>
    procedure SetTokenSource(Source: Integer)
    begin
        this.AppRegistrationSource := Source = "BJF MN Emulator Token Source"::AppRegistration.AsInteger();
        this.MobileNAVSource := Source = "BJF MN Emulator Token Source"::MobileNAVToken.AsInteger();
        this.SuppliedSource := Source = "BJF MN Emulator Token Source"::SuppliedToken.AsInteger();
        CurrPage.Update(false);
    end;

    var
        Texts: Codeunit "BJF MN Emulator Text";
        AppRegistrationSource: Boolean;
        MobileNAVSource: Boolean;
        SuppliedSource: Boolean;
        AppRegistrationStep1Txt: Text;
        AppRegistrationStep2Txt: Text;
        AppRegistrationStep3Txt: Text;
        AppRegistrationStep4Txt: Text;
        AppRegistrationStep5Txt: Text;
        MobileNAVStep1Txt: Text;
        MobileNAVStep2Txt: Text;
        MobileNAVStep3Txt: Text;
        SuppliedStep1Txt: Text;
        SuppliedStep2Txt: Text;
        SuppliedStep3Txt: Text;
        SuppliedStep4Txt: Text;
        AboutTxt: Text;
        AppRegistrationStep1Lbl: Label '1. In Microsoft Entra ID, register an app. Under Authentication, add a Web platform with the Redirect URI shown in Emulator Setup.', MaxLength = 500;
        AppRegistrationStep2Lbl: Label '2. Under API permissions, add the delegated permission Dynamics 365 Business Central, user_impersonation.', MaxLength = 500;
        AppRegistrationStep3Lbl: Label '3. Under Certificates and secrets, create a client secret.', MaxLength = 500;
        AppRegistrationStep4Lbl: Label '4. In Emulator Setup, enter the Client ID and the client secret. The emulator checks the setup after each change.', MaxLength = 500;
        AppRegistrationStep5Lbl: Label '5. The emulator signs in. When it has no token, it opens the Microsoft sign-in page for you. Connected turns on when the token is there.', MaxLength = 500;
        MobileNAVStep1Lbl: Label '1. Choose Request MobileNAV Token above. It runs the token request of O365 Self-authorization (MobileNAV) for the signed-in user.', MaxLength = 500;
        MobileNAVStep2Lbl: Label '2. Sign in with the O365 Auth. Email shown on the O365 Self-authorization (MobileNAV) page. A private browser session is recommended.', MaxLength = 500;
        MobileNAVStep3Lbl: Label '3. Done. The emulator connects with the token MobileNAV stored. MobileNAV refreshes the token itself when it expires.', MaxLength = 500;
        SuppliedStep1Lbl: Label '1. Download the emulator sign-in script. Choose Download Emulator Sign-in Script (PowerShell) or (Python) above. The file holds no secret.', MaxLength = 500;
        SuppliedStep2Lbl: Label '2. Run the sign-in script. The tenant, the client ID, the company and the environment are filled in. The client ID is the O365 App ID of MobileNAV Master Data. The app registration needs Allow public client flows set to Yes.', MaxLength = 500;
        SuppliedStep3Lbl: Label '3. Sign in. The script shows a code and a web address. Open the address, enter the code and sign in as the user whose screens you want.', MaxLength = 500;
        SuppliedStep4Lbl: Label '4. Done. The script gives the token to the emulator, which uses it for about an hour. Connected turns on when the token is there.', MaxLength = 500;
}

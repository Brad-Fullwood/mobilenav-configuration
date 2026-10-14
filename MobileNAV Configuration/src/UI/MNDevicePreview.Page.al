namespace BradFullwood.MobileNAV.Configuration;

using System.Utilities;

/// <summary>
/// Draws the device pages a provider declares as phone screens, from its definition laid over
/// MobileNAV's live rows: list, card, wizard stages, menu and layout rules. Shown as a FactBox on the
/// MobileNAV Configuration page, following the selected provider. The screens are slides of one carousel, and the drawing downloads as HTML.
/// </summary>
page 77726 "BJF MN Device Preview"
{
    ApplicationArea = All;
    Caption = 'MobileNAV Device Preview';
    PageType = CardPart;

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Options';

                field(LanguageField; this.LanguageCode)
                {
                    Caption = 'Language';
                    ToolTip = 'Specifies the MobileNAV language code the captions are drawn in, for example ENU or DEU.';

                    trigger OnValidate()
                    begin
                        this.Refresh();
                    end;
                }
            }
            group(Note)
            {
                ShowCaption = false;

                field(PreviewNote; this.PreviewNoteLbl)
                {
                    Editable = false;
                    ShowCaption = false;
                    ToolTip = 'Specifies how the drawing is made: it is built from the provider and the current MobileNAV rows, and nothing is stored.';
                }
            }
            group(Device)
            {
                ShowCaption = false;

                usercontrol(Viewer; "BJF MN HTML Viewer")
                {
                    trigger ControlReady()
                    begin
                        this.ViewerReady := true;
                        this.Refresh();
                    end;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        if this.LanguageCode = '' then
            this.LanguageCode := this.ScreenRenderer.SessionLanguageCode();
    end;

    /// <summary>Shows the device pages of a provider. Draws again only when the provider changes.</summary>
    /// <param name="NewProviderType">The provider to draw.</param>
    procedure SetProvider(NewProviderType: Enum "BJF MN Config Provider")
    begin
        if NewProviderType = this.ProviderType then
            exit;
        this.ProviderType := NewProviderType;
        if this.ViewerReady then
            this.Refresh();
    end;

    /// <summary>Downloads the device pages of the provider as one HTML file, in the language of the Language field.</summary>
    procedure DownloadDrawing()
    var
        TempBlob: Codeunit "Temp Blob";
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        HtmlOutStream: OutStream;
        HtmlInStream: InStream;
        FileName: Text;
    begin
        if this.ProviderType = Enum::"BJF MN Config Provider"::None then
            Error(this.ChooseProviderLbl);
        this.ProviderCatalog.GetMetadata(this.ProviderType, ProviderId, ProviderName, ProviderDescription);
        this.Html := this.ScreenRenderer.Render(this.ProviderType, this.LanguageCode);
        TempBlob.CreateOutStream(HtmlOutStream, TextEncoding::UTF8);
        HtmlOutStream.WriteText(this.Html);
        TempBlob.CreateInStream(HtmlInStream, TextEncoding::UTF8);
        FileName := StrSubstNo(this.FileNameTok, ProviderId, this.LanguageCode);
        DownloadFromStream(HtmlInStream, '', '', '', FileName);
    end;

    local procedure Refresh()
    begin
        if this.ProviderType = Enum::"BJF MN Config Provider"::None then
            this.Html := StrSubstNo(this.EmptyPageTok, this.ChooseProviderLbl)
        else
            this.Html := this.ScreenRenderer.Render(this.ProviderType, this.LanguageCode);
        if this.ViewerReady then
            CurrPage.Viewer.SetContent(this.Html);
    end;

    var
        ScreenRenderer: Codeunit "BJF MN Screen Renderer";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ProviderType: Enum "BJF MN Config Provider";
        LanguageCode: Code[10];
        Html: Text;
        ViewerReady: Boolean;
        ChooseProviderLbl: Label 'Choose a provider to draw its device pages.';
        PreviewNoteLbl: Label 'The drawing is built live from the provider''s code and MobileNAV''s current rows each time it is shown, not stored.';
        EmptyPageTok: Label '<!doctype html><html><body style="font-family:system-ui,sans-serif;color:rgb(84,110,122);padding:24px">%1</body></html>', Locked = true, Comment = '%1 = message';
        FileNameTok: Label 'device-preview-%1-%2.html', Locked = true, Comment = '%1 = provider id, %2 = language code';
}

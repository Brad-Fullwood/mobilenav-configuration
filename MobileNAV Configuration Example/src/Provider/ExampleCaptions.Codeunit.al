namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Answers for the captions the provider marks with TranslatedCaptions(). The framework makes
/// each language MobileNAV supports the session language in turn and raises the event, so a Label
/// here resolves to the translation in Translations/*.xlf, and the translators need no
/// MobileNAV knowledge. Answer only for your own page and control and leave Handled false for the rest.
/// </summary>
codeunit 50105 "Example Captions"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Config Application", OnGetTranslatedCaption, '', false, false)]
    local procedure "BJF MN Config Application_OnGetTranslatedCaption"(PageId: Integer; ControlName: Text; var Caption: Text; var Handled: Boolean)
    begin
        case true of
            (PageId = Page::"Example Stock Count") and (ControlName = ''):
                Caption := this.StockCountCaptionLbl;
            (PageId = Page::"MobileNAV Item") and (ControlName = 'ExampleNotes'):
                Caption := this.ExampleNotesCaptionLbl;
            else
                exit;
        end;
        Handled := true;
    end;

    var
        StockCountCaptionLbl: Label 'Stock Count', MaxLength = 250;
        ExampleNotesCaptionLbl: Label 'Warehouse notes', MaxLength = 250;
}

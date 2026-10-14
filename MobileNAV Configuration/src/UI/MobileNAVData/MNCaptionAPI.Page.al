namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's captions per language, read-only: one row per page, control and language.
/// Control ID 0 is the page itself. Filter on pageId.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/captionTranslations.
/// </summary>
page 77738 "BJF MN Caption API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV CaptionML Admin.';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV CaptionML Admin.';
    EntityName = 'captionTranslation';
    EntitySetCaption = 'MobileNAV CaptionML Admin.';
    EntitySetName = 'captionTranslations';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV CaptionML Admin." = r;
    SourceTable = "MobileNAV CaptionML Admin.";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(pageId; Rec."Page ID") { }
                field(controlId; Rec."Control ID") { }
                field(languageCode; Rec."Language Code") { }
                field(caption; Rec."Caption ML") { }
            }
        }
    }
}

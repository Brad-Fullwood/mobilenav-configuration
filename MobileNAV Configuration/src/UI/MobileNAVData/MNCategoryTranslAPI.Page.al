namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's category descriptions per language, read-only. Filter on category.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/categoryTranslations.
/// </summary>
page 77739 "BJF MN Category Transl. API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Category Transl.';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Category Transl.';
    EntityName = 'categoryTranslation';
    EntitySetCaption = 'MobileNAV Category Transl.';
    EntitySetName = 'categoryTranslations';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Category Transl." = r;
    SourceTable = "MobileNAV Category Transl.";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(category; Rec.Category) { }
                field(languageCode; Rec."Language Code") { }
                field(description; Rec.Description) { }
            }
        }
    }
}

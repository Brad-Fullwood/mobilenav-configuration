namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Writes MobileNAV master data a definition declares: categories with their translations, and profiles.</summary>
codeunit 77767 "BJF MN Master Data Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = rim,
        tabledata "MobileNAV Category Transl." = rim;

    /// <summary>Creates the category or updates its description. Order is MobileNAV's own append-to-end default.</summary>
    procedure EnsureCategory(CategoryCode: Code[20]; Description: Text[250])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if this.FindCategory(CategoryCode, MasterData) then begin
            if (Description = '') or (MasterData.Description = Description) then
                exit;
            MasterData.Validate(Description, CopyStr(Description, 1, MaxStrLen(MasterData.Description)));
            MasterData.Modify(false);
            exit;
        end;
        MasterData.Init();
        MasterData.Validate(Type, MasterData.Type::Category);
        MasterData.Validate(Code, CategoryCode);
        MasterData.Validate(Description, CopyStr(Description, 1, MaxStrLen(MasterData.Description)));
        MasterData.Insert(true);
    end;

    procedure FindCategory(CategoryCode: Code[20]; var MasterData: Record "MobileNAV Master Data"): Boolean
    begin
        exit(MasterData.Get(MasterData.Type::Category, CategoryCode, 0, '', MasterData.Area::Normal));
    end;

    procedure EnsureCategoryTranslation(CategoryCode: Code[20]; LanguageCode: Code[10]; Description: Text[250])
    var
        CategoryTranslation: Record "MobileNAV Category Transl.";
    begin
        if CategoryTranslation.Get(CategoryCode, LanguageCode) then begin
            if CategoryTranslation.Description = Description then
                exit;
            CategoryTranslation.Validate(Description, CopyStr(Description, 1, MaxStrLen(CategoryTranslation.Description)));
            CategoryTranslation.Modify(false);
            exit;
        end;
        CategoryTranslation.Init();
        CategoryTranslation.Validate(Category, CategoryCode);
        CategoryTranslation.Validate("Language Code", LanguageCode);
        CategoryTranslation.Validate(Description, CopyStr(Description, 1, MaxStrLen(CategoryTranslation.Description)));
        CategoryTranslation.Insert(false);
    end;

    /// <summary>Creates the profile or updates its description, as MobileNAV's own import does.</summary>
    procedure EnsureProfile(ProfileCode: Code[30]; Description: Text[250])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if this.FindProfile(ProfileCode, MasterData) then begin
            if (Description = '') or (MasterData.Description = Description) then
                exit;
            MasterData.Validate(Description, CopyStr(Description, 1, MaxStrLen(MasterData.Description)));
            MasterData.Modify(false);
            exit;
        end;
        MasterData.Init();
        MasterData.Validate(Type, MasterData.Type::Profile);
        MasterData.Validate(Code, CopyStr(ProfileCode, 1, MaxStrLen(MasterData.Code)));
        MasterData.Validate(Description, CopyStr(Description, 1, MaxStrLen(MasterData.Description)));
        MasterData.Insert(false);
    end;

    procedure FindProfile(ProfileCode: Code[30]; var MasterData: Record "MobileNAV Master Data"): Boolean
    begin
        exit(MasterData.Get(MasterData.Type::Profile, CopyStr(ProfileCode, 1, MaxStrLen(MasterData.Code)), 0, '', MasterData.Area::Normal));
    end;
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every MobileNAV profile carry what the provider declared? MobileNAV resolves the device
/// screen from profile rows, which override the service-level rows outright: a published page
/// needs a Page row in every profile it can be reached in (all of them with a menu tile, otherwise
/// those that carry a parent page), and a link's target needs a Parent Page row in every profile
/// the parent page belongs to, or the button is not drawn. Field rows are different: MobileNAV
/// keeps one only where a profile deviates from the service row (its hierarchy rebuild drops
/// the rest as inherited), so a missing row is healthy and only a row that contradicts the
/// declaration or excludes the control is a problem.
/// </summary>
codeunit 77796 "BJF Check Config Profiles" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Profile Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.CheckProvider(Finding, TempProvider);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        Kind: Text;
        Args: List of [Text];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        case Kind of
            this.PageFixTok:
                this.ProfileManagement.IncludePageInProfiles(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 30));
            this.PageDropTok:
                this.ProfileManagement.RemovePageFromProfile(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 30));
            this.CategoryFixTok:
                this.ProfileManagement.SetPageCategory(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(3), 1, 20));
            this.MenuFixTok:
                this.ApplyMenuFix(Args);
            this.ParentFixTok:
                this.ProfileManagement.LinkPageToParent(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100), CopyStr(Args.Get(3), 1, 30));
            this.FieldFixTok:
                this.ApplyFieldFix(Args);
            else
                Error(this.NoAutomaticFixErr);
        end;
    end;

    local procedure ApplyMenuFix(Args: List of [Text])
    var
        Visible: Boolean;
    begin
        Evaluate(Visible, Args.Get(3));
        if not this.ProfileManagement.SetPageMenuVisibility(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 30), Visible) then
            Error(this.MenuUnreachableErr, Args.Get(1), Args.Get(2));
    end;

    local procedure ApplyFieldFix(Args: List of [Text])
    var
        Visible: Boolean;
        Editable: Boolean;
    begin
        Evaluate(Visible, Args.Get(4));
        Evaluate(Editable, Args.Get(5));
        this.ProfileManagement.ConfigureProfileField(
            CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100), CopyStr(Args.Get(3), 1, 30), Visible, Editable);
    end;

    local procedure CheckProvider(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary)
    var
        TempLine: Record "BJF MN Config Line" temporary;
        TempProperty: Record "BJF MN Config Property" temporary;
        Profiles: List of [Code[30]];
        FieldProfiles: List of [Code[30]];
        ParentsByPage: Dictionary of [Integer, List of [Text]];
        OwnCategoryProfiles: List of [Text];
    begin
        this.Support.BuildDefinition(TempProvider.Provider, TempLine, TempProperty);
        this.Support.ListProfiles(Profiles);
        this.Support.ListFieldProfiles(FieldProfiles);
        this.CollectParents(TempLine, ParentsByPage);
        this.CollectProfileCategories(TempLine, OwnCategoryProfiles);

        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempLine.FindSet() then
            repeat
                this.CheckPageRows(Finding, TempProvider, TempLine, TempProperty, ParentsByPage, OwnCategoryProfiles, Profiles);
            until TempLine.Next() = 0;

        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Linked Field");
        if TempLine.FindSet() then
            repeat
                this.CheckParentRows(Finding, TempProvider, TempLine, Profiles);
            until TempLine.Next() = 0;

        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Field");
        if TempLine.FindSet() then
            repeat
                this.CheckFieldRows(Finding, TempProvider, TempLine, FieldProfiles);
            until TempLine.Next() = 0;
    end;

    local procedure CheckPageRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; var TempProperty: Record "BJF MN Config Property" temporary; ParentsByPage: Dictionary of [Integer, List of [Text]]; OwnCategoryProfiles: List of [Text]; Profiles: List of [Code[30]])
    var
        ServiceName: Text[100];
        Profile: Code[30];
        Category: Code[20];
        Parents: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        if not Line."Show In Menu" and this.Lookup.IsMobileNAVPage(Line."Page ID") then
            exit; // The administrator's profile rows stay, see "BJF MN Config Application".KeepsAdministratorProfiles.
        Category := this.ProfileManagement.DeclaredMenuCategory(TempProperty, Line."Page ID");
        if not Line."Show In Menu" then
            Parents := this.ParentPages(Line, ServiceName, ParentsByPage);
        foreach Profile in Profiles do
            this.CheckPageRowInProfile(Finding, TempProvider, Line, ServiceName, Profile, Category, Parents, OwnCategoryProfiles);
    end;

    local procedure ParentPages(Line: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; ParentsByPage: Dictionary of [Integer, List of [Text]]) Parents: List of [Text]
    begin
        if ParentsByPage.ContainsKey(Line."Page ID") then
            Parents := ParentsByPage.Get(Line."Page ID");
        // The apply falls back to the relations MobileNAV already has to the page.
        if Parents.Count() = 0 then
            Parents := this.Lookup.RelationSources(ServiceName);
        exit(Parents);
    end;

    local procedure CheckPageRowInProfile(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; Profile: Code[30]; Category: Code[20]; Parents: List of [Text]; OwnCategoryProfiles: List of [Text])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        // A page without a tile belongs only where a parent page can open it. Where no parent
        // is collected, a row that is excluded from the profile says the same thing and stays.
        if not Line."Show In Menu" and not this.ProfileManagement.AnyParentInProfile(Parents, Profile) then begin
            this.CheckOrphanPageRow(Finding, TempProvider, ServiceName, Profile);
            exit;
        end;
        if not this.ProfileManagement.FindPageRow(ServiceName, Profile, ProfileSetup) or ProfileSetup."Exclude from Profile" then begin
            Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Blocker,
                this.Support.Prefix(TempProvider, StrSubstNo(this.PageMissingMsg, ServiceName, Profile)),
                Finding."Related Record ID", StrSubstNo(this.PageFixMsg, ServiceName, Profile),
                this.Support.PackFix(this.PageFixTok, this.FixArgs(ServiceName, Profile)));
            exit;
        end;
        this.CheckMenuTile(Finding, TempProvider, Line, ServiceName, Profile, ProfileSetup);
        this.CheckProfileCategory(Finding, TempProvider, Line, ServiceName, Profile, Category, ProfileSetup, OwnCategoryProfiles);
    end;

    local procedure CheckOrphanPageRow(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; ServiceName: Text[100]; Profile: Code[30])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if this.ProfileManagement.FindPageRow(ServiceName, Profile, ProfileSetup) and not ProfileSetup."Exclude from Profile" then
            Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Warning,
                this.Support.Prefix(TempProvider, StrSubstNo(this.PageOrphanMsg, ServiceName, Profile)),
                ProfileSetup.RecordId(), StrSubstNo(this.PageDropMsg, ServiceName, Profile),
                this.Support.PackFix(this.PageDropTok, this.FixArgs(ServiceName, Profile)));
    end;

    local procedure CheckMenuTile(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; Profile: Code[30]; ProfileSetup: Record "MobileNAV Profile Setup")
    var
        Args: List of [Text];
    begin
        if ProfileSetup."Display in Menu" = Line."Show In Menu" then
            exit;
        Args := this.FixArgs(ServiceName, Profile);
        Args.Add(Format(Line."Show In Menu"));
        Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Warning,
            this.Support.Prefix(TempProvider, StrSubstNo(this.MenuWrongMsg, ServiceName, Profile, Format(Line."Show In Menu"), Format(ProfileSetup."Display in Menu"))),
            ProfileSetup.RecordId(), StrSubstNo(this.MenuFixMsg, ServiceName, Profile),
            this.Support.PackFix(this.MenuFixTok, Args));
    end;

    /// <summary>
    /// The device groups the home menu by the profile row's category, not the service one. A
    /// profile the declaration gives its own category belongs to the master data check, which
    /// reads that declaration.
    /// </summary>
    /// <param name="Finding">Receives a finding when the category differs.</param>
    /// <param name="TempProvider">The provider that declared the page.</param>
    /// <param name="Line">The published page.</param>
    /// <param name="ServiceName">The service the page is registered as.</param>
    /// <param name="Profile">The profile being checked.</param>
    /// <param name="Category">The category MenuCategory() declared, or blank.</param>
    /// <param name="ProfileSetup">The page's row in the profile.</param>
    /// <param name="OwnCategoryProfiles">The pages and profiles with a category of their own.</param>
    local procedure CheckProfileCategory(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; Profile: Code[30]; Category: Code[20]; ProfileSetup: Record "MobileNAV Profile Setup"; OwnCategoryProfiles: List of [Text])
    var
        Args: List of [Text];
    begin
        if (Category = '') or (ProfileSetup.Category = Category) then
            exit;
        if OwnCategoryProfiles.Contains(this.CategoryKey(Line."Page ID", Profile)) then
            exit;
        Args := this.FixArgs(ServiceName, Profile);
        Args.Add(Category);
        Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Warning,
            this.Support.Prefix(TempProvider, StrSubstNo(this.CategoryWrongMsg, ServiceName, Profile, Category, ProfileSetup.Category)),
            ProfileSetup.RecordId(), StrSubstNo(this.CategoryFixMsg, ServiceName, Profile, Category),
            this.Support.PackFix(this.CategoryFixTok, Args));
    end;

    local procedure FixArgs(ServiceName: Text[100]; Profile: Code[30]) Args: List of [Text]
    begin
        Args.Add(ServiceName);
        Args.Add(Profile);
        exit(Args);
    end;

    /// <summary>
    /// For each page a link or lookup opens, the service names of the pages that open it. Built
    /// from the whole definition before it is filtered to published pages: a temporary record
    /// passed by value carries only the rows its filters let through, so a copy taken inside the
    /// published-page loop holds no link rows and every page looks unreachable.
    /// </summary>
    /// <param name="TempLine">The provider's definition. Filters are reset on exit.</param>
    /// <param name="ParentsByPage">Receives the parent service names by target page ID.</param>
    local procedure CollectParents(var TempLine: Record "BJF MN Config Line" temporary; var ParentsByPage: Dictionary of [Integer, List of [Text]])
    var
        ParentService: Text[100];
        Parents: List of [Text];
    begin
        TempLine.Reset();
        TempLine.SetRelationFilter();
        if TempLine.FindSet() then
            repeat
                ParentService := this.Support.GetServiceName(TempLine."Page ID");
                if ParentService <> '' then begin
                    Clear(Parents);
                    if ParentsByPage.ContainsKey(TempLine."Target Page ID") then
                        Parents := ParentsByPage.Get(TempLine."Target Page ID");
                    if not Parents.Contains(ParentService) then begin
                        Parents.Add(ParentService);
                        ParentsByPage.Set(TempLine."Target Page ID", Parents);
                    end;
                end;
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    /// <summary>The pages and profiles MenuCategoryInProfile() gives a category of their own.</summary>
    /// <param name="TempLine">The provider's definition. Filters are reset on exit.</param>
    /// <param name="OwnCategoryProfiles">Receives one key per page and profile, built by CategoryKey().</param>
    local procedure CollectProfileCategories(var TempLine: Record "BJF MN Config Line" temporary; var OwnCategoryProfiles: List of [Text])
    begin
        TempLine.Reset();
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Page");
        TempLine.SetFilter("Menu Category", '<>%1', '');
        if TempLine.FindSet() then
            repeat
                OwnCategoryProfiles.Add(this.CategoryKey(TempLine."Page ID", TempLine.Profile));
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    local procedure CategoryKey(PageId: Integer; Profile: Code[30]): Text
    begin
        exit(StrSubstNo(this.CategoryKeyTok, PageId, Profile));
    end;

    local procedure CheckParentRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; Profiles: List of [Code[30]])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        ParentService: Text[100];
        ChildService: Text[100];
        Profile: Code[30];
        Args: List of [Text];
    begin
        ParentService := this.Support.GetServiceName(Line."Page ID");
        ChildService := this.Support.GetServiceName(Line."Target Page ID");
        if (ParentService = '') or (ChildService = '') then
            exit;
        foreach Profile in Profiles do begin
            // A profile that does not carry the parent page, or excludes it, cannot show the
            // button anyway.
            if not this.ProfileManagement.FindPageRow(ParentService, Profile, ProfileSetup) then
                continue;
            if ProfileSetup."Exclude from Profile" then
                continue;
            ProfileSetup.Reset();
            ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::"Parent Page");
            ProfileSetup.SetRange(ID, ChildService);
            ProfileSetup.SetRange(Profile, Profile);
            ProfileSetup.SetRange(Parent, ParentService);
            if ProfileSetup.IsEmpty() then begin
                Clear(Args);
                Args.Add(ChildService);
                Args.Add(ParentService);
                Args.Add(Profile);
                Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Blocker,
                    this.Support.Prefix(TempProvider, StrSubstNo(this.ParentMissingMsg, Line."Control Name", ParentService, ChildService, Profile)),
                    Finding."Related Record ID", StrSubstNo(this.ParentFixMsg, ChildService, ParentService, Profile),
                    this.Support.PackFix(this.ParentFixTok, Args));
            end;
        end;
    end;

    local procedure CheckFieldRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; AllProfiles: List of [Code[30]])
    var
        FieldRow: Record "MobileNAV Service Setup";
        ProfileSetup: Record "MobileNAV Profile Setup";
        ServiceName: Text[100];
        Profiles: List of [Code[30]];
        Profile: Code[30];
        Args: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        if not this.Lookup.FindFieldRow(ServiceName, Line."Control Name", FieldRow) then
            exit; // Reported by the field check.
        if Line.Profile <> '' then
            Profiles.Add(Line.Profile)
        else
            Profiles := AllProfiles;

        ProfileSetup.SetLoadFields("Exclude from Profile", "Visible Inherited", Visible, "Editable Inherited", Editable);
        foreach Profile in Profiles do begin
            // No row means the profile inherits the service row, which the field check covers.
            if not ProfileSetup.Get(ProfileSetup."Profile Type"::Field, ServiceName, Profile, FieldRow.ControlID) then
                continue;
            if this.IsRowWrong(ProfileSetup, Line) then begin
                Clear(Args);
                Args.Add(ServiceName);
                Args.Add(Line."Control Name");
                Args.Add(Profile);
                Args.Add(Format(Line.Visible));
                Args.Add(Format(Line.Editable));
                Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Blocker,
                    this.Support.Prefix(TempProvider, StrSubstNo(this.FieldWrongMsg, Line."Control Name", ServiceName, Profile, Line.Visible, Line.Editable)),
                    Finding."Related Record ID", StrSubstNo(this.FieldFixMsg, Line."Control Name", Profile),
                    this.Support.PackFix(this.FieldFixTok, Args));
            end;
        end;
    end;

    /// <summary>Whether a profile field row contradicts the provider's declaration for it.</summary>
    /// <param name="ProfileSetup">The profile field row.</param>
    /// <param name="Line">The declared profile field.</param>
    /// <returns>True when the row excludes the control or overrides its visibility or editability against the declaration.</returns>
    local procedure IsRowWrong(ProfileSetup: Record "MobileNAV Profile Setup"; Line: Record "BJF MN Config Line" temporary): Boolean
    var
        Wrong: Boolean;
    begin
        Wrong := ProfileSetup."Exclude from Profile";
        if not Wrong and not ProfileSetup."Visible Inherited" then
            Wrong := ProfileSetup.Visible <> Line.Visible;
        if not Wrong and not ProfileSetup."Editable Inherited" then
            Wrong := ProfileSetup.Editable <> Line.Editable;
        exit(Wrong);
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        ProfileManagement: Codeunit "BJF MN Profile Mgt.";
        PageOrphanMsg: Label 'Page %1 has a row in profile %2, but it has no menu tile and none of its parent pages is in that profile, so devices there cannot reach it and the apply cannot hide its tile.', Comment = '%1 = service, %2 = profile';
        PageDropMsg: Label 'Remove page %1 from profile %2.', Comment = '%1 = service, %2 = profile';
        CategoryWrongMsg: Label 'Page %1 in profile %2: the menu category is declared %3 but the profile row has %4, so the tile sits in the wrong group on the device.', Comment = '%1 = service, %2 = profile, %3 = declared category, %4 = category on the row';
        CategoryFixMsg: Label 'Set the menu category of page %1 in profile %2 to %3.', Comment = '%1 = service, %2 = profile, %3 = category';
        CategoryFixTok: Label 'CATEGORY', Locked = true;
        CategoryKeyTok: Label '%1|%2', Locked = true;
        PageDropTok: Label 'PROFILEDROP', Locked = true;
        MenuWrongMsg: Label 'Page %1 in profile %2 is declared with a home menu tile %3 but MobileNAV has %4; the device menu follows the profile row.', Comment = '%1 = service, %2 = profile, %3 = declared, %4 = live';
        MenuFixMsg: Label 'Set the menu tile for %1 in profile %2 as declared.', Comment = '%1 = service, %2 = profile';
        MenuUnreachableErr: Label 'Page %1 in profile %2 has no parent link, so hiding its tile would remove it from the profile. Declare ShowInMenu() or a Link.', Comment = '%1 = service, %2 = profile';
        MenuFixTok: Label 'PROFILEMENU', Locked = true;
        PageMissingMsg: Label 'Page %1 is missing from profile %2 (or excluded from it), so the profile''s devices cannot reach it and any button opening it is hidden.', Comment = '%1 = service, %2 = profile';
        PageFixMsg: Label 'Add page %1 to profile %2.', Comment = '%1 = service, %2 = profile';
        ParentMissingMsg: Label 'Button %1 on %2 opens %3, but profile %4 has no parent link between them, so the button is not drawn.', Comment = '%1 = control, %2 = parent service, %3 = child service, %4 = profile';
        ParentFixMsg: Label 'Link %1 under %2 in profile %3.', Comment = '%1 = child, %2 = parent, %3 = profile';
        FieldWrongMsg: Label 'Control %1 on %2 is overridden in profile %3 against its declaration (visible %4, editable %5), and the profile row is what the device obeys.', Comment = '%1 = control, %2 = service, %3 = profile, %4 = visible, %5 = editable';
        FieldFixMsg: Label 'Write the profile row for %1 in profile %2.', Comment = '%1 = control, %2 = profile';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        PageFixTok: Label 'PROFILEPAGE', Locked = true;
        ParentFixTok: Label 'PROFILEPARENT', Locked = true;
        FieldFixTok: Label 'PROFILEFIELD', Locked = true;
}

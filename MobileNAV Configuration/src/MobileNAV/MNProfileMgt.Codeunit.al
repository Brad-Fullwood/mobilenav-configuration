namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes the per-profile rows MobileNAV resolves a device screen from. A profile row for a
/// control overrides the service-level row outright, and MobileNAV creates those rows itself
/// when it rebuilds a profile's page hierarchy; a control it has never been told about is not
/// visible in the rebuilt profile. The same goes for pages: a profile only collects a page it
/// has a Page row for, and only draws a link once the target is reachable through a Parent
/// Page row.
///
/// Profile Setup's OnValidate triggers cascade across the hierarchy and raise Confirm dialogs,
/// which an unattended apply cannot answer, so the rows are assigned directly and inserted
/// without triggers, as MobileNAV's own AddParent does.
/// </summary>
codeunit 77791 "BJF MN Profile Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Profile Setup" = rimd;

    /// <summary>
    /// Writes the control's row for one profile, or for every profile that has a user when none
    /// is named. The row is per profile, so a profile shared by several users is written once.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ControlName">The control name on the page.</param>
    /// <param name="Profile">The MobileNAV profile code. Empty means every profile.</param>
    /// <param name="Visible">Whether the control is visible.</param>
    /// <param name="Editable">Whether the control is editable.</param>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureProfileField(ServiceName: Text[100]; ControlName: Text[100]; Profile: Code[30]; Visible: Boolean; Editable: Boolean): Boolean
    var
        FieldRow: Record "MobileNAV Service Setup";
        ProfileSetup: Record "MobileNAV Profile Setup";
        WrittenProfiles: List of [Code[30]];
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, FieldRow) then
            exit(false);

        if Profile <> '' then begin
            this.WriteProfileField(ServiceName, FieldRow.ControlID, Profile, Visible, Editable);
            exit(true);
        end;
        ProfileSetup.SetLoadFields(Profile);
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        if ProfileSetup.FindSet() then
            repeat
                if not WrittenProfiles.Contains(ProfileSetup.Profile) then begin
                    WrittenProfiles.Add(ProfileSetup.Profile);
                    this.WriteProfileField(ServiceName, FieldRow.ControlID, ProfileSetup.Profile, Visible, Editable);
                end;
            until ProfileSetup.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// Gives the page a Page row (a tile, and a place in the menu) in one profile, or in every
    /// profile when none is named. The row is created the way MobileNAV's Main Menu Editor
    /// creates it, so MobileNAV fills in the page number, table number and page type itself.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Profile">The MobileNAV profile code. Empty means every profile.</param>
    procedure IncludePageInProfiles(ServiceName: Text[100]; Profile: Code[30])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if Profile <> '' then begin
            this.IncludePageInProfile(ServiceName, Profile);
            exit;
        end;
        MasterData.SetLoadFields(Code);
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                this.IncludePageInProfile(ServiceName, MasterData.Code);
            until MasterData.Next() = 0;
    end;

    /// <summary>
    /// Gives a page that is reached only through links a Page row in each profile where one of
    /// its declared parent pages has a row, and takes it out of the other profiles. A profile
    /// that does not carry the parent has no way to open the page, and MobileNAV deletes a Page
    /// row that is neither on the menu nor linked, so leaving one there only fails the apply.
    /// </summary>
    /// <param name="ServiceName">The page's service name.</param>
    /// <param name="Parents">Service names of the pages whose links open it.</param>
    procedure IncludePageWhereParentExists(ServiceName: Text[100]; Parents: List of [Text])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        MasterData.SetLoadFields(Code);
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                if this.AnyParentInProfile(Parents, MasterData.Code) then
                    this.IncludePageInProfile(ServiceName, MasterData.Code)
                else
                    this.RemovePageFromProfile(ServiceName, MasterData.Code);
            until MasterData.Next() = 0;
    end;

    /// <summary>
    /// Whether any of the given pages has a Page row in the profile that the profile's devices
    /// actually collect. A row excluded from the profile does not count: MobileNAV never sends
    /// that page there, so nothing on it can open a child page either.
    /// </summary>
    /// <param name="Parents">Service names of candidate parent pages.</param>
    /// <param name="Profile">The profile to look in.</param>
    /// <returns>True when at least one parent has a Page row there.</returns>
    procedure AnyParentInProfile(Parents: List of [Text]; Profile: Code[30]): Boolean
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        Parent: Text;
    begin
        foreach Parent in Parents do
            if this.FindPageRow(CopyStr(Parent, 1, 100), Profile, ProfileSetup) then
                if not ProfileSetup."Exclude from Profile" then
                    exit(true);
        exit(false);
    end;

    /// <summary>Removes the page's Page row and its Parent Page rows from one profile.</summary>
    /// <param name="ServiceName">The page's service name.</param>
    /// <param name="Profile">The profile to remove it from.</param>
    procedure RemovePageFromProfile(ServiceName: Text[100]; Profile: Code[30])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        ProfileSetup.SetRange(Profile, Profile);
        ProfileSetup.SetRange(ID, CopyStr(ServiceName, 1, MaxStrLen(ProfileSetup.ID)));
        ProfileSetup.SetFilter("Profile Type", '%1|%2', ProfileSetup."Profile Type"::Page, ProfileSetup."Profile Type"::"Parent Page");
        ProfileSetup.DeleteAll(false);
    end;

    /// <summary>
    /// Shows or hides the page's tile on the device home menu in one profile, or in every profile
    /// when none is named. The device menu is built from the profile Page row's own flag, not the
    /// service-level one. MobileNAV drops a Page row that is neither on the menu nor linked from a
    /// parent, so this runs after the parent links exist.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Profile">The MobileNAV profile code. Empty means every profile.</param>
    /// <param name="Show">True to show the page in the menu.</param>
    /// <returns>False when hiding the page would delete its row because no parent links to it.</returns>
    procedure SetPageMenuVisibility(ServiceName: Text[100]; Profile: Code[30]; Show: Boolean): Boolean
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if Profile <> '' then
            exit(this.SetPageMenuVisibilityInProfile(ServiceName, Profile, Show));
        MasterData.SetLoadFields(Code);
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                if not this.SetPageMenuVisibilityInProfile(ServiceName, MasterData.Code, Show) then
                    exit(false);
            until MasterData.Next() = 0;
        exit(true);
    end;

    local procedure SetPageMenuVisibilityInProfile(ServiceName: Text[100]; Profile: Code[30]; Show: Boolean): Boolean
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        MustDelete: Boolean;
    begin
        if not this.FindPageRow(ServiceName, Profile, ProfileSetup) then
            exit(true);
        if ProfileSetup."Display in Menu" = Show then
            exit(true);
        // MobileNAV's own validation adds or removes the root row; no confirmation is requested.
        ProfileSetup.ValidateDisplayInMenu(Show, false, MustDelete);
        if MustDelete then
            exit(false);
        ProfileSetup.Modify(false);
        exit(true);
    end;

    /// <summary>
    /// Makes the child page reachable from the parent page in one profile, or in every profile
    /// when none is named, so a link from the parent to the child is drawn.
    /// </summary>
    /// <param name="ChildServiceName">The service name of the child page.</param>
    /// <param name="ParentServiceName">The service name of the parent page.</param>
    /// <param name="Profile">The MobileNAV profile code. Empty means every profile.</param>
    procedure LinkPageToParent(ChildServiceName: Text[100]; ParentServiceName: Text[100]; Profile: Code[30])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if Profile <> '' then begin
            this.LinkPageToParentInProfile(ChildServiceName, ParentServiceName, Profile);
            exit;
        end;
        MasterData.SetLoadFields(Code);
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                this.LinkPageToParentInProfile(ChildServiceName, ParentServiceName, MasterData.Code);
            until MasterData.Next() = 0;
    end;

    /// <summary>
    /// Sets a page's per-profile switches. Their triggers cascade through the hierarchy and
    /// can confirm, so they are assigned directly, as IncludePageInProfile does.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ProfileCode">The MobileNAV profile code.</param>
    /// <param name="Excluded">Whether the profile leaves the page out.</param>
    /// <param name="Online">Whether the page works online only.</param>
    /// <param name="LookupOnly">Whether the page opens for lookup only.</param>
    /// <param name="CategoryCode">The menu category code.</param>
    procedure ConfigureProfilePage(ServiceName: Text[100]; ProfileCode: Code[30]; Excluded: Boolean; Online: Boolean; LookupOnly: Boolean; CategoryCode: Code[20])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        Category: Code[20];
    begin
        if not this.FindPageRow(ServiceName, ProfileCode, ProfileSetup) then begin
            this.IncludePageInProfile(ServiceName, ProfileCode);
            this.FindPageRow(ServiceName, ProfileCode, ProfileSetup);
        end;
        // A blank category is no declaration at all, so the profile keeps the one it has.
        Category := ProfileSetup.Category;
        if CategoryCode <> '' then
            Category := CategoryCode;
        if (ProfileSetup."Exclude from Profile" = Excluded) and (ProfileSetup."Use as Online" = Online)
            and (ProfileSetup."Lookup Only" = LookupOnly) and (ProfileSetup.Category = Category)
        then
            exit;
#pragma warning disable PC0037
        ProfileSetup."Exclude from Profile" := Excluded;
        ProfileSetup."Use as Online" := Online;
        ProfileSetup."Lookup Only" := LookupOnly;
        ProfileSetup.Category := Category;
#pragma warning restore PC0037
        ProfileSetup.Modify(false);
    end;

    /// <summary>
    /// Files the page's tile under a menu category in every profile that carries it. The device
    /// groups the home menu by the profile Page row's own category, so the service-level one that
    /// MenuCategory() writes decides nothing on its own.
    /// </summary>
    /// <param name="ServiceName">The page's service name.</param>
    /// <param name="CategoryCode">The MobileNAV category code; nothing happens when it is blank.</param>
    procedure SetPageCategory(ServiceName: Text[100]; CategoryCode: Code[20])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if CategoryCode = '' then
            exit;
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::Page);
        ProfileSetup.SetRange(ID, CopyStr(ServiceName, 1, MaxStrLen(ProfileSetup.ID)));
        ProfileSetup.SetRange("Control ID", 0);
        if ProfileSetup.FindSet(true) then
            repeat
                if ProfileSetup.Category <> CategoryCode then begin
                    ProfileSetup.Validate(Category, CategoryCode);
                    ProfileSetup.Modify(true);
                end;
            until ProfileSetup.Next() = 0;
    end;

    /// <summary>The category MenuCategory() declared for the page, or blank when it declared none.</summary>
    /// <param name="TempConfigurationProperty">The provider's declared properties. Filters are reset on exit.</param>
    /// <param name="PageId">The page to read the category for.</param>
    /// <returns>The category code, or blank.</returns>
    procedure DeclaredMenuCategory(var TempConfigurationProperty: Record "BJF MN Config Property" temporary; PageId: Integer): Code[20]
    var
        Category: Code[20];
    begin
        TempConfigurationProperty.Reset();
        TempConfigurationProperty.SetRange("Page ID", PageId);
        TempConfigurationProperty.SetRange("Control Name", '');
        TempConfigurationProperty.SetRange(Setting, this.PropertyCatalog.Setting(Enum::"BJF MN Property"::MenuCategory));
        if TempConfigurationProperty.FindFirst() then
            Category := CopyStr(TempConfigurationProperty.Value, 1, MaxStrLen(Category));
        TempConfigurationProperty.Reset();
        exit(Category);
    end;

    local procedure IncludePageInProfile(ServiceName: Text[100]; Profile: Code[30])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if this.FindPageRow(ServiceName, Profile, ProfileSetup) then begin
            if not ProfileSetup."Exclude from Profile" then
                exit;
#pragma warning disable PC0037
            ProfileSetup."Exclude from Profile" := false;
#pragma warning restore PC0037
            ProfileSetup.Modify(false);
            exit;
        end;

        ProfileSetup.Init();
        ProfileSetup.Validate("Profile Type", ProfileSetup."Profile Type"::Page);
        ProfileSetup.Validate(Profile, Profile);
        ProfileSetup.Validate(ID, CopyStr(ServiceName, 1, MaxStrLen(ProfileSetup.ID)));
        // MobileNAV's "append to the end" sentinel, as its Main Menu Editor writes it.
#pragma warning disable PC0037
        ProfileSetup.Order := 2147483647;
#pragma warning restore PC0037
        ProfileSetup.Insert(true);
    end;

    local procedure LinkPageToParentInProfile(ChildServiceName: Text[100]; ParentServiceName: Text[100]; Profile: Code[30])
    var
        ParentRow: Record "MobileNAV Profile Setup";
        Link: Record "MobileNAV Profile Setup";
        ChildId: Text[100];
        ParentId: Text[100];
        NextControlId: Integer;
    begin
        ChildId := CopyStr(ChildServiceName, 1, MaxStrLen(Link.ID));
        ParentId := CopyStr(ParentServiceName, 1, MaxStrLen(Link.Parent));

        // The parent's Page row supplies the hierarchy properties; IncludePageInProfiles has
        // already written it for every published page.
        if not this.FindPageRow(ParentId, Profile, ParentRow) then
            exit;

        this.CopyRootsFromParent(ChildId, ParentId, Profile);

        Link.SetRange("Profile Type", Link."Profile Type"::"Parent Page");
        Link.SetRange(ID, ChildId);
        Link.SetRange(Profile, Profile);
        Link.SetRange(Parent, ParentId);
        if not Link.IsEmpty() then
            exit;

        // Control ID sequences within child and profile, as MobileNAV's AddParent numbers it.
        Link.SetRange(Parent);
        NextControlId := 1;
        if Link.FindLast() then
            NextControlId := Link."Control ID" + 1;
        Link.Init();
#pragma warning disable PC0037
        Link."Control ID" := NextControlId;
        Link."Profile Type" := Link."Profile Type"::"Parent Page";
        Link.ID := ChildId;
        Link.Profile := Profile;
        Link.Parent := ParentId;
        Link."Exclude from Profile" := ParentRow."Exclude from Profile";
        Link."Lookup Only" := ParentRow."Lookup Only";
        Link."Page Type" := ParentRow."Page Type";
        Link."Use as Online" := ParentRow."Use as Online";
#pragma warning restore PC0037
        Link.Insert(false);
    end;

    /// <summary>
    /// Gives the child every Root Page row the parent has. MobileNAV keeps one Root Page row per
    /// menu page a page is reached from, and deletes a page without a menu tile that has none when
    /// its Display in Menu is cleared. A Parent Page row alone does not add them.
    /// </summary>
    /// <param name="ChildId">The child page's service name.</param>
    /// <param name="ParentId">The parent page's service name.</param>
    /// <param name="Profile">The profile.</param>
    local procedure CopyRootsFromParent(ChildId: Text[100]; ParentId: Text[100]; Profile: Code[30])
    var
        ParentRoot: Record "MobileNAV Profile Setup";
        ChildRoot: Record "MobileNAV Profile Setup";
        NextControlId: Integer;
    begin
        ParentRoot.SetLoadFields(Parent);
        ParentRoot.SetRange("Profile Type", ParentRoot."Profile Type"::"Root Page");
        ParentRoot.SetRange(ID, ParentId);
        ParentRoot.SetRange(Profile, Profile);
        if not ParentRoot.FindSet() then
            exit;
        repeat
            ChildRoot.Reset();
            ChildRoot.SetRange("Profile Type", ChildRoot."Profile Type"::"Root Page");
            ChildRoot.SetRange(ID, ChildId);
            ChildRoot.SetRange(Profile, Profile);
            ChildRoot.SetRange(Parent, ParentRoot.Parent);
            if ChildRoot.IsEmpty() then begin
                // Control ID sequences within child and profile, as MobileNAV's AddRoot numbers it.
                ChildRoot.SetRange(Parent);
                NextControlId := 1;
                if ChildRoot.FindLast() then
                    NextControlId := ChildRoot."Control ID" + 1;
                ChildRoot.Init();
#pragma warning disable PC0037
                ChildRoot."Control ID" := NextControlId;
                ChildRoot."Profile Type" := ChildRoot."Profile Type"::"Root Page";
                ChildRoot.ID := ChildId;
                ChildRoot.Profile := Profile;
                ChildRoot.Parent := ParentRoot.Parent;
#pragma warning restore PC0037
                ChildRoot.Insert(false);
            end;
        until ParentRoot.Next() = 0;
    end;

    /// <summary>
    /// Visible and Editable are marked as not inherited: an inherited value is one MobileNAV may
    /// recompute from the service row, which is what declaring the field for the profile overrides.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ControlId">The MobileNAV control ID.</param>
    /// <param name="Profile">The MobileNAV profile code. Empty means every profile.</param>
    /// <param name="Visible">Whether the control is visible.</param>
    /// <param name="Editable">Whether the control is editable.</param>
    local procedure WriteProfileField(ServiceName: Text[100]; ControlId: Integer; Profile: Code[30]; Visible: Boolean; Editable: Boolean)
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        IsNew: Boolean;
    begin
        IsNew := not ProfileSetup.Get(ProfileSetup."Profile Type"::Field, ServiceName, Profile, ControlId);
#pragma warning disable PC0037
        if IsNew then begin
            ProfileSetup.Init();
            ProfileSetup."Profile Type" := ProfileSetup."Profile Type"::Field;
            ProfileSetup.ID := CopyStr(ServiceName, 1, MaxStrLen(ProfileSetup.ID));
            ProfileSetup.Profile := Profile;
            ProfileSetup."Control ID" := ControlId;
        end;
        ProfileSetup.Visible := Visible;
        ProfileSetup."Visible Inherited" := false;
        ProfileSetup.Editable := Editable;
        ProfileSetup."Editable Inherited" := false;
        ProfileSetup."Exclude from Profile" := false;
#pragma warning restore PC0037
        if IsNew then
            ProfileSetup.Insert(false)
        else
            ProfileSetup.Modify(false);
    end;

    /// <summary>Finds a profile's Page row, filtering "Control ID" = 0 (the field left blank on a partial-key Get).</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Profile">The MobileNAV profile code. Empty means every profile.</param>
    /// <param name="ProfileSetup">The MobileNAV Profile Setup row.</param>
    /// <returns>True when the Page row was found.</returns>
    procedure FindPageRow(ServiceName: Text[100]; Profile: Code[30]; var ProfileSetup: Record "MobileNAV Profile Setup"): Boolean
    begin
        ProfileSetup.Reset();
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::Page);
        ProfileSetup.SetRange(ID, ServiceName);
        ProfileSetup.SetRange(Profile, Profile);
        ProfileSetup.SetRange("Control ID", 0);
        exit(ProfileSetup.FindFirst());
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        PropertyCatalog: Codeunit "BJF MN Property Catalog";
}

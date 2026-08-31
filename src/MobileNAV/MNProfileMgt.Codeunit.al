namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Owns a field's per-profile state.
///
/// MobileNAV resolves a control's visibility in two layers. The service-level field
/// configuration ("MobileNAV Service Setup") is the default, but when a row exists for the
/// control in "MobileNAV Profile Setup" for the profile a device user is on, that row wins
/// outright — MobileNAV's own config builder reads it as
/// `if ProfiledFieldFound then Visible := Profiled.Visible else Visible := Source.Visible`.
///
/// This matters because MobileNAV creates those profile rows itself when it rebuilds the page
/// hierarchy, and a control it has never been told about is not visible in the rebuilt profile.
/// A provider that only sets the service-level row therefore configures a field perfectly and
/// still ships a device screen that does not show it. Declaring the field for the profile is
/// what closes that gap.
///
/// Profile rows are keyed on the control's numeric Control ID rather than its name, so the
/// service-level row is always resolved first to learn it.
/// </summary>
codeunit 77791 "BJF MN Profile Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Profile Setup" = rim,
        tabledata "MobileNAV Service Setup" = r;

    /// <summary>
    /// Makes a control visible for one MobileNAV profile, or for every defined profile when
    /// no profile is named. A profile that has no row for the control yet gets one, so the
    /// declaration survives MobileNAV rebuilding the profile's page hierarchy.
    /// </summary>
    /// <param name="ServiceName">MobileNAV service the field belongs to.</param>
    /// <param name="ControlName">Field's control name on the page.</param>
    /// <param name="Profile">Profile to configure; empty configures every defined profile.</param>
    /// <param name="Visible">Whether the field is shown for the profile.</param>
    /// <param name="Editable">Whether the field can be edited for the profile.</param>
    /// <returns>True when the control exists at service level and at least one profile was written.</returns>
    procedure ConfigureProfileField(ServiceName: Text[100]; ControlName: Text[100]; Profile: Code[30]; Visible: Boolean; Editable: Boolean): Boolean
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        ControlId: Integer;
        Written: Boolean;
    begin
        if not this.TryGetControlId(ServiceName, ControlName, ControlId) then
            exit(false);

        if Profile <> '' then
            exit(this.WriteProfileField(ServiceName, ControlId, Profile, Visible, Editable));

        // Every profile that exists, so a field declared once is not quietly missing for the
        // one profile an administrator happens to put a device user on.
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        if ProfileSetup.FindSet() then
            repeat
                if this.WriteProfileField(ServiceName, ControlId, ProfileSetup.Profile, Visible, Editable) then
                    Written := true;
            until ProfileSetup.Next() = 0;
        exit(Written);
    end;

    /// <summary>
    /// Makes a published page reachable from MobileNAV's profiles.
    ///
    /// Publishing a page registers its web service, which is not the same as a profile being
    /// allowed to use it. MobileNAV collects a user's pages from the profile rows of type Page,
    /// and a page with no such row is not collected. That absence is invisible twice over: the
    /// page has no tile, and any control whose only job is to open it is force-hidden too,
    /// because MobileNAV only draws a relation button once its target page is among the
    /// collected ones. A provider that publishes a page and links a control to it therefore
    /// produces a correct-looking configuration that shows neither.
    ///
    /// The row is created the way MobileNAV's own Main Menu Editor creates it — Validate and
    /// Insert(true) — so MobileNAV fills in the page number, table number and page type from
    /// the registered service rather than this code guessing them.
    /// </summary>
    /// <param name="ServiceName">MobileNAV service to make reachable.</param>
    /// <param name="Profile">Profile to configure; empty configures every defined profile.</param>
    /// <returns>True when at least one profile row was created or updated.</returns>
    procedure IncludePageInProfiles(ServiceName: Text[100]; Profile: Code[30]): Boolean
    var
        MasterData: Record "MobileNAV Master Data";
        Changed: Boolean;
    begin
        if Profile <> '' then
            exit(this.IncludePageInProfile(ServiceName, Profile));

        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                if this.IncludePageInProfile(ServiceName, MasterData.Code) then
                    Changed := true;
            until MasterData.Next() = 0;
        exit(Changed);
    end;

    /// <summary>
    /// Creates or un-excludes one profile's row for the page. Order is MobileNAV's own
    /// "append to the end" sentinel, matching how its Main Menu Editor adds a page.
    /// </summary>
    local procedure IncludePageInProfile(ServiceName: Text[100]; Profile: Code[30]): Boolean
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if ProfileSetup.Get(ProfileSetup."Profile Type"::Page, ServiceName, Profile) then begin
            if not ProfileSetup."Exclude from Profile" and ProfileSetup."Display in Menu" then
                exit(false);
            // Direct assignment: these OnValidate triggers cascade across the profile's page
            // hierarchy and can raise Confirm(), which an unattended apply cannot answer.
#pragma warning disable PC0037
            ProfileSetup."Exclude from Profile" := false;
            ProfileSetup."Display in Menu" := true;
#pragma warning restore PC0037
            ProfileSetup.Modify(false);
            exit(true);
        end;

        Clear(ProfileSetup);
        ProfileSetup.Validate("Profile Type", ProfileSetup."Profile Type"::Page);
        ProfileSetup.Validate(Profile, Profile);
        ProfileSetup.Validate(ID, CopyStr(ServiceName, 1, MaxStrLen(ProfileSetup.ID)));
        ProfileSetup.Order := 2147483647;
        ProfileSetup.Insert(true);
        exit(true);
    end;

    /// <summary>
    /// Registers one page as a child of another in MobileNAV's profile page hierarchy.
    ///
    /// A relation button is drawn only when MobileNAV can reach the target page from the page
    /// the button sits on, and reachability is the hierarchy, not mere presence: the target
    /// needs a Parent Page row naming its parent. Without one the target can be a perfectly
    /// good page with its own tile while the control that is supposed to open it from the
    /// parent stays invisible.
    ///
    /// The row mirrors MobileNAV's own AddParent: the child's properties for the hierarchy are
    /// taken from the parent's page row, and Control ID sequences within child and profile.
    /// </summary>
    /// <param name="ChildServiceName">Service the button opens.</param>
    /// <param name="ParentServiceName">Service the button sits on.</param>
    /// <param name="Profile">Profile to configure; empty configures every defined profile.</param>
    /// <returns>True when at least one parent row was created.</returns>
    procedure LinkPageToParent(ChildServiceName: Text[100]; ParentServiceName: Text[100]; Profile: Code[30]): Boolean
    var
        MasterData: Record "MobileNAV Master Data";
        Created: Boolean;
    begin
        if Profile <> '' then
            exit(this.LinkPageToParentInProfile(ChildServiceName, ParentServiceName, Profile));

        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                if this.LinkPageToParentInProfile(ChildServiceName, ParentServiceName, MasterData.Code) then
                    Created := true;
            until MasterData.Next() = 0;
        exit(Created);
    end;

    local procedure LinkPageToParentInProfile(ChildServiceName: Text[100]; ParentServiceName: Text[100]; Profile: Code[30]): Boolean
    var
        ParentRow: Record "MobileNAV Profile Setup";
        ExistingLink: Record "MobileNAV Profile Setup";
        LastLink: Record "MobileNAV Profile Setup";
        NewLink: Record "MobileNAV Profile Setup";
        ChildId: Text[100];
        ParentId: Text[100];
    begin
        ChildId := CopyStr(ChildServiceName, 1, MaxStrLen(NewLink.ID));
        ParentId := CopyStr(ParentServiceName, 1, MaxStrLen(NewLink.Parent));

        // The parent's own page row supplies the hierarchy properties, so it has to exist in
        // this profile first. IncludePageInProfiles has already run for published pages.
        if not ParentRow.Get(ParentRow."Profile Type"::Page, ParentId, Profile) then
            exit(false);

        ExistingLink.SetRange("Profile Type", ExistingLink."Profile Type"::"Parent Page");
        ExistingLink.SetRange(ID, ChildId);
        ExistingLink.SetRange(Profile, Profile);
        ExistingLink.SetRange(Parent, ParentId);
        if not ExistingLink.IsEmpty() then
            exit(false);

        // Control ID sequences per child and profile, matching MobileNAV's AddParent.
        LastLink.SetRange("Profile Type", LastLink."Profile Type"::"Parent Page");
        LastLink.SetRange(ID, ChildId);
        LastLink.SetRange(Profile, Profile);
        if LastLink.FindLast() then
            NewLink."Control ID" := LastLink."Control ID" + 1
        else
            NewLink."Control ID" := 1;

        NewLink."Profile Type" := NewLink."Profile Type"::"Parent Page";
        NewLink.ID := ChildId;
        NewLink.Profile := Profile;
        NewLink.Parent := ParentId;
        NewLink."Exclude from Profile" := ParentRow."Exclude from Profile";
        NewLink."Lookup Only" := ParentRow."Lookup Only";
        NewLink."Page Type" := ParentRow."Page Type";
        NewLink."Use as Online" := ParentRow."Use as Online";
        NewLink.Insert(false);
        exit(true);
    end;

    /// <summary>
    /// Writes one profile's row for the control, inserting it when the profile has never been
    /// told about the control. Visible and Editable are marked as not inherited: an inherited
    /// value is one MobileNAV is free to recompute from the service row, which is exactly the
    /// behaviour a caller is overriding by declaring the field for the profile.
    /// </summary>
    local procedure WriteProfileField(ServiceName: Text[100]; ControlId: Integer; Profile: Code[30]; Visible: Boolean; Editable: Boolean): Boolean
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        IsNew: Boolean;
    begin
        IsNew := not ProfileSetup.Get(ProfileSetup."Profile Type"::Field, ServiceName, Profile, ControlId);
        if IsNew then begin
            ProfileSetup.Init();
            ProfileSetup."Profile Type" := ProfileSetup."Profile Type"::Field;
            ProfileSetup.ID := CopyStr(ServiceName, 1, MaxStrLen(ProfileSetup.ID));
            ProfileSetup.Profile := Profile;
            ProfileSetup."Control ID" := ControlId;
        end;

        // Direct assignment throughout: the OnValidate triggers on these fields cascade across
        // the profile's page hierarchy (recomputing inheritance for parent and child pages) and
        // raise Confirm() dialogs, neither of which can run inside an unattended apply.
#pragma warning disable PC0037
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
        exit(true);
    end;

    /// <summary>
    /// Resolves a control's numeric Control ID from the service-level field row, which is how
    /// profile rows identify a control.
    /// </summary>
    local procedure TryGetControlId(ServiceName: Text[100]; ControlName: Text[100]; var ControlId: Integer): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.SetRange(FieldName, CopyStr(this.WebServiceHandling.ConvertFieldName(ControlName), 1, 75));
        if not ServiceSetup.FindFirst() then
            exit(false);
        ControlId := ServiceSetup.ControlID;
        exit(true);
    end;

    var
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
}

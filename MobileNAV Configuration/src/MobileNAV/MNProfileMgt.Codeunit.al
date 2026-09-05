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
    Permissions = tabledata "MobileNAV Profile Setup" = rim,
        tabledata "MobileNAV Service Setup" = r;

    /// <summary>Writes the control's row for one profile, or for every profile when none is named.</summary>
    /// <returns>False when the control has no field row on the service.</returns>
    procedure ConfigureProfileField(ServiceName: Text[100]; ControlName: Text[100]; Profile: Code[30]; Visible: Boolean; Editable: Boolean): Boolean
    var
        FieldRow: Record "MobileNAV Service Setup";
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, FieldRow) then
            exit(false);

        if Profile <> '' then begin
            this.WriteProfileField(ServiceName, FieldRow.ControlID, Profile, Visible, Editable);
            exit(true);
        end;
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        if ProfileSetup.FindSet() then
            repeat
                this.WriteProfileField(ServiceName, FieldRow.ControlID, ProfileSetup.Profile, Visible, Editable);
            until ProfileSetup.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// Gives the page a Page row (a tile, and a place in the menu) in one profile, or in every
    /// profile when none is named. The row is created the way MobileNAV's Main Menu Editor
    /// creates it, so MobileNAV fills in the page number, table number and page type itself.
    /// </summary>
    procedure IncludePageInProfiles(ServiceName: Text[100]; Profile: Code[30])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if Profile <> '' then begin
            this.IncludePageInProfile(ServiceName, Profile);
            exit;
        end;
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                this.IncludePageInProfile(ServiceName, MasterData.Code);
            until MasterData.Next() = 0;
    end;

    /// <summary>
    /// Makes the child page reachable from the parent page in one profile, or in every profile
    /// when none is named, so a link from the parent to the child is drawn.
    /// </summary>
    procedure LinkPageToParent(ChildServiceName: Text[100]; ParentServiceName: Text[100]; Profile: Code[30])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if Profile <> '' then begin
            this.LinkPageToParentInProfile(ChildServiceName, ParentServiceName, Profile);
            exit;
        end;
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                this.LinkPageToParentInProfile(ChildServiceName, ParentServiceName, MasterData.Code);
            until MasterData.Next() = 0;
    end;

    local procedure IncludePageInProfile(ServiceName: Text[100]; Profile: Code[30])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        if this.FindPageRow(ServiceName, Profile, ProfileSetup) then begin
            if not ProfileSetup."Exclude from Profile" and ProfileSetup."Display in Menu" then
                exit;
#pragma warning disable PC0037
            ProfileSetup."Exclude from Profile" := false;
            ProfileSetup."Display in Menu" := true;
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
    /// Visible and Editable are marked as not inherited: an inherited value is one MobileNAV may
    /// recompute from the service row, which is what declaring the field for the profile overrides.
    /// </summary>
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
    local procedure FindPageRow(ServiceName: Text[100]; Profile: Code[30]; var ProfileSetup: Record "MobileNAV Profile Setup"): Boolean
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
}

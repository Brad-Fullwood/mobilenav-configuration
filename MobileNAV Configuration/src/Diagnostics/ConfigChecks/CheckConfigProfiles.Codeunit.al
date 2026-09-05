namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every MobileNAV profile carry what the provider declared? MobileNAV resolves the device
/// screen from profile rows, which override the service-level rows outright: a published page
/// needs a Page row per profile, and a link's target needs a Parent Page row in every profile
/// the parent page belongs to, or the button is not drawn. Field rows are different: MobileNAV
/// keeps one only where a profile deviates from the service row (its hierarchy rebuild drops
/// the rest as inherited), so a missing row is healthy and only a row that contradicts the
/// declaration or excludes the control is a problem.
/// </summary>
codeunit 77796 "BJF Check Config Profiles" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Profile Setup" = r,
        tabledata "MobileNAV Service Setup" = r;

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
        ProfileManagement: Codeunit "BJF MN Profile Mgt.";
        Kind: Text;
        Args: List of [Text];
        Visible: Boolean;
        Editable: Boolean;
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        case Kind of
            this.PageFixTok:
                ProfileManagement.IncludePageInProfiles(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 30));
            this.ParentFixTok:
                ProfileManagement.LinkPageToParent(CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100), CopyStr(Args.Get(3), 1, 30));
            this.FieldFixTok:
                begin
                    Evaluate(Visible, Args.Get(4));
                    Evaluate(Editable, Args.Get(5));
                    ProfileManagement.ConfigureProfileField(
                        CopyStr(Args.Get(1), 1, 100), CopyStr(Args.Get(2), 1, 100), CopyStr(Args.Get(3), 1, 30), Visible, Editable);
                end;
            else
                Error(this.NoAutomaticFixErr);
        end;
    end;

    local procedure CheckProvider(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary)
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Profiles: List of [Code[30]];
        FieldProfiles: List of [Code[30]];
    begin
        this.Support.BuildDefinition(TempProvider.Provider, TempLine);
        this.Support.ListProfiles(Profiles);
        this.Support.ListFieldProfiles(FieldProfiles);

        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempLine.FindSet() then
            repeat
                this.CheckPageRows(Finding, TempProvider, TempLine, Profiles);
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

    local procedure CheckPageRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; Profiles: List of [Code[30]])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        ServiceName: Text[100];
        Profile: Code[30];
        Args: List of [Text];
    begin
        ServiceName := this.Lookup.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        foreach Profile in Profiles do
            if not this.FindPageRow(ServiceName, Profile, ProfileSetup) or ProfileSetup."Exclude from Profile" or not ProfileSetup."Display in Menu" then begin
                Clear(Args);
                Args.Add(ServiceName);
                Args.Add(Profile);
                Finding.AddWithFix(Finding."Check Type"::"Config Profiles", Finding.Severity::Blocker,
                    this.Support.Prefix(TempProvider, StrSubstNo(this.PageMissingMsg, ServiceName, Profile)),
                    Finding."Related Record ID", StrSubstNo(this.PageFixMsg, ServiceName, Profile),
                    this.Support.PackFix(this.PageFixTok, Args));
            end;
    end;

    local procedure CheckParentRows(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary; Profiles: List of [Code[30]])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        ParentService: Text[100];
        ChildService: Text[100];
        Profile: Code[30];
        Args: List of [Text];
    begin
        ParentService := this.Lookup.GetServiceName(Line."Page ID");
        ChildService := this.Lookup.GetServiceName(Line."Target Page ID");
        if (ParentService = '') or (ChildService = '') then
            exit;
        foreach Profile in Profiles do begin
            // A profile that does not carry the parent page cannot show the button anyway.
            if not this.FindPageRow(ParentService, Profile, ProfileSetup) then
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
        ServiceName := this.Lookup.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        if not this.Lookup.FindFieldRow(ServiceName, Line."Control Name", FieldRow) then
            exit; // Reported by the field check.
        if Line.Profile <> '' then
            Profiles.Add(Line.Profile)
        else
            Profiles := AllProfiles;

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
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        PageMissingMsg: Label 'Page %1 is missing from profile %2 (or excluded from its menu), so the profile''s devices cannot reach it and any button opening it is hidden.', Comment = '%1 = service, %2 = profile';
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

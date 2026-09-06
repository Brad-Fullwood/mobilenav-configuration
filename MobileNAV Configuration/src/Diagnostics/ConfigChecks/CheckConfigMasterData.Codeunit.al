namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Do the declared categories, their translations, profiles and per-profile page switches
/// exist as declared? Each finding's fix rewrites that one item.
/// </summary>
codeunit 77704 "BJF Check Config Master Data" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Category Transl." = r,
        tabledata "MobileNAV Profile Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                TempLine.SetFilter(Operation, '%1|%2|%3|%4',
                    Enum::"BJF MN Config Operation"::Category, Enum::"BJF MN Config Operation"::"Category Translation",
                    Enum::"BJF MN Config Operation"::Profile, Enum::"BJF MN Config Operation"::"Profile Page");
                if TempLine.FindSet() then
                    repeat
                        this.CheckLine(Finding, TempProvider, TempLine);
                    until TempLine.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        EntryNo: Integer;
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.MasterDataFixTok then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(EntryNo, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        if not TempLine.Get(EntryNo) then
            Error(this.LineGoneErr);
        this.Write(TempLine);
    end;

    local procedure CheckLine(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; Line: Record "BJF MN Config Line" temporary)
    var
        Difference: Text;
        Severity: Enum "BJF Diagnostic Severity";
        Args: List of [Text];
    begin
        Difference := this.Problem(Line, Severity);
        if Difference = '' then
            exit;
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(Line."Entry No.", 0, 9));
        Finding.AddWithFix(Finding."Check Type"::"Config Master Data", Severity,
            this.Support.Prefix(TempProvider, Difference), Finding."Related Record ID", StrSubstNo(this.FixMsg, Line.Operation),
            this.Support.PackFix(this.MasterDataFixTok, Args));
    end;

    local procedure Problem(Line: Record "BJF MN Config Line" temporary; var Severity: Enum "BJF Diagnostic Severity"): Text
    begin
        Severity := Severity::Blocker;
        case Line.Operation of
            Enum::"BJF MN Config Operation"::Category:
                exit(this.CategoryProblem(Line, Severity));
            Enum::"BJF MN Config Operation"::"Category Translation":
                exit(this.TranslationProblem(Line, Severity));
            Enum::"BJF MN Config Operation"::Profile:
                exit(this.ProfileProblem(Line, Severity));
            Enum::"BJF MN Config Operation"::"Profile Page":
                exit(this.ProfilePageProblem(Line));
        end;
        exit('');
    end;

    local procedure CategoryProblem(Line: Record "BJF MN Config Line" temporary; var Severity: Enum "BJF Diagnostic Severity"): Text
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not this.MasterDataManagement.FindCategory(CopyStr(Line."Control Name", 1, 20), MasterData) then
            exit(StrSubstNo(this.NoCategoryMsg, Line."Control Name"));
        if (Line.Description <> '') and (MasterData.Description <> Line.Description) then begin
            Severity := Severity::Warning;
            exit(StrSubstNo(this.CategoryDescriptionMsg, Line."Control Name", Line.Description, MasterData.Description));
        end;
        exit('');
    end;

    local procedure TranslationProblem(Line: Record "BJF MN Config Line" temporary; var Severity: Enum "BJF Diagnostic Severity"): Text
    var
        CategoryTranslation: Record "MobileNAV Category Transl.";
    begin
        if not CategoryTranslation.Get(CopyStr(Line."Control Name", 1, 20), Line."Language Code") then
            exit(StrSubstNo(this.NoTranslationMsg, Line."Control Name", Line."Language Code"));
        if CategoryTranslation.Description <> Line.Description then begin
            Severity := Severity::Warning;
            exit(StrSubstNo(this.TranslationMsg, Line."Control Name", Line."Language Code", Line.Description, CategoryTranslation.Description));
        end;
        exit('');
    end;

    local procedure ProfileProblem(Line: Record "BJF MN Config Line" temporary; var Severity: Enum "BJF Diagnostic Severity"): Text
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if not this.MasterDataManagement.FindProfile(Line.Profile, MasterData) then
            exit(StrSubstNo(this.NoProfileMsg, Line.Profile));
        if (Line.Description <> '') and (MasterData.Description <> Line.Description) then begin
            Severity := Severity::Warning;
            exit(StrSubstNo(this.ProfileDescriptionMsg, Line.Profile, Line.Description, MasterData.Description));
        end;
        exit('');
    end;

    local procedure ProfilePageProblem(Line: Record "BJF MN Config Line" temporary): Text
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        ServiceName: Text[100];
    begin
        ServiceName := this.Lookup.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit('');
        if not this.ProfileManagement.FindPageRow(ServiceName, Line.Profile, ProfileSetup) then
            exit(StrSubstNo(this.NoProfilePageMsg, ServiceName, Line.Profile));
        if (ProfileSetup."Exclude from Profile" <> Line.Disabled) or (ProfileSetup."Use as Online" <> Line."Auto Refresh On Open") or (ProfileSetup."Lookup Only" <> Line."Multi Select") then
            exit(StrSubstNo(this.ProfilePageMsg, ServiceName, Line.Profile));
        exit('');
    end;

    local procedure Write(Line: Record "BJF MN Config Line" temporary)
    var
        ServiceName: Text[100];
    begin
        case Line.Operation of
            Enum::"BJF MN Config Operation"::Category:
                this.MasterDataManagement.EnsureCategory(CopyStr(Line."Control Name", 1, 20), Line.Description);
            Enum::"BJF MN Config Operation"::"Category Translation":
                this.MasterDataManagement.EnsureCategoryTranslation(CopyStr(Line."Control Name", 1, 20), Line."Language Code", Line.Description);
            Enum::"BJF MN Config Operation"::Profile:
                this.MasterDataManagement.EnsureProfile(Line.Profile, Line.Description);
            Enum::"BJF MN Config Operation"::"Profile Page":
                begin
                    ServiceName := this.Lookup.GetServiceName(Line."Page ID");
                    if ServiceName = '' then
                        Error(this.PageGoneErr, Line."Page ID");
                    this.ProfileManagement.ConfigureProfilePage(ServiceName, Line.Profile, Line.Disabled, Line."Auto Refresh On Open", Line."Multi Select");
                end;
        end;
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        MasterDataManagement: Codeunit "BJF MN Master Data Mgt.";
        ProfileManagement: Codeunit "BJF MN Profile Mgt.";
        NoCategoryMsg: Label 'Category %1 is declared but does not exist in MobileNAV.', Comment = '%1 = category code';
        CategoryDescriptionMsg: Label 'Category %1 is declared as "%2" but is "%3".', Comment = '%1 = category code, %2 = declared description, %3 = live description';
        NoTranslationMsg: Label 'Category %1 has no %2 translation.', Comment = '%1 = category code, %2 = language code';
        TranslationMsg: Label 'Category %1 in %2 is declared as "%3" but is "%4".', Comment = '%1 = category code, %2 = language code, %3 = declared description, %4 = live description';
        NoProfileMsg: Label 'Profile %1 is declared but does not exist in MobileNAV.', Comment = '%1 = profile code';
        ProfileDescriptionMsg: Label 'Profile %1 is declared as "%2" but is "%3".', Comment = '%1 = profile code, %2 = declared description, %3 = live description';
        NoProfilePageMsg: Label 'Page %1 has no row in profile %2, so its per-profile switches cannot hold.', Comment = '%1 = service name, %2 = profile code';
        ProfilePageMsg: Label 'Page %1 in profile %2 does not carry the declared exclusion, online and lookup-only switches.', Comment = '%1 = service name, %2 = profile code';
        FixMsg: Label 'Write the declared %1.', Comment = '%1 = line kind';
        LineGoneErr: Label 'The provider no longer declares this item.';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        MasterDataFixTok: Label 'MASTERDATA', Locked = true;
}

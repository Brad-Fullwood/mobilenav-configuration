namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Runs diagnostic checks for the current user, replacing their previous findings.</summary>
codeunit 77770 "BJF Diagnostics Runner"
{
    Access = Public;
    Permissions = tabledata "BJF Diagnostic Finding" = rd;

    trigger OnRun()
    begin
        this.RunAll();
    end;

    /// <summary>The check types that compare provider declarations with MobileNAV's live configuration.</summary>
    /// <returns>The configuration check types, in run order.</returns>
    procedure ConfigCheckTypes() CheckTypes: List of [Enum "BJF Diagnostic Check Type"]
    begin
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Services");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Fields");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Profiles");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Page Rules");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Apply State");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Properties");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Staging");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Relations");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Page Rows");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Groups");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Layouts");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Master Data");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Appearance");
        CheckTypes.Add(Enum::"BJF Diagnostic Check Type"::"Config Line Formats");
    end;

    /// <summary>Runs every check registered in "BJF Diagnostic Check Type".</summary>
    procedure RunAll()
    var
        CheckTypes: List of [Enum "BJF Diagnostic Check Type"];
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"BJF Diagnostic Check Type".Ordinals() do
            CheckTypes.Add(Enum::"BJF Diagnostic Check Type".FromInteger(Ordinal));
        this.Run(CheckTypes);
    end;

    /// <summary>Runs the given checks. Their previous findings are cleared first; other checks' findings stay.</summary>
    /// <param name="CheckTypes">The checks to run, in order.</param>
    procedure Run(CheckTypes: List of [Enum "BJF Diagnostic Check Type"])
    var
        Finding: Record "BJF Diagnostic Finding";
        DoctorRunCache: Codeunit "BJF MN Doctor Run Cache";
        DiagnosticCheck: Interface "BJF Diagnostic Check";
        CheckType: Enum "BJF Diagnostic Check Type";
    begin
        if CheckTypes.Count() = 0 then
            exit;

        Finding.SetRange("User ID", UserId());
        foreach CheckType in CheckTypes do begin
            Finding.SetRange("Check Type", CheckType);
            Finding.DeleteAll(false);
        end;
        Finding.SetRange("Check Type");

        // The configuration checks share one build of each provider for the run. The binding
        // ends with DoctorRunCache, also when a check fails.
        BindSubscription(DoctorRunCache);
        foreach CheckType in CheckTypes do begin
            DiagnosticCheck := CheckType;
            DiagnosticCheck.RunCheck(Finding);
        end;
        UnbindSubscription(DoctorRunCache);

        if not this.HasFindings(CheckTypes) then
            Finding.Add(CheckTypes.Get(1), Enum::"BJF Diagnostic Severity"::Info, this.AllPassedMsg);
    end;

    local procedure HasFindings(CheckTypes: List of [Enum "BJF Diagnostic Check Type"]): Boolean
    var
        Finding: Record "BJF Diagnostic Finding";
        CheckType: Enum "BJF Diagnostic Check Type";
    begin
        Finding.SetRange("User ID", UserId());
        foreach CheckType in CheckTypes do begin
            Finding.SetRange("Check Type", CheckType);
            if not Finding.IsEmpty() then
                exit(true);
        end;
        exit(false);
    end;

    var
        AllPassedMsg: Label 'All checks passed - no issues found.';
}

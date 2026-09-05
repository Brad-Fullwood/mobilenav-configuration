namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Runs diagnostic checks for the current user, replacing their previous findings.</summary>
codeunit 77770 "BJF Diagnostics Runner"
{
    Access = Public;
    Permissions = tabledata "BJF Diagnostic Finding" = rimd;

    trigger OnRun()
    begin
        this.RunAll();
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
    procedure Run(CheckTypes: List of [Enum "BJF Diagnostic Check Type"])
    var
        Finding: Record "BJF Diagnostic Finding";
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

        foreach CheckType in CheckTypes do begin
            DiagnosticCheck := CheckType;
            DiagnosticCheck.RunCheck(Finding);
        end;

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

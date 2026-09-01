namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Clears previous findings and runs every check registered in enum "BJF Diagnostic Check Type".
/// </summary>
codeunit 77770 "BJF Diagnostics Runner"
{
    Access = Public;
    Permissions = tabledata "BJF Diagnostic Finding" = rimd;

    trigger OnRun()
    begin
        RunAll();
    end;

    /// <summary>Runs every registered check for the current user. Equivalent to RunChecks('').</summary>
    procedure RunAll()
    begin
        RunChecks('');
    end;

    /// <summary>
    /// Clears and re-runs only the checks whose enum value matches CheckTypeFilter (an AL filter
    /// expression evaluated against "BJF Diagnostic Check Type", e.g. an option/enum filter such
    /// as '0|2'). An empty filter matches every check, so RunAll() simply calls RunChecks('').
    /// Findings are always scoped to the current user.
    /// </summary>
    procedure RunChecks(CheckTypeFilter: Text)
    var
        Finding: Record "BJF Diagnostic Finding";
        CheckType: Enum "BJF Diagnostic Check Type";
        DiagnosticCheck: Interface "BJF Diagnostic Check";
        Ordinal: Integer;
        AnyChecksRun: Boolean;
    begin
        Finding.Reset();
        Finding.SetRange("User ID", UserId());
        if CheckTypeFilter <> '' then
            Finding.SetFilter("Check Type", CheckTypeFilter);
        Finding.DeleteAll();

        foreach Ordinal in Enum::"BJF Diagnostic Check Type".Ordinals() do begin
            CheckType := Enum::"BJF Diagnostic Check Type".FromInteger(Ordinal);
            if CheckTypeMatchesFilter(CheckType, CheckTypeFilter) then begin
                AnyChecksRun := true;
                DiagnosticCheck := CheckType;
                DiagnosticCheck.RunCheck(Finding);
            end;
        end;

        if AnyChecksRun then begin
            Finding.Reset();
            Finding.SetRange("User ID", UserId());
            if CheckTypeFilter <> '' then
                Finding.SetFilter("Check Type", CheckTypeFilter);
            if Finding.IsEmpty() then
                Finding.Add(CheckType, Enum::"BJF Diagnostic Severity"::Info, AllPassedMsg);
        end;
    end;

    /// <summary>
    /// True when CheckType satisfies CheckTypeFilter (an empty filter always matches). AL has no
    /// direct "does this value satisfy this filter string" primitive, so this inserts a throwaway
    /// temporary record carrying the value, applies the filter, and asks whether it survives it -
    /// the same technique SetFilter/IsEmpty use for any other field.
    /// </summary>
    local procedure CheckTypeMatchesFilter(CheckType: Enum "BJF Diagnostic Check Type"; CheckTypeFilter: Text): Boolean
    var
        TempFinding: Record "BJF Diagnostic Finding" temporary;
    begin
        if CheckTypeFilter = '' then
            exit(true);
        TempFinding."Entry No." := 1;
        TempFinding."Check Type" := CheckType;
        TempFinding.Insert();
        TempFinding.SetFilter("Check Type", CheckTypeFilter);
        exit(not TempFinding.IsEmpty());
    end;

    var
        AllPassedMsg: Label 'All checks passed - no issues found.';
}

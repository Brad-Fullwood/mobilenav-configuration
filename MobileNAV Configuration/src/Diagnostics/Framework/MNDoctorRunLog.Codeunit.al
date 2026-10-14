namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Runs Doctor checks and writes one run log row per run, with the issue counts the run left for the current user.</summary>
codeunit 77812 "BJF MN Doctor Run Log"
{
    Access = Internal;
    Permissions = tabledata "BJF Diagnostic Finding" = r,
                  tabledata "BJF Doctor Run Log" = rid;

    /// <summary>Runs the given checks, then records the run.</summary>
    /// <param name="RunSource">Where the run came from.</param>
    /// <param name="CheckTypes">The checks to run, in order.</param>
    procedure RunChecks(RunSource: Enum "BJF Doctor Run Source"; CheckTypes: List of [Enum "BJF Diagnostic Check Type"])
    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
    begin
        DiagnosticsRunner.Run(CheckTypes);
        this.Record(RunSource);
    end;

    /// <summary>Runs every check, then records the run.</summary>
    /// <param name="RunSource">Where the run came from.</param>
    procedure RunAll(RunSource: Enum "BJF Doctor Run Source")
    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
    begin
        DiagnosticsRunner.RunAll();
        this.Record(RunSource);
    end;

    local procedure Record(RunSource: Enum "BJF Doctor Run Source")
    var
        Finding: Record "BJF Diagnostic Finding";
        RunLog: Record "BJF Doctor Run Log";
        CurrentUser: Code[50];
    begin
        CurrentUser := CopyStr(UserId(), 1, MaxStrLen(Finding."User ID"));
        Finding.SetRange("User ID", CurrentUser);
        Finding.SetRange(Severity, Finding.Severity::Blocker);
        RunLog.Validate(Blockers, Finding.Count());
        Finding.SetRange(Severity, Finding.Severity::Warning);
        RunLog.Validate(Warnings, Finding.Count());

        RunLog.Init();
        RunLog.Validate("Run At", CurrentDateTime());
        RunLog.Validate(Source, RunSource);
        RunLog.Validate("Run By", CurrentUser);
        RunLog.Insert(false);
        if RunSource = Enum::"BJF Doctor Run Source"::"Page Open" then
            this.TrimPageOpenRows();
    end;

    /// <summary>Deletes the oldest page open rows beyond the kept count. Manual and job queue rows are never trimmed.</summary>
    local procedure TrimPageOpenRows()
    var
        RunLog: Record "BJF Doctor Run Log";
        Excess: Integer;
    begin
        RunLog.SetRange(Source, Enum::"BJF Doctor Run Source"::"Page Open");
        Excess := RunLog.Count() - this.KeptRunsCount();
        if Excess <= 0 then
            exit;
        if RunLog.FindSet() then
            repeat
                RunLog.Delete(false);
                Excess -= 1;
            until (Excess = 0) or (RunLog.Next() = 0);
    end;

    local procedure KeptRunsCount(): Integer
    begin
        exit(200);
    end;
}

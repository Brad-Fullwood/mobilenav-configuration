namespace BradFullwood.MobileNAV.Example.Tests;

/// <summary>
/// Runs the example's test codeunits, all of them or one, and keeps one result row per test method in
/// its instance. The caller makes an instance, calls SetCodeunitId, calls Run and reads the rows with
/// CopyResults. TestIsolation is Disabled, so database changes made by the tests are not rolled back:
/// run the tests in a test environment.
/// </summary>
codeunit 50156 "Example Test Runner"
{
    Subtype = TestRunner;
    TestIsolation = Disabled;

    trigger OnRun()
    begin
        this.RunTest(Codeunit::"Example Provider Test");
        this.RunTest(Codeunit::"Example Cookbook Test");
        this.RunTest(Codeunit::"New Provider Scaffold Test");
        this.RunTest(Codeunit::"Example Device Preview Test");
        this.RunTest(Codeunit::"Provider Writer Test");
        this.RunTest(Codeunit::"Emulator Test");
        this.RunTest(Codeunit::"Lookup Scan Builder Test");
        this.RunTest(Codeunit::"Layout Buffer Check Test");
        this.RunTest(Codeunit::"Option Captions Check Test");
    end;

    trigger OnBeforeTestRun(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Permissions: TestPermissions): Boolean
    begin
        exit(true);
    end;

    trigger OnAfterTestRun(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Permissions: TestPermissions; Success: Boolean)
    begin
        // A test codeunit that passed has no row of its own: each of its methods has one.
        if (FunctionName = '') and Success then
            exit;
        this.AddResult(CodeunitId, CodeunitName, FunctionName, Success);
    end;

    /// <summary>Limits the next run to one test codeunit.</summary>
    /// <param name="CodeunitId">The id of the test codeunit, or 0 to run all of them.</param>
    procedure SetCodeunitId(CodeunitId: Integer)
    begin
        this.OnlyCodeunitId := CodeunitId;
    end;

    /// <summary>Copies the result rows of the run into a table, in the order the tests ran.</summary>
    /// <param name="TempTarget">Receives one row per result. Filters on the table do not stop the copy.</param>
    procedure CopyResults(var TempTarget: Record "Example Test Result" temporary)
    begin
        if this.TempResults.FindSet() then
            repeat
                TempTarget := this.TempResults;
                TempTarget.Insert(false);
            until this.TempResults.Next() = 0;
    end;

    /// <summary>Runs one test codeunit, unless a single codeunit was asked for and this is not it.</summary>
    /// <param name="CodeunitId">The id of the test codeunit.</param>
    local procedure RunTest(CodeunitId: Integer)
    begin
        if (this.OnlyCodeunitId <> 0) and (this.OnlyCodeunitId <> CodeunitId) then
            exit;
        // Reading the Boolean stops a failed Run from raising an error, which would end the runner before the
        // other test codeunits. OnAfterTestRun has already recorded the failure, so the runner moves on.
        if not Codeunit.Run(CodeunitId) then
            exit;
    end;

    /// <summary>Adds one result row for a test method, or for a test codeunit that failed as a whole.</summary>
    /// <param name="CodeunitId">The id of the test codeunit.</param>
    /// <param name="CodeunitName">The name of the test codeunit.</param>
    /// <param name="FunctionName">The test method, or '' for the test codeunit.</param>
    /// <param name="Passed">Whether the test passed.</param>
    local procedure AddResult(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Passed: Boolean)
    begin
        this.TempResults.Init();
        this.TempResults.Validate("Line No.", this.TempResults.Count() + 1);
        this.TempResults.Validate("Codeunit Id", CodeunitId);
        this.TempResults.Validate("Codeunit Name", CopyStr(CodeunitName, 1, MaxStrLen(this.TempResults."Codeunit Name")));
        if FunctionName = '' then
            this.TempResults.Validate("Method Name", this.CodeunitLevelTok)
        else
            this.TempResults.Validate("Method Name", CopyStr(FunctionName, 1, MaxStrLen(this.TempResults."Method Name")));
        this.TempResults.Validate("Success", Passed);
        if not Passed then
            this.TempResults.Validate("Error Text", CopyStr(GetLastErrorText(), 1, MaxStrLen(this.TempResults."Error Text")));
        this.TempResults.Insert(false);
    end;

    var
        TempResults: Record "Example Test Result" temporary;
        OnlyCodeunitId: Integer;
        CodeunitLevelTok: Label '(codeunit)', Locked = true;
}

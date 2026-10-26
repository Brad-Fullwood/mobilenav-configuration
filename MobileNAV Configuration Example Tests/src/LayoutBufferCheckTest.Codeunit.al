namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Checks the Leftover Layout Buffers doctor check on the case Arnold Wills met: an action line
/// buffer row for Query ID 1 is left behind, the user has no Settings Buffer rows, so MobileNAV's next
/// build gets Query ID 1 and its Insert of the same action line fails. The tests write buffer rows for
/// a user no one logs in with and delete them again, because the test run has no isolation.
/// </summary>
codeunit 50160 "Layout Buffer Check Test"
{
    Subtype = Test;
    Access = Internal;
    Permissions = tabledata "MobileNAV D. L. Act. L. Buff." = rid,
        tabledata "MobileNAV D. L. Action Buff." = id,
        tabledata "MobileNAV Dynamic Layout Buff." = id,
        tabledata "MobileNAV Settings Buffer" = id;

    /// <summary>A leftover action line at the Query ID of the next build is a Blocker, and the fix deletes it.</summary>
    [Test]
    procedure LeftoverAtNextQueryIsBlockerAndFixDeletesIt()
    var
        TempFinding: Record "BJF Diagnostic Finding" temporary;
        Check: Codeunit "BJF Check Layout Buffers";
    begin
        // Given a user with no Settings Buffer rows and an action line buffer row for Query ID 1
        this.Cleanup();
        this.InsertActionLine(1);

        // When the check runs
        this.AssertEqualInt(1, Check.NextQueryId(this.TestUserTok));
        Check.RunCheck(TempFinding);

        // Then it reports a Blocker for the user, with a fix
        this.FindTestFinding(TempFinding);
        this.AssertEqual(Format(Enum::"BJF Diagnostic Severity"::Blocker), Format(TempFinding.Severity));
        this.AssertTrue(TempFinding.Fixable, this.NotFixableErr);

        // And the fix deletes the row
        Check.ApplyFix(TempFinding);
        this.AssertEqualInt(0, this.ActionLineCount(1));
        this.Cleanup();
    end;

    /// <summary>The fix keeps the rows of the user's current build and deletes only the leftover ones.</summary>
    [Test]
    procedure FixKeepsCurrentBuild()
    var
        TempFinding: Record "BJF Diagnostic Finding" temporary;
        Check: Codeunit "BJF Check Layout Buffers";
        StaleQueryIds: List of [Integer];
    begin
        // Given a current build with Query ID 2 and a leftover action line of Query ID 1
        this.Cleanup();
        this.InsertSettingsRow(2);
        this.InsertLayout(2);
        this.InsertAction(2);
        this.InsertActionLine(2);
        this.InsertActionLine(1);

        // When the check runs
        this.AssertEqualInt(1, Check.CountStaleRows(this.TestUserTok, StaleQueryIds));
        this.AssertTrue(StaleQueryIds.Contains(1), this.StaleIdErr);
        Check.RunCheck(TempFinding);

        // Then the next build (Query ID 3) does not collide, so it is a Warning
        this.FindTestFinding(TempFinding);
        this.AssertEqual(Format(Enum::"BJF Diagnostic Severity"::Warning), Format(TempFinding.Severity));

        // And the fix leaves Query ID 2 alone
        Check.ApplyFix(TempFinding);
        this.AssertEqualInt(0, this.ActionLineCount(1));
        this.AssertEqualInt(1, this.ActionLineCount(2));
        this.AssertEqualInt(0, Check.CountStaleRows(this.TestUserTok, StaleQueryIds));
        this.Cleanup();
    end;

    /// <summary>A user whose layout buffers all belong to the current build gives no finding.</summary>
    [Test]
    procedure CurrentBuildOnlyGivesNoFinding()
    var
        TempFinding: Record "BJF Diagnostic Finding" temporary;
        Check: Codeunit "BJF Check Layout Buffers";
    begin
        this.Cleanup();
        this.InsertSettingsRow(4);
        this.InsertLayout(4);
        this.InsertAction(4);
        this.InsertActionLine(4);

        Check.RunCheck(TempFinding);

        TempFinding.SetRange("Fix Context", this.TestUserTok);
        this.AssertEqualInt(0, TempFinding.Count());
        this.Cleanup();
    end;

    local procedure InsertSettingsRow(QueryId: Integer)
    var
        SettingsBuffer: Record "MobileNAV Settings Buffer";
    begin
        SettingsBuffer.Init();
        SettingsBuffer.Validate("User ID", this.TestUserTok);
        SettingsBuffer.Validate("Query ID", QueryId);
        SettingsBuffer.Validate("Service Name", this.ServiceTok);
        SettingsBuffer.Insert(false);
    end;

    local procedure InsertLayout(QueryId: Integer)
    var
        LayoutBuffer: Record "MobileNAV Dynamic Layout Buff.";
    begin
        LayoutBuffer.Init();
        LayoutBuffer.Validate("User ID", this.TestUserTok);
        LayoutBuffer.Validate("Query ID", QueryId);
        LayoutBuffer.Validate("Service Name", this.ServiceTok);
        LayoutBuffer.Validate(Code, this.LayoutTok);
        LayoutBuffer.Insert(false);
    end;

    local procedure InsertAction(QueryId: Integer)
    var
        ActionBuffer: Record "MobileNAV D. L. Action Buff.";
    begin
        ActionBuffer.Init();
        ActionBuffer.Validate("User ID", this.TestUserTok);
        ActionBuffer.Validate("Query ID", QueryId);
        ActionBuffer.Validate("Service Name", this.ServiceTok);
        ActionBuffer.Validate("Layout Code", this.LayoutTok);
        ActionBuffer.Validate(Type, ActionBuffer.Type::HideField);
        ActionBuffer.Insert(false);
    end;

    local procedure InsertActionLine(QueryId: Integer)
    var
        ActionLineBuffer: Record "MobileNAV D. L. Act. L. Buff.";
    begin
        ActionLineBuffer.Init();
        ActionLineBuffer.Validate("User ID", this.TestUserTok);
        ActionLineBuffer.Validate("Query ID", QueryId);
        ActionLineBuffer.Validate("Service Name", this.ServiceTok);
        ActionLineBuffer.Validate("Layout Code", this.LayoutTok);
        ActionLineBuffer.Validate("Action Type", ActionLineBuffer."Action Type"::HideField);
        ActionLineBuffer.Validate(Name, this.ControlTok);
        ActionLineBuffer.Insert(false);
    end;

    local procedure ActionLineCount(QueryId: Integer): Integer
    var
        ActionLineBuffer: Record "MobileNAV D. L. Act. L. Buff.";
    begin
        ActionLineBuffer.SetRange("User ID", this.TestUserTok);
        ActionLineBuffer.SetRange("Query ID", QueryId);
        exit(ActionLineBuffer.Count());
    end;

    local procedure FindTestFinding(var TempFinding: Record "BJF Diagnostic Finding" temporary)
    begin
        TempFinding.SetRange("Check Type", Enum::"BJF Diagnostic Check Type"::"Layout Buffers");
        TempFinding.SetRange("Fix Context", this.TestUserTok);
        this.AssertEqualInt(1, TempFinding.Count());
        if not TempFinding.FindFirst() then
            Error(this.NoFindingErr);
    end;

    local procedure Cleanup()
    var
        SettingsBuffer: Record "MobileNAV Settings Buffer";
        LayoutBuffer: Record "MobileNAV Dynamic Layout Buff.";
        ActionBuffer: Record "MobileNAV D. L. Action Buff.";
        ActionLineBuffer: Record "MobileNAV D. L. Act. L. Buff.";
    begin
        SettingsBuffer.SetRange("User ID", this.TestUserTok);
        SettingsBuffer.DeleteAll(false);
        LayoutBuffer.SetRange("User ID", this.TestUserTok);
        LayoutBuffer.DeleteAll(false);
        ActionBuffer.SetRange("User ID", this.TestUserTok);
        ActionBuffer.DeleteAll(false);
        ActionLineBuffer.SetRange("User ID", this.TestUserTok);
        ActionLineBuffer.DeleteAll(false);
    end;

    local procedure AssertEqual(Expected: Text; Actual: Text)
    begin
        if Expected <> Actual then
            Error(this.MismatchErr, Expected, Actual);
    end;

    local procedure AssertEqualInt(Expected: Integer; Actual: Integer)
    begin
        this.AssertEqual(Format(Expected), Format(Actual));
    end;

    local procedure AssertTrue(Condition: Boolean; Message: Text)
    begin
        if not Condition then
            Error(ErrorInfo.Create(Message));
    end;

    var
        TestUserTok: Label 'BJF LAYOUT BUFFER TEST', Locked = true;
        ServiceTok: Label 'MNAdhocMovement', Locked = true;
        LayoutTok: Label 'ITEMS_ADDED', Locked = true;
        ControlTok: Label 'Delete_Items', Locked = true;
        MismatchErr: Label 'Expected %1, got %2.', Comment = '%1 = expected value, %2 = actual value';
        NoFindingErr: Label 'The check reported no finding for the test user.';
        NotFixableErr: Label 'The finding has no fix.';
        StaleIdErr: Label 'Query ID 1 is not reported as left over.';
}

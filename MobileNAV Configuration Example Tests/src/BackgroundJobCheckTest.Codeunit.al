namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;
using System.Threading;

/// <summary>
/// Checks the Background Job doctor check and the apply's pre-check on the three cases: the MobileNAV
/// BackgroundRefresh job queue entry Ready, On Hold, and missing. The tests move the entries that exist
/// to another object id while they run and put them back, and delete the entry they insert, because the
/// test run has no isolation. The entry is inserted without triggers so no task is scheduled.
/// </summary>
codeunit 50162 "Background Job Check Test"
{
    Subtype = Test;
    Access = Internal;
    Permissions = tabledata "BJF Diagnostic Finding" = rd,
        tabledata "Job Queue Entry" = rimd;

    /// <summary>A Ready entry gives a Warning naming the entry and its status, and the apply stops with the same text before it changes anything.</summary>
    [Test]
    procedure ReadyEntryWarnsAndBlocksApply()
    var
        Finding: Record "BJF Diagnostic Finding";
        TestEntry: Record "Job Queue Entry";
        Check: Codeunit "BJF Check Background Job";
        Application: Codeunit "BJF MN Config Application";
        Guard: Codeunit "BJF MN Background Job Guard";
        ExpectedText: Text;
    begin
        // Given a Ready BackgroundRefresh entry and no other
        this.ParkExistingEntries();
        this.InsertEntry(TestEntry, false);
        ExpectedText := Guard.ErrorText(TestEntry);

        // When the check runs and an apply is tried
        this.MarkFirstEntryNo();
        Check.RunCheck(Finding);

        // Then the Doctor warns with the text
        Finding.Reset();
        Finding.SetFilter("Entry No.", '>=%1', this.FirstEntryNo);
        Finding.SetRange("Related Record ID", TestEntry.RecordId());
        Finding.SetLoadFields(Severity, Message);
        if not Finding.FindFirst() then
            Error(this.NoFindingErr);
        this.AssertEqual(Format(Enum::"BJF Diagnostic Severity"::Warning), Format(Finding.Severity));
        this.AssertEqual(CopyStr(ExpectedText, 1, MaxStrLen(Finding.Message)), Finding.Message);

        // And the apply stops with the same text
        asserterror Application.ApplyProvider(Enum::"BJF MN Config Provider"::Example);
        this.AssertEqual(ExpectedText, GetLastErrorText());
        this.AssertTrue(StrPos(ExpectedText, Format(TestEntry.Status::Ready)) > 0, 'The text names the status.');

        this.CleanUp(TestEntry);
    end;

    /// <summary>An On Hold entry gives no finding and the pre-check passes.</summary>
    [Test]
    procedure OnHoldEntryPasses()
    var
        Finding: Record "BJF Diagnostic Finding";
        TestEntry: Record "Job Queue Entry";
        Check: Codeunit "BJF Check Background Job";
        Guard: Codeunit "BJF MN Background Job Guard";
    begin
        // Given an On Hold BackgroundRefresh entry and no other
        this.ParkExistingEntries();
        this.InsertEntry(TestEntry, true);

        // When the check runs and the pre-check runs
        this.MarkFirstEntryNo();
        Check.RunCheck(Finding);
        Guard.CheckOnHold();

        // Then neither reports anything
        this.AssertNoFindings(Finding);

        this.CleanUp(TestEntry);
    end;

    /// <summary>With no entry the check gives no finding and the pre-check passes.</summary>
    [Test]
    procedure NoEntryPasses()
    var
        Finding: Record "BJF Diagnostic Finding";
        TestEntry: Record "Job Queue Entry";
        Check: Codeunit "BJF Check Background Job";
        Guard: Codeunit "BJF MN Background Job Guard";
    begin
        // Given no BackgroundRefresh entry
        this.ParkExistingEntries();

        // When the check runs and the pre-check runs
        this.MarkFirstEntryNo();
        Check.RunCheck(Finding);
        Guard.CheckOnHold();

        // Then neither reports anything
        this.AssertNoFindings(Finding);

        this.CleanUp(TestEntry);
    end;

    local procedure AssertNoFindings(var Finding: Record "BJF Diagnostic Finding")
    begin
        Finding.Reset();
        Finding.SetFilter("Entry No.", '>=%1', this.FirstEntryNo);
        Finding.SetRange("Check Type", Enum::"BJF Diagnostic Check Type"::"Config Background Job");
        this.AssertTrue(Finding.IsEmpty(), 'No finding expected.');
    end;

#pragma warning disable PC0037 // Validate would run Job Queue Entry's triggers, which fill the description and schedule a task. The test needs the raw row.
#pragma warning disable PC0029 // The id is a test row key, no ordering needed.
    /// <summary>Moves the entries a company already has to another object id so the test controls what the check finds.</summary>
    local procedure ParkExistingEntries()
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"MobileNAV BackgroundRefresh JQ");
        if JobQueueEntry.FindSet() then
            repeat
                this.ParkedIds.Add(JobQueueEntry.ID);
                JobQueueEntry."Object ID to Run" := Codeunit::"Background Job Check Test";
                JobQueueEntry.Modify(false);
            until JobQueueEntry.Next() = 0;
    end;

    /// <summary>Inserts a recurring MobileNAV BackgroundRefresh entry without triggers.</summary>
    /// <param name="JobQueueEntry">Receives the entry.</param>
    /// <param name="OnHold">True for status On Hold, false for Ready.</param>
    local procedure InsertEntry(var JobQueueEntry: Record "Job Queue Entry"; OnHold: Boolean)
    begin
        JobQueueEntry.Init();
        JobQueueEntry.ID := CreateGuid();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"MobileNAV BackgroundRefresh JQ";
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry.Description := 'Background Job Check Test';
        if OnHold then
            JobQueueEntry.Status := JobQueueEntry.Status::"On Hold"
        else
            JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry.Insert(false);
    end;

    /// <summary>Deletes the entry the test inserted and puts the parked entries back.</summary>
    /// <param name="TestEntry">The entry the test inserted, or a blank record.</param>
    local procedure CleanUp(var TestEntry: Record "Job Queue Entry")
    var
        JobQueueEntry: Record "Job Queue Entry";
        ParkedId: Guid;
    begin
        if TestEntry.Get(TestEntry.ID) then
            TestEntry.Delete(false);
        foreach ParkedId in this.ParkedIds do
            if JobQueueEntry.Get(ParkedId) then begin
                JobQueueEntry."Object ID to Run" := Codeunit::"MobileNAV BackgroundRefresh JQ";
                JobQueueEntry.Modify(false);
            end;
        Clear(this.ParkedIds);
        this.DeleteTestFindings();
    end;

#pragma warning restore PC0037
#pragma warning restore PC0029

    local procedure MarkFirstEntryNo()
    var
        Finding: Record "BJF Diagnostic Finding";
    begin
        Finding.SetLoadFields("Entry No.");
        if Finding.FindLast() then
            this.FirstEntryNo := Finding."Entry No." + 1
        else
            this.FirstEntryNo := 1;
    end;

    local procedure DeleteTestFindings()
    var
        Finding: Record "BJF Diagnostic Finding";
    begin
        Finding.SetFilter("Entry No.", '>=%1', this.FirstEntryNo);
        Finding.DeleteAll(false);
    end;

    local procedure AssertEqual(Expected: Text; Actual: Text)
    begin
        if Expected <> Actual then
            Error(this.NotEqualErr, Expected, Actual);
    end;

    local procedure AssertTrue(Condition: Boolean; Description: Text)
    begin
        if not Condition then
            Error(this.AssertFailedErr, Description);
    end;

    var
        ParkedIds: List of [Guid];
        FirstEntryNo: Integer;
        NoFindingErr: Label 'The check gave no finding for the Ready entry.';
        AssertFailedErr: Label 'Assertion failed: %1', Comment = '%1 = what was expected';
        NotEqualErr: Label 'Expected "%1" but got "%2".', Comment = '%1 = expected, %2 = actual';
}

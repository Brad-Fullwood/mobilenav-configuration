namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;
using System.Automation;

/// <summary>
/// Checks the Option Captions doctor check on the case Arnold Wills met: Refresh Page took the values
/// of Approval Entry Document Type from the page's WSDL, which left out the values Insight Works adds,
/// while the captions kept them. The tests write service setup rows for a service no page uses and
/// delete them again, and put AddOn-Converted Option String back as they found it, because the test run
/// has no isolation.
/// </summary>
codeunit 50161 "Option Captions Check Test"
{
    Subtype = Test;
    Access = Internal;
    Permissions = tabledata "BJF Diagnostic Finding" = rd,
        tabledata "MobileNAV Master Data" = rm,
        tabledata "MobileNAV Service Setup" = rid;

    /// <summary>With AddOn-Converted Option String off the check gives a Warning, and the fix sets it.</summary>
    [Test]
    procedure FlagOffIsWarningAndFixSetsIt()
    var
        Finding: Record "BJF Diagnostic Finding";
        MasterData: Record "MobileNAV Master Data";
        Check: Codeunit "BJF Check Option Captions";
        WasSet: Boolean;
    begin
        // Given the flag is off
        WasSet := this.SetFlag(false);

        // When the check runs
        this.MarkFirstEntryNo();
        Check.RunCheck(Finding);

        // Then it reports a Warning on the general setup row, with a fix
        this.GetGeneralSetup(MasterData);
        this.FindFinding(Finding, MasterData.RecordId());
        this.AssertEqual(Format(Enum::"BJF Diagnostic Severity"::Warning), Format(Finding.Severity));
        this.AssertTrue(Finding.Fixable, this.NotFixableErr);

        // And the fix sets the flag
        Check.ApplyFix(Finding);
        this.GetGeneralSetup(MasterData);
        this.AssertTrue(MasterData."AddOn-Converted Option String", this.FlagNotSetErr);
        this.DeleteTestFindings();
        this.SetFlag(WasSet);
    end;

    /// <summary>A row with fewer values than its field has options is a Blocker, and the fix gives it every option through MobileNAV's validation.</summary>
    [Test]
    procedure ShortValuesIsBlockerAndFixRebuildsThem()
    var
        Finding: Record "BJF Diagnostic Finding";
        ServiceSetup: Record "MobileNAV Service Setup";
        Check: Codeunit "BJF Check Option Captions";
        WasSet: Boolean;
        ExpectedCount: Integer;
    begin
        // Given the flag is off and a row for Approval Entry Document Type keeps two values
        WasSet := this.SetFlag(false);
        this.Cleanup();
        this.InsertRows();
        ExpectedCount := Check.CountItems(ServiceSetup.GetOptionValues(Database::"Approval Entry", this.DocumentTypeFieldNo()));
        this.AssertTrue(ExpectedCount > 2, this.TooFewOptionsErr);

        // When the check runs
        this.MarkFirstEntryNo();
        Check.RunCheck(Finding);

        // Then it reports a Blocker for the row
        this.GetFieldRow(ServiceSetup);
        this.FindFinding(Finding, ServiceSetup.RecordId());
        this.AssertEqual(Format(Enum::"BJF Diagnostic Severity"::Blocker), Format(Finding.Severity));

        // And the fix sets the flag and gives the row one value per option
        Check.ApplyFix(Finding);
        this.GetFieldRow(ServiceSetup);
        this.AssertEqualInt(ExpectedCount, Check.CountItems(ServiceSetup.BuildOptionValues(true)));
        this.AssertEqualInt(ExpectedCount, Check.CountItems(ServiceSetup.OptionCaptions + ServiceSetup.OptionCaptions2));

        // And the check no longer reports the row
        this.DeleteTestFindings();
        this.MarkFirstEntryNo();
        Check.RunCheck(Finding);
        this.AssertEqualInt(0, this.CountFindings(Finding, ServiceSetup.RecordId()));
        this.Cleanup();
        this.DeleteTestFindings();
        this.SetFlag(WasSet);
    end;

    local procedure FindFinding(var Finding: Record "BJF Diagnostic Finding"; RelatedRecordId: RecordId)
    begin
        this.AssertEqualInt(1, this.CountFindings(Finding, RelatedRecordId));
    end;

    /// <summary>Counts the Option Captions findings on a record, and leaves the last one current.</summary>
    /// <param name="Finding">Receives the last finding found.</param>
    /// <param name="RelatedRecordId">The record the finding is about.</param>
    /// <returns>The number of findings.</returns>
    local procedure CountFindings(var Finding: Record "BJF Diagnostic Finding"; RelatedRecordId: RecordId) Found: Integer
    var
        EntryNo: Integer;
    begin
        Found := 0;
        // A loop over the few rows this run added, so no key on these fields is needed.
        Finding.Reset();
        Finding.SetFilter("Entry No.", '>=%1', this.FirstEntryNo);
        if Finding.FindSet() then
            repeat
                if (Finding."Check Type" = Enum::"BJF Diagnostic Check Type"::"Option Captions") and (Finding."Related Record ID" = RelatedRecordId) then begin
                    Found += 1;
                    EntryNo := Finding."Entry No.";
                end;
            until Finding.Next() = 0;
        if Found > 0 then
            if not Finding.Get(EntryNo) then
                Error(this.NoFindingErr);
    end;

    /// <summary>Remembers where this run's findings start. The Doctor runner writes to the real table, and so does the test, because AutoIncrement does not number rows of a temporary table.</summary>
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

    local procedure InsertRows()
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.Init();
        ServiceSetup.Validate("Service Name", this.ServiceTok);
        ServiceSetup.Validate("Line Type", ServiceSetup."Line Type"::Main);
        ServiceSetup.Insert(false);

        ServiceSetup.Init();
        ServiceSetup.Validate("Service Name", this.ServiceTok);
        ServiceSetup.Validate("Line Type", ServiceSetup."Line Type"::Field);
        ServiceSetup.Validate("Page Line No.", 10000);
        // Assigned without validation: validating Field No. would rebuild the values the test needs short.
#pragma warning disable PC0037
        ServiceSetup."Table No." := Database::"Approval Entry";
        ServiceSetup."Field No." := this.DocumentTypeFieldNo();
        ServiceSetup.ControlID := 987654321;
        ServiceSetup.FieldName := this.FieldNameTok;
        ServiceSetup.FieldType := ServiceSetup.FieldType::Option;
        ServiceSetup.OptionValues := this.ShortValuesTok;
#pragma warning restore PC0037
        ServiceSetup.Insert(false);
    end;

    local procedure GetFieldRow(var ServiceSetup: Record "MobileNAV Service Setup")
    begin
        if not ServiceSetup.Get(this.ServiceTok, ServiceSetup."Line Type"::Field, 10000, 0, 0) then
            Error(this.NoRowErr);
    end;

    local procedure DocumentTypeFieldNo(): Integer
    var
        ApprovalEntry: Record "Approval Entry";
    begin
        exit(ApprovalEntry.FieldNo("Document Type"));
    end;

    /// <summary>Sets AddOn-Converted Option String and returns the value it had.</summary>
    /// <param name="NewValue">The value to set.</param>
    /// <returns>The value before the change.</returns>
    local procedure SetFlag(NewValue: Boolean) OldValue: Boolean
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        this.GetGeneralSetup(MasterData);
        OldValue := MasterData."AddOn-Converted Option String";
        MasterData.Validate("AddOn-Converted Option String", NewValue);
        MasterData.Modify(false);
    end;

    local procedure GetGeneralSetup(var MasterData: Record "MobileNAV Master Data")
    begin
        if not MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then
            Error(this.NoGeneralSetupErr);
    end;

    local procedure Cleanup()
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Service Name", this.ServiceTok);
        ServiceSetup.DeleteAll(false);
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
        FirstEntryNo: Integer;
        ServiceTok: Label 'BJFOptionCaptionsTest', Locked = true;
        FieldNameTok: Label 'Document_Type', Locked = true;
        ShortValuesTok: Label 'Quote,Order', Locked = true;
        MismatchErr: Label 'Expected %1, got %2.', Comment = '%1 = expected value, %2 = actual value';
        NoRowErr: Label 'The test row is missing.';
        NoFindingErr: Label 'The finding is missing.';
        NotFixableErr: Label 'The finding has no fix.';
        FlagNotSetErr: Label 'AddOn-Converted Option String is still off after the fix.';
        TooFewOptionsErr: Label 'Approval Entry Document Type has two options or fewer, so the test cannot show a short value list.';
        NoGeneralSetupErr: Label 'MobileNAV Master Data has no general setup row. Run the MobileNAV setup first.';
}

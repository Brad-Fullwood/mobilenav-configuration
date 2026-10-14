namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Utilities;

/// <summary>Lists the current user's diagnostic findings, with Apply Fix and Open Related Record actions.</summary>
page 77762 "BJF Diagnostic Findings Part"
{
    Caption = 'Diagnostic Findings';
    PageType = ListPart;
    SourceTable = "BJF Diagnostic Finding";
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Findings)
            {
                field(Severity; Rec.Severity)
                {
                    ApplicationArea = All;
                    StyleExpr = this.SeverityStyle;
                }
                field("Check Type"; Rec."Check Type")
                {
                    ApplicationArea = All;
                }
                field(Message; Rec.Message)
                {
                    ApplicationArea = All;

                    trigger OnDrillDown()
                    begin
                        Message(Rec.Message);
                    end;
                }
                field(Fixable; Rec.Fixable)
                {
                    ApplicationArea = All;
                }
                field("Fix Description"; Rec."Fix Description")
                {
                    ApplicationArea = All;
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ApplyFix)
            {
                ApplicationArea = All;
                Caption = 'Apply Fix';
                Image = CompleteLine;
                Scope = Repeater;
                ToolTip = 'Applies the automatic fix for the selected finding(s). What the fix does is described in the Fix Description column; the fix is provided by the check that produced the finding.';

                trigger OnAction()
                begin
                    this.ApplySelectedFixes();
                end;
            }
            action(OpenRelatedRecord)
            {
                ApplicationArea = All;
                Caption = 'Open Related Record';
                Image = Navigate;
                Scope = Repeater;
                ToolTip = 'Opens the record the selected finding is about (for example the Item Tracking Code or the journal line).';

                trigger OnAction()
                var
                    PageManagement: Codeunit "Page Management";
                    RecRef: RecordRef;
                begin
                    if Rec."Related Record ID".TableNo() = 0 then begin
                        Message(this.NoRelatedRecordMsg);
                        exit;
                    end;
                    if not RecRef.Get(Rec."Related Record ID") then begin
                        Message(this.RelatedRecordGoneMsg);
                        exit;
                    end;
                    PageManagement.PageRun(RecRef);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.FilterGroup(2);
        Rec.SetRange("User ID", UserId());
        Rec.FilterGroup(0);
    end;

    trigger OnAfterGetRecord()
    begin
        case Rec.Severity of
            Rec.Severity::Blocker:
                this.SeverityStyle := Format(PageStyle::Unfavorable);
            Rec.Severity::Warning:
                this.SeverityStyle := Format(PageStyle::Ambiguous);
            else
                this.SeverityStyle := Format(PageStyle::Standard);
        end;
    end;

    local procedure ApplySelectedFixes()
    var
        SelectedFinding: Record "BJF Diagnostic Finding";
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
        DiagnosticCheck: Interface "BJF Diagnostic Check";
        FixCount: Integer;
    begin
        SelectedFinding.Copy(Rec);
        CurrPage.SetSelectionFilter(SelectedFinding);
        #pragma warning disable AA0210 // Only the current user's short findings list is filtered. A key on Fixable is not worth it.
        SelectedFinding.SetRange(Fixable, true);
        #pragma warning restore AA0210
        FixCount := SelectedFinding.Count();
        if FixCount = 0 then begin
            Message(this.NoFixableSelectedMsg);
            exit;
        end;

        if FixCount = 1 then begin
            if not SelectedFinding.FindFirst() then
                exit;
            if not Confirm(StrSubstNo(this.ConfirmSingleFixQst, SelectedFinding."Fix Description"), false) then
                exit;
        end else
            if not Confirm(StrSubstNo(this.ConfirmMultiFixQst, FixCount), false) then
                exit;

        SelectedFinding.FindSet();
        repeat
            DiagnosticCheck := SelectedFinding."Check Type";
            DiagnosticCheck.ApplyFix(SelectedFinding);
        until SelectedFinding.Next() = 0;

        DiagnosticsRunner.RunAll();
        CurrPage.Update(false);
    end;

    var
        SeverityStyle: Text;
        NoRelatedRecordMsg: Label 'This finding has no related record.';
        RelatedRecordGoneMsg: Label 'The related record no longer exists.';
        NoFixableSelectedMsg: Label 'None of the selected findings have an automatic fix.';
        ConfirmSingleFixQst: Label '%1\\Continue?', Comment = '%1 = fix description';
        ConfirmMultiFixQst: Label 'Apply the automatic fix for %1 finding(s)?', Comment = '%1 = number of findings';
}

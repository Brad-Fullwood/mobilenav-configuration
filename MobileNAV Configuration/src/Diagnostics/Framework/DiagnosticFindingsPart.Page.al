namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Utilities;

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
                    ToolTip = 'Specifies how serious the finding is. Blockers break a MobileNAV device flow.';
                }
                field("Check Type"; Rec."Check Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies which diagnostic check produced the finding.';
                }
                field(Message; Rec.Message)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the finding. Drill down to read the full text.';

                    trigger OnDrillDown()
                    begin
                        Message(Rec.Message);
                    end;
                }
                field(Fixable; Rec.Fixable)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the check that produced this finding can repair it automatically with the Apply Fix action.';
                }
                field("Fix Description"; Rec."Fix Description")
                {
                    ApplicationArea = All;
                    Visible = false;
                    ToolTip = 'Specifies what the Apply Fix action will do for this finding.';
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
        SelectedFinding.SetRange(Fixable, true);
        FixCount := SelectedFinding.Count();
        if FixCount = 0 then begin
            Message(this.NoFixableSelectedMsg);
            exit;
        end;

        if FixCount = 1 then begin
            SelectedFinding.FindFirst();
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

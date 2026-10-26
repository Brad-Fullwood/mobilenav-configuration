namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// Runs every diagnostic in a company that has no provider, where the provider-bound actions have no
/// row to bind to. POST {} to api/bjf/mobilenav/v1.0/companies({id})/doctorRuns runs the Doctor and
/// answers with the number of Blocker and Warning findings. Read the findings from diagnosticFindings.
/// </summary>
page 77706 "BJF MN Doctor Run API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Doctor Run';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Doctor Run';
    EntityName = 'doctorRun';
    EntitySetCaption = 'MobileNAV Doctor Runs';
    EntitySetName = 'doctorRuns';
    Extensible = false;
    InsertAllowed = true;
    ModifyAllowed = false;
    ODataKeyFields = "Entry No.";
    PageType = API;
    SourceTable = "BJF Doctor Run Log";
    SourceTableTemporary = true;
    Permissions = tabledata "BJF Diagnostic Finding" = r;

    layout
    {
        area(Content)
        {
            repeater(Runs)
            {
                field(entryNo; Rec."Entry No.") { }
                field(blockers; Rec.Blockers) { Editable = false; }
                field(warnings; Rec.Warnings) { Editable = false; }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        Finding: Record "BJF Diagnostic Finding";
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
    begin
        DiagnosticsRunner.RunAll();
        Finding.SetRange("User ID", CopyStr(UserId(), 1, MaxStrLen(Finding."User ID")));
        Finding.SetRange(Severity, Finding.Severity::Blocker);
        Rec."Entry No." := 1;
        Rec.Blockers := Finding.Count();
        Finding.SetRange(Severity, Finding.Severity::Warning);
        Rec.Warnings := Finding.Count();
        exit(true);
    end;
}

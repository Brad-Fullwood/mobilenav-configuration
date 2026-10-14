namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063, LC0092 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The current user's Doctor findings, produced by runConfigChecks or runAllDiagnostics on
/// configProviders. The bound action applies a finding's automatic fix when it has one.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/diagnosticFindings({id}), where id is the finding's SystemId.
/// </summary>
page 77791 "BJF MN Diagnostic Finding API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Diagnostic Finding';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Diagnostic Finding';
    EntityName = 'diagnosticFinding';
    EntitySetCaption = 'MobileNAV Diagnostic Findings';
    EntitySetName = 'diagnosticFindings';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "BJF Diagnostic Finding";

    layout
    {
        area(Content)
        {
            repeater(Findings)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { Caption = 'Last Modified Date Time'; Editable = false; }
                field(entryNo; Rec."Entry No.") { }
                field(checkType; Rec."Check Type") { }
                field(severity; Rec.Severity) { }
                field(message; Rec.Message) { }
                field(fixable; Rec.Fixable) { }
                field(fixDescription; Rec."Fix Description") { }
                field(relatedRecordId; Format(Rec."Related Record ID")) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.SetRange("User ID", CopyStr(UserId(), 1, MaxStrLen(Rec."User ID")));
    end;

    /// <summary>Applies this finding's automatic fix, then re-runs every diagnostic.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure applyFix(var ActionContext: WebServiceActionContext)
    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
        DiagnosticCheck: Interface "BJF Diagnostic Check";
    begin
        Rec.TestField(Fixable);
        DiagnosticCheck := Rec."Check Type";
        DiagnosticCheck.ApplyFix(Rec);
        DiagnosticsRunner.RunAll();
        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"BJF MN Diagnostic Finding API");
        ActionContext.SetResultCode(WebServiceActionResultCode::Deleted);
    end;
}

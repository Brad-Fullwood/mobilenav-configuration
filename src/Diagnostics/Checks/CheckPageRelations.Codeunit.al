namespace BradFullwood.MobileNAV.Configuration;

codeunit 77774 "BJF Check Page Relations" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rmd;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        // Rebuilding the profile hierarchy walks every page reference and resolves it with a
        // direct Get on the related page's main record, aborting the whole rebuild on the
        // first one it cannot resolve. The error it raises names the page that owns the
        // reference rather than the page that is missing, so the real cause never appears in
        // the message. Until such a reference is cleared, no configuration change of any kind
        // reaches a device, because every rebuild stops at the same record.
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Relation);
        if ServiceSetup.FindSet() then
            repeat
                if not this.RelatedPageExists(ServiceSetup.RelatedPageName) then
                    Finding.AddWithFix(
                        Enum::"BJF Diagnostic Check Type"::"Page Relations", Enum::"BJF Diagnostic Severity"::Blocker,
                        StrSubstNo(this.RelationMsg, ServiceSetup."Service Name", ServiceSetup.RelatedPageName),
                        ServiceSetup.RecordId(),
                        StrSubstNo(this.DeleteRelationFixLbl, ServiceSetup."Service Name", ServiceSetup.RelatedPageName));
            until ServiceSetup.Next() = 0;

        // A list page also points at the card page it opens, which is followed before any
        // relation is looked at and breaks the rebuild in the same way.
        ServiceSetup.Reset();
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if ServiceSetup.FindSet() then
            repeat
                if ServiceSetup.RelatedPageName <> ServiceSetup."Service Name" then
                    if not this.RelatedPageExists(ServiceSetup.RelatedPageName) then
                        Finding.AddWithFix(
                            Enum::"BJF Diagnostic Check Type"::"Page Relations", Enum::"BJF Diagnostic Severity"::Blocker,
                            StrSubstNo(this.PageMsg, ServiceSetup."Service Name", ServiceSetup.RelatedPageName),
                            ServiceSetup.RecordId(),
                            StrSubstNo(this.ClearPageFixLbl, ServiceSetup."Service Name", ServiceSetup.RelatedPageName));
            until ServiceSetup.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        RelationFilter: Record "MobileNAV Service Setup";
        RecRef: RecordRef;
    begin
        if Finding."Related Record ID".TableNo() <> Database::"MobileNAV Service Setup" then
            exit;
        if not RecRef.Get(Finding."Related Record ID") then
            exit; // already cleared
        RecRef.SetTable(ServiceSetup);

        case ServiceSetup."Line Type" of
            ServiceSetup."Line Type"::Relation:
                begin
                    // The filters belong to the relation and would be orphaned without it.
                    RelationFilter.SetRange("Service Name", ServiceSetup."Service Name");
                    RelationFilter.SetRange("Line Type", RelationFilter."Line Type"::Filter);
                    RelationFilter.SetRange("Page Line No.", ServiceSetup."Page Line No.");
                    RelationFilter.SetRange("Relation No.", ServiceSetup."Relation No.");
                    RelationFilter.DeleteAll(false);
                    ServiceSetup.Delete(false);
                end;
            ServiceSetup."Line Type"::Main:
                begin
                    ServiceSetup.RelatedPageName := '';
                    ServiceSetup.Modify(false);
                end;
            else
                Error(this.UnexpectedLineTypeErr);
        end;
    end;

    local procedure RelatedPageExists(RelatedPageName: Text[100]): Boolean
    var
        MainPage: Record "MobileNAV Service Setup";
    begin
        if RelatedPageName = '' then
            exit(true);

        // Resolved the same way the rebuild resolves it, so a main record that exists under
        // unexpected line numbers is reported here exactly as the rebuild would miss it.
        exit(MainPage.Get(RelatedPageName, MainPage."Line Type"::Main));
    end;

    var
        RelationMsg: Label 'Page %1 has a relation to %2, which has no main configuration record. Rebuilding the profile hierarchy stops here and reports it against %1, so no configuration reaches any device. Register %2 in the configuration, or delete the relation.', Comment = '%1 = owning page service name, %2 = missing related page service name';
        PageMsg: Label 'Page %1 opens related page %2, which has no main configuration record. Rebuilding the profile hierarchy stops here and reports it against %1, so no configuration reaches any device. Register %2 in the configuration, or clear the related page.', Comment = '%1 = owning page service name, %2 = missing related page service name';
        DeleteRelationFixLbl: Label 'Delete the relation to the missing page %2 from page %1, together with its filters.', Comment = '%1 = owning page service name, %2 = missing related page service name';
        ClearPageFixLbl: Label 'Clear the missing related page %2 from page %1.', Comment = '%1 = owning page service name, %2 = missing related page service name';
        UnexpectedLineTypeErr: Label 'This finding no longer refers to a page or relation record.';
}

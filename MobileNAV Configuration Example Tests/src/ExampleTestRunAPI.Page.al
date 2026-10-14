namespace BradFullwood.MobileNAV.Example.Tests;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// Runs the example's tests and returns one row per test method. A GET on testResults runs every test
/// codeunit and answers the rows. With $filter=codeunitId eq 50153 only that test codeunit runs. The rows
/// are temporary, so a POST could return one row only: the run happens when the rows are read.
/// Route: api/bjf/mobilenavtests/v1.0/companies({id})/testResults.
/// </summary>
page 50157 "Example Test Run API"
{
    APIGroup = 'mobilenavtests';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'Example Test Run';
    // The run commits through the emulator (its tests call Respond), so it must not read from a read-only replica.
    DataAccessIntent = ReadWrite;
    DeleteAllowed = false;
    Editable = false;
    EntityCaption = 'Example Test Result';
    EntityName = 'testResult';
    EntitySetCaption = 'Example Test Results';
    EntitySetName = 'testResults';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = "Line No.";
    PageType = API;
    SourceTable = "Example Test Result";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field(lineNo; Rec."Line No.") { }
                field(codeunitId; Rec."Codeunit Id") { }
                field(codeunitName; Rec."Codeunit Name") { }
                field(methodName; Rec."Method Name") { }
                field(success; Rec.Success) { }
                field(errorText; Rec."Error Text") { }
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    var
        Runner: Codeunit "Example Test Runner";
        CodeunitFilter: Text;
        RunCodeunitId: Integer;
    begin
        if not this.RunDone then begin
            this.RunDone := true;
            // A filter other than one codeunit id (or none) runs every test codeunit.
            CodeunitFilter := Rec.GetFilter("Codeunit Id");
            if not Evaluate(RunCodeunitId, CodeunitFilter) then
                RunCodeunitId := 0;
            Runner.SetCodeunitId(RunCodeunitId);
            Runner.Run();
            Runner.CopyResults(Rec);
        end;
        exit(Rec.Find(Which));
    end;

    var
        RunDone: Boolean;
}

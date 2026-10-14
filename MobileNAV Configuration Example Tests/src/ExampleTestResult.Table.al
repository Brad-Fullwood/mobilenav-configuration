namespace BradFullwood.MobileNAV.Example.Tests;

/// <summary>
/// One result of the example's tests: a test method, or a test codeunit that failed as a whole. The rows
/// are temporary. They exist for the run that made them and go out in the answer of the test run API.
/// </summary>
table 50158 "Example Test Result"
{
    Caption = 'Example Test Result';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(2; "Codeunit Id"; Integer)
        {
            Caption = 'Codeunit Id';
        }
        field(3; "Codeunit Name"; Text[30])
        {
            Caption = 'Codeunit Name';
        }
        field(4; "Method Name"; Text[128])
        {
            Caption = 'Method Name';
        }
        field(5; Success; Boolean)
        {
            Caption = 'Success';
        }
        field(6; "Error Text"; Text[2048])
        {
            Caption = 'Error Text';
        }
    }

    keys
    {
        key(PK; "Line No.")
        {
            Clustered = true;
        }
    }
}

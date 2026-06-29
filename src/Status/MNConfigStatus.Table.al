#if BJF_MN_CONFIG_SOURCE
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Per-company application state for each stable provider id.</summary>
table 77781 "BJF MN Config Status"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Status';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
        }
        field(2; "Provider Name"; Text[100])
        {
            Caption = 'Provider Name';
        }
        field(3; "Applied Version"; Integer)
        {
            Caption = 'Applied Version';
        }
        field(4; "Applied At"; DateTime)
        {
            Caption = 'Applied At';
        }
        field(5; "Applied By"; Code[50])
        {
            Caption = 'Applied By';
        }
        field(6; "Manually Outdated"; Boolean)
        {
            Caption = 'Manually Outdated';
        }
        field(7; "Outdated At"; DateTime)
        {
            Caption = 'Outdated At';
        }
        field(8; "Outdated By"; Code[50])
        {
            Caption = 'Outdated By';
        }
    }

    keys
    {
        key(PK; "Provider ID")
        {
            Clustered = true;
        }
    }

    procedure PopulateState(var TempProviderBuffer: Record "BJF MN Provider Buffer" temporary)
    begin
        TempProviderBuffer.State := Enum::"BJF MN Config State"::"Not Applied";
        if not Get(TempProviderBuffer."Provider ID") then
            exit;

        TempProviderBuffer."Applied Previously" := true;
        TempProviderBuffer."Applied Version" := "Applied Version";
        TempProviderBuffer."Applied At" := "Applied At";
        TempProviderBuffer."Applied By" := "Applied By";

        if "Manually Outdated" or ("Applied Version" <> TempProviderBuffer."Defined Version") then
            TempProviderBuffer.State := Enum::"BJF MN Config State"::Outdated
        else
            TempProviderBuffer.State := Enum::"BJF MN Config State"::Applied;
    end;

    procedure RecordApplied(ProviderId: Code[50]; ProviderName: Text[100]; ProviderVersion: Integer)
    begin
        if not Get(ProviderId) then begin
            Init();
            "Provider ID" := ProviderId;
            Insert();
        end;

        "Provider Name" := ProviderName;
        "Applied Version" := ProviderVersion;
        "Applied At" := CurrentDateTime();
        "Applied By" := CopyStr(UserId(), 1, MaxStrLen("Applied By"));
        "Manually Outdated" := false;
        Clear("Outdated At");
        Clear("Outdated By");
        Modify();
    end;

    procedure MarkOutdated(ProviderId: Code[50])
    begin
        if not Get(ProviderId) then
            Error(NotAppliedErr, ProviderId);

        "Manually Outdated" := true;
        "Outdated At" := CurrentDateTime();
        "Outdated By" := CopyStr(UserId(), 1, MaxStrLen("Outdated By"));
        Modify();
    end;

    var
        NotAppliedErr: Label 'MobileNAV configuration provider %1 has not been applied and cannot be marked outdated.', Comment = '%1 = provider id';
}
#endif

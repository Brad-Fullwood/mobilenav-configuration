namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Per-company application state for each stable provider id.</summary>
table 77781 "BJF MN Config Status"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Status';
    DataClassification = SystemMetadata;
    Permissions = tabledata "BJF MN Config Status" = rim;

    fields
    {
        field(1; "Provider ID"; Code[50])
        {
            Caption = 'Provider ID';
            NotBlank = true;
        }
        field(2; "Provider Name"; Text[100])
        {
            Caption = 'Provider Name';
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
        field(9; "Device Handover Pending"; Boolean)
        {
            Caption = 'Device Handover Pending';
        }
        field(10; "Content Hash"; Text[64])
        {
            Caption = 'Content Hash';
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
        if not this.Get(TempProviderBuffer."Provider ID") then
            exit;

        TempProviderBuffer."Applied Previously" := true;
        TempProviderBuffer."Applied Hash" := "Content Hash";
        TempProviderBuffer."Applied At" := "Applied At";
        TempProviderBuffer."Applied By" := "Applied By";

        // A pending device handover counts as outdated: the configuration is in the setup
        // tables but has not reached the devices.
        if "Manually Outdated" or "Device Handover Pending" or ("Content Hash" <> TempProviderBuffer."Defined Hash") then
            TempProviderBuffer.State := Enum::"BJF MN Config State"::Outdated
        else
            TempProviderBuffer.State := Enum::"BJF MN Config State"::Applied;
    end;

    procedure RecordApplied(ProviderId: Code[50]; ProviderName: Text[100]; ContentHash: Text[64]; DeviceHandoverPending: Boolean)
    begin
        if not this.Get(ProviderId) then begin
            this.Init();
            "Provider ID" := ProviderId;
            this.Insert(false);
        end;

        "Provider Name" := ProviderName;
        "Content Hash" := ContentHash;
        "Applied At" := CurrentDateTime();
        "Applied By" := CopyStr(UserId(), 1, MaxStrLen("Applied By"));
        "Manually Outdated" := false;
        "Device Handover Pending" := DeviceHandoverPending;
        Clear("Outdated At");
        Clear("Outdated By");
        this.Modify(false);
    end;

    procedure MarkOutdated(ProviderId: Code[50])
    begin
        if not this.Get(ProviderId) then
            Error(this.NotAppliedErr, ProviderId);

        "Manually Outdated" := true;
        "Outdated At" := CurrentDateTime();
        "Outdated By" := CopyStr(UserId(), 1, MaxStrLen("Outdated By"));
        this.Modify(false);
    end;

    var
        NotAppliedErr: Label 'MobileNAV configuration provider %1 has not been applied and cannot be marked outdated.', Comment = '%1 = provider id';
}

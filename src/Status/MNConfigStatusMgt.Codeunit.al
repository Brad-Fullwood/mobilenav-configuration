namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Owns persisted provider application and manual-outdated state.</summary>
codeunit 77783 "BJF MN Config Status Mgt."
{
    Access = Internal;
    Permissions = tabledata "BJF MN Config Status" = rim;

    procedure PopulateState(var ProviderBuffer: Record "BJF MN Provider Buffer" temporary)
    var
        ConfigurationStatus: Record "BJF MN Config Status";
    begin
        ProviderBuffer.State := Enum::"BJF MN Config State"::"Not Applied";
        if not ConfigurationStatus.Get(ProviderBuffer."Provider ID") then
            exit;

        ProviderBuffer."Applied Previously" := true;
        ProviderBuffer."Applied Version" := ConfigurationStatus."Applied Version";
        ProviderBuffer."Applied At" := ConfigurationStatus."Applied At";
        ProviderBuffer."Applied By" := ConfigurationStatus."Applied By";

        if ConfigurationStatus."Manually Outdated" or
           (ConfigurationStatus."Applied Version" <> ProviderBuffer."Defined Version")
        then
            ProviderBuffer.State := Enum::"BJF MN Config State"::Outdated
        else
            ProviderBuffer.State := Enum::"BJF MN Config State"::Applied;
    end;

    procedure RecordApplied(ProviderId: Code[50]; ProviderName: Text[100]; ProviderVersion: Integer)
    var
        ConfigurationStatus: Record "BJF MN Config Status";
    begin
        if not ConfigurationStatus.Get(ProviderId) then begin
            ConfigurationStatus.Init();
            ConfigurationStatus."Provider ID" := ProviderId;
            ConfigurationStatus.Insert();
        end;

        ConfigurationStatus."Provider Name" := ProviderName;
        ConfigurationStatus."Applied Version" := ProviderVersion;
        ConfigurationStatus."Applied At" := CurrentDateTime();
        ConfigurationStatus."Applied By" := CopyStr(UserId(), 1, MaxStrLen(ConfigurationStatus."Applied By"));
        ConfigurationStatus."Manually Outdated" := false;
        Clear(ConfigurationStatus."Outdated At");
        Clear(ConfigurationStatus."Outdated By");
        ConfigurationStatus.Modify();
    end;

    procedure MarkOutdated(ProviderId: Code[50])
    var
        ConfigurationStatus: Record "BJF MN Config Status";
    begin
        if not ConfigurationStatus.Get(ProviderId) then
            Error(NotAppliedErr, ProviderId);

        ConfigurationStatus."Manually Outdated" := true;
        ConfigurationStatus."Outdated At" := CurrentDateTime();
        ConfigurationStatus."Outdated By" := CopyStr(UserId(), 1, MaxStrLen(ConfigurationStatus."Outdated By"));
        ConfigurationStatus.Modify();
    end;

    var
        NotAppliedErr: Label 'MobileNAV configuration provider %1 has not been applied and cannot be marked outdated.', Comment = '%1 = provider id';
}

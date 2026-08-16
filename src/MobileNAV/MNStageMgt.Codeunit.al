namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Owns MobileNAV wizard-stage persistence. The data shape mirrors MobileNAV's own config
/// XML import (ImportPageStages in codeunit "MobileNAV Config XML Handler"): one
/// Line Type::Stage row per stage at Page Line No. 10000, 20000, ..., and a comma-separated
/// mask in each visible field row's Stage field with one token per stage — 'H' hidden,
/// 'R' visible read-only, empty enabled. Stage rows are rebuilt from scratch on every apply
/// so re-applying a provider stays idempotent.
/// </summary>
codeunit 77790 "BJF MN Stage Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rimd,
        tabledata "MobileNAV Master Data" = rim;

    procedure ApplyPageStaging(ServiceName: Text[100]; var ConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        StageIds: List of [Text];
    begin
        ConfigurationLine.Reset();
        ConfigurationLine.SetRange("Page ID", PageId);
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
        ConfigurationLine.FindFirst();
        PageManagement.SetStaging(
            ServiceName, ConfigurationLine."Auto Next Stage", ConfigurationLine."Back-Next Visible");

        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Stage);
        if ConfigurationLine.FindSet() then
            repeat
                StageIds.Add(ConfigurationLine."Stage Id");
                this.EnsureStageCategory(ConfigurationLine."Stage Id", ConfigurationLine."Stage Description");
            until ConfigurationLine.Next() = 0;

        this.RebuildStageRows(ServiceName, StageIds);
        this.InitializeFieldMasks(ServiceName, StageIds.Count());

        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Stage Field");
        if ConfigurationLine.FindSet() then
            repeat
                this.SetFieldMaskToken(
                    ServiceName, StageIds, StageIds.IndexOf(ConfigurationLine."Stage Id"),
                    ConfigurationLine."Control Name", ConfigurationLine."Stage Enabled");
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure RebuildStageRows(ServiceName: Text[100]; StageIds: List of [Text])
    var
        StageRow: Record "MobileNAV Service Setup";
        StageId: Text;
        PageLineNo: Integer;
    begin
        StageRow.SetRange("Service Name", ServiceName);
        StageRow.SetRange("Line Type", StageRow."Line Type"::Stage);
        StageRow.DeleteAll();

        // Mirrors ImportPageStages: stage rows carry only the primary key and the stage id.
        foreach StageId in StageIds do begin
            PageLineNo += 10000;
            StageRow.Init();
            StageRow."Service Name" := ServiceName;
            StageRow."Line Type" := StageRow."Line Type"::Stage;
            StageRow."Page Line No." := PageLineNo;
            StageRow."Relation No." := 0;
            StageRow."Line No." := 0;
            StageRow.Stage := CopyStr(StageId, 1, MaxStrLen(StageRow.Stage));
            StageRow.Insert(false);
        end;
    end;

    local procedure InitializeFieldMasks(ServiceName: Text[100]; StageCount: Integer)
    var
        FieldRow: Record "MobileNAV Service Setup";
    begin
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        FieldRow.SetRange(Visible, true);
        FieldRow.SetFilter(FieldClass, '<>%1&<>%2', FieldRow.FieldClass::GroupStart, FieldRow.FieldClass::GroupEnd);
        FieldRow.ModifyAll(Stage, this.HiddenMask(StageCount), false);
    end;

    local procedure SetFieldMaskToken(ServiceName: Text[100]; StageIds: List of [Text]; StageIndex: Integer; ControlName: Text[100]; FieldEnabled: Boolean)
    var
        FieldRow: Record "MobileNAV Service Setup";
        Tokens: List of [Text];
        MaskText: Text;
        NewMask: Text;
        TokenIndex: Integer;
    begin
        FieldRow.SetRange("Object Type", FieldRow."Object Type"::Page);
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        FieldRow.SetRange(FieldName, this.ConvertFieldName(ControlName));
        if not FieldRow.FindFirst() then
            Error(StageFieldMissingErr, ControlName, ServiceName);

        MaskText := FieldRow.Stage;
        if MaskText = '' then
            MaskText := this.HiddenMask(StageIds.Count());
        Tokens := MaskText.Split(',');

        for TokenIndex := 1 to Tokens.Count() do begin
            if TokenIndex > 1 then
                NewMask += ',';
            if TokenIndex = StageIndex then begin
                if not FieldEnabled then
                    NewMask += 'R';
            end else
                NewMask += Tokens.Get(TokenIndex);
        end;

        FieldRow.Stage := CopyStr(NewMask, 1, MaxStrLen(FieldRow.Stage));
        FieldRow.Modify(false);
    end;

    local procedure HiddenMask(StageCount: Integer) Mask: Text
    var
        StageIndex: Integer;
    begin
        for StageIndex := 1 to StageCount do begin
            if StageIndex > 1 then
                Mask += ',';
            Mask += 'H';
        end;
    end;

    /// <summary>
    /// Stage ids double as MobileNAV category codes, whose descriptions caption the wizard
    /// steps on the device. Categories live in MobileNAV Master Data under Type::Category.
    /// </summary>
    local procedure EnsureStageCategory(StageId: Code[100]; Description: Text[250])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        if MasterData.Get(MasterData.Type::Category, CopyStr(StageId, 1, MaxStrLen(MasterData.Code))) then begin
            if (Description <> '') and (MasterData.Description <> Description) then begin
                MasterData.Description := CopyStr(Description, 1, MaxStrLen(MasterData.Description));
                MasterData.Modify(false);
            end;
            exit;
        end;

        MasterData.Init();
        MasterData.Type := MasterData.Type::Category;
        MasterData.Code := CopyStr(StageId, 1, MaxStrLen(MasterData.Code));
        MasterData.Description := CopyStr(Description, 1, MaxStrLen(MasterData.Description));
        MasterData.Insert(false);
    end;

    local procedure ConvertFieldName(OriginalName: Text): Text[75]
    begin
        exit(CopyStr(WebServiceHandling.ConvertFieldName(OriginalName), 1, 75));
    end;

    var
        PageManagement: Codeunit "BJF MN Page Mgt.";
        WebServiceHandling: Codeunit "MobileNAV Web Service Handling";
        StageFieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 when assigning wizard stages.', Comment = '%1 = control name, %2 = MobileNAV service name';
}

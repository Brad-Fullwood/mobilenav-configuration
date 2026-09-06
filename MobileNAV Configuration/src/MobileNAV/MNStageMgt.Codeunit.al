namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes a wizard's stages the way MobileNAV's own configuration import does: one Stage row
/// per stage at Page Line No. 10000, 20000, ..., and a comma-separated mask on every visible
/// field row with one token per stage: 'H' hidden, 'R' read-only, empty editable. Stage rows
/// are rebuilt from scratch on every apply.
/// </summary>
codeunit 77790 "BJF MN Stage Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rimd;

    /// <summary>Applies the page's Staging, Stage and Stage Field lines.</summary>
    procedure ApplyPageStaging(ServiceName: Text[100]; var ConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        StageIds: List of [Text];
        RestartFromStageId: Text;
    begin
        ConfigurationLine.Reset();
        ConfigurationLine.SetRange("Page ID", PageId);
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
        if not ConfigurationLine.FindFirst() then
            exit;
        this.PageManagement.SetStaging(
            ServiceName, ConfigurationLine."Auto Next Stage", ConfigurationLine."Back-Next Visible",
            ConfigurationLine."Staging Behavior");

        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Stage);
        if ConfigurationLine.FindSet() then
            repeat
                StageIds.Add(ConfigurationLine."Stage Id");
                if ConfigurationLine."Stage Restart From" then
                    RestartFromStageId := ConfigurationLine."Stage Id";
                this.EnsureStageCategory(ConfigurationLine."Stage Id", ConfigurationLine."Stage Description");
            until ConfigurationLine.Next() = 0;

        this.RebuildStageRows(ServiceName, StageIds, RestartFromStageId);
        this.HideAllFieldsInAllStages(ServiceName, StageIds.Count());

        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Stage Field");
        if ConfigurationLine.FindSet() then
            repeat
                this.ShowFieldInStage(
                    ServiceName, ConfigurationLine."Control Name", StageIds.IndexOf(ConfigurationLine."Stage Id"),
                    StageIds.Count(), ConfigurationLine."Stage Enabled");
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure RebuildStageRows(ServiceName: Text[100]; StageIds: List of [Text]; RestartFromStageId: Text)
    var
        StageRow: Record "MobileNAV Service Setup";
        StageId: Text;
        PageLineNo: Integer;
    begin
        StageRow.SetRange("Service Name", ServiceName);
        StageRow.SetRange("Line Type", StageRow."Line Type"::Stage);
        StageRow.DeleteAll(false);

        foreach StageId in StageIds do begin
            PageLineNo += 10000;
            StageRow.Init();
            StageRow.Validate("Service Name", ServiceName);
            StageRow.Validate("Line Type", StageRow."Line Type"::Stage);
            StageRow.Validate("Page Line No.", PageLineNo);
            StageRow.Validate("Relation No.", 0);
            StageRow.Validate("Line No.", 0);
            StageRow.Validate(Stage, CopyStr(StageId, 1, MaxStrLen(StageRow.Stage)));
            StageRow.Validate("Staging Restart From", StageId = RestartFromStageId);
            StageRow.Insert(false);
        end;
    end;

    local procedure HideAllFieldsInAllStages(ServiceName: Text[100]; StageCount: Integer)
    var
        FieldRow: Record "MobileNAV Service Setup";
    begin
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        FieldRow.SetRange(Visible, true);
        FieldRow.SetFilter(FieldClass, '<>%1&<>%2', FieldRow.FieldClass::GroupStart, FieldRow.FieldClass::GroupEnd);
        FieldRow.ModifyAll(Stage, this.HiddenMask(StageCount), false);
    end;

    local procedure ShowFieldInStage(ServiceName: Text[100]; ControlName: Text[100]; StageIndex: Integer; StageCount: Integer; FieldEnabled: Boolean)
    var
        FieldRow: Record "MobileNAV Service Setup";
        Tokens: List of [Text];
        Mask: TextBuilder;
        CurrentMask: Text;
        TokenIndex: Integer;
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, FieldRow) then
            Error(this.StageFieldMissingErr, ControlName, ServiceName);

        CurrentMask := FieldRow.Stage;
        if CurrentMask = '' then
            CurrentMask := this.HiddenMask(StageCount);
        Tokens := CurrentMask.Split(',');
        if not FieldEnabled then
            Tokens.Set(StageIndex, 'R')
        else
            Tokens.Set(StageIndex, '');

        for TokenIndex := 1 to Tokens.Count() do begin
            if TokenIndex > 1 then
                Mask.Append(',');
            Mask.Append(Tokens.Get(TokenIndex));
        end;
        FieldRow.Validate(Stage, CopyStr(Mask.ToText(), 1, MaxStrLen(FieldRow.Stage)));
        FieldRow.Modify(false);
    end;

    local procedure HiddenMask(StageCount: Integer): Text
    var
        Mask: TextBuilder;
        StageIndex: Integer;
    begin
        for StageIndex := 1 to StageCount do begin
            if StageIndex > 1 then
                Mask.Append(',');
            Mask.Append('H');
        end;
        exit(Mask.ToText());
    end;

    /// <summary>Stage ids double as MobileNAV category codes, whose descriptions caption the wizard steps on the device.</summary>
    local procedure EnsureStageCategory(StageId: Code[100]; Description: Text[250])
    begin
        this.MasterDataManagement.EnsureCategory(CopyStr(StageId, 1, 20), Description);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        MasterDataManagement: Codeunit "BJF MN Master Data Mgt.";
        PageManagement: Codeunit "BJF MN Page Mgt.";
        StageFieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 when assigning wizard stages.', Comment = '%1 = control name, %2 = MobileNAV service name';
}

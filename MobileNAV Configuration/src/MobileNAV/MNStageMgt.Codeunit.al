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
    Permissions = tabledata "MobileNAV Service Setup" = imd;

    /// <summary>Applies the page's Staging, Stage and Stage Field lines.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ConfigurationLine">The definition lines of the apply.</param>
    /// <param name="PageId">The page object ID.</param>
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
        this.ShowFieldsInStages(ServiceName, ConfigurationLine, StageIds);
        ConfigurationLine.Reset();
    end;

    /// <summary>The token a Stage Field line puts in its stage's place in the mask: empty when the field is editable there, R read-only.</summary>
    /// <param name="StageLine">The Stage Field line.</param>
    /// <returns>The token.</returns>
    procedure ExpectedToken(StageLine: Record "BJF MN Config Line" temporary): Text
    begin
        if StageLine."Stage Enabled" then
            exit('');
        exit(this.ReadOnlyToken());
    end;

    /// <summary>A field row's token for one stage, trimmed; empty when the mask is empty or shorter.</summary>
    /// <param name="Mask">The field row's stage mask.</param>
    /// <param name="StageIndex">The stage, from 1.</param>
    /// <returns>The token.</returns>
    procedure TokenAt(Mask: Text; StageIndex: Integer): Text
    var
        Tokens: List of [Text];
    begin
        if Mask = '' then
            exit('');
        Tokens := Mask.Split(',');
        if StageIndex > Tokens.Count() then
            exit('');
        exit(Tokens.Get(StageIndex).Trim());
    end;

    /// <summary>The mask token for a field hidden in a stage.</summary>
    /// <returns>H.</returns>
    procedure HiddenToken(): Text
    begin
        exit(this.HiddenTok);
    end;

    /// <summary>The mask token for a field shown read-only in a stage.</summary>
    /// <returns>R.</returns>
    procedure ReadOnlyToken(): Text
    begin
        exit(this.ReadOnlyTok);
    end;

    /// <summary>
    /// Writes the Stage Field lines into the masks, one read and one modify per control. The
    /// lines of a control apply in declaration order, and controls in the order they first appear.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="StageFieldLine">The page's Stage Field lines.</param>
    /// <param name="StageIds">The declared stage IDs in order.</param>
    local procedure ShowFieldsInStages(ServiceName: Text[100]; var StageFieldLine: Record "BJF MN Config Line" temporary; StageIds: List of [Text])
    var
        ControlNames: List of [Text];
        StageIndexes: Dictionary of [Text, List of [Integer]];
        Tokens: Dictionary of [Text, List of [Text]];
        ControlName: Text[100];
    begin
        if StageFieldLine.FindSet() then
            repeat
                ControlName := StageFieldLine."Control Name";
                if not ControlNames.Contains(ControlName) then begin
                    ControlNames.Add(ControlName);
                    StageIndexes.Add(ControlName, this.NewIntegerList());
                    Tokens.Add(ControlName, this.NewTextList());
                end;
                // A List is a reference type: Get returns the list the dictionary holds.
                StageIndexes.Get(ControlName).Add(StageIds.IndexOf(StageFieldLine."Stage Id"));
                Tokens.Get(ControlName).Add(this.ExpectedToken(StageFieldLine));
            until StageFieldLine.Next() = 0;
        foreach ControlName in ControlNames do
            this.WriteControlMask(ServiceName, ControlName, StageIndexes.Get(ControlName), Tokens.Get(ControlName), StageIds.Count());
    end;

    local procedure NewIntegerList(): List of [Integer]
    var
        Values: List of [Integer];
    begin
        exit(Values);
    end;

    local procedure NewTextList(): List of [Text]
    var
        Values: List of [Text];
    begin
        exit(Values);
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

    /// <summary>Sets a control's tokens in its field row's mask and writes the mask once.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="ControlName">The control name from the definition.</param>
    /// <param name="StageIndexes">The stage of each of the control's Stage Field lines, from 1.</param>
    /// <param name="StageTokens">The token of each of the control's Stage Field lines.</param>
    /// <param name="StageCount">The number of declared stages.</param>
    local procedure WriteControlMask(ServiceName: Text[100]; ControlName: Text[100]; StageIndexes: List of [Integer]; StageTokens: List of [Text]; StageCount: Integer)
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
        for TokenIndex := 1 to StageIndexes.Count() do
            Tokens.Set(StageIndexes.Get(TokenIndex), StageTokens.Get(TokenIndex));

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
            Mask.Append(this.HiddenToken());
        end;
        exit(Mask.ToText());
    end;

    /// <summary>Stage ids double as MobileNAV category codes, whose descriptions caption the wizard steps on the device.</summary>
    /// <param name="StageId">The stage ID from the definition.</param>
    /// <param name="Description">The category description.</param>
    local procedure EnsureStageCategory(StageId: Code[100]; Description: Text[250])
    begin
        this.MasterDataManagement.EnsureCategory(CopyStr(StageId, 1, 20), Description);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        MasterDataManagement: Codeunit "BJF MN Master Data Mgt.";
        PageManagement: Codeunit "BJF MN Page Mgt.";
        HiddenTok: Label 'H', Locked = true;
        ReadOnlyTok: Label 'R', Locked = true;
        StageFieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 when assigning wizard stages.', Comment = '%1 = control name, %2 = MobileNAV service name';
}

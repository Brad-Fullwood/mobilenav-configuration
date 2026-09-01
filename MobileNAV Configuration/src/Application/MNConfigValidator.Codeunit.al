namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Validates a complete provider definition before any persistent data is changed. The builder
/// already refuses malformed declarations as they are made, so what is left to check here is
/// what only the whole definition reveals: the same target declared twice, and the wizard rules
/// MobileNAV enforces across stages. Every rule is declaration-order independent.
/// </summary>
codeunit 77785 "BJF MN Config Validator"
{
    Access = Internal;

    procedure Validate(var ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        DefinedTargets: Dictionary of [Text, Boolean];
    begin
        ConfigurationLine.Reset();
        if ConfigurationLine.IsEmpty() then
            Error(this.EmptyDefinitionErr);

        if ConfigurationLine.FindSet() then
            repeat
                this.ValidateLine(ConfigurationLine, DefinedTargets);
            until ConfigurationLine.Next() = 0;
        this.ValidateRestartStages(ConfigurationLine);
        ConfigurationLine.Reset();
    end;

    local procedure ValidateLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedTargets: Dictionary of [Text, Boolean])
    begin
        case ConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::"Published Page":
                this.EnsureUnique(DefinedTargets, StrSubstNo(this.PageKeyTok, ConfigurationLine."Page ID"));
            Enum::"BJF MN Config Operation"::Field,
            Enum::"BJF MN Config Operation"::"Linked Field",
            Enum::"BJF MN Config Operation"::"Function Field",
            Enum::"BJF MN Config Operation"::"Scan Field":
                this.EnsureUnique(
                    DefinedTargets,
                    StrSubstNo(this.ControlKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
            Enum::"BJF MN Config Operation"::"Profile Field":
                this.EnsureUnique(
                    DefinedTargets,
                    StrSubstNo(
                        this.ProfileFieldKeyTok, ConfigurationLine."Page ID",
                        LowerCase(ConfigurationLine."Control Name"), LowerCase(ConfigurationLine.Profile)));
            Enum::"BJF MN Config Operation"::"User Scope":
                this.EnsureUnique(DefinedTargets, StrSubstNo(this.UserScopeKeyTok, ConfigurationLine."Page ID"));
            Enum::"BJF MN Config Operation"::Staging:
                this.EnsureUnique(DefinedTargets, StrSubstNo(this.StagingKeyTok, ConfigurationLine."Page ID"));
            Enum::"BJF MN Config Operation"::Stage:
                this.ValidateStageLine(ConfigurationLine, DefinedTargets);
            Enum::"BJF MN Config Operation"::"Stage Field":
                this.EnsureUnique(
                    DefinedTargets,
                    StrSubstNo(
                        this.StageFieldKeyTok, ConfigurationLine."Page ID",
                        LowerCase(ConfigurationLine."Stage Id"), LowerCase(ConfigurationLine."Control Name")));
        end;
    end;

    local procedure ValidateStageLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedTargets: Dictionary of [Text, Boolean])
    begin
        // Stage ids double as MobileNAV category codes (Code[20]); a longer id
        // passes the apply but fails on the device during configuration sync.
        if StrLen(ConfigurationLine."Stage Id") > this.MaxStageIdLength() then
            Error(this.StageIdTooLongErr, ConfigurationLine."Stage Id", this.MaxStageIdLength());
        this.EnsureUnique(
            DefinedTargets,
            StrSubstNo(this.StageKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Stage Id")));
    end;

    /// <summary>
    /// MobileNAV keeps one restart-from stage per page and restarts from the first stage anyway,
    /// so a flag on the first stage marks the wrong stage and two flags cannot both survive.
    /// </summary>
    local procedure ValidateRestartStages(var ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        FirstStageOfPage: Dictionary of [Integer, Code[100]];
        RestartStageOfPage: Dictionary of [Integer, Code[100]];
    begin
        ConfigurationLine.Reset();
        ConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Stage);
        if ConfigurationLine.FindSet() then
            repeat
                if not FirstStageOfPage.ContainsKey(ConfigurationLine."Page ID") then
                    FirstStageOfPage.Add(ConfigurationLine."Page ID", ConfigurationLine."Stage Id");
                if ConfigurationLine."Stage Restart From" then begin
                    if FirstStageOfPage.Get(ConfigurationLine."Page ID") = ConfigurationLine."Stage Id" then
                        Error(this.RestartFromFirstStageErr, ConfigurationLine."Stage Id");
                    if RestartStageOfPage.ContainsKey(ConfigurationLine."Page ID") then
                        Error(this.RestartFromDuplicateErr, ConfigurationLine."Stage Id", RestartStageOfPage.Get(ConfigurationLine."Page ID"));
                    RestartStageOfPage.Add(ConfigurationLine."Page ID", ConfigurationLine."Stage Id");
                end;
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure MaxStageIdLength(): Integer
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        exit(MaxStrLen(MasterData.Code));
    end;

    local procedure EnsureUnique(var DefinedTargets: Dictionary of [Text, Boolean]; TargetKey: Text)
    begin
        if DefinedTargets.ContainsKey(TargetKey) then
            Error(this.DuplicateTargetErr, TargetKey);
        DefinedTargets.Add(TargetKey, true);
    end;

    var
        EmptyDefinitionErr: Label 'The provider did not define any MobileNAV configuration.';
        StageIdTooLongErr: Label 'Stage id %1 exceeds %2 characters. Stage ids double as MobileNAV category codes and longer ids fail on the device during configuration sync.', Comment = '%1 = stage id, %2 = maximum length';
        DuplicateTargetErr: Label 'The provider declares the same configuration target more than once: %1.', Comment = '%1 = normalized target key';
        RestartFromFirstStageErr: Label 'Stage %1 is marked RestartsHere but it is the page''s first stage. The wizard restarts from the first stage anyway, so flag a later stage or none.', Comment = '%1 = stage id';
        RestartFromDuplicateErr: Label 'Stage %1 is marked RestartsHere but stage %2 on the same page already is. MobileNAV keeps a single restart-from stage per page.', Comment = '%1 = stage id, %2 = other stage id';
        PageKeyTok: Label 'PAGE|%1', Locked = true;
        ControlKeyTok: Label 'CONTROL|%1|%2', Locked = true;
        ProfileFieldKeyTok: Label 'PROFILEFIELD|%1|%2|%3', Locked = true;
        UserScopeKeyTok: Label 'USERSCOPE|%1', Locked = true;
        StagingKeyTok: Label 'STAGING|%1', Locked = true;
        StageKeyTok: Label 'STAGE|%1|%2', Locked = true;
        StageFieldKeyTok: Label 'STAGEFIELD|%1|%2|%3', Locked = true;
}

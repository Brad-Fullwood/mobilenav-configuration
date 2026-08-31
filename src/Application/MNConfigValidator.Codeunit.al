
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Validates a complete provider definition before any persistent data is changed.</summary>
codeunit 77785 "BJF MN Config Validator"
{
    Access = Internal;

    procedure Validate(var ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        DefinedOperations: Dictionary of [Text, Boolean];
    begin
        ConfigurationLine.Reset();
        if ConfigurationLine.IsEmpty() then
            Error(this.EmptyDefinitionErr);

        if ConfigurationLine.FindSet() then
            repeat
                this.ValidateLine(ConfigurationLine, DefinedOperations);
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure ValidateLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Page ID" <= 0 then
            Error(this.PageIdRequiredErr, ConfigurationLine."Entry No.");

        case ConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::"Published Page":
                this.ValidatePublishedPageLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::Field:
                this.ValidateFieldLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::"Linked Field":
                this.ValidateLinkedFieldLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::"Function Field":
                this.ValidateFunctionFieldLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::"Profile Field":
                this.ValidateProfileFieldLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::"User Scope":
                this.ValidateUserScopeLine(ConfigurationLine, DefinedOperations);
        end;
        this.ValidateStageGroupLine(ConfigurationLine, DefinedOperations);
    end;

    local procedure ValidatePublishedPageLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Service Name" = '' then
            Error(this.ServiceNameRequiredErr, ConfigurationLine."Entry No.");
        this.EnsureUnique(DefinedOperations, StrSubstNo(this.PageOperationKeyTok, ConfigurationLine."Page ID"));
    end;

    local procedure ValidateFieldLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        // The builder always emits an importance, so an empty one means the line
        // did not come from the builder rather than "leave MobileNAV's default".
        if ConfigurationLine.Importance = '' then
            Error(this.ImportanceRequiredErr, ConfigurationLine."Entry No.");
        this.RequireImportanceValue(ConfigurationLine);
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(this.FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
    end;

    /// <summary>
    /// A profile line keys on page, control and profile rather than page and control: it sits
    /// alongside the control's own field line rather than replacing it, and a control can be
    /// declared for several named profiles.
    /// </summary>
    local procedure ValidateProfileFieldLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(
                this.ProfileFieldOperationKeyTok, ConfigurationLine."Page ID",
                LowerCase(ConfigurationLine."Control Name"), LowerCase(ConfigurationLine.Profile)));
    end;

    local procedure ValidateUserScopeLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        this.EnsureUnique(DefinedOperations, StrSubstNo(this.UserScopeOperationKeyTok, ConfigurationLine."Page ID"));
    end;

    local procedure ValidateLinkedFieldLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Target Page ID" <= 0 then
            Error(this.TargetPageIdRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Target Filter Field" = '' then
            Error(this.TargetFieldRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Source Field" = '' then
            Error(this.SourceFieldRequiredErr, ConfigurationLine."Entry No.");
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(this.FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
    end;

    local procedure ValidateFunctionFieldLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Mobile Type" = '' then
            Error(this.MobileTypeRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Function Name" = '' then
            Error(this.FunctionNameRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Function Type" = '' then
            Error(this.FunctionTypeRequiredErr, ConfigurationLine."Entry No.");
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(this.FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
    end;

    local procedure ValidateStageGroupLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        case ConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::"Scan Field":
                this.ValidateScanFieldLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::Staging:
                this.ValidateStagingLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::Stage:
                this.ValidateStageLine(ConfigurationLine, DefinedOperations);
            Enum::"BJF MN Config Operation"::"Stage Field":
                this.ValidateStageFieldLine(ConfigurationLine, DefinedOperations);
        end;
    end;

    local procedure ValidateScanFieldLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(this.FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
    end;

    local procedure ValidateStagingLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        this.RequireStagingBehaviorValue(ConfigurationLine);
        this.EnsureUnique(DefinedOperations, StrSubstNo(this.StagingOperationKeyTok, ConfigurationLine."Page ID"));
    end;

    local procedure ValidateStageLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Stage Id" = '' then
            Error(this.StageIdRequiredErr, ConfigurationLine."Entry No.");
        // Stage ids double as MobileNAV category codes (Code[20]); a longer id
        // passes the apply but fails on the device during configuration sync.
        if StrLen(ConfigurationLine."Stage Id") > this.MaxStageIdLength() then
            Error(this.StageIdTooLongErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id", this.MaxStageIdLength());
        if not DefinedOperations.ContainsKey(StrSubstNo(this.StagingOperationKeyTok, ConfigurationLine."Page ID")) then
            Error(this.StagingNotDeclaredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Stage Restart From" then
            this.ValidateStageRestartFrom(ConfigurationLine, DefinedOperations);
        if not DefinedOperations.ContainsKey(StrSubstNo(this.FirstStageKeyTok, ConfigurationLine."Page ID")) then
            DefinedOperations.Add(StrSubstNo(this.FirstStageKeyTok, ConfigurationLine."Page ID"), true);
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(this.StageOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Stage Id")));
    end;

    local procedure ValidateStageRestartFrom(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        // Restarting from the first stage is what MobileNAV does anyway, so a
        // flag there means the provider marked the wrong stage.
        if not DefinedOperations.ContainsKey(StrSubstNo(this.FirstStageKeyTok, ConfigurationLine."Page ID")) then
            Error(this.RestartFromFirstStageErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id");
        // MobileNAV's stage configurator keeps a single restart-from stage per
        // page (it clears the flag from every other stage), so two flagged
        // stages cannot both survive an apply.
        if DefinedOperations.ContainsKey(StrSubstNo(this.RestartFromKeyTok, ConfigurationLine."Page ID")) then
            Error(this.RestartFromDuplicateErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id");
        DefinedOperations.Add(StrSubstNo(this.RestartFromKeyTok, ConfigurationLine."Page ID"), true);
    end;

    local procedure ValidateStageFieldLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Stage Id" = '' then
            Error(this.StageIdRequiredErr, ConfigurationLine."Entry No.");
        if ConfigurationLine."Control Name" = '' then
            Error(this.ControlNameRequiredErr, ConfigurationLine."Entry No.");
        if not DefinedOperations.ContainsKey(
            StrSubstNo(this.StageOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Stage Id")))
        then
            Error(this.StageNotDeclaredErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id");
        this.EnsureUnique(
            DefinedOperations,
            StrSubstNo(
                this.StageFieldOperationKeyTok, ConfigurationLine."Page ID",
                LowerCase(ConfigurationLine."Stage Id"), LowerCase(ConfigurationLine."Control Name")));
    end;

    local procedure MaxStageIdLength(): Integer
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        exit(MaxStrLen(MasterData.Code));
    end;

    local procedure RequireStagingBehaviorValue(ConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        // Empty keeps the library's long-standing default ('Always'). The member names are
        // checked here so a typo fails the validation pass rather than the option resolution
        // midway through an apply.
        case UpperCase(ConfigurationLine."Staging Behavior") of
            '', 'ALWAYS', 'CREATIONONLY', 'PERSISTSTATE':
                exit;
        end;
        Error(
            this.StagingBehaviorInvalidErr, ConfigurationLine."Entry No.",
            ConfigurationLine."Staging Behavior", this.SupportedStagingBehaviorTok);
    end;

    local procedure RequireImportanceValue(ConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        case UpperCase(ConfigurationLine.Importance) of
            'NONE', 'REQUIREDFORINSERT', 'MANDATORY', 'ADDITIONAL':
                exit;
        end;
        Error(this.ImportanceInvalidErr, ConfigurationLine."Entry No.", ConfigurationLine.Importance, this.SupportedImportanceTok);
    end;

    local procedure EnsureUnique(var DefinedOperations: Dictionary of [Text, Boolean]; OperationKey: Text)
    begin
        if DefinedOperations.ContainsKey(OperationKey) then
            Error(this.DuplicateOperationErr, OperationKey);
        DefinedOperations.Add(OperationKey, true);
    end;

    var
        EmptyDefinitionErr: Label 'The provider did not define any MobileNAV configuration.';
        PageIdRequiredErr: Label 'Configuration line %1 must specify a positive page ID.', Comment = '%1 = configuration line number';
        ServiceNameRequiredErr: Label 'Configuration line %1 must specify a preferred service name.', Comment = '%1 = configuration line number';
        ControlNameRequiredErr: Label 'Configuration line %1 must specify a control name.', Comment = '%1 = configuration line number';
        TargetPageIdRequiredErr: Label 'Configuration line %1 must specify a positive target page ID.', Comment = '%1 = configuration line number';
        TargetFieldRequiredErr: Label 'Configuration line %1 must specify a target filter field.', Comment = '%1 = configuration line number';
        SourceFieldRequiredErr: Label 'Configuration line %1 must specify a source field.', Comment = '%1 = configuration line number';
        MobileTypeRequiredErr: Label 'Configuration line %1 must specify a mobile type.', Comment = '%1 = configuration line number';
        FunctionNameRequiredErr: Label 'Configuration line %1 must specify a function name.', Comment = '%1 = configuration line number';
        FunctionTypeRequiredErr: Label 'Configuration line %1 must specify a function type.', Comment = '%1 = configuration line number';
        ImportanceRequiredErr: Label 'Configuration line %1 must specify an importance.', Comment = '%1 = configuration line number';
        ImportanceInvalidErr: Label 'Configuration line %1 specifies importance %2, which is not one of %3.', Comment = '%1 = configuration line number, %2 = requested importance, %3 = supported importance values';
        StageIdRequiredErr: Label 'Configuration line %1 must specify a stage id.', Comment = '%1 = configuration line number';
        StageIdTooLongErr: Label 'Configuration line %1: stage id %2 exceeds %3 characters. Stage ids double as MobileNAV category codes and longer ids fail on the device during configuration sync.', Comment = '%1 = configuration line number, %2 = stage id, %3 = maximum length';
        StagingNotDeclaredErr: Label 'Configuration line %1 defines a stage on a page without a preceding EnableStaging declaration.', Comment = '%1 = configuration line number';
        StageNotDeclaredErr: Label 'Configuration line %1 assigns a field to stage %2, which has no preceding AddStage declaration.', Comment = '%1 = configuration line number, %2 = stage id';
        DuplicateOperationErr: Label 'The provider defines the same configuration target more than once: %1.', Comment = '%1 = normalized operation key';
        StagingBehaviorInvalidErr: Label 'Configuration line %1 specifies staging behavior %2, which is not one of %3.', Comment = '%1 = configuration line number, %2 = requested staging behavior, %3 = supported staging behavior values';
        RestartFromFirstStageErr: Label 'Configuration line %1 marks stage %2 as the restart-from stage, but it is the page''s first stage. The wizard restarts from the first stage anyway, so flag a later stage or none.', Comment = '%1 = configuration line number, %2 = stage id';
        RestartFromDuplicateErr: Label 'Configuration line %1 marks stage %2 as the restart-from stage, but the page already has one. MobileNAV keeps a single restart-from stage per page.', Comment = '%1 = configuration line number, %2 = stage id';
        SupportedImportanceTok: Label 'None, RequiredForInsert, Mandatory, Additional', Locked = true;
        SupportedStagingBehaviorTok: Label 'Always, CreationOnly, PersistState', Locked = true;
        PageOperationKeyTok: Label 'PAGE|%1', Locked = true;
        FieldOperationKeyTok: Label 'FIELD|%1|%2', Locked = true;
        ProfileFieldOperationKeyTok: Label 'PROFILEFIELD|%1|%2|%3', Locked = true;
        UserScopeOperationKeyTok: Label 'USERSCOPE|%1', Locked = true;
        StagingOperationKeyTok: Label 'STAGING|%1', Locked = true;
        FirstStageKeyTok: Label 'STAGEFIRST|%1', Locked = true;
        RestartFromKeyTok: Label 'STAGERESTART|%1', Locked = true;
        StageOperationKeyTok: Label 'STAGE|%1|%2', Locked = true;
        StageFieldOperationKeyTok: Label 'STAGEFIELD|%1|%2|%3', Locked = true;
}

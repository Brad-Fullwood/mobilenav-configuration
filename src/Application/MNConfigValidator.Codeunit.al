
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
            Error(EmptyDefinitionErr);

        if ConfigurationLine.FindSet() then
            repeat
                this.ValidateLine(ConfigurationLine, DefinedOperations);
            until ConfigurationLine.Next() = 0;
        ConfigurationLine.Reset();
    end;

    local procedure ValidateLine(ConfigurationLine: Record "BJF MN Config Line" temporary; var DefinedOperations: Dictionary of [Text, Boolean])
    begin
        if ConfigurationLine."Page ID" <= 0 then
            Error(PageIdRequiredErr, ConfigurationLine."Entry No.");

        case ConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::"Published Page":
                begin
                    this.RequireValue(ConfigurationLine."Service Name", ServiceNameRequiredErr, ConfigurationLine."Entry No.");
                    this.EnsureUnique(DefinedOperations, StrSubstNo(PageOperationKeyTok, ConfigurationLine."Page ID"));
                end;
            Enum::"BJF MN Config Operation"::Field:
                begin
                    this.RequireValue(ConfigurationLine."Control Name", ControlNameRequiredErr, ConfigurationLine."Entry No.");
                    // The builder always emits an importance, so an empty one means the line
                    // did not come from the builder rather than "leave MobileNAV's default".
                    this.RequireValue(ConfigurationLine.Importance, ImportanceRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireImportanceValue(ConfigurationLine);
                    this.EnsureUnique(
                        DefinedOperations,
                        StrSubstNo(FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
                end;
            Enum::"BJF MN Config Operation"::"Linked Field":
                begin
                    this.RequireValue(ConfigurationLine."Control Name", ControlNameRequiredErr, ConfigurationLine."Entry No.");
                    if ConfigurationLine."Target Page ID" <= 0 then
                        Error(TargetPageIdRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireValue(ConfigurationLine."Target Filter Field", TargetFieldRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireValue(ConfigurationLine."Source Field", SourceFieldRequiredErr, ConfigurationLine."Entry No.");
                    this.EnsureUnique(
                        DefinedOperations,
                        StrSubstNo(FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
                end;
            Enum::"BJF MN Config Operation"::"Function Field":
                begin
                    this.RequireValue(ConfigurationLine."Control Name", ControlNameRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireValue(ConfigurationLine."Mobile Type", MobileTypeRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireValue(ConfigurationLine."Function Name", FunctionNameRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireValue(ConfigurationLine."Function Type", FunctionTypeRequiredErr, ConfigurationLine."Entry No.");
                    this.EnsureUnique(
                        DefinedOperations,
                        StrSubstNo(FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
                end;
            Enum::"BJF MN Config Operation"::"Scan Field":
                begin
                    this.RequireValue(ConfigurationLine."Control Name", ControlNameRequiredErr, ConfigurationLine."Entry No.");
                    this.EnsureUnique(
                        DefinedOperations,
                        StrSubstNo(FieldOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
                end;
            Enum::"BJF MN Config Operation"::Staging:
                begin
                    this.RequireStagingBehaviorValue(ConfigurationLine);
                    this.EnsureUnique(DefinedOperations, StrSubstNo(StagingOperationKeyTok, ConfigurationLine."Page ID"));
                end;
            Enum::"BJF MN Config Operation"::Stage:
                begin
                    this.RequireValue(ConfigurationLine."Stage Id", StageIdRequiredErr, ConfigurationLine."Entry No.");
                    // Stage ids double as MobileNAV category codes (Code[20]); a longer id
                    // passes the apply but fails on the device during configuration sync.
                    if StrLen(ConfigurationLine."Stage Id") > MaxStageIdLength() then
                        Error(StageIdTooLongErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id", MaxStageIdLength());
                    if not DefinedOperations.ContainsKey(StrSubstNo(StagingOperationKeyTok, ConfigurationLine."Page ID")) then
                        Error(StagingNotDeclaredErr, ConfigurationLine."Entry No.");
                    if ConfigurationLine."Stage Restart From" then begin
                        // Restarting from the first stage is what MobileNAV does anyway, so a
                        // flag there means the provider marked the wrong stage.
                        if not DefinedOperations.ContainsKey(StrSubstNo(FirstStageKeyTok, ConfigurationLine."Page ID")) then
                            Error(RestartFromFirstStageErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id");
                        // MobileNAV's stage configurator keeps a single restart-from stage per
                        // page (it clears the flag from every other stage), so two flagged
                        // stages cannot both survive an apply.
                        if DefinedOperations.ContainsKey(StrSubstNo(RestartFromKeyTok, ConfigurationLine."Page ID")) then
                            Error(RestartFromDuplicateErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id");
                        DefinedOperations.Add(StrSubstNo(RestartFromKeyTok, ConfigurationLine."Page ID"), true);
                    end;
                    if not DefinedOperations.ContainsKey(StrSubstNo(FirstStageKeyTok, ConfigurationLine."Page ID")) then
                        DefinedOperations.Add(StrSubstNo(FirstStageKeyTok, ConfigurationLine."Page ID"), true);
                    this.EnsureUnique(
                        DefinedOperations,
                        StrSubstNo(StageOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Stage Id")));
                end;
            Enum::"BJF MN Config Operation"::"Stage Field":
                begin
                    this.RequireValue(ConfigurationLine."Stage Id", StageIdRequiredErr, ConfigurationLine."Entry No.");
                    this.RequireValue(ConfigurationLine."Control Name", ControlNameRequiredErr, ConfigurationLine."Entry No.");
                    if not DefinedOperations.ContainsKey(
                        StrSubstNo(StageOperationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Stage Id")))
                    then
                        Error(StageNotDeclaredErr, ConfigurationLine."Entry No.", ConfigurationLine."Stage Id");
                    this.EnsureUnique(
                        DefinedOperations,
                        StrSubstNo(
                            StageFieldOperationKeyTok, ConfigurationLine."Page ID",
                            LowerCase(ConfigurationLine."Stage Id"), LowerCase(ConfigurationLine."Control Name")));
                end;
        end;
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
            StagingBehaviorInvalidErr, ConfigurationLine."Entry No.",
            ConfigurationLine."Staging Behavior", SupportedStagingBehaviorTok);
    end;

    local procedure RequireImportanceValue(ConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        case UpperCase(ConfigurationLine.Importance) of
            'NONE', 'REQUIREDFORINSERT', 'MANDATORY', 'ADDITIONAL':
                exit;
        end;
        Error(ImportanceInvalidErr, ConfigurationLine."Entry No.", ConfigurationLine.Importance, SupportedImportanceTok);
    end;

    local procedure RequireValue(Value: Text; ErrorMessage: Text; EntryNo: Integer)
    begin
        if Value = '' then
            Error(ErrorMessage, EntryNo);
    end;

    local procedure EnsureUnique(var DefinedOperations: Dictionary of [Text, Boolean]; OperationKey: Text)
    begin
        if DefinedOperations.ContainsKey(OperationKey) then
            Error(DuplicateOperationErr, OperationKey);
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
        StagingOperationKeyTok: Label 'STAGING|%1', Locked = true;
        FirstStageKeyTok: Label 'STAGEFIRST|%1', Locked = true;
        RestartFromKeyTok: Label 'STAGERESTART|%1', Locked = true;
        StageOperationKeyTok: Label 'STAGE|%1|%2', Locked = true;
        StageFieldOperationKeyTok: Label 'STAGEFIELD|%1|%2|%3', Locked = true;
}

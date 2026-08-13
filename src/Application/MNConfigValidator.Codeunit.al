
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
        end;
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
        DuplicateOperationErr: Label 'The provider defines the same configuration target more than once: %1.', Comment = '%1 = normalized operation key';
        PageOperationKeyTok: Label 'PAGE|%1', Locked = true;
        FieldOperationKeyTok: Label 'FIELD|%1|%2', Locked = true;
}

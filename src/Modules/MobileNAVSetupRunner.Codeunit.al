namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Dispatches setup modules registered by dependent extensions.
/// </summary>
codeunit 77782 "BJF MobileNAV Setup Runner"
{
    trigger OnRun()
    begin
        ApplyAll();
    end;

    /// <summary>Applies every registered setup module, excluding the None placeholder.</summary>
    procedure ApplyAll()
    var
        SetupModuleType: Enum "BJF MobileNAV Setup Module";
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"BJF MobileNAV Setup Module".Ordinals() do
            if Ordinal <> Enum::"BJF MobileNAV Setup Module"::None.AsInteger() then begin
                SetupModuleType := Enum::"BJF MobileNAV Setup Module".FromInteger(Ordinal);
                ApplyModule(SetupModuleType);
            end;
    end;

    /// <summary>Applies one setup module. Intended for consumer install and upgrade codeunits.</summary>
    procedure ApplyModule(SetupModuleType: Enum "BJF MobileNAV Setup Module")
    var
        SetupModule: Interface "BJF MobileNAV Setup Module";
    begin
        if SetupModuleType = Enum::"BJF MobileNAV Setup Module"::None then
            exit;

        SetupModule := SetupModuleType;
        SetupModule.ApplySetup();
    end;
}

namespace BradFullwood.MobileNAV.Configuration;

codeunit 77702 "BJF Check Config Groups" implements "BJF Diagnostic Check"
{
    Access = Internal;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    begin
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    var
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
}

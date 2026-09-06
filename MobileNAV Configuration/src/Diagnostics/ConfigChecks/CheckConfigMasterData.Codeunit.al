namespace BradFullwood.MobileNAV.Configuration;

codeunit 77704 "BJF Check Config Master Data" implements "BJF Diagnostic Check"
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

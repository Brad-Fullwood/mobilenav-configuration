namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Runs one emulator request inside Codeunit.Run, so that an error in the dispatcher stops this
/// codeunit only. "BJF MN Emulator".Respond reads that error and returns it as an error response,
/// and the emulator page keeps working.
/// </summary>
codeunit 77728 "BJF MN Emulator Request Run"
{
    Access = Internal;
    TableNo = "BJF MN Emulator Request";

    trigger OnRun()
    var
        Emulator: Codeunit "BJF MN Emulator";
    begin
        Rec.SetResponse(Emulator.Handle(Rec.Request));
    end;
}

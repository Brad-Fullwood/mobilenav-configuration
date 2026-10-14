namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Does every declared line format have the rows "BJF MN Line Format Mgt." would write, in the
/// same order? The fix rewrites the line.
/// </summary>
codeunit 77762 "BJF Check Config Line Formats" implements "BJF Diagnostic Check"
{
    Access = Internal;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                this.CheckProvider(Finding, TempProvider, TempLine);
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        PageId: Integer;
        LineNo: Integer;
        ServiceName: Text[100];
    begin
        this.Support.ReadProviderFix(Finding, this.LineFormatFixTok, Kind, Args, TempLine);
        Evaluate(PageId, Args.Get(1));
        Evaluate(LineNo, Args.Get(2));
        if not this.LineFormatManagement.DeclaredLineNos(TempLine, PageId).Contains(LineNo) then
            Error(this.LineFormatGoneErr);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        this.LineFormatManagement.ApplyLineFormat(ServiceName, TempLine, PageId, LineNo);
    end;

    local procedure CheckProvider(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        PageIds: List of [Integer];
        PageId: Integer;
        LineNo: Integer;
    begin
        PageIds := TempLine.PageIdsWith(Enum::"BJF MN Config Operation"::"Line Format");
        foreach PageId in PageIds do
            foreach LineNo in this.LineFormatManagement.DeclaredLineNos(TempLine, PageId) do
                this.CheckLine(Finding, TempProvider, TempLine, PageId, LineNo);
    end;

    local procedure CheckLine(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; LineNo: Integer)
    var
        TempLineFormat: Record "MobileNAV Line Format" temporary;
        LiveLineFormat: Record "MobileNAV Line Format";
        ServiceName: Text[100];
        Problem: Text;
        FindingText: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Support.GetServiceName(PageId);
        if ServiceName = '' then
            exit;
        if not this.TryBuildLineFormat(ServiceName, TempLine, PageId, LineNo, TempLineFormat) then begin
            Problem := GetLastErrorText();
            FindingText := Problem;
        end else begin
            Problem := this.Difference(
                this.LineFormatManagement.Signatures(TempLineFormat, ServiceName, LineNo),
                this.LineFormatManagement.Signatures(LiveLineFormat, ServiceName, LineNo));
            FindingText := StrSubstNo(this.LineFormatMsg, LineNo, ServiceName, Problem);
        end;
        if Problem = '' then
            exit;
        Args.Add(Format(PageId, 0, 9));
        Args.Add(Format(LineNo, 0, 9));
        this.Support.AddProviderFinding(Finding, Finding."Check Type"::"Config Line Formats", Finding.Severity::Warning, TempProvider,
            FindingText, this.Support.MainRowId(ServiceName),
            StrSubstNo(this.FixMsg, LineNo, ServiceName), this.LineFormatFixTok, Args);
    end;

    // The writer's error, for example a field MobileNAV does not have, becomes the finding text.
    [TryFunction]
    local procedure TryBuildLineFormat(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; LineNo: Integer; var TempLineFormat: Record "MobileNAV Line Format" temporary)
    begin
        this.LineFormatManagement.BuildLineFormat(ServiceName, TempLine, PageId, LineNo, TempLineFormat);
    end;

    /// <summary>Describes the first difference between the declared and the live rows.</summary>
    /// <param name="Expected">The rows the declaration writes.</param>
    /// <param name="Live">The rows MobileNAV has.</param>
    /// <returns>A description of the first difference, or empty when the rows match.</returns>
    local procedure Difference(Expected: List of [Text]; Live: List of [Text]): Text
    var
        Index: Integer;
    begin
        if Live.Count() = 0 then
            exit(this.MissingLbl);
        if Live.Count() <> Expected.Count() then
            exit(StrSubstNo(this.CountLbl, Expected.Count(), Live.Count()));
        for Index := 1 to Expected.Count() do
            if Expected.Get(Index) <> Live.Get(Index) then
                exit(StrSubstNo(this.RowLbl, Index, Expected.Get(Index), Live.Get(Index)));
        exit('');
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        LineFormatManagement: Codeunit "BJF MN Line Format Mgt.";
        LineFormatMsg: Label 'Line format %1 of %2 does not match the declaration: %3', Comment = '%1 = line number, %2 = service name, %3 = what differs';
        FixMsg: Label 'Rewrite line format %1 of %2 from the declaration.', Comment = '%1 = line number, %2 = service name';
        MissingLbl: Label 'the line has no rows.';
        CountLbl: Label '%1 rows declared, %2 found.', Comment = '%1 = declared count, %2 = live count';
        RowLbl: Label 'row %1 is %3, declared %2.', Comment = '%1 = row position, %2 = declared row, %3 = live row';
        LineFormatGoneErr: Label 'The provider no longer declares this line format.';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        LineFormatFixTok: Label 'LINEFORMAT', Locked = true;
}

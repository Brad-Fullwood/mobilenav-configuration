namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Do the declared captions and menu pictures hold on the live rows? The fix rewrites the one that differs.</summary>
codeunit 77705 "BJF Check Config Appearance" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                TempLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::Caption, Enum::"BJF MN Config Operation"::"Menu Picture");
                if TempLine.FindSet() then
                    repeat
                        this.CheckLine(Finding, TempProvider, TempLine);
                    until TempLine.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        EntryNo: Integer;
        ServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        if Kind <> this.AppearanceFixTok then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(EntryNo, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        if not TempLine.Get(EntryNo) then
            Error(this.LineGoneErr);
        ServiceName := this.Lookup.GetServiceName(TempLine."Page ID");
        if ServiceName = '' then
            Error(this.PageGoneErr, TempLine."Page ID");
        if TempLine.Operation = Enum::"BJF MN Config Operation"::Caption then
            this.AppearanceManagement.SetCaption(ServiceName, TempLine."Control Name", TempLine."Language Code", TempLine.Description)
        else
            this.AppearanceManagement.SetMenuPicture(ServiceName, TempLine);
    end;

    local procedure CheckLine(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; var Line: Record "BJF MN Config Line" temporary)
    var
        MainRow: Record "MobileNAV Service Setup";
        ServiceName: Text[100];
        Problem: Text;
        Args: List of [Text];
    begin
        ServiceName := this.Lookup.GetServiceName(Line."Page ID");
        if ServiceName = '' then
            exit;
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            exit;
        if Line.Operation = Enum::"BJF MN Config Operation"::Caption then
            Problem := this.CaptionProblem(ServiceName, Line)
        else
            if not this.AppearanceManagement.MenuPictureMatches(MainRow, Line) then
                Problem := StrSubstNo(this.PictureMsg, ServiceName);
        if Problem = '' then
            exit;
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(Line."Entry No.", 0, 9));
        Finding.AddWithFix(Finding."Check Type"::"Config Appearance", Finding.Severity::Warning,
            this.Support.Prefix(TempProvider, Problem), MainRow.RecordId(), StrSubstNo(this.FixMsg, ServiceName),
            this.Support.PackFix(this.AppearanceFixTok, Args));
    end;

    local procedure CaptionProblem(ServiceName: Text[100]; Line: Record "BJF MN Config Line" temporary): Text
    var
        FieldRow: Record "MobileNAV Service Setup";
        Live: Text;
    begin
        if (Line."Control Name" <> '') and not this.Lookup.FindFieldRow(ServiceName, Line."Control Name", FieldRow) then
            exit(''); // Reported by the field check.
        if not this.AppearanceManagement.GetCaption(ServiceName, Line."Control Name", Line."Language Code", Live) then
            exit(StrSubstNo(this.NoCaptionMsg, this.Target(ServiceName, Line."Control Name"), Line."Language Code", Line.Description));
        if Live <> Line.Description then
            exit(StrSubstNo(this.CaptionMsg, this.Target(ServiceName, Line."Control Name"), Line."Language Code", Line.Description, Live));
        exit('');
    end;

    local procedure Target(ServiceName: Text[100]; ControlName: Text[100]): Text
    begin
        if ControlName = '' then
            exit(StrSubstNo(this.PageTargetLbl, ServiceName));
        exit(StrSubstNo(this.ControlTargetLbl, ControlName, ServiceName));
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        AppearanceManagement: Codeunit "BJF MN Appearance Mgt.";
        NoCaptionMsg: Label '%1 has no %2 caption; "%3" is declared.', Comment = '%1 = page or control, %2 = language code, %3 = declared caption';
        CaptionMsg: Label '%1 is captioned "%4" in %2 but "%3" is declared.', Comment = '%1 = page or control, %2 = language code, %3 = declared caption, %4 = live caption';
        PictureMsg: Label 'The menu picture of %1 is not the declared one.', Comment = '%1 = service name';
        FixMsg: Label 'Write the declared caption or picture on %1.', Comment = '%1 = service name';
        PageTargetLbl: Label 'page %1', Comment = '%1 = service name';
        ControlTargetLbl: Label 'control %1 of %2', Comment = '%1 = control name, %2 = service name';
        LineGoneErr: Label 'The provider no longer declares this caption or picture.';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        AppearanceFixTok: Label 'APPEARANCE', Locked = true;
}

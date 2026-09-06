namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Are the declared field order and field groups in place? Declared controls must lead in
/// declaration order where OrderAsDeclared says so, and each group's marker rows must wrap
/// its members, which must sit together. The fix rewrites order or groups for the page.
/// </summary>
codeunit 77702 "BJF Check Config Groups" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        TempProvider: Record "BJF MN Provider Buffer" temporary;
        TempLine: Record "BJF MN Config Line" temporary;
        TempGroupLine: Record "BJF MN Config Line" temporary;
    begin
        this.Support.ListProviders(TempProvider);
        if TempProvider.FindSet() then
            repeat
                this.Support.BuildDefinition(TempProvider.Provider, TempLine);
                TempGroupLine.Copy(TempLine, true);
                TempGroupLine.Reset();
                TempGroupLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Field Order", Enum::"BJF MN Config Operation"::Group);
                if TempGroupLine.FindSet() then
                    repeat
                        this.CheckLine(Finding, TempProvider, TempGroupLine, TempLine);
                    until TempGroupLine.Next() = 0;
            until TempProvider.Next() = 0;
    end;

    local procedure CheckLine(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; GroupLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    begin
        if GroupLine.Operation = Enum::"BJF MN Config Operation"::"Field Order" then
            this.CheckOrder(Finding, TempProvider, GroupLine."Page ID", TempLine)
        else
            this.CheckGroup(Finding, TempProvider, GroupLine, TempLine);
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TempLine: Record "BJF MN Config Line" temporary;
        Kind: Text;
        Args: List of [Text];
        Ordinal: Integer;
        PageId: Integer;
        ServiceName: Text[100];
    begin
        this.Support.UnpackFix(Finding."Fix Context", Kind, Args);
        Evaluate(Ordinal, Args.Get(1));
        Evaluate(PageId, Args.Get(2));
        this.Support.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempLine);
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            Error(this.PageGoneErr, PageId);
        case Kind of
            this.OrderFixTok:
                this.GroupManagement.ApplyDeclaredOrder(ServiceName, TempLine, PageId);
            this.GroupsFixTok:
                this.GroupManagement.ApplyGroups(ServiceName, TempLine, PageId);
            else
                Error(this.NoAutomaticFixErr);
        end;
    end;

    local procedure CheckOrder(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; PageId: Integer; var TempLine: Record "BJF MN Config Line" temporary)
    var
        ServiceName: Text[100];
    begin
        ServiceName := this.Lookup.GetServiceName(PageId);
        if ServiceName = '' then
            exit;
        this.Report(Finding, TempProvider, PageId, ServiceName, this.OrderProblem(ServiceName, PageId, TempLine), this.OrderFixTok);
    end;

    /// <summary>The first declared control whose Order is not its declaration position.</summary>
    local procedure OrderProblem(ServiceName: Text[100]; PageId: Integer; var TempLine: Record "BJF MN Config Line" temporary): Text
    var
        FieldRow: Record "MobileNAV Service Setup";
        Placed: List of [Integer];
        Problem: Text;
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetFilter(Operation, '%1|%2|%3|%4|%5',
            Enum::"BJF MN Config Operation"::Field, Enum::"BJF MN Config Operation"::"Function Field",
            Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Scan Field",
            Enum::"BJF MN Config Operation"::"Lookup Field");
        if TempLine.FindSet() then
            repeat
                if this.IsNewlyPlaced(ServiceName, TempLine."Control Name", Placed, FieldRow) and (Problem = '') and (FieldRow.Order <> Placed.Count()) then
                    Problem := StrSubstNo(this.OutOfOrderLbl, TempLine."Control Name", Placed.Count(), FieldRow.Order);
            until TempLine.Next() = 0;
        TempLine.Reset();
        exit(Problem);
    end;

    local procedure IsNewlyPlaced(ServiceName: Text[100]; ControlName: Text[100]; var Placed: List of [Integer]; var FieldRow: Record "MobileNAV Service Setup"): Boolean
    begin
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, FieldRow) then
            exit(false);
        if Placed.Contains(FieldRow."Page Line No.") then
            exit(false);
        Placed.Add(FieldRow."Page Line No.");
        exit(true);
    end;

    local procedure CheckGroup(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; GroupLine: Record "BJF MN Config Line" temporary; var TempLine: Record "BJF MN Config Line" temporary)
    var
        Members: List of [Integer];
        ServiceName: Text[100];
        Problem: Text;
    begin
        ServiceName := this.Lookup.GetServiceName(GroupLine."Page ID");
        if ServiceName = '' then
            exit;
        Members := this.GroupManagement.MemberPageLineNos(ServiceName, TempLine, GroupLine."Page ID", GroupLine."Group Code");
        if Members.Count() = 0 then
            exit;
        Problem := this.MarkerProblem(ServiceName, GroupLine."Group Code", true, Members.Get(1));
        if Problem = '' then
            Problem := this.MarkerProblem(ServiceName, GroupLine."Group Code", false, Members.Get(Members.Count()));
        if Problem = '' then
            Problem := this.ContiguityProblem(ServiceName, GroupLine."Group Code", Members);
        this.Report(Finding, TempProvider, GroupLine."Page ID", ServiceName, Problem, this.GroupsFixTok);
    end;

    local procedure MarkerProblem(ServiceName: Text[100]; GroupCode: Code[20]; IsStart: Boolean; AnchorPageLineNo: Integer): Text
    var
        GroupRow: Record "MobileNAV Service Setup";
        AnchorRow: Record "MobileNAV Service Setup";
        Offset: Integer;
    begin
        if IsStart then
            Offset := -1
        else
            Offset := 1;
        if not this.GroupManagement.FindGroupRow(ServiceName, GroupCode, IsStart, GroupRow) then
            exit(StrSubstNo(this.NoMarkerLbl, GroupCode));
        if GroupRow."Page Line No." <> AnchorPageLineNo + Offset then
            exit(StrSubstNo(this.MarkerPlaceLbl, GroupCode));
        if GroupRow.Category <> GroupCode then
            exit(StrSubstNo(this.MarkerCaptionLbl, GroupCode));
        AnchorRow.Get(ServiceName, AnchorRow."Line Type"::Field, AnchorPageLineNo, 0, 0);
        if GroupRow.Order <> AnchorRow.Order then
            exit(StrSubstNo(this.MarkerOrderLbl, GroupCode));
        exit('');
    end;

    local procedure ContiguityProblem(ServiceName: Text[100]; GroupCode: Code[20]; Members: List of [Integer]): Text
    var
        MemberRow: Record "MobileNAV Service Setup";
        PageLineNo: Integer;
        PreviousOrder: Integer;
    begin
        PreviousOrder := 0;
        foreach PageLineNo in Members do begin
            MemberRow.Get(ServiceName, MemberRow."Line Type"::Field, PageLineNo, 0, 0);
            if (PreviousOrder <> 0) and (MemberRow.Order <> PreviousOrder + 1) then
                exit(StrSubstNo(this.NotContiguousLbl, GroupCode, MemberRow.FieldName));
            PreviousOrder := MemberRow.Order;
        end;
        exit('');
    end;

    local procedure Report(var Finding: Record "BJF Diagnostic Finding"; TempProvider: Record "BJF MN Provider Buffer" temporary; PageId: Integer; ServiceName: Text[100]; Problem: Text; FixKind: Text)
    var
        MainRow: Record "MobileNAV Service Setup";
        Args: List of [Text];
    begin
        if Problem = '' then
            exit;
        Args.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        Args.Add(Format(PageId, 0, 9));
        if this.Lookup.FindMainRow(ServiceName, MainRow) then;
        Finding.AddWithFix(Finding."Check Type"::"Config Groups", Finding.Severity::Blocker,
            this.Support.Prefix(TempProvider, StrSubstNo(this.GroupsMsg, ServiceName, Problem)),
            MainRow.RecordId(), StrSubstNo(this.FixMsg, ServiceName),
            this.Support.PackFix(FixKind, Args));
    end;

    var
        Support: Codeunit "BJF MN Doctor Support";
        Lookup: Codeunit "BJF MN Service Lookup";
        GroupManagement: Codeunit "BJF MN Group Mgt.";
        GroupsMsg: Label 'Page %1 is not laid out as declared: %2', Comment = '%1 = service name, %2 = what differs';
        FixMsg: Label 'Rewrite the field order and groups of %1.', Comment = '%1 = service name';
        OutOfOrderLbl: Label 'control %1 should be at position %2 but is at %3.', Comment = '%1 = control name, %2 = declared position, %3 = live position';
        NoMarkerLbl: Label 'group %1 has no marker row.', Comment = '%1 = group code';
        MarkerPlaceLbl: Label 'a marker row of group %1 is not next to its member.', Comment = '%1 = group code';
        MarkerCaptionLbl: Label 'a marker row of group %1 carries another caption.', Comment = '%1 = group code';
        MarkerOrderLbl: Label 'a marker row of group %1 is out of order.', Comment = '%1 = group code';
        NotContiguousLbl: Label 'the members of group %1 are not together (at %2).', Comment = '%1 = group code, %2 = field name';
        PageGoneErr: Label 'Page %1 is no longer registered in MobileNAV.', Comment = '%1 = page id';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        OrderFixTok: Label 'ORDER', Locked = true;
        GroupsFixTok: Label 'GROUPS', Locked = true;
}

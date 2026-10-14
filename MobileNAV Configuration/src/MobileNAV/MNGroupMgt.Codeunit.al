namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Field order and field groups. MobileNAV displays fields by their dense Order and keeps a
/// group as two marker rows squeezed in at Page Line No. -1 and +1 around the first and last
/// member, captioned by a category. Order is renumbered the way MobileNAV's own rearrange
/// does: normal fields first, then flow filters.
/// </summary>
codeunit 77761 "BJF MN Group Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = rimd;

    /// <summary>Declared controls first, in declaration order, then the rest in their existing order.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="PageId">The page object ID.</param>
    procedure ApplyDeclaredOrder(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        FieldRow: Record "MobileNAV Service Setup";
        Placed: List of [Integer];
        NextOrder: Integer;
    begin
        this.SetControlRange(TempLine, PageId);
        if TempLine.FindSet() then
            repeat
                if this.Lookup.FindFieldRow(ServiceName, TempLine."Control Name", FieldRow) and not Placed.Contains(FieldRow."Page Line No.") then begin
                    NextOrder += 1;
                    this.SetOrder(FieldRow, NextOrder);
                    Placed.Add(FieldRow."Page Line No.");
                end;
            until TempLine.Next() = 0;
        TempLine.Reset();
        this.Renumber(ServiceName, Placed, NextOrder);
    end;

    /// <summary>Writes the page's groups: members made contiguous, marker rows rebuilt, order renumbered.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="PageId">The page object ID.</param>
    procedure ApplyGroups(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        TempGroupLine: Record "BJF MN Config Line" temporary;
    begin
        TempGroupLine.Copy(TempLine, true);
        TempGroupLine.Reset();
        TempGroupLine.SetRange("Page ID", PageId);
        TempGroupLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Group);
        if TempGroupLine.FindSet() then
            repeat
                this.DeleteGroupRows(ServiceName, TempGroupLine."Group Code");
            until TempGroupLine.Next() = 0;
        if TempGroupLine.FindSet() then
            repeat
                this.ApplyGroup(ServiceName, TempLine, PageId, TempGroupLine."Group Code");
            until TempGroupLine.Next() = 0;
    end;

    /// <summary>The page line numbers of a group's members, in declaration order; empty when the group has none.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="TempLine">The definition lines of the apply.</param>
    /// <param name="PageId">The page object ID.</param>
    /// <param name="GroupCode">The group code from the definition.</param>
    /// <returns>The member page line numbers.</returns>
    procedure MemberPageLineNos(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; GroupCode: Code[20]) Members: List of [Integer]
    var
        FieldRow: Record "MobileNAV Service Setup";
    begin
        this.SetControlRange(TempLine, PageId);
        TempLine.SetRange("Group Code", GroupCode);
        if TempLine.FindSet() then
            repeat
                if this.Lookup.FindFieldRow(ServiceName, TempLine."Control Name", FieldRow) then
                    Members.Add(FieldRow."Page Line No.");
            until TempLine.Next() = 0;
        TempLine.Reset();
        exit(Members);
    end;

    procedure FindGroupRow(ServiceName: Text[100]; GroupCode: Code[20]; IsStart: Boolean; var GroupRow: Record "MobileNAV Service Setup"): Boolean
    begin
        GroupRow.Reset();
        GroupRow.SetRange("Service Name", ServiceName);
        GroupRow.SetRange("Line Type", GroupRow."Line Type"::Field);
        if IsStart then
            GroupRow.SetRange(FieldClass, GroupRow.FieldClass::GroupStart)
        else
            GroupRow.SetRange(FieldClass, GroupRow.FieldClass::GroupEnd);
        GroupRow.SetRange(FieldName, this.GroupFieldName(GroupCode, IsStart));
        exit(GroupRow.FindFirst());
    end;

    procedure GroupFieldName(GroupCode: Code[20]; IsStart: Boolean): Text[75]
    begin
        if IsStart then
            exit(CopyStr(StrSubstNo(this.StartNameTok, GroupCode), 1, 75));
        exit(CopyStr(StrSubstNo(this.EndNameTok, GroupCode), 1, 75));
    end;

    local procedure ApplyGroup(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; GroupCode: Code[20])
    var
        FirstRow: Record "MobileNAV Service Setup";
        LastRow: Record "MobileNAV Service Setup";
        Members: List of [Integer];
    begin
        Members := this.MemberPageLineNos(ServiceName, TempLine, PageId, GroupCode);
        if Members.Count() = 0 then
            exit;
        this.MakeContiguous(ServiceName, Members);
        this.GetFieldRow(ServiceName, Members.Get(1), FirstRow);
        this.GetFieldRow(ServiceName, Members.Get(Members.Count()), LastRow);
        this.InsertGroupRow(FirstRow, GroupCode, true);
        this.InsertGroupRow(LastRow, GroupCode, false);
        this.Renumber(ServiceName, Members, 0);
    end;

    /// <summary>Members take consecutive orders starting at the first member's; everything after shifts.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Members">The page line numbers of the group members.</param>
    local procedure MakeContiguous(ServiceName: Text[100]; Members: List of [Integer])
    var
        Orders: Dictionary of [Integer, Integer];
        Ordered: List of [Integer];
        PageLineNo: Integer;
        Index: Integer;
        Position: Integer;
    begin
        Ordered := this.PageLineNosByOrder(ServiceName, false, Orders);
        foreach PageLineNo in Members do
            Ordered.Remove(PageLineNo);
        Position := this.PositionOfFirstMember(ServiceName, Ordered, Members, Orders);
        for Index := Members.Count() downto 1 do
            Ordered.Insert(Position, Members.Get(Index));
        foreach PageLineNo in Ordered do begin
            Index += 1;
            this.SetOrderOf(ServiceName, PageLineNo, Orders, Index);
        end;
    end;

    /// <summary>Where the first member sat before it was taken out, as a 1-based insert position.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Ordered">The page line numbers in display order, without the members.</param>
    /// <param name="Members">The page line numbers of the group members.</param>
    /// <param name="Orders">The Order of each row in Ordered, by page line number.</param>
    /// <returns>The 1-based insert position.</returns>
    local procedure PositionOfFirstMember(ServiceName: Text[100]; Ordered: List of [Integer]; Members: List of [Integer]; Orders: Dictionary of [Integer, Integer]): Integer
    var
        FirstRow: Record "MobileNAV Service Setup";
        Position: Integer;
        PageLineNo: Integer;
        RowOrder: Integer;
    begin
        this.GetFieldRow(ServiceName, Members.Get(1), FirstRow);
        Position := 1;
        foreach PageLineNo in Ordered do begin
            RowOrder := Orders.Get(PageLineNo);
            if (RowOrder > FirstRow.Order) or ((RowOrder = FirstRow.Order) and (PageLineNo > FirstRow."Page Line No.")) then
                exit(Position);
            Position += 1;
        end;
        exit(Position);
    end;

    local procedure InsertGroupRow(AnchorRow: Record "MobileNAV Service Setup"; GroupCode: Code[20]; IsStart: Boolean)
    var
        GroupRow: Record "MobileNAV Service Setup";
        Offset: Integer;
    begin
        if IsStart then
            Offset := -1
        else
            Offset := 1;
        GroupRow.Init();
        GroupRow.Validate("Service Name", AnchorRow."Service Name");
        GroupRow.Validate("Line Type", AnchorRow."Line Type");
        GroupRow.Validate("Page Line No.", AnchorRow."Page Line No." + Offset);
        GroupRow.Validate("Relation No.", 0);
        GroupRow.Validate("Line No.", 0);
#pragma warning disable PC0037
        GroupRow."Object Type" := AnchorRow."Object Type";
        GroupRow."Object ID" := AnchorRow."Object ID";
        if IsStart then
            GroupRow.FieldClass := GroupRow.FieldClass::GroupStart
        else
            GroupRow.FieldClass := GroupRow.FieldClass::GroupEnd;
        GroupRow.Category := GroupCode;
        GroupRow.Order := AnchorRow.Order;
        GroupRow.DisplayInMenu := AnchorRow.DisplayInMenu;
#pragma warning restore PC0037
        GroupRow.Validate(FieldName, this.GroupFieldName(GroupCode, IsStart));
        GroupRow.Validate(LocalizedFieldName, GroupRow.FieldName);
        GroupRow.Insert(true);
    end;

    /// <summary>Removes the declared group's own marker rows; an administrator's groups stay.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="GroupCode">The group code from the definition.</param>
    local procedure DeleteGroupRows(ServiceName: Text[100]; GroupCode: Code[20])
    var
        GroupRow: Record "MobileNAV Service Setup";
    begin
        if this.FindGroupRow(ServiceName, GroupCode, true, GroupRow) then
            GroupRow.Delete(false);
        if this.FindGroupRow(ServiceName, GroupCode, false, GroupRow) then
            GroupRow.Delete(false);
    end;

    /// <summary>Dense Order over every field row, normal fields before flow filters, by (Order, Page Line No.); the placed rows keep their leading positions.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="Placed">The page line numbers that already have their order.</param>
    /// <param name="PlacedCount">How many orders the placed rows already use.</param>
    local procedure Renumber(ServiceName: Text[100]; Placed: List of [Integer]; PlacedCount: Integer)
    var
        Orders: Dictionary of [Integer, Integer];
        PageLineNo: Integer;
        NextOrder: Integer;
    begin
        NextOrder := PlacedCount;
        foreach PageLineNo in this.PageLineNosByOrder(ServiceName, false, Orders) do
            if not Placed.Contains(PageLineNo) or (PlacedCount = 0) then begin
                NextOrder += 1;
                this.SetOrderOf(ServiceName, PageLineNo, Orders, NextOrder);
            end;
        foreach PageLineNo in this.PageLineNosByOrder(ServiceName, true, Orders) do begin
            NextOrder += 1;
            this.SetOrderOf(ServiceName, PageLineNo, Orders, NextOrder);
        end;
    end;

    /// <summary>The page's field rows in display order.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="FlowFilters">True for the flow filter rows, false for every other field row.</param>
    /// <param name="Orders">Receives the Order of each row returned, by page line number.</param>
    /// <returns>The page line numbers.</returns>
    local procedure PageLineNosByOrder(ServiceName: Text[100]; FlowFilters: Boolean; var Orders: Dictionary of [Integer, Integer]) PageLineNos: List of [Integer]
    var
        FieldRow: Record "MobileNAV Service Setup";
    begin
        FieldRow.SetLoadFields("Page Line No.", Order);
        FieldRow.SetCurrentKey("Service Name", "Line Type", Order);
        FieldRow.SetRange("Service Name", ServiceName);
        FieldRow.SetRange("Line Type", FieldRow."Line Type"::Field);
        if FlowFilters then
            FieldRow.SetRange(FieldClass, FieldRow.FieldClass::FlowFilter)
        else
            FieldRow.SetFilter(FieldClass, '<>%1', FieldRow.FieldClass::FlowFilter);
        if FieldRow.FindSet() then
            repeat
                PageLineNos.Add(FieldRow."Page Line No.");
                Orders.Set(FieldRow."Page Line No.", FieldRow.Order);
            until FieldRow.Next() = 0;
        exit(PageLineNos);
    end;

    /// <summary>Gives a row a new Order. The row is read and modified only when its Order changes.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <param name="PageLineNo">The row's page line number.</param>
    /// <param name="Orders">The known Order by page line number, kept up to date.</param>
    /// <param name="NewOrder">The Order to give the row.</param>
    local procedure SetOrderOf(ServiceName: Text[100]; PageLineNo: Integer; var Orders: Dictionary of [Integer, Integer]; NewOrder: Integer)
    var
        FieldRow: Record "MobileNAV Service Setup";
        CurrentOrder: Integer;
    begin
        if Orders.Get(PageLineNo, CurrentOrder) then
            if CurrentOrder = NewOrder then
                exit;
        this.GetFieldRow(ServiceName, PageLineNo, FieldRow);
        this.SetOrder(FieldRow, NewOrder);
        Orders.Set(PageLineNo, NewOrder);
    end;

    local procedure GetFieldRow(ServiceName: Text[100]; PageLineNo: Integer; var FieldRow: Record "MobileNAV Service Setup")
    begin
        if not FieldRow.Get(ServiceName, FieldRow."Line Type"::Field, PageLineNo, 0, 0) then
            Error(this.FieldRowMissingErr, PageLineNo, ServiceName);
    end;

    local procedure SetOrder(var FieldRow: Record "MobileNAV Service Setup"; NewOrder: Integer)
    begin
        if FieldRow.Order = NewOrder then
            exit;
        // Bulk renumbering assigns Order directly, as MobileNAV's own rearrange does.
#pragma warning disable PC0037
        FieldRow.Order := NewOrder;
#pragma warning restore PC0037
        FieldRow.Modify(false);
    end;

    local procedure SetControlRange(var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    begin
        TempLine.Reset();
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetControlFilter();
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        FieldRowMissingErr: Label 'MobileNAV service %2 has no field row at page line %1.', Comment = '%1 = page line no., %2 = service name';
        StartNameTok: Label '_%1_Start', Comment = '%1 = group code', Locked = true;
        EndNameTok: Label '_%1_End', Comment = '%1 = group code', Locked = true;
}

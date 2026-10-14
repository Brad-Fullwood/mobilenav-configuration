namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Writes line formats: what each line of a list row and each list cell shows. The rows of a
/// declared line are deleted and inserted again the way MobileNAV's own ParseLineFormat writes
/// them: one row per caption, value or separator, numbered in steps of 10000.
/// </summary>
codeunit 77768 "BJF MN Line Format Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Line Format" = rid;

    /// <summary>Rewrites every line format the definition declares for a page.</summary>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="TempLine">The definition lines of the apply. Filters are reset on exit.</param>
    /// <param name="PageId">The page the line formats belong to.</param>
    procedure ApplyLineFormats(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        LineNo: Integer;
    begin
        foreach LineNo in this.DeclaredLineNos(TempLine, PageId) do
            this.ApplyLineFormat(ServiceName, TempLine, PageId, LineNo);
    end;

    /// <summary>Rewrites one declared line format.</summary>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="TempLine">The definition lines of the apply. Filters are reset on exit.</param>
    /// <param name="PageId">The page the line format belongs to.</param>
    /// <param name="LineNo">MobileNAV's Setup Line No. of the line.</param>
    procedure ApplyLineFormat(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; LineNo: Integer)
    var
        LineFormat: Record "MobileNAV Line Format";
    begin
        this.FilterRows(LineFormat, ServiceName, LineNo);
        LineFormat.DeleteAll(false);
        LineFormat.Reset();
        this.BuildLineFormat(ServiceName, TempLine, PageId, LineNo, LineFormat);
        this.CheckLength(ServiceName, LineNo);
    end;

    /// <summary>Writes the rows of one declared line format into LineFormat: the real table on apply, a temporary copy when the Doctor compares.</summary>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="TempLine">The definition lines. Filters are reset on exit.</param>
    /// <param name="PageId">The page the line format belongs to.</param>
    /// <param name="LineNo">MobileNAV's Setup Line No. of the line.</param>
    /// <param name="LineFormat">The table the rows are inserted into.</param>
    procedure BuildLineFormat(ServiceName: Text[100]; var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; LineNo: Integer; var LineFormat: Record "MobileNAV Line Format")
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        RowNo: Integer;
    begin
        this.FilterElements(TempLine, PageId, LineNo);
        if TempLine.FindSet() then
            repeat
                // MobileNAV turns an unknown field into separator text without a word.
                if TempLine."Filter Type" <> this.SeparatorTok then
                    if not this.Lookup.FindFieldRow(ServiceName, TempLine."Control Name", ServiceSetup) then
                        Error(this.NoFieldRowErr, TempLine."Control Name", ServiceName, LineNo);
                RowNo += 10000;
                // Written as MobileNAV's ParseLineFormat writes the rows: assigned directly.
#pragma warning disable PC0037
                LineFormat.Init();
                LineFormat."Object Type" := LineFormat."Object Type"::Page;
                LineFormat."Service Name" := ServiceName;
                LineFormat."Setup Line No." := LineNo;
                LineFormat."Line No." := RowNo;
                case TempLine."Filter Type" of
                    this.CaptionTok:
                        LineFormat."Line Type" := LineFormat."Line Type"::Caption;
                    this.SeparatorTok:
                        LineFormat."Line Type" := LineFormat."Line Type"::Separator;
                    else
                        LineFormat."Line Type" := LineFormat."Line Type"::Value;
                end;
                LineFormat."Setup Field Name" := this.ElementText(TempLine);
#pragma warning restore PC0037
                LineFormat.Insert(false);
            until TempLine.Next() = 0;
        TempLine.Reset();
    end;

    /// <summary>The line numbers the definition declares for a page, in declaration order.</summary>
    /// <param name="TempLine">The definition lines. Filters are reset on exit.</param>
    /// <param name="PageId">The page.</param>
    /// <returns>The line numbers.</returns>
    procedure DeclaredLineNos(var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer) LineNos: List of [Integer]
    begin
        TempLine.Reset();
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Line Format");
        TempLine.SetRange("Page ID", PageId);
        if TempLine.FindSet() then
            repeat
                if not LineNos.Contains(TempLine."Line Format No.") then
                    LineNos.Add(TempLine."Line Format No.");
            until TempLine.Next() = 0;
        TempLine.Reset();
        exit(LineNos);
    end;

    /// <summary>The rows of a line format, one entry per row as type and text.</summary>
    /// <param name="LineFormat">The table the rows are read from: the real table or a temporary copy.</param>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="LineNo">MobileNAV's Setup Line No. of the line.</param>
    /// <returns>The rows in MobileNAV's order.</returns>
    procedure Signatures(var LineFormat: Record "MobileNAV Line Format"; ServiceName: Text[100]; LineNo: Integer) Signature: List of [Text]
    begin
        this.FilterRows(LineFormat, ServiceName, LineNo);
        LineFormat.SetLoadFields("Line Type", "Setup Field Name");
        if LineFormat.FindSet() then
            repeat
                Signature.Add(this.RowSignature(LineFormat));
            until LineFormat.Next() = 0;
        exit(Signature);
    end;

    local procedure RowSignature(LineFormat: Record "MobileNAV Line Format"): Text
    var
        TypeName: Text;
    begin
        case LineFormat."Line Type" of
            LineFormat."Line Type"::Caption:
                TypeName := this.CaptionTok;
            LineFormat."Line Type"::Separator:
                TypeName := this.SeparatorTok;
            else
                TypeName := this.ValueTok;
        end;
        exit(UpperCase(TypeName) + this.JoinTok + LineFormat."Setup Field Name");
    end;

    local procedure FilterRows(var LineFormat: Record "MobileNAV Line Format"; ServiceName: Text[100]; LineNo: Integer)
    begin
        LineFormat.SetRange("Object Type", LineFormat."Object Type"::Page);
        LineFormat.SetRange("Service Name", ServiceName);
        LineFormat.SetRange("Setup Line No.", LineNo);
    end;

    local procedure FilterElements(var TempLine: Record "BJF MN Config Line" temporary; PageId: Integer; LineNo: Integer)
    begin
        TempLine.Reset();
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Line Format");
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange("Line Format No.", LineNo);
    end;

    /// <summary>A separator's text, or the name MobileNAV stores the control under.</summary>
    /// <param name="ElementLine">The Line Format line.</param>
    /// <returns>The value of the row's Setup Field Name.</returns>
    local procedure ElementText(ElementLine: Record "BJF MN Config Line" temporary): Text[75]
    begin
        if ElementLine."Filter Type" = this.SeparatorTok then
            exit(CopyStr(ElementLine."Filter Value", 1, 75));
        exit(this.Lookup.StoredFieldName(ElementLine."Control Name"));
    end;

    /// <summary>
    /// MobileNAV copies the first and second line, with each field as its order number, into a
    /// 100 character field when it builds the device configuration, and that build fails on a
    /// longer line.
    /// </summary>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="LineNo">MobileNAV's Setup Line No. of the line.</param>
    local procedure CheckLength(ServiceName: Text[100]; LineNo: Integer)
    var
        LineFormat: Record "MobileNAV Line Format";
        Composed: Text;
    begin
        if LineNo > 2 then
            exit;
        Composed := LineFormat.ComposeLineFormat(ServiceName, LineNo, false);
        if StrLen(Composed) > this.MaxLineLength() then
            Error(this.LineTooLongErr, LineNo, ServiceName, StrLen(Composed), this.MaxLineLength());
    end;

    local procedure MaxLineLength(): Integer
    begin
        exit(100);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        NoFieldRowErr: Label 'Line format %3 of %2 shows %1, but MobileNAV has no field of that name on the page.', Comment = '%1 = control name, %2 = service name, %3 = line number';
        LineTooLongErr: Label 'Line format %1 of %2 is %3 characters as MobileNAV stores it for the device, more than the %4 it allows. Shorten the separators or show fewer fields.', Comment = '%1 = line number, %2 = service name, %3 = length, %4 = maximum length';
        CaptionTok: Label 'Caption', Locked = true;
        ValueTok: Label 'Value', Locked = true;
        SeparatorTok: Label 'Separator', Locked = true;
        JoinTok: Label '|', Locked = true;
}

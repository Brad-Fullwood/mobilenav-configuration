namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Finds dynamic layout buffer rows left from configuration builds that no longer exist.
/// At login MobileNAV builds a user's configuration under a Query ID: the user's highest Query ID
/// in the Settings Buffer plus one, or 1 when the user has no Settings Buffer rows. It writes the
/// layout, condition, action and action line buffers of that Query ID with a plain Insert. The
/// cleanup of an old Query ID reaches the action lines only through the layout and action rows of
/// the same Query ID, and deleting a MobileNAV User Setup row deletes the user's Settings Buffer
/// rows but none of the layout buffers. A leftover row whose Query ID comes round again stops the
/// login with "The record in table Dynamic Layout Action Line Buffer already exists". Regenerate
/// User Specific Config does not remove it: MobileNAV clears the layout buffers there only when the
/// user still has a Settings Buffer row.
/// </summary>
codeunit 77816 "BJF Check Layout Buffers" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV D. L. Act. L. Buff." = rd,
        tabledata "MobileNAV D. L. Action Buff." = rd,
        tabledata "MobileNAV D. L. Cond. Buff." = rd,
        tabledata "MobileNAV Dynamic Layout Buff." = rd,
        tabledata "MobileNAV Settings Buffer" = r,
        tabledata "MobileNAV User Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        Users: List of [Code[50]];
        ForUserId: Code[50];
    begin
        this.CollectUsers(Users);
        foreach ForUserId in Users do
            this.CheckUser(Finding, ForUserId);
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        TableNo: Integer;
        ForUserId: Code[50];
    begin
        ForUserId := CopyStr(Finding."Fix Context", 1, MaxStrLen(ForUserId));
        if ForUserId = '' then
            Error(this.NoUserErr);
        foreach TableNo in this.BufferTables() do
            this.DeleteStaleRows(TableNo, ForUserId);
    end;

    /// <summary>The Query ID MobileNAV gives the user's next configuration build.</summary>
    /// <param name="ForUserId">The MobileNAV user.</param>
    /// <returns>The highest Query ID of the user's Settings Buffer rows plus one, or 1.</returns>
    procedure NextQueryId(ForUserId: Code[50]): Integer
    var
        SettingsBuffer: Record "MobileNAV Settings Buffer";
    begin
        SettingsBuffer.SetRange("User ID", ForUserId);
        SettingsBuffer.SetLoadFields("Query ID");
        if SettingsBuffer.FindLast() then
            exit(SettingsBuffer."Query ID" + 1);
        exit(1);
    end;

    /// <summary>Counts the user's layout buffer rows whose Query ID has no Settings Buffer rows.</summary>
    /// <param name="ForUserId">The MobileNAV user.</param>
    /// <param name="StaleQueryIds">Receives each such Query ID once.</param>
    /// <returns>The number of rows in the four layout buffers.</returns>
    procedure CountStaleRows(ForUserId: Code[50]; var StaleQueryIds: List of [Integer]): Integer
    var
        TableNo: Integer;
        QueryId: Integer;
        RowCount: Integer;
    begin
        Clear(StaleQueryIds);
        foreach TableNo in this.BufferTables() do
            foreach QueryId in this.QueryIdsOf(TableNo, ForUserId) do
                if not this.IsLiveQuery(ForUserId, QueryId) then begin
                    RowCount += this.RowsOf(TableNo, ForUserId, QueryId);
                    if not StaleQueryIds.Contains(QueryId) then
                        StaleQueryIds.Add(QueryId);
                end;
        exit(RowCount);
    end;

    local procedure CheckUser(var Finding: Record "BJF Diagnostic Finding"; ForUserId: Code[50])
    var
        UserSetup: Record "MobileNAV User Setup";
        RelatedRecordId: RecordId;
        StaleQueryIds: List of [Integer];
        RowCount: Integer;
        NextId: Integer;
    begin
        RowCount := this.CountStaleRows(ForUserId, StaleQueryIds);
        if RowCount = 0 then
            exit;
        NextId := this.NextQueryId(ForUserId);
        UserSetup.SetLoadFields("User ID");
        if UserSetup.Get(ForUserId) then
            RelatedRecordId := UserSetup.RecordId();
        if StaleQueryIds.Contains(NextId) then
            Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Layout Buffers", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(this.CollisionMsg, ForUserId, RowCount, this.JoinIds(StaleQueryIds), NextId), RelatedRecordId,
                StrSubstNo(this.FixMsg, ForUserId), ForUserId)
        else
            Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Layout Buffers", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(this.LeftoverMsg, ForUserId, RowCount, this.JoinIds(StaleQueryIds)), RelatedRecordId,
                StrSubstNo(this.FixMsg, ForUserId), ForUserId);
    end;

    /// <summary>The four layout buffer tables. Each has User ID as field 1 and Query ID as field 2, the first two fields of its primary key.</summary>
    /// <returns>The table numbers.</returns>
    local procedure BufferTables(): List of [Integer]
    var
        Tables: List of [Integer];
    begin
        Tables.Add(Database::"MobileNAV Dynamic Layout Buff.");
        Tables.Add(Database::"MobileNAV D. L. Cond. Buff.");
        Tables.Add(Database::"MobileNAV D. L. Action Buff.");
        Tables.Add(Database::"MobileNAV D. L. Act. L. Buff.");
        exit(Tables);
    end;

    /// <summary>Every user with a row in any layout buffer, read one user at a time along the primary key.</summary>
    /// <param name="Users">Receives each user once.</param>
    local procedure CollectUsers(var Users: List of [Code[50]])
    var
        BufferRef: RecordRef;
        UserField: FieldRef;
        TableNo: Integer;
        ForUserId: Code[50];
    begin
        foreach TableNo in this.BufferTables() do begin
            BufferRef.Open(TableNo);
            UserField := BufferRef.Field(this.UserIdFieldNo());
            BufferRef.SetLoadFields(this.UserIdFieldNo());
            while BufferRef.FindFirst() do begin
                ForUserId := UserField.Value();
                if not Users.Contains(ForUserId) then
                    Users.Add(ForUserId);
                UserField.SetFilter('>%1', ForUserId);
            end;
            BufferRef.Close();
        end;
    end;

    /// <summary>The Query IDs of one user's rows in one layout buffer.</summary>
    /// <param name="TableNo">The layout buffer table.</param>
    /// <param name="ForUserId">The MobileNAV user.</param>
    /// <returns>Each Query ID once, ascending.</returns>
    local procedure QueryIdsOf(TableNo: Integer; ForUserId: Code[50]): List of [Integer]
    var
        BufferRef: RecordRef;
        QueryField: FieldRef;
        QueryIds: List of [Integer];
        QueryId: Integer;
    begin
        BufferRef.Open(TableNo);
        BufferRef.Field(this.UserIdFieldNo()).SetRange(ForUserId);
        QueryField := BufferRef.Field(this.QueryIdFieldNo());
        BufferRef.SetLoadFields(this.QueryIdFieldNo());
        while BufferRef.FindFirst() do begin
            QueryId := QueryField.Value();
            QueryIds.Add(QueryId);
            QueryField.SetFilter('>%1', QueryId);
        end;
        exit(QueryIds);
    end;

    local procedure RowsOf(TableNo: Integer; ForUserId: Code[50]; QueryId: Integer): Integer
    var
        BufferRef: RecordRef;
    begin
        BufferRef.Open(TableNo);
        BufferRef.Field(this.UserIdFieldNo()).SetRange(ForUserId);
        BufferRef.Field(this.QueryIdFieldNo()).SetRange(QueryId);
        exit(BufferRef.Count());
    end;

    local procedure IsLiveQuery(ForUserId: Code[50]; QueryId: Integer): Boolean
    var
        SettingsBuffer: Record "MobileNAV Settings Buffer";
    begin
        SettingsBuffer.SetRange("User ID", ForUserId);
        SettingsBuffer.SetRange("Query ID", QueryId);
        exit(not SettingsBuffer.IsEmpty());
    end;

    // DeleteAll(false): the layout and action buffers' OnDelete triggers only cascade within one
    // Query ID, which this delete already covers, and an action line has no parent to cascade from.
    local procedure DeleteStaleRows(TableNo: Integer; ForUserId: Code[50])
    var
        BufferRef: RecordRef;
        QueryId: Integer;
    begin
        foreach QueryId in this.QueryIdsOf(TableNo, ForUserId) do
            if not this.IsLiveQuery(ForUserId, QueryId) then begin
                BufferRef.Open(TableNo);
                BufferRef.Field(this.UserIdFieldNo()).SetRange(ForUserId);
                BufferRef.Field(this.QueryIdFieldNo()).SetRange(QueryId);
                BufferRef.DeleteAll(false);
                BufferRef.Close();
            end;
    end;

    local procedure JoinIds(QueryIds: List of [Integer]): Text
    var
        Builder: TextBuilder;
        QueryId: Integer;
    begin
        foreach QueryId in QueryIds do begin
            if Builder.Length() > 0 then
                Builder.Append(', ');
            Builder.Append(Format(QueryId, 0, 9));
        end;
        exit(Builder.ToText());
    end;

    local procedure UserIdFieldNo(): Integer
    begin
        exit(1);
    end;

    local procedure QueryIdFieldNo(): Integer
    begin
        exit(2);
    end;

    var
        CollisionMsg: Label 'User %1 has %2 dynamic layout buffer rows from configuration builds that no longer exist (Query ID %3). MobileNAV gives the next build Query ID %4, so the next login stops with "The record in table Dynamic Layout ... Buffer already exists". Regenerate User Specific Config does not remove these rows.', Comment = '%1 = user id, %2 = number of rows, %3 = query ids, %4 = next query id';
        LeftoverMsg: Label 'User %1 has %2 dynamic layout buffer rows from configuration builds that no longer exist (Query ID %3). A login stops with "The record in table Dynamic Layout ... Buffer already exists" once MobileNAV gives a build one of these Query IDs again, for example after the MobileNAV user is deleted and created again.', Comment = '%1 = user id, %2 = number of rows, %3 = query ids';
        FixMsg: Label 'Delete the layout buffer rows of user %1 whose Query ID has no Settings Buffer rows. The current configuration is kept.', Comment = '%1 = user id';
        NoUserErr: Label 'The finding does not name a user.';
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Collects what an apply preview changes. Before a MobileNAV record changes for the first time
/// it keeps the record as stored; when the apply has finished it compares each touched record
/// with what it kept. Records are matched on their primary key, so a row MobileNAV deletes and
/// inserts again during a metadata refresh shows only its real differences. The results go to a
/// temporary table, which the rollback that ends the preview does not undo.
/// </summary>
codeunit 77713 "BJF MN Preview Recorder"
{
    Access = Internal;
    SingleInstance = true;
    Permissions = tabledata "BJF MN Preview Line" = rid;

    procedure Start()
    begin
        this.Stop();
        Clear(this.Touched);
        Clear(this.TableNumbers);
        Clear(this.RecordIds);
        Clear(this.Originals);
        Clear(this.RecordLabels);
        Clear(this.InsertedKeys);
        this.TempPreviewLine.Reset();
        this.TempPreviewLine.DeleteAll(false);
        this.LastEntryNo := 0;
        this.Active := true;
    end;

    procedure Stop()
    begin
        this.Active := false;
    end;

    procedure IsActive(): Boolean
    begin
        exit(this.Active);
    end;

    /// <summary>A record was inserted. It has no stored state to compare with.</summary>
    /// <param name="SourceRecord">The inserted record.</param>
    procedure Inserted(SourceRecord: Variant)
    var
        RecRef: RecordRef;
        RecordKey: Text;
    begin
        if not this.Active then
            exit;
        RecRef.GetTable(SourceRecord);
        // MobileNAV's metadata refresh works on temporary copies of its tables, which are not changes.
        if RecRef.IsTemporary() then
            exit;
        RecordKey := this.Remember(RecRef);
        if RecordKey <> '' then
            this.InsertedKeys.Add(RecordKey, true);
    end;

    /// <summary>A record is about to be renamed: the old key is kept as stored and the new key counts as inserted.</summary>
    /// <param name="SourceRecord">The record being renamed.</param>
    procedure Renaming(SourceRecord: Variant)
    begin
        if not this.Active then
            exit;
        this.KeepStored(SourceRecord, false);
        this.Inserted(SourceRecord);
    end;

    /// <summary>A record is about to be modified or deleted. Keeps it as stored, once.</summary>
    /// <param name="SourceRecord">The record about to change.</param>
    procedure Changing(SourceRecord: Variant)
    begin
        if not this.Active then
            exit;
        this.KeepStored(SourceRecord, true);
    end;

    /// <summary>Keeps a record as stored, found by its system ID, unless its key is kept already.</summary>
    /// <param name="SourceRecord">The record about to change.</param>
    /// <param name="KeyIsStored">Whether the record's key is the stored one, so a key kept already skips the read. A rename carries the new key.</param>
    local procedure KeepStored(SourceRecord: Variant; KeyIsStored: Boolean)
    var
        RecRef: RecordRef;
        StoredRef: RecordRef;
        RecordKey: Text;
    begin
        RecRef.GetTable(SourceRecord);
        // MobileNAV's metadata refresh works on temporary copies of its tables, which are not changes.
        if RecRef.IsTemporary() then
            exit;
        if KeyIsStored then
            if this.TableNumbers.ContainsKey(Format(RecRef.RecordId())) then
                exit;
        StoredRef.Open(RecRef.Number());
        if not StoredRef.GetBySystemId(this.SystemIdOf(RecRef)) then
            exit;
        RecordKey := this.Remember(StoredRef);
        if RecordKey <> '' then
            this.Originals.Add(RecordKey, this.ValuesOf(StoredRef));
    end;

    /// <summary>
    /// Keeps the stored state of every record of a table whose field has the given value. MobileNAV
    /// clears a page's rows with DeleteAll, which raises no per-record events, so the rows of each
    /// declared page are kept before the apply starts.
    /// </summary>
    /// <param name="TableNo">The table to read.</param>
    /// <param name="FieldNo">The field to filter on.</param>
    /// <param name="FieldValue">The value the field must have.</param>
    procedure KeepRows(TableNo: Integer; FieldNo: Integer; FieldValue: Variant)
    var
        RecRef: RecordRef;
        RecordKey: Text;
    begin
        if not this.Active then
            exit;
        RecRef.Open(TableNo);
        RecRef.Field(FieldNo).SetRange(FieldValue);
        if RecRef.FindSet() then
            repeat
                RecordKey := this.Remember(RecRef);
                if RecordKey <> '' then
                    this.Originals.Add(RecordKey, this.ValuesOf(RecRef));
            until RecRef.Next() = 0;
    end;

    /// <summary>The framework changed a web service registration. Tenant Web Service raises no table events.</summary>
    /// <param name="ServiceName">The web service name.</param>
    /// <param name="ObjectTypeName">The object type of the web service.</param>
    /// <param name="IsNew">Whether the registration was created.</param>
    /// <param name="OldObjectId">The object ID before the change.</param>
    /// <param name="NewObjectId">The object ID after the change.</param>
    /// <param name="OldPublished">Whether the service was published before the change.</param>
    /// <param name="NewPublished">Whether the service is published after the change.</param>
    procedure WebServiceChanged(ServiceName: Text; ObjectTypeName: Text; IsNew: Boolean; OldObjectId: Integer; NewObjectId: Integer; OldPublished: Boolean; NewPublished: Boolean)
    var
        RecordLabel: Text;
    begin
        if not this.Active then
            exit;
        RecordLabel := StrSubstNo(this.WebServiceLabelTok, ObjectTypeName, ServiceName);
        if IsNew then begin
            this.AddLine(this.InsertTok, this.WebServiceTableTok, RecordLabel, this.ObjectIdTok, '', Format(NewObjectId));
            this.AddLine(this.InsertTok, this.WebServiceTableTok, RecordLabel, this.PublishedTok, '', Format(NewPublished));
            exit;
        end;
        if OldObjectId <> NewObjectId then
            this.AddLine(this.ModifyTok, this.WebServiceTableTok, RecordLabel, this.ObjectIdTok, Format(OldObjectId), Format(NewObjectId));
        if OldPublished <> NewPublished then
            this.AddLine(this.ModifyTok, this.WebServiceTableTok, RecordLabel, this.PublishedTok, Format(OldPublished), Format(NewPublished));
    end;

    /// <summary>Compares every touched record with its stored state. Call before the preview rolls back.</summary>
    procedure Finish()
    var
        RecRef: RecordRef;
        RecordKey: Text;
        Exists: Boolean;
    begin
        foreach RecordKey in this.Touched do begin
            RecRef.Open(this.TableNumbers.Get(RecordKey));
            Exists := RecRef.Get(this.RecordIds.Get(RecordKey));
            if this.InsertedKeys.ContainsKey(RecordKey) then begin
                if Exists then
                    this.AddInsertedRecord(RecRef);
            end else
                if Exists then
                    this.AddModifiedFields(RecRef, this.Originals.Get(RecordKey))
                else
                    this.AddLine(this.DeleteTok, RecRef.Caption(), this.RecordLabels.Get(RecordKey), '', '', '');
            RecRef.Close();
        end;
    end;

    /// <summary>Records why the preview stopped when the apply itself failed.</summary>
    /// <param name="ErrorText">The error that stopped the apply.</param>
    procedure AddError(ErrorText: Text)
    begin
        this.AddLine(this.ErrorTok, '', '', '', '', ErrorText);
    end;

    /// <summary>Copies the collected lines to the stored preview of a provider, replacing its previous preview.</summary>
    /// <param name="ProviderId">The provider the preview belongs to.</param>
    /// <returns>The number of lines stored.</returns>
    procedure SaveAs(ProviderId: Code[50]) LineCount: Integer
    var
        PreviewLine: Record "BJF MN Preview Line";
    begin
        PreviewLine.SetRange("Provider ID", ProviderId);
        PreviewLine.DeleteAll(false);
        this.TempPreviewLine.Reset();
        if this.TempPreviewLine.FindSet() then
            repeat
                PreviewLine.Init();
                PreviewLine.TransferFields(this.TempPreviewLine, false);
                Clear(PreviewLine."Entry No.");
                PreviewLine.Validate("Provider ID", ProviderId);
                PreviewLine.Validate("Previewed At", CurrentDateTime());
                PreviewLine.Validate("Previewed By", CopyStr(UserId(), 1, MaxStrLen(PreviewLine."Previewed By")));
                PreviewLine.Insert(false);
                LineCount += 1;
            until this.TempPreviewLine.Next() = 0;
        exit(LineCount);
    end;

    local procedure Remember(var RecRef: RecordRef): Text
    var
        RecordKey: Text;
    begin
        RecordKey := Format(RecRef.RecordId());
        // TableNumbers has every touched key for the lookup, Touched keeps the order Finish reports in.
        if this.TableNumbers.ContainsKey(RecordKey) then
            exit('');
        this.Touched.Add(RecordKey);
        this.TableNumbers.Add(RecordKey, RecRef.Number());
        this.RecordIds.Add(RecordKey, RecRef.RecordId());
        this.RecordLabels.Add(RecordKey, RecordKey);
        exit(RecordKey);
    end;

    local procedure SystemIdOf(var RecRef: RecordRef) SystemId: Guid
    begin
        SystemId := RecRef.Field(RecRef.SystemIdNo()).Value();
    end;

    local procedure ValuesOf(var RecRef: RecordRef): List of [Text]
    var
        FieldValues: List of [Text];
        FieldIndex: Integer;
    begin
        for FieldIndex := 1 to RecRef.FieldCount() do
            FieldValues.Add(this.ValueOf(RecRef.FieldIndex(FieldIndex)));
        exit(FieldValues);
    end;

    local procedure ValueOf(FieldRef: FieldRef): Text
    begin
        if not this.IsCompared(FieldRef) then
            exit('');
        exit(Format(FieldRef.Value()));
    end;

    local procedure IsCompared(FieldRef: FieldRef): Boolean
    begin
        if FieldRef.Class() <> FieldClass::Normal then
            exit(false);
        if FieldRef.Number() >= 2000000000 then
            exit(false);
        exit(not (FieldRef.Type() in [FieldType::Blob, FieldType::Media, FieldType::MediaSet]));
    end;

    local procedure AddModifiedFields(var RecRef: RecordRef; StoredValues: List of [Text])
    var
        FieldRef: FieldRef;
        FieldIndex: Integer;
        NewValue: Text;
    begin
        for FieldIndex := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(FieldIndex);
            NewValue := this.ValueOf(FieldRef);
            if NewValue <> StoredValues.Get(FieldIndex) then
                this.AddLine(this.ModifyTok, RecRef.Caption(), Format(RecRef.RecordId()), FieldRef.Name(), StoredValues.Get(FieldIndex), NewValue);
        end;
    end;

    local procedure AddInsertedRecord(var RecRef: RecordRef)
    var
        FieldRef: FieldRef;
        FieldIndex: Integer;
        NewValue: Text;
    begin
        for FieldIndex := 1 to RecRef.FieldCount() do begin
            FieldRef := RecRef.FieldIndex(FieldIndex);
            NewValue := this.ValueOf(FieldRef);
            if not (NewValue in ['', '0', 'No']) then
                this.AddLine(this.InsertTok, RecRef.Caption(), Format(RecRef.RecordId()), FieldRef.Name(), '', NewValue);
        end;
    end;

    local procedure AddLine(Change: Text; TableName: Text; RecordLabel: Text; FieldName: Text; OldValue: Text; NewValue: Text)
    begin
        this.LastEntryNo += 1;
        this.TempPreviewLine.Init();
        this.TempPreviewLine."Entry No." := this.LastEntryNo;
        this.TempPreviewLine.Change := CopyStr(Change, 1, MaxStrLen(this.TempPreviewLine.Change));
        this.TempPreviewLine."Table Name" := CopyStr(TableName, 1, MaxStrLen(this.TempPreviewLine."Table Name"));
        this.TempPreviewLine."Record" := CopyStr(RecordLabel, 1, MaxStrLen(this.TempPreviewLine."Record"));
        this.TempPreviewLine."Field Name" := CopyStr(FieldName, 1, MaxStrLen(this.TempPreviewLine."Field Name"));
        this.TempPreviewLine."Old Value" := CopyStr(OldValue, 1, MaxStrLen(this.TempPreviewLine."Old Value"));
        this.TempPreviewLine."New Value" := CopyStr(NewValue, 1, MaxStrLen(this.TempPreviewLine."New Value"));
        this.TempPreviewLine.Insert(false);
    end;

    var
        TempPreviewLine: Record "BJF MN Preview Line" temporary;
        Touched: List of [Text];
        InsertedKeys: Dictionary of [Text, Boolean];
        TableNumbers: Dictionary of [Text, Integer];
        RecordIds: Dictionary of [Text, RecordId];
        RecordLabels: Dictionary of [Text, Text];
        Originals: Dictionary of [Text, List of [Text]];
        Active: Boolean;
        LastEntryNo: Integer;
        WebServiceLabelTok: Label '%1 %2', Locked = true;
        WebServiceTableTok: Label 'Tenant Web Service', Locked = true;
        ObjectIdTok: Label 'Object ID', Locked = true;
        PublishedTok: Label 'Published', Locked = true;
        InsertTok: Label 'Insert', Locked = true;
        ModifyTok: Label 'Modify', Locked = true;
        DeleteTok: Label 'Delete', Locked = true;
        ErrorTok: Label 'Error', Locked = true;
}

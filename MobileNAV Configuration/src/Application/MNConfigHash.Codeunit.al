namespace BradFullwood.MobileNAV.Configuration;

using System.Security.Encryption;

/// <summary>
/// Fingerprints a provider's definition so the framework can tell on its own when the
/// declaration has changed since it was last applied. The lines are serialized in a canonical
/// order that does not depend on the sequence the provider declared them in, so reordering a
/// definition is not a change while adding, removing or altering a declaration is.
/// </summary>
codeunit 77792 "BJF MN Config Hash"
{
    Access = Internal;

    procedure Compute(var ConfigurationLine: Record "BJF MN Config Line" temporary; var ConfigurationProperty: Record "BJF MN Config Property" temporary): Text[64]
    var
        TempSortedLine: Record "BJF MN Config Line" temporary;
        TempSortedProperty: Record "BJF MN Config Property" temporary;
        CryptographyManagement: Codeunit "Cryptography Management";
        Serialized: TextBuilder;
    begin
        TempSortedLine.Copy(ConfigurationLine, true);
        TempSortedLine.Reset();
        TempSortedLine.SetCurrentKey(Operation, "Page ID", "Control Name", Profile, "Stage Id", "Entry No.");
        if TempSortedLine.FindSet() then
            repeat
                this.AppendRecord(Serialized, TempSortedLine, TempSortedLine.FieldNo("Entry No."));
            until TempSortedLine.Next() = 0;

        TempSortedProperty.Copy(ConfigurationProperty, true);
        TempSortedProperty.Reset();
        TempSortedProperty.SetCurrentKey("Page ID", "Control Name", "Field No.");
        if TempSortedProperty.FindSet() then
            repeat
                this.AppendRecord(Serialized, TempSortedProperty, TempSortedProperty.FieldNo("Entry No."));
            until TempSortedProperty.Next() = 0;
        exit(CopyStr(CryptographyManagement.GenerateHash(Serialized.ToText(), 2), 1, 64));
    end;

    local procedure AppendRecord(var Serialized: TextBuilder; Line: Variant; EntryNoFieldNo: Integer)
    var
        LineRef: RecordRef;
        FieldRef: FieldRef;
        FieldIndex: Integer;
        OptionOrdinal: Integer;
    begin
        LineRef.GetTable(Line);
        Serialized.Append(this.LineSeparatorTok);
        for FieldIndex := 1 to LineRef.FieldCount() do begin
            FieldRef := LineRef.FieldIndex(FieldIndex);
            if FieldRef.Number() <> EntryNoFieldNo then begin
                // Options and enums serialize as ordinals: captions depend on the session
                // language and a fingerprint must not.
                if FieldRef.Type() = FieldType::Option then begin
                    OptionOrdinal := FieldRef.Value();
                    Serialized.Append(Format(OptionOrdinal, 0, 9));
                end else
                    Serialized.Append(Format(FieldRef.Value(), 0, 9));
                Serialized.Append(this.FieldSeparatorTok);
            end;
        end;
    end;

    var
        LineSeparatorTok: Label '\n', Locked = true;
        FieldSeparatorTok: Label '|', Locked = true;
}

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

    procedure Compute(var ConfigurationLine: Record "BJF MN Config Line" temporary): Text[64]
    var
        TempSorted: Record "BJF MN Config Line" temporary;
        CryptographyManagement: Codeunit "Cryptography Management";
        Serialized: TextBuilder;
    begin
        TempSorted.Copy(ConfigurationLine, true);
        TempSorted.Reset();
        TempSorted.SetCurrentKey(Operation, "Page ID", "Control Name", Profile, "Stage Id", "Entry No.");
        Serialized.Append(this.FormatVersionTok);
        if TempSorted.FindSet() then
            repeat
                this.AppendLine(Serialized, TempSorted);
            until TempSorted.Next() = 0;
        exit(CopyStr(CryptographyManagement.GenerateHash(Serialized.ToText(), 2), 1, 64));
    end;

    local procedure AppendLine(var Serialized: TextBuilder; Line: Record "BJF MN Config Line" temporary)
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
            if FieldRef.Number <> Line.FieldNo("Entry No.") then begin
                // Options and enums serialize as ordinals: captions depend on the session
                // language and a fingerprint must not.
                if FieldRef.Type = FieldType::Option then begin
                    OptionOrdinal := FieldRef.Value();
                    Serialized.Append(Format(OptionOrdinal, 0, 9));
                end else
                    Serialized.Append(Format(FieldRef.Value(), 0, 9));
                Serialized.Append(this.FieldSeparatorTok);
            end;
        end;
    end;

    var
        FormatVersionTok: Label 'v3:', Locked = true;
        LineSeparatorTok: Label '\n', Locked = true;
        FieldSeparatorTok: Label '|', Locked = true;
}

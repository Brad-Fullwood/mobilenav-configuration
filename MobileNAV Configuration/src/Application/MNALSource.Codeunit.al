namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Turns text into pieces of AL source: identifiers and string literals. Used by the provider writer and the scaffold writer.
/// </summary>
codeunit 77721 "BJF MN AL Source"
{
    Access = Internal;

    var
        AlphanumericTok: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', Locked = true;
        DigitsTok: Label '0123456789', Locked = true;

    /// <summary>Returns an identifier made from a text: each run of letters and digits starts upper case, and an all-capital run of three or more letters is capitalised.</summary>
    /// <param name="Value">Any text, such as a caption, a field name or an object name.</param>
    /// <returns>The identifier. It starts with N when the result is empty or starts with a digit.</returns>
    procedure Identifier(Value: Text): Text
    var
        Result: Text;
        Word: Text;
    begin
        foreach Word in this.Words(Value) do
            if (StrLen(Word) > 2) and (Word = UpperCase(Word)) and (Word <> LowerCase(Word)) then
                Result += UpperCase(CopyStr(Word, 1, 1)) + LowerCase(CopyStr(Word, 2))
            else
                Result += UpperCase(CopyStr(Word, 1, 1)) + CopyStr(Word, 2);
        if (Result = '') or (StrPos(this.DigitsTok, CopyStr(Result, 1, 1)) > 0) then
            exit('N' + Result);
        exit(Result);
    end;

    /// <summary>Returns the text as the body of an AL single quoted string.</summary>
    /// <param name="Value">The text.</param>
    /// <returns>The text with each quote doubled, without the surrounding quotes.</returns>
    procedure Escaped(Value: Text): Text
    begin
        exit(Value.Replace('''', ''''''));
    end;

    /// <summary>Returns the text as an AL single quoted string literal, with the quotes around it.</summary>
    /// <param name="Value">The text.</param>
    /// <returns>The literal, for example 'it''s'.</returns>
    procedure Quoted(Value: Text): Text
    begin
        exit('''' + this.Escaped(Value) + '''');
    end;

    /// <summary>Returns the letters and digits of a text, keeping their case. A text that starts with a digit gets N in front.</summary>
    /// <param name="Value">Any caption, prefix or object name.</param>
    /// <returns>The letters and digits, or an empty text when the value has none.</returns>
    procedure LettersAndDigits(Value: Text): Text
    var
        Result: Text;
        CharIndex: Integer;
    begin
        for CharIndex := 1 to StrLen(Value) do
            if this.IsLetterOrDigit(Value[CharIndex]) then
                Result += CopyStr(Value, CharIndex, 1);
        if Result <> '' then
            if this.IsDigit(Result[1]) then
                exit('N' + Result);
        exit(Result);
    end;

    /// <summary>Splits a text into its runs of ASCII letters and digits. Each run is one word.</summary>
    /// <param name="Value">Any text.</param>
    /// <returns>The words, in order. Other characters separate them.</returns>
    procedure Words(Value: Text): List of [Text]
    var
        Result: List of [Text];
        Word: Text;
        Letter: Text;
        Index: Integer;
    begin
        for Index := 1 to StrLen(Value) do begin
            Letter := CopyStr(Value, Index, 1);
            if StrPos(this.AlphanumericTok, Letter) > 0 then
                Word += Letter
            else
                this.AddWord(Result, Word);
        end;
        this.AddWord(Result, Word);
        exit(Result);
    end;

    local procedure AddWord(var Result: List of [Text]; var Word: Text)
    begin
        if Word <> '' then
            Result.Add(Word);
        Word := '';
    end;

    local procedure IsLetterOrDigit(Character: Char): Boolean
    begin
        exit(((Character >= 'A') and (Character <= 'Z')) or ((Character >= 'a') and (Character <= 'z')) or this.IsDigit(Character));
    end;

    local procedure IsDigit(Character: Char): Boolean
    begin
        exit((Character >= '0') and (Character <= '9'));
    end;
}

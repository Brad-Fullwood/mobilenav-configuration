namespace BradFullwood.MobileNAV.Configuration;

using System.Text;

/// <summary>
/// One emulator request sent through the API. The row is temporary and never stored: the request
/// text goes in, and the response comes back in the same call.
/// </summary>
table 77700 "BJF MN Emulator Request"
{
    Access = Internal;
    Caption = 'MobileNAV Emulator Request';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; Request; Text[2048])
        {
            Caption = 'Request';
        }
        /// <summary>
        /// The response JSON of the request. A blob, because a card or a list can be longer than a
        /// text field holds.
        /// </summary>
        field(3; Response; Blob)
        {
            Caption = 'Response';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    /// <summary>Stores the response text in the Response blob, replacing what it held.</summary>
    /// <param name="Value">The response JSON.</param>
    procedure SetResponse(Value: Text)
    var
        OutStr: OutStream;
    begin
        Rec.Response.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(Value);
    end;

    /// <summary>Reads the Response blob back as text, in chunks so long responses come through whole.</summary>
    /// <returns>The response JSON, or '' when no response is stored.</returns>
    procedure GetResponse(): Text
    var
        InStr: InStream;
        Chunk: Text;
        Builder: TextBuilder;
    begin
        Rec.Response.CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS() do begin
            InStr.ReadText(Chunk, 1000);
            Builder.Append(Chunk);
        end;
        exit(Builder.ToText());
    end;
}

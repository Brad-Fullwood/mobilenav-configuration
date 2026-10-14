namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The About text of the device emulator, shown at the top of the Emulator help FactBox. The three paragraphs form one text,
/// with a blank line between them, so the FactBox shows all of it in one scroll area.
/// </summary>
codeunit 77831 "BJF MN Emulator Text"
{
    Access = Internal;

    var
        AboutPara1Lbl: Label 'The emulator runs the MobileNAV code of this tenant. It builds the chosen user''s configuration through the MobileNAV Core Functions codeunit, inside a rollback. Lists, cards, buttons, validation and menus then come from the MobileNAV page services. The emulator sends them the same SOAP requests as a device, built by the MobileNAV Web Service Handling and Encode Decode Helper codeunits. The profile, the user setup and the token come from the MobileNAV Profile Setup, User Setup and OAuth Helper records.', MaxLength = 1000;
        AboutPara2Lbl: Label 'The emulator has no camera, so a scan is typed into a scan box. It has no offline mode, and it does not run the offline JavaScript of the device. It draws the screens on a computer, not on device hardware.', MaxLength = 1000;
        AboutPara3Lbl: Label 'Reads never change data. Buttons, field edits and scans change data only when Allow Writes is on. Allow HttpClient Requests must be on for this extension in Extension Management, or the emulator cannot call the page services.', MaxLength = 1000;

    /// <summary>The About text: the three paragraphs in one text, with a blank line between them.</summary>
    /// <returns>The text to show. TextBuilder.AppendLine writes the platform line break.</returns>
    procedure AboutText(): Text
    var
        Builder: TextBuilder;
    begin
        Builder.AppendLine(this.AboutPara1Lbl);
        Builder.AppendLine('');
        Builder.AppendLine(this.AboutPara2Lbl);
        Builder.AppendLine('');
        Builder.AppendLine(this.AboutPara3Lbl);
        exit(Builder.ToText());
    end;
}

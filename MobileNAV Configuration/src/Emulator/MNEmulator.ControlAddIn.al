namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Draws MobileNAV device screens as phone frames: the main menu, lists, cards and drill-downs.
/// The control asks the page for each screen through the Request event and shows the answer.
/// Used by the device emulator page.
/// </summary>
controladdin "BJF MN Emulator"
{
    RequestedHeight = 780;
    MinimumHeight = 400;
    VerticalStretch = true;
    HorizontalStretch = true;
    VerticalShrink = true;
    HorizontalShrink = true;
    Scripts = 'src/Emulator/Scripts/Emulator.js';
    StartupScript = 'src/Emulator/Scripts/EmulatorStartup.js';

    /// <summary>Raised once the control has loaded and can take a response.</summary>
    event ControlReady();

    /// <summary>Raised when the user asks for a screen.</summary>
    /// <param name="RequestJson">The request JSON, as defined by the emulator protocol.</param>
    event Request(RequestJson: Text);

    /// <summary>Shows the response to the last request, replacing the screen shown.</summary>
    /// <param name="ResponseJson">The response JSON built by the emulator codeunit.</param>
    procedure Respond(ResponseJson: Text);

    /// <summary>Shows a message in the status area of the phone frame.</summary>
    /// <param name="Text">The message to show.</param>
    procedure ShowMessage(Text: Text);
}

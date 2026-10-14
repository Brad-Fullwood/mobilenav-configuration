namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Shows a full HTML document inside a sandboxed iframe. Used by the device preview in place of
/// Microsoft's WebPageViewer, which Business Central online does not permit in a per-tenant extension.
/// </summary>
controladdin "BJF MN HTML Viewer"
{
    RequestedHeight = 700;
    MinimumHeight = 400;
    VerticalStretch = true;
    HorizontalStretch = true;
    VerticalShrink = true;
    HorizontalShrink = true;
    Scripts = 'src/Preview/Scripts/HtmlViewer.js';
    StartupScript = 'src/Preview/Scripts/HtmlViewerStartup.js';

    /// <summary>Raised once the control has loaded and can take content.</summary>
    event ControlReady();

    /// <summary>Replaces the shown document.</summary>
    /// <param name="Html">The full HTML document to show.</param>
    procedure SetContent(Html: Text);
}

// Renders the HTML document Business Central sends in an iframe that fills the control.
// The iframe runs no scripts: sandbox allows same origin only.
function getViewerFrame() {
    var frame = document.getElementById('bjfMnHtmlViewer');
    if (!frame) {
        var host = document.getElementById('controlAddIn');
        host.style.margin = '0';
        host.style.padding = '0';
        host.style.height = '100%';
        host.style.overflow = 'hidden';
        frame = document.createElement('iframe');
        frame.id = 'bjfMnHtmlViewer';
        frame.setAttribute('sandbox', 'allow-same-origin');
        frame.style.border = '0';
        frame.style.width = '100%';
        frame.style.height = '100%';
        frame.style.display = 'block';
        host.appendChild(frame);
    }
    return frame;
}

function SetContent(html) {
    getViewerFrame().srcdoc = html;
}

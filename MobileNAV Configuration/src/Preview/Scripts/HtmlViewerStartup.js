// Creates the iframe and tells Business Central the control can take content.
getViewerFrame();
Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlReady', []);

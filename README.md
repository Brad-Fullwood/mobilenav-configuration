# MobileNAV Configuration

Three Business Central apps in one repository. Open `MobileNAV Configuration.code-workspace` in VS Code to work on all three.

| Folder | App | What it is |
|---|---|---|
| [`MobileNAV Configuration/`](MobileNAV%20Configuration/README.md) | MobileNAV Configuration | The framework: declare what a MobileNAV device shows in fluent AL, apply it correctly, route device buttons to one event, and diagnose and repair MobileNAV from the MobileNAV Doctor page. |
| [`MobileNAV Configuration WMS/`](MobileNAV%20Configuration%20WMS/README.md) | MobileNAV Configuration WMS | Satellite: the doctor checks that need WMS MobileNAV installed. |
| [`MobileNAV Configuration Example/`](MobileNAV%20Configuration%20Example/README.md) | MobileNAV Configuration Example | The example to read and copy: one provider in fifteen levels, from three fields on an item page to a scan wizard, a dialog and buttons on MobileNAV's own pages. Written for a Business Central developer who has not used MobileNAV. |

Build each app from its own folder (see its README). The WMS and Example apps compile against the framework's `.app` in their `.alpackages`.

Tools: `MobileNAV Configuration/tools/generate_table_functions.py` regenerates the table function codeunits from the MobileNAV symbols after a MobileNAV upgrade. The framework README's Build section has the command.

## License

Copyright (c) 2026 Brad Fullwood.

Licensed under the Mozilla Public License 2.0. See [LICENSE](LICENSE). You may use, modify and distribute this code, including in commercial products. Changes to these files must be published under the same license, and copyright notices must be kept.

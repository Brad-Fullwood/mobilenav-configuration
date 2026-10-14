# MobileNAV Configuration WMS

Satellite app for [MobileNAV Configuration](../MobileNAV%20Configuration/README.md). It contributes the doctor checks and workarounds that need **WMS MobileNAV** (MULTISOFT) installed, through an `enumextension` of `"BJF Diagnostic Check Type"`:

| Check | Catches |
|---|---|
| **Inventory Setup** | Package number series, package tracking and the undefined package number not set; the Move-posts-own-lines workaround active. |
| **Package Consistency** | Package No. Information records without a matching MUL WMS Package record, which the WMS integrity check hard-gets after every package posting. |
| **Split Packages** | Packages whose stock is spread over more than one bin, which fails every posting that touches them. The fix posts a reclassification consolidating the package into the bin holding most of it, carrying lot, serial and package tracking. |
| **Movement Journals** | MobileNAV User Setup without a Movement Journal Name; the batch missing on a Transfer-type template; the batch lacking a No. Series, which makes Move/Split Package fail with "Document No. must have a value". The fix assigns an `MNMOVE` series, creating it if needed. |
| **Item Tracking Codes** | "Package Info. Inb./Outb. Must Exist" enabled without the create-on-posting workaround, which breaks Split/Move Package. Also flags "Package Transfer Tracking" disabled. |
| **Leftover Move Lines** | Lines left in a MobileNAV movement batch, which Move Package posts together with the move. A Blocker when Bin or New Bin Code is missing at a bin-mandatory location, otherwise a Warning. The fix deletes the line with its item tracking. |

It also carries workarounds for WMS MobileNAV behaviour that would otherwise need a fix in every customer app:

| Workaround | Fixes |
|---|---|
| **Tote fill** (`src/Workarounds/WMSToteFill.Codeunit.al`) | Registering one pick line from the device stops with *Missing tote no.* while any other Take line on the pick has no tote, because WMS checks the whole pick. When a tote is scanned on a line of a tote pick, the same tote goes on the other Take lines without a tote that belong in it under the pick's Tote Combination (same order, shipment or customer). Found at a customer site, 13 October 2026. |
| **Create Package Info. on Posting** (Item Tracking Code Card, off by default) | Standard BC has "Create SN/Lot No. Info on Posting" but no package equivalent. With "Package Info. Inb./Outb. Must Exist" on, a reclass to a freshly generated package number (MobileNAV Split Package) fails because BC hard-gets Package No. Information for the new number. The workaround creates the missing record for both numbers before the check runs. Remove it once Microsoft ships the standard toggle. |
| **Move Posts Only Its Own Lines** (Inventory Setup, off by default) | `MUL WMS PageFunctions.MovePackage2` posts the whole movement batch instead of the lines it created, so any stale line blocks every Move Package or posts with it. Each item journal line is stamped with its creating session. When enabled, non-interactive postings of a MobileNAV movement batch are narrowed to the current session's lines. Interactive posting and callers that already scope their lines are untouched. Remove it once MultiSoft fixes `MovePackage2`. |

It is a separate app only so the framework installs in environments without WMS MobileNAV. Depends on MobileNAV Configuration 4.0.0.0 and WMS MobileNAV 1.2.0.0. Object ids 77740 to 77759. Run the checks from **MobileNAV Doctor**, **Run all diagnostics**.

## Upgrading from 4.6

Three fields move from MobileNAV Configuration to this app: Create Package Info. on Posting (Item Tracking Code), Move Posts Only Its Own Lines (Inventory Setup) and Created Session ID (Item Journal Line). They get new field ids here, and their values are not carried over.

Deploy in this order:

1. MobileNAV Configuration, with `bcbd.py upload --schema ForceSync`.
2. This app.
3. Switch the two options on again on the Item Tracking Codes and Inventory Setup that used them.

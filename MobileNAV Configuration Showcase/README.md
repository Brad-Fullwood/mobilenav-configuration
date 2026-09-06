# MobileNAV Configuration Showcase

The reference provider for [MobileNAV Configuration](../MobileNAV%20Configuration/README.md): one codeunit, six levels, from three lines to a full device flow. Install it, apply it, walk through it on a device. It is also the smoke test: every verb the framework offers is used at least once, and the doctor checks all of it.

Read [`ShowcaseMNProvider.Codeunit.al`](src/Provider/ShowcaseMNProvider.Codeunit.al) top to bottom. That file is the talk.

## The six levels

| Level | What the device gets | Lines | What you did not have to know |
|---|---|---|---|
| 1 | Three fields on MobileNAV's item page, one editable, one filterable | 4 | Importance defaults, profile rows, the Page Update flag, metadata refresh |
| 2 | A button on the item page that runs your code | 2 plus a handler | Which MobileNAV function serves the item table, the companion web service, per-table events |
| 3 | A bin lookup, a headed group, declared order, an inventory-only filter, a location flow filter, two layout rules (the button only shows when out of stock; the quantity turns red) | 12 | Relation rows, group marker rows, the dense Order number, filter row numbering, dynamic layout tables |
| 4 | A page of your own: a stock-count sheet, per user, opened as a new count, with a scan input, a quantity with steppers, a bin lookup, and a two-stage wizard that advances on its own | 15 | Web-service publishing, the Own filter, stage rows and stage masks, category codes behind stage captions |
| 5 | A dialog with two inputs and a button that runs a procedure of yours, on a table MobileNAV has no function for | 8 | Report-type pages, function-codeunit web services, the Main row pointer to it |
| 6 | A profile, a menu heading with a German translation, captions per language, a hidden toolbar button, a saved filter, one field kept off the profile | 12 | Master data rows, the caption table, saved-filter row numbering, profile field rows |

## Running it

1. Build the framework (`MobileNAV Configuration`), drop its `.app` into this folder's `.alpackages` next to the MobileNAV and Microsoft symbols, and build this app.
2. Install both. Install applies the provider; the device handover waits for a client.
3. Open **MobileNAV Configuration**, select *MobileNAV Configuration Showcase*, run **Apply selected**. Answer the delegated-admin prompt if it appears.
4. Open **MobileNAV Doctor**. Every check should pass. Then break something in MobileNAV's own setup pages (hide a field, delete a stage, change a caption) and run the checks again: the finding names what changed and **Apply Fix** puts it back.
5. On a device: the item list shows the new fields; an item with no stock offers *Flag for Reorder*; the *Stock Count* tile opens a count sheet that moves from scan to count by itself; *Quick Adjust* posts a count through your own codeunit.

## What to point at in the meeting

- The provider has no MobileNAV service names, no control ids, no profile rows, no stage masks. Every one of those is a MobileNAV rule the framework applies.
- Everything declared is checked. The doctor is the regression test for configuration, and its fixes are the repair.
- Adding a field to a page is one line. Adding a button is one line plus a subscriber. Adding a page of your own is a normal AL page plus a declaration.
- What stays manual is deliberate and listed in the framework README's Coverage section.

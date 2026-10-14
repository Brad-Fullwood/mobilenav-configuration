# MobileNAV Configuration Example

A Business Central app that configures MobileNAV devices from AL code. It is written for a Business Central developer who has not worked with MobileNAV. Read it, build it, apply it, then copy the pattern into a customer app.

MobileNAV is the app that puts Business Central pages on Android scanners and phones. Its setup normally lives in a dozen administration pages. With the [MobileNAV Configuration](../MobileNAV%20Configuration/README.md) framework you declare the setup in one codeunit instead, and the framework writes the MobileNAV rows, checks them and repairs them.

Start with [`ExampleMNProvider.Codeunit.al`](src/Provider/ExampleMNProvider.Codeunit.al) and read it top to bottom. Each level is one procedure, and its comment says what the device gets and what you did not have to know.

## I want to...

| I want to... | Level | Where to look |
|---|---|---|
| Show a field on a MobileNAV page | 1 | `LevelOneThreeLines` in the provider, the field in `src/Item/ExampleMobileNAVItem.PageExt.al` |
| Add a button that runs my code | 2, 7 | `LevelTwoAButtonWithCodeBehind`, the handler in `src/Item/ExampleItemHandler.Codeunit.al` (`src/Bin/ExampleBinHandler.Codeunit.al` for a table MobileNAV has no function for) |
| Fill a field by picking a record (a lookup) | 3 | `LevelThreeLookupsGroupsAndALayout` |
| Put a page of my own on the device | 4 | `LevelFourAPageOfYourOwn`, `src/StockCount/ExampleStockCount.Page.al` |
| Run the page as a wizard | 4 | The `Wizard()` and `Stage()` part of `LevelFourAPageOfYourOwn` |
| Show a dialog that runs a procedure of mine | 5 | `LevelFiveADialogWithYourOwnFunction`, `src/StockCount/ExampleQuickAdjust.Page.al`, `src/StockCount/ExampleCountFunctions.Codeunit.al` |
| Take a photo on the device and store it | 12 | `LevelTwelveAPhotoOnTheCount`, the Photo controls in `src/StockCount/ExampleStockCount.Page.al`, `src/StockCount/ExampleStockCountFunctions.Codeunit.al` |
| Capture a signature | 13 | `LevelThirteenASignatureOnTheCount`, the same two files |
| Show child rows of a record | 14 | `LevelFourteenChildRows`, `src/StockCount/ExampleStockCountLines.Page.al`, `src/StockCount/ExampleStockCountLine.Table.al` |
| Print a document to the device as a PDF | 15 | `LevelFifteenAPrintToPdf`, `src/StockCount/ExampleStockCount.Report.al`, `StockCountPrint` in `src/StockCount/ExampleStockCountFunctions.Codeunit.al` |
| Filter what the device lists, or offer a filter | 1, 3, 6 | `Filterable()` in level 1, `PageFilterExpression` and `FlowFilter` in level 3, `SavedFilter` in level 6 |
| Give device users a profile, or hide a field from one | 6 | `LevelSixProfilesCategoriesAndPolish` |
| Caption a page or a control | 6 | `LevelSixProfilesCategoriesAndPolish` |
| Colour a line, show a toast or a dialog without a tap | 8 | `LevelEightColourALine`, `src/Bin/ExampleMobileNAVBin.PageExt.al`, `src/Bin/ExampleBinHandler.Codeunit.al` |
| Change a MobileNAV page that has no tile | 9 | `LevelNineAPageMobileNAVAlreadyLinksTo` |
| Choose what a list row shows (a line format) | 10 | `LevelTenASecondLineInTheList` |

## The levels

| Level | What the device gets | Lines | What you did not have to know |
|---|---|---|---|
| 1 | Three fields on MobileNAV's item page: one editable, one in the filter pane | 4 | That MobileNAV hides new fields behind "show more", the row each profile needs, the Page Update flag, the metadata refresh |
| 2 | A Flag for Reorder button on the item page that runs your code | 3, plus a handler | Which MobileNAV function serves the item table, the companion web service the tap travels through, MobileNAV's per-table events |
| 3 | A bin lookup, a headed group, the declared fields first, inventory items only, a location filter, and two layout rules: the button shows only while out of stock, and the quantity turns red | 15 | Relation rows, group marker rows, MobileNAV's Order numbering, filter row numbering, the dynamic layout tables |
| 4 | A stock count page of your own with a menu tile, per user, opened as a new count, with a scan input, a bin lookup, a quantity with plus and minus buttons, a two-stage wizard that moves on by itself, and a Stock Counts button on the item page that opens it | 22 | Web service publishing, the Own filter that scopes a page to the device user, stage rows and stage masks, the category codes behind stage captions, the Parent Page rows a link needs |
| 5 | A Quick Adjust dialog with two inputs and a Post button that runs a procedure of yours | 10 | Report-type pages, function codeunit web services, the Main row field that points the dialog at your codeunit |
| 6 | A profile, a menu heading with a German translation, a caption per language, a hidden toolbar button, a saved filter, and Unit Price kept off the example profile | 14 | Master data rows, the caption table, saved filter row numbering, profile field rows |
| 7 | An Items in Bin button on MobileNAV's bin page, a table MobileNAV has no page function for | 2, plus a handler | That MobileNAV serves buttons on 40 tables only, and the companion codeunit the framework registers for the 78 others |
| 8 | Bins that hold stock show their first line in green | 2, plus the page extension field and a handler | MobileNAV's FieldControl mobile type and the encoded text it carries |
| 9 | Zone Code in the filter pane of MobileNAV's bin content page, which has no tile and is opened from MobileNAV's own pages | 3 | That a page without a tile must be reachable from another page, that MobileNAV's own relations count, and that taking over the page's tiles would make MobileNAV delete other pages' root rows |
| 10 | A second line on every item list row: the inventory with its caption, then the item category | 5 | MobileNAV's Line Format table, one row per caption, value or separator, and that MobileNAV turns a misspelt field name into plain text instead of failing |
| 12 | A Photo control on the stock count: take a picture, see it on the card, stored in a Media field | 9, plus a page control pair and a function | That binding the Media field gives "No file specified", the hidden size field the device asks, MobileNAV's BLOB function shape and its EXP, IMP, DEL and LEN actions, how a codeunit of yours becomes an operation of the page's web service |
| 13 | A signature pad on the stock count, stored in a Media field | 9, plus a page control pair and a function | That a signature is an image control of another mobile type, and that a read-only signature draws only an icon on Android |
| 14 | A Lines button on the stock count card that opens the count's lines, a page without a tile | 9, plus a table and a list page | That MobileNAV does not show list parts, that a page without a tile needs a link or MobileNAV drops its profile rows, the Parent Page rows that make the link drawn |
| 15 | A Print button on the stock count that opens the count as a PDF, from a report of yours | 8, plus a report and a function | That a file comes back through a function of type Generated BLOB, that mobile type PDF makes the device open it, the result text MobileNAV wraps the file in |

Levels 12 to 15 each add a wizard stage to the stock count, because on a wizard page a control shows only in the stages that show it.

## What is in the app

| File | What it does |
|---|---|
| `src/Provider/ExampleMNProvider.Codeunit.al` | The provider: the levels. |
| `src/Provider/ExampleMNProviders.EnumExt.al` | Registers the provider so the framework lists it. |
| `src/Provider/ExampleInstall.Codeunit.al` | Applies the provider when the app is installed. |
| `src/Item/ExampleItem.TableExt.al` | Three fields on Item: notes, default bin, reorder flag. |
| `src/Item/ExampleMobileNAVItem.PageExt.al` | Adds those fields and the placeholder controls for the button and the link to MobileNAV's item page. |
| `src/Item/ExampleItemHandler.Codeunit.al` | Runs when the Flag for Reorder button is tapped. |
| `src/StockCount/ExampleStockCount.Table.al`, `ExampleStockCount.Page.al` | The stock count table, with its Photo and Signature Media fields, and the card page the device shows, with the placeholder controls and web-service wrappers for the photo, signature and print. |
| `src/StockCount/ExampleStockCountFunctions.Codeunit.al` | The photo, signature and print functions, declared on the stock count page with `PageFunctions()`. |
| `src/StockCount/ExampleStockCountLine.Table.al`, `ExampleStockCountLines.Page.al` | The count's lines and the list page the Lines button opens. |
| `src/StockCount/ExampleStockCount.Report.al`, `ExampleStockCount.rdl` | The report the Print button returns as a PDF. |
| `src/StockCount/ExampleQuickAdjust.Page.al` | The dialog page. |
| `src/StockCount/ExampleCountFunctions.Codeunit.al` | The procedure the dialog's Post button runs. |
| `src/Bin/ExampleMobileNAVBin.PageExt.al` | Adds the button and the field control to MobileNAV's bin page. |
| `src/Bin/ExampleBinHandler.Codeunit.al` | Runs when the bin button is tapped, and picks the line colour. |
| `permissions/ExampleMNConfig.PermissionSet.al` | Execute and data permissions for all of the above, plus the framework's own permission set. |

Object ids are 50100 to 50149, a normal customer range, so the app looks like the customer app you will write.

## Build it

1. Put these symbol packages in this folder's `.alpackages`: the framework (`Brad Fullwood_MobileNAV Configuration_4.5.1.0.app`, built from `../MobileNAV Configuration`), `MULTISOFT KFT_MobileNAV`, and the Microsoft System, System Application, Business Foundation, Base Application and Application packages. The repository does not include the MobileNAV and Microsoft packages.
2. Build from this folder:

```sh
python3 ~/Projects/tools/business-central/bc-build-deploy/bcbd.py build
```

`bcbd.py` runs the compiler with CodeCop, UICop, PerTenantExtensionCop and the ALCops analyzers, and prints the diagnostics by rule. The app builds with zero diagnostics. The AL extension in VS Code builds it too.

## Apply it

Install the framework, then this app, in a sandbox that has MobileNAV. The install codeunit applies the provider, but install has no client to answer MobileNAV's confirmation dialogs, so the provider shows as Outdated until it is applied once more:

1. Open **MobileNAV Configuration**.
2. Select *MobileNAV Configuration Example* and run **Apply selected**.
3. Answer Yes to the delegated-admin or API-access prompt. It can appear more than once, once for each new web service.
4. Open **MobileNAV Doctor** and run the checks. Every check should pass.

From the command line, with `mnconfig.py` from the `mobilenav-config` tools:

```sh
mnconfig.py preview EXAMPLE    # what the apply would change, rolled back afterwards
mnconfig.py apply EXAMPLE
mnconfig.py doctor             # repeat until it prints no findings
```

Run the API as a licensed user of the tenant. A delegated administrator cannot answer MobileNAV's confirmation from an API call.

## See it on a device

Log out of the MobileNAV app and log in again. A page refresh does not download a new configuration.

- The item list has the new fields, an Out of stock saved filter, and Inventory and Location in the filter pane.
- An item with no stock shows Flag for Reorder and a red quantity. Tapping the button shows a toast and sets the flag.
- Stock Counts on the item opens your counts of that item.
- The Example menu heading holds two tiles. Stock Count opens a new count that moves from the scan stage to the count stage by itself. Quick Adjust posts a count through `PostCount`.
- The bin list shows bins with stock in green. Items in Bin on a bin answers with a toast.
- MobileNAV's bin content page offers Zone Code as a filter.
- After the count stage, the stock count asks for a photo and a signature, offers Lines, which opens the count's lines, and Print, which opens the count as a PDF.

To try the Doctor, change something in MobileNAV's own setup pages (hide a field, delete a stage, change a caption) and run the checks again. The finding names what changed, and **Apply Fix** puts it back.

## Copy the pattern into a customer app

1. **Dependency.** Add the framework to the customer app's `app.json`. The framework uses namespaces, so the app needs `runtime` 12.0 or later.

    ```json
    "dependencies": [
      {
        "id": "8943817b-00dd-4a15-b70a-209b96da80e2",
        "name": "MobileNAV Configuration",
        "publisher": "Brad Fullwood",
        "version": "4.5.1.0"
      }
    ]
    ```

2. **Provider codeunit.** Copy `ExampleMNProvider.Codeunit.al`. Give it your own `GetId`, name and description, and keep only the levels you need in `DefineConfiguration`. One provider per feature keeps each one small.
3. **Enum extension.** Copy `ExampleMNProviders.EnumExt.al` and point its `Implementation` at your provider. The framework finds providers through this enum.
4. **Page extension placeholder controls.** For each field you show on a MobileNAV page, add it to a page extension of that page. For each button or link, add a placeholder control, `field(YourButton; '')`, and declare it in the provider with `Button('YourButton')` or `Link(...)`. A page of your own is a normal AL page, and the provider refers to its control names.
5. **Handler subscriber.** Subscribe to `"BJF MN Function Router".OnPageFunction`, filter on the page id and the control name, and use `FunctionRecord.SetTable()` to get the tapped record. `ExampleItemHandler.Codeunit.al` is the whole pattern. For colours, toasts and dialogs without a tap, wire a FieldControl field as in `ExampleMobileNAVBin.PageExt.al` and subscribe to `"BJF MN Field Control".OnCalculateFieldControl`.
6. **Install codeunit.** Copy `ExampleInstall.Codeunit.al` and change the enum value. An administrator still applies the provider once from **MobileNAV Configuration** after install, to finish the handover to devices.
7. **Permission set.** Grant execute on the provider and every handler codeunit, and data permissions on your own tables. Include `"BJF MN Configuration"`, which administrators need to open **MobileNAV Configuration** and **MobileNAV Doctor**.

A button on a page of your own needs one more thing. If the page's source table is one MobileNAV Page Functions serves, add the one-line web-service wrapper below to the page, named after that table's dispatcher (the framework README lists them). The dialog's button needs none, because it runs through `Functions()`.

```al
[ServiceEnabled]
procedure MNTrackSpecExtFunc(PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
var
    FunctionRouter: Codeunit "BJF MN Function Router";
begin
    exit(FunctionRouter.Execute(Rec, PageName, FieldName, DeviceID));
end;
```

For a page over your own table, declare `PageFunctions(Codeunit::"Your Functions")` and name each button's procedure with `FunctionName()`. Each procedure takes the record as its first parameter, `"Key"`, and the page gets a `[ServiceEnabled]` wrapper of the same name, as MobileNAV's own pages have. The stock count page and `ExampleStockCountFunctions.Codeunit.al` show both for the photo, signature and print functions.

## Test your provider

Codeunit `"BJF MN Provider Assert"` checks a provider in a unit test. It builds the provider's definition and compares it with Business Central metadata:

- every page and function codeunit id exists
- every control name is a control of its page (page extension controls included) or a field of the page's source table
- every button function exists for the page's source table, as the apply checks it
- the builder's modifier rules and the validator's rules hold (Filterable on a button, the same control declared twice, a second RestartsHere)
- every published page has a menu tile or a Link or Lookup that opens it, unless it is one of MobileNAV's pages
- every page the provider uses without publishing it is one of MobileNAV's pages

It reads no MobileNAV table, so the test runs in a container where MobileNAV is installed but not configured. A test codeunit with one method is enough:

```al
codeunit 50150 "Example Provider Test"
{
    Subtype = Test;

    [Test]
    procedure ExampleProviderIsValid()
    var
        ProviderAssert: Codeunit "BJF MN Provider Assert";
    begin
        ProviderAssert.AssertProviderIsValid(Enum::"BJF MN Config Provider"::Example);
    end;
}
```

`AssertProviderIsValid` raises one error that lists every problem. `ProviderIsValid(Provider)` returns a Boolean, and `ProviderIsValid(Provider, Errors)` also returns the messages in a `List of [Text]`, for a test that checks one message.

The test needs no test toolkit. The folder `../MobileNAV Configuration Example Tests` is this test as an app (ids 50150 to 50159) that depends on the framework and this app. Put both `.app` files and the packages listed under Build it in its `.alpackages`, then build it the same way.

Control names are checked only where the session can read the system table Page Control Field. Business Central online does not grant that to every license: a delegated administrator gets a license error when opening it. There the other checks still run.

The app `MobileNAV Configuration Example Tests` also publishes API page `testResults`, with publisher `bjf` and group `mobilenavtests`. A GET on `testResults` runs the test codeunits 50150 to 50155 and returns one row per test method, with `success` and `errorText`. A filter on `codeunitId`, such as `$filter=codeunitId eq 50153`, runs one codeunit. `mnconfig.py tests` calls this API. The runner turns test isolation off, so the tests write to the database they run against. Run them in a sandbox.

## What the framework refuses, and the message you get

These two declarations stop the apply with an error that says what to do.

**A function name the page does not have.** MobileNAV Page Functions has no `RegisterLine` for Warehouse Journal Line:

```al
Configuration.Page(Page::"MobileNAV WhsePhysInvtJrnlLine")
    .Button('Register').FunctionName('RegisterLine');
```

> Button Register on `<service>` names function RegisterLine, which MobileNAV Page Functions does not have for table 7311, so every tap would fail on the device. Leave FunctionName() out, use one of `<the names it has>`, or declare PageFunctions() with the codeunit that has RegisterLine.

Leave `FunctionName()` out on MobileNAV's own pages. The framework picks the right function.

**A companion web service another app registered.** Another app already points Bin Content's companion web service at its own codeunit:

```al
Configuration.Page(Page::"MobileNAV BinContent")
    .Button('YourButton');
```

> Web service `<service>` (Codeunit) already points at object `<id> <name>`, and this configuration needs it to point at `<id> <name>`. Another app or an administrator registered it, so the apply leaves it alone. If `<id>` does not serve these buttons, run the MobileNAV Doctor and apply its fix to repoint the service. If it does, declare PageFunctions(`<id>`) on the page.

## Full reference

The framework [README](../MobileNAV%20Configuration/README.md) has every builder method in its Fluent reference section, how a button tap reaches Business Central in Buttons end to end, the Field control section, and the MobileNAV rules the framework applies for you.

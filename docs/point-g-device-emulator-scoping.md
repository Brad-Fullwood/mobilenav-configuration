# Point G: a device emulator in Business Central (scoping note)

Status on 25 October 2026, framework 4.9.0.1. No code in this note.

## The question

Can a developer or a key user see and use a complete MobileNAV device inside Business Central, without a
scanner, an Android emulator or a device login? The emulator API has been in the framework since 4.7.0.0 at the latest, when the command line `emulate` wrapper for it was added.
The roadmap estimate of 3 days, written on 14 October, is for closing the gaps listed below.

## What 4.9.0.1 already has

Page "BJF MN Device Emulator" ([README, Device emulator](../MobileNAV%20Configuration/README.md#device-emulator)):

- Menu, lists and cards for any user, language and profile, from MobileNAV's own configuration build. The
  build runs inside a rollback, so it needs no device login, writes no Login Log row and takes no licence.
- Reads run in process through the page's source table view: sort, predefined filters, flow filters, parent
  relation filters, saved filters, the filter panel, search, dynamic layouts and stage settings, all
  computed in AL.
- Writes, buttons, scans, dialogs, pictures and signatures go to the tenant's SOAP page service with a
  delegated token of the signed-in user, so page triggers and `[ServiceEnabled]` functions run as they do
  for a device. Three token sources: App Registration, MobileNAV Token, Supplied Token.
- An API (`emulatorRequests`, 13 request kinds) that a script or a test can drive.
- Allow Writes in a sandbox. Outside a sandbox it also needs Allow Writes in Production and a confirmation.

## What is missing (from the README's Limits section)

1. The offline JavaScript of the device does not run.
2. A Card tile on the menu opens only when its main menu action is Create. Other Card tiles show a notice.
3. The FieldControl of an in-process read is empty. Only a live read through the page service fills it.
4. Where the MobileNAV source does not say how the device evaluates a rule, the emulator follows its own
   reading, named in a code comment. Examples: a layout without conditions matches every record, and auto
   next moves on when every editable mandatory field of the stage has a value.

## Data layer questions (answer these first)

1. Which device behaviour lives only in the Android client and not in Business Central data? List every
   rule the emulator now guesses (item 4 above) and check each against a real device capture from the
   `mobilenav-harness` headless device.
2. Can in-process reads compute FieldControl, or does it need the page's OnAfterGetRecord on a SOAP read?
   If SOAP, what does a live read per card cost in time for a list of 50 rows?
3. Can a Card tile that is not Create be opened in process? What record does the device pick when a card
   page opens straight from the menu?
4. Offline operations: which parts of the offline package (Offline Admin., Offline Admin. D., the
   JavaScript templates) can be read from tables, and which are only interpreted on the device?
5. Do HTML and ZPL print templates need rendering in the emulator, or is a download link enough?
6. Which MobileNAV version range must the emulator follow? The table function codeunits are generated
   from MobileNAV 12.0.0.46 symbols. Name the tables the emulator reads directly so an upgrade check can
   find changes.
7. What does the emulator need from the device session that a Business Central session lacks (device ID,
   GPS, camera, the login configuration download)?

## Question for Multisoft

Does Multisoft have, or plan, a browser or desktop MobileNAV client that runs against Business Central, or
can it publish how the Android client evaluates layouts, stages, auto next and the offline JavaScript
(a specification or the evaluation code)? With either, the emulator can follow the device's own rules
instead of a reading of the configuration tables. Without either, the gaps above stay as documented limits
and each guessed rule is checked against the headless device.

## Next step

Answer data layer questions 1 to 3 with captures from a sandbox. They decide whether the rest is days of
work or a set of limits to document. Send the Multisoft question at the same time, since it does not
depend on the answers.

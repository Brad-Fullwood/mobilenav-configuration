namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Generates a provider from the live MobileNAV setup of the example's pages and checks that it
/// restates the item page and the example's notes field. Passes without checking when MobileNAV has
/// no setup for the item page, as in a container without MobileNAV configuration.
/// </summary>
codeunit 50154 "Provider Writer Test"
{
    Subtype = Test;
    Access = Internal;

    /// <summary>The generated provider declares the item page and, once the example is applied, its notes field.</summary>
    [Test]
    procedure GeneratedProviderRestatesExamplePages()
    var
        ProviderWriter: Codeunit "BJF MN Provider Writer";
        ServiceNames: List of [Text];
        ServiceName: Text;
        Generated: Text;
    begin
        if not ProviderWriter.HasService(this.ItemServiceTok) then
            exit;
        foreach ServiceName in this.ExampleServiceNames() do
            if ProviderWriter.HasService(ServiceName) then
                ServiceNames.Add(ServiceName);
        ProviderWriter.SetProvider(this.ProviderIdTok, 50100, '', '');
        ProviderWriter.SetScope(false, false, false);
        Generated := ProviderWriter.Generate(ServiceNames);
        if not Generated.Contains(this.ItemPageCallTok) then
            Error(this.MissingTextErr, this.ItemPageCallTok);
        if ProviderWriter.HasControl(this.ItemServiceTok, this.NotesControlTok) and not Generated.Contains(this.NotesFieldCallTok) then
            Error(this.MissingTextErr, this.NotesFieldCallTok);
    end;

    local procedure ExampleServiceNames(): List of [Text]
    var
        Names: List of [Text];
    begin
        Names.Add(this.ItemServiceTok);
        Names.Add(this.BinServiceTok);
        Names.Add(this.StockCountServiceTok);
        Names.Add(this.QuickAdjustServiceTok);
        exit(Names);
    end;

    var
        ProviderIdTok: Label 'EXAMPLE', Locked = true;
        ItemServiceTok: Label 'MNItem', Locked = true;
        BinServiceTok: Label 'MNBin', Locked = true;
        StockCountServiceTok: Label 'MNExampleStockCount', Locked = true;
        QuickAdjustServiceTok: Label 'MNExampleQuickAdjust', Locked = true;
        NotesControlTok: Label 'ExampleNotes', Locked = true;
        ItemPageCallTok: Label 'Configuration.Page(Page::"MobileNAV Item")', Locked = true;
        NotesFieldCallTok: Label '.Field(''ExampleNotes'')', Locked = true;
        MissingTextErr: Label 'The generated provider does not contain %1.', Comment = '%1 = the expected AL text';
}

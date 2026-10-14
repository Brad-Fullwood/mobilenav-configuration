namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Holds the provider list and every provider's definition for one Doctor run, so the
/// configuration checks share one build instead of rebuilding each provider per check.
/// "BJF Diagnostics Runner" binds an instance for the run. The binding ends with the runner's
/// variable, also when a check fails, so no cache outlives its run. Unbound, TryGetProviders and
/// TryGetDefinition return false and "BJF MN Doctor Support" builds on demand.
/// </summary>
codeunit 77733 "BJF MN Doctor Run Cache"
{
    Access = Internal;
    EventSubscriberInstance = Manual;

    /// <summary>Copies the run's provider list, when a run cache is bound.</summary>
    /// <param name="TempProvider">Receives one row per provider. Emptied first.</param>
    /// <returns>True when a bound run cache answered.</returns>
    procedure TryGetProviders(var TempProvider: Record "BJF MN Provider Buffer" temporary) Found: Boolean
    begin
        this.OnGetProviders(TempProvider, Found);
        exit(Found);
    end;

    /// <summary>Copies a provider's definition, when a run cache is bound and holds it.</summary>
    /// <param name="ProviderType">The provider whose definition is wanted.</param>
    /// <param name="TempConfigurationLine">Receives the provider's lines. Emptied first.</param>
    /// <param name="TempConfigurationProperty">Receives the provider's properties. Emptied first.</param>
    /// <returns>True when a bound run cache answered.</returns>
    procedure TryGetDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary) Found: Boolean
    begin
        this.OnGetDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty, Found);
        exit(Found);
    end;

    /// <summary>
    /// Builds the provider list the way "BJF MN Provider Catalog".Populate does and keeps each
    /// definition built on the way, so each provider is built once per run.
    /// </summary>
    local procedure EnsureFilled()
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        ProviderType: Enum "BJF MN Config Provider";
    begin
        if this.Filled then
            exit;
        this.TempCachedProvider.Reset();
        this.TempCachedProvider.DeleteAll(false);
        foreach ProviderType in this.ProviderCatalog.ProviderTypes() do begin
            this.ProviderCatalog.AddProvider(this.TempCachedProvider, ProviderType, TempConfigurationLine, TempConfigurationProperty);
            this.StoreDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
        end;
        this.Filled := true;
    end;

    /// <summary>
    /// Keeps a provider's definition, its entry numbers moved into a block of their own. A
    /// definition with entry numbers outside one block is not kept and is built on demand.
    /// </summary>
    /// <param name="ProviderType">The provider the definition belongs to.</param>
    /// <param name="TempConfigurationLine">The provider's lines. Filters are reset.</param>
    /// <param name="TempConfigurationProperty">The provider's properties. Filters are reset.</param>
    local procedure StoreDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    var
        Offset: Integer;
    begin
        TempConfigurationLine.Reset();
        TempConfigurationProperty.Reset();
        if not (this.LinesFitBlock(TempConfigurationLine) and this.PropertiesFitBlock(TempConfigurationProperty)) then
            exit;
        Offset := (this.Offsets.Count() + 1) * this.BlockSize();
        this.Offsets.Add(ProviderType.AsInteger(), Offset);
        if TempConfigurationLine.FindSet() then
            repeat
                this.TempCachedLine := TempConfigurationLine;
                this.TempCachedLine.Validate("Entry No.", TempConfigurationLine."Entry No." + Offset);
                this.TempCachedLine.Insert(false);
            until TempConfigurationLine.Next() = 0;
        if TempConfigurationProperty.FindSet() then
            repeat
                this.TempCachedProperty := TempConfigurationProperty;
                this.TempCachedProperty.Validate("Entry No.", TempConfigurationProperty."Entry No." + Offset);
                this.TempCachedProperty.Insert(false);
            until TempConfigurationProperty.Next() = 0;
    end;

    local procedure LinesFitBlock(var TempConfigurationLine: Record "BJF MN Config Line" temporary): Boolean
    begin
        if TempConfigurationLine.FindFirst() then
            if TempConfigurationLine."Entry No." < 0 then
                exit(false);
        if TempConfigurationLine.FindLast() then
            exit(TempConfigurationLine."Entry No." < this.BlockSize());
        exit(true);
    end;

    local procedure PropertiesFitBlock(var TempConfigurationProperty: Record "BJF MN Config Property" temporary): Boolean
    begin
        if TempConfigurationProperty.FindFirst() then
            if TempConfigurationProperty."Entry No." < 0 then
                exit(false);
        if TempConfigurationProperty.FindLast() then
            exit(TempConfigurationProperty."Entry No." < this.BlockSize());
        exit(true);
    end;

    local procedure BlockSize(): Integer
    begin
        exit(1000000);
    end;

    [InternalEvent(false)]
    local procedure OnGetProviders(var TempProvider: Record "BJF MN Provider Buffer" temporary; var Found: Boolean)
    begin
    end;

    [InternalEvent(false)]
    local procedure OnGetDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var Found: Boolean)
    begin
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Doctor Run Cache", OnGetProviders, '', false, false)]
    local procedure "BJF MN Doctor Run Cache_OnGetProviders"(var TempProvider: Record "BJF MN Provider Buffer" temporary; var Found: Boolean)
    begin
        if Found then
            exit;
        this.EnsureFilled();
        TempProvider.Reset();
        TempProvider.DeleteAll(false);
        this.TempCachedProvider.Reset();
        if this.TempCachedProvider.FindSet() then
            repeat
                TempProvider := this.TempCachedProvider;
                TempProvider.Insert(false);
            until this.TempCachedProvider.Next() = 0;
        Found := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Doctor Run Cache", OnGetDefinition, '', false, false)]
    local procedure "BJF MN Doctor Run Cache_OnGetDefinition"(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var Found: Boolean)
    var
        Offset: Integer;
    begin
        if Found then
            exit;
        this.EnsureFilled();
        if not this.Offsets.Get(ProviderType.AsInteger(), Offset) then
            exit;
        TempConfigurationLine.Reset();
        TempConfigurationLine.DeleteAll(false);
        this.TempCachedLine.SetRange("Entry No.", Offset, Offset + this.BlockSize() - 1);
        if this.TempCachedLine.FindSet() then
            repeat
                TempConfigurationLine := this.TempCachedLine;
                TempConfigurationLine.Validate("Entry No.", this.TempCachedLine."Entry No." - Offset);
                TempConfigurationLine.Insert(false);
            until this.TempCachedLine.Next() = 0;
        TempConfigurationProperty.Reset();
        TempConfigurationProperty.DeleteAll(false);
        this.TempCachedProperty.SetRange("Entry No.", Offset, Offset + this.BlockSize() - 1);
        if this.TempCachedProperty.FindSet() then
            repeat
                TempConfigurationProperty := this.TempCachedProperty;
                TempConfigurationProperty.Validate("Entry No.", this.TempCachedProperty."Entry No." - Offset);
                TempConfigurationProperty.Insert(false);
            until this.TempCachedProperty.Next() = 0;
        Found := true;
    end;

    var
        TempCachedProvider: Record "BJF MN Provider Buffer" temporary;
        TempCachedLine: Record "BJF MN Config Line" temporary;
        TempCachedProperty: Record "BJF MN Config Property" temporary;
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        Offsets: Dictionary of [Integer, Integer];
        Filled: Boolean;
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// What every configuration check shares: the registered providers and their rebuilt
/// definitions, the profiles to check against, and the fix-context format a check and its
/// ApplyFix agree on. Checks compare declared intent with live data; they never apply.
/// </summary>
codeunit 77799 "BJF MN Doctor Support"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Profile Setup" = r;

    /// <summary>Every registered provider, taken from the Doctor run cache while a run binds one.</summary>
    /// <param name="TempProvider">Receives one row per provider.</param>
    procedure ListProviders(var TempProvider: Record "BJF MN Provider Buffer" temporary)
    begin
        if not this.DoctorRunCache.TryGetProviders(TempProvider) then
            this.ProviderCatalog.Populate(TempProvider);
        TempProvider.Reset();
    end;

    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
    begin
        this.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
    end;

    /// <summary>The provider's definition, taken from the Doctor run cache while a run binds one.</summary>
    /// <param name="ProviderType">The provider to build.</param>
    /// <param name="TempConfigurationLine">Receives the provider's lines.</param>
    /// <param name="TempConfigurationProperty">Receives the provider's properties.</param>
    procedure BuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    begin
        if not this.DoctorRunCache.TryGetDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty) then
            this.ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
        TempConfigurationLine.Reset();
        TempConfigurationProperty.Reset();
    end;

    /// <summary>The service name a page is registered under, remembered for the life of this instance.</summary>
    /// <param name="PageId">The page object ID.</param>
    /// <returns>The service name, or empty when the page is not registered.</returns>
    procedure GetServiceName(PageId: Integer): Text[100]
    var
        ServiceName: Text;
    begin
        if this.ServiceNames.Get(PageId, ServiceName) then
            exit(CopyStr(ServiceName, 1, 100));
        ServiceName := this.Lookup.GetServiceName(PageId);
        this.ServiceNames.Add(PageId, ServiceName);
        exit(CopyStr(ServiceName, 1, 100));
    end;

    /// <summary>The record ID of a service's Main row.</summary>
    /// <param name="ServiceName">The MobileNAV service name of the page.</param>
    /// <returns>The Main row's record ID, or the ID of a blank row when the service has none.</returns>
    procedure MainRowId(ServiceName: Text[100]): RecordId
    var
        MainRow: Record "MobileNAV Service Setup";
    begin
        if this.Lookup.FindMainRow(ServiceName, MainRow) then; // Without a main row the finding carries an empty record ID.
        exit(MainRow.RecordId());
    end;

    /// <summary>Every profile MobileNAV defines.</summary>
    /// <param name="Profiles">Receives the profile codes.</param>
    procedure ListProfiles(var Profiles: List of [Code[30]])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        MasterData.SetLoadFields(Code);
        MasterData.SetRange(Type, MasterData.Type::Profile);
        if MasterData.FindSet() then
            repeat
                Profiles.Add(MasterData.Code);
            until MasterData.Next() = 0;
    end;

    /// <summary>Every profile that has at least one user, which is where field rows are written.</summary>
    /// <param name="Profiles">Receives the profile codes, each once.</param>
    procedure ListFieldProfiles(var Profiles: List of [Code[30]])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        ProfileSetup.SetLoadFields(Profile);
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        if ProfileSetup.FindSet() then
            repeat
                if not Profiles.Contains(ProfileSetup.Profile) then
                    Profiles.Add(ProfileSetup.Profile);
            until ProfileSetup.Next() = 0;
    end;

    /// <summary>Packs a fix's kind and arguments into a finding's Fix Context.</summary>
    /// <param name="Kind">The fix kind token the check's ApplyFix reads.</param>
    /// <param name="Args">The fix arguments.</param>
    /// <returns>The packed Fix Context text.</returns>
    procedure PackFix(Kind: Text; Args: List of [Text]): Text
    var
        Packed: TextBuilder;
        Arg: Text;
    begin
        Packed.Append(Kind);
        foreach Arg in Args do begin
            Packed.Append(this.FixSeparatorTok);
            Packed.Append(Arg);
        end;
        exit(Packed.ToText());
    end;

    procedure UnpackFix(FixContext: Text; var Kind: Text; var Args: List of [Text])
    var
        Parts: List of [Text];
    begin
        Parts := FixContext.Split(this.FixSeparatorTok);
        Kind := Parts.Get(1);
        Parts.RemoveAt(1);
        Args := Parts;
    end;

    /// <summary>
    /// Adds a finding about one provider, with a fix whose arguments start with the provider's
    /// ordinal. ReadProviderFix reads the fix back.
    /// </summary>
    /// <param name="Finding">Receives the finding.</param>
    /// <param name="CheckType">The check that produced the finding.</param>
    /// <param name="FindingSeverity">How serious the finding is.</param>
    /// <param name="TempProvider">The provider the finding concerns.</param>
    /// <param name="Message">The finding text, without the provider prefix.</param>
    /// <param name="RelatedRecordId">The record the finding is about.</param>
    /// <param name="FixDescription">What the Apply Fix action will do.</param>
    /// <param name="FixKind">The fix kind token the check's ApplyFix reads.</param>
    /// <param name="Args">The fix arguments that follow the provider ordinal.</param>
    procedure AddProviderFinding(var Finding: Record "BJF Diagnostic Finding"; CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; TempProvider: Record "BJF MN Provider Buffer" temporary; Message: Text; RelatedRecordId: RecordId; FixDescription: Text; FixKind: Text; Args: List of [Text])
    var
        FixArgs: List of [Text];
    begin
        FixArgs.Add(Format(TempProvider.Provider.AsInteger(), 0, 9));
        FixArgs.AddRange(Args);
        Finding.AddWithFix(CheckType, FindingSeverity, this.Prefix(TempProvider, Message), RelatedRecordId, FixDescription, this.PackFix(FixKind, FixArgs));
    end;

    /// <summary>Reads a fix added by AddProviderFinding and builds the provider's definition.</summary>
    /// <param name="Finding">The finding to fix.</param>
    /// <param name="ExpectedKind">The only fix kind the caller handles, or empty to accept any.</param>
    /// <param name="Kind">Receives the fix kind.</param>
    /// <param name="Args">Receives the fix arguments that follow the provider ordinal.</param>
    /// <param name="TempConfigurationLine">Receives the provider's lines.</param>
    procedure ReadProviderFix(Finding: Record "BJF Diagnostic Finding"; ExpectedKind: Text; var Kind: Text; var Args: List of [Text]; var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
    begin
        this.ReadProviderFix(Finding, ExpectedKind, Kind, Args, TempConfigurationLine, TempConfigurationProperty);
    end;

    /// <summary>
    /// Reads a fix added by AddProviderFinding and builds the provider's definition. The build
    /// skips the Doctor run cache, so the fix works from the current declaration.
    /// </summary>
    /// <param name="Finding">The finding to fix.</param>
    /// <param name="ExpectedKind">The only fix kind the caller handles, or empty to accept any.</param>
    /// <param name="Kind">Receives the fix kind.</param>
    /// <param name="Args">Receives the fix arguments that follow the provider ordinal.</param>
    /// <param name="TempConfigurationLine">Receives the provider's lines.</param>
    /// <param name="TempConfigurationProperty">Receives the provider's properties.</param>
    procedure ReadProviderFix(Finding: Record "BJF Diagnostic Finding"; ExpectedKind: Text; var Kind: Text; var Args: List of [Text]; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    var
        Ordinal: Integer;
    begin
        this.UnpackFix(Finding."Fix Context", Kind, Args);
        if (ExpectedKind <> '') and (Kind <> ExpectedKind) then
            Error(this.NoAutomaticFixErr);
        Evaluate(Ordinal, Args.Get(1));
        Args.RemoveAt(1);
        this.ProviderCatalog.BuildDefinition(Enum::"BJF MN Config Provider".FromInteger(Ordinal), TempConfigurationLine, TempConfigurationProperty);
        TempConfigurationLine.Reset();
        TempConfigurationProperty.Reset();
    end;

    /// <summary>Joins three parts of a row signature.</summary>
    /// <param name="First">The first part.</param>
    /// <param name="Second">The second part.</param>
    /// <param name="Third">The third part.</param>
    /// <returns>The parts, separated by the signature separator.</returns>
    procedure Signature(First: Text; Second: Text; Third: Text): Text
    begin
        exit(First + this.FixSeparatorTok + Second + this.FixSeparatorTok + Third);
    end;

    /// <summary>Joins five parts of a row signature.</summary>
    /// <param name="First">The first part.</param>
    /// <param name="Second">The second part.</param>
    /// <param name="Third">The third part.</param>
    /// <param name="Fourth">The fourth part.</param>
    /// <param name="Fifth">The fifth part.</param>
    /// <returns>The parts, separated by the signature separator.</returns>
    procedure Signature(First: Text; Second: Text; Third: Text; Fourth: Text; Fifth: Text): Text
    begin
        exit(this.Signature(First, Second, Third) + this.FixSeparatorTok + Fourth + this.FixSeparatorTok + Fifth);
    end;

    /// <summary>Compares the declared rows of one kind with the live rows: the count first, then each row in order.</summary>
    /// <param name="KindName">The row kind, as the finding names it.</param>
    /// <param name="Expected">The declared row signatures.</param>
    /// <param name="Live">The live row signatures.</param>
    /// <returns>A description of the first difference, or empty when the rows match.</returns>
    procedure FirstDifference(KindName: Text; Expected: List of [Text]; Live: List of [Text]): Text
    var
        Index: Integer;
    begin
        if Live.Count() <> Expected.Count() then
            exit(this.CountDifference(KindName, Expected.Count(), Live.Count()));
        for Index := 1 to Expected.Count() do
            if Live.Get(Index) <> Expected.Get(Index) then
                exit(StrSubstNo(this.RowLbl, KindName, Index));
        exit('');
    end;

    /// <summary>Compares the declared and the live number of rows of one kind.</summary>
    /// <param name="KindName">The row kind, as the finding names it.</param>
    /// <param name="ExpectedCount">The number of rows declared.</param>
    /// <param name="LiveCount">The number of rows found.</param>
    /// <returns>A description of the difference, or empty when the counts match.</returns>
    procedure CountDifference(KindName: Text; ExpectedCount: Integer; LiveCount: Integer): Text
    begin
        if LiveCount = ExpectedCount then
            exit('');
        exit(StrSubstNo(this.CountLbl, KindName, ExpectedCount, LiveCount));
    end;

    /// <summary>Prefixes a finding with the provider it concerns.</summary>
    /// <param name="TempProvider">The provider the finding concerns.</param>
    /// <param name="Message">The finding text.</param>
    /// <returns>The finding text prefixed with the provider name.</returns>
    procedure Prefix(TempProvider: Record "BJF MN Provider Buffer" temporary; Message: Text): Text
    begin
        exit(StrSubstNo(this.PrefixedMsg, TempProvider.Name, Message));
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        DoctorRunCache: Codeunit "BJF MN Doctor Run Cache";
        Lookup: Codeunit "BJF MN Service Lookup";
        ServiceNames: Dictionary of [Integer, Text];
        PrefixedMsg: Label '[%1] %2', Comment = '%1 = provider name, %2 = finding', Locked = true;
        CountLbl: Label '%1: %2 declared, %3 found.', Comment = '%1 = row kind, %2 = declared count, %3 = live count';
        RowLbl: Label '%1: row %2 differs.', Comment = '%1 = row kind, %2 = row position';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        FixSeparatorTok: Label '|', Locked = true;
}

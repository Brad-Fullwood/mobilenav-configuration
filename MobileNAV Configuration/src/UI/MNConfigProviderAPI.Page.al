namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063, LC0092 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// Registered configuration providers with their applied state, for scripts and agents:
/// GET lists them; bound actions apply a provider, mark it outdated, and run the Doctor.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/configProviders('{providerId}').
/// </summary>
page 77790 "BJF MN Config Provider API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Configuration Provider';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Configuration Provider';
    EntityName = 'configProvider';
    EntitySetCaption = 'MobileNAV Configuration Providers';
    EntitySetName = 'configProviders';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = "Provider ID";
    PageType = API;
    SourceTable = "BJF MN Provider Buffer";
    SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Providers)
            {
                field(providerId; Rec."Provider ID") { }
                field(name; Rec.Name) { }
                field(description; Rec.Description) { }
                field(state; Rec.State) { }
                field(appliedPreviously; Rec."Applied Previously") { }
                field(appliedAt; Rec."Applied At") { }
                field(appliedBy; Rec."Applied By") { }
                field(definedHash; Rec."Defined Hash") { }
                field(appliedHash; Rec."Applied Hash") { }
            }
        }
    }

    trigger OnFindRecord(Which: Text): Boolean
    begin
        if not this.Populated then
            this.Populate();
        exit(Rec.Find(Which));
    end;

    /// <summary>Applies this provider's declaration to MobileNAV, the same as Apply selected on the providers page.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure apply(var ActionContext: WebServiceActionContext)
    var
        ConfigurationApplication: Codeunit "BJF MN Config Application";
    begin
        ConfigurationApplication.ApplyProvider(Rec.Provider, true);
        this.RefreshRow();
        this.SetResult(ActionContext);
    end;

    /// <summary>Marks this provider outdated so the next apply rebuilds it in full.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure markOutdated(var ActionContext: WebServiceActionContext)
    var
        ConfigurationStatus: Record "BJF MN Config Status";
    begin
        ConfigurationStatus.MarkOutdated(Rec."Provider ID");
        this.RefreshRow();
        this.SetResult(ActionContext);
    end;

    /// <summary>
    /// Shows what applying this provider would change, without changing it: the apply runs and
    /// is rolled back. Read the result from configPreviewLines filtered on the provider id.
    /// </summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure preview(var ActionContext: WebServiceActionContext)
    var
        ConfigurationPreview: Codeunit "BJF MN Config Preview";
    begin
        ConfigurationPreview.Preview(Rec.Provider);
        this.RefreshRow();
        this.SetResult(ActionContext);
    end;

    /// <summary>Runs the configuration checks for every provider; read the results from diagnosticFindings.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure runConfigChecks(var ActionContext: WebServiceActionContext)
    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
    begin
        DiagnosticsRunner.Run(DiagnosticsRunner.ConfigCheckTypes());
        this.SetResult(ActionContext);
    end;

    /// <summary>Runs every diagnostic, including the general MobileNAV checks and those other apps contribute.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure runAllDiagnostics(var ActionContext: WebServiceActionContext)
    var
        DiagnosticsRunner: Codeunit "BJF Diagnostics Runner";
    begin
        DiagnosticsRunner.RunAll();
        this.SetResult(ActionContext);
    end;

    /// <summary>
    /// Fills the buffer while keeping the key and filters the request located, so a bound action
    /// acts on the provider in the URL rather than on the last row inserted.
    /// </summary>
    local procedure Populate()
    var
        LocatedProviderId: Code[50];
        View: Text;
    begin
        LocatedProviderId := Rec."Provider ID";
        View := Rec.GetView();
        this.ProviderCatalog.Populate(Rec);
        Rec.SetView(View);
        Rec.Validate("Provider ID", LocatedProviderId);
        this.Populated := true;
    end;

    /// <summary>Rebuilds the located row after an action, the way Populate builds each row, without rebuilding the other providers.</summary>
    local procedure RefreshRow()
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        ConfigurationStatus: Record "BJF MN Config Status";
        ConfigurationHash: Codeunit "BJF MN Config Hash";
        DeclaredProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
    begin
        this.ProviderCatalog.GetMetadata(Rec.Provider, DeclaredProviderId, ProviderName, ProviderDescription);
        this.ProviderCatalog.BuildDefinition(Rec.Provider, TempConfigurationLine, TempConfigurationProperty);
        Rec.Validate(Name, ProviderName);
        Rec.Validate(Description, ProviderDescription);
        Rec.Validate("Defined Hash", ConfigurationHash.Compute(TempConfigurationLine, TempConfigurationProperty));
        Rec.Validate("Applied Previously", false);
        Rec.Validate("Applied Hash", '');
        Rec.Validate("Applied At", 0DT);
        Rec.Validate("Applied By", '');
        ConfigurationStatus.PopulateState(Rec);
        Rec.Modify(false);
    end;

    local procedure SetResult(var ActionContext: WebServiceActionContext)
    begin
        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"BJF MN Config Provider API");
        ActionContext.AddEntityKey(Rec.FieldNo("Provider ID"), Rec."Provider ID");
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        Populated: Boolean;
}

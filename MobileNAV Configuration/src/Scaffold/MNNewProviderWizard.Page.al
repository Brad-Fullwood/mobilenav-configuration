namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// Writes a new MobileNAV Configuration provider for a customer app. The user gives the app's
/// details, picks MobileNAV pages, the fields on each page and the device buttons, and Finish
/// downloads a zip file with the provider, enum extension, page extensions, handler, install
/// codeunit, permission set, app.json dependencies and a README.txt.
/// </summary>
page 77721 "BJF MN New Provider Wizard"
{
    ApplicationArea = All;
    Caption = 'New MobileNAV Provider';
    PageType = NavigatePage;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(StepAppDetails)
            {
                Caption = 'App details';
                Visible = this.Step = 1;
                InstructionalText = 'Describe the app that receives the provider. The prefix starts every object name and every new control name.';

                field(Prefix; this.Prefix)
                {
                    Caption = 'Prefix';
                    ShowMandatory = true;
                    ToolTip = 'Specifies the object name prefix, such as ABC. Object names become ABC MN Provider, ABC MN Handler and so on, and new controls are named ABC followed by the field name or button caption.';

                    trigger OnValidate()
                    begin
                        if this.ProviderId = '' then
                            this.ProviderId := CopyStr(this.ScaffoldWriter.DefaultProviderId(this.Prefix), 1, MaxStrLen(this.ProviderId));
                    end;
                }
                field(Publisher; this.Publisher)
                {
                    Caption = 'Publisher';
                    ToolTip = 'Specifies the publisher in the app''s app.json.';

                    trigger OnValidate()
                    begin
                        this.SuggestNamespace();
                    end;
                }
                field(AppName; this.AppName)
                {
                    Caption = 'App name';
                    ShowMandatory = true;
                    ToolTip = 'Specifies the name in the app''s app.json.';

                    trigger OnValidate()
                    begin
                        this.SuggestNamespace();
                        if this.ProviderName = '' then
                            this.ProviderName := this.AppName;
                    end;
                }
                field(Namespace; this.Namespace)
                {
                    Caption = 'Namespace';
                    ToolTip = 'Specifies the namespace of the generated files. Use the namespace the app''s other files declare.';
                }
                field(FirstObjectId; this.FirstObjectId)
                {
                    Caption = 'First object ID';
                    MinValue = 1;
                    ShowMandatory = true;
                    ToolTip = 'Specifies the first free object ID in the app''s ID range. Each object type counts up from it. README.txt lists which object gets which ID.';
                }
                field(ProviderId; this.ProviderId)
                {
                    Caption = 'Provider ID';
                    ToolTip = 'Specifies the stable ID the framework records the provider''s state under. The default is the prefix in upper case.';
                }
                field(ProviderName; this.ProviderName)
                {
                    Caption = 'Provider name';
                    ToolTip = 'Specifies the name the MobileNAV Configuration page shows for the provider. The default is the app name.';
                }
                field(ProviderDescription; this.ProviderDescription)
                {
                    Caption = 'Description';
                    MultiLine = true;
                    ToolTip = 'Specifies what the provider configures. The default is Device configuration for, followed by the app name.';
                }
            }
            group(StepPages)
            {
                Caption = 'MobileNAV pages';
                Visible = this.Step = 2;
                InstructionalText = 'Select the MobileNAV pages this provider extends. Each page gets a page extension. Check the group its controls are added to: most pages call their first group Group, some call it General.';

                part(PagesPart; "BJF MN Scaffold Pages Part")
                {
                }
            }
            group(StepFields)
            {
                Caption = 'Fields';
                Visible = this.Step = 3;
                InstructionalText = 'Select the fields the device shows on each page. A field that is not on the page yet gets a control in the page extension.';

                field(ShownPage; this.ShownPageName)
                {
                    Caption = 'Page';
                    Editable = false;
                    ToolTip = 'Specifies the page whose fields are listed. Choose the assist button to show another selected page.';

                    trigger OnAssistEdit()
                    begin
                        this.ChooseShownPage();
                    end;
                }
                part(FieldsPart; "BJF MN Field Pick Part")
                {
                }
            }
            group(StepButtons)
            {
                Caption = 'Buttons';
                Visible = this.Step = 4;
                InstructionalText = 'Add the device buttons. Each button gets a placeholder control in the page extension and a procedure in the handler codeunit that shows a toast until you replace it with the work.';

                part(ButtonsPart; "BJF MN Button Pick Part")
                {
                }
            }
            group(StepFinish)
            {
                Caption = 'Finish';
                Visible = this.Step = 5;
                InstructionalText = 'Choose Finish to download a zip file with the provider files. README.txt in the zip file lists the steps to add them to the app.';

                field(Summary; this.SummaryText)
                {
                    Caption = 'Files';
                    Editable = false;
                    MultiLine = true;
                    ShowCaption = false;
                    ToolTip = 'Specifies the files the zip file holds.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionBack)
            {
                ApplicationArea = All;
                Caption = 'Back';
                Enabled = this.Step > 1;
                Image = PreviousRecord;
                InFooterBar = true;
                ToolTip = 'Goes to the previous step.';

                trigger OnAction()
                begin
                    this.Step -= 1;
                end;
            }
            action(ActionNext)
            {
                ApplicationArea = All;
                Caption = 'Next';
                Enabled = this.Step < 5;
                Image = NextRecord;
                InFooterBar = true;
                ToolTip = 'Goes to the next step.';

                trigger OnAction()
                begin
                    this.NextStep();
                end;
            }
            action(ActionFinish)
            {
                ApplicationArea = All;
                Caption = 'Finish';
                Enabled = this.Step = 5;
                Image = Approve;
                InFooterBar = true;
                ToolTip = 'Downloads the zip file with the provider files.';

                trigger OnAction()
                begin
                    this.Finish();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.Step := 1;
        this.FirstObjectId := 50100;
        this.ScaffoldWriter.LoadMobileNAVPages(this.TempScaffoldPage);
        CurrPage.PagesPart.Page.SetPages(this.TempScaffoldPage);
        CurrPage.FieldsPart.Page.SetRows(this.TempFieldPick);
        this.ApplySelectedProvider();
    end;

    /// <summary>
    /// Sets the provider the wizard takes its defaults from. Call it before RunModal: the defaults are filled in
    /// when the page opens.
    /// </summary>
    /// <param name="Provider">The provider selected on MobileNAV Configuration. None keeps the wizard's own defaults.</param>
    procedure SetSelectedProvider(Provider: Enum "BJF MN Config Provider")
    begin
        this.SelectedProvider := Provider;
    end;

    /// <summary>
    /// Fills the app and provider defaults from the selected provider. The first object ID goes after the
    /// provider's app's last object and leaves room for every page extension plus the provider, enum extension,
    /// install, handler and permission set objects.
    /// </summary>
    local procedure ApplySelectedProvider()
    var
        ProviderDefaults: Codeunit "BJF MN Provider Defaults";
        PackageId: Guid;
    begin
        if not ProviderDefaults.ReadProvider(this.SelectedProvider, this.ProviderId, this.ProviderName, this.ProviderDescription, this.Prefix, this.Publisher, this.AppName, PackageId) then
            exit;
        this.FirstObjectId := ProviderDefaults.FirstFreeObjectId(PackageId, this.TempScaffoldPage.Count() + 5);
        this.SuggestNamespace();
    end;

    local procedure NextStep()
    begin
        case this.Step of
            1:
                this.CheckAppDetails();
            2:
                this.PrepareFields();
            3:
                CurrPage.ButtonsPart.Page.SetRows(this.TempFieldPick, this.TempScaffoldPage, this.Prefix);
            4:
                this.PrepareSummary();
        end;
        this.Step += 1;
    end;

    local procedure CheckAppDetails()
    begin
        if this.Prefix = '' then
            Error(this.PrefixRequiredErr);
        if this.AppName = '' then
            Error(this.AppNameRequiredErr);
        if this.FirstObjectId <= 0 then
            Error(this.FirstObjectIdRequiredErr);
        if this.Namespace = '' then
            this.SuggestNamespace();
    end;

    local procedure PrepareFields()
    begin
        this.TempScaffoldPage.Reset();
        this.TempScaffoldPage.SetRange(Selected, true);
        if this.TempScaffoldPage.IsEmpty() then
            Error(this.PageRequiredErr);
        this.TempScaffoldPage.Reset();
        this.ScaffoldWriter.SetAppDetails(this.Prefix, this.Namespace, this.Publisher, this.AppName, this.FirstObjectId);
        this.ScaffoldWriter.LoadFieldPicks(this.TempScaffoldPage, this.TempFieldPick);
        this.TempScaffoldPage.SetCurrentKey(Selected, "Page Name");
        this.TempScaffoldPage.SetRange(Selected, true);
        if this.TempScaffoldPage.FindFirst() then
            this.ShowPage(this.TempScaffoldPage);
        this.TempScaffoldPage.Reset();
    end;

    local procedure ChooseShownPage()
    var
        PageNames: List of [Text];
        PageIds: List of [Integer];
        Menu: Text;
        Choice: Integer;
    begin
        this.TempScaffoldPage.Reset();
        this.TempScaffoldPage.SetCurrentKey(Selected, "Page Name");
        this.TempScaffoldPage.SetRange(Selected, true);
        if this.TempScaffoldPage.FindSet() then
            repeat
                PageNames.Add(this.TempScaffoldPage."Page Name");
                PageIds.Add(this.TempScaffoldPage."Page ID");
                if Menu <> '' then
                    Menu += ',';
                Menu += this.TempScaffoldPage."Page Name";
            until this.TempScaffoldPage.Next() = 0;
        this.TempScaffoldPage.Reset();
        Choice := StrMenu(Menu);
        if Choice = 0 then
            exit;
        if this.TempScaffoldPage.Get(PageIds.Get(Choice)) then
            this.ShowPage(this.TempScaffoldPage);
    end;

    local procedure ShowPage(ScaffoldPage: Record "BJF MN Scaffold Page" temporary)
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        AllObjWithCaption.SetLoadFields("Object Caption");
        this.ShownPageName := ScaffoldPage."Page Name";
        if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Page, ScaffoldPage."Page ID") then
            if AllObjWithCaption."Object Caption" <> '' then
                this.ShownPageName := AllObjWithCaption."Object Caption";
        CurrPage.FieldsPart.Page.ShowPage(ScaffoldPage."Page ID");
    end;

    local procedure PrepareSummary()
    var
        FilePaths: List of [Text];
        FileTexts: List of [Text];
        FilePath: Text;
    begin
        this.SetWriterInput();
        this.ScaffoldWriter.Render(this.TempScaffoldPage, this.TempFieldPick, FilePaths, FileTexts);
        this.SummaryText := '';
        foreach FilePath in FilePaths do
            this.SummaryText += FilePath + this.TypeHelper.LFSeparator();
    end;

    local procedure Finish()
    begin
        this.SetWriterInput();
        this.ScaffoldWriter.CheckNewControlNames(this.TempScaffoldPage, this.TempFieldPick);
        this.ScaffoldWriter.DownloadZip(this.TempScaffoldPage, this.TempFieldPick);
        CurrPage.Close();
    end;

    local procedure SetWriterInput()
    begin
        this.ScaffoldWriter.SetAppDetails(this.Prefix, this.Namespace, this.Publisher, this.AppName, this.FirstObjectId);
        this.ScaffoldWriter.SetProvider(this.ProviderId, this.ProviderName, this.ProviderDescription);
    end;

    local procedure SuggestNamespace()
    begin
        if (this.Namespace = '') or (this.Namespace = this.SuggestedNamespace) then begin
            this.SuggestedNamespace := CopyStr(this.ScaffoldWriter.DefaultNamespace(this.Publisher, this.AppName), 1, MaxStrLen(this.SuggestedNamespace));
            this.Namespace := this.SuggestedNamespace;
        end;
    end;

    var
        TempScaffoldPage: Record "BJF MN Scaffold Page" temporary;
        TempFieldPick: Record "BJF MN Field Pick" temporary;
        ScaffoldWriter: Codeunit "BJF MN Scaffold Writer";
        TypeHelper: Codeunit "Type Helper";
        Step: Integer;
        Prefix: Text[20];
        Publisher: Text[100];
        AppName: Text[100];
        Namespace: Text[250];
        SuggestedNamespace: Text[250];
        FirstObjectId: Integer;
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ShownPageName: Text[250];
        SummaryText: Text;
        SelectedProvider: Enum "BJF MN Config Provider";
        PrefixRequiredErr: Label 'Enter a prefix.';
        AppNameRequiredErr: Label 'Enter the app name.';
        FirstObjectIdRequiredErr: Label 'Enter the first object ID.';
        PageRequiredErr: Label 'Select at least one MobileNAV page.';
}

namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Lists all registered providers, their application state, and actions to apply or
/// deliberately invalidate selected providers.
/// </summary>
page 77780 "BJF Custom MN Config"
{
    ApplicationArea = All;
    Caption = 'Apply custom MobileNAV config';
    PageType = List;
    SourceTable = "BJF MN Provider Buffer";
    SourceTableTemporary = true;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Providers)
            {
                field(Selected; Rec.Selected)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this provider is included in the next action.';
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the provider name.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Describes the configuration owned by this provider.';
                }
                field(State; Rec.State)
                {
                    ApplicationArea = All;
                    Editable = false;
                    StyleExpr = StateStyle;
                    ToolTip = 'Specifies whether the provider has never been applied, is current, or is outdated.';
                }
                field("Applied Previously"; Rec."Applied Previously")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies whether this provider has been applied successfully before.';
                }
                field("Defined Version"; Rec."Defined Version")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the version currently declared by the provider.';
                }
                field("Applied Version"; Rec."Applied Version")
                {
                    ApplicationArea = All;
                    Editable = false;
                    BlankZero = true;
                    ToolTip = 'Specifies the last successfully applied provider version.';
                }
                field("Applied At"; Rec."Applied At")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies when the provider was last applied successfully.';
                }
                field("Applied By"; Rec."Applied By")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies who last applied the provider.';
                }
                field("Provider ID"; Rec."Provider ID")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies the stable identifier used for application tracking.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ApplySelected)
            {
                ApplicationArea = All;
                Caption = 'Apply selected';
                Image = Apply;
                ToolTip = 'Validates and applies each selected MobileNAV configuration provider.';

                trigger OnAction()
                begin
                    ApplySelectedProviders();
                end;
            }
            action(MarkSelectedOutdated)
            {
                ApplicationArea = All;
                Caption = 'Mark selected outdated';
                Image = ChangeStatus;
                ToolTip = 'Marks previously applied providers as outdated without changing their MobileNAV configuration.';

                trigger OnAction()
                begin
                    MarkSelectedProvidersOutdated();
                end;
            }
            action(SelectAll)
            {
                ApplicationArea = All;
                Caption = 'Select all';
                Image = SelectEntries;
                ToolTip = 'Selects all registered providers.';

                trigger OnAction()
                begin
                    SetSelection(true);
                end;
            }
            action(ClearSelection)
            {
                ApplicationArea = All;
                Caption = 'Clear selection';
                Image = ClearFilter;
                ToolTip = 'Clears the provider selection.';

                trigger OnAction()
                begin
                    SetSelection(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ApplySelected_Promoted; ApplySelected)
                {
                }
                actionref(MarkSelectedOutdated_Promoted; MarkSelectedOutdated)
                {
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.State of
            Enum::"BJF MN Config State"::Applied:
                StateStyle := 'Favorable';
            Enum::"BJF MN Config State"::Outdated:
                StateStyle := 'Ambiguous';
            else
                StateStyle := 'Attention';
        end;
    end;

    trigger OnOpenPage()
    begin
        ReloadProviders();
    end;

    local procedure ApplySelectedProviders()
    var
        AppliedCount: Integer;
    begin
        Rec.SetRange(Selected, true);
        if Rec.FindSet() then
            repeat
                ConfigurationApplication.ApplyProvider(Rec.Provider);
                AppliedCount += 1;
            until Rec.Next() = 0;
        Rec.Reset();

        if AppliedCount = 0 then
            Error(SelectionRequiredErr);

        ReloadProviders();
        CurrPage.Update(false);
        Message(AppliedMsg, AppliedCount);
    end;

    local procedure MarkSelectedProvidersOutdated()
    var
        OutdatedCount: Integer;
    begin
        Rec.SetRange(Selected, true);
        Rec.SetRange("Applied Previously", true);
        if Rec.FindSet() then
            repeat
                StatusManagement.MarkOutdated(Rec."Provider ID");
                OutdatedCount += 1;
            until Rec.Next() = 0;
        Rec.Reset();

        if OutdatedCount = 0 then
            Error(AppliedSelectionRequiredErr);

        ReloadProviders();
        CurrPage.Update(false);
    end;

    local procedure SetSelection(NewValue: Boolean)
    begin
        Rec.Reset();
        if Rec.FindSet() then
            repeat
                Rec.Selected := NewValue;
                Rec.Modify();
            until Rec.Next() = 0;
        CurrPage.Update(false);
    end;

    local procedure ReloadProviders()
    begin
        ProviderCatalog.Populate(Rec);
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        StatusManagement: Codeunit "BJF MN Config Status Mgt.";
        StateStyle: Text;
        SelectionRequiredErr: Label 'Select at least one configuration provider.';
        AppliedSelectionRequiredErr: Label 'Select at least one provider that has been applied previously.';
        AppliedMsg: Label '%1 MobileNAV configuration provider(s) were applied.', Comment = '%1 = number of providers';
}

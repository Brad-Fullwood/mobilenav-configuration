namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's page configuration rows (pages, fields, relations, filters, stages), read-only, so
/// a device page's configuration can be inspected per company without the administration pages.
/// Filter on serviceName and lineType; a field row has lineType Field. The page and control
/// settings the builder writes are here too, so mnconfig.py reverse can restate a page in code.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/serviceSetupLines.
/// </summary>
page 77793 "BJF MN Service Setup API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Service Setup Line';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Service Setup Line';
    EntityName = 'serviceSetupLine';
    EntitySetCaption = 'MobileNAV Service Setup Lines';
    EntitySetName = 'serviceSetupLines';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Service Setup" = r;
    SourceTable = "MobileNAV Service Setup";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(serviceName; Rec."Service Name") { }
                field(objectType; Rec."Object Type") { }
                field(objectId; Rec."Object ID") { }
                field(tableNo; Rec."Table No.") { }
                field(pageType; Rec."Page Type") { }
                field(lineType; Rec."Line Type") { }
                field(pageLineNo; Rec."Page Line No.") { }
                field(relationNo; Rec."Relation No.") { }
                field(lineNo; Rec."Line No.") { }
                field(controlId; Rec.ControlID) { }
                field(name; Rec.Name) { }
                field(fieldName; Rec.FieldName) { }
                field(fieldNo; Rec."Field No.") { }
                field(fieldType; Rec.FieldType) { }
                field(mobileType; Rec.MobileType) { }
                field(fieldCategory; Rec."Field Category") { }
                field(visible; Rec.Visible) { }
                field(editable; Rec.Editable) { }
                field(displayInMenu; Rec.DisplayInMenu) { }
                field(importance; Rec.Mandatory) { }
                field(category; Rec.Category) { }
                field(order; Rec."Order") { }
                field(validationBehavior; Rec."Validation Behavior") { }
                field(enableStaging; Rec."Enable Staging") { }
                field(stage; Rec.Stage) { }
                field(regExText; Rec.RegExText) { }
                field(regExResults; Rec.RegExResults) { }
                field(regExInherited; Rec."RegEx Inherited") { }
                field(functionName; Rec."Function Name") { }
                field(functionType; Rec."Function Type") { }
                field(pageInsert; Rec."Page Insert") { }
                field(pageUpdate; Rec."Page Update") { }
                field(pageDelete; Rec."Page Delete") { }
                field(quickEditAction; Rec."Quick Edit/Action") { }
                field(dynamicReadOnly; Rec."Dynamic ReadOnly") { }
                field(relatedPageName; Rec.RelatedPageName) { }
                field(relatedPageType; Rec."Related PageType") { }
                field(relatedTableNo; Rec."Related Table No.") { }
                field(relatedCodeFieldName; Rec.RelatedPgCodeFldName) { }
                field(relatedDescriptionFieldName; Rec.RelatedPgDescFldName) { }
                field(filterType; Rec.FilterType) { }
                field(filterComparisonType; Rec."Filter Comparsion Type") { }
                field(sourceFieldName; Rec.SourceFieldName) { }
                field(destFieldName; Rec.DestFieldName) { }
                field(filterValue; Rec.FilterValue) { }
                field(fieldClass; Rec.FieldClass) { }
                field(tableFieldName; this.TableFieldName) { }
                field(visibleAsFilter; Rec."Visible as Filter") { }
                field(mainMenuAction; Rec."Main Menu Action") { }
                field(reportServiceName; Rec.OptionValues2) { }
                field(functionCodeunitName; this.FunctionCodeunitName) { }
                field(companionCodeunitName; this.CompanionCodeunitName) { }
                field(checkForChangesPeriod; Rec."Check for Changes Period") { }
                field(defaultDrillDown; Rec."Default DrillDown") { }
                field(onOpenFunctionName; Rec."OnOpen Function Name") { }
                field(onCloseFunctionName; Rec."OnClose Function Name") { }
                field(hidePrefixNew; Rec.HidePrefixNew) { }
                field(hidePrefixPageNameOnCard; Rec.HidePrefixPageNameOnCard) { }
                field(hidePrefixParentOnDrillDown; Rec.HidePrefixParentOnDrillDown) { }
                field(showFilterPanel; Rec.ShowFilterPanelAutomatically) { }
                field(hideButtonCardRefresh; Rec.HideBtnCardRefresh) { }
                field(hideButtonCardHideFields; Rec.HideBtnCardHideFields) { }
                field(hideButtonCardFlowFilters; Rec.HideBtnCardFlowFilters) { }
                field(hideButtonCardNavigate; Rec.HideBtnCardNavigate) { }
                field(hideButtonListSort; Rec.HideBtnListSort) { }
                field(hideButtonListRefresh; Rec.HideBtnListRefresh) { }
                field(hideButtonListFilter; Rec.HideBtnListFilter) { }
                field(hideButtonListFlowFilters; Rec.HideBtnListFlowFilters) { }
                field(hideButtonListFullScreen; Rec."Hide List Full Screen") { }
                field(hideButtonListMultiSelect; Rec."Hide List Multi-Select") { }
                field(hideButtonListHideFilters; Rec."Hide List Hide Filters") { }
                field(hideLongerToolbarCaption; Rec."Hide Longer Toolbar Caption") { }
                field(autoRefreshOnOpen; Rec.AutoRefreshOnOpen) { }
                field(autoRefreshCardOnChildUpdate; Rec.AutoRefreshCardOnChildUpdate) { }
                field(autoRefreshListOnChildUpdate; Rec.AutoRefreshListOnChildUpdate) { }
                field(autoRefreshListOnUpdate; Rec.AutoRefreshListOnUpdate) { }
                field(autoOpenSingleRecord; Rec.AutoOpenSingleListItemOnOpen) { }
                field(showUnreadCount; Rec."Show Unread Record Count") { }
                field(mineFilterType; Rec."Mine Filter Type") { }
                field(cardAssignToMe; Rec."Card Assign to me") { }
                field(listAssignToMe; Rec."List Assign to me") { }
                field(pageStyle; Rec."Page Style") { }
                field(filterByParent; Rec."Filter By Parent Enabled") { }
                field(chunkSize; Rec."Chunk Size") { }
                field(listDisplayLimit; Rec."List Display Limit") { }
                field(autoNextStage; Rec."Auto Next Stage") { }
                field(backNextVisible; Rec."Back-Next Visible") { }
                field(stagingBehavior; Rec."Staging Behavior") { }
                field(stagingRestartFrom; Rec."Staging Restart From") { }
                field(menuPictureVersion; Rec."Menu Picture Version") { }
                field(decimalPlaces; Rec."Decimal Places") { }
                field(quantityIncrement; Rec."Quantity Increment") { }
                field(fieldToIncrease; Rec."Field to Increase") { }
                field(minValue; Rec."Min. Value Dec") { }
                field(maxValue; Rec."Max. Value Dec") { }
                field(promotedOnGroupHeader; Rec.PromotedOnGroupHeader) { }
                field(allowSkip; Rec."Allow Skip") { }
                field(hideCardDrillDown; Rec."Hide Card DrillDown") { }
                field(validateIfNotChanged; Rec."Validate if not Changed") { }
                field(multiSelect; Rec.MultiSelect) { }
                field(propagationType; Rec."Propagation Type") { }
                field(filterScope; Rec."Filter Scope") { }
                field(viewType; Rec."View Type") { }
                field(searchType; Rec."Search Type") { }
                field(ownFilterSet; Rec."Own Filter Set") { }
                field(operationType; Rec."Operation Type") { }
                field(optionValues; this.OptionValuesText) { }
                field(optionCaptions; this.OptionCaptionsText) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.FunctionCodeunitName := '';
        this.CompanionCodeunitName := '';
        this.TableFieldName := '';
        // The option values and captions the configuration build reads for the device.
        this.OptionValuesText := Rec.BuildOptionValues(true);
        this.OptionCaptionsText := Rec.BuildOptionCaptions(true);
        if Rec."Line Type" <> Rec."Line Type"::Main then begin
            // A flow filter is declared by its table field name, which the stored control name does not keep.
            if Rec.FieldClass = Rec.FieldClass::FlowFilter then
                this.TableFieldName := CopyStr(this.ServiceLookup.FieldNameOf(Rec."Table No.", Rec."Field No."), 1, MaxStrLen(this.TableFieldName));
            exit;
        end;
        if Rec.OptionValues2 <> '' then
            this.FunctionCodeunitName := CopyStr(this.ServiceLookup.CodeunitNameOfService(Rec.OptionValues2), 1, MaxStrLen(this.FunctionCodeunitName));
        this.CompanionCodeunitName := CopyStr(this.ServiceLookup.CodeunitNameOfService(Rec."Service Name"), 1, MaxStrLen(this.CompanionCodeunitName));
    end;

    var
        ServiceLookup: Codeunit "BJF MN Service Lookup";
        TableFieldName: Text[80];
        FunctionCodeunitName: Text[30];
        CompanionCodeunitName: Text[30];
        OptionValuesText: Text;
        OptionCaptionsText: Text;
}

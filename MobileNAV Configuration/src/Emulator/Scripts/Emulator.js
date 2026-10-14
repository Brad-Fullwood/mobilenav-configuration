// Draws MobileNAV device screens for the device emulator control: the main menu, lists with search,
// sort, saved filters and a filter panel, cards, drill-downs to related lists, and, when the emulator
// setup allows writes, card edits, scans, buttons and the device commands the page sends back.
// The page answers each request through window.Respond. Requests go out through the Request event.
// Every piece of data goes in with textContent, so a caption cannot inject markup.
// Everything sits in one function so that only Respond and ShowMessage become globals.
(function () {
    var STYLE_ID = 'bjfMnEmulatorStyle';
    // Colours are MobileNAV areas. Each one is a custom property on the phone root, with the screenshot
    // value as its fallback here. applyTheme overwrites them from the theme of a response.
    var CSS = [
        '.bjf-mn-emu-root{--mn-ButtonTitleBackground:#33A4E3;--mn-ButtonTitleForeground:#FFFFFF;--mn-HighlightBackground:#227DAF;--mn-HighlightForeground:#FFFFFF;--mn-DialogBorder:#11567B;--mn-Separator:#E0E0E0;--mn-GroupSeparator:#FFFFFF;--mn-WindowBackground:#E1F2FB;--mn-WindowForeground:#000000;--mn-DisabledButtonBackground:#AAAAAA;--mn-DisabledButtonForeground:#FFFFFF;--mn-CardDisabledCaption:#AAAAAA;--mn-CardMandatoryCaption:#A60D14;--mn-CardValidatedCaption:#008000;--mn-PageBackground:#FFFFFF;--mn-PageForeground:#000000;--mn-TitleToolbarBackground:#33A4E3;--mn-TitleToolbarForeground:#FFFFFF;--mn-HomeTileBackground:#FFFFFF;--mn-CardAdditionalCaption:#3F3F3F;--mn-ToolbarAdditionalCaption:#3F3F3F;height:100%;box-sizing:border-box;overflow:hidden;padding:10px;background:#f3f2f1;color:var(--mn-PageForeground);font:14px/1.35 Roboto,"Segoe UI",system-ui,sans-serif;-webkit-font-smoothing:antialiased}',
        '.bjf-mn-emu-root *,.bjf-mn-emu-root *::before,.bjf-mn-emu-root *::after{box-sizing:border-box}',
        '.bjf-mn-emu-root :focus-visible{outline:2px solid #227DAF;outline-offset:2px}',
        '.bjf-mn-emu-frame{position:relative;display:flex;flex-direction:column;width:100%;max-width:356px;height:100%;margin:0 auto;border:1px solid #c8c6c4;border-radius:0;background:var(--mn-PageBackground);overflow:hidden}',
        '.bjf-mn-emu-bar{display:flex;flex:0 0 auto;align-items:center;height:42px;min-height:42px;background:var(--mn-TitleToolbarBackground);color:var(--mn-TitleToolbarForeground);padding:0 2px;border-bottom:1px solid var(--mn-HighlightBackground);z-index:2}',
        '.bjf-mn-emu-writes{flex:0 0 auto;background:#fff;color:#a4262c;border-bottom:1px solid #e0e0e0;padding:8px 12px;font:12px/1.35 "Segoe UI",system-ui,sans-serif;overflow-wrap:anywhere}',
        '.bjf-mn-emu-titles{flex:1;min-width:0;text-align:center;padding:0 4px}',
        '.bjf-mn-emu-sub{font-size:13px;font-weight:400;color:var(--mn-PageForeground);line-height:1.2;overflow-wrap:anywhere}',
        '.bjf-mn-emu-bar .bjf-mn-emu-sub,.bjf-mn-emu-bar .bjf-mn-emu-title{color:var(--mn-TitleToolbarForeground)}',
        '.bjf-mn-emu-title{font-size:16px;font-weight:400;color:var(--mn-PageForeground);line-height:1.2;overflow-wrap:anywhere}',
        '.bjf-mn-emu-title.bjf-mn-emu-record{font-size:14px;font-weight:700}',
        '.bjf-mn-emu-strip{flex:0 0 auto;background:var(--mn-WindowBackground);color:var(--mn-WindowForeground);border-bottom:1px solid var(--mn-Separator);padding:6px 12px;font-size:12px;font-weight:600;line-height:1.35}',
        '.bjf-mn-emu-content{flex:1 1 auto;min-height:0;overflow-y:auto;overflow-x:hidden;background:var(--mn-PageBackground)}',
        '.bjf-mn-emu-content.bjf-mn-emu-card{background:var(--mn-HighlightBackground);color:var(--mn-HighlightForeground)}',
        '.bjf-mn-emu-cat{display:flex;align-items:center;justify-content:space-between;gap:8px;width:100%;min-height:48px;padding:6px 16px;margin:0;border:none;background:var(--mn-PageBackground);color:var(--mn-PageForeground);font:inherit;font-size:18px;font-weight:400;line-height:1.2;text-align:left;overflow-wrap:anywhere}',
        '.bjf-mn-emu-cat.bjf-mn-emu-collapsible{cursor:pointer}',
        '.bjf-mn-emu-cat .bjf-mn-emu-svg{flex:0 0 auto;width:28px;height:28px;stroke-width:2}',
        '.bjf-mn-emu-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:4px;padding:4px;background:var(--mn-HighlightBackground)}',
        '.bjf-mn-emu-grid[hidden]{display:none}',
        '.bjf-mn-emu-tile{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;aspect-ratio:1/1;min-width:0;padding:8px 6px;background:var(--mn-HomeTileBackground);color:var(--mn-PageForeground);text-align:center;cursor:pointer;overflow:hidden;font-size:14px;font-weight:700;line-height:1.2;transition:opacity .1s}',
        '.bjf-mn-emu-tile:hover{opacity:.85}',
        '.bjf-mn-emu-tile:active{opacity:.7}',
        '.bjf-mn-emu-tile .bjf-mn-emu-svg{width:36px;height:36px;stroke-width:1.5;color:var(--mn-PageForeground)}',
        '.bjf-mn-emu-pic{flex:0 0 auto;width:24px;height:24px;object-fit:contain}',
        '.bjf-mn-emu-tile .bjf-mn-emu-pic{width:36px;height:36px}',
        '.bjf-mn-emu-tile>span{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;max-width:100%;overflow-wrap:anywhere}',
        '.bjf-mn-emu-empty{color:var(--mn-ToolbarAdditionalCaption);padding:32px 20px;text-align:center;font-size:13px;line-height:1.5}',
        '.bjf-mn-emu-error{background:none;color:#a4262c;padding:8px 10px;margin:8px 10px 0;font:13px/1.35 "Segoe UI",system-ui,sans-serif;overflow-wrap:anywhere}',
        '.bjf-mn-emu-note{background:none;color:#323130;padding:8px 10px;margin:8px 10px;font:12px/1.4 "Segoe UI",system-ui,sans-serif;overflow-wrap:anywhere}',
        '.bjf-mn-emu-toolbar{display:flex;flex-wrap:wrap;gap:6px;padding:8px 10px;margin:0;background:var(--mn-PageBackground);border-bottom:1px solid var(--mn-Separator)}',
        '.bjf-mn-emu-search{flex:1 1 100%;min-width:0;margin:0;padding:7px 10px;border:1px solid #000;border-radius:0;font:inherit;font-size:14px;background:#fff;color:#000}',
        '.bjf-mn-emu-search:focus{outline:2px solid #227DAF;outline-offset:1px}',
        '.bjf-mn-emu-select{flex:1 1 auto;min-width:0;max-width:100%;padding:6px 8px;border:1px solid #000;border-radius:0;font:inherit;font-size:13px;background:#fff;color:#000;cursor:pointer}',
        '.bjf-mn-emu-applied{background:none;color:#323130;font:600 12px/1.35 "Segoe UI",system-ui,sans-serif;margin:0;padding:6px 12px;border-bottom:1px solid #e0e0e0;overflow-wrap:anywhere}',
        '.bjf-mn-emu-panel{background:#fff;color:#323130;border-bottom:1px solid #e0e0e0;padding:10px 12px;margin:0;font:13px/1.35 "Segoe UI",system-ui,sans-serif}',
        '.bjf-mn-emu-panel>.bjf-mn-emu-dtext{background:none;color:#323130;padding:0;margin:0 0 8px;font-size:12px}',
        '.bjf-mn-emu-flabel{font-size:14px;font-weight:400;color:var(--mn-PageForeground);margin:8px 0 4px}',
        '.bjf-mn-emu-flabel:first-child{margin-top:0}',
        '.bjf-mn-emu-input{width:100%;padding:6px 8px;border:1px solid #000;border-radius:0;font:inherit;font-size:14px;background:#fff;color:#000}',
        '.bjf-mn-emu-input:focus{outline:2px solid #227DAF;outline-offset:1px}',
        '.bjf-mn-emu-edit{display:flex;gap:6px;align-items:center;margin-top:3px}',
        '.bjf-mn-emu-edit .bjf-mn-emu-input{flex:1 1 auto;min-width:0;width:auto}',
        '.bjf-mn-emu-step{padding:5px 11px;font-weight:700}',
        '.bjf-mn-emu-actions{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}',
        '.bjf-mn-emu-content>.bjf-mn-emu-actions{padding:10px 14px 14px;margin-top:0}',
        '.bjf-mn-emu-button{padding:6px 12px;border:1px solid currentColor;border-radius:0;background:var(--mn-WindowBackground);color:var(--mn-WindowForeground);font:inherit;font-size:14px;line-height:1.25;cursor:pointer}',
        '.bjf-mn-emu-button.bjf-mn-emu-primary{background:var(--mn-HighlightBackground);color:var(--mn-HighlightForeground)}',
        '.bjf-mn-emu-button:disabled{background:var(--mn-DisabledButtonBackground);color:var(--mn-DisabledButtonForeground);cursor:not-allowed}',
        '.bjf-mn-emu-row{display:flex;align-items:center;gap:8px;min-height:48px;padding:6px 12px;margin:0;background:var(--mn-PageBackground);color:var(--mn-PageForeground);overflow-wrap:anywhere}',
        '.bjf-mn-emu-row.bjf-mn-emu-alt{background:var(--mn-HighlightBackground);color:var(--mn-HighlightForeground)}',
        '.bjf-mn-emu-rowtext{flex:1 1 auto;min-width:0}',
        '.bjf-mn-emu-drillicon{display:flex;flex:0 0 auto;color:inherit}',
        '.bjf-mn-emu-open{cursor:pointer}',
        '.bjf-mn-emu-line1{display:flex;justify-content:space-between;align-items:baseline;gap:10px;font-size:14px;font-weight:700;line-height:1.3;overflow-wrap:anywhere}',
        '.bjf-mn-emu-line2{display:flex;justify-content:space-between;align-items:baseline;gap:10px;font-size:14px;font-weight:400;line-height:1.3;margin-top:1px;overflow-wrap:anywhere}',
        '.bjf-mn-emu-line3{display:flex;justify-content:space-between;align-items:baseline;gap:10px;font-size:13px;font-weight:400;line-height:1.3;margin-top:1px;overflow-wrap:anywhere}',
        '.bjf-mn-emu-lft{min-width:0}',
        '.bjf-mn-emu-rgt{flex:0 0 auto;text-align:right;white-space:nowrap}',
        '.bjf-mn-emu-tag{display:inline-block;font-size:11px;font-weight:600;border:1px solid currentColor;padding:0 4px;margin-top:2px;overflow-wrap:anywhere}',
        '.bjf-mn-emu-field{padding:10px 16px 8px;min-height:58px;background:transparent;color:var(--mn-HighlightForeground)}',
        '.bjf-mn-emu-fcap{font-size:14px;font-weight:400;line-height:1.3;color:var(--mn-HighlightForeground);overflow-wrap:anywhere}',
        '.bjf-mn-emu-fcap.bjf-mn-emu-mand{color:var(--mn-HighlightForeground);font-weight:700}',
        '.bjf-mn-emu-fval{display:flex;align-items:center;gap:8px;min-width:0;padding-left:12px;margin-top:2px;font-size:14px;line-height:1.35;color:var(--mn-HighlightForeground);overflow-wrap:anywhere}',
        '.bjf-mn-emu-fmain{flex:1 1 auto;min-width:0;overflow-wrap:anywhere}',
        '.bjf-mn-emu-side{display:flex;flex:0 0 auto;align-items:center;color:inherit}',
        '.bjf-mn-emu-icon{display:flex;flex:0 0 auto;align-items:center;justify-content:center;width:32px;height:32px;padding:4px;border:none;border-radius:0;background:transparent;color:inherit;cursor:pointer}',
        '.bjf-mn-emu-icon:hover:not(:disabled){opacity:.8}',
        '.bjf-mn-emu-icon:disabled{opacity:.35;cursor:default}',
        '.bjf-mn-emu-fval .bjf-mn-emu-icon{width:36px;height:36px;padding:6px}',
        '.bjf-mn-emu-bar .bjf-mn-emu-icon{width:40px;height:40px;padding:8px;color:var(--mn-TitleToolbarForeground)}',
        '.bjf-mn-emu-bar .bjf-mn-emu-icon:hover:not(:disabled){opacity:.6}',
        '.bjf-mn-emu-bar .bjf-mn-emu-icon:disabled{opacity:.3}',
        '.bjf-mn-emu-svg{width:22px;height:22px;fill:none;stroke:currentColor;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round}',
        '.bjf-mn-emu-svg.bjf-mn-emu-filled{fill:currentColor;stroke:none}',
        '.bjf-mn-emu-slot{flex:0 0 40px}',
        '.bjf-mn-emu-toggle{position:relative;display:inline-block;flex:0 0 auto;width:36px;height:18px;padding:0;border:2px solid currentColor;border-radius:9px;background:transparent;color:inherit;cursor:pointer}',
        '.bjf-mn-emu-toggle::after{content:"";position:absolute;top:1px;left:1px;width:12px;height:12px;border-radius:50%;background:currentColor;transition:left .15s}',
        '.bjf-mn-emu-toggle[aria-checked="true"]::after{left:19px}',
        '.bjf-mn-emu-toggle:disabled{cursor:default;opacity:.8}',
        '.bjf-mn-emu-foot{display:flex;flex:0 0 auto;flex-wrap:wrap;background:var(--mn-TitleToolbarBackground);color:var(--mn-TitleToolbarForeground);overflow:hidden;z-index:3}',
        '.bjf-mn-emu-foot:empty{display:none}',
        '.bjf-mn-emu-foot-item{flex:0 0 16.6666%;min-width:0;height:60px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;padding:4px 2px;border:none;background:transparent;color:var(--mn-TitleToolbarForeground);font:inherit;font-size:11px;line-height:1.15;cursor:pointer;overflow:hidden}',
        '.bjf-mn-emu-foot-item>span{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
        '.bjf-mn-emu-foot-item .bjf-mn-emu-svg{width:24px;height:24px;stroke-width:1.6}',
        '.bjf-mn-emu-foot-item:disabled{opacity:.4;cursor:not-allowed}',
        '.bjf-mn-emu-sheet{order:0;flex:0 0 100%;display:flex;flex-wrap:wrap;background:var(--mn-PageBackground);color:var(--mn-PageForeground);border-top:1px solid #e0e0e0}',
        '.bjf-mn-emu-sheet .bjf-mn-emu-pick{flex:0 0 16.6666%;min-width:0;height:60px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;padding:4px 2px;margin:0;border:none;border-radius:0;background:transparent;color:var(--mn-PageForeground);font-size:11px;line-height:1.15;white-space:nowrap;overflow:hidden}',
        '.bjf-mn-emu-sheet .bjf-mn-emu-pick>span{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
        '.bjf-mn-emu-sheet .bjf-mn-emu-pick .bjf-mn-emu-svg{width:24px;height:24px;stroke-width:1.6}',
        '.bjf-mn-emu-sheet .bjf-mn-emu-pick:disabled{opacity:.4}',
        '.bjf-mn-emu-drill{background:none;border:none;padding:0;color:inherit;font:inherit;text-align:left;cursor:pointer;overflow-wrap:anywhere;max-width:100%}',
        '.bjf-mn-emu-link{display:inline-block;color:var(--mn-HighlightBackground);font-weight:600;text-decoration:underline;text-underline-offset:2px;overflow-wrap:anywhere}',
        '.bjf-mn-emu-toast{position:absolute;left:14px;right:14px;bottom:64px;z-index:4;background:#323130;color:#fff;padding:8px 12px;font:13px/1.35 "Segoe UI",system-ui,sans-serif;overflow-wrap:anywhere}',
        '.bjf-mn-emu-overlay{position:absolute;top:0;right:0;bottom:0;left:0;z-index:5;display:flex;align-items:center;justify-content:center;padding:14px;background:rgba(0,0,0,.45)}',
        '.bjf-mn-emu-dialog{width:100%;max-width:330px;background:#fff;color:#323130;border:1px solid #c8c6c4;border-radius:0;padding:0 0 12px;overflow:hidden;overflow-wrap:anywhere;font:13px/1.35 "Segoe UI",system-ui,sans-serif}',
        '.bjf-mn-emu-dialog>.bjf-mn-emu-title{display:block;margin:0;padding:12px 16px 8px;background:none;color:#323130;font-size:14px;font-weight:600;text-align:left;overflow-wrap:anywhere}',
        '.bjf-mn-emu-dialog>.bjf-mn-emu-dtext{margin:0 16px 12px;font-size:13px;color:#323130}',
        '.bjf-mn-emu-dialog>.bjf-mn-emu-dtext:empty{display:none}',
        '.bjf-mn-emu-dialog .bjf-mn-emu-edit{padding:0 16px}',
        '.bjf-mn-emu-dialog>.bjf-mn-emu-actions{justify-content:flex-end;padding:0 16px}',
        '.bjf-mn-emu-dialog .bjf-mn-emu-button{min-width:80px;padding:6px 12px;font:13px/1.25 "Segoe UI",system-ui,sans-serif;background:#fff;color:#323130;border:1px solid #8a8886;border-radius:0}',
        '.bjf-mn-emu-stages{display:flex;flex-wrap:wrap;justify-content:center;align-items:center;background:var(--mn-WindowBackground);border-bottom:1px solid var(--mn-Separator);padding:6px 10px 8px;margin:0}',
        '.bjf-mn-emu-stagename{flex:0 0 100%;text-align:center;font-size:13px;font-weight:700;color:var(--mn-WindowForeground);margin-bottom:4px;overflow-wrap:anywhere}',
        '.bjf-mn-emu-stage{display:inline-block;width:12px;height:12px;margin:3px;padding:0;border:2px solid var(--mn-ButtonTitleBackground);border-radius:50%;background:transparent;color:transparent;font-size:0;overflow:hidden}',
        '.bjf-mn-emu-stage.bjf-mn-emu-reached,.bjf-mn-emu-stage.bjf-mn-emu-current{background:var(--mn-ButtonTitleBackground)}',
        '.bjf-mn-emu-stage.bjf-mn-emu-current{box-shadow:0 0 0 2px rgba(51,164,227,.3)}',
        '.bjf-mn-emu-fielderr{color:var(--mn-CardMandatoryCaption);font-size:12px;font-weight:600;margin-top:4px;overflow-wrap:anywhere}',
        '.bjf-mn-emu-fielderr:empty{display:none}',
        '.bjf-mn-emu-content.bjf-mn-emu-card .bjf-mn-emu-fielderr{color:var(--mn-HighlightForeground)}',
        '.bjf-mn-emu-content.bjf-mn-emu-card>.bjf-mn-emu-error{background:var(--mn-PageBackground);padding:8px 10px}',
        '.bjf-mn-emu-blob{width:100%;margin-top:2px}',
        '.bjf-mn-emu-preview{display:block;max-width:100%;height:auto;margin:6px 0;border:1px solid #e0e0e0;border-radius:4px;background:#fff}',
        '.bjf-mn-emu-pdf{display:block;width:100%;height:280px;margin:6px 0;border:1px solid #e0e0e0;border-radius:4px;background:#fff}',
        '.bjf-mn-emu-pad{display:block;width:100%;height:140px;margin:8px 0;border:1px dashed var(--mn-HighlightBackground);border-radius:4px;background:var(--mn-PageBackground);touch-action:none}',
        '.bjf-mn-emu-picks{margin-top:8px;max-height:260px;overflow-y:auto}',
        '.bjf-mn-emu-picks:empty{display:none}',
        '.bjf-mn-emu-pick{display:block;width:100%;margin:0;padding:8px 12px;border:none;border-radius:0;background:var(--mn-PageBackground);color:var(--mn-PageForeground);font:inherit;text-align:left;cursor:pointer;overflow-wrap:anywhere}',
        '.bjf-mn-emu-picks .bjf-mn-emu-pick:nth-child(odd){background:var(--mn-HighlightBackground);color:var(--mn-HighlightForeground)}',
        '.bjf-mn-emu-pick:hover:not(:disabled){opacity:.85}',
        '.bjf-mn-emu-menu{position:absolute;top:42px;right:0;z-index:6;width:min(260px,88%);max-height:70%;overflow-y:auto;background:#fff;color:#323130;border:1px solid #c8c6c4;font:13px/1.35 "Segoe UI",system-ui,sans-serif}',
        '.bjf-mn-emu-menu-label{display:block;padding:10px 12px 4px;font-size:12px;font-weight:600;color:#605e5c}',
        '.bjf-mn-emu-menu-item{display:block;width:100%;padding:8px 12px;margin:0;border:none;border-bottom:1px solid #edebe9;border-radius:0;background:#fff;color:#323130;font:13px/1.35 "Segoe UI",system-ui,sans-serif;text-align:left;cursor:pointer}',
        '.bjf-mn-emu-menu-item:disabled{opacity:.4;cursor:not-allowed}',
        '.bjf-mn-emu-menu .bjf-mn-emu-select{display:block;width:calc(100% - 24px);margin:0 12px 8px;border-color:#8a8886}',
        '@media (prefers-reduced-motion:reduce){.bjf-mn-emu-root *,.bjf-mn-emu-root *::before,.bjf-mn-emu-root *::after{transition-duration:.01ms!important;animation-duration:.01ms!important}}'
    ].join('');
    var LOADING = 'Loading...';
    var WRITES_OFF = 'Writes are off. Turn on Allow Writes on the emulator setup page to run buttons and edit fields.';
    var EMPTY_START = 'Choose Load Menu on the page to show the device menu.';
    var LIVE_NOTE = 'The live read failed, so these values come from the stored data. ';
    var UNHANDLED = 'Not handled in this emulator: ';
    var OPEN_RELATED = 'Open';
    var SCAN_BUTTON = 'Scan';
    var SCAN_HINT = 'Scan or type a value';
    var PAGE_READ_ONLY = 'This page is read-only in its layout.';
    var BLOB_SHOW = 'Show';
    var BLOB_UPLOAD = 'Upload';
    var BLOB_SIGN = 'Sign';
    var BLOB_DOWNLOAD = 'Download';
    var BLOB_NONE = 'No picture on the page.';
    var LOOKUP_BUTTON = 'Lookup';
    var REFRESH_LABEL = 'Refresh';
    var MENU_LABEL = 'Menu';
    var SORT_LABEL = 'Sort by';
    var FILTERS_LABEL = 'Filters';
    var SHOW_MORE = 'Show more';
    var SHOW_LESS = 'Show less';
    var FOOT_MAX = 6;
    var SVG_NS = 'http://www.w3.org/2000/svg';
    // Glyphs read from the MobileNAV Android resources: back, drill chevron, expand and the list icon. Filled
    // glyphs take the text colour. Refresh, search and the document glyph are outlines drawn in the same colour.
    var ICON_PATHS = {
        back: { view: '0 0 24 24', fill: true, d: 'M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12l4.58-4.59z' },
        drill: { view: '0 0 48 48', fill: true, d: 'm18.75 36-2.15-2.15 9.9-9.9-9.9-9.9 2.15-2.15L30.8 23.95Z' },
        expand_more: { view: '0 0 48 48', fill: true, d: 'M10.4 26.4q-1 0-1.7-.7T8 24q0-1 .7-1.7t1.7-.7q1 0 1.7.7t.7 1.7q0 1-.7 1.7t-1.7.7Zm13.6 0q-1 0-1.7-.7t-.7-1.7q0-1 .7-1.7t1.7-.7q1 0 1.7.7t.7 1.7q0 1-.7 1.7t-1.7.7Zm13.6 0q-1 0-1.7-.7t-.7-1.7q0-1 .7-1.7t1.7-.7q1 0 1.7.7T40 24q0 1-.7 1.7t-1.7.7Z' },
        expand_less: { view: '0 96 960 960', fill: true, d: 'm283 711-43-43 240-240 240 239-43 43-197-197-197 198Z' },
        search: { view: '0 0 24 24', d: 'M11 4a7 7 0 1 0 0 14 7 7 0 1 0 0-14M20 20l-4-4' },
        refresh: { view: '0 0 24 24', d: 'M20 12a8 8 0 1 1-2.3-5.6M20 4v5h-5' },
        item: { view: '0 0 24 24', d: 'M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6' },
        barcode: { view: '0 0 24 24', d: 'M4 5v14M7 5v14M10 5v14M13 5v14M17 5v14M20 5v14' },
        chevron_up: { view: '0 0 24 24', d: 'M6 15l6-6 6 6' },
        chevron_down: { view: '0 0 24 24', d: 'M6 9l6 6 6-6' },
        menu: { view: '0 0 24 24', d: 'M4 6h16M4 12h16M4 18h16' },
        neutral: { view: '0 0 24 24', d: 'M5 5h14v14H5z' }
    };

    // The app icons that a layout can send by code (AppImageType names). The 24 px SVG paths take the text
    // colour. The PNG files are drawn as they are. Codes that are not here get the neutral glyph.
    var APP_ICONS = {
        add: { png: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAADfklEQVRYw+2XwW5bVRCG/5l7rx1HaoPirBApgRS6gEUXbIIoiKdAiCfgARACQdoQKiFRCYQEK3gVdoCE6JIFKKUlpi2Lhog0se8598z8LO517DQ0rkW9IkeyLPlenfPNzP/PHAOn6/++ZJqX1zc+zrqLi19duPD8G0WRRxIEABGAjs52b/vnmzdvvbW5sf7bo+6ZTwPg7tpd6i6+/tqrC61Wcez5d9//sLS1daOYZs98unSRKcYqxohWq0BVJQCAqgIgqlAZSJ8ZAIg65yDMHO6js1QFDm+ezwiAEJD1t9PhTbBCgFS4c1pZTQlQhyfuhPsoAwJARIZJmopAp3n56uZ6cvPS3UDn4cedcHOYWRLh/n/KwObVT7rz8/NztcVGFc0ytb29+3ms4hk3g5GwJgNNYhBj1QohLH967bOoWdYieShf1Qwh9P29d9/580SAs2fPXFtdXX2JzsAxABF4LKMudrvPighSVY1EyDoTy8tPnXt5be2bosgPVDUbni8iyLNCf9++FQCsnQiw1F26eOnSKy+6GUYRjMlQBGaOVFWjX0VAGFaePtdeeWblBY67QwRsOlYZBpNLQOBAyDoq8t+aEdzsoSqVoVIhEAViqnCw34eqws0GEwFSSuz3B9BMwMZWfER30wxiDgrgZhiEEoN+QEoVOp0OvPbpyQAxBtzb+QutVo723BzyLIcIoKJjgjs+UIZ6MEsoy4BBWSKldGhPN4MdP/84gACaUoUYSuwf9FEUBdpFjizPkalCVOFknRcKSKs1kRIsGZIlmFldhKb+AIaOkcklMOuUZQmng070h62dAlWFZgoRrScgCaLpB2TdqB7SDN0dqYqdiQC7u7vf/nT9+g6J+OAeMUZ9YmHh4nPnzz+Z5TncrfF47fPbd24f/NHr/Zhl2X1RPbK3iuj+QT9MBAghvn/v3k5GguORqIiHEHKSX5v7m0o2vX9YCmBv7+/enbt33+50OluqWoxXXEiBiE8E2Lj8QTxB6PHzL75M5glq0tQaTa0Vquqtdnvw0ZUPDYA99mF0+cpmDjJPlUGgRwBUCTozBeZmNw0bVVtKh8IaASjc/egAefw3IsBJmFl9JxgDEKnH89D3s7kRobZeckcudgQAELhztgAkhWSb7jB5MAMCkjnJbGYAquohhBu9Xu9XUU1sLqANwFy/3/9FVQen/3ZO1zTrH4cRNeTgM7bvAAAAAElFTkSuQmCC' },
        assign_to_me: { view: "0 0 24 24", svg: "<g> <path fill=\"none\" d=\"M0 0h24v24H0z\"/> <path d=\"M12 14v2a6 6 0 0 0-6 6H4a8 8 0 0 1 8-8zm0-1c-3.315 0-6-2.685-6-6s2.685-6 6-6 6 2.685 6 6-2.685 6-6 6zm0-2c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm6 10.5l-2.939 1.545.561-3.272-2.377-2.318 3.286-.478L18 14l1.47 2.977 3.285.478-2.377 2.318.56 3.272L18 21.5z\"/> </g>" },
        barcode: { png: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAP+klEQVR42u1bTWwcR3b+XlX3/JKiR5Q8svwnWbGy8gLJGpYtQQt4/bfxwQsFvgQ+6OBDckhyNRwgOScn3xYJsEBuK2DhwAYWvngBWzYUw17BMox14F1BsWUvJcsUaVHkUEPOTHfVezl0VbOm2T0ktRGwQdRAYzjdNVXvfe97r169KgJ3rjvXnevOdee6c/2/veg2tf1juORWlaK9e/fSwYMH9d69e9VoNKJ6vY44jpEkCYnIH63GSZIgjmNorWVtbQ3T09NgZllaWuL5+Xk7NzcnRWCiQh8KgH7iiSdqL7300uFut7sPAIkIiQhEhJRSIMpwIyKIyNinf+ff+0//twfQP3P9jv3Gfw8/q9qE75nZvxcnjyil5Nq1a9feeOON/56bm0sAWABcBgAB0DMzM42XX3755GOPPfYv7XZ7N2UXineooFKqVOlN1Kp4V1RmE5cLAITPQpCYeRNoIiIPPfTQjUaj8Y9nz559q9frDR0LpAiAiuO41mw2W91u92Sr1eoCiELLElGubBGIsr/LvheBKFOsSvGi0sU+lFI5COHdbre7d99991/W6/V34zjmNE3ZMWEcAACNJEmm0zSdAqBERDkXADPnA4SK+ZuZN9E8bO9/o5QqVaTM6uHl+ymxcP6sTPmsqag0Tdtpmk4DMACSUgCIKGbmtjEmpsBsV65cwenTp3OlvCJaa7z66qv59/Pnz+P9998HEaFer+PFF1/E22+/jbW1NQDA0aNH8cwzz8AYg9dffx2Li4tjiokInn76aVy9ehUXL16EiGB2dhZPPvkk3nzzTVhrAQAnT57E4cOHwcx47bXXYIwBM48BcOrUKdx777059saYmJnbRNR3xkYZABGAhjEmEpGc7r1eD++8886YFZVSqNVqeOWVV6C1BgBcvnwZZ86cgVIK7XYbTz31FD788EMsLy8DAGZmZvDss8+CmfHpp5/iyy+/HPNbZsahQ4dw4cIFfPDBBwCABx54AI888gjee+89WGshIjh+/DgOHz4MEcGZM2eQJMkmAF544QXcd999uXJOp4bTsRwAY4xO0zRy1C+NyFv5YtVdjAFh0AoBKPp+2CZ0Px+bqtyhGGdERFlrI2OMLgOANmQjVRWpq6atYnQvRueyAFhUKlSgGEvKYkOxzVYziZNThboCkOI0SH7erxK4KogVwQktWAxgZWwpMqCMHWUWnsS4gmGocJcmQpsifNU0VTaQF9TPClvN7R6coquFdxGUSe44yd2qrmjbiXWFtauSmiIDqrK3KqZUTXuTkqQyVm513RIA23WBsjukrqe1Vzb8vpNgOqnNLQFQlr0VrRpaNGxb5c9FBoTKepepUnw7DJhk/UlM2JIBVdG2SqBQ2bJgVhYDyqhcdIEwX9gOAMWAuyMAyvx7OxE//F2ZMsXAGAJQlcpWsWErACYF4B0xYNKgofDF55NiQRj0ylZzZfGhbLytGFA0xi0HwVDIcOFTFfTGrFmSBxSnua3AqmJAFVDbsXw1AH6wQifFVd2Y4AVah6hzhYU8A/J+gj7L3KboHkVXmhSXvF4oeRdtp5A2hr5PpIly5RC+Zx5TZlMmGLSXAGx4Bb1ShXY5WF6eEhfgQMkx9ni9tgWAtYC1QJoCSmU/tBbKd+4LIwA0c9bWGEApwBiQj77MADPI3RDJ2nqL+98yZ3mpe0b+mVv6otAPiYCYIWkKcXIpX68IAzUzxJgskLuxZCsA3GuhXg904wZIKZAI4l4PnUBQD0BsLWhpCYhjQCk0+n3cZQwUEZrGIO73MZOmYGMAEbTW1yHXr4OYMT0a4S5jIM6qEIFlRn0wQHs4xF3GZEvoJEHc76NjLawxEAC11VXQ0hLIWuy2FkkhoAJA3OtBLS0BRFDMoF4PIpshiAolYiERqO++g/7mG5Bb+DQWFnC/s2K+wBBBTAR15QoojkFEmLpxA/c61BtJgsa1a9g3GqFpDEQEu1ZWgMuXQdZiz9oa+mmauYwv0jFj+vp17F5dxX4HwN7BAM2FBexPU1gnQ3NxEerKFYi12G8MjLXjbkaExuIi1MxMtuRzOpEIqKIqLDEgh5j1wNqoduECxevrABEEwF3z8zhmbe5DnlZaBNHHH0NHEUCEfV9/jaNpCgCoAZj5/HP82doa1kcjAMD9V66APvoImhlHlpcxOxxu8uXupUvghQVIkgAi6PR6uOt3v8NjSZJbePbiRShjAGYcTdO8UBLGrM6FC4hXVvJlX21ujvYwR01mfQmQ1AGRZzoPAq2z09N/39H6r1W3u78xM9MCEbEIDUcjfDs/v2kTgYhw4MCBrHIkgl6vh+tLS3nVaF+3i4XFxcxyAGZ27cKe2VkAwNVvv8XIARMKvmfPHgyGQ6z1+5ngtRp2796NawsLmS8D6Ha7aLfbEABf//73GYuc5T0Q+++5B41GA0QkYJbR6uo6Lyx8u2ztv//o5s1/nQPWxwoiKwD97WDwy39rtU7Mar1PajXA0Z2ZkTia0ngNDfDtiGCjCIn7jQbAcYyUCMb7uNageh0sgoQIIyd0Pv0CsFrDKIXEzTREBI7jbHzX1kYRpFaDiCDxRX6fshOB3NheBxKBaM03mH/3d4PBL1c2agIbBZEegA+MSX86HP7iH+r1o/Vmc8r7prUW655iQQwgANJsQlztMI1jDDwARLD1OgYeACKkUQRptQBmjJTK2/p+RQSmVkOSplj3ghPB1moYBFO0rdchzSYggoHPNQIgAcDWapBmMwNDBIN6ffWnw+EvPjAm7VcEQVpXCj+L4/kXjx37+vGFhX1g1h6AtUD5vDgqAmm1NgCo1bDmd1iIYBsNrCuF1P12FMdAqwWIYKg11gtrDXF9jIZDrHn2KQXbaGAtACCt1YBWCyyCvrO6BEBCBKbRyGTLStl88dChr3928eL8IIsd5RUhn3AsPfMMD7/4ArXf/jazSpJkAhQWSArIBtEaBCCp1dB3bSIAttHAgAgjZ5lRHIOdUAOlxpTybEtqNQyjCGuOYaQ1jAOAXT+m0cj6Edl4HtYugaxNs5kB//3vY+nhh5l//vNNucAYAEopIiISrWn9Jz+BWl6GWlqCrdWyiOEpFtBcms08YTJRhIFrEzmqrgPwoS6NIsAJPlQK6yUAmDhGojUGTlDtXCBsa+MY0mhAnAvYUDbHAlurQRoNmNlZrL/wAuSrr4gAUkqR319AWB4eW/8rBdvpYPDcc+BGAxxFSAEkIkiDOxEBoggSRZA4hnV0T0WQAmCt8++JCCwREEVAFCElQuLbuvYpkPeRuDt1gdH3kRLBap0lX3E8Jk8oI2sNaTax/txzsLOzm9Y21alwkJ8nR45AXb4MfvfdTNkwBngXiCKIUiClYLXO23EAgJ9BjFJAHEOYs/2pMHd3FmStYYiQOCp7IH20J6+c68c/l8LCh7XG6NFHkRw5Ulm/nFgQ8VPK8Ic/RPr550hdpkYu4FC2eQiOIpDWGe2UypTy8SQAACIwSkHiGGBGSpT1WRjXKJWxwAWzlAjigM1XmFpnwPtp0BmMgjiV7tuHwYkTmXuW1BEqXWDTzszUFFaOHUPfKTJylvMURRxn1ojjjAEBfTmKsr+dpQxRBoDLD8J+EhGMXNQ3RBgxY+RdyffjdzWdC3AUbfThfp8A6ANYOXYMPDV16xWhsJpyrd3GOREcC3MBkSzZcQwgpbIEJlzze8H9HK9UbrncNQpFD6M1UpcIERFSog0XcG5htQZHUe4C1o/pPs+J4OFWC90/pCJUXGf/WgRdAPeI5EteLZIpFEVg7wKFrM4HJgksJ47aSbB48Wt21jp/ByAPeklYKwhjgEgGgFN03gFwaps1QTWpGhxaZwjgjAjWnfWMC1CidX6zUjAi+S1Kwbi2RiQLVs5/rXvm3/mblQITwbjlsX+W+jbOTUQpiNZ5/6kI1p2Mg0K5rqrMPxGAYmIhABYdEzi4hSi//bELG0RmdhayAQAgytoF78I2+Xe/TA779kxwuQe7MVgEv2bG4g43RtSkvYAwQSE32H+JYA6AdUKFAHiFvRIcKMoA2FPdldNCRTlsF3z3IHhghSjrhwiiVNaGCHNONi4s2LbaHlM72RQhp/j7zHkGJkrlANiQAQErQqvmQAVg5YzyrAlYZB3lOWATB/m/JcIAwPvMsG4l+AczYFI8gAhWAZz1BUpnCVFqIwHyFV+nuPFWdtZjpbIYEABmPEie7l5ZzyjXHwfgwlWszjJjNZgFdrI/GJUUhKXqgEE4BV4C8EXAAAQUR0BTDrI8CZa9XFKtlYrbJ2X51Oz7JsKXAC55+RwDJuxrSrH4HZVVxYvU73Q6eP755xEuIgCgqVS2vk8SCIDO7CwePnIEBCCKIjSnpvAnhw9jOBoBIrh7376cvgceeggznU4+DfoSeGf37szqTobp6Wk0p6bwp9/7HthRdnrXrsz6jQaaP/4x/qIgl9YanU6n9ERJMWsOj4u0iGhPvV6///Tp0/989OjRE9lUL5uPxzqBASBaWEDzo4+y0nf4vioA+UJHQQip2szwTAiSMHJT7ODECZhut3IT1E1/AsB+8sknH506deqfRqPRFRG5jqwklleEnDuTEJFl5iR85s4ObVJEANhuF+nBg6h99dWY8gjWDGOgef/17/xeQ+gOnhEB0FSoHqUHD8J2uyB/cLNkm97J7vZrOCEi647Rlp4UZWY2xpj03LlzHz/44IOPTk1NTbnzQjRp0bR24ACmr15FdPMmSaizt1jJCW3Z5jHvMas6pcz0tNw8cADizh9OmOqEiKTf7/fPnTv3sTEmZWYT1lDCX9YAzADotlqtBx5//PEfzM7O3pem6ZS1Ni4eLgqEFRJBZ3U1fnJ5eX8EaPjdmJD2t3LOvVCHhAgMkf3PTufb5V27UlcApYouRGudxnHcX1pa+ub8+fO/WV9fvwxgwZVAkyIAEYA2gA4R3a2U6hJRB8CUA4cKMWNsMBGhv1LqnuNa3+v85X/7/wtEROSctVf/g3neu2aJLOGEkgDoi8gyMy+IyCKAZQBrbuYdcwHrfnDTHSpMXeOmq3JTFQv8wL+y9ovjRH/eVWr3tk8p7WB//hrzjV+l6Wd2owpWaf0ggRw4hXsAbobnhMvyAL8IYwBDZ/k4AAATLCsrgHxszHd/U6sdrynVoHEQdvqfFvlcLERImIdvGXNuBViZYIgiC6xbsyUOiGFQoKpURjlgtPtUE+i/aeApAG/V6w8fiqIfgEipIEHBTuPAxpY3XzLmNydHoy/6m6fwSQD4zNoECSdvVQ9gh1KZ0rSVzG0APWs/6yjVrml9n58V/EbrtlNvfy4YkIT5m561n7UBsw0AyjI+qWLgbflHKAHI1uu7tNY/gtZtt1m4IwCQ7fcJrF2z1p7Vo9Eq7dyNtulntwkENJsPIo4fz8/dK7W98Zg3Dhql6XkMBnO3Q/nbCoADQWF6ehrGaNRqgNbbG89aQZIAUWRx8+ZNKvjt/xkAxthwa8Ld9v/R+x+uOWIw6JUoegAAAABJRU5ErkJggg==' },
        ch_img_next: { view: "0 96 960 960", svg: "<path d=\"m375 816-43-43 198-198-198-198 43-43 241 241-241 241Z\"/>" },
        ch_img_prev: { view: "0 96 960 960", svg: "<path d=\"M561 816 320 575l241-241 43 43-198 198 198 198-43 43Z\"/>" },
        chevron_back: { view: "0 0 24 24", svg: "<path d=\"M0 0h24v24H0V0z\" fill=\"none\"/><path d=\"M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12l4.58-4.59z\"/>" },
        close: { png: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAD0klEQVRYR+1V21ITWRR11PKuVZZaas08TPk0H+DlS/wGQT/CJ53RF6oIBBgKon/gJSFCKZqEJELSTZoQJOlLLmBAAwkICddku3agU0lT0B31TahaRU733nuts/Y+p48cOfw7dMDEAa/Xe8Pn8/3VrFHIOYPcf5rNa4hHgT8FQUiFQqEpFLxktRhiTweDwQFJkvIej+em1byGOCT+DXJtc3OT1tbWaGxsbAKCrpoVY/JAIPB6eXmZyuUyxWKxAmrdMsvbQy6KYmJjY6NahFEn4tp+xUB+yu/3v15aWqrlbW9vUzgczrW1td22JIL7DfLk+vo6bSG5HqVSiUZHRycRc9lYDM9OgtxZKBSISWt5W1tV8U6ns9DR0XHHVATsuquqaqVaAMn12MS6WCxWRaAdNSd44HRyYw5vZA2IRqNks9kemgrgAIh4oGpahQl5BuqxgfXq6irPRBQirnPPQe7K5/N7YnnnRbjG5J2dnU8tketBEHEfTpSZkGehHutYr0AEnJBA7l4EuTGGiTlGkiYI1v8LAX80JWDXiRZFUSpMyDYasfztGy0sLpJus/5+ZWWF+F0kEmHyx00T1yfAiVZZVipcvARLD8Iq5qOAE8AQx8fZ9ic/RV7XjhYZTjA5W2uETsxucDsEUWTyRz9k+36KvRhMWZHLxWKJmJDBVudx7L7mcsAC5RYWKCwI1Z7/kp0bWsGXTIR3yaQ5EM5/+QJ8rSE7N0cOhyMHAaY3ZlMCYeXJvr4+VzwhU3ZuHpjb+T9vAJ5pyRT1OxwScix/Ow4Ug0Jnenp6XkzGYjSbzZrjc5YUVaX+/v4InNj32rbkAMhPdHd3v5ImopSZnW3EzM56ZvYzZXZ/12Kwjssyi5Ag4oolMmMQ2w7ylxFcJKlMhlLpRqQzM+QPBGhwaIj4t/E950zHE4TWRVFrz7fDzPazvHMxIpGWSgOpBiTTaRrxB/ioPW5vb299MzhU4WfGOF5/mo5T344T1tqxu3OnII6ToiUN0EhNJsk3MsJH7T99FyzC/Wawwu8UTduTMzk1xe2YQG3zduCLde/d8DDJqkYJRWmAjOHyeH288xq5LqLDZmsdcLsrHGPMSygqjYZCLPq56Tyg+LGurq7nwY8faRrHTkdcVuiDx3PgJQMnWlwD7jLH1ueOo5W9vb0jqH3eVAAHIPB4l93+zB8I0hR6+AnDNPz+g6UbDiLuOV0DZc7hXAHfBJD7UPOiJXI9iEXY7XYHDxuT88BZLYA2tjpdrkpYEOn/HfILVnMb4pB4FE44IKTprxr6/QCtfIsa536I/DDpt3HgOxUz2hv8GzhOAAAAAElFTkSuQmCC' },
        decrease: { view: "0 0 512 512", svg: "<g> <path d=\"M256,488.7V512c141.4,0,256-114.6,256-256C512,114.6,397.4,0,256,0C114.6,0,0,114.6,0,256c0,141.4,114.6,256,256,256V488.7 v-23.3c-57.9,0-110.1-23.4-148.1-61.3C70,366.1,46.6,313.9,46.5,256c0-57.9,23.4-110.1,61.3-148.1c38-37.9,90.2-61.3,148.1-61.3 c57.9,0,110.1,23.4,148.1,61.3c37.9,38,61.3,90.2,61.3,148.1c0,57.9-23.4,110.1-61.3,148.1c-38,37.9-90.2,61.3-148.1,61.3V488.7z M116.4,279.3h279.3v-46.5H116.4V279.3z\"/> </g>" },
        ea_drilldown: { view: "0 0 48 48", svg: "<path d=\"m18.75 36-2.15-2.15 9.9-9.9-9.9-9.9 2.15-2.15L30.8 23.95Z\"/>" },
        ea_map: { png: 'data:image/png;base64,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' },
        edit: { png: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAMAAABg3Am1AAAAV1BMVEUAAAAgIGAaJmYYMW0VK2oYKGgVK2oYLGkWLGsWLGoXK2sWLGkWLGsXLGsXLGoYK2kYLGoXK2oXK2oXK2oXK2oXK2oXK2oXK2oXK2oXK2oXK2oXK2r///8pP0qPAAAAG3RSTlMACBQVGCBIS1FSWGhpbm93gJrP0dLW3+X4+vysKRQQAAAAnElEQVRIx+3UsRKCMBAE0EUEQQUlUTHu//+nRW6gcXRPG4ts/XZyF4YAJS9TjdNYOXwdSIZa9xeS5HWrFo7MCfJUZ2sM0jzt2pik+VO/NAZt36Uh7JDv57EHcGLcfPaRTLOdcRB919ysIXqgmcnUivt2AHZ36Sv/5JX7+Tcfv/R9Kr54INqfq3qQdHmQdPlccHjYAy17eD28vuR9nkTIHgdXsEMBAAAAAElFTkSuQmCC' },
        expand_less: { view: "0 96 960 960", svg: "<path d=\"m283 711-43-43 240-240 240 239-43 43-197-197-197 198Z\"/>" },
        expand_more: { view: "0 96 960 960", svg: "<path d=\"M480 711 240 471l43-43 197 198 197-197 43 43-240 239Z\"/>" },
        filter: { png: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAADn0lEQVRYw+2Xz2tdRRTHPzP3vpfEvAqKqN2JWfhrYTduRHHjTnDnX+CvrS5EBUWEJo2FbgpSiV3oQkFcuCvisqKIC7G8mjZtEm9+NHkvbRKT9/vNzDku5r40lrR9edSI0IHL3Dtczvncc77nzFy4O/7jYfZabH/xzGzyyINjiAUsGAskYC0ooAGQfNZ4LwEIaG995x2P6WwQKtuN4TeqpRt9pXsBJI8/PJY+PQbOgCmASeNsi5FZfX653LEHyZ/Vo9oF7cb10MJsVDDFzuhevtK94xKiAW/AKBiJswVsIUKIBTWgeZTU0ouY0QTVNL7XqEC7DkmRvgHC5bWqwT6kPndkknjZJKbCWFDZFWYBQr4m8ct769tVjBQIm4n0DeAvVF6Sq7Uvi8899pQpFkFzAJP+c+7lugdCiCnRAEbR2jwMNwmLQ1WXmbf6FiFA/b3Drwy9+MTp9Mij9xLSXTpIr+uCniDdjgiR6JzGAmxfQGqB7s86NfJO9uZefuzNAEqTq9+6X7NvpLoJNkBwUWjiQfJ7JepATK6HHK5RgdocAG7GLIZNTt3Mj71VjWq985H7ZW4W38m/zu+qAB9zbGwemWFQhfqfULsIqRJWLCGTE6WJ7PeBAEYnrqyGbP1dV15WhswuoRGd0SvTBNw61MrQnIOCRVsJ3bL7XoVP992IbhyNybHPh18+8po9/AB0kqgDbIQITQgb0K2Cb8aIJEr3p9o1d6nzQunowvStbKd99cut9ofu7PSThefve9YW83o3JhdgB6yBpADJCBQVX67h57tv3875bVOwk4pjVyp+qf6+/21pi9YytFagVQG3lesi7xcjKXLV48r1KbryVT+2bb+bRml86axfSE6GioGCuZ49JZZeEqAruHO1afnLnxidWNQ7CgAgDabcjP6ozQBWQHobj4AV/MVtH7LWeGly6VK/NvcFcOhYthyqTPo5qcf8hwiRKrLWxpW3v1YfvtuPTbvf/bt0NDvjLnNa1oKH2IK1HXDl5oysh+OliaXWvwoAoE2Ou1lm8AImIKuddpjvnCp9svjHfm0NBFA6lq1qS1fUxY1HG76mQnkQWymDDqupIhAsGCzWFA8WoFd+alBN+u6qdyQFO01c81JEBg/k4OdZHYlHtwCiBw+gLXNea4qxLj+GHTiA/aB7/p4fZMNgEtF4DDpAgNGPs2pYT1/tnBs5I9fM/SbV4gFrAA6Nzy/rVvK6Xyl8hiW5+5/3vxx/A7YnBnVt37YGAAAAAElFTkSuQmCC' },
        hide_additional: { view: "0 -960 960 960", svg: "<path d=\"m290-85-42-42 232-232 232 232-42 42-190-190L290-85Zm190-517L248-834l42-42 190 190 190-190 42 42-232 232Z\"/>" },
        increase: { view: "131 -131 512 512", svg: "<g> <path d=\"M412.8-2.6H362V100H259.4v50.9H362v102.6h50.9V150.8h102.6V100H412.8V-2.6z M387-131 c-141.3,0-256,114.7-256,256s114.7,256,256,256s256-114.7,256-256S528.3-131,387-131z M387,329.3c-113.1,0-204.3-91.3-204.3-204.3 S273.9-79.3,387-79.3S591.3,11.9,591.3,125S500.1,329.3,387,329.3z\"/> </g>" },
        make_read: { view: "0 0 48 48", svg: "<g> <path d=\"M38.5,13.2c-0.5-0.4-0.9-0.7-1.4-1.1C33.3,9.4,28.9,8,24,8s-9.3,1.4-13.2,4.2C6.9,15,3.9,18.5,2,23 c1.9,4.5,4.9,8.1,8.8,10.8C14.7,36.5,19.1,38,24,38c4.7,0,9-1.3,12.9-3.9l0.4-5.6h-4.7L38.5,13.2z M30,29c-1.7,1.7-3.7,2.5-6,2.5 c-2.4,0-4.4-0.8-6-2.5c-1.7-1.7-2.5-3.7-2.5-6c0-2.4,0.8-4.4,2.5-6c1.7-1.7,3.7-2.5,6-2.5c2.4,0,4.4,0.8,6,2.5 c1.7,1.7,2.5,3.7,2.5,6C32.5,25.4,31.7,27.4,30,29z\"/> <path d=\"M24,17.4c-1.6,0-2.9,0.5-4,1.6s-1.6,2.4-1.6,4s0.5,2.9,1.6,4s2.4,1.6,4,1.6s2.9-0.5,4-1.6s1.6-2.4,1.6-4s-0.5-2.9-1.6-4 S25.6,17.4,24,17.4z\"/> <polygon points=\"45.6,21.2 41.4,21.2 42,12.7 37.1,25.5 40.6,25.5 40,33.2 \"/> </g>" },
        make_unread: { view: "0 0 48 48", svg: "<g> <polygon points=\"45.6,21.2 41.4,21.2 42,12.7 37.1,25.5 40.6,25.5 40,33.2 \"/> <path d=\"M24,35c-4,0-7.7-1.1-11.1-3.3c-3.4-2.2-6-5.1-7.8-8.7c1.8-3.6,4.4-6.5,7.8-8.7C16.3,12.1,20,11,24,11s7.7,1.1,11.1,3.3 c0.9,0.6,1.7,1.2,2.4,1.8l1.1-2.9c-0.5-0.4-0.9-0.7-1.4-1.1C33.3,9.4,28.9,8,24,8s-9.3,1.3-13.2,4.1C6.9,14.9,3.9,18.5,2,23 c1.9,4.5,4.9,8,8.8,10.8C14.7,36.6,19.1,38,24,38c4.8,0,9.1-1.4,12.9-4l0.3-3.8c-0.7,0.5-1.4,1.1-2.1,1.5C31.7,33.9,28,35,24,35z\" /> <path d=\"M18,17c-1.7,1.6-2.5,3.7-2.5,6s0.8,4.4,2.5,6c1.6,1.7,3.6,2.5,6,2.5s4.4-0.8,6-2.5c1.7-1.6,2.5-3.7,2.5-6s-0.8-4.4-2.5-6 c-1.6-1.7-3.7-2.5-6-2.5S19.6,15.3,18,17z M29.6,23c0,1.6-0.5,2.9-1.6,4s-2.4,1.6-4,1.6s-2.9-0.5-4-1.6s-1.6-2.4-1.6-4 s0.5-2.9,1.6-4s2.4-1.6,4-1.6s2.9,0.5,4,1.6S29.6,21.4,29.6,23z\"/> </g>" },
        menu: { view: "0 0 24 24", svg: "<path d=\"M0 0h24v24H0V0z\" fill=\"none\"/><path d=\"M3 18h18v-2H3v2zm0-5h18v-2H3v2zm0-7v2h18V6H3z\"/>" },
        more: { view: "0 0 48 48", svg: "<path d=\"M10.4 26.4q-1 0-1.7-.7T8 24q0-1 .7-1.7t1.7-.7q1 0 1.7.7t.7 1.7q0 1-.7 1.7t-1.7.7Zm13.6 0q-1 0-1.7-.7t-.7-1.7q0-1 .7-1.7t1.7-.7q1 0 1.7.7t.7 1.7q0 1-.7 1.7t-1.7.7Zm13.6 0q-1 0-1.7-.7t-.7-1.7q0-1 .7-1.7t1.7-.7q1 0 1.7.7T40 24q0 1-.7 1.7t-1.7.7Z\"/>" },
        multiselect: { view: "0 0 48 48", svg: "<path d=\"M9 42q-1.25 0-2.125-.875T6 39V9q0-1.25.875-2.125T9 6h30q.7 0 1.275.3t.925.7L39 9.2V9H9v30h30V21.85l3-3V39q0 1.25-.875 2.125T39 42Zm14.05-8.4-11.1-11.1 2.1-2.1 9 9 19.1-19.1 2.1 2.1Z\"/>" },
        person: { view: "0 0 24 24", svg: "<path d=\"M0 0h24v24H0V0z\" fill=\"none\"/><path d=\"M12 5.9c1.16 0 2.1.94 2.1 2.1s-.94 2.1-2.1 2.1S9.9 9.16 9.9 8s.94-2.1 2.1-2.1m0 9c2.97 0 6.1 1.46 6.1 2.1v1.1H5.9V17c0-.64 3.13-2.1 6.1-2.1M12 4C9.79 4 8 5.79 8 8s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm0 9c-2.67 0-8 1.34-8 4v3h16v-3c0-2.66-5.33-4-8-4z\"/>" },
        refresh: { png: 'data:image/png;base64,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' },
        salesperson_half_on: { view: "0 -960 960 960", svg: "<path d=\"m637-244-42-178 138-120-182-16-71-168v387l157 95ZM233-120l65-281L80-590l288-25 112-265 112 265 288 25-218 189 65 281-247-149-247 149Z\"/>" },
        search: { png: 'data:image/png;base64,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' },
        selected_only_off: { view: "0 -960 960 960", svg: "<path d=\"m576-160-42-42 111-111-111-111 42-42 111 111 111-111 42 42-111 111 111 111-42 42-111-111-111 111Zm83-374L517-676l42-42 100 99 179-179 42 43-221 221ZM80-290v-60h360v60H80Zm0-320v-60h360v60H80Z\"/>" },
        selected_only_on: { view: "0 -960 960 960", svg: "<path d=\"M659-214 517-356l42-42 100 99 179-179 42 43-221 221Zm0-320L517-676l42-42 100 99 179-179 42 43-221 221ZM80-290v-60h360v60H80Zm0-320v-60h360v60H80Z\"/>" },
        show_additional: { view: "0 -960 960 960", svg: "<path d=\"M480-80 240-320l44-44 196 196 196-196 44 44L480-80ZM284-596l-44-44 240-240 240 240-44 44-196-196-196 196Z\"/>" },
        signature: { png: 'data:image/png;base64,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' },
        signature_no_sig: { png: 'data:image/png;base64,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' },
        unread_filter_off: { view: "0 0 48 48", svg: "<path d=\"M24,31.5c2.4,0,4.4-0.8,6-2.5c1.7-1.6,2.5-3.7,2.5-6s-0.8-4.4-2.5-6c-1.6-1.7-3.7-2.5-6-2.5s-4.4,0.8-6,2.5 c-1.7,1.6-2.5,3.7-2.5,6s0.8,4.4,2.5,6C19.6,30.7,21.6,31.5,24,31.5z M24,28.6c-1.6,0-2.9-0.5-4-1.6c-1.1-1.1-1.6-2.4-1.6-4 s0.5-2.9,1.6-4c1.1-1.1,2.4-1.6,4-1.6s2.9,0.5,4,1.6c1.1,1.1,1.6,2.4,1.6,4s-0.5,2.9-1.6,4C26.9,28.1,25.6,28.6,24,28.6z M24,38 c-4.9,0-9.3-1.4-13.2-4.2S3.9,27.5,2,23c1.9-4.5,4.9-8.1,8.8-10.9S19.1,8,24,8s9.3,1.4,13.2,4.1S44.1,18.5,46,23 c-1.9,4.5-4.9,8.1-8.8,10.8S28.9,38,24,38z M24,35c4,0,7.7-1.1,11.1-3.3s6-5.1,7.7-8.7c-1.8-3.6-4.3-6.5-7.7-8.7S28,11,24,11 s-7.7,1.1-11.1,3.3s-6,5.1-7.8,8.7c1.8,3.6,4.4,6.5,7.8,8.7S20,35,24,35z\"/>" },
        unread_filter_on: { view: "0 0 48 48", svg: "<path d=\"m31.45 27.05-2.2-2.2q1.3-3.55-1.35-5.9-2.65-2.35-5.75-1.2l-2.2-2.2q.85-.55 1.9-.8 1.05-.25 2.15-.25 3.55 0 6.025 2.475Q32.5 19.45 32.5 23q0 1.1-.275 2.175-.275 1.075-.775 1.875Zm6.45 6.45-2-2q2.45-1.8 4.275-4.025Q42 25.25 42.85 23q-2.5-5.55-7.5-8.775Q30.35 11 24.5 11q-2.1 0-4.3.4-2.2.4-3.45.95L14.45 10q1.75-.8 4.475-1.4Q21.65 8 24.25 8q7.15 0 13.075 4.075Q43.25 16.15 46 23q-1.3 3.2-3.35 5.85-2.05 2.65-4.75 4.65Zm2.9 11.3-8.4-8.25q-1.75.7-3.95 1.075T24 38q-7.3 0-13.25-4.075T2 23q1-2.6 2.775-5.075T9.1 13.2L2.8 6.9l2.1-2.15L42.75 42.6ZM11.15 15.3q-1.85 1.35-3.575 3.55Q5.85 21.05 5.1 23q2.55 5.55 7.675 8.775Q17.9 35 24.4 35q1.65 0 3.25-.2t2.4-.6l-3.2-3.2q-.55.25-1.35.375T24 31.5q-3.5 0-6-2.45T15.5 23q0-.75.125-1.5T16 20.15Zm15.25 7.1Zm-5.8 2.9Z\"/>" }
    };

    var PICTURE_TYPES = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', svg: 'image/svg+xml' };

    var LOOKUP_FAILED = 'The lookup failed.';
    var LOOKUP_EMPTY = 'No matching records.';
    var LOOKUP_MORE = 'More';
    var LOOKUP_PAGE = 50;
    var SEARCH_LABEL = 'Search';
    var CANCEL_LABEL = 'Cancel';
    var PAD_CLEAR = 'Clear';
    var PAD_SAVE = 'Save';
    var PAD_EMPTY = 'Sign in the box first.';
    var SIGNATURE_FILE = 'signature.png';
    var NEXT_LABEL = 'Next';
    var BACK_LABEL = 'Back';
    var FINISH_LABEL = 'Finish';
    var STAGE_DONE = ' (done)';
    var MARK_MANDATORY = ' *';
    var MARK_INSERT = ' +';
    var NOT_NUMBER = 'Enter a number.';
    var MANDATORY_BLANK = 'This field is mandatory.';
    var WRITES_ON = 'Writes are on. Buttons, edits and scans change data in ';
    var WRITES_ON_ANY = 'this environment';
    var NOT_WHOLE = 'Enter a whole number.';
    var AT_LEAST = 'The value must be at least ';
    var AT_MOST = 'The value must be at most ';
    var NEW_LABEL = 'New';
    var NEW_SUB = 'New record';
    var SAVE_LABEL = 'Save';
    var SAVED_LABEL = 'Saved.';
    var DONE_LABEL = 'Done.';
    var SAVE_FIRST = 'Save the record first.';
    var NEW_BLOB_NOTE = 'Save the record to add a picture.';
    var TOAST_MS = 3000;
    var DIALOG_COMMANDS = ['MI', 'MC', 'MT', 'MB'];
    var DIALOG_BUTTONS = {
        Ok: [['OK', 'Ok']],
        OkCancel: [['OK', 'Ok'], ['Cancel', 'Cancel']],
        YesNo: [['Yes', 'Yes'], ['No', 'No']],
        YesNoCancel: [['Yes', 'Yes'], ['No', 'No'], ['Cancel', 'Cancel']]
    };

    var stack = [];
    var queue = [];
    var banner = '';
    var download = null;
    var writesOn = false;
    var environmentName = '';
    var focusName = '';
    var unhandled = [];
    var toast = null;
    var toastTimer = null;
    var parts = null;

    function el(tag, className, text) {
        var node = document.createElement(tag);
        node.className = className;
        if (text !== undefined && text !== null) {
            node.appendChild(document.createTextNode(String(text)));
        }
        return node;
    }

    function clear(node) {
        while (node.firstChild) {
            node.removeChild(node.firstChild);
        }
    }

    function copyObject(source) {
        var target = {};
        for (var key in source) {
            if (source.hasOwnProperty(key)) {
                target[key] = source[key];
            }
        }
        return target;
    }

    function top() {
        return stack.length > 0 ? stack[stack.length - 1] : null;
    }

    // The entry a command or answer belongs to: its target when still on the stack, else the top screen.
    function contextEntry(target) {
        return target && stack.indexOf(target) >= 0 ? target : top();
    }

    // Turns a field name into the element form the commands use: spaces and dots become underscores,
    // repeats collapse, and leading and trailing underscores go.
    function convertName(name) {
        return String(name || '').trim().replace(/[ .]/g, '_').replace(/_+/g, '_').replace(/^_+|_+$/g, '');
    }

    function button(caption, className, onClick) {
        var node = el('button', className, caption);
        node.type = 'button';
        node.addEventListener('click', onClick);
        return node;
    }

    // An icon from ICON_PATHS in the current text colour. Filled glyphs fill, outlines stroke.
    function icon(name) {
        var glyph = ICON_PATHS[name];
        var svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('viewBox', glyph.view);
        svg.setAttribute('class', glyph.fill ? 'bjf-mn-emu-svg bjf-mn-emu-filled' : 'bjf-mn-emu-svg');
        svg.setAttribute('aria-hidden', 'true');
        var path = document.createElementNS(SVG_NS, 'path');
        path.setAttribute('d', glyph.d);
        svg.appendChild(path);
        return svg;
    }

    // A bundled app icon for a code, or null when the code is not one of the bundled icons.
    function bundledIcon(code) {
        if (!code || !Object.prototype.hasOwnProperty.call(APP_ICONS, code)) {
            return null;
        }
        var glyph = APP_ICONS[code];
        if (glyph.png) {
            var img = document.createElement('img');
            img.className = 'bjf-mn-emu-pic';
            img.alt = '';
            img.src = glyph.png;
            return img;
        }
        var svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('viewBox', glyph.view);
        svg.setAttribute('class', 'bjf-mn-emu-svg');
        svg.setAttribute('aria-hidden', 'true');
        svg.innerHTML = glyph.svg;
        return svg;
    }

    // The picture sent with a tile or a button, as an image, or null when there is none or its type is not shown.
    function pictureNode(entry) {
        if (!entry || !entry.picture || !Object.prototype.hasOwnProperty.call(PICTURE_TYPES, entry.pictureType)) {
            return null;
        }
        var img = document.createElement('img');
        img.className = 'bjf-mn-emu-pic';
        img.alt = '';
        img.src = 'data:' + PICTURE_TYPES[entry.pictureType] + ';base64,' + entry.picture;
        return img;
    }

    // The icon of a tile or a button: its picture, else its bundled app icon, else the neutral glyph.
    function actionIcon(entry) {
        return pictureNode(entry) || bundledIcon(entry && entry.icon) || icon('neutral');
    }

    // An icon-only button. The title is its name for a reader and for hover.
    function iconButton(name, title, className, onClick) {
        var node = el('button', className);
        node.type = 'button';
        node.title = title;
        node.setAttribute('aria-label', title);
        node.appendChild(icon(name));
        node.addEventListener('click', onClick);
        return node;
    }

    function disabledButton(caption, title) {
        var node = el('button', 'bjf-mn-emu-button', caption);
        node.type = 'button';
        node.disabled = true;
        node.title = title;
        return node;
    }

    // The request that loads an entry again, or null when there is nothing to load.
    function requestFor(entry) {
        if (!entry) {
            return null;
        }
        if (entry.response.isNew === true) {
            return entry.request ? copyObject(entry.request) : null;
        }
        if (entry.response.kind === 'card') {
            return { kind: 'card', service: entry.response.service, position: entry.response.position };
        }
        if (entry.request && entry.response.kind === 'list') {
            return copyObject(entry.request);
        }
        return null;
    }

    // A list the page opens by itself, such as the start list of the emulator, has no request in the queue.
    // Its toolbar sends search, sort and paging requests, so it gets the minimal list request for its service.
    function requestFromAnswer(response) {
        if (response.kind === 'list') {
            return { kind: 'list', service: response.service || '' };
        }
        return null;
    }

    // Sends a request to the page. mode says what the answer does to the stack. target is the entry the
    // answer belongs to. then, when given, runs with the answer after it is stored. Answers come back in
    // the order the requests went out, so the queue pairs each answer with its request.
    function send(request, mode, target, then) {
        if (request.kind === 'card') {
            request.live = true;
        }
        queue.push({ request: request, mode: mode, target: target || null, then: then || null });
        window.ShowMessage(LOADING);
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('Request', [JSON.stringify(request)]);
    }

    // Creates the frame on first use and keeps references to the parts that change.
    function getParts() {
        if (parts) {
            return parts;
        }
        var host = document.getElementById('controlAddIn');
        host.style.margin = '0';
        host.style.padding = '0';
        host.style.height = '100%';
        host.style.overflow = 'hidden';
        if (!document.getElementById(STYLE_ID)) {
            var style = document.createElement('style');
            style.id = STYLE_ID;
            style.appendChild(document.createTextNode(CSS));
            document.head.appendChild(style);
        }
        var root = el('div', 'bjf-mn-emu-root');
        var frame = el('div', 'bjf-mn-emu-frame');
        var bar = el('div', 'bjf-mn-emu-bar');
        var writes = el('div', 'bjf-mn-emu-writes');
        writes.style.display = 'none';
        var strip = el('div', 'bjf-mn-emu-strip');
        strip.style.display = 'none';
        var content = el('div', 'bjf-mn-emu-content');
        frame.appendChild(bar);
        frame.appendChild(writes);
        frame.appendChild(strip);
        frame.appendChild(content);
        var foot = el('div', 'bjf-mn-emu-foot');
        frame.appendChild(foot);
        root.appendChild(frame);
        host.appendChild(root);
        parts = { root: root, frame: frame, bar: bar, writes: writes, strip: strip, content: content, foot: foot };
        return parts;
    }

    // Keeps the state a card builds up from commands when a new card answer replaces it.
    function carryOver(old, neu) {
        if (old && old.response.kind === 'card' && neu.response.kind === 'card') {
            neu.overrides = old.overrides;
            neu.stageCode = old.stageCode;
            neu.hiddenStages = old.hiddenStages;
            neu.validatedStages = old.validatedStages;
            neu.previews = old.previews;
        }
    }

    // Puts an answer on the stack. push adds a screen. replace swaps the target entry, or the top one
    // when there is no target. A replace whose target has been closed is dropped. append adds rows to
    // the top list. Any other case, including a page answer with nothing pending, starts over.
    function store(entry, mode, target) {
        var last = top();
        var index = target ? stack.indexOf(target) : -1;
        if (mode === 'replace' && target && index < 0) {
            return false;
        }
        if (mode === 'replace' && last) {
            var at = index >= 0 ? index : stack.length - 1;
            carryOver(stack[at], entry);
            stack[at] = entry;
        } else if (mode === 'push' && last) {
            stack.push(entry);
        } else if (mode === 'append' && last) {
            last.response.rows = (last.response.rows || []).concat(entry.response.rows || []);
            last.response.hasMore = entry.response.hasMore;
            last.response.skip = entry.response.skip;
            last.response.top = entry.response.top;
        } else {
            stack = [entry];
        }
        return true;
    }

    // Reloads the top screen when a RP command marked it stale, once nothing waits for the page.
    function settle() {
        var entry = top();
        if (queue.length > 0 || !entry || !entry.stale) {
            return;
        }
        entry.stale = false;
        var request = requestFor(entry);
        if (request) {
            send(request, 'replace', entry);
        }
    }

    // The back chevron pops a screen. With one screen left it only clears an error banner, so the screen stays.
    function goBack() {
        if (stack.length > 1) {
            stack.pop();
        }
        banner = '';
        download = null;
        window.ShowMessage('');
        render();
        settle();
    }

    // The top bar as on the device: a back chevron at left on every screen but the menu, the page caption above
    // and the record title below, centred, and a menu icon at right. The menu sheet holds Refresh and, on a list,
    // the sort and the filter panel.
    function renderBar(bar, entry) {
        clear(bar);
        var canBack = stack.length > 1;
        bar.appendChild(canBack ? iconButton('back', BACK_LABEL, 'bjf-mn-emu-icon bjf-mn-emu-back', goBack) : el('span', 'bjf-mn-emu-slot'));
        var small = '';
        var main = 'MobileNAV';
        if (entry) {
            var response = entry.response;
            if (response.kind === 'menu') {
                small = response.profile ? 'MobileNAV (' + response.profile + ')' : 'MobileNAV';
                main = response.user || 'Menu';
            } else if (response.kind === 'card') {
                small = response.caption || 'MobileNAV';
                main = response.isNew === true ? NEW_SUB : (response.title || response.caption || 'MobileNAV');
            } else {
                main = response.caption || 'MobileNAV';
            }
        }
        var titles = el('div', 'bjf-mn-emu-titles');
        if (small) {
            titles.appendChild(el('div', 'bjf-mn-emu-sub', small));
        }
        titles.appendChild(el('div', 'bjf-mn-emu-title' + (entry && entry.response.kind === 'card' ? ' bjf-mn-emu-record' : ''), main));
        bar.appendChild(titles);
        bar.appendChild(iconButton('menu', MENU_LABEL, 'bjf-mn-emu-icon bjf-mn-emu-hamburger', function () {
            toggleMenu(entry);
        }));
    }

    // The filter panel of the list on screen, or null. The menu sheet toggles it.
    var filterPanel = null;

    // The menu sheet node while it is open, or null.
    var menuNode = null;

    // Closes the menu sheet. Every render closes it, so a picked item never leaves it open.
    function closeMenu() {
        if (menuNode && menuNode.parentNode) {
            menuNode.parentNode.removeChild(menuNode);
        }
        menuNode = null;
    }

    // Opens the menu sheet under the top bar, or closes it when it is open.
    function toggleMenu(entry) {
        if (menuNode) {
            closeMenu();
            return;
        }
        menuNode = menuSheet(entry);
        getParts().frame.appendChild(menuNode);
    }

    // The menu sheet: Refresh, and on a list the sort key, the direction and the filter panel. The sort controls
    // send the list again, as they did in the toolbar.
    function menuSheet(entry) {
        var sheet = el('div', 'bjf-mn-emu-menu');
        var canRefresh = !!entry && entry.response.isNew !== true && requestFor(entry) !== null;
        var refresh = button(REFRESH_LABEL, 'bjf-mn-emu-menu-item bjf-mn-emu-refresh', function () {
            closeMenu();
            var next = requestFor(entry);
            if (next) {
                send(next, 'replace', entry);
            }
        });
        refresh.disabled = !canRefresh;
        sheet.appendChild(refresh);
        if (!entry || entry.response.kind !== 'list') {
            return sheet;
        }
        var request = entry.request || {};
        var response = entry.response;
        var keys = response.keys || [];
        if (keys.length > 0) {
            var sortSelect = el('select', 'bjf-mn-emu-select');
            for (var i = 0; i < keys.length; i++) {
                var option = el('option', '', keys[i].caption);
                option.value = String(keys[i].no);
                sortSelect.appendChild(option);
            }
            sortSelect.value = String(response.sortKey);
            sortSelect.addEventListener('change', function () {
                var next = copyObject(request);
                next.sortKey = Number(sortSelect.value);
                next.skip = 0;
                send(next, 'replace');
            });
            sheet.appendChild(el('span', 'bjf-mn-emu-menu-label', SORT_LABEL));
            sheet.appendChild(sortSelect);
            sheet.appendChild(button(response.ascending ? 'Ascending' : 'Descending', 'bjf-mn-emu-menu-item', function () {
                var next = copyObject(request);
                next.ascending = !response.ascending;
                next.skip = 0;
                send(next, 'replace');
            }));
        }
        sheet.appendChild(button(FILTERS_LABEL, 'bjf-mn-emu-menu-item', function () {
            closeMenu();
            if (filterPanel) {
                filterPanel.style.display = filterPanel.style.display === 'none' ? 'block' : 'none';
            }
        }));
        return sheet;
    }

    function openTile(tile) {
        // A dialog page gets no main menu action from MobileNAV, so its page type alone opens the form.
        if (tile.mainMenuAction === 'Create' || tile.pageType === 'Report') {
            send({ kind: 'newCard', service: tile.service }, 'push');
            return;
        }
        if (tile.pageType === 'Card') {
            send({ kind: 'card', service: tile.service }, 'push');
            return;
        }
        send({ kind: 'list', service: tile.service }, 'push');
    }

    function makeTile(tile) {
        var node = el('div', 'bjf-mn-emu-tile');
        node.tabIndex = 0;
        node.setAttribute('role', 'button');
        node.appendChild(actionIcon(tile));
        node.appendChild(el('span', '', tile.caption));
        node.addEventListener('click', function () {
            openTile(tile);
        });
        node.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.key === ' ' || event.keyCode === 13 || event.keyCode === 32) {
                event.preventDefault();
                openTile(tile);
            }
        });
        return node;
    }

    // A group header is a white bar with the group name and a chevron. It opens and closes the blue tile area
    // under it. The first group opens at first and the others start closed.
    function groupHeader(caption, grid, open) {
        var header = el('button', 'bjf-mn-emu-cat bjf-mn-emu-collapsible');
        header.type = 'button';
        header.appendChild(el('span', '', caption));
        header.appendChild(icon(open ? 'chevron_up' : 'chevron_down'));
        header.setAttribute('aria-expanded', open ? 'true' : 'false');
        header.addEventListener('click', function () {
            grid.hidden = !grid.hidden;
            header.replaceChild(icon(grid.hidden ? 'chevron_down' : 'chevron_up'), header.lastChild);
            header.setAttribute('aria-expanded', grid.hidden ? 'false' : 'true');
        });
        return header;
    }

    function renderMenu(content, response) {
        var categories = response.categories || [];
        if (categories.length === 0) {
            content.appendChild(el('div', 'bjf-mn-emu-empty', 'No tiles for this user.'));
            return;
        }
        for (var i = 0; i < categories.length; i++) {
            var category = categories[i];
            var tiles = category.tiles || [];
            var grid = el('div', 'bjf-mn-emu-grid');
            grid.hidden = i > 0;
            content.appendChild(groupHeader(category.caption, grid, i === 0));
            for (var j = 0; j < tiles.length; j++) {
                grid.appendChild(makeTile(tiles[j]));
            }
            content.appendChild(grid);
        }
    }

    // The RI: entry of the row's FieldControl text, which is a comma list, holds the icon name.
    function iconName(fieldControl) {
        var entries = String(fieldControl || '').split(',');
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].indexOf('RI:') === 0) {
                return entries[i].substring(3);
            }
        }
        return '';
    }

    // A line shows its text left. A tab splits the line into a left and a right value, so the right value sits at
    // the right edge. The layout colour, when given, goes on the whole line. A right colour goes on the right value.
    function lineNode(className, text, colour, rightColour) {
        var node = el('div', className);
        var pieces = String(text === null || text === undefined ? '' : text).split('\t');
        node.appendChild(el('span', 'bjf-mn-emu-lft', pieces[0]));
        if (pieces.length > 1) {
            var right = el('span', 'bjf-mn-emu-rgt', pieces.slice(1).join(' '));
            if (rightColour) {
                right.style.color = rightColour;
            }
            node.appendChild(right);
        }
        if (colour) {
            node.style.color = colour;
        }
        return node;
    }

    // A chevron at the right of a row that opens something.
    function drillChevron() {
        var chevron = el('span', 'bjf-mn-emu-drillicon');
        chevron.appendChild(icon('drill'));
        return chevron;
    }

    // A row takes its layout colours on its lines and background, and its layout row icon when it has one.
    // Odd rows take the blue highlight. A list row with a card opens it on a click.
    function makeRow(row, cardService, alt) {
        var layout = row.layout || {};
        var colors = layout.colors || {};
        var node = el('div', 'bjf-mn-emu-row' + (alt ? ' bjf-mn-emu-alt' : '') + (cardService ? ' bjf-mn-emu-open' : ''));
        if (colors.background) {
            node.style.background = colors.background;
        }
        var text = el('div', 'bjf-mn-emu-rowtext');
        // The cells: top left and right, middle left and right, bottom left and right. A colour of the cell wins over
        // the colour of the first or second line.
        text.appendChild(lineNode('bjf-mn-emu-line1', row.line1, colors.topLeft || colors.firstLine, colors.topRight));
        if (row.line2) {
            text.appendChild(lineNode('bjf-mn-emu-line2', row.line2, colors.middleLeft || colors.secondLine, colors.middleRight));
        }
        if (row.line3) {
            text.appendChild(lineNode('bjf-mn-emu-line3', row.line3, colors.bottomLeft, colors.bottomRight));
        }
        var iconText = layout.rowIcon || iconName(row.fieldControl);
        var rowIconNode = bundledIcon(iconText);
        if (rowIconNode) {
            text.appendChild(rowIconNode);
        } else if (iconText) {
            text.appendChild(el('span', 'bjf-mn-emu-tag', iconText));
        }
        node.appendChild(text);
        if (cardService) {
            node.tabIndex = 0;
            node.setAttribute('role', 'button');
            var openRow = function () {
                send({ kind: 'card', service: cardService, position: row.position }, 'push');
            };
            node.addEventListener('click', openRow);
            node.addEventListener('keydown', function (event) {
                if (event.key === 'Enter' || event.key === ' ' || event.keyCode === 13 || event.keyCode === 32) {
                    event.preventDefault();
                    openRow();
                }
            });
        }
        return node;
    }

    function filterValue(request, fieldName) {
        var filters = request.filters || [];
        for (var i = 0; i < filters.length; i++) {
            if (filters[i].field === fieldName) {
                return filters[i].value;
            }
        }
        return '';
    }

    // The filter panel: one text input per filter field, Apply and Clear.
    function makeFilterPanel(request, response) {
        var panel = el('div', 'bjf-mn-emu-panel');
        panel.style.display = 'none';
        var inputs = [];
        var fields = response.filterFields || [];
        if (fields.length === 0) {
            panel.appendChild(el('div', 'bjf-mn-emu-empty', 'This list has no filter fields.'));
            return panel;
        }
        for (var i = 0; i < fields.length; i++) {
            var input = el('input', 'bjf-mn-emu-input');
            input.type = 'text';
            input.value = filterValue(request, fields[i].field);
            panel.appendChild(el('div', 'bjf-mn-emu-flabel', fields[i].caption));
            panel.appendChild(input);
            inputs.push({ field: fields[i].field, input: input });
        }
        var actions = el('div', 'bjf-mn-emu-actions');
        actions.appendChild(button('Apply', 'bjf-mn-emu-button bjf-mn-emu-primary', function () {
            var filters = [];
            for (var j = 0; j < inputs.length; j++) {
                var value = inputs[j].input.value.trim();
                if (value !== '') {
                    filters.push({ field: inputs[j].field, value: value });
                }
            }
            var next = copyObject(request);
            next.filters = filters;
            next.skip = 0;
            send(next, 'replace');
        }));
        actions.appendChild(button('Clear', 'bjf-mn-emu-button', function () {
            var next = copyObject(request);
            for (var j = 0; j < inputs.length; j++) {
                inputs[j].input.value = '';
            }
            next.filters = [];
            next.skip = 0;
            send(next, 'replace');
        }));
        panel.appendChild(actions);
        return panel;
    }

    function renderToolbar(content, request, response) {
        var toolbar = el('div', 'bjf-mn-emu-toolbar');

        var search = el('input', 'bjf-mn-emu-search');
        search.type = 'search';
        search.placeholder = 'Search';
        search.value = request.search || '';
        search.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.keyCode === 13) {
                var next = copyObject(request);
                next.search = search.value;
                next.skip = 0;
                send(next, 'replace');
            }
        });
        toolbar.appendChild(search);
        if (response.insertAllowed === true) {
            toolbar.appendChild(button(NEW_LABEL, 'bjf-mn-emu-button bjf-mn-emu-primary', function () {
                openNew(request, response);
            }));
        }

        var saved = response.savedFilters || [];
        var savedSelect = el('select', 'bjf-mn-emu-select');
        savedSelect.appendChild(el('option', '', 'No saved filter'));
        savedSelect.firstChild.value = '';
        for (var k = 0; k < saved.length; k++) {
            var savedOption = el('option', '', saved[k].name);
            savedOption.value = saved[k].name;
            savedSelect.appendChild(savedOption);
        }
        savedSelect.value = request.savedFilter || '';
        savedSelect.addEventListener('change', function () {
            var next = copyObject(request);
            if (savedSelect.value === '') {
                delete next.savedFilter;
            } else {
                next.savedFilter = savedSelect.value;
            }
            next.skip = 0;
            send(next, 'replace');
        });
        toolbar.appendChild(savedSelect);

        var panel = makeFilterPanel(request, response);
        filterPanel = panel;
        content.appendChild(toolbar);
        content.appendChild(panel);
        if (response.appliedFilters) {
            content.appendChild(el('div', 'bjf-mn-emu-applied', response.appliedFilters));
        }
    }

    function renderList(content, entry) {
        var request = entry.request || {};
        var response = entry.response;
        renderToolbar(content, request, response);

        var rows = response.rows || [];
        if (rows.length === 0) {
            content.appendChild(el('div', 'bjf-mn-emu-empty', 'No records.'));
        }
        for (var i = 0; i < rows.length; i++) {
            content.appendChild(makeRow(rows[i], response.cardService, i % 2 === 0));
        }
        if (response.hasMore) {
            content.appendChild(button('More', 'bjf-mn-emu-button bjf-mn-emu-primary', function () {
                var next = copyObject(request);
                next.skip = (response.skip || 0) + (response.top || 0);
                send(next, 'append');
            }));
        }
    }

    function parentRequest(card, service, fieldName) {
        return {
            kind: 'list',
            service: service,
            parent: { service: card.service, position: card.position, field: fieldName }
        };
    }

    function isScanType(field) {
        var type = String(field.mobileType || '').toLowerCase();
        return type.indexOf('barcode') >= 0 || type.indexOf('scan') >= 0;
    }

    // Runs a button or action on a card. The answer does not change the stack. Its commands run next.
    // values go to the page function by parameter name. onResult, when given, sees the answer first.
    function sendAction(entry, fieldName, functionName, values, onResult) {
        var card = entry.response;
        send({
            kind: 'action',
            service: card.service,
            position: card.position,
            field: fieldName,
            functionName: functionName,
            values: values || {}
        }, 'none', entry, function (response) {
            if (response) {
                if (onResult) {
                    onResult(response);
                }
                runCommands(response.commands, entry, render);
            }
        });
    }

    // Writes one field through the page, runs the commands of the answer, then loads the card again at
    // the position the write returned.
    function sendUpdate(entry, fieldName, value) {
        var card = entry.response;
        send({
            kind: 'update',
            service: card.service,
            position: card.position,
            field: fieldName,
            value: value
        }, 'none', entry, function (response) {
            if (!response) {
                return;
            }
            runCommands(response.commands, entry, function () {
                reloadCard(entry, response.position);
            });
        });
    }

    // Loads the card again after a write. A staged card may then move on to its next stage.
    function reloadCard(entry, position) {
        if (stack.indexOf(entry) < 0) {
            // A command closed the card, so the screen under it is drawn here.
            render();
            settle();
            return;
        }
        send({
            kind: 'card',
            service: entry.response.service,
            position: position || entry.response.position
        }, 'replace', entry, function (response) {
            if (response) {
                autoNextStage(entry);
            }
        });
    }

    // Loads an entry again. Returns false when there is nothing to load, so the command does not wait.
    function refreshEntry(entry, next) {
        var request = requestFor(entry);
        if (!request) {
            return false;
        }
        send(request, 'replace', entry, function () {
            next();
        });
        return true;
    }

    function drillButton(card, field) {
        return button(OPEN_RELATED, 'bjf-mn-emu-drill', function () {
            send(parentRequest(card, field.drill.service, field.drill.field), 'push');
        });
    }

    // The state one card draws from: layout fields by name, stage state and whether writes are allowed.
    function makeView(entry) {
        var layout = entry.response.layout || {};
        var layoutFields = {};
        var names = Object.keys(layout.fields || {});
        entry.overrides = entry.overrides || {};
        for (var i = 0; i < names.length; i++) {
            layoutFields[convertName(names[i])] = layout.fields[names[i]] || {};
        }
        var pageReadOnly = layout.pageReadOnly === true;
        return {
            entry: entry,
            writes: entry.response.writesAllowed === true && !pageReadOnly,
            pageReadOnly: pageReadOnly,
            layoutFields: layoutFields,
            stage: stageInfo(entry),
            focusInput: null,
            isNew: entry.response.isNew === true,
            dialog: entry.response.isNew === true && entry.response.dialog === true,
            notes: {}
        };
    }

    // The rules for one field on a card. Stage token H hides the field on the current stage and R makes
    // it read-only. Read-only from the layout or the stage, and a read-only page, hold even when a command
    // makes the field editable. Everything else comes from the card's own commands.
    function fieldRules(view, field) {
        var key = convertName(field.name);
        var override = view.entry.overrides[key] || {};
        var layoutField = view.layoutFields[key] || {};
        var token = '';
        if (view.stage.enabled && view.stage.allIndex >= 0) {
            token = (field.stages || [])[view.stage.allIndex] || '';
        }
        var readOnly = override.readOnly === true || layoutField.readOnly === true || token === 'R' || view.pageReadOnly;
        return {
            hidden: override.hidden === true || layoutField.hidden === true || token === 'H',
            readOnly: readOnly,
            editable: view.writes && !readOnly && (override.editable === true || field.editable === true),
            caption: override.caption || layoutField.caption || field.caption,
            captionColor: override.captionColor || layoutField.captionColor || '',
            valueColor: override.valueColor || layoutField.valueColor || ''
        };
    }

    // The caption with * for a mandatory field and + for a field required on insert.
    function captionText(field, text) {
        var marks = '';
        if (field.mandatory === 'Mandatory') {
            marks += MARK_MANDATORY;
        }
        if (field.requiredForInsert === true) {
            marks += MARK_INSERT;
        }
        return text + marks;
    }

    // Reads a number as the device writes it: an optional sign, digits with comma groups, and a dot.
    // Returns NaN for anything else, so a value with a decimal comma is refused.
    function parseNumber(text) {
        var clean = String(text || '').replace(/\s/g, '');
        if (!/\d/.test(clean) || !/^[-+]?(\d{1,3}(,\d{3})+|\d*)(\.\d*)?$/.test(clean)) {
            return NaN;
        }
        return Number(clean.replace(/,/g, ''));
    }

    function isWholeNumber(text) {
        return /^[-+]?(\d{1,3}(,\d{3})+|\d+)$/.test(String(text || '').replace(/\s/g, ''));
    }

    // decimal or integer for the numeric field types, '' for every other field.
    function numericType(field) {
        var type = String(field.fieldType || '').toLowerCase();
        if (type.indexOf('decimal') >= 0) {
            return 'decimal';
        }
        if (type.indexOf('integer') >= 0) {
            return 'integer';
        }
        return '';
    }

    // The reason a typed value must not be sent, or '' when it can be sent. The emulator reads the minimum
    // and maximum values as plain numbers. A blank value is allowed, unless the field is mandatory.
    function refusal(field, text) {
        var type = numericType(field);
        if (type === '') {
            return '';
        }
        var trimmed = String(text || '').trim();
        if (trimmed === '') {
            return field.mandatory === 'Mandatory' ? MANDATORY_BLANK : '';
        }
        var number = parseNumber(trimmed);
        if (isNaN(number)) {
            return NOT_NUMBER;
        }
        if (type === 'integer' && !isWholeNumber(trimmed)) {
            return NOT_WHOLE;
        }
        var min = parseNumber(field.minValue);
        var max = parseNumber(field.maxValue);
        if (!isNaN(min) && number < min) {
            return AT_LEAST + field.minValue + '.';
        }
        if (!isNaN(max) && number > max) {
            return AT_MOST + field.maxValue + '.';
        }
        return '';
    }

    // Shows a decimal with at least N and at most M decimals, for a decimalPlaces text "N:M".
    function withDecimals(text, field) {
        var places = /^(\d+):(\d+)$/.exec(String(field.decimalPlaces || ''));
        var number = parseNumber(text);
        if (!places || numericType(field) !== 'decimal' || isNaN(number)) {
            return text;
        }
        var least = Math.min(Number(places[1]), 20);
        var most = Math.min(Number(places[2]), 20);
        var parts = number.toFixed(most).split('.');
        var fraction = parts[1] || '';
        while (fraction.length > least && fraction.charAt(fraction.length - 1) === '0') {
            fraction = fraction.substring(0, fraction.length - 1);
        }
        while (fraction.length < least) {
            fraction += '0';
        }
        return parts[0] + (fraction ? '.' + fraction : '');
    }

    // The stages of a card. A stage is hidden when the layout hides it or an SH command did. The current
    // stage is kept on the entry, and moves to the first visible stage when it is missing or hidden.
    function stageInfo(entry) {
        var card = entry.response;
        var staging = card.staging || {};
        var layout = card.layout || {};
        var all = staging.enabled === true ? (staging.stages || []) : [];
        var layoutHidden = layout.hiddenStages || [];
        entry.hiddenStages = entry.hiddenStages || {};
        entry.validatedStages = entry.validatedStages || {};
        var visible = [];
        var i;
        for (i = 0; i < all.length; i++) {
            if (layoutHidden.indexOf(all[i].code) < 0 && !entry.hiddenStages[all[i].code]) {
                visible.push(all[i]);
            }
        }
        var position = -1;
        for (i = 0; i < visible.length; i++) {
            if (visible[i].code === entry.stageCode) {
                position = i;
            }
        }
        if (position < 0) {
            position = visible.length > 0 ? 0 : -1;
            entry.stageCode = position === 0 ? visible[0].code : '';
        }
        var allIndex = -1;
        for (i = 0; i < all.length; i++) {
            if (all[i].code === entry.stageCode) {
                allIndex = i;
            }
        }
        return {
            enabled: all.length > 0,
            all: all,
            visible: visible,
            position: position,
            current: position >= 0 ? visible[position] : null,
            allIndex: allIndex,
            backNext: staging.backNextVisible !== false,
            autoNext: staging.autoNext === true
        };
    }

    // A stage is validated by an SSV or RSV command. Without one, the layout's StageValidated rules decide.
    function isStageValidated(entry, code) {
        var marks = entry.validatedStages || {};
        if (Object.prototype.hasOwnProperty.call(marks, code)) {
            return marks[code] === true;
        }
        return ((entry.response.layout || {}).validatedStages || []).indexOf(code) >= 0;
    }

    // The stage strip at the top of a staged card: one chip per visible stage, the current one highlighted.
    function stageStrip(entry, info) {
        var strip = el('div', 'bjf-mn-emu-stages');
        if (info.position >= 0 && info.position < info.visible.length) {
            var current = info.visible[info.position];
            strip.appendChild(el('div', 'bjf-mn-emu-stagename', current.caption || current.code));
        }
        for (var i = 0; i < info.visible.length; i++) {
            var stage = info.visible[i];
            var text = stage.caption || stage.code;
            if (isStageValidated(entry, stage.code)) {
                text += STAGE_DONE;
            }
            var className = 'bjf-mn-emu-stage';
            if (i === info.position) {
                className += ' bjf-mn-emu-current';
            } else if (i < info.position) {
                className += ' bjf-mn-emu-reached';
            }
            strip.appendChild(el('span', className, text));
        }
        return strip;
    }

    function moveStage(entry, index) {
        var info = stageInfo(entry);
        if (index < 0 || index >= info.visible.length) {
            return;
        }
        entry.stageCode = info.visible[index].code;
        render();
    }

    // Back and Next. Next reads Finish on the last visible stage and closes the card. On a new record Finish saves it first.
    function stageNav(view, info) {
        var entry = view.entry;
        var row = el('div', 'bjf-mn-emu-actions');
        if (info.backNext) {
            var back = button(BACK_LABEL, 'bjf-mn-emu-button', function () {
                var current = stageInfo(entry);
                moveStage(entry, current.position - 1);
            });
            back.disabled = info.position <= 0;
            row.appendChild(back);
        }
        var last = info.position >= info.visible.length - 1;
        row.appendChild(button(last ? FINISH_LABEL : NEXT_LABEL, 'bjf-mn-emu-button bjf-mn-emu-primary', function () {
            var current = stageInfo(entry);
            if (current.position >= current.visible.length - 1) {
                if (view.isNew) {
                    saveNew(view);
                    return;
                }
                if (closeCard(entry)) {
                    window.ShowMessage('');
                    render();
                    settle();
                }
            } else {
                moveStage(entry, current.position + 1);
            }
        }));
        return row;
    }

    // Removes a card from the stack. Returns false when the entry is not a card on the stack.
    function closeCard(entry) {
        var index = stack.indexOf(entry);
        if (index < 0 || entry.response.kind !== 'card') {
            return false;
        }
        stack.splice(index, 1);
        banner = '';
        download = null;
        return true;
    }

    function hideStage(entry, code) {
        if (!entry || entry.response.kind !== 'card' || !code) {
            return;
        }
        entry.hiddenStages = entry.hiddenStages || {};
        entry.hiddenStages[code] = true;
    }

    function setStageMark(entry, code, validated) {
        if (!entry || entry.response.kind !== 'card' || !code) {
            return;
        }
        entry.validatedStages = entry.validatedStages || {};
        entry.validatedStages[code] = validated;
    }

    // RS: the first visible stage with restartFrom set, else the first visible stage.
    function restartStage(entry) {
        if (!entry || entry.response.kind !== 'card') {
            return;
        }
        var info = stageInfo(entry);
        var target = null;
        for (var i = 0; i < info.visible.length; i++) {
            if (info.visible[i].restartFrom === true) {
                target = info.visible[i];
                break;
            }
        }
        if (!target && info.visible.length > 0) {
            target = info.visible[0];
        }
        if (target) {
            entry.stageCode = target.code;
        }
    }

    // Moves a staged card to the next visible stage once every mandatory editable field on the current
    // stage has a value. The emulator reads "every mandatory field" as the fields that are editable here.
    function autoNextStage(target) {
        var entry = contextEntry(target);
        if (!entry || entry.response.kind !== 'card') {
            return;
        }
        var view = makeView(entry);
        var info = view.stage;
        if (!info.enabled || !info.autoNext || info.position < 0) {
            return;
        }
        var groups = entry.response.groups || [];
        for (var i = 0; i < groups.length; i++) {
            var fields = groups[i].fields || [];
            for (var j = 0; j < fields.length; j++) {
                var field = fields[j];
                var rules = fieldRules(view, field);
                if (rules.hidden || !rules.editable || field.mandatory !== 'Mandatory') {
                    continue;
                }
                if (String(field.value || '') === '') {
                    return;
                }
            }
        }
        if (info.position + 1 < info.visible.length) {
            entry.stageCode = info.visible[info.position + 1].code;
            render();
        }
    }

    // The kind of picture a blob field takes: a signature, an image, or a file that downloads.
    function blobKind(field) {
        var type = String(field.mobileType || '').toLowerCase();
        if (type.indexOf('signature') >= 0) {
            return 'signature';
        }
        if (type.indexOf('image') >= 0) {
            return 'image';
        }
        return 'file';
    }

    // Pictures are kept per field and record position, so a card reload keeps the picture on screen.
    function previewKey(entry, key) {
        return key + '@' + (entry.response.position || '');
    }

    // Image bytes come back as base64. The type is read from the first characters.
    function imageSource(base64) {
        var mime = 'image/png';
        if (base64.indexOf('/9j/') === 0) {
            mime = 'image/jpeg';
        } else if (base64.indexOf('R0lG') === 0) {
            mime = 'image/gif';
        }
        return 'data:' + mime + ';base64,' + base64;
    }

    // Keeps the picture of a blob field. An empty text or -1 means the page holds no picture.
    function setPreview(entry, key, base64) {
        var clean = String(base64 || '').replace(/\s/g, '');
        entry.previews = entry.previews || {};
        entry.previews[previewKey(entry, key)] = clean === '' || clean === '-1' ? '' : clean;
    }

    // The buttons of a blob field, and its picture when one is kept. Every call goes to the page function.
    function blobBox(view, field, key) {
        var entry = view.entry;
        var kind = blobKind(field);
        var wrap = el('div', 'bjf-mn-emu-blob');
        var stored = entry.previews ? entry.previews[previewKey(entry, key)] : undefined;
        if (stored === '') {
            wrap.appendChild(el('div', 'bjf-mn-emu-line2', BLOB_NONE));
        } else if (stored) {
            var image = el('img', 'bjf-mn-emu-preview');
            image.src = imageSource(stored);
            image.alt = field.caption || field.name;
            wrap.appendChild(image);
        }
        var actions = el('div', 'bjf-mn-emu-actions');
        if (kind === 'file') {
            actions.appendChild(actionButton(view, BLOB_DOWNLOAD, field.name, field.functionName, { action: 'EXP' }));
        } else {
            actions.appendChild(actionButton(view, BLOB_SHOW, field.name, field.functionName, { action: 'EXP' }, function (response) {
                setPreview(entry, key, response.base64Result);
            }));
        }
        if (kind === 'image') {
            actions.appendChild(uploadButton(view, field, key));
        }
        if (kind === 'signature') {
            if (view.writes) {
                actions.appendChild(button(BLOB_SIGN, 'bjf-mn-emu-button', function () {
                    openSignaturePad(entry, field, key);
                }));
            } else {
                actions.appendChild(disabledButton(BLOB_SIGN, WRITES_OFF));
            }
        }
        wrap.appendChild(actions);
        return wrap;
    }

    // Sends a picture to the page with the IMP action, and keeps it on screen.
    function sendImport(entry, field, key, base64, fileName) {
        sendAction(entry, field.name, field.functionName, { action: 'IMP', base64Result: base64, fileName: fileName }, function () {
            setPreview(entry, key, base64);
        });
    }

    // The upload button of an image field: a file picker, then the chosen file goes to the page.
    function uploadButton(view, field, key) {
        if (!view.writes) {
            return disabledButton(BLOB_UPLOAD, WRITES_OFF);
        }
        return button(BLOB_UPLOAD, 'bjf-mn-emu-button', function () {
            var input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.addEventListener('change', function () {
                var file = input.files && input.files[0];
                if (!file) {
                    return;
                }
                var reader = new FileReader();
                reader.onload = function () {
                    var text = String(reader.result || '');
                    sendImport(view.entry, field, key, text.substring(text.indexOf(',') + 1), file.name);
                };
                reader.readAsDataURL(file);
            });
            input.click();
        });
    }

    // A pad to draw a signature in. Save sends the drawing as a PNG through the page's import action.
    function openSignaturePad(entry, field, key) {
        var frame = getParts().frame;
        var overlay = el('div', 'bjf-mn-emu-overlay');
        var box = el('div', 'bjf-mn-emu-dialog');
        var canvas = document.createElement('canvas');
        canvas.className = 'bjf-mn-emu-pad';
        canvas.width = 300;
        canvas.height = 150;
        var context = canvas.getContext('2d');
        var note = el('div', 'bjf-mn-emu-dtext', '');
        var drawing = false;
        var drawn = false;
        var last = null;

        function clearPad() {
            context.fillStyle = '#ffffff';
            context.fillRect(0, 0, canvas.width, canvas.height);
            context.lineWidth = 2;
            context.lineCap = 'round';
            context.strokeStyle = '#212121';
            drawn = false;
            note.textContent = '';
        }

        function pointAt(event) {
            var rect = canvas.getBoundingClientRect();
            return {
                x: (event.clientX - rect.left) * canvas.width / rect.width,
                y: (event.clientY - rect.top) * canvas.height / rect.height
            };
        }

        function endStroke() {
            drawing = false;
        }

        canvas.addEventListener('pointerdown', function (event) {
            drawing = true;
            last = pointAt(event);
            canvas.setPointerCapture(event.pointerId);
        });
        canvas.addEventListener('pointermove', function (event) {
            if (!drawing) {
                return;
            }
            var point = pointAt(event);
            context.beginPath();
            context.moveTo(last.x, last.y);
            context.lineTo(point.x, point.y);
            context.stroke();
            last = point;
            drawn = true;
        });
        canvas.addEventListener('pointerup', endStroke);
        canvas.addEventListener('pointercancel', endStroke);
        clearPad();

        function close() {
            if (overlay.parentNode) {
                overlay.parentNode.removeChild(overlay);
            }
        }

        var pad = el('div', 'bjf-mn-emu-actions');
        pad.appendChild(button(PAD_CLEAR, 'bjf-mn-emu-button', clearPad));
        pad.appendChild(button(PAD_SAVE, 'bjf-mn-emu-button bjf-mn-emu-primary', function () {
            if (!drawn) {
                note.textContent = PAD_EMPTY;
                return;
            }
            var data = canvas.toDataURL('image/png');
            close();
            sendImport(entry, field, key, data.substring(data.indexOf(',') + 1), SIGNATURE_FILE);
        }));
        pad.appendChild(button(CANCEL_LABEL, 'bjf-mn-emu-button', close));

        box.appendChild(el('div', 'bjf-mn-emu-title', field.caption || field.name));
        box.appendChild(canvas);
        box.appendChild(note);
        box.appendChild(pad);
        overlay.appendChild(box);
        frame.appendChild(overlay);
    }

    // The search icon at the right of an editable lookup field. Tapping it opens the picker.
    function lookupIcon(view, field) {
        return iconButton('chevron_down', LOOKUP_BUTTON, 'bjf-mn-emu-icon bjf-mn-emu-lookup', function () {
            openLookup(view.entry, field);
        });
    }

    // The lookup picker: a search box, pages of code and description rows, and a pick. The pick writes the
    // code with an update, the same as a typed value. The lookup answer does not change the stack.
    function openLookup(entry, field) {
        var card = entry.response;
        var frame = getParts().frame;
        var overlay = el('div', 'bjf-mn-emu-overlay');
        var box = el('div', 'bjf-mn-emu-dialog');
        var search = el('input', 'bjf-mn-emu-input');
        search.type = 'search';
        search.placeholder = SEARCH_LABEL;
        var message = el('div', 'bjf-mn-emu-dtext', '');
        var picks = el('div', 'bjf-mn-emu-picks');
        var rows = [];
        var skip = 0;
        var more = button(LOOKUP_MORE, 'bjf-mn-emu-button', function () {
            load(skip, false);
        });
        more.style.display = 'none';

        function close() {
            if (overlay.parentNode) {
                overlay.parentNode.removeChild(overlay);
            }
        }

        function pickRow(row) {
            var node = el('button', 'bjf-mn-emu-pick');
            node.type = 'button';
            node.appendChild(el('div', 'bjf-mn-emu-line1', row.code));
            if (row.description) {
                node.appendChild(el('div', 'bjf-mn-emu-line2', row.description));
            }
            node.addEventListener('click', function () {
                close();
                pickValue(entry, field, row.code);
            });
            return node;
        }

        function draw() {
            clear(picks);
            for (var i = 0; i < rows.length; i++) {
                picks.appendChild(pickRow(rows[i]));
            }
        }

        function load(from, reset) {
            if (reset) {
                rows = [];
                skip = 0;
            }
            send({
                kind: 'lookup',
                service: card.service,
                position: card.position,
                field: field.name,
                search: search.value,
                skip: from,
                top: LOOKUP_PAGE
            }, 'side', entry, function (response) {
                if (!response || response.kind !== 'lookup') {
                    message.textContent = banner || LOOKUP_FAILED;
                    return;
                }
                var page = response.rows || [];
                rows = rows.concat(page);
                skip = from + page.length;
                more.style.display = response.hasMore === true ? '' : 'none';
                message.textContent = rows.length === 0 ? LOOKUP_EMPTY : '';
                draw();
            });
        }

        var searchRow = el('div', 'bjf-mn-emu-edit');
        searchRow.appendChild(search);
        searchRow.appendChild(button(SEARCH_LABEL, 'bjf-mn-emu-button', function () {
            load(0, true);
        }));
        search.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.keyCode === 13) {
                event.preventDefault();
                load(0, true);
            }
        });
        var footer = el('div', 'bjf-mn-emu-actions');
        footer.appendChild(more);
        footer.appendChild(button(CANCEL_LABEL, 'bjf-mn-emu-button', close));

        box.appendChild(el('div', 'bjf-mn-emu-title', field.caption || field.name));
        box.appendChild(searchRow);
        box.appendChild(message);
        box.appendChild(picks);
        box.appendChild(footer);
        overlay.appendChild(box);
        frame.appendChild(overlay);
        load(0, true);
    }

    function actionButton(view, caption, fieldName, functionName, values, onResult) {
        if (!view.writes) {
            return disabledButton(caption, view.pageReadOnly ? PAGE_READ_ONLY : WRITES_OFF);
        }
        var entry = view.entry;
        return button(caption, 'bjf-mn-emu-button', function () {
            sendAction(entry, fieldName, functionName, values, onResult);
        });
    }

    // A text input that writes on Enter or when it loses focus, with - and + buttons when the field has
    // a quantity increment. A value the field rules refuse is not sent. The reason shows under the input.
    function editBox(view, field, key) {
        var entry = view.entry;
        var column = el('div', '');
        var wrap = el('div', 'bjf-mn-emu-edit');
        var note = el('div', 'bjf-mn-emu-fielderr', '');
        var input = el('input', 'bjf-mn-emu-input');
        input.type = 'text';
        input.value = withDecimals(field.value || '', field);
        var last = input.value;

        function write(text) {
            var value = withDecimals(text, field);
            if (numericType(field) !== '' && String(value).trim() === '') {
                value = '';
            }
            var reason = refusal(field, value);
            note.textContent = reason;
            if (reason) {
                return;
            }
            last = value;
            input.value = value;
            sendUpdate(entry, field.name, value);
        }

        function commit() {
            if (input.value === last) {
                return;
            }
            write(input.value);
        }

        function step(delta) {
            var base = input.value.trim() === '' ? 0 : parseNumber(input.value);
            if (isNaN(base)) {
                note.textContent = NOT_NUMBER;
                return;
            }
            write(String(Math.round((base + delta) * 1000000) / 1000000));
        }

        input.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.keyCode === 13) {
                event.preventDefault();
                commit();
            }
        });
        input.addEventListener('blur', commit);
        wrap.appendChild(input);

        var increment = Number(field.quantityIncrement || 0);
        if (increment !== 0) {
            wrap.appendChild(button('-', 'bjf-mn-emu-button bjf-mn-emu-step', function () {
                step(-increment);
            }));
            wrap.appendChild(button('+', 'bjf-mn-emu-button bjf-mn-emu-step', function () {
                step(increment);
            }));
        }
        column.appendChild(wrap);
        column.appendChild(note);
        if (key === focusName) {
            view.focusInput = input;
        }
        return column;
    }

    // A scan box for a scan type field. Enter or the barcode icon sends the text as an update. The icon sits at
    // the right of the field row, so the box returns both parts.
    function scanBox(view, field, key) {
        var entry = view.entry;
        var wrap = el('div', 'bjf-mn-emu-edit');
        var input = el('input', 'bjf-mn-emu-input');
        input.type = 'text';
        input.placeholder = SCAN_HINT;

        function scan() {
            var text = input.value.trim();
            if (text === '') {
                return;
            }
            input.value = '';
            sendUpdate(entry, field.name, text);
        }

        input.addEventListener('keydown', function (event) {
            if (event.key === 'Enter' || event.keyCode === 13) {
                event.preventDefault();
                scan();
            }
        });
        wrap.appendChild(input);
        var button = iconButton('barcode', SCAN_BUTTON, 'bjf-mn-emu-icon bjf-mn-emu-scan', scan);
        if (key === focusName) {
            view.focusInput = input;
        }
        return { wrap: wrap, button: button };
    }

    // The New button of a list: a new-record form for the list's service, under the list's parent when it has one.
    function openNew(request, response) {
        var next = { kind: 'newCard', service: response.service || request.service || '' };
        if (request.parent) {
            next.parent = copyObject(request.parent);
        }
        send(next, 'push');
    }

    // What a new-record form shows for a field: what the user typed, else the default the request filled in.
    function newValue(entry, field) {
        var values = entry.values || {};
        return Object.prototype.hasOwnProperty.call(values, field.name) ? values[field.name] : (field.value || '');
    }

    function setNewValue(entry, name, value) {
        entry.values = entry.values || {};
        entry.values[name] = value;
    }

    // A lookup pick fills the new-record form. On a saved record it writes the code, as a typed value does.
    function pickValue(entry, field, code) {
        if (entry.response.isNew === true) {
            setNewValue(entry, field.name, code);
            render();
            return;
        }
        sendUpdate(entry, field.name, code);
    }

    // An input of a new-record form. Typing only changes the form. Save sends the values.
    function newFieldInput(view, field) {
        var entry = view.entry;
        var column = el('div', '');
        var wrap = el('div', 'bjf-mn-emu-edit');
        var note = el('div', 'bjf-mn-emu-fielderr', '');
        var input = el('input', 'bjf-mn-emu-input');
        input.type = 'text';
        input.value = newValue(entry, field);
        input.addEventListener('input', function () {
            setNewValue(entry, field.name, input.value);
            note.textContent = '';
        });
        wrap.appendChild(input);
        column.appendChild(wrap);
        column.appendChild(note);
        view.notes[field.name] = note;
        return column;
    }

    // Checks the form, then sends its editable values as a create. The card it answers with replaces the form.
    function saveNew(view) {
        var entry = view.entry;
        var card = entry.response;
        var values = {};
        var valid = true;
        var groups = card.groups || [];
        for (var i = 0; i < groups.length; i++) {
            var fields = groups[i].fields || [];
            for (var j = 0; j < fields.length; j++) {
                var field = fields[j];
                var rules = fieldRules(view, field);
                if (rules.hidden || !rules.editable) {
                    continue;
                }
                var text = newValue(entry, field);
                var reason = refusal(field, text);
                if (view.notes[field.name]) {
                    view.notes[field.name].textContent = reason;
                }
                if (reason) {
                    valid = false;
                } else {
                    values[field.name] = text;
                }
            }
        }
        if (!valid) {
            return;
        }
        var request = { kind: 'create', service: card.service, values: values };
        if (entry.request && entry.request.parent) {
            request.parent = copyObject(entry.request.parent);
        }
        send(request, 'replace', entry, function (response) {
            if (response && response.created === true) {
                showToast(SAVED_LABEL);
            }
        });
    }

    // The values a dialog run sends: every shown field, by its name. Buttons and pictures are left out.
    function dialogValues(view) {
        var values = {};
        var groups = view.entry.response.groups || [];
        for (var i = 0; i < groups.length; i++) {
            var fields = groups[i].fields || [];
            for (var j = 0; j < fields.length; j++) {
                var field = fields[j];
                if (field.button || field.blob === true || fieldRules(view, field).hidden) {
                    continue;
                }
                values[field.name] = newValue(view.entry, field);
            }
        }
        return values;
    }

    // Runs a dialog page's function with the form's values. The form stays open, and its answer shows under the buttons.
    function runDialog(view, functionName) {
        var entry = view.entry;
        send({
            kind: 'dialogRun',
            service: entry.response.service,
            functionName: functionName,
            values: dialogValues(view)
        }, 'side', entry, function (response) {
            if (!response) {
                return;
            }
            entry.result = dialogResult(response);
            runCommands(response.commands, entry, render);
        });
    }

    function dialogRunButton(view, caption, functionName) {
        if (!view.writes) {
            return disabledButton(caption, view.pageReadOnly ? PAGE_READ_ONLY : WRITES_OFF);
        }
        return button(caption, 'bjf-mn-emu-button', function () {
            runDialog(view, functionName);
        });
    }

    // What a dialog answer shows: its message, the file it returns, or Done. when the answer holds nothing.
    function dialogResult(response) {
        var base64 = String(response.base64Result || '').replace(/\s/g, '');
        var name = String(response.fileName || '');
        var message = String(response.message || '');
        var hasFile = base64 !== '' && name !== '';
        return {
            message: message,
            name: hasFile ? name : '',
            base64: hasFile ? base64 : '',
            empty: message === '' && (response.commands || []).length === 0 && !hasFile
        };
    }

    // A picture file shows as a picture and a PDF in a frame. Every file also gets a download link.
    function resultPanel(result) {
        var panel = el('div', 'bjf-mn-emu-panel');
        if (result.message) {
            panel.appendChild(el('div', 'bjf-mn-emu-dtext', result.message));
        }
        if (result.empty) {
            panel.appendChild(el('div', 'bjf-mn-emu-dtext', DONE_LABEL));
        }
        if (result.base64) {
            var lower = result.name.toLowerCase();
            if (/\.(png|jpe?g|gif|bmp)$/.test(lower)) {
                var image = el('img', 'bjf-mn-emu-preview');
                image.src = imageSource(result.base64);
                image.alt = result.name;
                panel.appendChild(image);
            } else if (/\.pdf$/.test(lower)) {
                var frame = el('iframe', 'bjf-mn-emu-pdf');
                frame.src = 'data:application/pdf;base64,' + result.base64;
                frame.title = result.name;
                panel.appendChild(frame);
            }
            var link = el('a', 'bjf-mn-emu-link', BLOB_DOWNLOAD + ' ' + result.name);
            link.href = 'data:application/octet-stream;base64,' + result.base64;
            link.download = result.name;
            panel.appendChild(link);
        }
        return panel;
    }

    // The buttons of a new-record form. A dialog form runs its functions and has no Save. Any other form has Save.
    function newFormActions(content, view) {
        var entry = view.entry;
        var actions = entry.response.actions || [];
        var row = el('div', 'bjf-mn-emu-actions');
        for (var i = 0; i < actions.length; i++) {
            row.appendChild(view.dialog
                ? dialogRunButton(view, actions[i].caption, actions[i].functionName || actions[i].field)
                : disabledButton(actions[i].caption, SAVE_FIRST));
        }
        if (!view.dialog) {
            row.appendChild(view.writes
                ? button(SAVE_LABEL, 'bjf-mn-emu-button bjf-mn-emu-primary', function () {
                    saveNew(view);
                })
                : disabledButton(SAVE_LABEL, view.pageReadOnly ? PAGE_READ_ONLY : WRITES_OFF));
        }
        content.appendChild(row);
        if (view.dialog && entry.result) {
            content.appendChild(resultPanel(entry.result));
        }
    }

    // One field row of a card. Returns null when a layout, a stage or a command hides the field.
    function isBooleanField(field) {
        return String(field.fieldType || '').toLowerCase() === 'boolean';
    }

    // A Boolean field shows a switch at the right of its value. An editable switch writes Yes or No.
    function toggleBox(view, field, editable) {
        var on = /^(yes|true|1)$/i.test(String(field.value || '').trim());
        var node = el('button', 'bjf-mn-emu-toggle');
        node.type = 'button';
        node.setAttribute('role', 'switch');
        node.setAttribute('aria-checked', on ? 'true' : 'false');
        node.title = field.caption || field.name;
        node.disabled = !editable;
        node.addEventListener('click', function () {
            sendUpdate(view.entry, field.name, on ? 'No' : 'Yes');
        });
        return node;
    }

    function cardField(view, field) {
        var entry = view.entry;
        var key = convertName(field.name);
        var rules = fieldRules(view, field);
        if (rules.hidden) {
            return null;
        }
        var row = el('div', 'bjf-mn-emu-field');
        if (field.button) {
            if (view.isNew) {
                row.appendChild(view.dialog
                    ? dialogRunButton(view, rules.caption, field.functionName || field.name)
                    : disabledButton(rules.caption, SAVE_FIRST));
            } else {
                row.appendChild(actionButton(view, rules.caption, field.name, field.functionName || field.name));
            }
            return row;
        }

        var captionNode = el('div', 'bjf-mn-emu-fcap', captionText(field, rules.caption));
        if (field.mandatory === 'Mandatory' && !rules.captionColor) {
            captionNode.className += ' bjf-mn-emu-mand';
        }
        if (rules.captionColor) {
            captionNode.style.color = rules.captionColor;
        }
        var valueNode = el('div', 'bjf-mn-emu-fval');
        var main = el('div', 'bjf-mn-emu-fmain');
        var side = el('div', 'bjf-mn-emu-side');
        valueNode.appendChild(main);
        if (rules.valueColor) {
            valueNode.style.color = rules.valueColor;
        }
        if (view.isNew) {
            // A new record has no page record yet, so pictures and related lists wait for Save.
            if (field.blob === true && field.functionName) {
                main.appendChild(el('div', 'bjf-mn-emu-line2', NEW_BLOB_NOTE));
            } else if (rules.editable) {
                main.appendChild(newFieldInput(view, field));
            } else {
                main.appendChild(document.createTextNode(field.value || ''));
            }
        } else if (field.blob === true && field.functionName) {
            main.appendChild(blobBox(view, field, key));
        } else if (rules.editable && isScanType(field)) {
            main.appendChild(el('div', 'bjf-mn-emu-line2', field.value || ''));
            var scan = scanBox(view, field, key);
            main.appendChild(scan.wrap);
            side.appendChild(scan.button);
        } else if (isBooleanField(field)) {
            main.appendChild(document.createTextNode(field.value || ''));
            side.appendChild(toggleBox(view, field, rules.editable));
        } else if (rules.editable) {
            main.appendChild(editBox(view, field, key));
            if (field.drill && field.value && !field.lookup) {
                main.appendChild(drillButton(entry.response, field));
            }
        } else if (field.drill && field.value) {
            main.appendChild(button(field.value, 'bjf-mn-emu-drill', function () {
                send(parentRequest(entry.response, field.drill.service, field.drill.field), 'push');
            }));
            side.appendChild(icon('drill'));
        } else {
            main.appendChild(document.createTextNode(field.value || ''));
        }
        if (field.lookup && rules.editable) {
            side.appendChild(lookupIcon(view, field));
        }
        if (side.childNodes.length > 0) {
            valueNode.appendChild(side);
        }
        row.appendChild(captionNode);
        row.appendChild(valueNode);
        return row;
    }

    function runAction(view, action) {
        sendAction(view.entry, action.field, action.functionName || action.field);
    }

    // The bottom bar shows up to FOOT_MAX actions. Its last slot toggles a sheet of the other actions that opens
    // upward from the bar. The sheet sits inside the bar, so clearing the bar removes it as well.
    function renderFooter(view, actions) {
        var foot = getParts().foot;
        var direct = actions.length > FOOT_MAX ? actions.slice(0, FOOT_MAX - 1) : actions;
        for (var i = 0; i < direct.length; i++) {
            foot.appendChild(footItem(view, direct[i]));
        }
        if (actions.length > FOOT_MAX) {
            var more = el('button', 'bjf-mn-emu-foot-item');
            more.type = 'button';
            more.appendChild(icon('expand_more'));
            more.appendChild(el('span', '', SHOW_MORE));
            var sheet = null;
            var closeSheet = function () {
                if (sheet && sheet.parentNode) {
                    sheet.parentNode.removeChild(sheet);
                }
                sheet = null;
                more.replaceChild(icon('expand_more'), more.firstChild);
                more.lastChild.textContent = SHOW_MORE;
            };
            more.addEventListener('click', function () {
                if (sheet) {
                    closeSheet();
                    return;
                }
                sheet = openActionSheet(view, actions.slice(FOOT_MAX - 1), closeSheet);
                foot.appendChild(sheet);
                more.replaceChild(icon('expand_less'), more.firstChild);
                more.lastChild.textContent = SHOW_LESS;
            });
            foot.appendChild(more);
        }
    }

    function footItem(view, action) {
        var node = el('button', 'bjf-mn-emu-foot-item');
        node.type = 'button';
        node.appendChild(actionIcon(action));
        node.appendChild(el('span', '', action.caption));
        if (!view.writes) {
            node.disabled = true;
            node.title = view.pageReadOnly ? PAGE_READ_ONLY : WRITES_OFF;
        } else {
            node.addEventListener('click', function () {
                runAction(view, action);
            });
        }
        return node;
    }

    // The sheet of the actions past the bottom bar. Picking one closes the sheet, then runs the action.
    function openActionSheet(view, actions, close) {
        var sheet = el('div', 'bjf-mn-emu-sheet');
        for (var i = 0; i < actions.length; i++) {
            sheet.appendChild(sheetItem(view, actions[i], close));
        }
        return sheet;
    }

    function sheetItem(view, action, close) {
        var node = el('button', 'bjf-mn-emu-pick');
        node.appendChild(actionIcon(action));
        node.appendChild(el('span', '', action.caption));
        node.type = 'button';
        if (!view.writes) {
            node.disabled = true;
            node.title = view.pageReadOnly ? PAGE_READ_ONLY : WRITES_OFF;
        } else {
            node.addEventListener('click', function () {
                close();
                runAction(view, action);
            });
        }
        return node;
    }

    function renderCard(content, entry) {
        var card = entry.response;
        var view = makeView(entry);
        var info = view.stage;
        var layout = card.layout || {};
        if (card.live === false && card.liveError) {
            content.appendChild(el('div', 'bjf-mn-emu-note', LIVE_NOTE + card.liveError));
        }
        var warnings = layout.warnings || [];
        for (var w = 0; w < warnings.length; w++) {
            content.appendChild(el('div', 'bjf-mn-emu-note', warnings[w]));
        }
        var staged = info.enabled && info.visible.length > 0;
        if (staged) {
            content.appendChild(stageStrip(entry, info));
        }
        var groups = card.groups || [];
        for (var i = 0; i < groups.length; i++) {
            var fields = groups[i].fields || [];
            var rows = [];
            for (var j = 0; j < fields.length; j++) {
                var row = cardField(view, fields[j]);
                if (row) {
                    rows.push(row);
                }
            }
            if (rows.length > 0 && groups[i].caption) {
                content.appendChild(el('div', 'bjf-mn-emu-cat', groups[i].caption));
            }
            for (var r = 0; r < rows.length; r++) {
                content.appendChild(rows[r]);
            }
        }
        if (staged) {
            content.appendChild(stageNav(view, info));
        }

        var actions = card.actions || [];
        if (view.isNew) {
            newFormActions(content, view);
        } else {
            renderFooter(view, actions);
        }

        var drilldowns = card.drilldowns || [];
        if (!view.isNew && drilldowns.length > 0) {
            content.appendChild(el('div', 'bjf-mn-emu-cat', 'Related'));
            for (var m = 0; m < drilldowns.length; m++) {
                var drilldown = drilldowns[m];
                var node = el('div', 'bjf-mn-emu-row bjf-mn-emu-open');
                node.appendChild(el('div', 'bjf-mn-emu-rowtext', drilldown.caption));
                node.appendChild(drillChevron());
                node.tabIndex = 0;
                node.setAttribute('role', 'button');
                var openDrill = makeDrilldownHandler(card, drilldown);
                node.addEventListener('click', openDrill);
                node.addEventListener('keydown', makeDrilldownKeyHandler(openDrill));
                content.appendChild(node);
            }
        }

        // SF focuses its field once nothing is in flight, so the focus lands on the last card drawn.
        if (queue.length === 0) {
            if (view.focusInput) {
                view.focusInput.focus();
            }
            focusName = '';
        }
    }

    // Each navigation row gets its own handler, so every click opens its own list.
    function makeDrilldownHandler(card, drilldown) {
        return function () {
            send(parentRequest(card, drilldown.service, drilldown.field), 'push');
        };
    }

    function makeDrilldownKeyHandler(openDrill) {
        return function (event) {
            if (event.key === 'Enter' || event.key === ' ' || event.keyCode === 13 || event.keyCode === 32) {
                event.preventDefault();
                openDrill();
            }
        };
    }

    // Runs a dialog from the MI, MC, MT and MB commands. The answer goes to the page with the card it
    // belongs to, and next runs once the answer's own commands have run.
    function showDialog(group, target, next) {
        var view = getParts();
        var id = '';
        var title = '';
        var text = '';
        var buttons = '';
        for (var i = 0; i < group.length; i++) {
            var value = (group[i].args || [])[0] || '';
            if (group[i].cmd === 'MI') {
                id = value;
            } else if (group[i].cmd === 'MC') {
                title = value;
            } else if (group[i].cmd === 'MT') {
                text = value;
            } else if (group[i].cmd === 'MB') {
                buttons = value;
            }
        }
        var choices = DIALOG_BUTTONS.hasOwnProperty(buttons) ? DIALOG_BUTTONS[buttons] : DIALOG_BUTTONS.Ok;
        var overlay = el('div', 'bjf-mn-emu-overlay');
        var box = el('div', 'bjf-mn-emu-dialog');
        if (title) {
            box.appendChild(el('div', 'bjf-mn-emu-title', title));
        }
        box.appendChild(el('div', 'bjf-mn-emu-dtext', text));
        var actions = el('div', 'bjf-mn-emu-actions');
        for (var j = 0; j < choices.length; j++) {
            actions.appendChild(dialogButton(overlay, choices[j], j === 0, id, target, next));
        }
        box.appendChild(actions);
        overlay.appendChild(box);
        view.frame.appendChild(overlay);
    }

    function dialogButton(overlay, choice, primary, id, target, next) {
        var className = primary ? 'bjf-mn-emu-button bjf-mn-emu-primary' : 'bjf-mn-emu-button';
        return button(choice[0], className, function () {
            overlay.parentNode.removeChild(overlay);
            answerDialog(id, choice[1], target, next);
        });
    }

    function answerDialog(id, answer, target, next) {
        var entry = contextEntry(target);
        if (!entry) {
            next();
            return;
        }
        var card = entry.response;
        send({
            kind: 'dialogAnswer',
            service: card.service,
            position: card.position,
            answer: 'MI:' + id + ',MB:' + answer
        }, 'none', entry, function (response) {
            if (response) {
                runCommands(response.commands, entry, next);
            } else {
                next();
            }
        });
    }

    function showToast(text) {
        var view = getParts();
        if (toast && toast.parentNode) {
            toast.parentNode.removeChild(toast);
        }
        clearTimeout(toastTimer);
        var node = el('div', 'bjf-mn-emu-toast', text);
        toast = node;
        view.frame.appendChild(node);
        toastTimer = setTimeout(function () {
            if (node.parentNode) {
                node.parentNode.removeChild(node);
            }
            if (toast === node) {
                toast = null;
            }
        }, TOAST_MS);
    }

    function closeAll() {
        stack = stack.length > 0 && stack[0].response.kind === 'menu' ? [stack[0]] : [];
    }

    // Pairs of arguments from index 1 on: field, value, field, value.
    function pairsFrom(args) {
        var pairs = [];
        for (var i = 1; i + 1 < args.length; i += 2) {
            pairs.push({ field: args[i], value: args[i + 1] });
        }
        return pairs;
    }

    function openCard(args, next) {
        send({ kind: 'card', service: args[0] || '', match: pairsFrom(args) }, 'push', null, function () {
            next();
        });
        return true;
    }

    function openList(args, next) {
        send({ kind: 'list', service: args[0] || '', filters: pairsFrom(args) }, 'push', null, function () {
            next();
        });
        return true;
    }

    function overrideFor(entry, name) {
        var key = convertName(name);
        entry.overrides = entry.overrides || {};
        if (!entry.overrides[key]) {
            entry.overrides[key] = {};
        }
        return entry.overrides[key];
    }

    // R, H and E on a card: read-only, hidden or editable.
    function setOverride(entry, cmd, name) {
        if (!entry || entry.response.kind !== 'card') {
            return;
        }
        var override = overrideFor(entry, name);
        if (cmd === 'R') {
            override.readOnly = true;
            override.editable = false;
        } else if (cmd === 'H') {
            override.hidden = true;
        } else {
            override.editable = true;
            override.readOnly = false;
        }
    }

    function hexColor(text) {
        return /^[0-9A-Fa-f]{6}$/.test(String(text || ''));
    }

    // F on a card: name, hidden Y/N, read-only Y/N, caption, caption colour and value colour in RRGGBB.
    function setProperties(entry, args) {
        if (!entry || entry.response.kind !== 'card' || !args[0]) {
            return;
        }
        var override = overrideFor(entry, args[0]);
        if (args[1]) {
            override.hidden = args[1] === 'Y';
        }
        if (args[2]) {
            override.readOnly = args[2] === 'Y';
        }
        if (args[3]) {
            override.caption = args[3];
        }
        if (hexColor(args[4])) {
            override.captionColor = '#' + args[4];
        }
        if (hexColor(args[5])) {
            override.valueColor = '#' + args[5];
        }
    }

    function isDialogCommand(cmd) {
        return DIALOG_COMMANDS.indexOf(cmd) >= 0;
    }

    // Runs one device command. Returns true when the command sent a request, and next runs once the
    // answer is stored. Every other command finishes at once.
    function runCommand(command, target, next) {
        var cmd = command.cmd || '';
        var args = command.args || [];
        var entry = contextEntry(target);
        var index = entry ? stack.indexOf(entry) : -1;
        switch (cmd) {
        case 'T':
            showToast(args[0] || '');
            return false;
        case 'C':
            if (stack.length > 1) {
                stack.pop();
            }
            return false;
        case 'CA':
            closeAll();
            return false;
        case 'CP':
            if (stack.length > 1) {
                stack.splice(stack.length - 2, 1);
            }
            return false;
        case 'CL':
            if (stack.length > 1 && top().response.kind === 'list') {
                stack.pop();
            }
            return false;
        case 'RP':
            if (index > 0) {
                stack[index - 1].stale = true;
            }
            return false;
        case 'RCU':
            return refreshEntry(entry, next);
        case 'RC':
            return index >= 0 && index + 1 < stack.length ? refreshEntry(stack[index + 1], next) : false;
        case 'O':
            return openCard(args, next);
        case 'CAO':
            closeAll();
            return openCard(args, next);
        case 'OL':
            return openList(args, next);
        case 'CAOL':
            closeAll();
            return openList(args, next);
        case 'R':
        case 'H':
        case 'E':
            setOverride(entry, cmd, args[0]);
            return false;
        case 'SF':
            focusName = convertName(args[0]);
            return false;
        case 'F':
            setProperties(entry, args);
            return false;
        case 'SH':
            hideStage(entry, args[0]);
            return false;
        case 'SSV':
            setStageMark(entry, args[0], true);
            return false;
        case 'RSV':
            setStageMark(entry, args[0], false);
            return false;
        case 'FS':
            closeCard(entry);
            return false;
        case 'RS':
            restartStage(entry);
            return false;
        default:
            unhandled.push(cmd);
            return false;
        }
    }

    // Runs the commands of one answer in order. A command that asks the page waits for its answer,
    // and done runs after the last command.
    function runCommands(commands, target, done) {
        var steps = (commands || []).slice();
        advance();

        function advance() {
            while (steps.length > 0) {
                var command = steps.shift();
                if (isDialogCommand(command.cmd)) {
                    var group = [command];
                    while (steps.length > 0 && isDialogCommand(steps[0].cmd)) {
                        group.push(steps.shift());
                    }
                    showDialog(group, target, advance);
                    return;
                }
                if (runCommand(command, target, advance)) {
                    return;
                }
            }
            if (unhandled.length > 0) {
                window.ShowMessage(UNHANDLED + unhandled.join(', '));
                unhandled = [];
            }
            if (done) {
                done();
            }
        }
    }

    function downloadPanel(file) {
        var panel = el('div', 'bjf-mn-emu-panel');
        var link = el('a', 'bjf-mn-emu-link', 'Download ' + file.name);
        link.href = file.href;
        link.download = file.name;
        panel.appendChild(link);
        return panel;
    }

    function render() {
        var view = getParts();
        var entry = top();
        closeMenu();
        filterPanel = null;
        renderBar(view.bar, entry);
        renderWrites();
        clear(view.content);
        clear(view.foot);
        view.content.className = entry && entry.response.kind === 'card' ? 'bjf-mn-emu-content bjf-mn-emu-card' : 'bjf-mn-emu-content';
        if (banner) {
            view.content.appendChild(el('div', 'bjf-mn-emu-error', banner));
        }
        if (download) {
            view.content.appendChild(downloadPanel(download));
        }
        if (!entry) {
            view.content.appendChild(el('div', 'bjf-mn-emu-empty', EMPTY_START));
            return;
        }
        var kind = entry.response.kind;
        if (kind === 'menu') {
            renderMenu(view.content, entry.response);
        } else if (kind === 'list') {
            renderList(view.content, entry);
        } else if (kind === 'card') {
            renderCard(view.content, entry);
        } else {
            view.content.appendChild(el('div', 'bjf-mn-emu-empty', 'Unknown response.'));
        }
    }

    function showConnection(response) {
        writesOn = response.writesAllowed === true;
        environmentName = String(response.environment || '');
        renderWrites();
    }

    // The red bar under the title while writes are on. It names the environment the writes go to.
    function renderWrites() {
        var view = getParts();
        view.writes.textContent = WRITES_ON + (environmentName || WRITES_ON_ANY) + '.';
        view.writes.style.display = writesOn ? 'block' : 'none';
    }

    // The file of a button or action answer, as a data URL, or null.
    function fileOf(response) {
        var data = String(response.base64Result || '').replace(/\s/g, '');
        if (!data || !response.fileName) {
            return null;
        }
        return { name: String(response.fileName), href: 'data:application/octet-stream;base64,' + data };
    }

    // The MobileNAV colour areas that the last theme set on the root. Each one is a custom property --mn-<area>.
    var themeAreas = [];

    // Sets the colour areas from a theme object such as {"TitleToolbarBackground": "#FFFFFF"}. Only a name made of
    // letters and digits, such as Custom1, with a #RRGGBB value is used. An area that the new theme leaves out falls back to the CSS value.
    function applyTheme(theme) {
        var root = getParts().root;
        for (var i = 0; i < themeAreas.length; i++) {
            root.style.removeProperty('--mn-' + themeAreas[i]);
        }
        themeAreas = [];
        if (!theme || typeof theme !== 'object') {
            return;
        }
        var names = Object.keys(theme);
        for (var j = 0; j < names.length; j++) {
            var colour = String(theme[names[j]]);
            if (/^[A-Za-z][A-Za-z0-9]*$/.test(names[j]) && /^#[0-9A-Fa-f]{6}$/.test(colour)) {
                root.style.setProperty('--mn-' + names[j], colour);
                themeAreas.push(names[j]);
            }
        }
    }

    window.ShowMessage = function (text) {
        var strip = getParts().strip;
        strip.textContent = text || '';
        strip.style.display = text ? 'block' : 'none';
    };

    window.Respond = function (json) {
        var response;
        try {
            response = JSON.parse(json);
        } catch (error) {
            response = { kind: 'error', message: error.message };
        }
        if (response && typeof response === 'object' && response.theme && typeof response.theme === 'object') {
            applyTheme(response.theme);
        }
        // A new-record form and a saved record are both cards, so their answers draw as cards.
        if (response && (response.kind === 'newCard' || response.kind === 'create')) {
            response.kind = 'card';
        }
        if (response && response.kind === 'connection') {
            showConnection(response);
            return;
        }
        if (response && response.kind === 'error' && response.request === 'connection') {
            showConnection({ connected: false, writesAllowed: false, message: response.message || '' });
            return;
        }
        var sent = queue.length > 0 ? queue.shift() : { request: null, mode: 'reset', target: null, then: null };
        if (queue.length === 0) {
            window.ShowMessage('');
        }
        if (!response || response.kind === 'error') {
            banner = (response && response.message) || 'The emulator returned no response.';
            render();
            if (sent.then) {
                sent.then(null);
            }
            settle();
            return;
        }
        banner = '';
        if (response.kind === 'card') {
            writesOn = response.writesAllowed === true;
        }
        if (sent.mode === 'none') {
            download = fileOf(response);
        } else if (sent.mode !== 'side') {
            download = null;
            store({ request: sent.request || requestFromAnswer(response), response: response, overrides: {}, stale: false }, sent.mode, sent.target);
        }
        render();
        if (sent.then) {
            sent.then(response);
        }
        settle();
    };
}());
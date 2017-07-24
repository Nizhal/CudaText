(*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) Alexey Torgashin
*)
unit proc_globdata;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Menus,
  Dialogs, Graphics, ExtCtrls, ComCtrls,
  InterfaceBase,
  LclProc, LclType, LazFileUtils, LazUTF8,
  IniFiles, jsonConf,
  Process,
  ATSynEdit,
  ATSynEdit_Keymap,
  ATSynEdit_Keymap_Init,
  ATStringProc,
  ATButtons,
  ATListbox,
  ATPanelSimple,
  proc_cmd,
  proc_lexer,
  proc_msg,
  proc_scrollbars,
  proc_keymap_undolist,
  ecSyntAnal;

var
  AppBookmarkSetup: array[1..255] of
    record ImageIndex: integer; Color: TColor; end;
  AppBookmarkImagelist: TImageList = nil;
  AppFolderOfLastInstalledAddon: string = '';

const
  AppExtensionThemeUi = '.cuda-theme-ui';
  AppExtensionThemeSyntax = '.cuda-theme-syntax';


type
  TAppPathId = (
    cDirSettings,
    cDirSettingsDefault,
    cDirPy,
    cDirData,
    cDirDataLexerlib,
    cDirDataNewdoc,
    cDirDataThemes,
    cDirDataAutocomplete,
    cDirDataAutocompleteSpec,
    cDirDataLangs,
    cDirDataSideIcons,
    cDirDataTreeIcons,
    cDirReadme,
    cDirLastInstalledAddon,
    cFileOptionsHistory,
    cFileOptionsDefault,
    cFileOptionsUser,
    cFileOptionsFiletypes,
    cFileOptionsKeymap,
    cFileOptionsHistoryFiles,
    cFileLexerStylesBackup,
    cFileReadmeHistory,
    cFileReadmeHelpMouse,
    cFileReadmeHelpLexers
    );

type
  TUiOps = record
    ScreenScale: integer;

    VarFontName: string;
    VarFontSize: integer;
    OutputFontName: string;
    OutputFontSize: integer;
    DoubleBuffered: boolean;

    PyLibrary: string;
    PyChangeSlow: integer;

    LexerThemes: boolean;
    SidebarShow: boolean;
    SidebarTheme: string;
    PictureTypes: string;
    MaxFileSizeToOpen: integer;
    MaxFileSizeForLexer: integer;

    AutocompleteCss: boolean;
    AutocompleteHtml: boolean;
    AutocompleteAutoshowCharCount: integer;
    AutocompleteTriggerChars: string;
    AutoCloseBrackets: string;

    ListboxSizeX: integer;
    ListboxSizeY: integer;
    ListboxCompleteSizeX: integer;
    ListboxCompleteSizeY: integer;
    ListboxFuzzySearch: boolean;

    TabWidth: integer;
    TabHeight: integer;
    TabHeightInner: integer;
    TabIndentTop: integer;
    TabIndentInit: integer;
    TabAngle: integer;
    TabBottom: boolean;
    TabColorFull: boolean;
    TabShowX: integer;
    TabShowPlus: boolean;
    TabDblClickClose: boolean;
    TabNumbers: boolean;

    MaxHistoryEdits: integer;
    MaxHistoryMenu: integer;
    MaxHistoryFiles: integer;

    FindSuggestSel: boolean;
    FindSuggestWord: boolean;
    FindSelCase: integer;
    FindShowFindfirst: boolean;
    FindIndentVert: integer;
    FindIndentHorz: integer;
    FindMultiLineScale: double;
    FindSeparateForm: boolean;

    EscapeClose: boolean;
    EscapeCloseConsole: boolean;
    ConsoleWordWrap: boolean;
    InitialDir: string;

    ExportHtmlNumbers: boolean;
    ExportHtmlFontName: string;
    ExportHtmlFontSize: integer;

    TreeTheme: string;
    TreeAutoSync: boolean;
    TreeTimeFill: integer;
    TreeTimeFocus: integer;
    TreeShowLines: boolean;
    TreeShowIcons: boolean;

    NewdocLexer: string;
    NewdocEnc: string;
    NewdocEnds: integer;

    DefaultEncUtf8: boolean;

    StatusNoSel: string;
    StatusSmallSel: string;
    StatusStreamSel: string;
    StatusColSel: string;
    StatusCarets: string;
    StatusPanels: string;
    StatusHeight: integer;
    StatusTime: integer;
    StatusAltTime: integer;
    StatusTabsize: string;
    StatusWrap: array[0..2] of string;

    ShowActiveBorder: boolean;
    ShowSidebarCaptions: boolean;
    ShowTitlePath: boolean;
    ShowLastFiles: boolean;
    OneInstance: boolean;
    NotifEnabled: boolean;
    NotifTimeSec: integer;
    NonTextFiles: integer; //0: prompt, 1: open, 2: don't open
    NonTextFilesBufferKb: integer;
    LexerMenuGrouped: boolean;
    ReloadFollowTail: boolean;
    FullScreen: string;
    MouseGotoDefinition: string;

    HotkeyFindDialog,
    HotkeyReplaceDialog,
    HotkeyFindFirst,
    HotkeyFindNext,
    HotkeyFindPrev,
    HotkeyReplaceAndFindNext,
    HotkeyReplaceNoFindNext,
    HotkeyReplaceAll,
    HotkeyCountAll,
    HotkeySelectAll,
    HotkeyMarkAll,
    HotkeyToggleRegex,
    HotkeyToggleCaseSens,
    HotkeyToggleWords,
    HotkeyToggleWrapped,
    HotkeyToggleInSelect,
    HotkeyToggleMultiline,
    HotkeyToggleConfirmRep
      : string;
  end;
var
  UiOps: TUiOps;

const
  cOptionSystemSuffix =
    {$ifdef windows} '' {$endif}
    {$ifdef linux} '__linux' {$endif}
    {$ifdef darwin} '__mac' {$endif} ;

const
  str_FontName = 'font_name'+cOptionSystemSuffix;
  str_FontSize = 'font_size'+cOptionSystemSuffix;
  str_FontQuality = 'font_quality'+cOptionSystemSuffix;
  str_FontLigatures = 'font_ligatures'; //+cOptionSystemSuffix;
  str_UiFontName = 'ui_font_name'+cOptionSystemSuffix;
  str_UiFontSize = 'ui_font_size'+cOptionSystemSuffix;
  str_UiFontOutputName = 'ui_font_output_name'+cOptionSystemSuffix;
  str_UiFontOutputSize = 'ui_font_output_size'+cOptionSystemSuffix;
  str_UiDoubleBuffered = 'ui_buffered'+cOptionSystemSuffix;
  str_DefEncodingIsUtf8 = 'def_encoding_utf8'+cOptionSystemSuffix;

type
  TEditorOps = record
    OpFontName: string;
    OpFontSize: integer;
    OpFontQuality: TFontQuality;
    OpFontLigatures: boolean;

    OpSpacingX: integer;
    OpSpacingY: integer;
    OpTabSize: integer;
    OpTabSpaces: boolean;
    OpTabMaxPosExpanded: integer;

    OpOvrSel: boolean;
    OpOvrOnPaste: boolean;
    OpUnderlineColorFiles: string;
    OpUnderlineColorSize: integer;
    OpLinks: boolean;
    OpLinksRegex: string;

    //view
    OpGutterShow: boolean;
    OpGutterFold: boolean;
    OpGutterFoldAlways: boolean;
    OpGutterFoldIcons: integer;
    OpGutterBookmarks: boolean;

    OpNumbersShow: boolean;
    OpNumbersFontSize: integer;
    OpNumbersStyle: integer;
    OpNumbersForCarets: boolean;
    OpNumbersCenter: boolean;

    OpRulerShow: boolean;
    OpRulerFontSize: integer;
    OpRulerSize: integer;
    OpRulerTextIndent: integer;

    OpMinimapShow: boolean;
    OpMinimapShowSelAlways: boolean;
    OpMinimapShowSelBorder: boolean;
    OpMinimapCharWidth: integer;
    OpMinimapAtLeft: boolean;
    OpMicromapShow: boolean;
    OpMicromapWidth: integer;
    OpMicromapWidthSmall: integer;
    OpMarginFixed: integer;
    OpMarginString: string;
    OpStaplesStyle: integer;

    //unprinted
    OpUnprintedShow: boolean;
    OpUnprintedSpaces: boolean;
    OpUnprintedEnds: boolean;
    OpUnprintedEndDetails: boolean;
    OpUnprintedReplaceSpec: boolean;
    OpUnprintedReplaceToCode: string;

    OpUnprintedEndArrow: boolean;
    OpUnprintedTabArrowLen: integer;
    OpUnprintedSpaceDotScale: integer;
    OpUnprintedEndDotScale: integer;
    OpUnprintedEndFontScale: integer;
    OpUnprintedTabPointerScale: integer;

    //wrap
    OpWrapMode: integer;
    OpWrapIndented: boolean;

    //undo
    OpUndoLimit: integer;
    OpUndoGrouped: boolean;
    OpUndoAfterSave: boolean;

    //caret
    OpCaretBlinkTime: integer;
    OpCaretBlinkEn: boolean;
    OpCaretShapeNorm: integer;
    OpCaretShapeOvr: integer;
    OpCaretShapeRO: integer;
    OpCaretVirtual: boolean;
    OpCaretMulti: boolean;
    OpCaretAfterPasteColumn: integer;
    OpCaretsAddedToColumnSel: boolean;

    //general
    OpShowCurLine: boolean;
    OpShowCurLineMinimal: boolean;
    OpShowCurLineOnlyFocused: boolean;
    OpShowCurCol: boolean;
    OpShowLastLineOnTop: boolean;
    OpShowSelectBgFull: boolean;
    OpShowSyntaxBgFull: boolean;
    OpCopyLineIfNoSel: boolean;
    OpCutLineIfNoSel: boolean;
    OpSavingTrimSpaces: boolean;
    OpSavingForceFinalEol: boolean;
    OpShowHintOnVertScroll: boolean;
    OpLexerDynamicHiliteEnabled: boolean;
    OpLexerDynamicHiliteMaxLines: integer;
    OpLexerLineSeparators: boolean;

    OpWordChars: UnicodeString;
    OpHexChars: UnicodeString;
    OpFoldStyle: integer;

    //indent
    OpIndentAuto: boolean;
    OpIndentAutoKind: integer;
    OpIndentSize: integer;
    OpUnIndentKeepsAlign: boolean;
    OpIndentMakesWholeLineSel: boolean;

    //mouse
    OpMouse2ClickDragSelectsWords: boolean;
    OpMouseDragDrop: boolean;
    OpMouseDragDropFocusTarget: boolean;
    OpMouseMiddleClickNiceScroll: boolean;
    OpMouseMiddleClickPaste: boolean;
    OpMouseRightClickMovesCaret: boolean;
    OpMouseEnableColumnSelection: boolean;
    OpMouseHideCursorOnType: boolean; //don't work on lin
    OpMouseGutterClickSelectedLine: boolean;
    OpMouseWheelZoom: boolean;
    OpMouseWheelSpeedVert: integer;
    OpMouseWheelSpeedHorz: integer;

    //keys
    OpKeyBackspaceUnindent: boolean;
    OpKeyTabIndents: boolean;
    OpKeyHomeToNonSpace: boolean;
    OpKeyHomeEndNavigateWrapped: boolean;
    OpKeyEndToNonSpace: boolean;
    OpKeyPageKeepsRelativePos: boolean;
    OpKeyPageUpDownSize: integer;
    OpKeyUpDownKeepColumn: boolean;
    OpKeyUpDownNavigateWrapped: boolean;
    OpKeyLeftRightSwapSel: boolean;
    OpKeyLeftRightSwapSelAndSelect: boolean;
  end;
var
  EditorOps: TEditorOps;

function GetAppPath(id: TAppPathId): string;
function GetAppLangFilename: string;

function GetAppLexerFilename(const ALexName: string): string;
function GetAppLexerMapFilename(const ALexName: string): string;
function GetAppLexerSpecificConfig(AName: string): string;
function GetAppLexerPropInCommentsSection(const ALexerName, AKey: string): string;

//function GetActiveControl(Form: TWinControl): TWinControl;
function GetListboxItemHeight(const AFontName: string; AFontSize: integer): integer;
function GetAppCommandCodeFromCommandStringId(const AId: string): integer;
function MsgBox(const Str: string; Flags: Longint): integer;
procedure MsgStdout(const Str: string; AllowMsgBox: boolean = false);

function GetAppKeymap_LexerSpecificConfig(AName: string): string;
function GetAppKeymapHotkey(const ACmdString: string): string;
function SetAppKeymapHotkey(AParams: string): boolean;
procedure AppKeymapCheckDuplicateForCommand(ACommand: integer; const ALexerName: string);
function AppKeymapHasDuplicateForKey(AHotkey, AKeyComboSeparator: string): boolean;
procedure AppKeymap_ApplyUndoList(AUndoList: TATKeymapUndoList);

procedure DoOps_SaveKeyItem(K: TATKeymapItem; const path, ALexerName: string);
procedure DoOps_SaveKey_ForPluginModuleAndMethod(AOverwriteKey: boolean;
  const AMenuitemCaption, AModuleName, AMethodName, ALexerName, AHotkey: string);

function DoLexerFindByFilename(const fn: string): TecSyntAnalyzer;
procedure DoLexerEnum(L: TStringList; AlsoDisabled: boolean = false);
procedure DoLexerExportFromLibToFile(an: TecSyntAnalyzer);

function CommandPlugins_GetIndexFromModuleAndMethod(AStr: string): integer;
procedure CommandPlugins_UpdateSubcommands(AStr: string);
procedure CommandPlugins_DeleteItem(AIndex: integer);

var
  AppManager: TecSyntaxManager = nil;
  AppKeymap: TATKeymap = nil;
  AppKeymapInitial: TATKeymap = nil;
  AppShortcutEscape: TShortcut = 0;
  AppLangName: string = '';

type
  TStrEvent = procedure(Sender: TObject; const ARes: string) of object;
  TStrFunction = function(const AStr: string): boolean of object;

const
  cEncNameUtf8_WithBom = 'UTF-8 with BOM';
  cEncNameUtf8_NoBom = 'UTF-8';
  cEncNameUtf16LE_WithBom = 'UTF-16 LE with BOM';
  cEncNameUtf16LE_NoBom = 'UTF-16 LE';
  cEncNameUtf16BE_WithBom = 'UTF-16 BE with BOM';
  cEncNameUtf16BE_NoBom = 'UTF-16 BE';
  cEncNameAnsi = 'ANSI';

  cEncNameCP1250 = 'CP1250';
  cEncNameCP1251 = 'CP1251';
  cEncNameCP1252 = 'CP1252';
  cEncNameCP1253 = 'CP1253';
  cEncNameCP1254 = 'CP1254';
  cEncNameCP1255 = 'CP1255';
  cEncNameCP1256 = 'CP1256';
  cEncNameCP1257 = 'CP1257';
  cEncNameCP1258 = 'CP1258';
  cEncNameCP437 = 'CP437';
  cEncNameCP850 = 'CP850';
  cEncNameCP852 = 'CP852';
  cEncNameCP866 = 'CP866';
  cEncNameCP874 = 'CP874';
  cEncNameISO1 = 'ISO-8859-1';
  cEncNameISO2 = 'ISO-8859-2';
  cEncNameMac = 'Macintosh';
  cEncNameCP932 = 'CP932';
  cEncNameCP936 = 'CP936';
  cEncNameCP949 = 'CP949';
  cEncNameCP950 = 'CP950';

type
  TAppEncodingRecord = record
    Sub,
    Name,
    ShortName: string;
  end;

const
  AppEncodings: array[0..30] of TAppEncodingRecord = (
    (Sub: ''; Name: cEncNameUtf8_NoBom; ShortName: 'utf8'),
    (Sub: ''; Name: cEncNameUtf8_WithBom; ShortName: 'utf8_bom'),
    (Sub: ''; Name: cEncNameUtf16LE_NoBom; ShortName: 'utf16le'),
    (Sub: ''; Name: cEncNameUtf16LE_WithBom; ShortName: 'utf16le_bom'),
    (Sub: ''; Name: cEncNameUtf16BE_NoBom; ShortName: 'utf16be'),
    (Sub: ''; Name: cEncNameUtf16BE_WithBom; ShortName: 'utf16be_bom'),
    (Sub: ''; Name: cEncNameAnsi; ShortName: 'ansi'),
    (Sub: ''; Name: '-'; ShortName: ''),
    (Sub: 'eu'; Name: cEncNameCP1250; ShortName: cEncNameCP1250),
    (Sub: 'eu'; Name: cEncNameCP1251; ShortName: cEncNameCP1251),
    (Sub: 'eu'; Name: cEncNameCP1252; ShortName: cEncNameCP1252),
    (Sub: 'eu'; Name: cEncNameCP1253; ShortName: cEncNameCP1253),
    (Sub: 'eu'; Name: cEncNameCP1257; ShortName: cEncNameCP1257),
    (Sub: 'eu'; Name: '-'; ShortName: ''),
    (Sub: 'eu'; Name: cEncNameCP437; ShortName: cEncNameCP437),
    (Sub: 'eu'; Name: cEncNameCP850; ShortName: cEncNameCP850),
    (Sub: 'eu'; Name: cEncNameCP852; ShortName: cEncNameCP852),
    (Sub: 'eu'; Name: cEncNameCP866; ShortName: cEncNameCP866),
    (Sub: 'eu'; Name: '-'; ShortName: ''),
    (Sub: 'eu'; Name: cEncNameISO1; ShortName: cEncNameISO1),
    (Sub: 'eu'; Name: cEncNameISO2; ShortName: cEncNameISO2),
    (Sub: 'eu'; Name: cEncNameMac; ShortName: 'mac'),
    (Sub: 'mi'; Name: cEncNameCP1254; ShortName: cEncNameCP1254),
    (Sub: 'mi'; Name: cEncNameCP1255; ShortName: cEncNameCP1255),
    (Sub: 'mi'; Name: cEncNameCP1256; ShortName: cEncNameCP1256),
    (Sub: 'as'; Name: cEncNameCP874; ShortName: cEncNameCP874),
    (Sub: 'as'; Name: cEncNameCP932; ShortName: cEncNameCP932),
    (Sub: 'as'; Name: cEncNameCP936; ShortName: cEncNameCP936),
    (Sub: 'as'; Name: cEncNameCP949; ShortName: cEncNameCP949),
    (Sub: 'as'; Name: cEncNameCP950; ShortName: cEncNameCP950),
    (Sub: 'as'; Name: cEncNameCP1258; ShortName: cEncNameCP1258)
  );


type
  TAppPyEvent = (
    cEventOnOpen,
    cEventOnOpenBefore,
    cEventOnClose,
    cEventOnSaveAfter,
    cEventOnSaveBefore,
    cEventOnKey,
    cEventOnKeyUp,
    cEventOnChange,
    cEventOnChangeSlow,
    cEventOnCaret,
    cEventOnClick,
    cEventOnClickDbl,
    cEventOnClickGap,
    cEventOnState,
    cEventOnFocus,
    cEventOnStart,
    cEventOnLexer,
    cEventOnComplete,
    cEventOnGotoDef,
    cEventOnFuncHint,
    cEventOnTabMove,
    cEventOnPanel,
    cEventOnConsole,
    cEventOnConsoleNav,
    cEventOnOutputNav,
    cEventOnSnippet,
    cEventOnMacro
    );
  TAppPyEvents = set of TAppPyEvent;
  TAppPyEventsPrior = array[TAppPyEvent] of byte;
    //0: default, 1,2...: higher priority

const
  cAppPyEvent: array[TAppPyEvent] of string = (
    'on_open',
    'on_open_pre',
    'on_close',
    'on_save',
    'on_save_pre',
    'on_key',
    'on_key_up',
    'on_change',
    'on_change_slow',
    'on_caret',
    'on_click',
    'on_click_dbl',
    'on_click_gap',
    'on_state',
    'on_focus',
    'on_start',
    'on_lexer',
    'on_complete',
    'on_goto_def',
    'on_func_hint',
    'on_tab_move',
    'on_panel',
    'on_console',
    'on_console_nav',
    'on_output_nav',
    'on_snippet',
    'on_macro'
    );

const
  cMaxItemsInInstallInf = 400;

type
  TAppPluginCmd = record
    ItemModule: string;
    ItemProc: string;
    ItemProcParam: string;
    ItemCaption: string;
    ItemLexers: string;
    ItemInMenu: boolean;
    ItemFromApi: boolean;
  end;
  TAppPluginCmdArray = array[0..400] of TAppPluginCmd;

type
  TAppPluginEvent = record
    ItemModule: string;
    ItemLexers: string;
    ItemEvents: TAppPyEvents;
    ItemEventsPrior: TAppPyEventsPrior;
    ItemKeys: string;
  end;
  TAppPluginEventArray = array[0..100] of TAppPluginEvent;

var
  FPluginsCmd: TAppPluginCmdArray;
  FPluginsEvents: TAppPluginEventArray;

type
  TAppSidePanel = record
    ItemCaption: string;
    ItemControl: TCustomControl;
    ItemTreeview: TTreeViewMy;
    ItemListbox: TATListbox;
    ItemImagelist: TImageList;
    ItemMenu: TPopupMenu;
  end;

var
  FAppSidePanels: array[0..20] of TAppSidePanel;
  FAppBottomPanels: array[0..50] of TAppSidePanel;

type
  PAppPanelProps = ^TAppPanelProps;
  TAppPanelProps = record
    Listbox: TATListbox;
    RegexStr: string;
    RegexIdLine,
    RegexIdCol,
    RegexIdName: integer;
    DefFilename: string;
    ZeroBase: boolean;
    Encoding: string;
  end;

type
  TAppMenuProps = class
  public
    CommandCode: integer;
    CommandString: string;
    TagString: string;
  end;

function AppEncodingShortnameToFullname(const S: string): string;
function AppEncodingFullnameToShortname(const S: string): string;
function AppEncodingListAsString: string;

var
  //values calculated from option ui_statusbar_panels
  StatusbarIndex_Caret: integer = 0;
  StatusbarIndex_Enc: integer = 1;
  StatusbarIndex_LineEnds: integer = 2;
  StatusbarIndex_Lexer: integer = 3;
  StatusbarIndex_TabSize: integer = 4;
  StatusbarIndex_InsOvr: integer = -1;
  StatusbarIndex_SelMode: integer = -1;
  StatusbarIndex_WrapMode: integer = -1;
  StatusbarIndex_Msg: integer = 5;


implementation

function MsgBox(const Str: string; Flags: Longint): integer;
begin
  Result:= Application.MessageBox(PChar(Str), PChar(msgTitle), Flags);
end;


function InitPyLibraryPath: string;
  //
  function GetMacPath(NMinorVersion: integer): string;
  begin
    Result:= Format('/Library/Frameworks/Python.framework/Versions/3.%d/lib/libpython3.%d.dylib',
      [NMinorVersion, NMinorVersion]);
  end;
  //
var
  N: integer;
begin
  Result:= '';

  {$ifdef windows}
  exit('python35.dll');
  {$endif}

  {$ifdef linux}
  exit('libpython3.5m.so.1.0');
  {$endif}

  {$ifdef darwin}
  for N:= 4 to 9 do
  begin
    Result:= GetMacPath(N);
    if FileExists(Result) then exit;
  end;
  {$endif}
end;

var
  OpDirExe: string = '';
  OpDirLocal: string = '';
  OpDirPrecopy: string = '';

function GetDirPrecopy: string;
begin
  Result:=
  {$ifdef windows} '' {$endif}
  {$ifdef linux} '/usr/share/cudatext' {$endif}
  {$ifdef darwin} ExtractFileDir(OpDirExe)+'/Resources' {$endif}
end;

function GetAppPath(id: TAppPathId): string;
begin
  case id of
    cDirSettings:
      begin
        Result:= OpDirLocal+DirectorySeparator+'settings';
        CreateDirUTF8(Result);
      end;
    cDirSettingsDefault:
      begin
        Result:= OpDirLocal+DirectorySeparator+'settings_default';
      end;
    cDirPy:
      begin
        Result:= OpDirLocal+DirectorySeparator+'py';
      end;

    cDirData:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data';
      end;
    cDirDataLexerlib:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'lexlib';
      end;
    cDirDataNewdoc:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'newdoc';
      end;
    cDirDataThemes:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'themes';
      end;
    cDirDataAutocomplete:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'autocomplete';
      end;
    cDirDataAutocompleteSpec:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'autocompletespec';
      end;
    cDirDataLangs:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'lang';
      end;
    cDirDataSideIcons:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'sideicons'+DirectorySeparator+UiOps.SidebarTheme;
      end;
    cDirDataTreeIcons:
      begin
        Result:= OpDirLocal+DirectorySeparator+'data'+DirectorySeparator+'codetreeicons'+DirectorySeparator+UiOps.TreeTheme;
      end;

    cDirReadme:
      begin
        Result:= OpDirLocal+DirectorySeparator+'readme';
      end;
    cDirLastInstalledAddon:
      begin
        Result:= AppFolderOfLastInstalledAddon;
      end;
    cFileOptionsDefault:
      begin
        Result:= GetAppPath(cDirSettingsDefault)+DirectorySeparator+'default.json';
      end;
    cFileOptionsHistory:
      begin
        Result:= GetAppPath(cDirSettings)+DirectorySeparator+'history.json';
      end;
    cFileOptionsUser:
      begin
        Result:= GetAppPath(cDirSettings)+DirectorySeparator+'user.json';
      end;
    cFileOptionsFiletypes:
      begin
        Result:= GetAppPath(cDirSettings)+DirectorySeparator+'filetypes.json';
      end;
    cFileOptionsKeymap:
      begin
        Result:= GetAppPath(cDirSettings)+DirectorySeparator+'keys.json';
      end;
    cFileOptionsHistoryFiles:
      begin
        Result:= GetAppPath(cDirSettings)+DirectorySeparator+'history files.json';
      end;
    cFileLexerStylesBackup:
      begin
        Result:= GetAppPath(cDirSettings)+DirectorySeparator+'lexer styles backup.ini';
      end;

    cFileReadmeHistory:
      begin
        Result:= GetAppPath(cDirReadme)+DirectorySeparator+'history.txt';
      end;
    cFileReadmeHelpMouse:
      begin
        Result:= GetAppPath(cDirReadme)+DirectorySeparator+'help mouse.txt';
      end;
    cFileReadmeHelpLexers:
      begin
        Result:= GetAppPath(cDirReadme)+DirectorySeparator+'help lexers install.txt';
      end;
  end;
end;

procedure InitDirs;
var
  S: string;
begin
  OpDirExe:= ExtractFileDir(ParamStrUTF8(0));
  OpDirPrecopy:= GetDirPrecopy;

  if DirectoryExistsUTF8(
      OpDirExe+
      DirectorySeparator+'data'+
      DirectorySeparator+'lexlib') then
    OpDirLocal:= OpDirExe
  else
  begin
    {$ifdef windows}
    OpDirLocal:= GetEnvironmentVariableUTF8('appdata')+'\CudaText';
    {$else}
    OpDirLocal:= GetEnvironmentVariableUTF8('HOME')+'/.cudatext';
    {$endif}
    CreateDirUTF8(OpDirLocal);

    if DirectoryExistsUTF8(OpDirPrecopy) then
    begin
      {$ifdef linux}
      RunCommand('cp', ['-R', '-u', '-t',
        OpDirLocal,
        '/usr/share/cudatext/py',
        '/usr/share/cudatext/data',
        '/usr/share/cudatext/readme',
        '/usr/share/cudatext/settings_default'
        ], S);
      {$endif}
      {$ifdef darwin}
      //see rsync help. need options:
      // -u (update)
      // -r (recursive)
      // -t (preserve times)
      RunCommand('rsync', ['-urt',
        OpDirPrecopy+'/',
        OpDirLocal
        ], S);
      {$endif}
    end;
  end;
end;

procedure InitEditorOps(var Op: TEditorOps);
begin
  with Op do
  begin
    OpFontName:=
      {$ifdef windows} 'Consolas' {$endif}
      {$ifdef linux} 'Courier New' {$endif}
      {$ifdef darwin} 'Monaco' {$endif} ;
    OpFontSize:= 10; //for all OS
    OpFontQuality:= fqDefault;
    OpFontLigatures:= false;

    OpSpacingX:= 0;
    OpSpacingY:= 1;

    OpTabSize:= 8;
    OpTabSpaces:= false;
    OpTabMaxPosExpanded:= 500;

    OpOvrSel:= true;
    OpOvrOnPaste:= false;

    OpUnderlineColorFiles:= '*';
    OpUnderlineColorSize:= 3;
    OpLinks:= true;
    OpLinksRegex:= ATSynEdit.cUrlRegexInitial;

    OpGutterShow:= true;
    OpGutterFold:= true;
    OpGutterFoldAlways:= true;
    OpGutterBookmarks:= true;
    OpGutterFoldIcons:= 0;

    OpNumbersShow:= true;
    OpNumbersFontSize:= 0;
    OpNumbersStyle:= Ord(cNumbersAll);
    OpNumbersForCarets:= false;
    OpNumbersCenter:= true;

    OpRulerShow:= false;
    OpRulerFontSize:= 8;
    OpRulerSize:= 20;
    OpRulerTextIndent:= 0;

    OpMinimapShow:= false;
    OpMinimapShowSelAlways:= false;
    OpMinimapShowSelBorder:= false;
    OpMinimapCharWidth:= 0;
    OpMinimapAtLeft:= false;

    OpMicromapShow:= false;
    OpMicromapWidth:= 12;
    OpMicromapWidthSmall:= 4;

    OpMarginFixed:= 2000; //hide margin
    OpMarginString:= '';
    OpStaplesStyle:= 1; //Ord(cLineStyleSolid)

    OpUnprintedShow:= false;
    OpUnprintedSpaces:= true;
    OpUnprintedEnds:= true;
    OpUnprintedEndDetails:= false;
    OpUnprintedReplaceSpec:= false;
    OpUnprintedReplaceToCode:= 'A4';

    OpUnprintedEndArrow:= true;
    OpUnprintedTabArrowLen:= 1;
    OpUnprintedSpaceDotScale:= 15;
    OpUnprintedEndDotScale:= 30;
    OpUnprintedEndFontScale:= 80;
    OpUnprintedTabPointerScale:= 22;

    OpWrapMode:= 0;
    OpWrapIndented:= true;

    OpUndoLimit:= 5000;
    OpUndoGrouped:= true;
    OpUndoAfterSave:= true;

    OpCaretBlinkTime:= cInitTimerBlink;
    OpCaretBlinkEn:= true;
    OpCaretShapeNorm:= Ord(cInitCaretShapeIns);
    OpCaretShapeOvr:= Ord(cInitCaretShapeOvr);
    OpCaretShapeRO:= Ord(cInitCaretShapeRO);
    OpCaretVirtual:= false;
    OpCaretMulti:= true;
    OpCaretAfterPasteColumn:= Ord(cPasteCaretColumnRight);
    OpCaretsAddedToColumnSel:= true;

    OpShowCurLine:= false;
    OpShowCurLineMinimal:= true;
    OpShowCurLineOnlyFocused:= false;
    OpShowCurCol:= false;
    OpShowLastLineOnTop:= true;
    OpShowSelectBgFull:= false;
    OpShowSyntaxBgFull:= true;
    OpCopyLineIfNoSel:= true;
    OpCutLineIfNoSel:= false;
    OpSavingTrimSpaces:= false;
    OpSavingForceFinalEol:= false;
    OpShowHintOnVertScroll:= false;
    OpLexerDynamicHiliteEnabled:= true;
    OpLexerDynamicHiliteMaxLines:= 2000;
    OpLexerLineSeparators:= false;

    OpWordChars:= '';
    OpHexChars:= '';
    OpFoldStyle:= 1;

    OpIndentAuto:= true;
    OpIndentAutoKind:= Ord(cIndentAsIs);
    OpIndentSize:= 2;
    OpUnIndentKeepsAlign:= true;
    OpIndentMakesWholeLineSel:= false;

    OpMouse2ClickDragSelectsWords:= true;
    OpMouseDragDrop:= true;
    OpMouseDragDropFocusTarget:= true;
    OpMouseMiddleClickNiceScroll:= true;
    OpMouseMiddleClickPaste:= false;
    OpMouseRightClickMovesCaret:= false;
    OpMouseEnableColumnSelection:= true;
    OpMouseHideCursorOnType:= false;
    OpMouseGutterClickSelectedLine:= true;
    OpMouseWheelZoom:= false;
    OpMouseWheelSpeedVert:= 3;
    OpMouseWheelSpeedHorz:= 10;

    OpKeyBackspaceUnindent:= true;
    OpKeyTabIndents:= true;
    OpKeyHomeToNonSpace:= true;
    OpKeyHomeEndNavigateWrapped:= true;
    OpKeyEndToNonSpace:= true;
    OpKeyPageKeepsRelativePos:= true;
    OpKeyPageUpDownSize:= Ord(cPageSizeFullMinus1);
    OpKeyUpDownKeepColumn:= true;
    OpKeyUpDownNavigateWrapped:= true;
    OpKeyLeftRightSwapSel:= true;
    OpKeyLeftRightSwapSelAndSelect:= false;
  end;
end;


function IsDoubleBufferedNeeded: boolean;
begin
  {$ifdef linux}
  //Qt needs true (else caret dont blink, and tab angled borders paint bad)
  Exit(true);
  {$endif}

  Result:= WidgetSet.GetLCLCapability(lcCanDrawOutsideOnPaint) = LCL_CAPABILITY_YES;
end;


procedure InitUiOps(var Op: TUiOps);
begin
  with Op do
  begin
    ScreenScale:= 100;

    VarFontName:= 'default';
    VarFontSize:=
      {$ifdef windows} 9 {$endif}
      {$ifdef linux} 10 {$endif}
      {$ifdef darwin} 10 {$endif} ;

    OutputFontName:= VarFontName;
    OutputFontSize:= VarFontSize;

    DoubleBuffered:= IsDoubleBufferedNeeded;

    LexerThemes:= true;
    SidebarShow:= true;
    SidebarTheme:= 'octicons_20x20';
    TreeTheme:= 'default_16x16';

    PyLibrary:= InitPyLibraryPath;
    PictureTypes:= 'bmp,png,jpg,jpeg,gif,ico';

    MaxFileSizeToOpen:= 30;
    MaxFileSizeForLexer:= 4;

    AutocompleteCss:= true;
    AutocompleteHtml:= true;
    AutocompleteAutoshowCharCount:= 0;
    AutocompleteTriggerChars:= '';
    AutoCloseBrackets:= '([{';

    ListboxSizeX:= 450;
    ListboxSizeY:= 300;
    ListboxCompleteSizeX:= 550;
    ListboxCompleteSizeY:= 200;
    ListboxFuzzySearch:= true;

    TabWidth:= 170;
    TabHeight:= 25;
    TabHeightInner:= TabHeight-1;
    TabIndentTop:= 0;
    TabIndentInit:= 5;
    TabAngle:= 3;
    TabBottom:= false;
    TabColorFull:= false;
    TabShowX:= 1; //show all
    TabShowPlus:= true;
    TabDblClickClose:= false;
    TabNumbers:= false;

    MaxHistoryEdits:= 20;
    MaxHistoryMenu:= 10;
    MaxHistoryFiles:= 25;

    FindSuggestSel:= false;
    FindSuggestWord:= true;
    FindSelCase:= 2;
    FindShowFindfirst:= true;
    FindIndentVert:= -5;
    FindIndentHorz:= 10;
    FindMultiLineScale:= 2.5;
    FindSeparateForm:= false;

    EscapeClose:= false;
    EscapeCloseConsole:= true;
    ConsoleWordWrap:= true;
    InitialDir:= '';

    ExportHtmlNumbers:= false;
    ExportHtmlFontSize:= 12;
    ExportHtmlFontName:= 'Courier New';

    TreeAutoSync:= true;
    TreeTimeFill:= 2000;
    TreeTimeFocus:= 300;
    TreeShowLines:= true;
    TreeShowIcons:= true;
    PyChangeSlow:= 2000;

    NewdocLexer:= '';
    NewdocEnc:= 'utf8';
    NewdocEnds:= {$ifdef windows} Ord(cEndWin) {$else} Ord(cEndUnix) {$endif};

    DefaultEncUtf8:= {$ifdef windows} false {$else} true {$endif};

    StatusNoSel:= 'Ln {y}, Col {xx}';
    StatusSmallSel:= 'Ln {y}, Col {xx}, sel';
    StatusStreamSel:= 'Ln {y}, Col {xx}, {sel} lines sel';
    StatusColSel:= '{sel}x{cols} column';
    StatusCarets:= '{carets} carets, {sel} lines sel';
    StatusPanels:= 'caret,C,170|enc,C,115|ends,C,50|lexer,C,140|tabsize,C,80|selmode,C,15|msg,L,4000';
    StatusHeight:= TabHeight;
    StatusTime:= 5;
    StatusAltTime:= 7;
    StatusTabsize:= 'Tab size {tab}{_}';
    StatusWrap[0]:= 'no-wrap';
    StatusWrap[1]:= 'wrap';
    StatusWrap[2]:= 'wrap-m';

    ShowActiveBorder:= true;
    ShowSidebarCaptions:= false;
    ShowTitlePath:= false;
    ShowLastFiles:= true;
    OneInstance:= false;
    NotifEnabled:= true;
    NotifTimeSec:= 2;
    NonTextFiles:= 0;
    NonTextFilesBufferKb:= 64;
    LexerMenuGrouped:= true;
    ReloadFollowTail:= true;
    FullScreen:= 'tp';
    MouseGotoDefinition:= 'a';

    HotkeyFindDialog:= 'Ctrl+F';
    HotkeyReplaceDialog:= 'Ctrl+R';
    HotkeyFindFirst:= 'Alt+Enter';
    HotkeyFindNext:= 'Enter';
    HotkeyFindPrev:= 'Shift+Enter';
    HotkeyReplaceAndFindNext:= 'Alt+Z';
    HotkeyReplaceNoFindNext:= 'Ctrl+Alt+Z';
    HotkeyReplaceAll:= 'Alt+A';
    HotkeyCountAll:= 'Alt+O';
    HotkeySelectAll:= 'Alt+E';
    HotkeyMarkAll:= 'Alt+K';
    HotkeyToggleRegex:= 'Alt+R';
    HotkeyToggleCaseSens:= 'Alt+C';
    HotkeyToggleWords:= 'Alt+W';
    HotkeyToggleWrapped:= 'Alt+N';
    HotkeyToggleInSelect:= 'Alt+X';
    HotkeyToggleMultiline:= 'Alt+M';
    HotkeyToggleConfirmRep:= 'Alt+Y';
  end;
end;


procedure SReplaceSpecialFilenameChars(var S: string);
begin
  S:= StringReplace(S, '/', '_', [rfReplaceAll]);
  S:= StringReplace(S, '\', '_', [rfReplaceAll]);
  S:= StringReplace(S, '*', '_', [rfReplaceAll]);
  S:= StringReplace(S, ':', '_', [rfReplaceAll]);
  S:= StringReplace(S, '<', '_', [rfReplaceAll]);
  S:= StringReplace(S, '>', '_', [rfReplaceAll]);
end;

function GetAppLexerSpecificConfig(AName: string): string;
begin
  //support none-lexer here
  if AName='' then
    AName:= '-';
  SReplaceSpecialFilenameChars(AName);
  Result:= GetAppPath(cDirSettings)+DirectorySeparator+'lexer '+AName+'.json';
end;

function GetAppKeymap_LexerSpecificConfig(AName: string): string;
begin
  //support none-lexer
  if AName='' then
    AName:= '-';
  SReplaceSpecialFilenameChars(AName);
  Result:= GetAppPath(cDirSettings)+DirectorySeparator+'keys lexer '+AName+'.json';
end;


function GetAppCommandCodeFromCommandStringId(const AId: string): integer;
begin
  //plugin item 'module,method'
  if Pos(',', AId)>0 then
  begin
    Result:= CommandPlugins_GetIndexFromModuleAndMethod(AId);
    if Result>=0 then
      Inc(Result, cmdFirstPluginCommand);
  end
  else
    //usual item
    Result:= StrToIntDef(AId, -1);
end;


function DoLexerFindByFilename(const fn: string): TecSyntAnalyzer;
var
  c: TJsonConfig;
  fn_opt, s, ext: string;
begin
  fn_opt:= GetAppPath(cFileOptionsFiletypes);
  if FileExistsUTF8(fn_opt) then
  begin
    c:= TJsonConfig.Create(nil);
    try
      c.FileName:= fn_opt;

      //by filename
      s:= c.GetValue(ExtractFileName(fn), '');
      if s<>'' then
      begin
        Result:= AppManager.FindAnalyzer(s);
        Exit
      end;

      //by extention
      ext:= ExtractFileExt(fn);
      if ext<>'' then
      begin
        s:= c.GetValue('*'+ext, '');
        if s<>'' then
        begin
          Result:= AppManager.FindAnalyzer(s);
          Exit
        end;
      end;
    finally
      c.Free;
    end;
  end;

  Result:= DoFindLexerForFilename(AppManager, fn);
end;


procedure DoOps_SaveKeyItem(K: TATKeymapItem; const path, ALexerName: string);
var
  c: TJSONConfig;
  sl: TStringList;
  i: integer;
begin
  c:= TJSONConfig.Create(nil);
  sl:= TStringlist.create;
  try
    c.Formatted:= true;

    if ALexerName<>'' then
      c.Filename:= GetAppKeymap_LexerSpecificConfig(ALexerName)
    else
      c.Filename:= GetAppPath(cFileOptionsKeymap);

    c.SetValue(path+'/name', K.Name);

    sl.clear;
    for i:= 0 to High(TATKeyArray) do
      if K.Keys1[i]<>0 then
        sl.Add(ShortCutToText(K.Keys1[i]));
    c.SetValue(path+'/s1', sl);

    sl.clear;
    for i:= 0 to High(TATKeyArray) do
      if K.Keys2[i]<>0 then
        sl.Add(ShortCutToText(K.Keys2[i]));
    c.SetValue(path+'/s2', sl);
  finally
    c.Free;
    sl.Free;
  end;
end;


procedure DoOps_SaveKey_ForPluginModuleAndMethod(AOverwriteKey: boolean;
  const AMenuitemCaption, AModuleName, AMethodName, ALexerName, AHotkey: string);
const
  cKeyComboSeparator = '|';
var
  c: TJSONConfig;
  sl: TStringList;
  path, s_items, s_item: string;
begin
  //check-1: is key registered for any other command?
  if not AOverwriteKey then
    if AppKeymapHasDuplicateForKey(AHotkey, cKeyComboSeparator) then exit;

  c:= TJSONConfig.Create(nil);
  sl:= TStringlist.create;
  try
    c.Formatted:= true;

    if ALexerName<>'' then
      c.Filename:= GetAppKeymap_LexerSpecificConfig(ALexerName)
    else
      c.Filename:= GetAppPath(cFileOptionsKeymap);

    path:= AModuleName+','+AMethodName;

    //check-2: this command has already any key?
    if not AOverwriteKey then
      if c.GetValue(path+'/s1', sl, '') then exit;

    c.SetValue(path+'/name', Utf8Decode(AMenuitemCaption));

    sl.Clear;
    s_items:= AHotkey;
    repeat
      s_item:= SGetItem(s_items, cKeyComboSeparator);
      if s_item='' then Break;
      sl.Add(s_item);
    until false;
    c.SetValue(path+'/s1', sl);
  finally
    c.Free;
    sl.Free;
  end;
end;


(*
function GetActiveControl(Form: TWinControl): TWinControl;
var
  Ctl: TControl;
  i: integer;
begin
  Result:= nil;
  for i:= 0 to Form.ControlCount-1 do
  begin
    Ctl:= Form.Controls[i];
    if (Ctl is TWinControl) then
      if (Ctl as TWinControl).Focused then
        exit(Ctl as TWinControl);
    if Ctl is TPanel then
    begin
      Result:= GetActiveControl(Ctl as TPanel);
      if Assigned(Result) then exit;
    end;
    if Ctl is TATPanelSimple then
    begin
      Result:= GetActiveControl(Ctl as TATPanelSimple);
      if Assigned(Result) then exit;
    end;
  end;
end;
*)

function GetListboxItemHeight(const AFontName: string; AFontSize: integer): integer;
var
  bmp: TBitmap;
begin
  bmp:= TBitmap.Create;
  try
    bmp.Canvas.Font.Name:= AFontName;
    bmp.Canvas.Font.Size:= AFontSize;
    Result:= bmp.Canvas.TextHeight('Pyj')+3;
  finally
    FreeAndNil(bmp);
  end;
end;


procedure DoLexerEnum(L: TStringList; AlsoDisabled: boolean = false);
var
  i: Integer;
begin
  with AppManager do
    for i:= 0 to AnalyzerCount-1 do
      if AlsoDisabled or not Analyzers[i].Internal then
        L.Add(Analyzers[i].LexerName);
end;

procedure DoLexerExportFromLibToFile(an: TecSyntAnalyzer);
begin
  if Assigned(an) then
    an.SaveToFile(GetAppLexerFilename(an.LexerName));
end;


procedure CommandPlugins_DeleteItem(AIndex: integer);
var
  i: integer;
begin
  if (AIndex>=Low(FPluginsCmd)) and (AIndex<=High(FPluginsCmd)) then
  begin
    for i:= AIndex to High(FPluginsCmd)-1 do
    begin
      FPluginsCmd[i].ItemModule:= FPluginsCmd[i+1].ItemModule;
      FPluginsCmd[i].ItemProc:= FPluginsCmd[i+1].ItemProc;
      FPluginsCmd[i].ItemProcParam:= FPluginsCmd[i+1].ItemProcParam;
      FPluginsCmd[i].ItemCaption:= FPluginsCmd[i+1].ItemCaption;
      FPluginsCmd[i].ItemLexers:= FPluginsCmd[i+1].ItemLexers;
      FPluginsCmd[i].ItemInMenu:= FPluginsCmd[i+1].ItemInMenu;
      FPluginsCmd[i].ItemFromApi:= FPluginsCmd[i+1].ItemFromApi;
    end;
  end;
  with FPluginsCmd[High(FPluginsCmd)] do
  begin
    ItemModule:= '';
    ItemProc:= '';
    ItemProcParam:= '';
    ItemFromApi:= false;
  end;
end;

function CommandPlugins_GetIndexFromModuleAndMethod(AStr: string): integer;
var
  i: integer;
  SModule, SProc, SProcParam: string;
begin
  Result:= -1;

  SModule:= SGetItem(AStr);
  SProc:= SGetItem(AStr);
  SProcParam:= SGetItem(AStr);

  if SModule='' then exit;
  if SProc='' then exit;

  for i:= Low(FPluginsCmd) to High(FPluginsCmd) do
    with FPluginsCmd[i] do
    begin
      if ItemModule='' then Break;
      if (ItemModule=SModule) and (ItemProc=SProc) and (ItemProcParam=SProcParam) then exit(i);
    end;
end;


procedure CommandPlugins_UpdateSubcommands(AStr: string);
const
  cSepRoot=';';
  cSepParams=#10;
  cSepNameParam=#9;
var
  SModule, SProc, SParams, SItem, SItemParam, SItemCaption: string;
  N: integer;
begin
  SModule:= SGetItem(AStr, cSepRoot);
  SProc:= SGetItem(AStr, cSepRoot);
  SParams:= AStr;

  //del items for module/method
  for N:= High(FPluginsCmd) downto Low(FPluginsCmd) do
    with FPluginsCmd[N] do
      if (ItemModule=SModule) and (ItemProc=SProc) and (ItemProcParam<>'') then
        CommandPlugins_DeleteItem(N);

  //find index of first free item
  N:= Low(FPluginsCmd);
  repeat
    if FPluginsCmd[N].ItemModule='' then break;
    Inc(N);
    if N>High(FPluginsCmd) then exit;
  until false;

  //add items for SParams
  repeat
    SItem:= SGetItem(SParams, cSepParams);
    if SItem='' then break;

    SItemCaption:= SGetItem(SItem, cSepNameParam);
    SItemParam:= SItem;

    with FPluginsCmd[N] do
    begin
      ItemModule:= SModule;
      ItemProc:= SProc;
      ItemProcParam:= SItemParam;
      ItemCaption:= SItemCaption;
      ItemFromApi:= true;
    end;
    Inc(N);
    if N>High(FPluginsCmd) then exit;
  until false;
end;


function GetAppLangFilename: string;
begin
  if AppLangName='' then
    Result:= ''
  else
    Result:= GetAppPath(cDirDataLangs)+DirectorySeparator+AppLangName+'.ini';
end;

function GetLexerFilenameWithExt(ALexName, AExt: string): string;
begin
  if ALexName<>'' then
  begin
    ALexName:= StringReplace(ALexName, ':', '_', [rfReplaceAll]);
    ALexName:= StringReplace(ALexName, '/', '_', [rfReplaceAll]);
    ALexName:= StringReplace(ALexName, '\', '_', [rfReplaceAll]);
    ALexName:= StringReplace(ALexName, '*', '_', [rfReplaceAll]);
    Result:= GetAppPath(cDirDataLexerlib)+DirectorySeparator+ALexName+AExt;
  end
  else
    Result:= '';
end;

function GetAppLexerMapFilename(const ALexName: string): string;
begin
  Result:= GetLexerFilenameWithExt(ALexName, '.cuda-lexmap');
end;

function GetAppLexerFilename(const ALexName: string): string;
begin
  Result:= GetLexerFilenameWithExt(ALexName, '.lcf');
end;


function GetAppKeymapHotkey(const ACmdString: string): string;
var
  NCode, NIndex: integer;
begin
  Result:= '';
  if Pos(',', ACmdString)=0 then
    NCode:= StrToIntDef(ACmdString, 0)
  else
  begin
    NIndex:= CommandPlugins_GetIndexFromModuleAndMethod(ACmdString);
    if NIndex<0 then exit;
    NCode:= NIndex+cmdFirstPluginCommand;
  end;

  NIndex:= AppKeymap.IndexOf(NCode);
  if NIndex<0 then exit;
  with AppKeymap[NIndex] do
    Result:= KeyArrayToString(Keys1)+'|'+KeyArrayToString(Keys2);
end;


function SetAppKeymapHotkey(AParams: string): boolean;
var
  NCode, NIndex: integer;
  SCmd, SKey1, SKey2: string;
begin
  Result:= false;
  SCmd:= SGetItem(AParams, '|');
  SKey1:= SGetItem(AParams, '|');
  SKey2:= SGetItem(AParams, '|');

  if Pos(',', SCmd)=0 then
    NCode:= StrToIntDef(SCmd, 0)
  else
  begin
    NIndex:= CommandPlugins_GetIndexFromModuleAndMethod(SCmd);
    if NIndex<0 then exit;
    NCode:= NIndex+cmdFirstPluginCommand;
  end;

  NIndex:= AppKeymap.IndexOf(NCode);
  if NIndex<0 then exit;
  with AppKeymap[NIndex] do
  begin
    KeyArraySetFromString(Keys1, SKey1);
    KeyArraySetFromString(Keys2, SKey2);

    //save to keys.json
    DoOps_SaveKeyItem(AppKeymap[NIndex], SCmd,
      ''); //Py API: no need lexer override
  end;
  Result:= true;
end;


procedure AppKeymapCheckDuplicateForCommand(ACommand: integer; const ALexerName: string);
var
  itemSrc, item: TATKeymapItem;
  itemKeyPtr: ^TATKeyArray;
  i: integer;
begin
  i:= AppKeymap.IndexOf(ACommand);
  if i<0 then exit;
  itemSrc:= AppKeymap[i];

  for i:= 0 to AppKeymap.Count-1 do
  begin
    item:= AppKeymap.Items[i];
    if item.Command=ACommand then Continue;

    if KeyArraysEqualNotEmpty(itemSrc.Keys1, item.Keys1) or
       KeyArraysEqualNotEmpty(itemSrc.Keys2, item.Keys1) then itemKeyPtr:= @item.Keys1 else
    if KeyArraysEqualNotEmpty(itemSrc.Keys1, item.Keys2) or
       KeyArraysEqualNotEmpty(itemSrc.Keys2, item.Keys2) then itemKeyPtr:= @item.Keys2 else
    Continue;

    if MsgBox(Format(msgConfirmHotkeyBusy, [item.Name]), MB_OKCANCEL or MB_ICONWARNING)=ID_OK then
    begin
      //clear in memory
      KeyArrayClear(itemKeyPtr^);

      //save to: user.json
      DoOps_SaveKeyItem(item, IntToStr(item.Command), '');
      //save to: lexer*.json
      if ALexerName<>'' then
        DoOps_SaveKeyItem(item, IntToStr(item.Command), ALexerName);
    end;
  end;
end;

function AppKeymapHasDuplicateForKey(AHotkey, AKeyComboSeparator: string): boolean;
var
  item: TATKeymapItem;
  i: integer;
begin
  Result:= false;
  if AHotkey='' then exit;

  //KeyArrayToString has separator ' * '
  AHotkey:= StringReplace(AHotkey, AKeyComboSeparator, ' * ', [rfReplaceAll]);

  for i:= 0 to AppKeymap.Count-1 do
  begin
    item:= AppKeymap.Items[i];
    if (KeyArrayToString(item.Keys1)=AHotkey) or
       (KeyArrayToString(item.Keys1)=AHotkey) then exit(true);
  end;
end;


procedure AppKeymap_ApplyUndoList(AUndoList: TATKeymapUndoList);
var
  UndoItem: TATKeymapUndoItem;
  i, ncmd, nitem: integer;
begin
  for i:= 0 to AUndoList.Count-1 do
  begin
    UndoItem:= AUndoList[i];

    ncmd:= GetAppCommandCodeFromCommandStringId(UndoItem.StrId);
    if ncmd<0 then Continue;

    nitem:= AppKeymap.IndexOf(ncmd);
    if nitem<0 then Continue;

    AppKeymap.Items[nitem].Keys1:= UndoItem.KeyArray1;
    AppKeymap.Items[nitem].Keys2:= UndoItem.KeyArray2;
  end;
end;

function GetAppLexerPropInCommentsSection(const ALexerName, AKey: string): string;
begin
  with TIniFile.Create(GetAppLexerMapFilename(ALexerName)) do
  try
    Result:= Trim(ReadString('comments', AKey, ''));
  finally
    Free
  end;
end;

procedure MsgStdout(const Str: string; AllowMsgBox: boolean = false);
begin
  {$ifdef windows}
  if AllowMsgBox then
    MsgBox(Str, MB_OK+MB_ICONINFORMATION);
  {$else}
  System.Writeln(Str);
  {$endif}
end;


function AppEncodingShortnameToFullname(const S: string): string;
var
  i: integer;
begin
  Result:= '';
  if S='' then exit;
  for i:= Low(AppEncodings) to High(AppEncodings) do
    with AppEncodings[i] do
      if SameText(S, ShortName) then
        Exit(Name);
end;

function AppEncodingFullnameToShortname(const S: string): string;
var
  i: integer;
begin
  Result:= '';
  if S='' then exit;
  for i:= Low(AppEncodings) to High(AppEncodings) do
    with AppEncodings[i] do
      if SameText(S, Name) then
        Exit(LowerCase(ShortName));
end;

function AppEncodingListAsString: string;
var
  i: integer;
begin
  Result:= '';
  for i:= Low(AppEncodings) to High(AppEncodings) do
    with AppEncodings[i] do
      if ShortName<>'' then
        Result:= Result + LowerCase(ShortName) + #10;
end;


initialization
  InitDirs;
  InitEditorOps(EditorOps);
  InitUiOps(UiOps);

  AppKeymap:= TATKeymap.Create;
  InitKeymapFull(AppKeymap);
  InitKeymapForApplication(AppKeymap);

  FillChar(AppBookmarkSetup, SizeOf(AppBookmarkSetup), 0);
  AppBookmarkImagelist:= TImageList.Create(nil);

  FillChar(FAppSidePanels, SizeOf(FAppSidePanels), 0);
  FillChar(FAppBottomPanels, SizeOf(FAppBottomPanels), 0);

  AppShortcutEscape:= ShortCut(vk_escape, []);
  Mouse.DragImmediate:= false;

finalization
  FreeAndNil(AppKeymap);
  FreeAndNil(AppBookmarkImagelist);

end.


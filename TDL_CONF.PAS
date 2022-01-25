{$I tdl_dire.inc}

{$IFDEF USEOVERLAYS}
{$O+,F+}
{$ENDIF}
unit tdl_conf;
{
TDL configuration definitions and objects.  The goal is to have every piece
of configurable data for the program managed in these structures so that data
can be checked for correctness, as well as saved/loaded from disk quickly (as
parsing .INI files is slow on vintage hardware).
}

interface

uses
  DOS,
  objects,
  support,
  tdl_cach,
  tdl_glob;

const
  maxHandlers=256;

type
  windowposition=record
    x1,y1,x2,y2:byte;
  end;

  colorscheme=record
    Border,Title,Icon,HiHot,HiNorm,LoHot,LoNorm,Off:Byte;
    WinBorder,WinBody,WinIcon,WinTitle:byte;
    FavIcon, UnpIcon:byte;
    MiSTerTurbo,MiSTerSlow,MiSTerMedium,MiSTerFast:byte;
    Mouse:byte;
  end;

  (*
  {holds character "backfore" color attribute choices}
  colorchoices=record
    background,                         {desktop background}
    pickern,                            {picker normal text}
    pickerh:byte;                       {picker highlighted text}
  end;
  *)

  {
  TConfig is the master configuration record for the TDL.  It contains the
  location of the config.ini file, the index files, and data verification
  methods for said data.
  }
  PConfig=^TConfig;
  TConfig=object(TObject)
    numTitles:word;                     {Total number of titles in indexes}
    swapping:boolean;                   {swap to disk/ram when launching}
    logging:boolean;
    auditing:boolean;
    preloading:boolean;                 {preload indexes in ram}
    readonly:boolean;                   {treat filesystem as read-only (ie. CDROM)}
    edebug:boolean;                     {excessive debugging messages on startup}
    userlevel:userlevels;               {what level user is operating in}
    customVidMode:word;
    pauseAfterRun:boolean;
    startupCacheScan:boolean;

    datacacheDir:DirStr;                {cache directory}
    baseDir:DirStr;                     {base directory (where config file is)}
    swapDir:DirStr;                     {directory to hold the swap file}
    progLocs:PathStr;                   {paths to look for source files}
    subheader:PathStr;                  {optional subheader, limited to 80 ch}
    startupDir:DirStr;                  {directory user was in at program start}
    exePath:DirStr;                     {full path to where exe is running from}

    titlesIDXname:baseftype;
    filesIDXname:baseftype;
    tPos:windowposition;                {titles picker dimensions}
    {colors:colorchoices;}

    {exec/spawno trashes the PSP, so if we want to retain command-line
    arguments, we should grab them first, then use them later}
    wantCondensed,
    wantSnow,
    wantAuditExport:boolean;
    freeLowDOSRam:word;                 {in paragraphs; 0 if we couldn't determine}
    EMSatStartup,
    XMSatStartup:longint;
    MiSterTurbo:boolean;
    MiSTerSlow:word;
    MiSTerMedium:word;
    MiSTerFast:word;
    colors:colorscheme;
    listSortField:byte;
    listSortAscend:boolean;
    disableBlink:boolean;
    header:string[50];
    Joystick:Boolean;
    JoyDebug:Boolean;
    JoyAutoCalibrate:Boolean;
    JoyAxisACentMax:word;
    JoyAxisACentMin:word;
    JoyAxisBCentMax:word;
    JoyAxisBCentMin:word;
    favIcon:Char;
    unpIcon:Char;
    MouseChar:Byte;
    persistSelected:Byte;
    Constructor Init(cfile,bdir:PathStr);

    Function FilesIDXLoc:PathStr;
    Function TitlesIDXLoc:PathStr;

    PRIVATE
    configFile:pathStr;
  end;

var
  Config:PConfig; {global configuration object for the TDL}
  fileCache:PFileCache; {global uncompressed file cache object (we init it here)}

implementation

uses
  totSYS,
  totLOOK,
  inifiles;

const
  INIBufSize=18*512*2; {enough to hold an entire 1.44MB track}

Constructor TConfig.Init;
var
  ini:PINIfile;
  iniresult:PINIResultType;
  s:string;
  tp:PathStr;

  N: NameStr;
  E: ExtStr;

  Function isPositive(s:string):boolean;
  begin
    if (upstring(s)='ENABLED')
    or (upstring(s)='TRUE')
    or (upstring(s)='ON')
    or (upstring(s)='YES')
    or (upstring(s)='1')
      then isPositive:=true
      else isPositive:=false;
  end;

  Function getSortField(s:string):byte;
  {var
     str:string;}
  begin
    {str := upstring(s)}
    if     (s = 'DOS' ) then getSortField  :=  $00
    else if(s = 'NAME') then getSortField  :=  $01
    else if(s = 'EXT' ) then getSortField  :=  $02
    else if(s = 'SIZE') then getSortField  :=  $03
    else if(s = 'TIME') then getSortField  :=  $04
    else                       getSortField  :=  $01;
  end;

begin
  Inherited Init;
  {Grab startup dir so we can chdir back to it at exit}
  GetDir(0,startupDir);
  startupDir:=StdPath(startupDir);

  {grab the exe path}
  FSplit(paramstr(0), exePath, N, E);

  {because TP cannot typecase strings, we have to do this:}
  baseDir:=StdPath(bdir);
  configFile:=baseDir+cfile;
  if not fileexists(configFile) then begin
    {User likely started tdl from the PATH outside its homedir.
    Head over there and try again.}
    s:=exePath;
    dec(byte(s[0])); {chop trailing slash to work with CHDIR}
    baseDir:=exePath;
    configFile:=baseDir+cfile;
    if not fileexists(configFile)
      then fatalerror(1,'Config file '+configFile+' not found');
    {if we found it, we should go over there to prevent further issues}
    CHDIR(s);
  end;
  {read config file for program defaults}

  {set some reasonable default values}
  userlevel:=regular;
  swapping:=false;
  logging:=false;
  auditing:=false;
  readonly:=false;
  preloading:=true;
  progLocs:='files';
  header           := TDLTitle;
  MiSterSlow       :=$A1A1;
  MiSterMedium     :=$A1A0;
  MiSterFast       :=$A100;
  MiSterTurbo      :=true;
  disableBlink     :=false;
  listSortField    :=1;
  listSortAscend   :=true;
  joystick         :=false;
  joyDebug         :=false;
  joyAutoCalibrate :=true;
  joyAxisACentMin  :=130;
  joyAxisACentMax  :=400;
  joyAxisBCentMin  :=130;
  joyAxisBCentMax  :=400;
  favIcon          :=favIconDft;
  unpIcon          :=unpIconDft;
  persistSelected  :=0;
  MouseChar        :=$02;

  with colors do
  begin
    Mouse          := $4f;
    Border         := $1b;
    Title          := $1e;
    Icon           := $7f;
    HiHot          := $21;
    HiNorm         := $2f;
    LoHot          := $1e;
    LoNorm         := $17;
    Off            := $19;
    WinBorder      := $19;
    WinBody        := $1e;
    WinIcon        := $1e;
    WinTitle       := $1b;
    FavIcon        := $1c; {bright red foreground}
    UnpIcon        := $19; {bright blue foreground}
    MiSTerTurbo    := Title;
    MiSTerSlow     := (MiSTerTurbo and $f0) or $02;
    MiSterMedium   := (MiSTerTurbo and $f0) or $0e;
    MiSterFast     := (MiSTerTurbo and $f0) or $0c;
  end;

  datacacheDir:='cache.dir';
  swapDir:='.';
  {set initial title list to start one row down}
  {assume 80x25 screen; can change later}
  with tpos do begin
    x1:=1; y1:=4; x2:=79; y2:=23;
  end;
  (*
  with colors do begin
    if Monitor^.ColorOn then begin
      background:=$07;
      pickern:=$70;
      pickerh:=$3f;
      {let's try using the global TOT vars}
      pickern:=LookTOT^.vMenuLoNorm;
      pickerh:=LookTOT^.vMenuHiNorm;
    end else begin
      background:=$07;
      pickern:=$07;
      pickerh:=$70;
    end;
  end;
  *)

  {configure the system using the configuration file}
  ini:=new(PINIFile,init(configFile,readfile,INIBufSize));
  if ini=NIL then begin
    fatalerror(2,'Couldn''t open INI file: '+s);
    exit;
  end;

  {read lines until we get the [prefs] section}
  INIResult:=ini^.ReadNextItem; {read very first line}
  while (INIResult<>nil) do begin
    if ini^.newSection then begin;
      ini^.ACKSection;
      if INIResult^.section='prefs'
        then break;
    end;
    INIResult:=ini^.ReadNextItem;
  end;
  if INIResult=nil
    then fatalerror(1,configFile+' mangled?');

  {now read lines until EOF, or a new section}
  INIResult:=ini^.ReadNextItem; {read first line of prefs}
  while (INIResult<>nil) do begin
    {new section? get out of here}
    if ini^.newSection then break;
    {populate user preferences}
    with INIResult^ do begin
      if upstring(key)='PROGLOCATIONS' then progLocs:=value;
      if upstring(key)='CACHELOCATION' then datacacheDir:=value;
      if upstring(key)='USERLEVEL' then begin
        if upstring(value)='KIOSK' then userlevel:=kiosk;
        if upstring(value)='REGULAR' then userlevel:=regular;
        if upstring(value)='POWER' then userlevel:=power;
      end;
      with colors do
      begin
        if upstring(key)='COLOR_MOUSE'         then Mouse        :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_BORDER'        then Border       :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_TITLE'         then Title        :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_ICON'          then Icon         :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_HIHOT'         then HiHot        :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_HINORM'        then HiNorm       :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_LOHOT'         then LoHot        :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_LONORM'        then LoNorm       :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_OFF'           then Off          :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_WIN_BORDER'    then WinBorder    :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_WIN_BODY'      then WinBody      :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_WIN_ICON'      then WinIcon      :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_WIN_TITLE'     then WinTitle     :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_FAV_ICON'      then FavIcon      :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_UNP_ICON'      then UnpIcon      :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_MISTER_TURBO'  then MiSTerTurbo  :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_MISTER_SLOW'   then MiSTerSlow   :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_MISTER_MEDIUM' then MiSTerMedium :=hexStrToLong(upstring(value));
        if upstring(key)='COLOR_MISTER_FAST'   then MiSTerFast   :=hexStrToLong(upstring(value));
      end;
      if upstring(key)='FAVICON'         then favIcon          := Char(hexStrToLong(upstring(value)));
      if upstring(key)='UNPICON'         then unpIcon          := Char(hexStrToLong(upstring(value)));
      if upstring(key)='LISTSORTFIELD'   then listSortField    := getSortField(upstring(value));
      if upstring(key)='LISTSORTASCEND'  then listSortAscend   := isPositive(value);
      if upstring(key)='DISABLEBLINK'    then disableBlink     := isPositive(value);
      if upstring(key)='SWAPPING'        then swapping         := isPositive(value);
      if upstring(key)='AUDITING'        then auditing         := isPositive(value);
      if upstring(key)='PAUSEAFTERRUN'   then pauseAfterRun    := isPositive(value);
      if upstring(key)='FORCELOGGING'    then logging          := isPositive(value);
      if upstring(key)='PRELOADING'      then preloading       := isPositive(value);
      if upstring(key)='CACHESCAN'       then startupCacheScan := isPositive(value);
      if upstring(key)='JOYSTICK'        then Joystick         := isPositive(value);
      if upstring(key)='JOYAUTOCAL'      then JoyAutoCalibrate := isPositive(value);
      if upstring(key)='MISTERTURBO'     then MiSTerTurbo      := isPositive(value);
      if upstring(key)='VESA'            then customvidmode    := hexStrToLong(upstring(value));
      if upstring(key)='MISTERSLOW'      then MiSTerSlow       := hexStrToLong(upstring(value));
      if upstring(key)='MISTERMEDIUM'    then MiSTerMedium     := hexStrToLong(upstring(value));
      if upstring(key)='MISTERFAST'      then MiSTerFast       := hexStrToLong(upstring(value));
      if upstring(key)='JOYAXISACENTMIN' then joyAxisACentMin  := hexStrToLong(upstring(value));
      if upstring(key)='JOYAXISACENTMAX' then joyAxisACentMax  := hexStrToLong(upstring(value));
      if upstring(key)='JOYAXISBCENTMIN' then joyAxisBCentMin  := hexStrToLong(upstring(value));
      if upstring(key)='JOYAXISBCENTMAX' then joyAxisBCentMax  := hexStrToLong(upstring(value));
      if upstring(key)='PERSISTSELECTED' then persistSelected  := hexStrToLong(value);
      if upstring(key)='MOUSECHAR'       then MouseChar        := hexStrToLong(upstring(value));
      if upstring(key)='HEADER'          then header           := value;
      if upstring(key)='SUBHEADER'       then begin
        {leading spaces are truncated -- we will put one back unless
        leading char is a colon, which should not have a leading space}
        subheader:=value;
        if subheader[1]<>':' then insert(#32,subheader,1);
      end;
    end;
    INIResult:=ini^.ReadNextItem;
  end;

  {Close the INI file.  If we have more sections to read, we can
  repeat the process.}

  dispose(ini,done);

  {$IFDEF DPMI}
  swapping:=false;
  {$ENDIF}

  fileCache:=new(PFileCache,init(datacacheDir));

  {Initialize data structures/indexes}
  titlesIDXname:='titles.idx';
  filesIDXname:='files.idx';
  if (fileexists(baseDir+titlesIDXname) = false)
  or (fileexists(baseDir+filesIDXname) = false)
    then FatalError(1,'Index files not found at '+baseDir);

end;

Function TConfig.FilesIDXLoc;
begin
  FilesIDXLoc:=basedir+filesIDXname;
end;

Function TConfig.TitlesIDXLoc;
begin
  TitlesIDXLoc:=baseDir+titlesIDXname;
end;


end.


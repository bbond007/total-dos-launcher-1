{$I tdl_dire.inc}

{$IFDEF USEOVERLAYS}
{$O+,F+}
{$ENDIF}
unit tdl_main;

{
Main application functionality.  Keeping the main program (event loop and
supporting code) in its own unit allows us to:
  - Develop and compile directly in a slow, memory-constrained DOS environment
  - Enable more granular overlay management if it turns out we need it
  - Program defensively
}

interface

Procedure PrintHelp;
function  Launch(tid:word;
                 pcursor,
                 pwinloc:Longint ):boolean;
procedure TDL_Init;
procedure TDL_EventLoop;
procedure TDL_Done;

implementation

uses
  DOS,
  joylib,
  support,
  strings,
  cmdlin,
  totFAST,
  totSYS,
  totINPUT,
  totLOOK,
  totLIST,
  totKEY,
  totMSG,
  streams,
  tdl_glob,
  tdl_cach,
  tdl_conf,
  tdl_inde,
  tdl_cons,
  tdl_hand,
  tdl_tset,
  tdl_audi;

const
  favsOn:boolean=false;

type
  txtcoords=record
    x,y:byte;
  end;

  pcursorLoc=record
     pcursor,
     pwinloc:Longint;
  end;

var
  jcloc:txtcoords; {jumpcursor location}

var
  titleSets:array[0..maxTitleSets-1] of PTitleSet;
  titleMetadata:PMetadata;
  MiSTerSpeed:Byte;
  startVmode:Byte;

procedure PrintPressAnyKey;
begin
  writeln('Hit a key to continue TDL startup.');
end;

procedure Joystick_Init(bQuiet:Boolean);

var
  JoyAxisACenter, JoyAxisBCenter:word;

begin
  key.vJoystick := config^.Joystick;

  if (key.vJoystick) then
  begin

    JoyAxisACenter := JoystickPosition(JoystickAAxisX);
    JoyAxisBCenter := JoystickPosition(JoystickAAxisY);

    if (JoyAxisACenter = $FFFF) or
       (JoyAxisACenter = $FFFF) or
       JoystickButton(JoystickAButton2)
       then
    begin
      if not bQuiet then
        writeln('Joystick not detected. Disabled!');
      key.vJoystick    := false;
      config^.Joystick := false;
    end
    else
    begin
      if (config^.JoyAutoCalibrate) then
      begin
        config^.JoyAxisACentMin := JoyAxisACenter - (JoyAxisACenter div 2);
        config^.JoyAxisACentMax := JoyAxisACenter + (JoyAxisACenter div 2);
        config^.JoyAxisBCentMin := JoyAxisBCenter - (JoyAxisBCenter div 2);
        config^.JoyAxisBCentMax := JoyAxisBCenter + (JoyAxisBCenter div 2);
      end;

      key.vJoyAxisACentMin := config^.JoyAxisACentMin;
      key.vJoyAxisACentMax := config^.JoyAxisACentMax;
      key.vJoyAxisBCentMin := config^.JoyAxisBCentMin;
      key.vJoyAxisBCentMax := config^.JoyAxisBCentMax;

      if(not bQuiet or config^.JoyDebug) then
      begin;
        writeln('Enabling (expeirmental) joystick support:');
        if (config^.JoyAutoCalibrate) then
          writeln('Auto-calibrating joystick...');
        writeln('  - Axis X cen min ', #26, ' ', key.vJoyAxisACentMin);
        writeln('  - Axis X cen max ', #26, ' ', key.vJoyAxisACentMax);
        writeln('  - Axis X cur pos ', #26, ' ', JoyAxisACenter);
        writeln('  - Axis Y cen min ', #26, ' ', key.vJoyAxisBCentMin);
        writeln('  - Axis Y cen max ', #26, ' ', key.vJoyAxisBCentMax);
        writeln('  - Axis Y cur pos ', #26, ' ', JoyAxisBCenter);
      end;
    end; {joystick detected}

    if(config^.JoyDebug) then
    begin
      PrintPressAnyKey;
      key.getinput;
    end;
  end; {key.vJoystick}
end;

procedure TDL_Init;
{
Initialize TDL, first with defaults and the refine using the config file.
TDL never changes the initial video mode when initializing, so that
error and status messages are always visible.
}
var
  sf,sd,temps:string;
  base:nameStr;
  full:string[12];
  ext:extStr;
  dir:dirStr;
  filepath:PathStr;
  w:word;
  {wantNlines:byte;}
  tf:PFileStruct;
  bQuiet:Boolean;

  procedure quietwriteln(str:String);
  begin
    if not (bQuiet) then
      writeln(str);
  end;

  procedure quietwrite(str:String);
  begin
    if not (bQuiet) then
      write(str);
  end;

begin
  {If user requested help, then print it and exit}
  if is_param('?') or is_param('h')
    then PrintHelp;
  MiSterSpeed:=0;

  RecordDOSScreen;

  if is_param('q') then
    bQuiet:=true
  else
    bQuiet:=false;

  {
  if not (bQuiet) then
    writeln('Current screen mode '#26' ',oldScreenParams.videomode);
  }

  {determine TDL base directory and configuration file to use:
  sf = startup configuration file
  sd = startup directory}
  if non_flag_count>0 then sf:=non_flag_param(1) else sf:='tdl.ini';
  if non_flag_count>1 then sd:=non_flag_param(2) else sd:='';
  sd:=StdPath(FExpand(sd));
  {attempt TDL config init}

  quietwriteln('Configuring launcher.  Use "-h" for command-line options.');
{ quietwriteln('Configuring '+TDLtitle+'.  Use "-h" for command-line options.'); }

  quietwriteln('Reading '+sf+'...');
  config:=new(pconfig,init(sf,sd));
  if config=nil
    then fatalerror(1,'Error while configuring; check '+sd+'\'+sf);

  {set config options based on command-line options}
  if is_param('d') then config^.edebug:=true;
  if is_param('r') then config^.readonly:=true;
  if is_param('c') then config^.wantCondensed:=true;
  if is_param('f') then config^.wantSnow:=true;
  if is_param('j') then config^.Joystick := true;
  if is_param('k') then
  begin
    config^.JoyDebug := true;
    config^.Joystick := true;
  end;
{ if is_param('s') then config^.wantAuditExport:=true; } (*not working*)

  {attempt TDL handlers init}

  quietwriteln('Registering handlers from handlers.ini...');
  Handlers:=new(PHandlers,init(config^.basedir+'handlers.ini'));
  {We can only show files properly for up to 42 filemasks.  If we have
  more handlers than that, switch to power user mode so that we only have
  to use one mask (*.*).}
  if Handlers^.Count>42 then config^.userlevel:=power;

  {Now that we have our handlers, let's try to use our swapping mechanism
  to determine how much memory is available for programs by running
  FREERAM (if it's available) and storing the result to show the user.
  config^.freeLowDOSRAM is 0 unless we change it in this code.}
  filepath:=fsearch('FREERAM.COM','utils;distro\utils');
  if filepath<>'' then begin
    {determine extension so we know which handler to use}
    fsplit(filepath,dir,base,ext);
    delete(ext,1,1); {remove period}
    if not Handlers^.handle(ext,filepath,dir)
      then fatalerror(2,'Couldn''t launch '+filepath +' -- Try swapping=disabled in TDL.INI')
      else config^.freeLowDOSRAM:=word(ptr($40,$f0)^);
  end else begin
    {if we couldn't find freeram, then fake it with an estimate}
    config^.freeLowDOSRAM:=memavail;
  end;

  {If we used SWAPPO, our PSP is gone, so all command-line parameters after
  this point are now empty!  Hope you got what you needed before this line!}

  {Track our EMS and XMS usage}
  config^.EMSatStartup:=ems_memavail;
  config^.XMSatStartup:=xms_memavail;

  Joystick_Init(bQuiet);

  {attempt initializing indexes}

  quietwriteln('Initializing files index...');
  files:=new(PFileIndex,
         init(config^.baseDir+config^.filesIDXname,config^.preloading));
  if files=nil then fatalerror(1,'Files index init failed');
  quietwriteln('Initializing titles index...');
  titles:=new(PTitleIndex,
          init(config^.baseDir+config^.titlesIDXname,config^.preloading));
  if titles=nil then fatalerror(1,'Titles index init failed');

  quietwrite('Title metadata: ');
  temps:=stdpath(sd)+'titles.dat';

  if config^.readonly then begin
    quietwriteln('Read-only mode: disabled');
    titleMetadata:=new(PMetadata,init('',config^.numTitles));
  end else begin
    quietwriteln('Initializing using '+temps);
    titleMetadata:=new(PMetadata,init(temps,config^.numTitles));
  end;

  {Ensure cache size is known before continuing}
  if not (bQuiet) then
    writeln('Inspecting file cache at ',fileCache^.path);
  fileCache^.Remaining;
  if not (bQuiet) then
    writeln(fileCache^.megsfree,' MB available for cache use.');
  if config^.startupCacheScan then begin
    quietwrite('Validating cache entries...');
    for w:=0 to config^.numtitles-1 do begin
      if titleMetadata^.getFlag(w,m_unpacked)=true then begin
        files^.retrieve(w,tf);
        if fileCache^.cDirExists(tf)=false then begin
          titleMetadata^.clearFlag(w,m_unpacked);
          titleMetadata^.changed:=true;
        end;
      end;
    end;
    {quiet}writeln('done.');
  end;


  if (config^.userlevel=power) or (config^.edebug=true) then begin
    writeln('Performing additional checks:');
    with config^ do begin
      {power users like to ensure they copied the stuff over correctly}
      write('Index locations: ');
      write(filesIDXloc);
      writeln(' ',titlesIDXloc);
      write('Checking index files for correctness: ');
      write('files... ');
      if files^.verify=false then fatalerror(1,'File index inconsistent');
      write('titles... ');
      if titles^.verify=false then fatalerror(1,'Title index inconsistent');
      writeln('passed.');

      {power users want to know everything}
      writeln('Number of titles: ',numTitles);
      writeln('Base directory: ',baseDir);
      writeln('Swapping enabled: ',swapping);
      writeln('Auditing enabled: ',auditing);
      writeln('Preloading enabled: ',preloading);
      writeln('Cache Directory: ',fileCache^.path);
      writeln('Startup Directory: ',startupDir);
    end;
    PrintPressAnyKey;
    asm
      xor     ax,ax
      int     16h
    end;
  end;

  {populate the initial list of titles we're working with}
  titleSets[activeSet]:=New(PTitleset,init(config^.numTitles));

  with titleSets[activeSet]^ do
    for w:=0 to numTitles-1 do
      titleIDs^[w]:=w;

  {init the audit log}
  if config^.auditing then begin
    auditLog:=new(PAuditLog,init(config^.basedir+'AUDIT.DAT'));
  end;

  {set up the screen}

  {If changing screen mode, we need to re-enable the screen. construct to
  pick up the new dimensions.}
  {Also: If we noticed we're already in a condensed mode coming in, make
  sure we record that fact so that restores go correctly.}
  if (oldScreenParams.videorows=43) or (oldScreenParams.videorows=50)
    then config^.wantCondensed:=true;
  if config^.wantCondensed then begin
    Monitor^.SetCondensed;
    config^.customvidmode:=3;
  end;
  {if VESA text mode specified, set it}
  w:=config^.customvidmode;
  if w>$100 then begin
    w:=setVESA(w);
    if w<>0 then begin
      write('Attempt to set VESA mode ',hexword(config^.customvidmode),'failed: ');
      case w of
        1:writeln('VESA not installed');
        2:writeln('VESA BIOS cannot set mode');
      end;
    end;
  end;
  if config^.customvidmode<>0 then begin
    {reset mouse, totsys.monitor, and screen so that they pick up new dimensions}
    Mouse.done;
    fastDone;
    dispose(monitor,done);

    SysInit;
    fastInit;
    {Mouse.init; }
    {Mouse.Show; }


  end;
  {set a marker for 40-col mode}
  if Monitor^.width=40
    then config^.customVidMode:=40;




  Mouse.done;
  Mouse.init;
  Mouse.SetMouseCursorStyle(config^.MouseChar,
                            config^.Colors.Mouse);
  Mouse.Show;
  if (screen.depth > 25) then
    mouse.EnableSoftMouseHack(screen.width,screen.depth);
  Mouse.Confine(1,1,screen.width,screen.depth);

  {
  Customize color choices.  For MDA, make selected/special text black on white, everything else white on black.
  For color, pick blue background and some reasonable choices for others.
  At some point, the user will be able
  to pick any color set they like, but for now, these are the defaults.
  }
  {Bor,Tit,Icon,HiHot,HiNorm,LoHot,LoNorm,Off}
  {SetWindow(Border,Body,Icons,Title:byte);}
  if Monitor^.ColorOn
    then begin
      {LookTOT^.SetMenu($1b,$1e,$7f,$31,$3f,$1e,$17,$19);}
      with config^.colors do
      begin
        LookTOT^.SetMenu(Border,Title,Icon,HiHot,HiNorm,LoHot,LoNorm,Off);
        LookTOT^.SetWindow(WinBorder,WinBody,WinIcon,WinTitle);
        faviconcol:=FavIcon;
        unpiconcol:=UnpIcon;
      end;
    end else begin
      LookTOT^.SetMenu($0F,$09,$78,$78,$70,$01,$07,$07);
    end;

  DOSScreen:=new(PScreenObj,init);
  DOSScreen^.save;
  with config^ do begin
    tpos.y2:=screen.depth-1;
    tpos.x2:=screen.width;
    screen.clear(LookTOT^.vMenuBorder,#0);
    {If provided a subheader in TDL.INI, use it.  Truncate if necessary.}
    temps:=config^.header + config^.subheader;
    if length(temps) > screen.width-1
      then temps[0]:=char(screen.width-1);
    screen.WriteCenter(1,LookTOT^.vMenuTitle,temps);
    jcloc.x:=16;
    jcloc.y:=tpos.y1-2;
    screen.WriteAt(1,tpos.y1-2,LookTOT^.vMenuLoNorm,jumplabel); screen.gotoxy(jcloc.x,jcloc.y);
    screen.WriteAt(1,tpos.y1-1,LookTOT^.vMenuLoNorm,'Or, choose from the following programs:');

    {status bar}
    screen.PartClear(1,screen.depth,screen.width,screen.depth,
      LookTOT^.vMenuHiNorm,' ');
    screen.WriteHI(1,screen.depth,
      LookTOT^.vMenuHiHot,LookTOT^.vMenuHiNorm,TDLStatus);

    {init message console now that we have our screen mode locked in}
    if config^.readonly
      then begin
        MsgConsole:=new(PMConsole,init(''));
        MsgConsole^.logmsg(warning,'Read-only filesystem: Debug log will not be written to a file!');
      end else
        MsgConsole:=new(PMConsole,init(config^.basedir+'tdl.log'));
    if (userlevel=power) or (logging=true) then begin
      MsgConsole^.verboseLog:=true;
    end;
    if config^.wantSnow
      then boolean(snowprone):=false;
    if boolean(snowprone)
      then MsgConsole^.logmsg(info,'Slower display routines enabled to avoid CGA "snow"')
      else MsgConsole^.logmsg(info,'No CGA "snow" checking will be performed when writing to screen RAM.');
  end;

  {power users want to know everything}
  with MsgConsole^ do begin
    with config^ do begin
      logmsg(info,'Number of titles: '+inttostr(numTitles));
      logmsg(info,'Base directory: '+baseDir);
      logmsg(info,'Swapping enabled: '+boolToStr(swapping,'',''));
      logmsg(info,'Preloading enabled: '+boolToStr(preloading,'',''));
      logmsg(info,'Data Cache Directory: '+fileCache^.path);
    end;
  end;


  if(config^.disableBlink) then
    disableBlink;

end;

Procedure PrintHelp;
begin
  asm
    jmp @start
@message:
    db 0ah,'Usage: TDL.EXE <switches>',0dh,0ah,0ah

    db 'Switches:',0dh,0ah
    db '-?, -h  This help',0dh,0ah
    db '-c      Set 43-line (EGA) or 50-line (VGA) mode.',0dh,0ah
    db '        (If you need more lines than that, see TDL.INI for VESA options.)',0dh,0ah
    db '-r      Instructs TDL that it is on read-only media (ie. CDROM or DVDROM)',0dh,0ah
    db '        and that it should not try to write anything to its local filesystem.',0dh,0ah
    db '        This disables "favorites" as well as writing the debug log to disk.',0dh,0ah
    db '-d      Print excessive debugging messages during initialization.',0dh,0ah
    db '        Used for troubleshooting only.',0dh,0ah
    db '-f      Always use fast display routines on all CGA systems.',0dh,0ah
    db '        This may cause "snow" or display corruption on true CGA adapters.',0dh,0ah
(*  db '-nXX    Override screen detection and force XX lines onscreen.',0dh,0ah
    db '        Debugging option; submit an issue if you''re forced to use this.',0dh,0ah*)
(*  db '-s      Export the AUDIT.DAT audit log to .CSV format.',0dh,0ah *)
    db '-j      Enable Joystick support.',0dh,0ah
    db '-k      Enable Joystick support with debug.',0dh,0ah
    db '-q      Use quiet startup mode.',0dh,0ah
    db 0ah,'$'

@start:
    push ds
    mov ax,0900h
    lea dx,@message
    mov bx,cs
    mov ds,bx
    int 21h
    pop ds
  end;
  halt(255);
end;


Procedure PopGeneralInfo;
var
  foomsg:PMessageObj;
  s:string[12];
  s2:string;
begin
  new(foomsg,init(2,'TDL info and stats'));
  with foomsg^ do begin
    case config^.userlevel of
      kiosk:s:='KIOSK';
      regular:s:='default';
      power:s:='Power User';
    end;
    with config^ do begin
      addline(' Swapping: '+boolToStr(swapping,'ENABLED','disabled'));
      if freeLowDOSRAM <> 0 then begin
        addline(' '+inttostr((longint(freeLowDOSRAM) * longint(16)) div 1024)
                   +' KB DOS RAM availble to launched programs ');
        addline(' ');
      end;
      addline(' TDL operating mode: '+s);
      addline(' TDL Heap remaining: '+inttostr(memavail div 1024)+' KB');

      {Report how much EMS or XMS we're using.  The logic below accounts
      for QEMM, DOSBox, and others reporting the same amount of EMS and XMS
      always available (they both draw EMS and XMS from an internal pool
      of managed RAM).  This code favors EMS use over XMS (because it's
      faster) so we favor reporting on EMS in a dual EMS/XMS situation.}
      s2:='';
      if config^.XMSatStartup > xms_memavail
        then s2:=inttostr((config^.XMSatStartup - xms_memavail) div 1024)+' KB of XMS';
      if config^.EMSatStartup > ems_memavail
        then s2:=inttostr((config^.EMSatStartup - ems_memavail) div 1024)+' KB of EMS';
      if s2<>''
        then addline(' TDL is using '+s2+' to accelerate index operations');

      addline(' # of Titles: '+inttostr(numtitles)+' ('+inttostr(titleMetadata^.Used)+' with additional metadata) ');
      addline(' Debug messsages logged to disk: '+boolToStr(logging,'ENABLED','disabled'));
      addline(' Treating filesystem as read-only: '+boolToStr(readonly,'YES','no'));
      {addline(' Excessive debug messages: '+boolToStr(edebug,'ENABLED','disabled'));}
      addline(' Pause after execution: '+boolToStr(pauseAfterRun,'ENABLED','disabled'));
      addline(' ');
      if fileCache^.bytesfree > (1024*1024)
        then s:=inttostr(fileCache^.megsFree)+' MB free)'
        else s:=inttostr(fileCache^.bytesFree div 1024)+' KB free)';
      addline(' Cache directory: '+fileCache^.path+' ('+s+' ');
    end;
    addline(' ');
    show;
  end;
  dispose(foomsg,done);
end;

Procedure PopTitleInfo(tid:word);
var
  foomsg:PMessageObj;
  s:string[12];
  tfbuf:PFileStruct;
  ttbuf:PTitleStruct;
  s2:string;

begin
  new(foomsg,init(2,'Information on this title'));
  titles^.retrieve(tid,ttbuf);
  files^.retrieve(tid,tfbuf);
  with foomsg^ do begin
    addline(' Title: '+ttbuf^.title);
    addline(' Filename: '+tfbuf^.name);
    s2:=' Cache Directory: ';
    if fileCache^.cDirExists(tfbuf)
      then s2:=s2+fileCache^.cDir(tfbuf)
      else s2:=s2+'(not yet unpacked)';
    addline(s2);
    show;
  end;
  dispose(foomsg,done);
end;


Procedure setMiSTerSpeed(speed:Byte);
begin
  case speed of
    0:PORTW[$8888]:=config^.MiSterFast;
    1:PORTW[$8888]:=config^.MiSterSlow;
    2:PORTW[$8888]:=config^.MiSterMedium;
  end;
  {
  begin
    asm
     mov DX, $8888
     mov AX, $A1A1
     out DX, AX
     end;
  end;
  }
end;

(* Old TXT for testing)

procedure savePos(pcursor,
                  pwinloc:Longint);
var
  saveFile:Text;
begin
  Assign(saveFile, config^.exepath + CursorFileName);
  Rewrite(saveFile);
  WriteLn(saveFile, pCursor);
  WriteLn(saveFile, pwinloc);
  Close(saveFile);
end;

procedure restorePos(var pCursor:Longint;
                     var pwinloc:Longint;
                       maxcursor:LongInt);
var
  str:String[10];
  Code: Integer;
  saveFile:Text;
  pwheight:Byte;

  procedure setDefault;
  begin
    pcursor := 0;
    pwinloc := 0;
  end;

begin
  if (config^.persistSelected = 1) or
     (config^.persistSelected = 2) then
  begin
    Assign(saveFile, config^.exepath + CursorFileName);
    {$I-}
    Reset(saveFile);
    {$I+}
    if IOResult = 0 then
    begin
      ReadLn(saveFile,str);
      Val(str, pcursor, Code);
      if (Code <> 0) then
        setDefault;
      ReadLn(saveFile,str);
      Val(str, pwinloc, Code);
      if (Code <> 0) then
        setDefault;
      Close(saveFile);
      pwheight:=config^.tpos.y2-config^.tpos.y1-1;
      if(pcursor > maxcursor) or
        (pwinloc > maxcursor - pwheight) then
        setDefault;
    end
    else
      setDefault;
  end
  else
    setDefault;

end;
*)

procedure savePos(pCursor,
                  pWinLoc:Longint);
var
  curLoc:pcursorLoc;
  saveFile:file of pcursorLoc;
begin
  curLoc.pCursor := pCursor;
  curLoc.pWinLoc := pWinLoc;
  Assign(saveFile, config^.exepath + CursorFileName);
  Rewrite(saveFile);
  write(saveFile, curLoc);
  Close(saveFile);
end;

procedure restorePos(var pCursor:Longint;
                     var pWinLoc:Longint;
                       maxcursor:LongInt);
var
  curLoc:pcursorLoc;
  saveFile:file of pcursorLoc;
  pwheight:Byte;
  procedure setDefault;
  begin
    pcursor := 0;
    pwinloc := 0;
  end;

begin
  if (config^.persistSelected = 1) or
     (config^.persistSelected = 2) then
  begin
    Assign(saveFile, config^.exepath + CursorFileName);
    {$I-}
    Reset(saveFile);
    {$I+}
    if IOResult = 0 then
    begin
      {$I-}
      read(saveFile, curLoc);
      Close(saveFile);
      {$i+}
      if IOResult <> 0 then
        setDefault
      else
      begin
        pCursor := curLoc.pCursor;
        PWinLoc := curLoc.pWinLoc;
      end;
      pwheight:=config^.tpos.y2-config^.tpos.y1-1;
      if(pcursor > maxcursor) or
        (pwinloc > maxcursor - pwheight) then
        setDefault;
    end
    else
      setDefault;
  end
  else
    setDefault;
end;


function Launch(tid:word;
                pcursor,
                pwinloc:Longint ):boolean;
{
Execution flow:

After picking a title, extraction handler is searched for.
  (If extraction handler not found, try using execution handler, in case
  the user copied over .txt or .gif files too)
Once extraction handler found, cache directory is searched for.
  If cache dir not found, create via extraction handler.
Once cache dir found/created, all extensions in it are searched for and
checked against all execution handlers, then only those with handlers
are displayed for user to choose.
  If only one found, launches automatically based on user level.

Notes:  It might be tempting to eliminate the distinction between
extraction and execution handlers, but this is necessary because we need
to handle the use case of the user copying over both "game.zip" and
"game.txt".  Otherwise, a blind search for the game\ cache directory
will always succeed if .zip launched first, and game.txt will never launch.

*** DEMDR4 and also note custom chartask if you want to trap different keys
*** actually, will probably do it myself.  use a listarrayobj
*** with a custom messagetask (chapter 9)
}
var
  base:nameStr;                       {basename of title we want to run}
  full:string[12];
  ext:extStr;
  dir:dirStr;
  wrkDir:string;
  temps:string;
  filepath:PathStr;                     {fully-qualified path to source file}
  tcachedir:PathStr;
  unpackEstimate:longint;

  tfbuf:PFileStruct;
  ttbuf:PTitleStruct;

  ListWin:pListDirSortObj;
  x1,y1,x2,y2,style:byte;

  s,filemasks:string;
  b:byte;
  p:pointer;

  procedure prepScreenForExec;
  begin
    screen.clear($07,' ');
    screen.writeCenter(1,$0f,'Executing:');
    screen.writeCenter(2,$07,filepath);
    screen.gotoxy(1,3);
  end;

begin
  { save every time item is selected }
  if (config^.persistSelected = 2) then
    SavePos(pcursor,pwinloc);

  {assume everything will go ok}
  Launch:=true;
  msgConsole^.logmsg(info,'Attempting to Launch title #'+inttostr(titleSets[activeSet]^.titleids^[tid])+':');
  if titleMetadata^.changed then begin
    msgConsole^.logmsg(info,'Flushing metadata cache');
    titleMetadata^.flush;
  end;
  {grab title so that we can determine the id needed for file}
  titles^.retrieve(tid,ttbuf);
  msgConsole^.logmsg(info, ttbuf^.title);
  {determine cache directory}
  if not files^.retrieve(tid,tfbuf)
      then die('Could not retrieve file info');
  if tfbuf^.id<>tid then die('Wrong file retrieved');
  tcachedir:=fileCache^.cDir(tfbuf);
  {files can be in multiple drives/paths; find where we put our file}
  full:=StrPas(tfbuf^.name);
  filepath:=fsearch(full,config^.ProgLocs);
  if filepath='' then begin
    popUserMessage(error,'PATH "'+config^.ProgLocs+'" did not contain "'+full+'".  Did you delete it?');
    Launch:=false;
    exit;
  end;
  {determine extension so we know which handler to use}
  fsplit(filepath,dir,base,ext);
  delete(ext,1,1); {remove period}

  {Diskspace check: Do we have the disk space to handle this?}
  unpackEstimate:=fileCache^.EstimateCacheUsage(ext,filepath);
  if (DirExists(tcachedir) = false)
  and (fileCache^.bytesfree < unpackEstimate) then begin
    s:='This title could require up to '
      +inttostr(unpackEstimate div 1024)
      +' KB of disk space to run properly, but your cache only has '
      +inttostr(fileCache^.bytesfree div 1024)
      +' KB free.  Please remove files from '
      +fileCache^.path
      +' to free up enough disk space.';
    popUserMessage(error,s);
    Launch:=false;
    exit;
  end;

  {Is the file directly launchable?  (ie. .txt, .gif, etc.)
  If so, launch it; if not, it is an archive that needs extraction.}
  if Handlers^.Exists(ext)=execution
    then begin
      {This file is already "unpacked" so mark it as such}
      titleMetadata^.setFlag(tid,m_unpacked);
      titleMetadata^.changed:=true;
      prepScreenForExec;
      Handlers^.handle(ext,filepath,dir);
    end else begin
      if Handlers^.Exists(ext)=extraction then begin
        if not DirExists(tcachedir) then begin
          msgConsole^.logmsg(info,'cache dir '+tcachedir+' not found; attempting to create');
          MkDirCDir(tcachedir);
          if not DirExists(tcachedir) then die('Could not create '+tcachedir);
          {burst archive into cache dir}
          screen.clear($07,' ');
          if screen.width<80
            then s:='This program requires unpacking.'
            else s:='This program requires unpacking before it can be executed.';
          screen.writeCenter(1,$0f,s);
          screen.writeCenter(2,$87,'Please wait...');
          screen.gotoxy(1,3);
          {Perform extraction.
          If extraction didn't go well, warn the user, but keep going.}
          if not Handlers^.handle(ext,filepath,tcachedir) then begin
            msgConsole^.logmsg(tdl_cons.error,'Error code received during extraction');
            PopUserMessage(warning,
              'There was an error reported while unpacking this title.  TDL will '+
              'attempt to continue.  If your progam doesn''t work, '+
              'consult tdl.log to see the exact command-line that failed, '+
              'then exit TDL and run it yourself to determine the exact error.'
            );
          end else begin
            {After successful unpack, update cache stats}
            fileCache^.Remaining;
          end;
        end;

        {If we are here, then this file was unpacked successfully}
        titleMetadata^.setFlag(tid,m_unpacked);
        titleMetadata^.changed:=true;

        {Switch to unpacked cache dir and obtain list of files we have
         registered execution handlers for.  Helper logic ensues:
           If power user, always give full list to users and let them pick.
           Otherwise:
             If only one found, execute immediately
             If multiple found but only one is exe or com, execute immediately
             Anything else, show list to users and let them pick}

        GetDir(0,WrkDir);
        chdir(tcachedir);
        s:='';
        {Power users see everything; others only see what we have handlers for.
        Power users can also sort the list if they want.  Also, power users
        can select an unknown file and it will use the "???" handler.}
        ListWin:=new(pListDirSortObj,init);
        filemasks:='';
        if config^.userlevel=power then begin
          filemasks:='*.*';
        end else begin
          {build file masks from registered executable handlers.
          Avoid the default handler.}
          for b:=0 to Handlers^.count-1 do begin
            if (PHandler(Handlers^.at(b))^.category=execution)
            and (b<>Handlers^.defaultHandler)
              then filemasks:=filemasks+'*.'+PHandler(Handlers^.at(b))^.extension+' ';
          end;
        end;
        ListWin^.settagging(false);
        with ListWin^ do begin
           {Init;}
           setTagging(false); {do not want user to "tag" files}
           {Power users can navigate directories; all others are "chrooted"}
           if config^.userlevel=power
             then ReadFiles(filemasks,AnyFile)
             else ReadFiles(filemasks,AnyFile-directory);
           SortFiles(config^.ListSortField, config^.ListSortAscend);
           if vTotPicks=0
             then msgConsole^.logMsg(warning,'No files found in '+tcachedir)
             else msgConsole^.logMsg(info,'Found '+inttostr(vTotPicks)+' files in '+tcachedir);
           {If we only have one file, launch immediately}
           {s:=vActiveDir + GetString(pred(vTopPick+vActivePick),0,0);}
           s:='';
           if (vTotPicks=1) and (config^.userlevel<>power) then begin
             s:=vActiveDir + GetString(vTopPick,0,0);
           end else begin
             if Monitor^.width<80
               then begin
                 win^.setTitle('Pick one to execute');
                 win^.getsize(x1,y1,x2,y2,style);
                 x1:=x1 div 2; x2:=x2 div 2;
                 win^.setsize(x1,y1,x2,y2,style);
               end else begin
                 win^.setTitle('Multiple components found; pick one to execute:');
               end;
             Go; {display the file picker dialog}
           end;
           if s=''
             then if (LastKey = kEsc) or (Lastkey = wClose)
               then s:='ABORTED*'
               else s:=GetHiString;
        end;
        dispose(ListWin,done);

        if s='ABORTED*' then begin
          chdir(WrkDir);
          MsgConsole^.logmsg(info,'User declined to choose a program');
          Launch:=false;
          exit; {get out of Launch()}
        end;

        {determine extension so we know which handler to use}
        filepath:=s;
        fsplit(filepath,dir,base,ext);
        delete(ext,1,1); {remove period}

        {if using VESA modes set screen back to what is was when
         program started... }
        Mouse.Done;
        if config^.customVidMode<>0 then
          RestoreDosScreen;
        if(config^.disableBlink) then
          enableBlink;

        prepScreenForExec;
        {if we have an execution handler for this, use it,
        otherwise we use the default (fallback) handler}

        {only save when acutal item is launched}

        {if (config^.persistSelected = 1) then  }
          SavePos(pcursor,pwinloc);
        if(config^.MiSTerTurbo) then
          setMiSTerSpeed(MiSterSpeed);
        if Handlers^.Exists(ext)=execution
          then Handlers^.handle(ext,filepath,dir)
          else Handlers^.handle('???',filepath,dir);

        if(config^.MiSTerTurbo) then
          setMiSTerSpeed(0);
        if(config^.disableBlink) then
          disableBlink;

      { Dump Keyboard Buffer }
        while key.KeyPressed do
          key.Readkey;
        MsgConsole^.logmsg(info,'Switching back to '+WrkDir);
        chdir(WrkDir);
      end else begin
        die('Don''t know how to handle "'+ext+'" files - add to handlers.ini');
      end;
    end;
end;

procedure exportAuditLog;
var
  ol:text;
  s,ds:string;
  w:word;
  ttbuf:PTitleStruct;

  function DTString(td:datetime):string;
  begin
    DTString:=inttostr(auditLog^.Entry.StartTime.month)+'/'
             +inttostr(auditLog^.Entry.StartTime.day)+'/'
             +inttostr(auditLog^.Entry.StartTime.year)+' '
             +inttostr(auditLog^.Entry.StartTime.hour)+':'
             +inttostr(auditLog^.Entry.StartTime.min);

  end;

  function buildASCIILine(_tid:word):string;
  begin
    titles^.retrieve(_tid,ttbuf);
    buildASCIILine:=DTString(auditLog^.Entry.StartTime)+','
      +DTString(auditLog^.Entry.EndTime)+','
      +inttostr(auditLog^.Entry.minsActive)+','
      +ttbuf^.title;
  end;

begin
  assign(ol,'audit.csv');
  rewrite(ol);
  writeln('Start Time,End Time,Minutes Active,Title');

  auditLog^.getFirst;
  writeln(ol,buildASCIILine(auditLog^.Entry.titleID));
  for w:=1 to auditLog^.totalEntries-1 do begin
    auditLog^.getNext;
    writeln(ol,buildASCIILine(auditLog^.Entry.titleID));
  end;
  close(ol);
end;

procedure TDL_EventLoop;
{
Picker draw logic:
  sliding window always shows where picker cursor (pcursor) is
  sliding window only moves if pcursor moves
  if pgup/dn, window slides by one unit, leaving pcursor in same place
  home/end do exactly that, with pcursor at top and bottom of list
  Don't repaint entire list if you don't have to!  Think of the snowy CGAs!
  (I swear to $DEITY I'm going to be the last human alive to remeber CGA snow)
}
const
  iconsPad=1+numMetaFlags;                 {padding on left edge for icons}
  escapeKey:word=kEsc;
  clearBlank:boolean=false;
  searchStrMax=20;
  kBackSpace=$08;

label
  nofavorites;

var
  w,dl:word;
  b:byte;
  s:string;
  a:array[0..15] of string;
  searchStr:String[searchStrMax];
  index:byte;
  p:pointer;
  tid:word;
  iconPosX,iconPosY:byte;

  ttbuf:PTitleStruct;
  pcursor,opcursor:longint;             {picker cursor location(s)}
  pwheight:byte;                        {picker window height}
  pwwidth:word;                         {picker window width}
  pwinloc,opwinloc:longint;             {picker window location(s)}
  mouseX, mouseY:Byte;      {stuff for mouse support}
  MouseL, mouseC, mouseR : boolean;
  scrollPct,
  scrollMax,
  scrollCur:Byte;
  Ticks: longint ABSOLUTE $0040:$006c;
  time : longint;
  procedure updateStatusBar;
  const
    negofs=11;
  var
    s2:string;
  begin
    s2:='#'+intPadded(succ(pcursor),5,'0')
       +'/'+intpadded(titleSets[activeSet]^.numTitles,5,'0');
    screen.WriteAT(screen.width-negofs,screen.depth,
      LookTOT^.vMenuHiNorm,s2);
  end;

  procedure showStatus(on:boolean;s:string);
  var
    b:byte;
  begin
    b:=LookTOT^.vMenuLoNorm AND $F0;
    b:=b OR (b SHR 4);
    if on
    { then screen.writeat(jcloc.x+3,jcloc.y,LookTOT^.vMenuLoNorm OR $80,s) }
    { else screen.writeat(jcloc.x+3,jcloc.y,b,s);                          }
      then screen.WriteCenter(jcloc.y,LookTOT^.vMenuLoNorm OR $80,s)
      else screen.WriteCenter(jcloc.y,b,s);
  end;

  function isValidChar(ch:Char):Boolean;
  begin
    isValidChar:=TRUE;
    {
    if(ord(ch)  = 32)                      then exit;
    if(ord(ch) >= 65) and (ord(ch) <= 90)  then exit;
    if(ord(ch) >= 97) and (ord(ch) <= 122) then exit;
    if(ord(ch) >= 48) and (ord(ch) <= 57)  then exit;
    }
    if not(ch in ['-', '''']) then exit;
    isValidChar:=FALSE;
  end;

  procedure doBinarySearch;
  var
    index:Byte;
    bsl,bsr,bsm:Integer;
    bsstr:titleStrType;
    str:String[20];

  begin
    {showStatus(true,'Seeking, please wait'); not necessary with binary search}

    str[0]:=Char(0);
    for index := 1 to Byte(searchStr[0]) do
      if isValidChar(searchStr[index]) then
        str:=str+searchStr[index];

    {Binary search:}
    bsl:=0; bsr:=titleSets[activeSet]^.numTitles-1; bsm:=bsr shr 1;
    while bsl<=bsr do
    begin
      bsm:=(bsl+bsr) shr 1;
      titles^.retrieve(titleSets[activeSet]^.titleIDs^[bsm],ttbuf);

      bsstr[0]:=Char(0);

      for index := 1 to Byte(ttbuf^.title[0]) do
      begin
        if isValidChar(ttbuf^.title[index]) then
          bsstr:=bsstr+UpCase(ttbuf^.title[index]);
        if(bsstr[0]=str[0]) then break;
      end;

      if (bsstr<str)
        then bsl:=bsm+1
        else bsr:=bsm-1;
      end;
      {The above code was written to handle duplicates, but can land on N-1.
      To fix this, we check if that happened and adjust:}
      if (bsstr<str) and (bsm<titleSets[activeSet]^.numTitles-1)
        then inc(bsm);

      pcursor:=bsm;
      pwinloc:=bsm;
      opwinloc:=-1;               {force window refresh}

      {showStatus(false,'Seeking, please wait'); {not necessary with binary search}
  end;

  procedure showMiSTerSpeed;
  begin
    if(config^.MiSTerTurbo) then
    begin
      screen.writeat(screen.width-11,2, config^.colors.MiSTerTurbo, 'Turbo=');
      case MiSTerSpeed of
        0:screen.writeat(screen.width-5,2,
          { (config^.colors.MiSTerTurbo and $f0) or } config^.colors.MiSTerFast,
          'Fast  ');
        1:screen.writeat(screen.width-5,2,
          { (config^.colors.MiSTerTurbo and $f0) or } config^.colors.MIsTerSlow,
          'Slow  ');
        2:screen.writeat(screen.width-5,2,
          { (config^.colors.MiSTerTurbo and $f0) or } config^.colors.MiSTerMedium,
          'Medium');
      end;
    end;
  end;

  procedure doHome;
  begin
    pcursor  := 0;                    {re-home picker cursor}
    pwinloc  := 0;                    {re-home sliding window}
    opwinloc :=-1;                    {force a window refresh}
  end;

  procedure DoLaunch;
  begin
    {Mouse.Location(mouseX, MouseY);}
    recordKeyState;
    tmpScreenSave;
    showStatus(true,'Preparing for launch...');
    if config^.auditing then
      auditLog^.newEntry(titleSets[activeSet]^.titleids^[pcursor]);
    {Launch it!  If launch was successful, clean up:}
    if Launch(titleSets[activeSet]^.titleids^[pcursor], pcursor, pwinloc) then
    begin
      if config^.pauseAfterRun then pauseForUser;
      RestoreDOSScreen;  { <-- Why do this AFTER launch? TODO }

      {if we have any goofy modes set, restore them}
      if config^.customVidMode<>0 then
      begin
        case config^.customVidMode of
          3:Monitor^.SetCondensed;
          $100..$110:setVESA(config^.customVidMode);
        end;
      end;
      if(config^.disableBlink) then
        disableBlink;
    end;
    if config^.auditing
    then auditLog^.closeEntry;
      tmpScreenRestore;
    restoreKeyState;

    Mouse.Location(mouseX, MouseY);
    Mouse.Done;
    Mouse.Init;
    Mouse.SetMouseCursorStyle(config^.MouseChar,
                              config^.Colors.Mouse);
    Mouse.Move(mouseX, MouseY);
    Mouse.Confine(1,1,screen.width,screen.depth);
    Mouse.Show;
    Mouse.WaitForRelease;
  end;

  function MouseInWindow:Boolean;
  begin
    if (mouseY < pwheight + succ(config^.tpos.y1)) and
       (mouseY > config^.tpos.y1) and
       (MouseX < config^.tpos.x2) and
       (MouseX > config^.tpos.x1) then
          MouseInWindow := true
        else
          MouseInWindow := false;
  end;

  procedure IndexMiSTerSpeed;
  begin
   inc(MiSterSpeed,1);
   if(MiSterSpeed > 2) then
     MiSterSpeed:=0;
   ShowMiSTerSpeed;
  end;

begin
  searchStr[0]:=Char(0);
  showMiSTerSpeed;
  {check for short-circuit operations here and avoid the entire event loop
  if we are doing a one-off operation}

  {export the audit log?}
  if config^.wantAuditExport then begin
    PopUserMessage(info,' Hit ENTER to export audit log to AUDIT.CSV ');
    exportAuditLog;
    exit;
  end;

  if config^.userlevel=kiosk
    then escapeKey:=kAltMinus;
  with config^.tpos do Screen.Box(X1,Y1,X2,Y2,LookTOT^.vMenuLoNorm,4);
  restorePos(pcursor,
             pwinloc,
             titleSets[activeSet]^.numTitles);

  pwwidth:=config^.tpos.x2 - config^.tpos.x1 - (iconsPad+1); {leave room for icon columns}
  p:=@s;
  updateStatusBar;
  opwinloc:=pwinloc+1;
  opcursor:=pcursor+1;
  repeat
    {msgConsole^.logmsg(info,'Refreshing display');}

    {update vertical scrollbar}
    with config^.tpos do
      screen.WriteVScrollBar(X2,Y1,Y2,LookTOT^.vMenuLoNorm,pcursor+1,titleSets[activeSet]^.numTitles);

    {determine height of our drawloop}
    pwheight:=config^.tpos.y2-config^.tpos.y1-1;
    {if we have less titles than screen lines, truncate}
    if pwheight>titleSets[activeSet]^.numTitles
      then begin
        pwheight:=titleSets[activeSet]^.numTitles;
        {Clear the part of the display that will never get updated.
        We only need to do this once, so keep track if we've done it.
        Otherwise, 8088 systems will suffer}
        if clearblank then begin
          with config^.tpos do
            screen.partclear(x1+iconspad-numMetaFlags,y1+pwheight+1,x2-1,y2-1,LookTOT^.vMenuLoNorm,#0);
          clearblank:=false;
        end;
      end;

    {draw our choices}
    for dl:=0 to pwheight-1 do begin
      {If we're not scrolling, we don't need to repaint the entire screen.
      Only repaint the changed lines.}
      if (opwinloc=pwinloc)
        then if not (abs((pwinloc+dl)-pcursor) in [0..1])
          then continue;
      tid:=titleSets[activeSet]^.titleIDs^[pwinloc+dl];
      if not titles^.retrieve(tid,ttbuf)
        then die('Could not retrieve title: '+inttostr(tid));
      s:=ttbuf^.title;
      b:=byte(s[0]);
      byte(s[0]):=pwwidth;              {clamp to window width}
      if b<pwwidth
        then strPadAfter(s,b);          {pad to window width}
      {determine when to use highlight color}
      if pwinloc+dl=pcursor {this is where the menu bar is}
        then b:=LookTOT^.vMenuHiNorm
        else b:=LookTOT^.vMenuLoNorm;
      {Now draw the title line in the picker:}
      with config^.tpos do begin
        screen.writeat(x1+iconsPad+1,y1+dl+1,b,s);
        iconPosX:=x1+iconspad;
        iconPosY:=y1+dl+1;
        {Is this title a favorite?  If so, print the "favorite" icon}
        if titleMetadata^.getFlag(tid,m_favorite)
          then screen.writeat(iconPosx,iconPosY,faviconcol,config^.favicon)
          else screen.writeat(iconPosx,iconPosY,LookTOT^.vMenuLoNorm,' ');
        {Has this title been unpacked already?}
        dec(iconPosX);
        if titleMetadata^.getFlag(tid,m_unpacked)
          then screen.writeat(iconPosx,iconPosY,unpiconcol,config^.unpicon)
          else screen.writeat(iconPosx,iconPosY,LookTOT^.vMenuLoNorm,' ');
      end;
    end;
    {msgConsole^.logmsg(info,'Getting input');}
    key.getinput;
    opwinloc:=pwinloc;
    opcursor:=pcursor;

    {bb7}
    {handle cursor movement}
    case key.lastkey of

      513:begin {left mouse button}
        time := Ticks;
        repeat
          Mouse.Status(mouseL,
                       mouseC,
                       mouseR,
                       mouseX,
                       mouseY);
        until mouseL = false;
        {cancel mouse button long press}
        if (Ticks - time < 18) then
        begin
          if (MouseY = 2) and
                  (MouseX >= screen.width-11) then
          begin
            IndexMiSTerSpeed;
          end
          else if (MouseY = screen.Depth) then { status bar }
          begin
             case mouseX of
               1..7:begin
                 recordKeyState;
                 tmpScreenSave;
                 popHelp;
                 tmpScreenRestore;
                 restoreKeyState;
               end;
               43..56:Begin
                 DoLaunch;
               end;
               57..67:begin
                 key.vLastkey := escapeKey;
               end;
             end;
             Mouse.WaitForRelease;
          end
          else if (MouseY = 1) then { F10 }
          begin
            recordKeyState;
            popAbout;
            restoreKeyState;
            Mouse.WaitForRelease;
          end
          else if (MouseX = config^.tpos.x2) then {Mouse click in scroll area}
          begin
            if(MouseY = config^.tpos.y1 ) then { Scroll UP }
            begin
              dec(pcursor,pwheight);
              dec(pwinloc,pwheight);
              opwinloc:=-1;
            end
            else if(MouseY = config^.tpos.y2) then
            begin
              inc(pcursor,pwheight);           { Scroll Down }
              inc(pwinloc,pwheight);
              opwinloc:=-1;
            end
            else if (MouseY > config^.tpos.y1) and { scroll % }
                    (MouseY < config^.tpos.y2) then
            begin
              ScrollMax := config^.tpos.y2 - config^.tpos.y1 - 2;
              ScrollCur := MouseY - config^.tpos.y1 - 1;
              ScrollPCT := (ScrollCur * 100) div ScrollMax;
            { Writeln('PCT --> ', ScrollPCT,'
                       CUR --> ', ScrollCur,'
                       MAX --> ',ScrollMax); }
              pwinloc   := (titleSets[activeSet]^.numTitles - pwheight) *
                            ScrollPct div 100;
              pcursor   := (titleSets[activeSet]^.numTitles -1) *
                            ScrollPct div 100;
              opwinloc  := -1;
            end;
          end { mouse click in scroll area }
          else if (MouseInWindow) then
          begin
            pcursor := pwinloc + mouseY - succ(config^.tpos.y1);
            opwinloc:=-1;
          end;
        end; { time - ticks > 18 }
      end; { 513 }
      523:begin { left mouse button double click }
          if (MouseInWindow) then
            DoLaunch;
          end;
      514:begin {right mouse button}
            key.vLastkey := escapeKey;
          end;
      kUp:begin
        dec(pcursor);
        if pcursor<pwinloc then dec(pwinloc);
      end;
      kDown:begin
        inc(pcursor);
        if pcursor>pwinloc+pwheight-1 then inc(pwinloc);
      end;
      kPgUp:begin
        dec(pcursor,pwheight);
        dec(pwinloc,pwheight);
        opwinloc:=-1;                   {force a window refresh}
      end;
      kPgDn:begin
        inc(pcursor,pwheight);
        inc(pwinloc,pwheight);
        opwinloc:=-1;                   {force a window refresh}
      end;
      kHome:begin
        doHome;
      end;
      kEnd:begin
        pcursor:=titleSets[activeSet]^.numTitles-1; {point to last title}
        pwinloc:=pcursor;               {this will get clamped later}
        opwinloc:=-1;                   {force a window refresh}
      end;
      kF3:begin
        IndexMiSTerSpeed;
      end;
      kF4:begin
        if config^.Joystick then
        begin
          Joystick_Init(true);
        end;
      end;
      kBackSpace:begin
        if(Byte(searchStr[0])>0) then
        begin
          searchStr[0]:=Char(Byte(searchStr[0])-1);
          screen.writeat(jcloc.x+Byte(searchStr[0]),jcloc.y,LookTOT^.vMenuLoHot, ' ');
          screen.gotoxy(jcloc.x+Byte(searchStr[0]),jcloc.y);
          if(Byte(searchStr[0])=0) then
            doHome
          else
            doBinarySearch;
        end;
      end;
      kDel:begin
        if(Byte(searchStr[0])>0) then
        begin
          screen.ClearText(jcloc.x, jcloc.y, jcloc.x+Pred(Byte(searchStr[0])), jcloc.y);
          screen.gotoxy(jcloc.x, jcloc.y);
          searchStr[0] := char(0);
        end;
        doHome;
      end;
      ord(' '),
      ord('-'),
      ord('.'),
      ord(''''),
      ord('0')..ord('9'),
      ord('A')..ord('Z'),
      ord('a')..ord('z'):begin
        if (Byte(searchStr[0])<searchStrMax)
             (* Don't let first char be space *)
          and ((Byte(searchStr[0])>0) or (key.lastkey<>ord(' ')))then
          begin
            searchStr:=searchStr+UpCase(chr(key.lastkey));
            screen.writeat(jcloc.x,jcloc.y,LookTOT^.vMenuLoHot, searchStr); (*ch);*)
            screen.gotoxy(jcloc.x+Byte(searchStr[0]),jcloc.y);
            doBinarySearch;
          end;
      end;
      kF2:begin {Toggle favorite for where the picker cursor is on}
        with titleMetadata^ do begin
          {get the real full title id we are sitting on}
          w:=titlesets[activeSet]^.TitleIDs^[pcursor];
          toggleFlag(w,m_favorite);
          changed:=true;
          (* if not metaFlags^[w] then opwinloc:=-1 {force window refresh} *)
          if not getFlag(w,m_favorite) then opwinloc:=-1 {force window refresh if not set (why are we doing this again??)}
        end;
      end;
      kCtlF:begin
        if not favson then begin
          {build a new title set out of just the favorites}
          {find how many favorites there are}
          w:=titleMetadata^.countFlag(m_favorite);
          {no favorites?  Get out of here}
          if w=0
            then goto nofavorites; {yes, not pure pascal-elegant. So sue me.}
          {build new title set}
          inc(activeSet);
          titleSets[activeSet]:=New(PTitleSet,init(w));
          {populate new title set}
          w:=0;
          {we use "with" to preload addressing to the existing larger titleset, as each of its elements will be iterated}
          with titleSets[activeSet-1]^ do begin
            for dl:=0 to numTitles-1 do begin
              {intentionally not using getFlag() here because we need the speed}
              if (titleMetadata^.metaFlags^[TitleIDs^[dl]] AND m_favorite)=m_favorite then begin
                titleSets[activeSet]^.TitleIDs^[w]:=dl;
                inc(w);
              end;
            end;
          end;
          clearBlank:=true;
        end else begin
          {discard our favorites titleset}
          dispose(titleSets[activeSet],done);
          titleSets[activeSet]:=nil;
          dec(activeSet);
        end;
        doHome;
        favson:=not favson;             {toggle "favorites on" status}
nofavorites:
      end;
      kEnter:begin {LAUNCH!}
        DoLaunch;
      end;
      kCtlF3:begin {show debug console}
        MsgConsole^.show;
        pause;
        MsgConsole^.hide;
      end;
      kF10:begin {show About This Program window}
        recordKeyState;
        popAbout;
        restoreKeyState;
      end;
      kF9:begin {show program info dialog}
        recordKeyState;
        popGeneralInfo;
        restoreKeyState;
      end;
      kCtlI:begin {show title info dialog}
        recordKeyState;
        popTitleInfo(titleSets[activeSet]^.titleids^[pcursor]);
        restoreKeyState;
      end;
      kF1:begin {show help screen}
        recordKeyState;
        tmpScreenSave;
        popHelp;
        tmpScreenRestore;
        restoreKeyState;
      end;
      kAltF5:begin {show DOS screen}
        tmpScreenSave;
        DOSScreen^.display;
        pause;
        tmpScreenRestore;
      end;
    else
      begin
      end;
    end;
    {adjust/clamp cursor and sliding window movement}
    {msgConsole^.logmsg(info,'Adjusting picker window vars');}
    if pcursor<0 then pcursor:=0;
    if pcursor>=titleSets[activeSet]^.numTitles
      then pcursor:=titleSets[activeSet]^.numTitles-1;
    if pwinloc<0 then pwinloc:=0;
    if pwinloc+pwheight>titleSets[activeSet]^.numTitles-1
      then begin
        pwinloc:=titleSets[activeSet]^.numTitles;
        pwinloc:=pwinloc-pwheight;
        if pwinloc<0 then pwinloc:=0;
      end;

    {msgConsole^.logmsg(info,'Updating status line');}
    updateStatusBar;
  until key.lastkey=escapeKey;
  {msgConsole^.logmsg(info,'Exiting picker loop');}
end;

procedure TDL_Done;
{
Close TDL down gracefully so we can check for programming errors
}
var
  w:word;
  s,s2:string;
  b:byte;
begin
  titleMetadata^.flush;
  dispose(titleMetadata,done);
  {free message console}
  dispose(MsgConsole,done);

  {free any working title sets}
  for w:=maxTitleSets-1 downto 0 do
    if titleSets[w]<>nil
      then if titleSets[w]^.TitleIDs<>nil
        then dispose(titleSets[w],done);

  s:=config^.startupDir; {grab startup dir before we trash object}

  if(config^.disableBlink) then
    enableBlink;

  if config^.auditing then dispose(auditLog,done);
  dispose(files,done);
  dispose(titles,done);
  dispose(handlers,done);
  dispose(fileCache,done);
  dispose(config,done);
  dispose(DOSScreen,done);
  tmpScreenRestore; {this will also deallocate it}
  OldScreenParams.cursorpos:=$0000;
  RestoreDOSScreen;

  writeln('Exiting '+TDLtitleFull);
  {$IFDEF SHOWBUILDINFO}
  writeln(TDLbuildInfo);
  {$ENDIF}
  writeln('Have a nice DOS!');

  {$IFDEF FINAL}
  {Switch back to the directory we started from. Massage path into a form
  that works with CHDIR. If raw drive, preserve slash so that CHDIR does
  what we want if the user called TDL from the root dir of any drive.}
  if length(s)<>3 then dec(byte(s[0]));
  CHDIR(s);
  {$ENDIF}
end;

end.

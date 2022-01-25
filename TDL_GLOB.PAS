unit tdl_glob;
{
Contains global constants and type definitions.
}

interface

uses
  support;

const
  maxTitles=maxbufsize div sizeof(word);
  maxCacheableTitles=maxbufsize div sizeof(longint);
  TDLtitleFull='MiSTer AO486 Launcher (Total Dos Launcher) V.87';
  TDLtitle='MiSTer AO486 Launcher';
  {$IFDEF SHOWBUILDINFO}
  TDLbuildInfo=#26' BinaryBond007 build 1/24/2022 '#27;
  {$ENDIF}
  (*TDLstatus='F1=Help~³~'#24'/'#25'/PgUp/PgDn/Home/End = Navigate~³~Enter = START~³~ESC=exit~³~';*)
  TDLstatus='F1=Help~³~'#24'/'#25'/PgUp/PgDn/Home/End = Navigate~³~Enter = LAUNCH~³~ESC = exit~³~';
  jumpLabel='Jump by title: ';

  numAboutLines=11;
  AboutText:array[0..numAboutLines-1] of pChar=(
    '',
    ' Project originator: Jim Leonard',
    ' ',
    ' We owe a debt of gratitude to:',
    '   Randy Hyde (swapping tech)',
    '   Duncan Murdoch (stream tricks)',
    '   Norbert Juffa (system library optimization)',
    '   Bob Ainsbury (interface primitives)',
    '',
    ' MiSTer Enhancements: BinaryBond007',
    ''
  );

  {metadata bitflag icon indicators}
  faviconDft=#03; {heart}
  favIconCol:byte=$0f;
  unpiconDft=#18;
  unpIconCol:byte=$0f;
  immediateExit:boolean=false;
  { File to save cursor location persisting reboot }
  CursorFileName='TDL.CUR';
  
type
  PTitleArray=^TTitleArray;
  TTitleArray=array[0..maxTitles] of word;

  PTitleOffsets=^TTitleOffsets;
  TTitleOffsets=array[0..maxCacheableTitles-1] of longint;

  baseftype=string[12];
  cmdlinetype=string[127-sizeof(baseftype)];
  titleStrType=string[132]; {Max screenmode we'll support is 132x60}

  handlertype=(extraction,execution);
  userlevels=(kiosk,regular,power);

  MD5hash=array[0..15] of byte;

  PFileStruct=^TFileStruct;
  TFileStruct=record
    ID:word;
    name:array[0..12-1] of char;
  end;

  PTitleStruct=^TTitleStruct;
  TTitleStruct=record
    ID:word;
    Hash:MD5hash;
    title:titleStrType;
  end;

implementation

end.
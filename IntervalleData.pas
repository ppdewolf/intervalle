unit IntervalleData;

{$MODE Delphi}



//Changed code: 1.the date was added in intervalleLog(see line 35) in order to
//control, when the intervalle programm really ends on grounds that it isn't
//possible to see, if the compilation dures more than 24 hours(see in Intervalle, line 231)
//Changed tempdir procedure because length is not supported by delphi 2009 and newer


interface

uses
  Windows,
  SysUtils;

procedure WriteLog (s : string);
function GetTempDir: string;
function StringToGetal (St: string): double;
procedure TestComma;

var
  CPlex_ILM                                         : string;
  envsetting                                        : string;
  DateNow, Date2001                                 : TDateTime;
  ConvertComma                                      : boolean;
  ConvertDot:boolean  ;
  windows_datetime                                  : tSystemTime;
  VarFormatSettings                                 : TFormatSettings;
  //--------------------------------------------------------------------
  XE                                                : Boolean;
  //---------------------------------------------------------------
  intervalleLog                                     : text;
   //-------------------------------------------------------------------
  barray                                            : array[0..20] of boolean = (true, true, true, true, true, true, true,
                                        true, true, true, true, true, true, true,  true, true, true, true, true, true, true);
  //----------------------------------------------------------------------
implementation


procedure WriteLog (s : string);
begin
  append(intervalleLog);
  //writeln (intervalleLog, 'intervalleLog');
  writeln (intervalleLog, TimeToStr(Time)+' '+DateToStr(Date)+' '+ s);
  writeln (s);
  CloseFile(intervalleLog);
end;

function GetTempDir: string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  //---------------------------------------------------------------------------
  if XE=true then begin      //runs version that works ion Delphi 2009 and later
    SetLength(Result,GetTempPath(0, nil));
    GetTempPath(Length(Result),PChar(Result));
    SetLength(Result,StrLen(PChar(Result)));
  end
  //----------------------------------------------------------------------------
  else begin                //version for delphi 2007 and older
    GetTempPath(SizeOf(Buffer) - 1, Buffer);
    Result := StrPas(Buffer);
  end;
end;

function StringToGetal (St: string): double;
var
  p : longint; X: double;
begin
  if ConvertComma then begin
    p := pos('.', st);
    if p > 0 then st[p] := ',';
  end; {if}

  if ConvertDot then begin
    p := pos(',', st);
    if p > 0 then st[p] := '.';
  end; {if}
  X := StrToFloat(St);
  StringToGetal := X;
end;



procedure TestComma;
var
  x: double; St: String; p: LongInt;
begin
 x := 0.01;
 St := FloatToStr(x);
 p := pos(',',St);
 ConvertComma := (p>0);
 writeln ('der',convertcomma);
end;



end.

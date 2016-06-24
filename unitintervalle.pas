unit UnitIntervalle;

{ MOD 08.2012:
Two modifications were made to make the program run with GLPK
1.)replaced "stdcall" with "cdecl" in the declaration of the GLPK parameters
2.) Placed SysUtils on top of the uses-list}

interface
uses
  SysUtils,          // MOD 08.2012 : put SysUtils on the top
  ComServ,
  Windows,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  Math,
  ExtCtrls,
  Printers,
  Menus,
  ComCtrls,
  DateUtils,
  IntervalleData;


function Intervalle(orgliste:tstrings;
                    p0Wert,p1Wert,p2Wert,p3Wert:Integer;
                    var OK: Boolean;
                    SolverType: Integer; dateirechnen:string): Tstrings;
//-------------------------------------------------------------------------
//var  barray: array[0..15] of boolean = (true, true, true, true, true, true, true,
//                                        true, true, true, true, true, true, true, true, true);
//------------------------------------------------------------------------------

implementation
type

//for CPlex function calls
  TReadcopyprob=function(env:pointer;lp:pointer;filename:string;filetype:string):Integer;stdcall;
  TChgobjsen=procedure(env:Pointer;lp:Pointer;maxormin:Integer);stdcall;
  TGetobjval=function(env:Pointer;lp:Pointer;var objval:double):Integer;stdcall;
  TLpopt=function(env:Pointer;lp:Pointer):Integer;stdcall;
  TGetobjsen=function(env:Pointer;lp:Pointer):Integer;stdcall;
  TCreateprob=function(env:Pointer;status:Pointer;s:string): Pointer; stdcall;
  TFreeprob=function(env:Pointer;lp:Pointer): Integer; stdcall;
  TOpenCPLEX=function(status:Pointer): Pointer; stdcall;
  TCloseCPLEX=function(env:Pointer): Integer; stdcall;
  TChgcoef=function(env:Pointer;lp:Pointer;row:integer;col:integer;newvalue:double):Integer;stdcall;
  Twritesol=function(env:pointer;lp:pointer;filename:string;filetype:string):Integer; stdcall;
  TPutEnv=function(envset:string):Integer; stdcall;
  TXEReadcopyprob=function(env:pointer;lp:pointer;filename:Ansistring;filetype:Ansistring):Integer;stdcall;
  TXECreateprob=function(env:Pointer;status:Pointer;s:Ansistring): Pointer; stdcall;
  TXEPutEnv=function(envset:ansistring):Integer; stdcall;

//begin------------------------------------------------------------------------
//for GLPK function calls
// MOD 08.2012 replaced "stdcall" with "cdecl"

Precord =^Trecord;
  TRecord =record   //controlparameters of the GLPK optimazation
     msg_lev :word ;
     meth : word;
     pricing : word;
     r_test : word;
     tol_bnf : double;
     tol_dj : double;
     tol_piv : double;
     obj_ll : double;
     obj_ul : double;
     it_lim : word;
     tm_lim :word;
     out_frq : word;
     out_dly :word;
     presolve : word;
     foo_bar : double; end;
  TGLPKCreateprob=function(sim:Pointer):Pointer; cdecl;
  TGLPKReadLP=function(sim:Pointer;parm:Pointer;filename:string):Integer;cdecl;
  TGLPKsetobjdir=function(sim:Pointer;dir:Integer):Pointer; cdecl;
  TGLPKDelProb=function(sim:Pointer):Pointer; cdecl;
  TGLPKsimplex=function(sim:Pointer;parm:Pointer):Integer;cdecl;
  TGLPKGetobjval=function(sim:Pointer):double;cdecl;
  TGLPKchgobjco=function(sim:Pointer;i:Integer;coef:Double):Pointer;cdecl;
  TGLPKPara=function(parm:Precord): Integer;cdecl;
  TXEGLPKReadLP=function(sim:Pointer;parm:Pointer;filename:Ansistring):Integer;cdecl;

//end-----------------------------------------------------------------------

//for XPress function calls
  EMyError=class(Exception);
  TCCString =Array[1..512] of char;
  TCCStringXE=Array[1..512] of Ansichar;
  TInt2 = array [0..1] of longint;
  TDouble2 = array[0..1] of double;
  TXPRSlicense=function(var nValue:longint; sLicMsg:TCCstring):longint; stdcall; //cdecl;
  TXPRSgetlicerrmsg=procedure(var sErrMsg:Tccstring; len:Longint); stdcall; //cdecl;
  TXPRSinit=function(msg:String):integer; stdcall; //cdecl;
  TXPRSCreateProb=function(var prob:pointer):longint; stdcall; //cdecl;
  TXPRSReadProb=function(prob:pointer;FileName:TCCString;Flags:TCCString):longint; stdcall; //cdecl;
  TXPRSMinim=function(prob:pointer;Flags:TCCString):longint; stdcall; //cdecl;
  TXPRSMaxim=function(prob:pointer;Flags:TCCString):longint; stdcall; //cdecl;
  TXPRSGetdblAttrib=function(prob:pointer; ind:longint;var result:double):longint; stdcall; //cdecl;
  TXPRSGetintAttrib=function(prob:pointer; ind:longint;var result:longint):longint; stdcall; //cdecl;
  TXPRSchgobj=function(prob:pointer;Nels:longint; mindex:TInt2; dobj:Tdouble2):longint; stdcall; //cdecl;
  TXPRSWriteProb=function(prob:pointer;FileName:TCCString;Flags:TCCString):longint; stdcall; //cdecl;
  TXPRSdestroyprob=function(prob:pointer):longint; stdcall;
  TXEXPRSlicense=function(var nValue:longint; sLicMsg:TCCstringXE):longint; stdcall; //cdecl;
  TXEXPRSgetlicerrmsg=procedure(var sErrMsg:TccstringXe; len:Longint); stdcall; //cdecl;
  TXeXPRSReadProb=function(prob:pointer;FileName:TCCStringxe;Flags:TCCStringxe):longint; stdcall; //cdecl;
  TXeXPRSMinim=function(prob:pointer;Flags:TCCStringxe):longint; stdcall; //cdecl;
  TXeXPRSMaxim=function(prob:pointer;Flags:TCCStringxe):longint; stdcall; //cdecl//;
  TXeXPRSWriteProb=function(prob:pointer;FileName:TCCStringXe;Flags:TCCStringXe):longint; stdcall; //cdecl;

  const cplex=1; xpress=2; GLPK=3; XPRS_LPOBJVAL=2001;XPRS_LPSTATUS=1010;


var
//for CPlex functions
  Readcopyprob:TReadcopyprob=nil;
  Chgobjsen:TChgobjsen=nil;
  Getobjval:TGetobjval=nil;
  Lpopt:TLpopt=nil;
  Getobjsen:TGetobjsen=nil;
  Createprob:TCreateprob=nil;
  Freeprob:TFreeprob=nil;
  OpenCPLEX:TOpenCPLEX=nil;
  CloseCPLEX:TCloseCPLEX=nil;
  Chgcoef:TChgcoef=nil;
  Writesol:TWritesol=nil;
  PutEnv:TPutEnv=nil;
  XEPutEnv:TXEPutEnv=nil;
  XECreateprob:TXECreateprob=nil;
  XEReadcopyprob:TXEReadcopyprob=nil;

//begin----------------------------------------------------------------
//GLPK
  GLPKCreateprob: TGLPKCreateprob=nil;
  GLPKReadLP:   TGLPKReadLP=nil;
  GLPKsetobjdir: TGLPKsetobjdir=nil;
  GLPKdelProb:TGLPKdelProb=nil;
  GLPKsimplex: TGLPKsimplex=nil;
  GLPKGetobjval: TGLPKGetobjval=nil;
  GLPKchgobjco:TGLPKchgobjco=nil;
  GLPKpara: TGLPKPara=nil;
  XEGLPKReadLp: TXEGLPKReadLp=nil;
//end------------------------------------------------------------------------

//Xpress
  XPRSlicense:TXPRSlicense=nil;
  XPRSgetlicerrmsg:TXPRSgetlicerrmsg=nil;
  XPRSinit:TXPRSinit=nil;
  XPRSCreateProb:TXPRSCreateProb=nil;
  XPRSReadProb:TXPRSReadProb=nil;
  XPRSMinim:TXPRSMinim=nil;
  XPRSMaxim:TXPRSMaxim=nil;
  XPRSGetdblAttrib:TXPRSGetdblAttrib=nil;
  XPRSGetintAttrib:TXPRSGetintAttrib=nil;
  XPRSchgobj:TXPRSchgobj=nil;
  XPRSWriteProb:TXPRSWriteProb=nil;
  XPRSdestroyprob:TXPRSdestroyprob=nil;
  XEXPRSlicense:TXEXPRSlicense=nil;
  XEXPRSgetlicerrmsg:TXEXPRSgetlicerrmsg=nil;
  XEXPRSReadProb:TXEXPRSReadProb=nil;
  XEXPRSMinim:TXEXPRSMinim=nil;
  XeXPRSMaxim:TXeXPRSMaxim=nil;
  XEXPRsWriteProb:TXEXPRSWriteProb=nil;
  DTS : boolean;
  // X: double; // MOD 08.2012: X is not used



//{$R *.RES}
////////////////////////////////////////////////////////////////////////////////
// function needs    * original table (without space characters)-> orgliste   //
//                   * user input for the p0,p1,p2,p3 values                  //
// output: list with the suppressed cells and the bounds of    //
//                    cells with ''u'' and ''m''                              //
////////////////////////////////////////////////////////////////////////////////

//Conversion strings can be more efficient, but used sparsely only
//Converts strings to CCStrings for the XPress solver

Function ConvertString (CC :Tccstring):String;
 var HS: string; l: longint;
begin
 l := 1; hs := '';
 while (CC[l] <> chr(0)) and (l < 255) do
  begin l:= l + 1; hs := hs + cc[l]; end;
 ConvertString := hs;
end;

Function ConvertToCCString (S:String):TCCString;
 Var HCC:TCCString; i:LongInt;
begin
// i := length(S);
  For i := 1 to length(s) do HCC[i]:= s[i];
    HCC[Length(s)+1]:= Chr(0);
    ConvertToCCString:= HCC;

end;

//----------------------------------------------------------------------
Function ConvertToCCStringXE (S:String): TCCStringXE;
 Var HCC:TCCStringXE; i:LongInt;
begin
// i := length(S);
  For i := 1 to length(s) do HCC[i]:= ansichar(s[i]);
    HCC[Length(s)+1]:= Chr(0);
    ConvertToCCStringXE:= HCC;
end;
 //--------------------------------------------------------------------------

function Intervalle(orgliste:tstrings;
                    p0Wert,p1Wert,p2Wert,p3Wert:Integer;
                    var OK: Boolean;
                    SolverType: Integer; dateirechnen:string): Tstrings;
type versionT =(PrimOnly, PrimSec, FromFile);


var
  zaehlerrow,zaehlercol,zaehlercol1,zaehlercol2,prim,
  sek,unsicher,orglaenge,zellanzahl,glganzahl         : longint;
  glgliste                                            : array of double;
  MinEckfeld,MaxEckfeld, OptimiserVersion,dateiname,typ   : string;
  merkliste, stringarray, basistab, rhs, minmax       : array of array of string;


  //auxiliary variables//
  merk,count,col,row,faktor,i,j,k,l,p,q,stat        : longint;
  orglisteNEU,neuliste,bounds              : tstrings;
  s,variable,merkstring,hilfsstring,upper,lower,m, HS : string;
  wert,wert1,wert2,wert3                            : extended;
  test                                              : boolean;
  env,lp,sim, flag                                  : Pointer;
  objval                                            : double;
  lib                                               : THandle;
  version                                           : versionT;
  nValue, ierr, dir                                 : integer;
  CCString, CCFlag                                  : TCCString;
  CCSTringXE, CCFlagXE                              : TCCStringXE;
  Mobj                                              : Tint2;
  Xobj                                              : TDouble2;

  //chgobj                                            : boolean;        // MOD 08.2012: no use!
  //con                                               : Textfile;       // MOD 08.2012: no use!
  //-----------------------------------------------------------------
  x,y                                               :real;
  parm                                              :Precord;
  para                                              : TRecord;
  hilfansi                                          : Ansistring;
  //----------------------------------------------------------------

begin

  /////////////////////////////////////////////////////////////////////////////
  // preprocessing:                                                          //
  //                                                                         //
  // initialisation of Stringarray, merkliste, Basistab, Glgliste, rhs...    //
  /////////////////////////////////////////////////////////////////////////////

try
  //  GetLocaleFormatSettings(LCID: Integer; VarFormatSettings);
  zellanzahl:=StrToInt(orgliste[1]);
  glganzahl:=StrToint(orgliste[zellanzahl+2]);
  orglaenge:=orgliste.Count;
  writeln ('start preprocessing');

  //begin----------------------------------------------------------------
  DTS := false;
  XE:=false;       //set to true if your using delphi 2009 or later
  //end----------------------------------------------------------------


  if dateirechnen = 'prim' then version := PrimOnly
  else
    if dateirechnen = 'primsec' then version := PrimSec
    else begin
      //Error[3]
      writeln ('illegal value for dateirechnen');
      ok := false;
      barray[3]:=false;
      exit;
  end;

  //merk+1: numbers for columns of Stringarray
  merk:=0;
  for i:=0 to  orglaenge-1 do begin
    hilfsstring:=orgliste[i];
    count:=0;
    for j:=1 to Length(orgliste[i]) do begin
      if hilfsstring[j]=' ' then inc(count);
    end;
    if count>merk then merk:=count;
  end;

//defining dimension of Stringarray
  SetLength(stringarray,merk+1,orglaenge);

//saving of the strings of orgliste in stringmatrix
  for i:=0 to orglaenge-1 do begin
    hilfsstring:=orgliste[i]+' ';
    k:=0;count:=0;
    merkstring:=' ';
    for j:=1 to Length(hilfsstring) do begin
      if hilfsstring[j]=' ' then begin
        merkstring:=copy(hilfsstring,count+1,j-count-1);
        //---------------------------------------------------------------------
        stringarray[k,i]:=merkstring;
        count:=j;
        inc(k);
      end;//if
    end; //for j...
    if merkstring= ' ' then stringarray[k,i]:= copy(hilfsstring,1,Length(hilfsstring));
  end; //for i...

  try  //creating mekliste with information about suppressed cells
    MinEckfeld:=Stringarray[1,1];
    MaxEckfeld:=stringarray[1,2];


//creating of the base table

//counting of the suppressed cells
    write ('counting suppressed cells');
    prim:=0;sek:=0;
    for row:=2 to zellanzahl+1 do begin
      if stringarray[3,row]='u' then inc(prim);
      if stringarray[3,row]='m' then inc(sek);
    end;
    writeln (' ( prim:', prim, ' and sec:', sek, ')');

// --------------------  MOD 02.2012  --------------------
    // for PrimOnly let zaehlercol1 the number of prim and zaehlercol2 the number of sek
    if version = PrimOnly then begin
	zaehlercol1:=prim;//number of columns for basistab
	zaehlercol2:=sek; // MOD 02.2012
    end
    else if version = PrimSec then begin
	zaehlercol1:=prim+sek;//number of columns for basistab
	zaehlercol2:=0;
    end;
    zaehlercol:=zaehlercol1+zaehlercol2;
// ------------------  END MOD 02.2012  ------------------

//suppressed cells notice

    SetLength(merkliste,4,zaehlercol);
    i:=0;
    for row:=2 to zellanzahl+1 do begin
      if ((version = PrimSec) and ((stringarray[3,row]='u') or (stringarray[3,row]='m'))) or
       ((version = PrimOnly) and (stringarray[3,row]='u')) then begin
        merkliste[0,i]:=IntToStr(row-2);//number of the suppressed field
        merkliste[1,i]:=stringarray[3,row];//suppression
        merkliste[2,i]:=stringarray[4,row];//lower Attacker
        merkliste[3,i]:=stringarray[5,row];//upper Attacker
        inc(i);
      end;
    end;

// --------------------  MOD 02.2012  --------------------
    // for PrimOnly save the sek cells at columns (i= zaehlercol1 to zaehlercol-1)
    for row:=2 to zellanzahl+1 do begin
      if ((version = PrimOnly) and (stringarray[3,row]='m')) then begin
        merkliste[0,i]:=IntToStr(row-2);//number of the suppressed field
        merkliste[1,i]:=stringarray[3,row];//suppression
        merkliste[2,i]:=stringarray[4,row];//lower Attacker
        merkliste[3,i]:=stringarray[5,row];//upper Attacker
        inc(i);
      end;
    end;
// ------------------  END MOD 02.2012  ------------------

  except showmessage('Error');
  end;

//numbers of equations for suppressed cells
  write('number of active equations: ');
  SetLength(glgliste,glganzahl);
  for i:=0 to glganzahl-1 do begin
    glgliste[i]:=0;
  end;

//--------------------------------------------------------------------

 {new version Anco}
 for j:=zellanzahl+3 to orglaenge-1 do begin
  val(stringarray[1,j],k,i);
  for col:=1 to k do begin
   val(stringarray[2*col+1,j],row,i); row := row + 2;
   if (stringarray[3,row]='u') or (stringarray[3,row]='m') then
     glgliste[j-zellanzahl-3]:=1;//=1, if suppressed cell in equations; else=0
  end;
 end;

//number of rows for base table
  zaehlerrow:=0;
  for i:=0 to glganzahl-1 do begin
   if glgliste[i]=1 then inc(zaehlerrow);
  end;

//rows for basistab
 SetLength(basistab,zaehlerrow);
 SetLength(rhs,3,zaehlerrow);
 writeln (zaehlerrow);

//rows for basistab
  l:=-1;
  for i:=0 to glganzahl-1 do begin
    if glgliste[i]=1 then begin
      inc(l);
      count:=strtoint(stringarray[1,zellanzahl+3+i])*2;
      wert:=StringToGetal(stringarray[0,zellanzahl+3+i]);
      merk:=0;
       for col :=3 to count+2 do
        if (col mod 2)>0 then begin
//----------------------------------------------------------------
         val(stringarray[col,zellanzahl+3+i], row, p); row := row + 2;
         if (stringarray[3,row]='u') or (stringarray[3,row]='m') then inc(merk);
        end; {if/for}


      SetLength(basistab[l],merk);//row l with merk columns
      rhs[2,l]:=inttostr(merk);
//suppressed cells in basistab
      merk:=0;
      for col := 3  to count+2 do
        if (col mod 2)>0 then begin
         val(stringarray[col,zellanzahl+3+i], row, p); row := row + 2;
         if (stringarray[3,row]='u') or (stringarray[3,row]='m') then begin
           variable:='x'+ stringarray[col,zellanzahl+3+i];
//hier voor xpress een volgnummer genereren
           if copy(stringarray[col+1,zellanzahl+3+i],2,1)='1' then variable:='+'+variable
           else variable:='-'+variable;
           basistab[l,merk]:=variable;
           inc(merk);
         end
         else begin
          if copy(stringarray[col+1,zellanzahl+3+i],2,1)='1' then faktor:=-1
          else faktor:=1;
          wert:=wert+StringToGetal(stringarray[1,2+StrToInt(stringarray[col,zellanzahl+3+i])])*faktor;
         end; {if}
      end; {if/for}
      rhs[0,l]:=floattostr(wert);
    end;
  end;

  glgliste:=nil;


//creating Min-Max-Array
  SetLength(minmax,6,zaehlercol1+1);  //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
  minmax[0,0]:='cell';
  minmax[1,0]:='min';
  minmax[2,0]:='max';
  minmax[3,0]:='value';
  minmax[4,0]:='suppression';
  minmax[5,0]:='unsafe=1';
  for row:=1 to zaehlercol1 do begin  //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    minmax[0,row]:='x'+ merkliste[0,row-1];
    minmax[3,row]:=stringarray[1,strtoint(merkliste[0,row-1])+2];
    minmax[4,row]:=stringarray[3,strtoint(merkliste[0,row-1])+2];
    minmax[5,row]:='0';
  end;
  writeln('preparation finished');

except
  //Error[4]
  Writeln('error in the preparation procedure');
  OK := False;
  barray[4]:=false;
  exit;
end;

/////////////////////////////////////////////////////////////////////////////
// Creating of the CPlex file                                              //
//                                                                         //
// end function: cells of Merkliste                                        //
// additional condition from base table                                    //
// Bounds calculated with p0-...-p3                                        //
// Solvertype = 1: Cplex, 2: XPress                                        //
/////////////////////////////////////////////////////////////////////////////

try
//changing in LP format
  neuliste:=TStringList.Create;

//end function
  writeln ('prepare obj-function');

// same for Cplex and xpress
  begin
   neuliste.add('Maximize');
    // neuliste.add('obj:');
    hs := 'obj: ';
  end; {if}

  i:=0;
  if (solvertype = cplex) or (solvertype = GLPK) then begin         //for CPLREX
   for row:=0 to zaehlercol1-1 do begin    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    //this if is superfluous Anco
    // if (merkliste[1,row]<>'s')then begin
    inc (i);
    if i = 1 then hs := hs + '+1x'+merkliste[0,row]
    else hs := hs+ '+0x'+merkliste[0,row];
    if length(hs)> 500 then begin
      neuliste.Add(hs);
      hs := '';
    end; {if}
   // end; {if}
   end; {do}
  if hs <> '' then neuliste.Add(hs);
  neuliste.add('Subject To');
  end //if solvertyp Cplex or GLPK

  else begin //XPRESS
    for row:=0 to zaehlercol1-1 do begin   //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
      //this if is superfluous Anco
      if (merkliste[1,row]<>'s')then begin
       inc (i);
        //if i=1 then neuliste[1]:=neuliste[1]+' + 1 x'+merkliste[0,row]
        //else neuliste[1]:=neuliste[1]+' + 1 x'+merkliste[0,row];
       if i=1 then hs:= hs + '+ 1 x'+ merkliste[0,row]
       else hs:= hs + ' + 0 x'+merkliste[0,row];
       if length(hs)> 500 then begin
         neuliste.Add(hs);
         hs := '';
       end; {if}
      end; {if}
    end; {do}
    if hs <>'' then neuliste.Add(hs);
    neuliste.add('Subject To');
  end;{if}

//-------------------------------------------------------------------

  writeln ('prepare relations');

  i := neuliste.count-1;
  for row:= Low(basistab) to High(basistab) do begin
  //if rhs[2,row]<> '0' then begin
     inc(i);
     neuliste.add('');
     val(rhs[2,row],j,p);
     if (solvertype = cplex) or (solvertype = GLPK) then begin            //CPLEX
      for col := 0 to j-1 do neuliste[i]:=neuliste[i]+basistab[row,col];
      neuliste[i]:=neuliste[i]+'='+rhs[0,row];
     end
     else begin                               //XPRESS
      for col := 0 to j-1 do neuliste[i]:=neuliste[i]+' '+basistab[row,col];
      neuliste[i]:=neuliste[i]+' = '+rhs[0,row];
     end; {if}
  //  end; {if rhs[2,row] <> '0'}
  end;{do}

  //--------------------------------------------------------
   basistab:=nil;
   rhs:=nil;
  //--------------------------------------------------------

//Bounds
  bounds:=TStringList.Create;
  bounds.add('Bounds');

  writeln ('prepare bounds');
  x := 0.78;
  if DTS then writeln (x:4:2);

  if p0Wert=0 then begin //per cents for bounds
    if p3Wert>=Min(p1Wert,p2Wert)then writeln('p3-Wert >= Min(p1;p2)')
    else begin
      if DTS then writeln ('p0wert = 0 AND Randomise');
      Randomize;
      {hier krijg ik een integer overflow,Anco}
      for row:=0 to zaehlercol-1 do begin
       if DTS then writeln ( 'Hello Luigi!. Row',row:3, ' merkliste[1]: ', merkliste[1,row]);
       if merkliste[1,row]<>'s' then begin
          if DTS then writeln('Hello: merkliste 0:', merkliste[0,row],', 1:', merkliste[1,row],', 2:', merkliste[2,row],', 3:', merkliste[3,row]);
          if DTS then write ('p3wert and wert3: ', p3wert);
          wert3:=p3Wert*random;
          if DTS then writeln (', ',wert3);
          if DTS then write ('wert1: ');
          wert1:=Int((StringToGetal(merkliste[2,row])/0.5*(100-p1Wert-wert3)/100));
          if DTS then writeln (wert1);
          if DTS then write ('wert3: ');
          wert3:=p3Wert*random;
          if DTS then   writeln (wert3);
          if DTS then write ('wert2: ');
          wert2:=Int((StringToGetal(merkliste[3,row])/1.5*(100+p2Wert+wert3)/100));
          if DTS then writeln (wert2);
          if DTS then writeln('Cplex or Xpress; wert1, wert2 and wert3',wert1, wert2, wert3);
          if (solvertype = cplex) or (solvertype = GLPK) then
            bounds.add(FloatToStr(wert1)+'<='+'x'+merkliste[0,row]+'<='+FloatToStr(wert2))
          else begin
            bounds.add ('x'+merkliste[0,row]+' <= '+FloatToStr(wert2));
            bounds.add ('x'+merkliste[0,row]+' >= '+FloatToStr(wert1));
          end;
       end; //3.if
      end;   //for row
    end;     //else zum 2.if
  end        //1.if

  else begin //table element for bounds
    if DTS then writeln ('P0Wert', P0Wert);
    for row:=0 to zaehlercol-1 do begin
      if DTS then writeln ( 'Hello Luigi!. Row',row:3, ' merkliste 1', merkliste[1,row]);
      if merkliste[1,row]<>'s' then begin
        wert1:=0;
        wert2:=Int(p0wert/100*StringToGetal(MaxEckfeld));
        if solvertype = cplex then
         bounds.add(FloatToStr(wert1)+'<='+'x'+merkliste[0,row]+'<='+FloatToStr(wert2))
        else
        begin
         bounds.add ('x'+merkliste[0,row]+' <= '+FloatToStr(wert2));
         bounds.add ('x'+merkliste[0,row]+' >= '+FloatToStr(wert1));
        end; {if}
      end;
    end;{do}
  end;

//End
  bounds.add('End');
  neuliste.AddStrings(bounds);

//LP-Datei is saved in current directory

  {dateiname:=GetCurrentDir+'\test';}
  if solvertype = cplex then dateiname:=GetTempDir+'testCP'
                        else  dateiname:=GetTempDir+'testXP';
  typ:='lp';
  // writeln ('Writing LP-file to', dateiname+'.lp');
  neuliste.SaveToFile(dateiname+'.lp');
  //neuliste.SaveToFile('problem.lp');

  writeln('LP-file constructed; see file: ', dateiname+'.lp');


  /////////////////////////////////////////////////////////////////////////////
  // optimization:                                                           //
  /////////////////////////////////////////////////////////////////////////////

  IF solvertype = cplex then BEGIN
//loading DLL functions
//check the path of the cplex.dll! (e.g. with extractfilepath)
    OptimiserVersion:='cplex75.dll';
    lib:=LoadLibrary(PCHAR(OptimiserVersion));
    if lib<>0 then begin
     @Readcopyprob:=GetProcAddress(lib,'CPXreadcopyprob');
     @Chgobjsen:=GetProcAddress(lib,'CPXchgobjsen');
     @Getobjval:=GetProcAddress(lib,'CPXgetobjval');
     @Lpopt:=GetProcAddress(lib,'CPXlpopt');
     @Createprob:=GetProcAddress(lib,'CPXcreateprob');
     @Freeprob:=GetProcAddress(lib,'CPXfreeprob');
     @OpenCPLEX:=GetProcAddress(lib,'CPXopenCPLEX');
     @CloseCPLEX:=GetProcAddress(lib,'CPXcloseCPLEX');
     @Chgcoef:=GetProcAddress(lib,'CPXchgcoef');
     @Writesol:=GetProcAddress(lib,'CPXwritesol');
     @PutEnv:=GetProcAddress(lib,'CPXputenv');
     @XEPutEnv:=GetProcAddress(lib,'CPXputenv');
     @XEReadcopyprob:=GetProcAddress(lib,'CPXreadcopyprob');
     @XECreateprob:=GetProcAddress(lib,'CPXcreateprob');
    end
    else begin
      //Error[5]
      barray[5]:=false;
      writeln(OptimiserVersion+'  library not found!');
      exit;          //was halt;
    end;

    stat:=1;
//Cplex starting
    //-----------------------------------------------------------------------
    envsetting := 'ILOG_LICENCE_FILE='+ IntervalleData.Cplex_ILM;
    if XE=true then begin
      hilfansi:=envsetting ;
      i:=XEputenv(hilfansi);
    end
    else i := putenv(envsetting);
    //---------------------------------------------------------------------

    if i <> 0 then begin
      //Error[6]
      writeln('environment setting failed');
      OK := false;
      barray[6]:=false;
      exit;
    end; {if}

    env:=OpenCPLEX(@stat);

    if  env=nil then begin
      //Error[7]
      Writeln('CPLEX could not be opened! error: '+IntToStr(stat));
      Ok := false;
      barray[7]:=false;
      exit;
    end
    else begin
      //-------------------------------------------------------------------
      if XE=true then lp:=XECreateprob(env,@stat,Ansistring('myprob'))
      else lp:=Createprob(env,@stat,'myprob');
      //-----------------------------------------------------------------
//optimization
      i:=-1;
      for row:=0 to zaehlercol1-1 do begin    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
       if merkliste[1,row]<>'s' then begin
        inc(i);
//begin-----------------------------------------------------
        x:=row;
        y:=zaehlercol1;			      //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
        q:=round((x/y)*100);
        Write(Format(#13+'%u percent complete.', [q]));
//end----------------------------------------------------------
        //write ('row:'+IntToStr(row) + ' problem nr: ' +IntTostr(i) + ' of ' + inttostr(zaehlercol1));    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
        if i=0 then begin
           if XE=true then stat:=XEReadcopyprob(env,lp,Ansistring(dateiname),Ansistring(typ))
           else stat:=Readcopyprob(env,lp,dateiname,typ)
//----------------------------------------------------------------------
        end
        else  begin
          stat:=Chgcoef(env,lp,-1,i-1,0);
          stat:=Chgcoef(env,lp,-1,i,1);
        end;
        Chgobjsen (env,lp,-1);
        stat:=Lpopt(env,lp);//maximize
        stat:=Getobjval(env,lp,objval);
        minmax[2,row+1]:=Floattostr(objval);
        // write ('; Max:', minmax[2,row+1]);
        Chgobjsen (env,lp,1);
        stat:=Lpopt(env,lp);//minimize
        stat:=Getobjval(env,lp,objval);
        minmax[1,row+1]:=FloatToStr(objval);
        // write ('; Min:', minmax[1,row+1]);
        // writeln;
       end;
     end;

//Cplex closing
      try
        stat:=Freeprob(env,lp);
        stat:=CloseCPLEX(env);
      except
        Writeln('CPLEX could not be closed');
      end;

      neuliste.Free;
      //DeleteFile(Dateiname+'.lp');//LP-Datei deleted in current directory
    end;//else CPLEX open

  END

//begin-------------------------------------------------------------------
ELSE
  IF solvertype = GLPK THEN BEGIN
    OptimiserVersion:='glpk_4_46.dll' ;
    lib:=LoadLibrary(PCHAR(OptimiserVersion));
    if lib<>0 then
    begin
      //flag:=nil;
      @GLPKCreateprob:=GetProcAddress(lib,'glp_create_prob');
      @GLPKReadLP :=GetProcAddress(lib,'glp_read_lp');
      @GLPKsetobjdir:=GetProcAddress(lib, 'glp_set_obj_dir');
      @GLPKDelProb:=GetProcAddress(lib,'glp_delete_prob');
      @GLPKsimplex:=GetProcAddress(lib,'glp_simplex') ;
      @GLPKgetobjval:=GetProcAddress(lib,'glp_get_obj_val');
      @GLPKchgobjco:=GetProcAddress(lib,'glp_set_obj_coef');
      @GLPKPara:=GetProcAddress(lib,'glp_init_smcp');
      @XEGLPKReadLP:=GetProcAddress(lib, 'glp_read_lp');
    end

   else begin
      //Error[8]
      Writeln('GLPK could not be found! error: '+IntToStr(stat));
      Ok := false;
      barray[8]:=false;
      exit;
   end;
   env:=nil; //MOD 08.2012
   sim:=GLPKCreateprob(env);
   i:=0;
   for row:=0 to zaehlercol1-1 do begin    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    inc(i);

     // write ('row:'+IntToStr(row) + ' problem nr: ' +IntTostr(i) + ' of ' + inttostr(zaehlercol1));  //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    //-----------------------------------------------------------
    if i=1 then begin
      if XE=true then  begin
        stat:=XEGLPKReadLP(sim,env,ansistring(dateiname+'.lp'));
      end
      else stat:=GLPKReadLP(sim,env,dateiname+'.lp');
          // writeln(stat);
    end
        //---------------------------------------------------------------
    else  begin
      flag:=GLPKChgobjco(sim,i-1,0);
      flag:=GLPKChgobjco(sim,i,1);
    end;
      //-----------------------------------------------------
    x:=row;
    y:=zaehlercol1;     //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    q:=round((x/y)*100);
    Write(Format(#13+'%u percent complete.', [q]));
    //----------------------------------------------------------
         //write ('row:'+IntToStr(row) + ' problem nr: ' +IntTostr(i) + ' of ' + inttostr(zaehlercol1));   //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
        flag:=GLPKsetobjdir(sim,2);
        Parm:=@para;
        stat:=GLPKpara(parm);
        //write(stat);
         para.msg_lev:=0;      //sets output of GLPK solver to Errors only.

        stat:=GLPKsimplex(sim,Parm);   //maximize
        objval:=GLPKGetobjval(sim);
        minmax[2,row+1]:=Floattostr(objval);
        //write ('; Max:', minmax[2,row+1]);
        flag:=GLPKsetobjdir(sim,1);
        stat:=GLPKsimplex(sim,Parm);   //minimize
        objval:=GLPKGetobjval(sim);
        minmax[1,row+1]:=FloatToStr(objval);
        //write ('; Min:', minmax[1,row+1]);
        //writeln;
        if stat<>0 then begin
           //Error[9]
           Writeln('Error in GLPK computation! error: '+IntToStr(stat));
           Ok := false;
           barray[9]:=false;
           exit ;
        end;

   end;


 env:=GLPKdelProb(sim);


END
//end-----------------------------------------------------------------------


ELSE BEGIN //xpress
//Check the path of xprs.dll to avoid an error
  OptimiserVersion:='xprs.dll';
  lib:=LoadLibrary(PCHAR(OptimiserVersion));
  if lib<>0 then begin
   @XPRSlicense:=GetProcAddress (lib,'_XPRSlicense@8');
   @XPRSgetlicerrmsg:=GetProcAddress (lib,'_XPRSgetlicerrmsg@8');
   @XPRSinit:=GetProcAddress (lib,'XPRSinit'); //'_XPRSinit@4');
   @XPRSReadProb:=getProcAddress(lib, '_XPRSreadprob@12');
   @XPRSCreateProb:=GetProcAddress(lib, '_XPRScreateprob@4');
   @XPRSMinim:=GetProcAddress(lib, '_XPRSminim@8');
   @XPRSMaxim:=GetProcAddress(lib, '_XPRSmaxim@8');
   @XPRSGetdblAttrib:=GetProcAddress (lib, '_XPRSgetdblattrib@12');
   @XPRSGetintAttrib:=GetProcAddress (lib, '_XPRSgetintattrib@12');
   @XPRSchgobj:=GetProcAddress(lib, '_XPRSchgobj@16');
   @XPRSWriteProb:=GetProcAddress(lib,'_XPRSwriteprob@12');
   @XPRSdestroyprob:=GetProcAddress(lib,'_XPRSdestroyprob@4');
   @XEXPRSlicense:=GetProcAddress(lib,'_XEXPRSlicense@8');
   @XEXPRSGetLicerrmsg:=GetprocAddress(lib,'_XPRSgetlicerrmsg@8');
   @XEXPRSReadProb:=GetProcAddress(lib,'_XPRSreadprob@12');
   @XEXPRSWriteProb:=GetProcAddress(lib,'_XPRSwriteprob@12');
   @XEXPRSMinim:=Getprocaddress(lib,'_XPRSminim@8');
   @XEXPRSMaxim:=Getprocaddress(lib,'_XPRSmaxim@8');

   {orglisteNEU:=TStringList.Create;
   orglisteNEU.loadfromfile('H:\Eigene_Dateien\PraktikantBashiri\Intervalle-Programm\xpauth.xpr');
   orglisteNEU.savetofile('H:\Eigene_Dateien\PraktikantBashiri\Intervalle-Programm\test.txt');   }

   //writeln('test1');

   iErr := XPRSinit('');

   if ierr <> 0 then begin
     XPRSgetlicerrmsg(ccString,256);
     //Error[11]
     writeln ('Xpress init error:'+ ConvertString(CCString));
     barray[11]:=false ;
     exit;
   end {if}
   else writeln ('XPress successfully opened');
  end
   else begin //@lib=nil
    //Error[12]
    writeln (OptimiserVersion+'xpress/mosel library not found');
    OK := false;
    barray[12]:=false;
    exit;
   end; {if}
//Do the XPress optimization

   stat:=XPRSCreateProb(env);
   if XE=true then begin

      CCstringXe := ConvertToCCStringXe(dateiname+'.lp');
      CCFlagXE := ConvertToCCStringXe('l');
      stat:=XeXPRSReadProb(env,CCstringXE,CCFlagXe);
      CCStringXe:= ConvertToCCStringXe(GetTempDir+'\Controle');
      CCFlagXe := ConvertToCCStringXe('l');
      i:= XeXPRSWriteProb(env,CCStringXE,CCFlagXE);
      Xobj[0]:= 0; Xobj[1]:= 1;
      i:= -1;
   end
   else begin
     CCstring := ConvertToCCString(dateiname+'.lp');
     CCFlag := ConvertToCCString('l');
     stat:=XPRSReadProb(env,CCstring,CCFlag);
     CCString:= ConvertToCCString(GetTempDir+'\Controle');
     CCFlag := ConvertToCCString('l');
     i:= XPRSWriteProb(env,CCString,CCFlag);
     Xobj[0]:= 0; Xobj[1]:= 1;
     i:= -1;
   end;

   for row:=0 to zaehlercol1-1 do begin    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    if merkliste[1,row]<>'s' then begin
//begin-----------------------------------------------------
    x:=row;
    y:=zaehlercol1;    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
   q:=round((x/y)*100);
   Write(Format(#13+'%u percent complete.', [q]));
//end----------------------------------------------------------
     inc(i);
    // write ('row:'+IntToStr(row) + ' problem nr: ' +IntTostr(i) + ' of ' + inttostr(zaehlercol1));    //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
     if i > 0 then begin
      mobj[0]:= i-1;
      mobj[1]:= i;
      p:= 2;
      stat:=XPRSchgobj(env, p, mobj, xobj);
     end; {if}
 //    ccFlag:= ConvertToCCString('l');
//     stat:= XPRSWriteProb(env,CCString,CCFlag);
     if XE=true then begin
        CCFLagXE := ConvertToCCStringxe('');
        stat:=XeXPRSMinim(env, CCflagXE);
        j:=0;
        stat:=XPRSGetintAttrib(env, XPRS_LPSTATUS, j);
        If j<>1 then begin
          writeln( 'No optimal solution for the minimum for cell', i );
          raise EMyError.Create( 'No optimal solution for the minimum for cell');
        end;
        stat:=XPRSGetdblAttrib(env, XPRS_LPOBJVAL, objval);
        minmax[1,row+1]:= FloatToStr(objval);
        //   write ('; Min:', minmax[1,row+1]);

         stat:=XEXPRSMaxim(env, CCflagXE);
         j:=0;
        stat:=XPRSGetintAttrib(env, XPRS_LPSTATUS, j);
        If j<>1 then begin
          writeln( 'No optimal solution for the maximum for cell', i );
          raise EMyError.Create( 'No optimal solution for the minimum for cell');
        end;
        stat:=XPRSGetdblAttrib(env, XPRS_LPOBJVAL ,objval);
        minmax[2,row+1]:= FloatToStr(objval);
     end
     else begin
        CCFLag := ConvertToCCString('');
        stat:=XPRSMinim(env, CCflag);
        j:=0;
        stat:=XPRSGetintAttrib(env, XPRS_LPSTATUS, j);
        If j<>1 then begin
          writeln( 'No optimal solution for the minimum for cell', i);
          raise EMyError.Create( 'No optimal solution for the minimum for cell');
        end;
        stat:=XPRSGetdblAttrib(env, XPRS_LPOBJVAL, objval);
        minmax[1,row+1]:= FloatToStr(objval);
        //   write ('; Min:', minmax[1,row+1]);

        stat:=XPRSMaxim(env, CCflag);
        j:=0;
        stat:=XPRSGetintAttrib(env, XPRS_LPSTATUS, j);
        If j<>1 then begin
          writeln( 'No optimal solution for the maximum for cell', i );
          raise EMyError.Create( 'No optimal solution for the minimum for cell');
        end;
        stat:=XPRSGetdblAttrib(env, XPRS_LPOBJVAL ,objval);
        minmax[2,row+1]:= FloatToStr(objval);
     end;
   //  write (' Max:', minmax[2,row+1]);
     end; {if}
  //  writeln;
    end; {do}

    neuliste.Free;

END; {if cplex/xpress}
 writeln(' ');

except
  on EMyError do begin
  OK:=false;
  barray[19]:=false;
  exit;
  end;
  else
 //Error[13]
 Writeln('error in the optimization procedure');
 OK := false;
 barray[13]:=false;
 exit;
end;

  /////////////////////////////////////////////////////////////////////////////
  // output                                                                  //
  /////////////////////////////////////////////////////////////////////////////
try
  //checking lower and upper, if safe
  unsicher:=0;
  for row:=1 to zaehlercol1 do begin     //-- MOD 02.2012: use zaehlercol1 instead of zaehlercol, no change! --
    //writeln (row);
    upper:= stringarray[7,strtoint(merkliste[0,row-1])+2];
    lower:= stringarray[6,strtoint(merkliste[0,row-1])+2];
    if ((StringToGetal(minmax[2,row])-StringToGetal(minmax[3,row])) < StringToGetal(upper))
    or ((StringToGetal(minmax[2,row])-StringToGetal(minmax[1,row])) < StringToGetal(lower))
    then begin minmax[5,row]:='1'; inc(unsicher); end;
  end;
//-----------------------------------------------------------
stringarray:=nil;
//-----------------------------------------------------------

  //preparation for displaying of the intervals in outputintneu.txt
   orglisteNEU:=TStringList.Create;
   orglisteNeu.add('The table contains '+inttostr(prim)+' primary suppressed cells ');
   orglisteNeu.add('and '+inttostr(sek)+' secondary suppressed cells.');
   orglisteNeu.add('There are still '+inttostr(unsicher)+' elected cells unprotected.');
  for row:=0 to zaehlercol1 do begin   //---- MOD 02.2012 -------
    if row=0  then orglisteNEU.add(minmax[0,row]+';'+minmax[1,row]+';'+minmax[2,row]+';'+minmax[3,row]+';'+minmax[4,row]+';'+minmax[5,row])
    else begin
     orglisteNEU.add(copy(minmax[0,row],2,Length(minmax[0,row])-1)+';'+minmax[1,row]+';'+minmax[2,row]+';'+minmax[3,row]+';'+minmax[4,row]+';'+minmax[5,row]);
    end;
  end;
  Intervalle:=orglisteNEU;

except
 writeln('error in the output procedure');
 OK := false;
 exit;

end;
Ok := true;
//--------------------------------------------------------
merkliste:=nil;
minmax:=nil;
//--------------------------------------------------------
end;



end.


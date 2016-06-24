unit UnitErsatzwerte;

//Changed code: 1.decimalseparator was added and set to point or comma
// 2. almost all dynamic arrays were set to =nil after their use, to free the used memory space

interface

uses
  ComServ,
  Windows,
  Messages,
  SysUtils,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  Math,
  Buttons,
  StdCtrls,
  Grids,
  ExtCtrls,
  Printers,
  Menus,
  ComCtrls,
  DateUtils,
  IntervalleData;





function Ersatzwerte (orgliste:tstrings;zellz,dimension,p0Wert,p1Wert,p2Wert,p3Wert,Kostenfunktion:Integer):tstrings;

implementation
//calculation of the synthetic cell values

///////////////////////////////////////////////////////////////////////////////
// processing of the txt File ~ from row 125                                 //
// processing of the JJ-file ~ from row 185                                  //
// preparation optimization ~ from row 390                                   //
// preparation CPlex file ~ from row 705                                     //
// instructions of optimization ~ from row 855                               //
// output of the results ~ from row 975                                      //
///////////////////////////////////////////////////////////////////////////////

type
//for CPlex functions calls
  TReadcopyprob=function(env:pointer;lp:pointer;filename:string;filetype:string):Integer;stdcall;
  TChgobjsen=procedure(env:Pointer;lp:Pointer;maxormin:Integer);stdcall;
  TGetobjval=function(env:Pointer;lp:Pointer;objval:double):Integer;stdcall;
  TLpopt=function(env:Pointer;lp:Pointer):Integer;stdcall;
  TGetobjsen=function(env:Pointer;lp:Pointer):Integer;stdcall;
  TCreateprob=function(env:Pointer;status:Pointer;s:string): Pointer; stdcall;
  TFreeprob=function(env:Pointer;lp:Pointer): Integer; stdcall;
  TOpenCPLEX=function(status:Pointer): Pointer; stdcall;
  TCloseCPLEX=function(env:Pointer): Integer; stdcall;
  TChgcoef=function(env:Pointer;lp:Pointer;row:integer;col:integer;newvalue:double):Integer;stdcall;
  Twritesol=function(env:pointer;lp:pointer;filename:string;filetype:string):Integer; stdcall;
  TPutEnv=function(envset:string):Integer; stdcall;


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

  zaehlerrow,zaehlercol,prim,sek,unsicher,
  orglaenge,zellanzahl,glganzahl                           : longint;
  eckfeld,dateiname,datei,CPlexVersion,typ                 : string;
  //dateiname := input Cplex, datei:= output Cplex

  merkliste,stringarray,stringmatrix,basistab,rhs,minmax,ersloesung,
  ersatz,primzell,primplus,primmin,sekund        : array of array of string;
  glgliste,hierarchieliste,gamma                 : array of double;
  gleichung                                      : array of array of longint;

  //auxiliary variables//
  test                                                     : boolean;
  faktor,hierarch,bis,stat,merk,count                      : longint;
  doub,hmax                                                : double;
  h,hilf,wert,wert1,wert2,wert3                            : extended;
  a                                      : array of array of extended;
  w,s,variable,merkstring,hilfsstring,komma                : string;
  hilfe                                                    : string[7];
  neuliste,listeEW,txtliste                                : tstrings;

  //auxiliary variables for Cplex-Handling
  f              : TFileStream;
  lib            : THandle;
  env,lp         : Pointer;


//exports
//  DllGetClassObject,
//  DllCanUnloadNow,
//  DllRegisterServer,
//  DllUnregisterServer;
//{$R *.RES}


////////////////////////////////////////////////////////////////////////////////
// function needs    * original table (without space characters)-> orgliste   //
//                   * dimension of the table                                 //
//                   * user input for the p0,p1,p2,p3 values                  //
//                   * chosen cost function                                   //
// output: list with the suppressed cells and the synthetic cell values of    //
//                    cells with ''u'' and ''m''                              //
////////////////////////////////////////////////////////////////////////////////
function Ersatzwerte (orgliste:tstrings;zellz,dimension,p0Wert,p1Wert,p2Wert,p3Wert,Kostenfunktion:Integer):tstrings;
var
  i,j,row,col,k,l,m       :longint;

begin
//---------------------------------------
decimalseparator:=',';
//---------------------------------------

  /////////////////////////////////////////////////////////////////////////////
  // procession of the TXT file (only for adaptive gammas)                   //
  //                                                                         //
  // Stringmatrix, hierarchieliste, hmax, gamma ...   are created            //
  /////////////////////////////////////////////////////////////////////////////
//try


  if zellz<>0 then begin
    SetLength(stringmatrix,3,zellz);
    txtliste:=Tstringlist.Create;
    txtliste.LoadFromFile('gammas.txt');
    //strings from orgliste in stringmatrix
    for i:=0 to zellz-1 do begin
      hilfsstring:=txtliste[i]+' ';
      k:=0;count:=0;
      merkstring:=' ';
      for j:=1 to Length(hilfsstring) do begin
        if hilfsstring[j]=' ' then begin
          merkstring:=copy(hilfsstring,count+1,j-count-1);
//          s:=merkstring;
{Only needed for special configurations ANCO
          while Pos('.', s) > 0 do s[Pos('.', s)] := ','; //dot -> comma
}
//          merkstring:=s;
          stringmatrix[k,i]:=merkstring;
          count:=j;
          inc(k);
        end;
      end;
      if merkstring= ' ' then stringmatrix[k,i]:= copy(hilfsstring,1,Length(hilfsstring));
    end;
    txtliste.free;

    //writing hierarchy from txt file in hierarchieliste
    Setlength(hierarchieliste, zellz);
    for i:=0 to zellz-1 do begin
      if (stringmatrix[1,i]<>'') AND (stringmatrix [1,i] <> ' ')
        then hierarchieliste[i]:=strtofloat(stringmatrix[1,i])
      else hierarchieliste[i]:=0;
    end;

    //maximum hierarchy hmax
    hmax:=MaxValue(hierarchieliste);


    //calculation of the gammas for each cell
    Setlength(gamma, zellz);
    for i:=0 to zellz-1 do begin
      if (stringmatrix[1,i]<>'') AND (stringmatrix [1,i] <> ' ') then
      //confirmation dialogue (space characters in txt file,...)
        gamma[i]:=(hmax-hierarchieliste[i])/hmax;
    end;
  end; // zellz<>0

//-------------------------------------------------
hierarchieliste:=nil;
//-------------------------------------------------


  /////////////////////////////////////////////////////////////////////////////
  // processing of the JJ-file:                                              //
  //                                                                         //
  // Stringarray, merkliste, Basistab, Glgliste, rhs...    are created       //
  // initialisation of MINMAX-Array (saves results)                          //
  /////////////////////////////////////////////////////////////////////////////

  zellanzahl:=StrToInt(orgliste[1]);
  glganzahl:=StrToint(orgliste[zellanzahl+2]);
  orglaenge:=orgliste.Count;

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
//--------------------------------------------
stringmatrix:=nil;
//--------------------------------------------


  //strings of orgliste in stringmatrix
  for i:=0 to orglaenge-1 do begin
     hilfsstring:=orgliste[i]+' ';
     k:=0;count:=0;
     merkstring:=' ';
     for j:=1 to Length(hilfsstring) do begin
      if hilfsstring[j]=' ' then begin
        merkstring:=copy(hilfsstring,count+1,j-count-1);
        s:=merkstring;
        while Pos('.', s) > 0 do s[Pos('.', s)] := ','; //dot -> comma
        merkstring:=s;
        stringarray[k,i]:=merkstring;
        count:=j;
        inc(k);
      end;//if
    end; //for j...
    if merkstring= ' ' then stringarray[k,i]:= copy(hilfsstring,1,Length(hilfsstring));
  end; //for i...

  eckfeld:=stringarray[1,2];


//creating of the base table

  //counting of the suppressed cells
  prim:=0;sek:=0;
  for row:=2 to zellanzahl+1 do begin
    if stringarray[3,row]='u' then inc(prim);
    if stringarray[3,row]='m' then inc(sek);
  end;
  zaehlercol:=prim+sek;//number of columns for basistab
// try
  //suppressed cells notice
  //9. field for apative gammas
  SetLength(merkliste,9,zaehlercol);
  i:=0;
  for row:=2 to zellanzahl+1 do begin
    if (stringarray[3,row]='u') or (stringarray[3,row]='m')then begin
      merkliste[0,i]:=IntToStr(row-2);//number of the suppressed field
      merkliste[1,i]:=stringarray[3,row];//suppression
      //2:= +/- of Primzell
      merkliste[3,i]:=stringarray[1,row];//original value
      //4,5:= upper-ai and ai-lower (Bounds included)
      merkliste[6,i]:=stringarray[4,row];//lower Attacker
      merkliste[7,i]:=stringarray[5,row];//upper Attacker
      if zellz<>0 then merkliste[8,i]:=floattostr(1/power(strtofloat(merkliste[3,i]),gamma[row-2]));     //cost function wtih apative gammas
      inc(i);
    end;
  end;
//  except showmessage('Error in area: 246 - 260 in UnitErsatzwerte');
//  end;

//----------------------------------------------------------------
gamma:=nil;
//----------------------------------------------------------------

  //numbers of equations for suppressed cells
  SetLength(glgliste,glganzahl);
  for i:=0 to glganzahl-1 do begin
    glgliste[i]:=0;
  end;
  for row:=2 to zellanzahl+1 do begin
    if (stringarray[3,row]='u') or (stringarray[3,row]='m')  then  begin
      for j:=zellanzahl+3 to orglaenge-1 do begin
        for col:=3 to merk do begin
           if stringarray[col,j]=stringarray[0,row] then begin
              glgliste[j-zellanzahl-3]:=1;//=1, if suppressed cell in equations, else =0
           end;
        end;
     end;
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

//rows for basistab
  l:=-1;
  for i:=0 to glganzahl-1 do begin
    if glgliste[i]=1 then begin
      inc(l);
      count:=strtoint(stringarray[1,zellanzahl+3+i])*2;
      wert:=strtofloat(stringarray[0,zellanzahl+3+i]);
      merk:=0;
      //number of columns
      for col:=3 to count+2 do begin
        test:=false;
        if (col mod 2)>0 then begin
          for row:=0 to zaehlercol-1 do begin
            if strtoint(stringarray[col,zellanzahl+3+i])=strtoint(merkliste[0,row]) then begin
              test:=true;
              break;
            end;
          end;
          if test=true then inc(merk);
        end;
      end;
      SetLength(basistab[l],merk);//row l with merk columns
      rhs[2,l]:=inttostr(merk);
      //suppressed cells in basistab
      merk:=0;
      for col:=3 to count+2 do begin
        test:=false;
        if (col mod 2)>0 then begin
          for row:=0 to zaehlercol-1 do begin
            if strtoint(stringarray[col,zellanzahl+3+i])=strtoint(merkliste[0,row]) then begin
              test:=true;
              break;
            end;
          end;
          if test=true then begin
            variable:='x'+ stringarray[col,zellanzahl+3+i];
            if copy(stringarray[col+1,zellanzahl+3+i],2,1)='1' then
                 variable:='+'+variable
            else variable:='-'+variable;
            basistab[l,merk]:=variable;
            inc(merk);
          end
          else begin
            if copy(stringarray[col+1,zellanzahl+3+i],2,1)='1' then faktor:=-1
            else faktor:=1;
            wert:=wert+strtofloat(stringarray[1,2+StrToInt(stringarray[col,zellanzahl+3+i])])*faktor;
          end; //else
        end;   //if col
      end;     //for col
      rhs[0,l]:=floattostr(wert);
    end;       //if glgliste
  end;         //for
//-------------------------------------------
glgliste:=nil;
//-------------------------------------------

 // number of primary suppressions in rhs
  for row:=0 to zaehlerrow-1 do begin
    i:=0;
    for col:=Low(basistab[row]) to High(basistab[row]) do begin
    //High returns the maximum length of the short-string type, Low returns zero
      for j:=0 to zaehlercol-1 do begin
        if copy(basistab[row,col],3,Length(basistab[row,col])-2)=merkliste[0,j] then begin
          if merkliste[1,j]='u' then inc(i);
          break;
        end;
      end;
    end;
    rhs[1,row]:=inttostr(i);
  end;
  //base table filled


 //creating Min-Max-Array
  SetLength(minmax,6,zaehlercol+1);
  minmax[0,0]:='cell'; //e.g. x1
  minmax[1,0]:='value';  //original value ai
  minmax[2,0]:='suppresion';
  minmax[3,0]:='unsafe=1';
  minmax[4,0]:='synthetic value';
  minmax[5,0]:='difference';
  for row:=1 to zaehlercol do begin
    minmax[0,row]:='x'+ merkliste[0,row-1];
    minmax[1,row]:=stringarray[1,strtoint(merkliste[0,row-1])+2];
    minmax[2,row]:=stringarray[3,strtoint(merkliste[0,row-1])+2];
    minmax[3,row]:='0';
  end;



  /////////////////////////////////////////////////////////////////////////////
  // preparation optimization:                                               //
  //                                                                         //
  // * initialisation primzell                                               //
  // * defining of hierarchy plane, level of aggregation (primplus,primmin)  //
  /////////////////////////////////////////////////////////////////////////////

  //defining the directions
  SetLength(gleichung,dimension*2,prim);
  for row:=0 to prim-1 do begin
    for col:=0 to (dimension*2)-1 do begin
      gleichung[col,row]:=-1;
    end;
  end;

//saving of the primary cells in primzell-array
  SetLength(primzell,5,prim);
  i:=-1;
  for row:=0 to zaehlercol-1 do begin
    if merkliste[1,row]='u' then begin
      inc(i);
      primzell[0,i]:=merkliste[0,row];
      primzell[3,i]:='0';
      //initialisation important, else abend possible
    end;
  end;

//counting the algebraic signs
  for i:=0 to prim-1 do begin
    k:=0;l:=0;j:=-1;
    for row:=0 to zaehlerrow-1 do begin
      for col:=Low(basistab[row]) to High(basistab[row]) do begin
        if (copy(basistab[row,col],3,Length(basistab[row,col])-2)=primzell[0,i]) then begin
          inc(j);
          if copy(basistab[row,col],1,1)='+' then  inc(k)
          else inc(l);
          gleichung[j,i]:=row;
        end;      //1.if
      end;        //for col...
    end;          //for row...
    primzell[1,i]:=inttostr(k);
    primzell[2,i]:=inttostr(l);
  end;            //for i...


//first hierarchy not necessary, because initialisation of each cell with 0


  //scaning basistab, defining hierarchy
  hierarch:=0;
  repeat
    test:=false;
    inc(hierarch);
    for i:=0 to prim-1 do begin
      if primzell[3,i]=Inttostr(hierarch-1) then begin
        for row:=0 to zaehlerrow-1 do begin
          if rhs[1,row]>'0'then begin
            for col:=Low(basistab[row]) to High(basistab[row]) do begin
              if ((copy(basistab[row,col],3,Length(basistab[row,col])-2)=primzell[0,i])) and (copy(basistab[row,col],1,1)='+') then begin
                for j:=Low(basistab[row]) to High(basistab[row]) do begin
                  if copy(basistab[row,j],1,1)='-' then begin
                    for k:=0 to prim-1 do begin
                      if (copy(basistab[row,j],3,Length(basistab[row,j])-2)=primzell[0,k]) then begin
                        primzell[3,k]:=Inttostr(hierarch);
                        test:=true;
                      end;
                    end;  //for k...
                  end;
                end;      //for j...
              end;
            end;          //for col...
          end;
        end;              //for row...
      end;
    end;                  //for i...
  until test=false;

  l:=0;
  for row:=0 to prim-1 do begin
    if primzell[3,row]='0' then inc(l);
  end;


  //auxiliary array a
  SetLength(a,4,l);
  i:=-1;
  for row:=0 to prim-1 do begin
    if primzell[3,row]='0' then begin
       inc(i);
       a[0,i]:=StrToFloat(stringarray[0,strtoint(primzell[0,row])+2]);
       a[1,i]:=StrToFloat(stringarray[7,strtoint(primzell[0,row])+2]);
       a[2,i]:=StrToFloat(stringarray[1,strtoint(primzell[0,row])+2]);
       a[3,i]:=0;
    end;
  end;


  //Shell Sort
  bis:=High(a[0]);
  k:=bis shr 1;
  While k>0 do begin
    for i:=0 to bis-k do begin
      j:=i;
      while (j>=0) and (a[1,j]<a[1,j+k]) do begin
        h:=a[0,j]; a[0,j]:=a[0,j+k];a[0,j+k]:=h;
        h:=a[1,j]; a[1,j]:=a[1,j+k];a[1,j+k]:=h;
        h:=a[2,j]; a[2,j]:=a[2,j+k];a[2,j+k]:=h;
        if j>k then dec(j,k) else j:=0
      end
    end;  //while j>=0
    k:=k shr 1;
  end;    //while k>0

  bis:=High(a[0]);
  k:=bis shr 1;
  While k>0 do begin
    for i:=0 to bis-k do begin
      j:=i;
      while (j>=0) and (a[1,j]=a[1,j+k]) and (a[2,j]<a[2,j+k]) do begin
       h:=a[0,j]; a[0,j]:=a[0,j+k];a[0,j+k]:=h;
        h:=a[1,j]; a[1,j]:=a[1,j+k];a[1,j+k]:=h;
        h:=a[2,j]; a[2,j]:=a[2,j+k];a[2,j+k]:=h;
        if j>k then dec(j,k) else j:=0
      end   //while j
    end;    //for i
    k:=k shr 1;
  end;      //while k


//level of aggregation Null plus/minus
  for i:=0 to High(a[0]) do begin
    if a[3,i]=0 then begin
       a[3,i]:=1;
       for j:=0 to prim-1 do begin
         if floattostr(a[0,i])=primzell[0,j] then begin
            primzell[4,j]:='p';
            break;
         end;                //if a[]=prin
       end;                  //for j...

       for k:=0 to dimension*2-1 do begin
         if gleichung[k,j]>=0 then begin
            row:=gleichung[k,j];
            if rhs[1,row]>'1' then begin
               merk:=High(a[0])+1;
               for col:=Low(basistab[row])  to High(basistab[row]) do begin
                  if copy(basistab[row,col],3,Length(basistab[row,col])-2)<>primzell[0,j] then  begin
                     for l:=0 to High(a[0]) do begin
                       if (copy(basistab[row,col],3,Length(basistab[row,col])-2)=floattostr(a[0,l])) and (a[3,l]=0) then begin
                          if l<merk then merk:=l;
                       break;
                       end;  //if
                     end;    //for l...
                  end;       //if
               end;          //for col...

               if merk<>High(a[0])+1 then begin
                  a[3,merk]:=1;
                  for m:=0 to prim-1 do begin
                    if floattostr(a[0,merk])=primzell[0,m] then begin
                       primzell[4,m]:='m';
                       break;
                    end;   //if a[0,merk]...
                  end;     //for m...
               end;        //if merk...
            end;           //if rhs...
         end;              //if gleichung...
       end;                //for k...
    end;                   //if a[3,i]...
  end;                     //for i...

//---------------------------------------
rhs:=nil;
a:=nil;
//---------------------------------------

//level of aggregation 1..n plus/minus
  for l:=1 to hierarch do begin
    for j:=0 to prim-1 do begin
      if primzell[3,j]=inttostr(l) then begin
         hilf:=0;
         for k:=0 to dimension*2-1 do begin
           if gleichung[k,j]>=0 then begin
              row:=gleichung[k,j];
              if (copy(basistab[row,0],3,Length(basistab[row,0])-2)=primzell[0,j])
              and (copy(basistab[row,0],1,1)='-') then  begin
                 h:=0;
                 for col:=Low(basistab[row])+1  to High(basistab[row]) do begin
                   for i:=0 to prim-1 do begin
                     if (copy(basistab[row,col],3,Length(basistab[row,col])-2)=primzell[0,i])
                     and (primzell[3,i]=inttostr(l-1)) then  begin
                        if primzell[4,i]='p' then
                           h:=h+StrToFloat(stringarray[7,strtoint(primzell[0,i])+2])
                        else h:=h-StrToFloat(stringarray[6,strtoint(primzell[0,i])+2]);
                     end;  //if basistab...
                   end;    //for i...
                 end;      //for col...
              if abs(h)>abs(hilf) then hilf:=h;
              end;         //if basistab[row,0]...
           end;           //if gleichung
         end;             //for k...
         if hilf<0 then primzell[4,j]:='m'
         else primzell[4,j]:='p';
      end;               //if primzell...
    end;                //for j...
  end;                 //for l...

//---------------------------------------------------
gleichung:=nil;
//---------------------------------------------------

  j:=0;k:=0;
  for row:=0 to prim-1 do begin
    if primzell[4,row]='p' then inc(j)
    else inc(k);
  end;


  //creating arrays (U+, U- for primary, and secondary cells separately)
  SetLength(primplus,3,j);
  SetLength(primmin,3,k);
  SetLength(sekund,2,sek);
  j:=-1;k:=-1;l:=-1;

  //writing plus/minus in merkliste
  for row:=0 to zaehlercol-1 do begin
    for i:=0 to prim-1 do begin
       if merkliste[0,row]=primzell[0,i] then begin
         merkliste[2,row]:=primzell[4,i];
         break;
       end;
    end;
  end;
//------------------------------------------
primzell:=nil;
//------------------------------------------

  //per cents for bounds
  if p0Wert=0 then begin
     if p3Wert>=Min(p1Wert,p2Wert)then writeln('p3-Wert >= Min(p1;p2)')
     else begin
     try
        Randomize;
        for row:=0 to zaehlercol-1 do begin
            wert3:=p3Wert*random;
            //lowerAttacker
            wert1:=Int((StrToFloat(merkliste[6,row])/0.5*(100-p1Wert-wert3)/100));
            wert3:=p3Wert*random;
            //upperAttacker
            wert2:=Int((StrToFloat(merkliste[7,row])/1.5*(100+p2Wert+wert3)/100));
            //upperAttacker minus ai
            merkliste[4,row]:=FloattoStr(Round(wert2-StrToFloat(merkliste[3,row])));
            //ai minus lowerAttacker;
            merkliste[5,row]:=FloattoStr(Round(StrToFloat(merkliste[3,row])-wert1));
        end;  // for row...

     except showmessage('Error in area 626 to 639 in UnitErsatzwerte');
     end;

     end;    // else
  end       // if p0Wert...



  //table element for bounds
  else begin
    for row:=0 to zaehlercol-1 do begin
      wert1:=0;//lowerAttacker
      wert2:=p0wert/100*StrToFloat(eckfeld);//upperAttacker
      merkliste[4,row]:=FloattoStr(Round(wert2-StrToFloat(merkliste[3,row])));//upperAttacker minus ai
      merkliste[5,row]:=FloattoStr(Round(StrToFloat(merkliste[3,row])-wert1));//ai minus lowerAttacker;
    end;     //for row...
  end;       //else

// try
  //cost function,.. in primplus,primmin,sekund
  for row:=0 to zaehlercol-1 do begin
    if (merkliste[1,row]='u') and (merkliste[2,row]='p') then begin
      inc(k);
      primplus[0,k]:= merkliste[0,row];
      primplus[2,k]:= merkliste[4,row];
      case Kostenfunktion of
        0: primplus[1,k]:='1';
        1: primplus[1,k]:=merkliste[3,row];
        2: primplus[1,k]:=FloatToStr(Log10(1+StrToFloat(merkliste[3,row])));
        3: primplus[1,k]:=FloatToStr(1/(1+StrToFloat(merkliste[3,row])));
        4: primplus[1,k]:=FloatToStr((Log10(1+StrToFloat(merkliste[3,row])))/(1+StrToFloat(merkliste[3,row])));
        5: primplus[1,k]:=merkliste[8,row];
      end;                               
    end;
    if (merkliste[1,row]='u') and (merkliste[2,row]='m') then begin
      inc(j);
      primmin[0,j]:= merkliste[0,row];
      primmin[2,j]:= merkliste[5,row];
//in the case... of is an EZeroDivide Exception (FloatingPointDivision by zero) possible,
//if 2,3 or 4 is choosen as the cost-function


      case Kostenfunktion of
        0: primmin[1,j]:='1';
        1: primmin[1,j]:=merkliste[3,row];
        2: primmin[1,j]:=FloatToStr(Log10(1+StrToFloat(merkliste[3,row])));
        3: primmin[1,j]:=FloatToStr(1/(1+StrToFloat(merkliste[3,row])));
        4: primmin[1,j]:=FloatToStr((Log10(1+StrToFloat(merkliste[3,row])))/(1+StrToFloat(merkliste[3,row])));
        5: primmin[1,j]:=merkliste[8,row];
      end;

    end;
    if merkliste[1,row]='m' then begin
      inc(l);
      sekund[0,l]:= merkliste[0,row];
      case Kostenfunktion of
        0: sekund[1,l]:='1';
        1: sekund[1,l]:=merkliste[3,row];
        2: sekund[1,l]:=FloatToStr(Log10(1+StrToFloat(merkliste[3,row])));
        3: sekund[1,l]:=FloatToStr(1/(1+StrToFloat(merkliste[3,row])));
        4: sekund[1,l]:=FloatToStr((Log10(1+StrToFloat(merkliste[3,row])))/(1+StrToFloat(merkliste[3,row])));
        5: sekund[1,l]:=merkliste[8,row];
      end;
    end;

  end;
// except('Error in area 661 to 700');
//  end;


/////////////////////////////////////////////////////////////////////////////
// Creating CPLEX file                                                     //
//                                                                         //
// end function: for z of U+: wi*zplus + wi*9000..00*zminus                //
//               for z of U-: wi*zminus + wi*9000..00*zplus                //
//               for s-cells: wi*zplus + wi*zminus                         //
// additional condition from base table                                    //
/////////////////////////////////////////////////////////////////////////////

 //LP-format as file for CPlex
  neuliste:=TStringList.Create;

 //end function
  neuliste.add('Min');
  neuliste.add('obj:');
  i:=1;
//  try

  //Primplus
  for col:=0 to Length(primplus[0])-1 do begin
    komma:='+'+primplus[1,col]+'x'+primplus[0,col]+'p';
    s:=komma;
    while Pos(',', s) > 0 do s[Pos(',', s)] := '.';
    komma:=s;
    j:=Length(neuliste[i]);
    if Length(komma)+j>255 then begin
       neuliste.add('');
       inc(i);
    end;
    neuliste[i]:=neuliste[i]+komma;
    komma:='+'+FloattoStr(StrToFloat(primplus[1,col])*9000000000000)+'x'+primplus[0,col]+'m';
    s:=komma;
    while Pos(',', s) > 0 do s[Pos(',', s)] := '.';
    komma:=s;
    j:=Length(neuliste[i]);
    if Length(komma)+j>255 then begin
       neuliste.add('');
       inc(i);
    end;
    neuliste[i]:=neuliste[i]+komma;
  end;  //for col...

//  except
//  showmessage('Error!');
//  end;

  //Primmin
  for col:=0 to Length(primmin[0])-1 do begin
    komma:='+'+primmin[1,col]+'x'+primmin[0,col]+'m';
    s:=komma;
    while Pos(',', s) > 0 do s[Pos(',', s)] := '.';
    komma:=s;
    j:=Length(neuliste[i]);
    if Length(komma)+j>255 then begin
       neuliste.add('');
       inc(i);
    end;
    neuliste[i]:=neuliste[i]+komma;
    komma:='+'+FloattoStr(StrToFloat(primmin[1,col])*9000000000000)+'x'+primmin[0,col]+'p';
    s:=komma;
    while Pos(',', s) > 0 do s[Pos(',', s)] := '.';
    komma:=s;
    j:=Length(neuliste[i]);
    if Length(komma)+j>255 then begin
       neuliste.add('');
       inc(i);
    end;
    neuliste[i]:=neuliste[i]+komma;
    end;


   //Sekund
  for col:=0 to Length(sekund[0])-1 do begin
    komma:='+'+sekund[1,col]+'x'+sekund[0,col]+'p';
    s:=komma;
    while Pos(',', s) > 0 do s[Pos(',', s)] := '.';
    komma:=s;
    j:=Length(neuliste[i]);
    if Length(komma)+j>255 then begin
       neuliste.add('');
       inc(i);
    end;
    neuliste[i]:=neuliste[i]+komma;
    komma:='+'+sekund[1,col]+'x'+sekund[0,col]+'m';
    s:=komma;
    while Pos(',', s) > 0 do s[Pos(',', s)] := '.';
    komma:=s;
    j:=Length(neuliste[i]);
    if Length(komma)+j>255 then begin
       neuliste.add('');
       inc(i);
    end;
    neuliste[i]:=neuliste[i]+komma;
  end;
//---------------------------------------
sekund:=nil;
//---------------------------------------

  //additional condition
  neuliste.add('Subject To');
  //reading of rows of basistab
  inc(i);
  for row := Low(basistab) to High(basistab) do begin
    inc(i);
    neuliste.add('');
    for col := Low(basistab[row]) to High(basistab[row]) do begin
      neuliste[i]:=neuliste[i]+basistab[row,col]+'p';
      if copy(basistab[row,col],1,1)='+' then
         neuliste[i]:=neuliste[i]+'-'+copy(basistab[row,col],2,Length(basistab[row,col]))+'m'
      else  //The difference is the algebraic sign!!
         neuliste[i]:=neuliste[i]+'+'+copy(basistab[row,col],2,Length(basistab[row,col]))+'m';
    end; //for col...
    neuliste[i]:=neuliste[i]+'=0';
  end;   //for row...

//---------------------------------------------------------------------
basistab:=nil;
//---------------------------------------------------------------------


  //Bounds
  neuliste.add('Bounds');
  for row:=0 to zaehlercol-1 do begin
    neuliste.add('0<='+'x'+merkliste[0,row]+'p'+'<='+merkliste[4,row]);
    neuliste.add('0<='+'x'+merkliste[0,row]+'m'+'<='+merkliste[5,row]);
  end;
  for row:=0 to Length(primplus[0])-1 do begin
    if strtofloat(stringarray[7,strtoint(primplus[0,row])+2])<strtofloat(primplus[2,row]) then
       neuliste.add('x'+primplus[0,row]+'p'+'>='+stringarray[7,strtoint(primplus[0,row])+2])
    else neuliste.add('x'+primplus[0,row]+'p'+'>='+primplus[2,row]);
  end;
  for row:=0 to Length(primmin[0])-1 do begin
    if strtofloat(stringarray[6,strtoint(primmin[0,row])+2])<strtofloat(primmin[2,row]) then
       neuliste.add('x'+primmin[0,row]+'m'+'>='+stringarray[6,strtoint(primmin[0,row])+2])
    else neuliste.add('x'+primmin[0,row]+'m'+'>='+primmin[2,row]);
  end;


  //End
  neuliste.Add('End');
//----------------------------
primplus:=nil;
primmin:=nil;
//----------------------------


  dateiname:=GetCurrentDir+'\VERSUCH';
  neuliste.SaveToFile(dateiname+'.lp');
//  showmessage(extractfilepath(dateiname));
  neuliste.free;

writeln('LP-file constructed');



  /////////////////////////////////////////////////////////////////////////////
  // optimization:                                                           //
  //                                                                         //
  // * function calls for Cplex                                              //
  // * readout of the file with the results and save in Ersatz, minmax       //
  /////////////////////////////////////////////////////////////////////////////



  CPlexVersion :='cplex75.dll';

  //loading DLL-functions
  lib:=LoadLibrary(PCHAR(CplexVersion));
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
//---------------------------------------------------
     @PutEnv:=GetProcAddress(lib,'CPXputenv');
//---------------------------------------------------
  end
  else begin
  //Error[18]
  writeln(CplexVersion+'  wasn''t found!');
  barray[18]:=false;
  exit
  end;

//If necessary another decimalseparator:
  decimalseparator:=',';

  stat:=1;
  typ:='lp';

//opening CPLEX
//Cplex starting

  envsetting := 'ILOG_LICENCE_FILE='+ IntervalleData.Cplex_ILM;

  i := putenv(envsetting);

  if i <> 0 then
   writeln('environment setting failed');


  env:=OpenCPLEX(@stat);

  lp:=Createprob(env,@stat,'myprob');
  stat:=Readcopyprob(env,lp,dateiname,typ);
  stat:=Lpopt(env,lp);//Min

  typ:='txt';

  //result as binary file
  typ:='bin';
  datei:=GetCurrentDir+'\loesung.bin';
  stat:=Writesol(env,lp,datei,typ);
  stat:=Freeprob(env,lp);
  stat:=CloseCPLEX(env);
//  FreeLibrary(lib);


  //DeleteFile(Dateiname+'.lp');   //input Cplex

  SetLength(ersloesung,2,zaehlercol*2);

  //readout of the binary file
  f:=TFileStream.Create(datei,fmOpenRead);
  f.Position:=920+zaehlerrow*72+72+24+72+72+4;
  for i:=0 to zaehlercol*2-1 do begin
    f.Read(doub,Sizeof(doub));
    ersloesung[1,i]:=floattostr(round(doub));
    f.Position:=f.Position+48;
    F.Read(hilfe,Sizeof(hilfe));
    ersloesung[0,i]:=hilfe[0]+hilfe;
    s:=ersloesung[0,i];
    while Pos(' ',s) > 0 do Delete(s,Pos(' ', s),1); //removing of the space characters
    ersloesung[0,i]:=s;
    f.Position:=f.Position+8;
  end;
  f.Free;


//creating compensation array
  SetLength(ersatz,4,zaehlercol+1);
  ersatz[1,0]:='plus';
  ersatz[2,0]:='minus';
  ersatz[3,0]:='synthetic value';
  for row:=1 to zaehlercol do begin
    ersatz[0,row]:=minmax[0,row];
    ersatz[1,row]:='0';
    ersatz[2,row]:='0';
  end;

  for i:=0 to zaehlercol*2-1 do begin
    for j:=1 to zaehlercol do begin
      if copy(ersloesung[0,i],1,Length(ersloesung[0,i])-1)=ersatz[0,j]then begin
        if copy(ersloesung[0,i],Length(ersloesung[0,i]),1)='p' then
           ersatz[1,j]:=ersloesung[1,i];
        if copy(ersloesung[0,i],Length(ersloesung[0,i]),1)='m' then
           ersatz[2,j]:=ersloesung[1,i];
        break;
      end;
    end;  //for j...
  end;    //for i...

//---------------------------------------
ersloesung:=nil;
//---------------------------------------


//calculating synthetic cell values, assign and count of the insecure cells
  for row:=1 to zaehlercol do begin
   minmax[4,row]:= InttoStr(StrToInt(minmax[1,row])+StrToInt(ersatz[1,row])-StrToInt(ersatz[2,row]));
    minmax[5,row]:=inttostr((strtoint(minmax[4,row])-strtoint(minmax[1,row])));

//try

    if abs(strtoint(minmax[5,row])) <
       max((strtofloat(stringarray[7,strtoint(merkliste[0,row-1])+2])),
           (strtofloat(stringarray[6,strtoint(merkliste[0,row-1])+2])))

      then begin  minmax[3,row]:=inttostr(strtoint('1')); inc(unsicher);
 end;

//except
//showmessage('Hier ein Error');
//end;
  end;
  merkliste:=nil;
  stringarray:=nil;


  DeleteFile(Datei);     //ouput Cplex results


  /////////////////////////////////////////////////////////////////////////////
  // output synthetic cell values                                            //
  /////////////////////////////////////////////////////////////////////////////

  //displaying of the synthetic cell values in outputers1neu.txt
   listeEW:=TStringList.Create;
   listeEW.add('The table contains '+inttostr(prim)+' primary suppressed cells ');
   listeEW.add('and '+inttostr(sek)+' secondary suppressed cells.');
   listeEW.add('There are still '+inttostr(unsicher)+' cells unprotected.');
   listeEW.add(' ');
//   showmessage(minmax[0,1]);
   for row:=0 to zaehlercol do begin
     if row=0  then listeEW.add(minmax[0,row]+';'+'synthetic value'+';'+'difference'+';'+minmax[3,row])
     else begin
       if length(minmax[4,row])<8 then begin
       listeEW.add(copy(minmax[0,row],2,Length(minmax[0,row])-1)+';'+minmax[4,row]+';'+minmax[5,row]+';'+minmax[3,row]);
       end
       else listeEW.add(copy(minmax[0,row],2,Length(minmax[0,row])-1)+';'+minmax[4,row]+';'+minmax[5,row]+';'+minmax[3,row]);
     end;
   end;
   for i:=0 to zaehlercol do begin

   end;
//---------------------------------------
minmax:=nil;
//---------------------------------------


   Ersatzwerte:=listeEW;
//---------------------------------------
//if there is an EAccessViolationError, then remove the lower line, it probably causes this error
ersatz:=nil;
//---------------------------------------
end;

exports  Ersatzwerte;

begin
  listeEW.Free;
  FreeLibrary(lib);
end.

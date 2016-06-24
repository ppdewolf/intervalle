program IntervalleBETA;

{$MODE Delphi}

{$APPTYPE CONSOLE}
//changes:
//1. some comments (oder parts of the programm) were erased
//2. The error barray was transfered to Intervalle Data so can be used fromm all the Units
//and GoTOFlag was entered in Intervalle so the programm does not break down but
//writes the Errors at the end of the console and in the logfile. Also an
// ErrorList was implemented so new Errors can be added at the end of the list.
//3. GLPK solver was included so the Intervalle programm can be used without Xpress or CPlex license
//4. The program now does not show each problem and solution in the consol but writes the percentage of advance.
//5. The program does not show the computation of the bounds anymore but this can be changed easy by setting DTS back to true.
//6. The program was adapted to Delphi XE2, a control parameter was entered at the beginigin fo unitintervalle.
//   To compile the programm with Delphi 2007 or older the parameter XE should be set false.
//7. An Error code is returned by the program.




uses
  SysUtils,
  Windows,
  Messages,
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
  ComCtrls, Interfaces,
  IntervalleData in 'IntervalleData.pas',
  UnitErsatzwerte in 'UnitErsatzwerte.pas',
  unitintervalle in 'unitintervalle.pas';

var
  dimension,zellanzahl,anzahltxt              :longint;
  liste                        : Tstrings;
  //---------------------------------------------------
   binary                                 : boolean;
  //---------------------------------------------------
  mosel,dateirechnen,AusgabeINT,AusgabeERSATZ,dateiTXT,s,version      : string;
  zeit1,zeit2{,logzeit}                     : Tdatetime;
  hrs,min,sec,msec                          : word;
  orglisteINTER,listeTXT,orglisteErsatz     : tstrings;
  p0,p1,p2,p3,inter,ersatz,kosten,i,j,k,count,merk  : Integer;
  OK                                        : Boolean;

  {// MOD 08.2012:not used Variables:
  T,hilfsstring,hilfsstring2,verzeichnis      : String;
  logfile                                     : Tstrings;
  p                                           : longint;    }


  //----------------------------------------------------------------
  ListeError                                : TStringList;
  //----------------------------------------------------------------

Label
  GoToLabel;


procedure TestDot;
var x: double; St: String; p: LongInt;
begin
 x := 0.01;
 St := FloatToStr(x);
 p := pos('.',St);
 ConvertDot := (p>0);
 writeln ('der',convertdot);
end;


procedure Offnen;
  /////////////////////////////////////////////////////////////////////////////
  // Open:                                                                   //
  // ----------------                                                        //
  // reaads information from inpu_audit                                      //
  // preprocessing of the JJ-file (Elemination of the space characters)      //
  /////////////////////////////////////////////////////////////////////////////
var
  s                                        : string;
  merk,count,i,j,k,orglaenge               : longint;
  listeEingabe                             : TStringList;


begin
//----------------------------------------------------------------------
  decimalseparator:='.';

//opening of the file
  listeEingabe:=TStringList.Create;
  if paramStr(1)<> '' then
    listeEingabe.LoadFromFile(paramStr(1))
  else begin
   //Error[1]
   writeln('error while loading file. missing first parameter');
   barray[1]:=false;
   exit;
  end;

//see in input_Audit.txt
  version:=listeEingabe[14];
  mosel:=listeEingabe[1];
  AusgabeInt:=listeEingabe[2];
  AusgabeErsatz:=listeEingabe[3];
  dateirechnen:=listeEingabe[4];
  dateiTXT:=listeEingabe[5];
  dimension:=strtoint(listeEingabe[6]);
  inter:=StrToInt(listeEingabe[7]);
  ersatz:=StrToInt(listeEingabe[8]);
  p0:=StrToInt(listeEingabe[9]);
  p1:=StrToInt(listeEingabe[10]);
  p2:=StrToInt(listeEingabe[11]);
  p3:=StrToInt(listeEingabe[12]);
  Kosten:=StrToInt(listeEingabe[13]);
  IntervalleData.CPlex_ILM:= ListeEingabe[15];

//reading of the jj-file
  liste:=TStringList.Create;
  liste.LoadFromFile(listeEingabe[0]);
  listeEingabe.Free;

//removing of the space characters in the first row
  s:=liste[0];
  s:=stringreplace(s, ' ', '', [rfReplaceAll, rfIgnoreCase]);
  //while Pos(' ',s) > 0 do Delete(s,Pos(' ', s),1);
  liste[0]:=s;

//removing of the space characters in the second row (number of the cells)
  s:=liste[1];
  s:=stringreplace(s, ' ', '', [rfReplaceAll, rfIgnoreCase]);
  // while Pos(' ',s) > 0 do Delete(s,Pos(' ', s),1);
  liste[1]:=s;
  zellanzahl:=StrToInt(liste[1]);

//removing of the space characters in the row defined by the number of equations
  s:=liste[zellanzahl+2];
  s:=stringreplace(s, ' ', '', [rfReplaceAll, rfIgnoreCase]);
  //while Pos(' ',s) > 0 do Delete(s,Pos(' ', s),1);
  liste[zellanzahl+2]:=s;

  orglaenge:=liste.Count;

//removing of the multiple space characters
  for i:=0 to orglaenge-1 do begin
    s:=liste[i];
    //showmessage(s);
    count:=0; merk:=0;
    TrimRight(s);
    for j:=1 to Length(liste[i]) do begin
      if s[j]<> ' ' then begin
        merk:=j;
        break;
      end;
    end;
    if merk>0 then  begin
      for j:=1 to merk-1 do begin
        Delete(s,1,1);
        //showmessage(s);
      end;
    end;
    k:=0;
    for j:=1 to Length(liste[i]) do begin
      if s[j-k]=' ' then inc(count);
      if count>1 then begin
        Delete(s,j-k,1);
        dec(count);
        inc(k);
        //showmessage(s);
      end;
      if s[j-k]<>' ' then count:=0;
    end;
    liste[i]:=s;
    //showmessage(liste[i]);
  end;  //for i

// The variable liste saves the original table (JJ-format) without space characters
// -> global variable, who will be used in the DLL-procedures

end;   //procedure Offnen



begin

//Logfile is build and Offnen is called
//    logzeit:=time;
  AssignFile (intervalleLog, paramStr(2)); //logfile:=TStringlist.Create;
  rewrite (intervalleLog); //Causes an EinOutError, if file does not exist!
  CloseFile(intervalleLog);

  WriteLog ('Start'); //logfile.add(TimeToStr(logzeit)+'   Start');
  Offnen;

  //---------------------------------------------------------------------
    if barray[1]=false then GoTo GotoLabel;
  //------------------------------------------------------------------------

  //logzeit:=time;
  WriteLog ('JJ-file was opened'); //logfile.add(TimeToStr(logzeit)+'   JJ-file was opened');
  TestComma;
  TestDot;


// Computation Units are called

  if (version='cplex') or (version = 'xpress') or (version='GLPK') Then Begin

      if inter=1 then begin                //computation of intervalle is demanded
          //try
          //begin
          // @IntervallC := GetProcAddress(libINTC, 'Intervalle');
           zeit1:=time;
           writeln('Calculation of intervals started. Please wait...');
           if version = 'cplex' then i:= 1 else if version='xpress' then i:= 2 else i:=3;
          //-----------------------------------------------------------------
          //           orglisteINTER:=TStringList.Create;
          //-----------------------------------------------------------------
//Unitintervalle is called
           orglisteINTER:=UnitIntervalle.Intervalle(liste,p0,p1,p2,p3,OK,i,dateirechnen);
           if not OK then begin
              writeln ( 'error occurred in intervalle procedure');
              writeln ( 'program stopped');
              //Error[14]
              barray[14]:=false;
              GoTo GoToLabel;
           end;
           try
            orglisteINTER.savetofile(AusgabeInt);
           except
            //Error[15]
            writeln('error in the calculating procedure');
            barray[15]:=false;
           end;
           if barray[15]=false then Goto GotoLabel;

           zeit2:=time;
           // logzeit:=time;
           WriteLog (' Calculation of intervals was successful');
           Decodetime((zeit1-zeit2),hrs,min,sec,msec);
           WriteLog ('Computing time: '+inttostr(hrs) +' hours '+inttostr(min)+' min '+inttostr(sec)+' sec');
          //----------------------------------------------------------------------
          //           orglisteINTER.free;
          //----------------------------------------------------------------------
          //end;

          //---------------------------------------------------------------
          //   if barray[14]=false or barray[15]=false then GoTo GotoLabel;
          //-------------------------------------------------------------------
      end  // if inter=1


      else
      WriteLog ('Calculating of intervalls was not demanded');

      if ersatz=1 then  //calculation of synthetic values demanded
      begin
        writeln;
        writeln;
        writeln('Calculation of synthetic cell values started. Please wait...');
//adaptive Gammas chosen
        if (kosten=5) AND (dateiTXT='without') then begin
          WriteLog ('You need to specify a txt-file for further Information if you choose cost-function 5 (adaptive gammas)');
          //Error[16]
          barray[16]:=false;
//-----------------------------------------------------------------------------
          GoTo GoToLabel;
//------------------------------------------------------------------------------
        end;

        if (kosten=5) AND (dateiTXT<>'without') THEN begin
          listeTXT:=TStringList.Create;
          listeTXT.loadfromfile(dateiTXT);
//the information of the txt file will be saved global in listeTXT global
// to avoiding loading of the file for another calculation
          anzahlTXT:=listeTXT.count;

//so long as the number of the cells is out of place, loading will be repeated
          if abs(anzahlTXT-zellanzahl)>5 then begin
//difference, because space characters at the end of the txt file are possible
            WriteLog ('jj-file and txt-file for adaptive gammas not match. Please try again with a new txt file.');
            halt;
          end      //if abs...
          else  begin      //if abs
            listetxt[0]:='xx';
//removing of the muliple space characters
            for i:=0 to anzahlTXT-1 do begin
             s:=listeTXT[i];
             count:=0; merk:=0;
             TrimRight(s);
             for j:=1 to Length(listeTXT[i]) do begin
               if s[j]<> ' ' then begin
                 merk:=j;
                 break;
               end;
             end;
             if merk>0 then begin
              for j:=1 to merk-1 do begin
                Delete(s,1,1);
              end;
             end;
             k:=0;
             for j:=1 to Length(listeTXT[i]) do begin
              if s[j-k]=' ' then inc(count);
              if count>1 then begin
                Delete(s,j-k,1);
                dec(count);
                inc(k);
              end;
              if s[j-k]<>' ' then count:=0;
             end;
             listeTXT[i]:=s;
            end;
          end;     //else  if abs
          listeTXT.savetofile('gammas.txt');
          listeTXT.Free;
        end;    //if kosten=5  and

        if (kosten=5) AND (dateiTXT='without') THEN begin
         WriteLog ('for adaptive gammas you need to specify a txt-file. Please try again with a path to a txt file instead of "Without".'); //Anco logfile.add('for adaptive gammas you need to specify a txt-file. Please try again with a path to a txt file instead of "Without".');
         //Error[17]
         barray[17]:=false;
         GoTo GoTOLabel;
        end;

//calculation of the synthetic cell values
//only run if the Gamma and the txt file have the same dimension or another cost function is chosen
        try
          begin
          //@ErsatzwerteC:=GetProcAddress(libEWC,'Ersatzwerte');
          //anzahltxt:=0; // Intitialisation of anzahltxt (if necessary)
            zeit1:=time;
          //--------------------------------------------------------------------------
          //          orglisteErsatz:=TStringlist.Create;
          //--------------------------------------------------------------------------
            orglisteErsatz:=UnitErsatzwerte.Ersatzwerte(liste,anzahltxt,dimension,p0,p1,p2,p3,Kosten);
            orglisteErsatz.savetoFile(AusgabeErsatz);
            zeit2:=time;
            // logzeit:=time;
            WriteLog ('synthetic cell values calculated successfully.'); //Anco logfile.add(TimeToStr(logzeit)+'   synthetic cell values calculated successfully.');
            WriteLog ('Computing time: '+TimetoStr(zeit2-zeit1)); //Anco logfile.add('           Computing time: '+TimetoStr(zeit2-zeit1));
            WriteLog (''); //Anco logfile.add('');
            // try
            //  Freelibrary(libEW);
            // except
            // WriteLog ('DLL could not be deallocated'); //Anco logfile.add('          DLL could not be deallocated');
            //end;
          end
        except
          //Error[19]
          writeln('error in the calculating procedure');
          barray[19]:=false;
        end;
        // else showmessage('DLL for synthetic cell value calculating was not found');
      end  //if ersatz=1
      else
      WriteLog ('Calculating of synthetic cell values was not demanded'); //Anco logfile.add('Calculating of synthetic cell values was not demanded');


  end     //if version=cplex or xpress  or GLPK
  else
  begin
    WriteLog ('Check the spelling of Xpress or Cplex in the input file.'); //Anco logfile.add('Check the spelling of Xpress or Cplex in the input file..');
    WriteLog ('For XPress type:  xpress and for Cplex type:    cplex'); //Anco logfile.add('For XPress type:  xpress and for Cplex type:    cplex');
    //Error[2]
    barray[2]:=false;
  end;
  //----------------------------------------------------------------
  //            orglisteErsatz.Free;
  //----------------------------------------------------------------

//creating of errorlist
  //--------------------------------------------------------------------
  GoToLabel:

  ListeError:=TStringList.Create;
  ListeError.LoadFromFile(Extractfilepath(paramStr(0))+'Error.txt');

  for i:=0 to 20 do begin
   if barray[i]=false then begin
      writelog('Program-Error['+inttostr(i)+']. '+ListeError[i-1]+' Please correct all errors.');
      binary:=false;
   end;//if
  end; //for

  if binary=true then
    writelog ('program intervalle finished successfully')
  else begin
      for i:=1 to 20 do  begin
        if barray[i]=false then halt(i);    //return Error code i
      end;
  end;
//--------------------------------------------------------------------------
end.


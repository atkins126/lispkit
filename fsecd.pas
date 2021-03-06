[INHERIT('SYS$LIBRARY:STARLET')] { FAB-related definitions }

program Lispkit(Input, Output, InFile, OutFile);

(*-----------------------------------------------------------------*)
(*                                                                 *)
(*   Reference model lazy interactive SECD machine, 3a   April 83  *)
(*                                                                 *)
(*   Modifications specific to VAX VMS Pascal gaj        April 83  *)
(*   Interface to VAX machine code amrn                    May 83  *)
(*   Change to break lines in file output gaj           August 83  *)
(*   I/O compatible with both version 1 & 2 compiers     April 84  *)
(*     -- need to remove the nested formal parameter lists from    *)
(*        the declaration of the external procedure to compile     *)
(*        with the version 1 compiler                              *)
(*                                                                 *)
(*-----------------------------------------------------------------*)
(*                                                                 *)
(*    (c)  P Henderson, G A Jones, S B Jones, A M R Newman         *)
(*                    Oxford University Computing Laboratory       *)
(*                    Programming Research Group                   *)
(*                    8-11 Keble Road                              *)
(*                    OXFORD  OX1 3QD                              *)
(*                                                                 *)
(*-----------------------------------------------------------------*)
(*                                                                 *)
(*   Documentation:                                                *)
(*                                                                 *)
(*     P Henderson, S B Jones, G A Jones                           *)
(*         The LispKit Manual                                      *)
(*         Oxford University Computing Laboratory                  *)
(*         Programming Research Group technical monograph PRG-32   *)
(*         Oxford, August 1983                                     *)
(*                                                                 *)
(*     P Henderson                                                 *)
(*         Functional Programming: Application and Implementation. *)
(*         Prentice-Hall International, London, 1980               *)
(*                                                                 *)
(*-----------------------------------------------------------------*)

(*------------------ Machine dependent constants ------------------*)

label 99;
                  
const FileRecordLimit = 255;
      OutFileWidth = 200;
      OutTermWidth = 80;

(*--------------- Machine dependent file management ---------------*)

var InOpen : boolean;
    InFile : text;
    NewInput, InFromTerminal, OutToTerminal : boolean;
    OutFile : text;
    OutFileColumn : integer;
    OutTermColumn : integer;
    NullName : packed array[1..255] of char;

function IsTerminal(VAR f : text) : boolean;
  type phyle = [UNSAFE] text;
       pointer = ^FAB$TYPE;
  var p : pointer;
      d : [UNSAFE] DEV$TYPE;
  function PAS$FAB(VAR f : phyle) : pointer; EXTERN;
begin p := PAS$FAB(f);
      d := p^.FAB$L_DEV;
      IsTerminal := d.DEV$V_TRM
end {IsTerminal};

procedure OpenInFile;
var s : packed array[1..255] of char;
begin writeln(Output);
      write(Output, 'Take input from where? ');
      if eoln(Input) then s := NullName else read(Input, s);
      readln(Input);
      if s = NullName then
        open(File_Variable := InFile,
             File_Name := 'SYS$INPUT',
             History := Old)
      else
        open(File_Variable := InFile,
             File_Name := s,
             History := Old,
             Error := CONTINUE);
      InOpen := Status(InFile) <= 0;
      if InOpen then
          begin reset(InFile); InFromTerminal := IsTerminal(InFile) end
      else write(Output, 'Cannot read from that file')
end {OpenInFile};

procedure CloseInFile; begin close(InFile); InOpen := false end;

procedure ChangeOutFile;
var s : packed array[1..255] of char;
    ok : boolean;
begin close(OutFile);
      repeat writeln(Output);
             write(Output, 'Send output to where? ');
             if eoln(Input) then s := NullName else read(Input, s);
             readln(Input);
             if s = NullName then
               open(File_Variable := OutFile,
                    File_Name := 'SYS$OUTPUT',
                    History := New,
                    Record_Length := FileRecordLimit)
             else
               open(File_Variable := OutFile,
                    File_Name := s,
                    History := New,
                    Record_Length := FileRecordLimit,
                    Error := CONTINUE);
             ok := Status(OutFile) <= 0;
             if ok then rewrite(OutFile)
             else write(Output, 'Cannot write to that file')
      until ok;
      OutToTerminal := IsTerminal(OutFile);
      OutTermColumn := 0;
      OutFileColumn := 0
end {ChangeOutFile};

(*------------------- Character input and output ------------------*)

procedure GetChar(VAR ch : char);
const EM = 8;
begin while not InOpen do begin OpenInFile; NewInput := true end;
      if eof(InFile) then begin CloseInFile; ch := ' ' end
      else
        if eoln(InFile) then
              begin readln(InFile); NewInput := true; ch := ' ' end
      else
        begin if NewInput then
                begin if InFromTerminal then OutTermColumn := 0;
                      NewInput := false
                end;
              read(InFile, ch);
              if ch = chr(EM) then
                   begin readln(InFile); ChangeOutFile; ch := ' ' end
        end;
end {GetChar};

procedure PutChar(ch : char);
const CR = 13;
begin if ch = ' '
      then if OutToTerminal then
              begin if OutTermColumn >= OutTermWidth then ch := chr(CR) end
           else
              begin if OutFileColumn >= OutFileWidth then ch := chr(CR) end;
      if ch = chr(CR) then
         begin writeln(OutFile);
               if OutToTerminal then
                     OutTermColumn := 0
               else OutFileColumn := 0
         end
      else
         begin write(OutFile, ch);
               if OutToTerminal then
                    OutTermColumn := OutTermColumn + 1
               else OutFileColumn := OutFileColumn + 1
         end
end {PutChar};

(*------- Machine dependent initialisation and finalisation -------*)

procedure Initialise(Version, SubVersion : char);
var i : 1..255;
begin writeln(Output, 'VAX Pascal SECD machine ', Version, SubVersion);
      for i := 1 to 255 do NullName[i] := ' ';
      open(File_Variable := InFile,
           File_Name := 'LISPKIT$SECDBOOT',
           History := Old,
           Error := CONTINUE);
      InOpen := status(InFile) <= 0;
      if InOpen then
             begin reset(InFile); InFromTerminal := IsTerminal(InFile) end
      else writeln(Output, 'No file LispKit$SECDboot');
      NewInput := true;
      open(File_Variable := OutFile,
           File_Name := 'SYS$OUTPUT',
           History := New,
           Record_Length := FileRecordLimit);
      rewrite(OutFile);
      OutToTerminal := IsTerminal(OutFile);
      OutTermColumn := 0;
      OutFileColumn := 0
end {Initialise};

procedure Terminate;
begin writeln(OutFile); close(OutFile); goto 99 end {Terminate};

(*--------------------- I/O independent code -----------------------*)

procedure Machine;
                        
        procedure writecon(c:char);
        begin
            if c = chr(13) then writeln(output) else
            write(output, c);
        end;

        procedure readcon(var c:char);
        begin
            read(input, c);
        end;

        procedure secdmc(procedure getdatachar(var ch:char);
                         procedure putdatachar(ch:char);
                         procedure getcommandchar(var ch:char);
                         procedure putcommandchar(ch:char));external;

begin
       initialise('3','a');
       secdmc(getchar, putchar, readcon, writecon);
end;

begin Machine; 99: end {LispKit}.

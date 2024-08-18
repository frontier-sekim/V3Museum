
;
;         MINIFY      The Executable File Compressor
;                     (c) Copyright 1991  by  Cheolsoo Ahn
;
;                     Version 0.2
;
;                     computer : IBM - PC
;                     language : Turbo Assembler 1.0
;                     ver  0.1 : 91. 10. 10.
;                     ver  0.2 : 91. 12. 11.
;

;================================================================
;         CONSTANTS DEFINITION
;================================================================

CR        EQU  0Dh                      ; ASCII carriage return
LF        EQU  0Ah                      ; ASCII line feed
TAB       EQU  09h                      ; ASCII tab
SPACE     EQU  20h                      ; ASCII space character


;================================================================
;         MACROS DEFINITION
;================================================================

PRINT     MACRO  String                 ; print string
          mov  ah, 9
          mov  dx, OFFSET String
          int  21h
          ENDM


;================================================================
;         MAIN PROGRAM
;================================================================

_TEXT     SEGMENT  WORD  PUBLIC  'CODE'

          ASSUME  cs:_TEXT, ds:_TEXT
          ORG  100h

 Entry:   jmp  Start

;----------------------------------------------------------------
;         Messages Definition
;----------------------------------------------------------------

 ProgName db   CR, LF
          db   'MINIFY   The Executable File Compressor   '
          db   'Version 0.2', CR, LF
          db   '(c) Copyright 1991     by  Cheolsoo Ahn'
          db   CR, LF, LF, '$'
 HelpMess db   'Usage: MINIFY <filename>', CR, LF, '$'
 EndMess  db   'File is successfully compressed', CR, LF, '$'
 ErrMess  db   'Error: ', 7, '$'
 ErrOffset     LABEL  WORD              ; address of message
 Offset1  dw   OFFSET ErrMess1
 Offset2  dw   OFFSET ErrMess2
 Offset3  dw   OFFSET ErrMess3
 Offset4  dw   OFFSET ErrMess4
 Offset5  dw   OFFSET ErrMess5
 Offset6  dw   OFFSET ErrMess6
 ErrMess1 db   'Can compress except COM files', CR, LF, '$'
 ErrMess2 db   'Cannot read the original file', CR, LF, '$'
 ErrMess3 db   'Insufficent memory', CR, LF, '$'
 ErrMess4 db   'Already compressed by MINIFY', CR, LF, '$'
 ErrMess5 db   'Cannot compress this file', CR, LF, '$'
 ErrMess6 db   'Cannot write the compressed file', CR, LF, '$'
 Handle   dw   ?

;----------------------------------------------------------------
;         Compressor Program
;----------------------------------------------------------------

 Start:   mov  sp, OFFSET StackArea     ; set new stack
          mov  bx, sp                   ; realloc memory
          add  bx, 0Fh
          mov  cl, 4
          shr  bx, cl
          mov  ah, 4Ah
          int  21h

          mov  ax, 2524h                ; set crit error handler
          mov  dx, OFFSET CritErrHndler
          int  21h

          Print  ProgName               ; print program name

          ;------------------------------------------------------

          mov  bx, 80h                  ; check argument
          mov  ax, 1
          call Argv
          cmp  bx, 80h                  ; argument present?
          jnz  ArgExist
          Print  HelpMess               ; if not, print usage
          jmp  NoErr

 ArgExist:mov  si, bx                   ; copy filename
          mov  di, OFFSET Filename
          xor  cx, cx                   ; reset counter
 NextFn:  lodsb
          cmp  al, SPACE                ; argument end if space
          je   MkASCIIZ
          cmp  al, TAB                  ; argument end if tab
          je   MkASCIIZ
          cmp  al, CR                   ; argument end if return
          je   MkASCIIZ
          cmp  al, 'a'                  ; is it lower character?
          jb   StrFn
          cmp  al, 'z'
          ja   StrFn
          and  al, 5Fh                  ; convert to upper char
 StrFn:   stosb
          inc  cx                       ; increase counter
          jmp  NextFn
 MkASCIIZ:mov  BYTE PTR [di], 0         ; make string to ASCIIZ

          cmp  WORD PTR [di - 3], 'OC'  ; is it COM?
          jne  IsExe
          cmp  BYTE PTR [di - 1], 'M'
          je   CopyOrig
 IsExe:   cmp  WORD PTR [di - 3], 'XE'  ; is it EXE?
          jne  NotProg
          cmp  BYTE PTR [di - 1], 'E'
          je   CopyOrig
 NotProg: jmp  Err1

 CopyOrig:mov  si, OFFSET Filename      ; copy filename
          mov  di, OFFSET OrigFile
          sub  cx, 3
          repz movsb
          mov  WORD PTR [di], 'RO'      ; make extension to ORI
          mov  WORD PTR [di + 2], 0049h

          mov  si, OFFSET Filename      ; copy filename
          mov  di, OFFSET TempFile
          repz movsb
          std
          mov  si, di
 NextTmp: lodsb
          cmp  al, '\'                  ; is it '\'?
          je   MkPath
          cmp  al, ':'                  ; is it ':'?
          je   MkPath
          cmp  si, OFFSET TempFile - 1  ; start of filename?
          jne  NextTmp
          dec  si
 MkPath:  mov  BYTE PTR [si + 2], 0     ; drop filename
          cld

          ;------------------------------------------------------

          mov  ax, 3D00h                ; open file
          mov  dx, OFFSET Filename
          int  21h
          jnc  GetSize                  ; error?
          jmp  Err2

 GetSize: mov  Handle, ax
          mov  bx, ax                   ; set pointer to end
          mov  ax, 4202h
          xor  cx, cx
          xor  dx, dx
          int  21h
          jnc  AllocMem                 ; error?
          jmp  Err2

 AllocMem:mov  DcmprLen, ax
          add  ax, 20Fh
          adc  dx, 0
          and  ax, 0FFF0h
          mov  WORD PTR MemEnd, ax
          dec  WORD PTR MemEnd

          mov  cx, 10h
          div  cx
          mov  bx, ax
          mov  ah, 48h                  ; alloc new memory
          int  21h
          jnc  ReadFile                 ; error?
          jmp  Err3

 ReadFile:mov  es, ax
          mov  ax, 4200h                ; set pointer to start
          mov  bx, Handle
          xor  cx, cx
          xor  dx, dx
          int  21h
          mov  ah, 3Fh                  ; read file
          mov  cx, DcmprLen
          xor  dx, dx
          push ds
          push es
          pop  ds
          int  21h
          jnc  ChkRS                    ; error?
          pop  ds
          jmp  Err2
 ChkRS:   pop  ds
          cmp  cx, ax                   ; check read byte
          je   ClsFile
          jmp  Err2

 ClsFile: mov  ah, 3Eh                  ; close file
          int  21h
          jnc  ChkHead                  ; error?
          jmp  Err2

          ;------------------------------------------------------

 ChkHead: cmp  WORD PTR es:[0], 5A4Dh   ; is it EXE file?
          jne  ChkMini
          jmp  Err1

 ChkMini: cmp  WORD PTR es:[1Eh], 'IM'   ; already compressed?
          jne  GetMark
          cmp  WORD PTR es:[20h], 'IN'
          jne  GetMark
          jmp  Err4

          ;------------------------------------------------------

 GetMark: mov  cx, DcmprLen             ; select RLE marker byte
          call SelectMarker
          mov  Marker, bl

          mov  si, cx                   ; relocate file content
          dec  si
          mov  di, WORD PTR MemEnd
          push ds
          push es
          pop  ds
          std
          repz movsb
          cld
          pop  ds

          mov  cx, DcmprLen             ; RLE compression
          mov  bl, Marker
          mov  si, di
          inc  si
          xor  di, di
          push ds
          push es
          pop  ds
          call RLEcompress
          pop  ds

          mov  CmprLen, cx              ; check compressed size
          mov  CmprLen2, cx
          add  cx, OFFSET Filename - OFFSET ComDcmpr2
          mov  WORD PTR CmprSize, cx
          add  cx, OFFSET ComDcmpr2 - OFFSET ComDcmpr1
          cmp  cx, DcmprLen             ; is it smaller?
          jb   PrpDcmp
          jmp  Err5

 PrpDcmp: add  cx, 0FFh
          mov  WORD PTR FileEnd, cx
          mov  ax, WORD PTR MemEnd
          sub  ax, OFFSET Filename - OFFSET ComDcmpr2
          sub  ax, OFFSET ToCmpr2 - OFFSET ComDcmpr1
          sub  ax, 101h
          mov  WORD PTR ToCmpr2, ax

          ;------------------------------------------------------

          mov  ah, 5Ah                  ; create temporary file
          xor  cx, cx
          mov  dx, OFFSET TempFile
          int  21h
          jnc  WrtDcmp1                 ; error?
          jmp  Err6

 WrtDcmp1:mov  bx, ax                   ; write decompressor1
          mov  ah, 40h
          mov  cx, OFFSET ComDcmpr2 - OFFSET ComDcmpr1
          mov  dx, OFFSET ComDcmpr1
          int  21h
          jnc  ChkWrtB1                 ; error?
          jmp  DelTemp
 ChkWrtB1:cmp  ax, cx                   ; check written byte
          je   WrtData
          jmp  DelTemp

 WrtData: mov  ah, 40h                  ; write compressed data
          mov  cx, CmprLen
          push ds
          push es
          pop  ds
          xor  dx, dx
          int  21h
          jnc  ChkWrtB2                 ; error?
          pop  ds
          jmp  DelTemp
 ChkWrtB2:pop  ds
          cmp  ax, cx                   ; check written byte
          je   WrtDcmp2
          jmp  DelTemp

 WrtDcmp2:mov  ah, 40h                  ; write decompressor2
          mov  cx, OFFSET Filename - OFFSET ComDcmpr2
          mov  dx, OFFSET ComDcmpr2
          int  21h
          jnc  ChkWrtB3                 ; error?
          jmp  DelTemp
 ChkWrtB3:cmp  ax, cx                   ; check written byte
          je   clsTfile
          jmp  DelTemp

 ClsTfile:mov  ah, 3Eh                  ; close file
          int  21h
          jnc  RenFile                  ; error?
          jmp  DelTemp

          ;------------------------------------------------------

 RenFile: push ds                       ; delete .ORI file
          pop  es
          mov  ah, 41h
          mov  dx, OFFSET OrigFile
          int  21h
          mov  ah, 56h                  ; rename file to .ORI
          mov  dx, OFFSET Filename
          mov  di, OFFSET OrigFile
          int  21h
          mov  ah, 56h                  ; rename temporary file
          mov  dx, OFFSET TempFile
          mov  di, OFFSET Filename
          int  21h

          Print  EndMess                ; print completed message

 NoErr:   xor  al, al                   ; no error
          jmp  Exit
 Err1:    mov  ax, 1
          jmp  PrtErr
 Err2:    mov  ax, 2
          jmp  PrtErr
 Err3:    mov  ax, 3
          jmp  PrtErr
 Err4:    mov  ax, 4
          jmp  PrtErr
 Err5:    mov  ax, 5
          jmp  PrtErr
 DelTemp: mov  ah, 41h                  ; delete temporary file
          mov  dx, OFFSET TempFile
          int  21h
 Err6:    mov  ax, 6
 PrtErr:  call PrintErrMess             ; print error message

 Exit:    mov  ah, 4Ch                  ; terminate
          int  21h

;----------------------------------------------------------------

Argv      PROC NEAR

          ; Function : Get address & length of command argument
          ; Call with: AX = argument number
          ;            BX = command line address
          ; Returns  : BX = argument address
          ;                (if no argument, BX doesn't change)

          push ax                       ; save original AX, CX
          push cx

          push bx
          cmp  BYTE PTR [bx], 0         ; no input ?
          je   RstrAdr

 Argv1:   mov  cx,-1                    ; set flag = outside arg

 Argv2:   inc  bx                       ; point to next character
          cmp  BYTE PTR [bx], SPACE
          je   Argv1                    ; outside if ASCII space
          cmp  BYTE PTR [bx], TAB
          je   Argv1                    ; outside if ASCII tab
          cmp  BYTE PTR [bx], CR
          je   RstrAdr                  ; exit if carriage return

          jcxz Argv2                    ; jump if inside argument

          inc  ah                       ; else count arguments
          cmp  ah,al                    ; is it requested one?
          je   SaveAdr                  ; yes, return to caller
          not  cx                       ; no, set flag = inside
          jmp  Argv2

 RstrAdr: pop  bx                       ; restore address
          jmp  ExitArgv

 SaveAdr: pop  cx                       ; ignore previous address

 ExitArgv:pop  cx                       ; restore original CX, AX
          pop  ax
          ret                           ; return to caller

Argv      ENDP

;----------------------------------------------------------------

SelectMarker   PROC NEAR

          ; Function : select the marker byte in RLE
          ; Call with: ES = segment of buffer
          ;            CX = data size
          ; Returns  : BL = RLE marker

          push ax                       ; save registers
          push cx
          push dx
          push si
          push di

          push cx                       ; set counters = 0
          push es
          push ds
          pop  es
          xor  ax, ax
          mov  di, OFFSET Counter
          mov  cx, 100h
          rep  stosw
          pop  es

          xor  si, si                   ; count frequency of byte
          mov  di, OFFSET Counter
          pop  cx
          xor  ah, ah
 NextCh:  mov  al, es:[si]
          inc  si
          mov  bx, ax
          shl  bx, 1
          inc  WORD PTR [di + bx]
          loop NextCh

          xor  bx, bx                   ; select least-frequently
          mov  si, OFFSET Counter       ;              -used byte
          mov  cx, 100h
          mov  dx, 0FFFFh
 NextCt:  lodsw
          cmp  ax, dx
          jae  Skip
          mov  dx, ax
          mov  bl, bh
 Skip:    inc  bh
          loop NextCt

          pop  di                       ; restore registers
          pop  si
          pop  dx
          pop  cx
          pop  ax
          ret                           ; return to caller

SelectMarker   ENDP

;----------------------------------------------------------------

RLEcompress    PROC NEAR

          ; Function : compress the data by RLE
          ; Call with: DS:SI = buffer of original data
          ;            ES:DI = buffer of compressed data
          ;            CX = data size
          ;            BL = RLE marker
          ; Returns  : CX = compressed data size

          push ax                       ; save registers
          push bx
          push si
          push di

          mov  al, [si]                 ; get first byte
          not  al
          xor  bh, bh                   ; set counter = 0

 Comp:    mov  ah, al                   ; save previous byte
          lodsb                         ; get one byte
          cmp  al, bl                   ; is it marker byte?
          je   FoundMk
          cmp  al, ah                   ; is it the same byte?
          je   SameCh
          call CheckCounter             ; check counter
          stosb                         ; store the byte
          xor  bh, bh                   ; reset counter
          jmp  Lcomp

 SameCh:  inc  bh                       ; increase counter
          cmp  bh, 0FFh                 ; counter = 0FFh ?
          jne  Lcomp
          mov  WORD PTR es:[di], bx     ; store marker & counter
          inc  di                       ; increase pointer
          inc  di
          mov  al, bl                   ; set new byte = marker
          xor  bh, bh                   ; reset counter
          jmp  Lcomp

 FoundMk: stosb                         ; store marker + 0
          mov  BYTE PTR es:[di], 0
          inc  di                       ; increase pointer
 Lcomp:   loop Comp

          call CheckCounter             ; check counter

          mov  cx, di                   ; save compressed size

          pop  di                       ; restore registers
          pop  si
          pop  bx
          pop  ax
          ret                           ; return to caller

RLEcompress    ENDP

;----------------------------------------------------------------

CheckCounter   PROC NEAR

          ; Function : check counter and store RLE data
          ; Call with: AH = previous counter
          ;            BH = counter
          ;            BL = RLE marker
          ;            DI = buffer of compressed data

          or   bh, bh                   ; counter = 0 ?
          je   ExitCC
          cmp  bh, 2                    ; counter > 3 ?
          ja   RLE
          jb   StoreIt
          mov  BYTE PTR es:[di], ah     ; counter = 2
          inc  di
 StoreIt: mov  BYTE PTR es:[di], ah     ; counter = 1
          jmp  IncAddr

 RLE:     mov  WORD PTR es:[di], bx     ; store marker + counter
          inc  di
 IncAddr: inc  di

 ExitCC:  ret                           ; return to caller

CheckCounter   ENDP

;----------------------------------------------------------------


PrintErrMess   PROC NEAR

          ; Function : print error message
          ; Call with: AX = error code

          push ax                       ; save registers
          push bx
          push dx

          push ax                       
          Print  ErrMess                ; print 'Error: '
          pop  ax

          dec  ax                       ; calc address of message
          shl  ax, 1
          mov  bx, offset ErrOffset
          add  bx, ax

          mov  ah, 9                    ; print error message
          mov  dx, [bx]
          int  21h

          pop  dx                       ; restore registers
          pop  bx
          pop  ax
          ret                           ; return to caller

PrintErrMess   ENDP

;----------------------------------------------------------------

CritErrHndler  PROC FAR

          ; Function : critical error handler

          push ax                       ; save registers
          push bx
          push cx
          push dx
          push ds
          push cs
          pop  ds

          test ah, 10000000b            ; determine device type
          jnz  ChDevErr
          test ah, 1
          jnz  DskWtErr
          Print  ErrMess                ; disk read error
          mov  dx, OFFSET CritErr1
          int  21h
          jmp  ExitH
 DskWtErr:Print  ErrMess                ; disk write error
          mov  dx, OFFSET CritErr2
          int  21h
          jmp  ExitH
 ChDevErr:Print  ErrMess                ; character device error
          mov  dx, OFFSET CritErr3
          int  21h

 ExitH:   pop  ds                       ; restore registers
          pop  dx
          pop  cx
          pop  bx
          pop  ax

          mov  al, 2                    ; Abort
          iret

 CritErr1 db   'Disk read error', CR, LF, '$'
 CritErr2 db   'Disk write error', CR, LF, '$'
 CritErr3 db   'I/O error occurred', CR, LF, '$'

CritErrHndler  ENDP

;----------------------------------------------------------------

ComDcmpr1 PROC  NEAR

          db   0BFh                     ; mov  di, MemEnd
 MemEnd:  dw   ?
          cmp  di, sp
          jb   Reloc1
          mov  ah, 9
          mov  dx, OFFSET Mess - OFFSET ComDcmpr1 + 100h
          int  21h
          ret

 Reloc1:  db   0BEh                     ; mov  si, FileEnd
 FileEnd: dw   ?
          db   0B9h                     ; mov  cx, CmprSize
 CmprSize:dw   ?
          std
          repz movsb
          cld
          db   0E9h                     ; jmp  ToCmpr2
 ToCmpr2: dw   ?

 Signate  db   'MINI'
 Ver      db   3
 CmprType db   1
 DcmprLen dw   ?
          dw   0
 CmprLen  dw   ?
          dw   0
 Mess     db   'Insufficient Memory', CR, LF, '$'

ComDcmpr1 ENDP

;----------------------------------------------------------------

ComDcmpr2 PROC  NEAR

          mov  si, di                   ; decompress data
          inc  si
          mov  di, 100h
          db   0B9h                     ; mov  cx, CmprLen2
 CmprLen2 dw   ?
          db   0B3h                     ; mov  bl, Marker
 Marker   db   ?

 Decomp:  lodsb                         ; get one byte
          cmp  al, bl
          je   PrcssMk
 NotMk:   stosb                         ; store the byte
          mov  ah, al                   ; save previous byte
 Ldecomp: loop Decomp

          mov  ax, 100h
          push ax                       ; store return address
          xor  si, si                   ; reset registers
          xor  di, di
          xor  cx, cx
          xor  bx, bx
          xor  ax, ax
          ret                           ; return to original

 PrcssMk: lodsb                         ; get counter byte
          dec  cx
          or   al, al                   ; counter = 0 ?
          jnz  GetNo
          mov  al, bl                   ; save marker byte
          jmp  NotMk                    ; store marker byte

 GetNo:   xchg ah, al                   ; AL = previous byte
 ReptCh:  stosb                         ; store the byte
          dec  ah                       ; decrease counter
          jnz  ReptCh
          mov  ah, bl                   ; save marker byte
          jmp  Ldecomp

ComDcmpr2 ENDP

;----------------------------------------------------------------

 Filename       LABEL  BYTE             ; original filename
 OrigFile       EQU    Filename +  80h  ; filename.ORI
 TempFile       EQU    OrigFile +  80h  ; temporary filename
 Counter        EQU    TempFile +  80h  ; counter
 Buffer         EQU    Counter  + 200h  ; stack area
 StackArea      EQU    Buffer   + 100h

;----------------------------------------------------------------

_TEXT     ENDS

          END  Entry


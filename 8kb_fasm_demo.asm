; Source: https://github.com/zeittresor/8k_FASM_Project

format PE GUI 4.0
entry start
include 'win32a.inc'

FW      = 480
FH      = 270
IDT     = 1
SC      = 7680             ; four bars at 125 BPM
NSC     = 16
XF      = 960              ; two beats
SR      = 11025
PT      = 1323             ; one 16th note at 125 BPM
BLOCKS  = 32               ; 32 x two-bar blocks = 64 bars
SN      = PT*32*BLOCKS     ; exactly 122.88 seconds

section '.data' data readable writeable

cls db 'd8k2',0
ttl db 'DISCOVERY 8K COMPOSED',0


nt dw 389,436,490,519,583,654,734,778,873,980,1038,1166,1308,1468,1556,1746,1960,2077,2331,2616,2937,3111,3492,3920,4153

lead db 14,255,16,18, 16,255,15,14, 18,255,16,15, 14,255,13,14
     db 18,255,19,18, 16,255,15,16, 14,16,18,255, 19,18,16,255
     db 14,16,18,19, 18,255,16,14, 16,18,19,255, 18,16,15,255

prog db 0,5,3,4, 0,5,1,4, 5,3,0,4, 3,4,2,5
     db 1,4,0,5, 3,4,0,0, 5,2,3,0, 1,4,0,4
     db 0,4,5,3, 1,5,3,4, 2,5,3,0, 1,4,0,4
     db 5,3,0,4, 3,4,2,5, 1,4,0,5, 3,4,0,0

arr db 20,21, 22,23, 31,31, 63,63, 29,31, 86,87, 95,95, 59,63
    db 20,22, 21,31, 55,63, 20,23, 95,95, 20,29, 63,63, 95,95

ang dd 0.024543693
amp dd 1024.0

wc WNDCLASS 0,WndProc,0,0,0,0,0,COLOR_WINDOW+1,0,cls
msg MSG
ps PAINTSTRUCT
bmi dd 40,FW,-FH
    dw 1,32
    dd 0,0,0,0,0,0

hdc dd 0
sw dd 800
sh dd 600
t0 dd 0
tms dd 0
loc dd 0
slow dd 0
mode dd 0
buf dd fb
mx dd FW/2
my dd FH/2
rnd dd 1234567
ph1 dd 0
ph2 dd 0
ph3 dd 0
ph4 dd 0
stepv dd 0
posv dd 0
secv dd 0
tmp dd 0
rrx dd 0
rry dd 0
rrw dd 0
rrh dd 0
rrcol dd 0
fx dd 0
fy dd 0

section '.text' code readable executable

start:
 invoke GetModuleHandle,0
 mov [wc.hInstance],eax
 invoke RegisterClass,wc
 invoke GetSystemMetrics,SM_CXSCREEN
 mov [sw],eax
 invoke GetSystemMetrics,SM_CYSCREEN
 mov [sh],eax
 call genlut
 call genwav
 invoke CreateWindowEx,0,cls,ttl,WS_POPUP+WS_VISIBLE,0,0,[sw],[sh],0,0,[wc.hInstance],0
 invoke GetTickCount
 mov [t0],eax
 invoke PlaySound,wavbuf,0,13
.loop:
 invoke GetMessage,msg,0,0,0
 test eax,eax
 jz .bye
 invoke TranslateMessage,msg
 invoke DispatchMessage,msg
 jmp .loop
.bye:
 invoke PlaySound,0,0,0
 invoke ExitProcess,0

proc WndProc uses ebx esi edi, h,u,w,l
 cmp [u],WM_CREATE
 je .cr
 cmp [u],WM_TIMER
 je .ti
 cmp [u],WM_PAINT
 je .pa
 cmp [u],WM_ERASEBKGND
 je .er
 cmp [u],WM_KEYDOWN
 je .key
 cmp [u],WM_LBUTTONDOWN
 je .cl
 cmp [u],WM_DESTROY
 je .de
 invoke DefWindowProc,[h],[u],[w],[l]
 ret
.er:
 mov eax,1
 ret
.key:
 cmp [w],VK_ESCAPE
 je .cl
 xor eax,eax              ; PrintScreen / Win+Shift+S etc. do not exit
 ret
.cr:
 invoke SetTimer,[h],IDT,33,0
 xor eax,eax
 ret
.ti:
 invoke InvalidateRect,[h],0,0
 xor eax,eax
 ret
.cl:
 invoke DestroyWindow,[h]
 xor eax,eax
 ret
.de:
 invoke PostQuitMessage,0
 xor eax,eax
 ret
.pa:
 invoke BeginPaint,[h],ps
 mov [hdc],eax
 invoke GetTickCount
 sub eax,[t0]
 mov [tms],eax
 xor edx,edx
 mov ebx,SC*NSC
 div ebx
 mov eax,edx
 xor edx,edx
 mov ebx,SC
 div ebx
 mov [mode],eax
 mov [loc],edx
 mov eax,[tms]
 shr eax,5
 mov [slow],eax
 ; smooth camera wobble from generated sine LUT
 mov eax,[slow]
 and eax,255
 movsx ebx,word [sintab+eax*2]
 sar ebx,5
 add ebx,FW/2
 mov [mx],ebx
 mov eax,[slow]
 shr eax,1
 add eax,73
 and eax,255
 movsx ebx,word [sintab+eax*2]
 sar ebx,6
 add ebx,FH/2
 mov [my],ebx
 mov dword [buf],fb
 push ebp
 call render
 pop ebp
 mov eax,[loc]
 cmp eax,SC-XF
 jb .show
 ; render next scene and progressively dissolve it in
 mov eax,[mode]
 push eax
 inc eax
 cmp eax,NSC
 jb @f
 xor eax,eax
@@:
 mov [mode],eax
 mov dword [buf],fb2
 push ebp
 call render
 pop ebp
 pop eax
 mov [mode],eax
 mov eax,[loc]
 sub eax,SC-XF
 imul eax,255
 xor edx,edx
 mov ebx,XF
 div ebx
 mov ebx,eax
 call dissolve
.show:
 invoke StretchDIBits,[hdc],0,0,[sw],[sh],0,0,FW,FH,fb,bmi,0,0CC0020h
 invoke EndPaint,[h],ps
 xor eax,eax
 ret
endp

genlut:
 finit
 xor ecx,ecx
.l:
 mov [tmp],ecx
 fild dword [tmp]
 fmul dword [ang]
 fsin
 fmul dword [amp]
 fistp word [sintab+ecx*2]
 inc ecx
 cmp ecx,256
 jb .l
 ret

genwav:
 mov dword [wavbuf],46464952h
 mov dword [wavbuf+4],36+SN*2
 mov dword [wavbuf+8],45564157h
 mov dword [wavbuf+12],20746D66h
 mov dword [wavbuf+16],16
 mov word [wavbuf+20],1
 mov word [wavbuf+22],1
 mov dword [wavbuf+24],SR
 mov dword [wavbuf+28],SR*2
 mov word [wavbuf+32],2
 mov word [wavbuf+34],16
 mov dword [wavbuf+36],61746164h
 mov dword [wavbuf+40],SN*2
 mov edi,wavbuf+44
 xor ecx,ecx
 mov [ph1],ecx
 mov [ph2],ecx
 mov [ph3],ecx
 mov [ph4],ecx
.g:
 mov eax,ecx
 xor edx,edx
 mov ebx,PT
 div ebx
 mov [stepv],eax
 mov [posv],edx
 mov esi,eax
 shr eax,5
 mov [secv],eax
 movzx eax,byte [arr+eax]
 mov [tmp],eax

 ; One real chord root per bar.  All interval arithmetic is diatonic.
 mov ebx,esi
 shr ebx,4
 movzx ebx,byte [prog+ebx]
 mov [rrx],ebx

 ; Bass is root-based; full blocks use the fifth on beat three for movement.
 mov edx,ebx
 test dword [tmp],8
 jz .br
 mov eax,[stepv]
 shr eax,2
 and eax,3
 cmp eax,2
 jne .br
 add edx,4
.br:
 movzx eax,word [nt+edx*2]
 add [ph2],eax

 ; Upper chord voices are the actual diatonic third and fifth, one octave up.
 mov ebx,[rrx]
 add ebx,9
 movzx eax,word [nt+ebx*2]
 add [ph3],eax
 mov ebx,[rrx]
 add ebx,11
 movzx eax,word [nt+ebx*2]
 add [ph4],eax

 ; Eighth-note melody event, motif selected by arrangement bits 5..6.
 mov ebx,[stepv]
 shr ebx,1
 and ebx,15
 mov eax,[tmp]
 shr eax,5
 and eax,3
 shl eax,4
 add ebx,eax
 movzx edx,byte [lead+ebx]
 mov [rry],edx
 cmp edx,255
 jne .ln
 mov edx,14                 ; keep oscillator phase alive during a rest
.ln:
 add edx,[rrx]
 movzx eax,word [nt+edx*2]
 add [ph1],eax

 xor ebp,ebp

 ; Bass is now a decaying note on every beat instead of a continuous drone.
 test dword [tmp],16
 jz .nb
 mov eax,[stepv]
 and eax,3
 imul eax,PT
 add eax,[posv]
 mov ebx,PT*3
 sub ebx,eax
 jle .nb
 mov eax,[ph2]
 shr eax,8
 and eax,255
 call tri
 imul eax,ebx
 sar eax,6
 add ebp,eax
.nb:

 ; Lead: explicit rests plus an eighth-note decay envelope make a phrase.
 test dword [tmp],2
 jz .nl
 cmp dword [rry],255
 je .nl
 mov eax,[stepv]
 and eax,1
 imul eax,PT
 add eax,[posv]
 mov ebx,PT*2
 sub ebx,eax
 jle .nl
 mov eax,[ph1]
 shr eax,8
 and eax,255
 call tri
 imul eax,ebx
 sar eax,5
 add ebp,eax
.nl:

 ; Quiet chord bed: third + fifth.  The pulsed bass supplies the chord root.
 test dword [tmp],4
 jz .np
 mov eax,[ph3]
 shr eax,8
 and eax,255
 call tri
 imul eax,14
 add ebp,eax
 mov eax,[ph4]
 shr eax,8
 and eax,255
 call tri
 imul eax,10
 add ebp,eax
.np:

 ; Drums: half-time/two-kick groove in light blocks, four-on-floor when full.
 test dword [tmp],1
 jz .nd
 mov eax,[stepv]
 and eax,3
 jnz .nk
 test dword [tmp],8
 jnz .kick
 mov eax,[stepv]
 and eax,7
 jnz .nk
.kick:
 mov eax,[posv]
 cmp eax,520
 ja .nk
 mov ebx,520
 sub ebx,eax
 test dword [posv],128
 jz @f
 neg ebx
@@:
 imul ebx,21
 add ebp,ebx
.nk:
 ; snare on beats 2 and 4
 mov eax,[stepv]
 and eax,7
 cmp eax,4
 jne .ns
 mov ebx,[posv]
 cmp ebx,520
 ja .ns
 mov eax,[rnd]
 imul eax,214013
 add eax,2531011
 mov [rnd],eax
 shr eax,16
 and eax,1023
 sub eax,512
 mov edx,520
 sub edx,ebx
 imul eax,edx
 sar eax,6
 add ebp,eax
.ns:
 ; off-beat hats only in full sections
 test dword [tmp],8
 jz .nd
 mov eax,[stepv]
 and eax,3
 cmp eax,2
 jne .nd
 mov ebx,[posv]
 cmp ebx,120
 ja .nd
 mov eax,[rnd]
 imul eax,214013
 add eax,2531011
 mov [rnd],eax
 shr eax,17
 and eax,511
 sub eax,256
 mov edx,120
 sub edx,ebx
 imul eax,edx
 sar eax,7
 add ebp,eax
.nd:

 ; Two tempo-related echoes give the melody a tail without another synth voice.
 test dword [tmp],2
 jz .ne
 cmp ecx,PT*3
 jb .ne
 movsx eax,word [edi-PT*6]
 sar eax,3
 add ebp,eax
 cmp ecx,PT*6
 jb .ne
 movsx eax,word [edi-PT*12]
 sar eax,4
 add ebp,eax
.ne:
 ; click-free loop edge
 cmp ecx,1024
 jae .fo
 imul ebp,ecx
 sar ebp,10
.fo:
 mov eax,SN
 sub eax,ecx
 cmp eax,1024
 jae .clip
 imul ebp,eax
 sar ebp,10
.clip:
 cmp ebp,30000
 jle .c1
 mov ebp,30000
.c1:
 cmp ebp,-30000
 jge .c2
 mov ebp,-30000
.c2:
 mov eax,ebp
 stosw
 inc ecx
 cmp ecx,SN
 jl .g
 ret

; AL-ish triangle helper. in EAX 0..255 -> -64..63
tri:
 cmp eax,128
 jb .a
 mov ebx,255
 sub ebx,eax
 mov eax,ebx
.a:
 sub eax,64
 ret

; -----------------------------------------------------------------------------
; rendering core

render:
 mov eax,[mode]
 test eax,eax
 jz nebula
 dec eax
 jz orbit
 dec eax
 jz warp
 dec eax
 jz city
 dec eax
 jz tunnel
 dec eax
 jz fluid
 dec eax
 jz helix
 dec eax
 jz chaos
 dec eax
 jz galaxy
 dec eax
 jz torus
 dec eax
 jz ribbon
 dec eax
 jz orbit
 dec eax
 jz nebula
 dec eax
 jz galaxy
 dec eax
 jz torus
 jmp warp

dark:
 mov edi,[buf]
 mov ecx,FW*FH
 mov eax,00060b16h
 rep stosd
 ret

grad:
 mov edi,[buf]
 xor ebx,ebx
.y:
 xor ecx,ecx
.x:
 mov eax,ebx
 shr eax,1
 shl eax,16
 mov edx,ebx
 shl edx,8
 or eax,edx
 mov edx,ecx
 add edx,[slow]
 shr edx,3
 and edx,63
 or eax,edx
 stosd
 inc ecx
 cmp ecx,FW
 jl .x
 inc ebx
 cmp ebx,FH
 jl .y
 ret

; EAX=x EBX=y EDX=color
putp:
 test eax,eax
 js .r
 cmp eax,FW
 jae .r
 test ebx,ebx
 js .r
 cmp ebx,FH
 jae .r
 push edi
 mov edi,ebx
 imul edi,FW
 add edi,eax
 shl edi,2
 add edi,[buf]
 mov [edi],edx
 pop edi
.r:
 ret

; rectangle using globals rrx/rry/rrw/rrh/rrcol
boxfb:
 mov ebx,[rry]
.by:
 mov eax,[rrx]
.bx:
 mov edx,[rrcol]
 call putp
 inc eax
 cmp eax,[rrw]
 jl .bx
 inc ebx
 cmp ebx,[rrh]
 jl .by
 ret

; compact palette from EAX seed -> EDX RGB
col:
 push ebx
 mov edx,eax
 imul edx,11
 add edx,[slow]
 and edx,255
 shl edx,16
 mov ebx,eax
 imul ebx,5
 sub ebx,[slow]
 and ebx,255
 shl ebx,8
 or edx,ebx
 mov ebx,eax
 imul ebx,3
 xor ebx,[slow]
 and ebx,255
 or edx,ebx
 pop ebx
 ret

; deterministic spatial dissolve from fb2 over fb
dissolve:
 mov esi,fb
 mov edi,fb2
 mov ecx,FW*FH
.d:
 mov eax,ecx
 imul eax,1103515245
 shr eax,24
 cmp eax,ebx
 ja .k
 mov eax,[edi]
 mov [esi],eax
.k:
 add esi,4
 add edi,4
 dec ecx
 jnz .d
 ret

; 0: smooth sine plasma / nebula
nebula:
 mov edi,[buf]
 xor ebx,ebx
.y:
 xor ecx,ecx
.x:
 mov eax,ecx
 lea eax,[eax*2+eax]
 add eax,[slow]
 and eax,255
 movsx edx,word [sintab+eax*2]
 mov eax,ebx
 lea eax,[eax*4+eax]
 sub eax,[slow]
 and eax,255
 movsx esi,word [sintab+eax*2]
 add edx,esi
 mov eax,ecx
 add eax,ebx
 shl eax,1
 mov esi,[slow]
 lea esi,[esi*2+esi]
 add eax,esi
 and eax,255
 movsx eax,word [sintab+eax*2]
 add eax,edx
 sar eax,4
 add eax,128
 mov edx,eax
 and edx,255
 mov eax,edx
 shl eax,16
 mov esi,edx
 shl esi,1
 and esi,255
 shl esi,8
 or eax,esi
 mov esi,edx
 shr esi,1
 xor esi,[slow]
 and esi,255
 or eax,esi
 stosd
 inc ecx
 cmp ecx,FW
 jl .x
 inc ebx
 cmp ebx,FH
 jl .y
 ret

; 1: star warp with depth-driven perspective
warp:
 call dark
 mov ecx,520
 cmp dword [mode],NSC-1
 jne @f
 mov ecx,780                 ; denser final warp
@@:
.s:
 push ecx
 mov eax,ecx
 imul eax,37
 mov edx,[slow]
 lea edx,[edx*4+edx]
 cmp dword [mode],NSC-1
 jne @f
 add edx,[slow]              ; finale travels faster
@@:
 sub eax,edx
 and eax,511
 add eax,18
 mov edi,eax
 mov eax,ecx
 imul eax,97
 and eax,511
 sub eax,256
 imul eax,190
 cdq
 idiv edi
 add eax,[mx]
 mov esi,eax
 mov eax,ecx
 imul eax,53
 and eax,255
 sub eax,128
 imul eax,150
 cdq
 idiv edi
 add eax,[my]
 mov ebx,eax
 mov eax,540
 sub eax,edi
 call col
 mov eax,esi
 call putp
 inc eax
 call putp
 inc ebx
 call putp
 pop ecx
 dec ecx
 jnz .s
 ret

; 2: radial tunnel with moving center and sine-banded walls
tunnel:
 mov edi,[buf]
 xor ebx,ebx
.y:
 xor ecx,ecx
.x:
 mov eax,ecx
 sub eax,[mx]
 mov esi,eax
 imul eax,eax
 mov edx,ebx
 sub edx,[my]
 mov ebp,edx
 imul edx,edx
 add eax,edx
 shr eax,7
 add eax,[slow]
 and eax,255
 movsx edx,word [sintab+eax*2]
 sar edx,3
 mov eax,esi
 xor eax,ebp
 sar eax,2
 add eax,[slow]
 and eax,63
 xor edx,eax
 mov eax,edx
 add eax,128
 call col
 mov eax,edx
 stosd
 inc ecx
 cmp ecx,FW
 jl .x
 inc ebx
 cmp ebx,FH
 jl .y
 ret

; 3: neon city / road
city:
 call grad
 mov ecx,42
.b:
 push ecx
 mov eax,ecx
 imul eax,43
 mov ebx,[slow]
 shl ebx,2
 sub eax,ebx
 and eax,511
 add eax,40
 mov edi,eax
 mov eax,ecx
 imul eax,67
 and eax,511
 sub eax,256
 imul eax,140
 cdq
 idiv edi
 add eax,FW/2
 mov [rrx],eax
 add eax,10
 mov [rrw],eax
 mov eax,14000
 cdq
 idiv edi
 mov ebx,FH
 sub ebx,eax
 mov [rry],ebx
 mov [rrh],FH
 mov eax,ecx
 imul eax,29
 call col
 mov [rrcol],edx
 call boxfb
 pop ecx
 dec ecx
 jnz .b
 ; road grid
 mov ebx,FH/2+8
.ry:
 xor ecx,ecx
.rx:
 mov eax,ecx
 sub eax,FW/2
 imul eax,ebx
 sar eax,4
 add eax,[slow]
 and eax,31
 cmp eax,2
 jb .line
 mov eax,ebx
 add eax,[slow]
 and eax,15
 cmp eax,2
 jae .skip
.line:
 mov eax,ecx
 mov edx,00ff58d8h
 call putp
.skip:
 inc ecx
 cmp ecx,FW
 jl .rx
 inc ebx
 cmp ebx,FH
 jl .ry
 ret

; 4: liquid interference / pseudo-metaballs
fluid:
 mov edi,[buf]
 ; Two slowly moving circular waves + one planar wave.  ADD, not XOR, keeps
 ; the field continuous; feedback with the previous frame provides afterglow.
 mov eax,[slow]
 and eax,255
 movsx eax,word [sintab+eax*2]
 sar eax,4
 add eax,FW/3
 mov [fx],eax
 mov eax,[slow]
 add eax,83
 and eax,255
 movsx eax,word [sintab+eax*2]
 sar eax,5
 add eax,FH/2
 mov [fy],eax
 xor ebx,ebx
.y:
 xor ecx,ecx
.x:
 mov eax,ecx
 sub eax,[fx]
 imul eax,eax
 mov edx,ebx
 sub edx,[fy]
 imul edx,edx
 add eax,edx
 shr eax,9
 mov edx,ecx
 sub edx,FW*2/3
 imul edx,edx
 mov ebp,ebx
 sub ebp,FH/3
 imul ebp,ebp
 add edx,ebp
 shr edx,10
 add eax,edx
 mov edx,ecx
 shl edx,1
 add edx,ebx
 sub edx,[slow]
 and edx,255
 movsx edx,word [sintab+edx*2]
 sar edx,6
 add eax,edx
 add eax,[slow]
 and eax,255
 movsx eax,word [sintab+eax*2]
 sar eax,3
 add eax,128
 ; restrained violet/cyan palette instead of independent rainbow channels
 mov edx,eax
 and edx,255
 mov esi,edx
 shr esi,1
 add esi,40
 and esi,255
 shl esi,8
 mov eax,edx
 shl eax,16
 or eax,esi
 mov esi,255
 sub esi,edx
 shr esi,1
 or eax,esi
 ; temporal 75/25 feedback: smooth motion and a cheap blur-like persistence
 mov edx,[edi]
 and edx,00fefefeh
 shr edx,1
 mov esi,eax
 and esi,00fefefeh
 shr esi,1
 add esi,edx
 mov eax,[edi]
 and eax,00fefefeh
 shr eax,1
 and esi,00fefefeh
 shr esi,1
 add eax,esi
 stosd
 inc ecx
 cmp ecx,FW
 jl .x
 inc ebx
 cmp ebx,FH
 jl .y
 ret

; 6: perspective double helix / data strand
helix:
 call dark
 mov ecx,420
.h:
 push ecx
 mov eax,ecx
 imul eax,5
 add eax,[slow]
 and eax,255
 mov esi,eax                  ; angle
 ; x axis walks across the screen while z breathes with cosine
 mov eax,ecx
 and eax,255
 sub eax,128
 mov [fx],eax
 mov eax,esi
 movsx ebx,word [sintab+eax*2]
 imul ebx,46
 sar ebx,10                   ; y
 add eax,64
 and eax,255
 movsx edi,word [sintab+eax*2]
 imul edi,38
 sar edi,10
 add edi,170                  ; z
 mov eax,[fx]
 imul eax,250
 cdq
 idiv edi
 add eax,FW/2
 mov [rrx],eax
 mov eax,ebx
 imul eax,250
 cdq
 idiv edi
 add eax,FH/2
 mov ebx,eax
 mov eax,ecx
 add eax,[slow]
 call col
 mov eax,[rrx]
 call putp
 ; opposite strand, mirrored in Y and with a different color seed
 pop ecx
 push ecx
 ; second point uses angle+128 => -y, same x/z approximation
 mov eax,ecx
 imul eax,5
 add eax,[slow]
 and eax,255
 movsx eax,word [sintab+eax*2]
 imul eax,-46
 sar eax,10
 imul eax,250
 cdq
 idiv edi
 add eax,FH/2
 mov ebx,eax
 mov eax,[rrx]
 mov edx,00ff60c8h
 call putp
 pop ecx
 dec ecx
 jnz .h
 ret

; 8: procedural spiral galaxy; radius and angle share the same LUT
galaxy:
 call dark
 mov ecx,900
.gp:
 push ecx
 mov eax,ecx
 and eax,255
 mov edi,eax                  ; radius
 mov eax,ecx
 imul eax,11
 mov edx,ecx
 shr edx,2
 add eax,edx
 add eax,[slow]
 and eax,255
 mov esi,eax
 movsx eax,word [sintab+esi*2]
 imul eax,edi
 sar eax,10
 add eax,FW/2
 mov [rrx],eax
 mov eax,esi
 add eax,64
 and eax,255
 movsx eax,word [sintab+eax*2]
 imul eax,edi
 sar eax,11
 add eax,FH/2
 mov ebx,eax
 mov eax,ecx
 add eax,[slow]
 call col
 mov eax,[rrx]
 call putp
 inc eax
 call putp
 pop ecx
 dec ecx
 jnz .gp
 ret

; 10: three soft sine ribbons / oscilloscope sculpture
ribbon:
 call dark
 mov ecx,1536
.r:
 push ecx
 mov eax,ecx
 and eax,511
 cmp eax,FW
 jae .skip
 mov esi,eax                 ; screen x / phase source
 mov edx,ecx
 shr edx,9                   ; one of three bands
 imul edx,53
 mov eax,esi
 add eax,edx
 add eax,[slow]
 and eax,255
 movsx ebx,word [sintab+eax*2]
 sar ebx,5
 mov eax,esi
 shl eax,1
 sub eax,[slow]
 add eax,edx
 and eax,255
 movsx eax,word [sintab+eax*2]
 sar eax,6
 add ebx,eax
 add ebx,FH/2
 mov eax,edx
 shl eax,2
 add eax,esi
 add eax,[slow]
 call col
 mov eax,esi
 call putp
 inc ebx
 call putp
.skip:
 pop ecx
 dec ecx
 jnz .r
 ret

; 5: evolving strange attractor / particle bloom
chaos:
 call dark
 mov dword [fx],3
 mov dword [fy],7
 mov ecx,2600
.p:
 push ecx
 mov eax,[fx]
 imul eax,73
 mov ebx,[fy]
 imul ebx,37
 add eax,ebx
 add eax,ecx
 add eax,[slow]
 and eax,1023
 sub eax,512
 mov [fx],eax
 mov eax,[fy]
 imul eax,61
 mov ebx,[fx]
 imul ebx,17
 sub eax,ebx
 add eax,ecx
 and eax,511
 sub eax,256
 mov [fy],eax
 mov eax,[fx]
 sar eax,1
 add eax,FW/2
 mov ebx,[fy]
 sar ebx,1
 add ebx,FH/2
 mov edx,ecx
 shl edx,3
 call col
 call putp
 inc eax
 call putp
 inc ebx
 call putp
 pop ecx
 dec ecx
 jnz .p
 ret

; 6: shaded planet + ring + stars
orbit:
 call dark
 mov eax,FW/2
 cmp dword [mode],11
 jne @f
 add eax,72                  ; second orbit pass becomes an off-axis eclipse
@@:
 mov [fx],eax
 ; stars first
 mov ecx,130
.st:
 push ecx
 mov eax,ecx
 imul eax,101
 add eax,[slow]
 and eax,511
 mov esi,eax
 mov ebx,ecx
 imul ebx,59
 and ebx,255
 mov eax,ecx
 shl eax,3
 call col
 mov eax,esi
 call putp
 pop ecx
 dec ecx
 jnz .st
 mov edi,[buf]
 xor ebx,ebx
.y:
 xor ecx,ecx
.x:
 mov eax,ecx
 sub eax,[fx]
 mov esi,eax
 imul eax,eax
 mov edx,ebx
 sub edx,FH/2
 mov ebp,edx
 imul edx,edx
 add eax,edx
 cmp eax,15500
 ja .ring
 ; sphere shading: restrained blue/green gas bands
 mov eax,esi
 add eax,[slow]
 sar eax,3
 and eax,31
 mov edx,ebp
 add edx,128
 shr edx,4
 and edx,15
 add eax,edx
 add eax,48
 mov edx,eax
 shl eax,1
 and eax,255
 mov esi,edx
 shl esi,8
 or eax,esi
 shr edx,1
 shl edx,16
 or eax,edx
 jmp .put
.ring:
 ; flattened ring around planet
 mov eax,ebp
 imul eax,eax
 shl eax,2
 mov edx,esi
 imul edx,edx
 add eax,edx
 cmp eax,25000
 ja .space
 cmp eax,18500
 jb .space
 mov eax,00d8a050h
 cmp dword [mode],11
 jne .put
 xor eax,009070a0h            ; copper/violet second orbit
 jmp .put
.space:
 mov eax,[edi]
.put:
 stosd
 inc ecx
 cmp ecx,FW
 jl .x
 inc ebx
 cmp ebx,FH
 jl .y
 ret

; 7: explicit 3D torus point cloud, rotated and perspective projected
torus:
 call dark
 mov ecx,980
.p:
 push ecx
 mov eax,ecx
 imul eax,7
 add eax,[slow]
 and eax,255
 mov esi,eax                 ; u
 mov eax,ecx
 imul eax,19
 mov edx,[slow]
 shl edx,1
 add eax,edx
 and eax,255
 mov ebp,eax                 ; v
 ; radius = 72 + 26*cos(v)
 mov eax,ebp
 add eax,64
 and eax,255
 movsx eax,word [sintab+eax*2]
 imul eax,26
 sar eax,10
 add eax,72
 mov edi,eax                 ; radius
 ; x = radius*cos(u)
 mov eax,esi
 add eax,64
 and eax,255
 movsx eax,word [sintab+eax*2]
 imul eax,edi
 sar eax,10
 mov [fx],eax
 ; y = radius*sin(u)
 mov eax,esi
 movsx eax,word [sintab+eax*2]
 imul eax,edi
 sar eax,10
 mov [fy],eax
 ; z = 180 + 26*sin(v)
 mov eax,ebp
 movsx eax,word [sintab+eax*2]
 imul eax,26
 sar eax,10
 add eax,180
 mov edi,eax
 ; rotate around Y using time angle
 mov eax,[fx]
 mov [rrx],eax
 mov eax,[slow]
 and eax,255
 movsx esi,word [sintab+eax*2]       ; sin t
 add eax,64
 and eax,255
 movsx ebp,word [sintab+eax*2]       ; cos t
 mov eax,[fx]
 imul eax,ebp
 mov edx,edi
 sub edx,180
 imul edx,esi
 add eax,edx
 sar eax,10
 mov [fx],eax
 mov eax,edi
 sub eax,180
 imul eax,ebp
 mov edx,[rrx]
 imul edx,esi
 sub eax,edx
 sar eax,10
 add eax,180
 mov edi,eax
 ; perspective project
 mov eax,[fx]
 imul eax,220
 cdq
 idiv edi
 add eax,FW/2
 mov esi,eax
 mov eax,[fy]
 imul eax,220
 cdq
 idiv edi
 add eax,FH/2
 mov ebx,eax
 mov eax,edi
 add eax,ecx
 call col
 mov eax,esi
 call putp
 inc eax
 call putp
 inc ebx
 call putp
 dec eax
 call putp
 pop ecx
 dec ecx
 jnz .p
 ret

; Keep the import directory in a real import section.
; Marking the complete code section as 'import' makes the PE loader treat
; machine code as IMAGE_IMPORT_DESCRIPTOR data and can fail with 0xC0000005.
section '.idata' import data readable writeable
library kernel,'KERNEL32.DLL',user,'USER32.DLL',gdi,'GDI32.DLL',winmm,'WINMM.DLL'
import kernel,GetModuleHandle,'GetModuleHandleA',ExitProcess,'ExitProcess',GetTickCount,'GetTickCount'
import user,RegisterClass,'RegisterClassA',CreateWindowEx,'CreateWindowExA',DefWindowProc,'DefWindowProcA',GetMessage,'GetMessageA',TranslateMessage,'TranslateMessage',DispatchMessage,'DispatchMessageA',BeginPaint,'BeginPaint',EndPaint,'EndPaint',PostQuitMessage,'PostQuitMessage',DestroyWindow,'DestroyWindow',SetTimer,'SetTimer',InvalidateRect,'InvalidateRect',GetSystemMetrics,'GetSystemMetrics'
import gdi,StretchDIBits,'StretchDIBits'
import winmm,PlaySound,'PlaySoundA'

; Runtime-generated storage. Keeping it in .bss costs virtual memory only.
section '.bss' readable writeable
sintab rw 256
wavbuf rb 44+SN*2
fb rb FW*FH*4
fb2 rb FW*FH*4

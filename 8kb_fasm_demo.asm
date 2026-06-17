format PE GUI 4.0
entry start
include '8kb_fasm_inc.inc'

FW=640
FH=360
IDT=1
SC=6200
SR=11025
SN=352800
PT=1378

section '.data' data readable writeable
 cls db 'd8kfb',0
 ttl db '8KB FASM v17 runtime music demo',0
 font db 'Arial',0
 m0 db 'LOL',0
 m1 db 'AI',0
 m2 db '404',0
 m3 db '???',0
 m4 db 'XD',0
 m5 db '<3',0
 m6 db 'WOW',0
 m7 db '8K',0
 mt dd m0,m1,m2,m3,m4,m5,m6,m7
 ml dd 3,2,3,3,2,2,3,2
 wc WNDCLASS 0,WndProc,0,0,0,0,0,COLOR_WINDOW+1,0,cls
 msg MSG
 ps PAINTSTRUCT
 hwnd dd 0
 hdc dd 0
 hf dd 0
 inst dd 0
 sw dd 800
 sh dd 600
 t0 dd 0
 tms dd 0
 loc dd 0
 slow dd 0
 mode dd 0
 mx dd FW/2
 my dd FH/2
 pxv dd 0
 pyv dd 0
 cval dd 0
 rrx dd 0
 rry dd 0
 rrw dd 0
 rrh dd 0
 rrcol dd 0
 fx dd 0
 fy dd 0
 ph1 dd 0
 ph2 dd 0
 ph3 dd 0
 ph4 dd 0
 rnd dd 1234567
 posv dd 0
 secv dd 0
 stepv dd 0
ltab dw 1556,1746,1960,2331,2616,2331,1960,1746,1556,1960,2331,3111,2616,2331,1746,1960,1746,1960,2331,2616,3111,2616,2331,1960,1556,1746,1960,2331,3492,3111,2616,2331
btab dw 389,389,490,389,583,490,436,389,389,583,490,436,389,490,583,778
 bmi dd 40,FW,-FH
     dw 1,32
     dd 0,0,0,0,0,0

section '.bss' readable writeable
 wavbuf rb 44+SN*2
 fb rb FW*FH*4

section '.code' code readable executable
start:
 invoke GetModuleHandle,0
 mov [inst],eax
 mov [wc.hInstance],eax
 invoke LoadCursor,0,IDC_ARROW
 mov [wc.hCursor],eax
 invoke RegisterClass,wc
 invoke GetSystemMetrics,SM_CXSCREEN
 mov [sw],eax
 invoke GetSystemMetrics,SM_CYSCREEN
 mov [sh],eax
 invoke CreateWindowEx,0,cls,ttl,WS_POPUP+WS_VISIBLE,0,0,[sw],[sh],0,0,[inst],0
 mov [hwnd],eax
 invoke ShowWindow,eax,SW_SHOW
 invoke UpdateWindow,eax
 call genwav
 invoke PlaySound,wavbuf,0,13
mloop:
 invoke GetMessage,msg,0,0,0
 cmp eax,0
 je bye
 invoke TranslateMessage,msg
 invoke DispatchMessage,msg
 jmp mloop
bye:
 invoke PlaySound,0,0,0
 invoke ExitProcess,0

proc WndProc h,u,w,l
 cmp [u],WM_CREATE
 je .cr
 cmp [u],WM_TIMER
 je .ti
 cmp [u],WM_PAINT
 je .pa
 cmp [u],WM_ERASEBKGND
 je .er
 cmp [u],WM_KEYDOWN
 je .cl
 cmp [u],WM_LBUTTONDOWN
 je .cl
 cmp [u],WM_DESTROY
 je .de
 invoke DefWindowProc,[h],[u],[w],[l]
 ret
.er:
 mov eax,1
 ret
.cr:
 invoke GetTickCount
 mov [t0],eax
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
 mov ebx,SC
 div ebx
 mov [loc],edx
 and eax,7
 mov [mode],eax
 mov eax,[loc]
 shr eax,6
 mov [slow],eax
 mov eax,FW/2
 mov ebx,[loc]
 shr ebx,7
 and ebx,63
 sub ebx,31
 add eax,ebx
 mov [mx],eax
 mov eax,FH/2
 mov ebx,[loc]
 shr ebx,8
 and ebx,31
 sub ebx,15
 add eax,ebx
 mov [my],eax
 call render
 invoke SetStretchBltMode,[hdc],4
 invoke StretchDIBits,[hdc],0,0,[sw],[sh],0,0,FW,FH,fb,bmi,0,0CC0020h
 call textm
 invoke EndPaint,[h],ps
 xor eax,eax
 ret
endp


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
 mov dword [ph1],0
 mov dword [ph2],0
 mov dword [ph3],0
 mov dword [ph4],0
.gw:
 mov eax,ecx
 xor edx,edx
 mov ebx,PT
 div ebx
 mov [stepv],eax
 mov [posv],edx
 mov esi,eax
 and esi,31
 mov ebx,eax
 shr ebx,5
 and ebx,7
 mov [secv],ebx
 mov ebx,[secv]
 imul ebx,3
 add ebx,esi
 and ebx,31
 movzx eax,word [ltab+ebx*2]
 add [ph1],eax
 mov ebx,esi
 shr ebx,2
 add ebx,[secv]
 and ebx,15
 movzx eax,word [btab+ebx*2]
 add [ph2],eax
 mov ebx,[secv]
 imul ebx,5
 add ebx,esi
 add ebx,8
 and ebx,31
 movzx eax,word [ltab+ebx*2]
 shr eax,1
 add [ph3],eax
 movzx eax,word [ltab+ebx*2]
 shr eax,2
 add [ph4],eax
 xor ebp,ebp
 mov eax,[ph2]
 shr eax,8
 and eax,255
 cmp eax,128
 jb .btri
 mov ebx,255
 sub ebx,eax
 mov eax,ebx
.btri:
 sub eax,64
 imul eax,120
 add ebp,eax
 mov eax,[secv]
 cmp eax,1
 jbe .nolead
 mov eax,[ph1]
 shr eax,8
 and eax,255
 cmp eax,128
 jb .ltri
 mov ebx,255
 sub ebx,eax
 mov eax,ebx
.ltri:
 sub eax,64
 imul eax,70
 add ebp,eax
.nolead:
 mov eax,[secv]
 cmp eax,3
 jb .nopad
 mov eax,[ph3]
 shr eax,8
 and eax,255
 cmp eax,128
 jb .ctri
 mov ebx,255
 sub ebx,eax
 mov eax,ebx
.ctri:
 sub eax,64
 imul eax,36
 add ebp,eax
 mov eax,[ph4]
 shr eax,8
 and eax,255
 cmp eax,128
 jb .ctri2
 mov ebx,255
 sub ebx,eax
 mov eax,ebx
.ctri2:
 sub eax,64
 imul eax,28
 add ebp,eax
.nopad:
 mov eax,[stepv]
 and eax,3
 cmp eax,0
 jne .nokick
 mov eax,[posv]
 cmp eax,900
 ja .nokick
 mov ebx,900
 sub ebx,eax
 mov eax,ebx
 imul eax,22
 test dword [ph2],8000h
 jz .kp
 neg eax
.kp:
 add ebp,eax
.nokick:
 mov eax,[stepv]
 and eax,15
 cmp eax,8
 jne .nosn
 mov eax,[posv]
 cmp eax,680
 ja .nosn
 mov ebx,680
 sub ebx,eax
 mov eax,[rnd]
 imul eax,214013
 add eax,2531011
 mov [rnd],eax
 shr eax,16
 and eax,1023
 sub eax,512
 imul eax,ebx
 sar eax,5
 add ebp,eax
.nosn:
 mov eax,[stepv]
 and eax,1
 cmp eax,1
 jne .nohh
 mov eax,[posv]
 cmp eax,170
 ja .nohh
 mov ebx,170
 sub ebx,eax
 mov eax,[rnd]
 imul eax,214013
 add eax,2531011
 mov [rnd],eax
 shr eax,16
 and eax,511
 sub eax,256
 imul eax,ebx
 sar eax,6
 add ebp,eax
.nohh:
 cmp ebp,30000
 jle .cl1
 mov ebp,30000
.cl1:
 cmp ebp,-30000
 jge .cl2
 mov ebp,-30000
.cl2:
 mov eax,ebp
 stosw
 inc ecx
 cmp ecx,SN
 jl .gw
 ret

render:
 mov eax,[mode]
 cmp eax,0
 je plasma
 cmp eax,1
 je star
 cmp eax,2
 je tunnel
 cmp eax,3
 je city
 cmp eax,4
 je balls
 cmp eax,5
 je fract
 cmp eax,6
 je planet
 jmp grid

; edx=color from eax seed
col:
 push ebx
 mov edx,eax
 imul edx,13
 add edx,[slow]
 and edx,255
 shl edx,16
 mov ebx,eax
 imul ebx,7
 add ebx,[slow]
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

putp:
 cmp eax,0
 jl .r
 cmp eax,FW
 jge .r
 cmp ebx,0
 jl .r
 cmp ebx,FH
 jge .r
 push ebx
 imul ebx,FW
 add ebx,eax
 mov dword [fb+ebx*4],edx
 pop ebx
.r: ret

boxfb:
 mov eax,[rry]
 mov [pyv],eax
.by:
 mov eax,[pxv]
 mov [rrx],eax
.bx:
 mov eax,[rrx]
 mov ebx,[pyv]
 mov edx,[rrcol]
 call putp
 inc dword [rrx]
 mov eax,[rrx]
 cmp eax,[rrw]
 jl .bx
 inc dword [pyv]
 mov eax,[pyv]
 cmp eax,[rrh]
 jl .by
 ret

dark:
 mov edi,fb
 mov ecx,FW*FH
 mov eax,00101018h
 rep stosd
 ret

grad:
 mov edi,fb
 xor ebx,ebx
.gy:
 xor ecx,ecx
.gx:
 mov eax,ebx
 shl eax,16
 mov edx,ebx
 shl edx,9
 or eax,edx
 mov edx,ecx
 add edx,[slow]
 and edx,255
 or eax,edx
 stosd
 inc ecx
 cmp ecx,FW
 jl .gx
 inc ebx
 cmp ebx,FH
 jl .gy
 ret

plasma:
 mov edi,fb
 xor ebx,ebx
.py:
 xor ecx,ecx
.px:
 mov eax,ecx
 imul eax,3
 mov edx,ebx
 imul edx,5
 xor eax,edx
 mov edx,[slow]
 shl edx,2
 add eax,edx
 mov edx,eax
 and edx,255
 mov eax,edx
 shl eax,16
 mov esi,edx
 imul esi,2
 and esi,255
 shl esi,8
 or eax,esi
 mov esi,ecx
 imul esi,ebx
 shr esi,5
 add esi,edx
 and esi,255
 or eax,esi
 stosd
 inc ecx
 cmp ecx,FW
 jl .px
 inc ebx
 cmp ebx,FH
 jl .py
 ret

star:
 call dark
 mov ecx,340
.sl:
 push ecx
 mov eax,ecx
 imul eax,31
 mov ebx,[slow]
 sub eax,ebx
 and eax,255
 add eax,18
 mov edi,eax
 mov eax,ecx
 imul eax,73
 and eax,511
 sub eax,256
 imul eax,170
 cdq
 idiv edi
 add eax,[mx]
 mov esi,eax
 mov eax,ecx
 imul eax,47
 and eax,255
 sub eax,128
 imul eax,120
 cdq
 idiv edi
 add eax,[my]
 mov ebx,eax
 mov eax,260
 sub eax,edi
 and eax,255
 call col
 mov eax,esi
 call putp
 inc eax
 call putp
 pop ecx
 dec ecx
 jnz .sl
 ret

tunnel:
 mov edi,fb
 xor ebx,ebx
.ty:
 xor ecx,ecx
.tx:
 mov eax,ecx
 sub eax,[mx]
 imul eax,eax
 mov edx,ebx
 sub edx,[my]
 imul edx,edx
 add eax,edx
 shr eax,7
 mov edx,ecx
 add edx,ebx
 add edx,[slow]
 shr edx,3
 xor eax,edx
 call col
 stosd
 inc ecx
 cmp ecx,FW
 jl .tx
 inc ebx
 cmp ebx,FH
 jl .ty
 ret

city:
 call grad
 mov ecx,36
.cy:
 push ecx
 mov eax,ecx
 imul eax,43
 mov ebx,[slow]
 shl ebx,2
 sub eax,ebx
 and eax,511
 add eax,35
 mov edi,eax
 mov eax,ecx
 imul eax,61
 and eax,511
 sub eax,256
 imul eax,120
 cdq
 idiv edi
 add eax,FW/2
 mov [rrx],eax
 mov [pxv],eax
 add eax,11
 mov [rrw],eax
 mov eax,12000
 cdq
 idiv edi
 mov ebx,FH
 sub ebx,eax
 mov [rry],ebx
 mov [rrh],FH
 mov eax,ecx
 imul eax,25
 call col
 mov [rrcol],edx
 call boxfb
 pop ecx
 dec ecx
 jnz .cy
 call road
 ret

road:
 mov ebx,FH/2+6
.ry:
 mov ecx,0
.rx:
 mov eax,ecx
 sub eax,FW/2
 imul eax,ebx
 sar eax,4
 add eax,[slow]
 and eax,31
 cmp eax,2
 jl .line
 mov eax,ebx
 add eax,[slow]
 and eax,15
 cmp eax,2
 jge .skip
.line:
 mov eax,ecx
 mov edx,00ff66ffh
 call putp
.skip:
 inc ecx
 cmp ecx,FW
 jl .rx
 inc ebx
 cmp ebx,FH
 jl .ry
 ret

balls:
 mov edi,fb
 xor ebx,ebx
.by:
 xor ecx,ecx
.bx:
 mov eax,ecx
 sub eax,FW/3
 mov edx,[slow]
 add edx,edx
 add eax,edx
 imul eax,eax
 mov esi,ebx
 sub esi,FH/2
 imul esi,esi
 add eax,esi
 shr eax,8
 mov edx,ecx
 sub edx,FW*2/3
 mov esi,[slow]
 shl esi,1
 sub edx,esi
 imul edx,edx
 add eax,edx
 mov edx,ebx
 sub edx,FH/3
 imul edx,edx
 shr edx,8
 add eax,edx
 xor eax,[slow]
 call col
 stosd
 inc ecx
 cmp ecx,FW
 jl .bx
 inc ebx
 cmp ebx,FH
 jl .by
 ret

fract:
 call dark
 mov dword [fx],1
 mov dword [fy],1
 mov ecx,1700
.fl:
 push ecx
 mov eax,[fx]
 imul eax,73
 mov ebx,[fy]
 imul ebx,37
 add eax,ebx
 add eax,ecx
 add eax,[slow]
 and eax,511
 sub eax,256
 mov [fx],eax
 mov eax,[fy]
 imul eax,61
 mov ebx,[fx]
 imul ebx,17
 sub eax,ebx
 add eax,ecx
 and eax,255
 sub eax,128
 mov [fy],eax
 mov eax,[fx]
 sar eax,1
 add eax,FW/2
 mov ebx,[fy]
 sar ebx,1
 add ebx,FH/2
 mov edx,ecx
 shl edx,4
 call col
 call putp
 pop ecx
 dec ecx
 jnz .fl
 ret

planet:
 call dark
 mov edi,fb
 xor ebx,ebx
.ly:
 xor ecx,ecx
.lx:
 mov eax,ecx
 sub eax,FW/2
 imul eax,eax
 mov edx,ebx
 sub edx,FH/2
 imul edx,edx
 add eax,edx
 cmp eax,15500
 jg .sky
 mov eax,ecx
 add eax,ebx
 add eax,[slow]
 call col
 jmp .put
.sky:
 cmp eax,20500
 jg .space
 mov eax,00ff8844h
 jmp .put
.space:
 mov eax,00040818h
.put:
 stosd
 inc ecx
 cmp ecx,FW
 jl .lx
 inc ebx
 cmp ebx,FH
 jl .ly
 call staro
 ret

staro:
 mov ecx,120
.so:
 push ecx
 mov eax,ecx
 imul eax,97
 add eax,[slow]
 and eax,511
 mov esi,eax
 mov ebx,ecx
 imul ebx,53
 and ebx,179
 mov eax,ecx
 shl eax,3
 call col
 mov eax,esi
 call putp
 pop ecx
 dec ecx
 jnz .so
 ret

grid:
 call grad
 mov ebx,FH/2-6
.gy2:
 xor ecx,ecx
.gx2:
 mov eax,ebx
 sub eax,FH/2-6
 mov edx,ecx
 sub edx,FW/2
 imul edx,eax
 sar edx,4
 add edx,[slow]
 and edx,31
 cmp edx,2
 jl .gl
 mov edx,ebx
 add edx,[slow]
 and edx,15
 cmp edx,2
 jge .gn
.gl:
 mov eax,ecx
 mov edx,00ffff22h
 call putp
.gn:
 inc ecx
 cmp ecx,FW
 jl .gx2
 inc ebx
 cmp ebx,FH
 jl .gy2
 ret

textm:
 invoke SetBkMode,[hdc],TRANSPARENT
 mov eax,[slow]
 shl eax,3
 call col
 invoke SetTextColor,[hdc],edx
 mov eax,[slow]
 shr eax,3
 and eax,7
 mov esi,[mt+eax*4]
 mov edi,[ml+eax*4]
 mov eax,[slow]
 and eax,127
 add eax,80
 invoke CreateFont,eax,0,0,0,900,0,0,0,ANSI_CHARSET,0,0,0,0,font
 mov [hf],eax
 invoke SelectObject,[hdc],eax
 mov eax,[slow]
 imul eax,17
 and eax,1023
 mov ebx,[slow]
 imul ebx,11
 and ebx,511
 invoke TextOut,[hdc],eax,ebx,esi,edi
 invoke DeleteObject,[hf]
 ret

section '.idata' import data readable writeable
 library kernel,'KERNEL32.DLL',user,'USER32.DLL',gdi,'GDI32.DLL',winmm,'WINMM.DLL'
 import kernel,GetModuleHandle,'GetModuleHandleA',ExitProcess,'ExitProcess',GetTickCount,'GetTickCount'
 import user,RegisterClass,'RegisterClassA',CreateWindowEx,'CreateWindowExA',DefWindowProc,'DefWindowProcA',GetMessage,'GetMessageA',TranslateMessage,'TranslateMessage',DispatchMessage,'DispatchMessageA',LoadCursor,'LoadCursorA',ShowWindow,'ShowWindow',UpdateWindow,'UpdateWindow',BeginPaint,'BeginPaint',EndPaint,'EndPaint',PostQuitMessage,'PostQuitMessage',DestroyWindow,'DestroyWindow',SetTimer,'SetTimer',InvalidateRect,'InvalidateRect',GetSystemMetrics,'GetSystemMetrics'
 import gdi,StretchDIBits,'StretchDIBits',SetStretchBltMode,'SetStretchBltMode',TextOut,'TextOutA',SetTextColor,'SetTextColor',SetBkMode,'SetBkMode',CreateFont,'CreateFontA',DeleteObject,'DeleteObject',SelectObject,'SelectObject'
 import winmm,PlaySound,'PlaySoundA'


ASSUME CS:CODES,DS:DATAS,ss:stack

DATAS SEGMENT
    STRIN DB 'Please enter the formula:  $'
    MESG DB 'Do you want to continue? (y/q) $' 
    FLAG1 DW 0             ;判断数字是否输入完毕
    SIGN DW 0              ;符号
	FLAG2 DW 0             ;异常标志位
    NUMBER DW 20 DUP(0)    ;保存输入的数值
    Operator DB 'M'        ;保存的运算符
             DB 10 DUP(0) 
    ERROR DB 0AH,0DH,'YOUR INPUT IS WRONG!$' 
DATAS ENDS

stack  segment	stack 		
		db	256 dup(?)      			
stack  ends

;宏定义，显示STR
DISP MACRO STR
    LEA DX,STR
    MOV AH,9
    INT 21H
ENDM

;宏定义给运算符赋权值	
CHOICE MACRO ASC,HAO,H 
    CMP AL,ASC  
    JNE OTH&HAO 
    MOV CH,H 
    JMP OTH7  
ENDM
		
CODES SEGMENT   

START: 
		MOV AX,DATAS  
		MOV DS,AX  
		MOV AX,STACK
		MOV SS,AX 
		LEA DI,NUMBER  
		LEA SI,Operator  
		
		MOV AX,0   
		MOV BX,0
		MOV CX,0  
		MOV DX,0  
		
START1: 
		DISP STRIN    ;显示STR1
	
;输入处理	
INPUT:  
		MOV AH,1  
		INT 21H        
		CMP AL,'='  
		JE L1                     ; AL = '=',则跳转到L1
		CMP AL,2AH                
		JB FUNCERR                     ; AL < '*',则跳转到ERR
		CMP AL,39H               
		JA  FUNCERR                   ; AL > '9',则跳转到ERR
		CMP AL,2FH                
		JBE L2                   ; '*' <= AL <= '/', 则跳L2
	
	
		                       ;'0' <= AL <= '9', 则执行以下指令，进行数字预处理
		INC WORD PTR FLAG1    ;将数字标志位加1
		SUB AL,30H            ;将ASCII码转16进制
		MOV AH,0 
		XCHG AX,[DI]          ;交换 AX 和 DS:[DI]
    
		MUL BX  
		MOV BX,10  
		XCHG AX,[DI]  
		ADD [DI],AX  
		JMP INPUT           ;数字预处理结束，跳转到INPUT
		
FUNCERR: 	MOV WORD PTR FLAG2,1
		jmp short INPUT
	
;判断配对标志位	
L1: 	CMP WORD PTR FLAG2,1
		JE DISERR
		CMP WORD PTR SIGN,0  
		JE L2  
		JMP BC  
	
;符号响应操作
L2:	
		cmp al,'q'
		je L3
		cmp al,'y'
		je L3
		cmp al,'Q'
		je L3
		cmp al,'q'
		je L3
		cmp al,'+'
		je L3
		cmp al,'-'
		je L3
		cmp al,'*'
		je L3
		cmp al,'/'
		je L3
		cmp al,'='
		je L3
DISERR:	call Crlf
		DISP ERROR        ;非法表达式处理
		call Crlf
		mov ax,4c00h
		int 21h
	
L3:		CMP WORD PTR FLAG1,0  ;判断数值指针是否已经下移一位
		JE L4 
		ADD DI,2  
		MOV WORD PTR FLAG1,0  ;将数字标志位复0
	
L4:	CALL ADVANCE          ;设定优先级
		CMP CH,5              
		JNE L5                
		INC WORD PTR SIGN  
	
L5: 
		CMP CH,1              
		JNE AGAIN  
		DEC WORD PTR SIGN  
	
	
     
AGAIN: 
		CMP BYTE PTR[SI],'M'  ;判断运算符存储区是否为空      
		JE SAVE
		CMP CH,[SI]           ;[SI]的内容为前一个符号或其权值
		JA SAVE  
		CMP BYTE PTR[SI],'('     
		JNE L6
		DEC SI
		JMP INPUT


	
L6: 
		DEC SI  
		MOV CL,[SI]  
		CALL MATCH            ;判断是什么运算符并进行相应的计算
		JMP AGAIN  
	
x:	jmp near ptr OUTPUT
y:	jmp near ptr INPUT    
SAVE: 
		CMP CH,0              ;判断是否是等号
		JE x   
		CMP CH,1  
		JE y             
		INC SI  
		MOV [SI],AL           ;保存符号
		INC SI  
		CMP CH,5              ;判断是否是左括号
		JNE GO_ON  
		MOV CH,2              ;改变(的权值	
	
GO_ON: 
		MOV [SI],CH           ;紧跟着保存符号的权值
		JMP INPUT
      
BC: 	LEA DX,ERROR 
		MOV AH,9  
		INT 21H  
		JMP OUTPUT_END  

;子程序，进行相应的运算
MATCH PROC NEAR          
		PUSH AX  
		XOR AX,AX
		XOR BX,BX
		CMP CL,2AH            ;乘法运算
		JNE MATCH_1
		SUB DI,2
		XCHG BX,[DI]
		SUB DI,2
		XCHG AX,[DI]
		IMUL BX
		MOV [DI],AX
		ADD DI,2
		JMP MATCH_END
MATCH_1:	
		CMP CL,2FH          ;除法运算
		JNE MATCH_2
		SUB DI,2
		XCHG BX,[DI]
		SUB DI,2  
		XCHG AX,[DI]
		CWD
		IDIV BX
		MOV [DI],AX
		ADD DI,2
		JMP MATCH_END
MATCH_2:
		CMP CL,2BH          ;加法运算
		JNE MATCH_3
		SUB DI,2
		XCHG BX,[DI]
		SUB DI,2
		ADD [DI],BX
		ADD DI,2
		JMP MATCH_END
MATCH_3:
		CMP CL,2DH          ;减法运算
		JNE MATCH_END
		SUB DI,2
		XCHG BX,[DI]
		SUB DI,2
		SUB [DI],BX  
		ADD DI,2
MATCH_END:
		POP AX 
		RET
MATCH ENDP

ADVANCE PROC
CHOICE 28H,1,5   
OTH1:CHOICE 29H,2,1 
OTH2:CHOICE 2AH,3,4  ;*
OTH3:CHOICE 2FH,4,4  ;/
OTH4:CHOICE 2BH,5,3  ;+
OTH5:CHOICE 2DH,6,3  ;-
OTH6:CHOICE 3DH,7,0  ;=
OTH7:RET
ADVANCE ENDP



;输出运算结果
OUTPUT:                   
		SUB DI,2
		CMP WORD PTR[DI],0
		JGE OUTPUT_1
		NEG WORD PTR[DI]
		MOV DL,'-'
		MOV AH,2
		INT 21H
OUTPUT_1: 	MOV BX,10000
		MOV CX,5
		MOV SI,0
OUTPUT_2: 	MOV AX,[DI]
		CWD
		DIV BX
		MOV [DI],DX
		CMP AL,0
		JNE OUTPUT_3
		CMP SI,0
		JNE OUTPUT_3
		CMP CX,1
		JE OUTPUT_3
		JMP OUTPUT_4
OUTPUT_3: 	MOV DL,AL
		ADD DL,30H
		MOV AH,2
		INT 21H
		MOV SI,1
OUTPUT_4: 	MOV AX,BX
		MOV DX,0
		MOV BX,10
		DIV BX
		MOV BX,AX
		LOOP OUTPUT_2
    
		CALL Crlf              
		DISP MESG
		MOV AH,1
		INT 21H
		CMP AL,'q'
		JE OUTPUT_END
		CMP AL,'Q'
		JE OUTPUT_END
		MOV WORD PTR[DI+2],0  
		CALL Crlf
		LEA DI,NUMBER  
		LEA SI,Operator
		JMP START1
OUTPUT_END: 
		call Crlf
		MOV AH,4CH
		INT 21H
		
;回车换行子函数	
Crlf proc         
		PUSH AX
		PUSH DX
		MOV AH,2
		MOV DL,0DH   ; CR归位键
		INT 21H      
		MOV AH,2
		MOV DL,0AH   ; LF换行键
		INT 21H      
		POP DX
		POP AX
		RET
Crlf endp

CODES ENDS

END START



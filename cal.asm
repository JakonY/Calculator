
ASSUME CS:CODES,DS:DATAS,SS:STACK


DATAS SEGMENT

	inputReminder		DB 'Please enter the formula:  $'
	continueReminder	DB 'Do you want to continue? (y/q) $'
	numberFinishedFlag	DW 0			;判断数字是否输入完毕
	SIGN DW 0			;符号
	errorFlag			DW 0			;异常标志位
	number				DW 20 DUP(0)	;保存输入的数值
	operator			DB 'M'			;保存的运算符
						DB 10 DUP(0)
	ERROR DB 0AH,0DH,'YOUR INPUT IS WRONG!$'

	; 运算符优先级的表格
	OPCODES		DB '=',0
				DB ')',1
				DB '+',2
				DB '-',2
				DB '*',3
				DB '/',3
				DB '(',4

DATAS ENDS


STACK SEGMENT STACK
		DB	256 DUP(?)
STACK ENDS


; 宏定义, 显示字符串string
DISPLAY MACRO string
    LEA DX,string
    MOV AH,9
    INT 21H
ENDM


CODES SEGMENT

START:
		MOV AX,DATAS
		MOV DS,AX
		MOV AX,STACK
		MOV SS,AX
		LEA DI,number
		LEA SI,operator

		MOV AX,0
		MOV BX,0
		MOV CX,0
		MOV DX,0

START1:
		DISPLAY inputReminder	;显示输入提示

; 输入处理
INPUT:
		MOV AH,1
		INT 21H

		; 若 AL = '=', 则跳转到FLAG_CHECKINH
		CMP AL,'='
		JE FLAG_CHECKINH

		; 若 AL ∈ { '+', '-', '*', '/' }, 则跳转到NUMBER_PROCESSING
		CMP AL,'+'
		JE NUMBER_PROCESSING
		CMP AL,'-'
		JE NUMBER_PROCESSING
		CMP AL,'*'
		JE NUMBER_PROCESSING
		CMP AL,'/'
		JE NUMBER_PROCESSING

		; 若 AL < '0' or AL > '9', 则跳转到 INPUT_ERROR
		CMP AL,'0'
		JB INPUT_ERROR
		CMP AL,'9'
		JA INPUT_ERROR

		; 若 '0' <= AL <= '9', 则执行以下指令
		; 进行数字预处理
		; DS:[DI] = DS:[DI] * 10 + AX
		INC WORD PTR numberFinishedFlag		;将数字标志位加1
		SUB AL,30H		;将输入数字的ASCII码转16进制
		MOV AH,0		;将AH寄存器清零
		XCHG AX,[DI]	;交换AX和DS:[DI]
		MUL BX			;用BX寄存器乘以AX寄存器的值, 并将结果保存在AX中
		MOV BX,10		;将BX寄存器设为10
		XCHG AX,[DI]	;再次将AX寄存器和DS:[DI]指向的内存单元进行交换
		ADD [DI],AX		;将AX寄存器的值加到DS:[DI]指向的内存单元中
		JMP INPUT		;数字预处理结束，跳转到INPUT

; 输入错误处理
INPUT_ERROR:
		MOV WORD PTR errorFlag,1
		JMP SHORT FLAG_CHECKINH

; 判断配对标志位
FLAG_CHECKINH:
		CMP WORD PTR errorFlag,1
		JE ERROR_DISPLAY
		CMP WORD PTR SIGN,0
		JE L2
		JMP BC

; 符号响应操作
L2:
		cmp al,'q'
		je NUMBER_PROCESSING
		cmp al,'y'
		je NUMBER_PROCESSING
		cmp al,'Q'
		je NUMBER_PROCESSING
		cmp al,'q'
		je NUMBER_PROCESSING
		cmp al,'='
		je NUMBER_PROCESSING

ERROR_DISPLAY:
		CALL CRLF
		DISPLAY ERROR			;非法表达式处理
		CALL CRLF
		MOV AX,4C00H
		INT 21H

NUMBER_PROCESSING:
		CMP WORD PTR numberFinishedFlag,0	;判断数值指针是否已经下移一位
		JE OPERATOR_PROCESSING
		ADD DI,2
		MOV WORD PTR numberFinishedFlag,0	;将数字标志位复0

OPERATOR_PROCESSING:
		CALL ADVANCE			;设定优先级
		CMP CH,4
		JNE L5
		INC WORD PTR SIGN

L5:
		CMP CH,1
		JNE AGAIN
		DEC WORD PTR SIGN

AGAIN:
		CMP BYTE PTR[SI],'M'	;判断运算符存储区是否为空
		JE SAVE
		CMP CH,[SI]				;[SI]的内容为前一个符号的优先级
		JA SAVE
		CMP BYTE PTR[SI],'('
		JNE L6
		DEC SI
		JMP INPUT

L6:
		DEC SI
		MOV CL,[SI]
		CALL MATCH		;判断是什么运算符并进行相应的计算
		JMP AGAIN

x:	jmp near ptr OUTPUT
y:	jmp near ptr INPUT
SAVE:
		CMP CH,0		;判断是否是等号
		JE x
		CMP CH,1		;判断是否是右括号
		JE y
		INC SI
		MOV [SI],AL		;保存符号
		INC SI
		CMP CH,4		;判断是否是左括号
		JNE GO_ON
		MOV CH,2		;改变(的权值

GO_ON: 
		MOV [SI],CH		;紧跟着保存符号的权值
		JMP INPUT

BC: 	LEA DX,ERROR
		MOV AH,9
		INT 21H
		JMP OUTPUT_END


; 宏定义, 抽取四个运算前部的共同代码
BEFORE_CALC MACRO
		SUB DI,2
		XCHG BX,[DI]
		SUB DI,2
		XCHG AX,[DI]
ENDM

; 宏定义, 抽取四个运算后部的共同代码
AFTER_CALC MACRO
		MOV [DI],AX
		ADD DI,2
ENDM

; 子程序, 进行相应的运算
MATCH PROC NEAR
		PUSH AX 		;将AX的值压入堆栈 (保护AX寄存器的值
		XOR AX,AX
		XOR BX,BX		;将AX和BX寄存器的值清零

		; 乘法运算
		CMP CL,'*'
		JNE MATCH_DIVISION
		BEFORE_CALC
		IMUL BX
		AFTER_CALC
		JMP MATCH_END

; 除法运算
MATCH_DIVISION:
		CMP CL,'/'
		JNE MATCH_ADDITION
		BEFORE_CALC
		CWD
		IDIV BX
		AFTER_CALC
		JMP MATCH_END

; 加法运算
MATCH_ADDITION:
		CMP CL,'+'
		JNE MATCH_SUBTRACTION
		BEFORE_CALC
		ADD AX,BX
		AFTER_CALC
		JMP MATCH_END

; 减法运算
MATCH_SUBTRACTION:
		CMP CL,'-'
		JNE MATCH_END
		BEFORE_CALC
		SUB AX,BX
		AFTER_CALC

MATCH_END:
		POP AX
		RET

MATCH ENDP


; 子程序, 进行运算符优先级赋值
ADVANCE PROC
	MOV BX,OFFSET OPCODES
	MOV CX,6			;循环次数为表格中的元素个数
LOOP_ADVANCE:
	CMP AL,[BX]			;比较当前输入字符和表格中的字符
	JE END_ADVANCE		;如果匹配，则跳转到 END_ADVANCE 处
	ADD BX,2			;每个表格项占两个字节，移动到下一个
	LOOP LOOP_ADVANCE	;循环比较
	MOV CH,-1			;没有匹配的情况下，将 CH 设为 -1
	RET
END_ADVANCE:
	MOV CH,[BX+1]		;匹配到时，将对应的操作码放入 CH 中
	RET
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
		DISPLAY continueReminder
		MOV AH,1
		INT 21H
		CMP AL,'q'
		JE OUTPUT_END
		CMP AL,'Q'
		JE OUTPUT_END
		MOV WORD PTR[DI+2],0  
		CALL Crlf
		LEA DI,number  
		LEA SI,operator
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



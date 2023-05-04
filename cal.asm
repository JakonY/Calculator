
ASSUME CS:CODES,DS:DATAS,SS:STACK


DATAS SEGMENT
	systemHead			DB '********************* Calculator *********************$'
	inputReminder		DB 'Please enter the formula:  $'
	continueReminder	DB 'Input q/Q to exit or others to continue:  $'
	exitReminder		DB 'Succeed to exit.$'
	numberFinishedFlag	DW 0			;判断数字是否输入完毕
	errorFlag			DW 0			;异常标志位
	number				DB 'M'			;保存输入的数值
						DB 20 DUP(0)
	operator			DB 'M'			;保存的运算符
						DB 10 DUP(0)
	ERROR DB 0AH,0DH,'Invalid fomula inputed!$'

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

; 显示输入提示
START1:
		ADD DI,2
		CALL Crlf
		DISPLAY systemHead
		CALL Crlf
		DISPLAY inputReminder

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

; 判断输入终止
END_CHECKING:
		CMP AL,'q'
		JE NUMBER_PROCESSING
		CMP AL,'Q'
		JE NUMBER_PROCESSING
		CMP AL,'y'
		JE NUMBER_PROCESSING
		CMP AL,'Y'
		JE NUMBER_PROCESSING
		CMP AL,'='
		JE NUMBER_PROCESSING

; 非法表达式处理
ERROR_DISPLAY:
		DISPLAY ERROR
		CALL Crlf
		MOV AX,4C00H
		INT 21H

NUMBER_PROCESSING:
		CMP WORD PTR numberFinishedFlag,0	;判断数值指针是否已经下移一位
		JE OPERATOR_PROCESSING
		ADD DI,2
		MOV WORD PTR numberFinishedFlag,0	;将数字标志位复0

OPERATOR_PROCESSING:
		CALL ADVANCE			;设定优先级

AGAIN:
		CMP BYTE PTR[SI],'M'	;判断运算符存储区是否为空
		JE SAVE
		CMP CH,[SI]				;[SI]的内容为前一个符号的优先级
		JA SAVE
		JMP OPERATION

; 从运算符栈中取出一个运算符, 并进行相应运算
OPERATION:
		DEC SI
		MOV CL,[SI]
		CALL MATCH		;判断是什么运算符并进行相应的计算
		JMP AGAIN

; 保存运算符及其权值
JMP_TO_OUTPUT:
		JMP NEAR PTR OUTPUT
SAVE:
		CMP CH,0		;判断是否是等号
		JE JMP_TO_OUTPUT
		INC SI
		MOV [SI],AL		;保存符号
		INC SI
		MOV [SI],CH		;紧跟着保存符号的权值
		JMP INPUT


; 宏定义, 抽取四个运算前部的共同代码
; 判断判断运算符是否为 matchOperator, 不是则跳转到下一个匹配标签处
; 否则从操作数栈中取出两个操作数, 分别存储在 AX 和 BX
BEFORE_CALC MACRO matchOperator,nextMatch,invalidProcessingLabel
		CMP CL,matchOperator
		JNE nextMatch
		SUB DI,2
		CMP BYTE PTR [DI],'M'
		JE invalidProcessingLabel
		XCHG BX,[DI]
		SUB DI,2
		CMP BYTE PTR [DI],'M'
		JE invalidProcessingLabel
		XCHG AX,[DI]
ENDM

; 宏定义, 抽取四个运算后部的共同代码
; 将运算结果 AX 存回操作数栈中
AFTER_CALC MACRO
		MOV [DI],AX
		ADD DI,2
ENDM

; 子程序, 表达式不合法处理
InvalidProcessing PROC NEAR
		DISPLAY ERROR
		CALL Crlf
		MOV AX,4C00H
		INT 21H
		RET
InvalidProcessing ENDP

; 子程序, 进行相应的运算
MATCH PROC NEAR
MATCH_MULTIPLY:
		PUSH AX 		;将AX的值压入堆栈 (保护AX寄存器的值
		XOR AX,AX
		XOR BX,BX		;将AX和BX寄存器的值清零
		; 乘法运算
		BEFORE_CALC '*' MATCH_DIVISION INVALID_PROCESSING
		IMUL BX
		AFTER_CALC
		JMP MATCH_END
; 除法运算
MATCH_DIVISION:
		BEFORE_CALC '/' MATCH_ADDITION INVALID_PROCESSING
		CWD
		IDIV BX
		AFTER_CALC
		JMP MATCH_END
; 不合法处理
INVALID_PROCESSING:
		CALL InvalidProcessing
		JMP MATCH_END
; 加法运算
MATCH_ADDITION:
		BEFORE_CALC '+' MATCH_SUBTRACTION INVALID_PROCESSING
		ADD AX,BX
		AFTER_CALC
		JMP MATCH_END
; 减法运算
MATCH_SUBTRACTION:
		BEFORE_CALC '-' MATCH_END INVALID_PROCESSING
		SUB AX,BX
		AFTER_CALC
		JMP MATCH_END
; 返回现场
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


; 输出运算结果
OUTPUT:
		; 减去 2 个字节, DI 指向运算结果的最高位
		SUB DI,2
		; 判断是否为负数
		CMP WORD PTR[DI],0
		JGE OUTPUT_1
		; 运算结果为负数时, 将其变成正数, 并输出一个负号
		NEG WORD PTR[DI]
		MOV DL,'-'
		MOV AH,2
		INT 21H
OUTPUT_1:
		MOV BX,10000	; BX 存储除数 10000
		MOV CX,5		; CX 存储循环次数
		MOV SI,0		; SI 存储是否有前导 0
OUTPUT_2:
		MOV AX,[DI]		; 将 AX 设置为当前运算结果
		CWD				; 扩展 AX 的符号位
		DIV BX			; 将 AX 除以 BX, 商存在 AX 中, 余数存在 DX 中
		MOV [DI],DX		; 将余数存储到 DI 所指向的地址中
		; 如果商为 0, 并且前面还没有输出过数字, 则不输出
		CMP AL,0
		JNE OUTPUT_3
		CMP SI,0
		JNE OUTPUT_3
		; 如果已经输出了 1 个数字, 并且还没达到指定循环次数, 则输出一个 0
		CMP CX,1
		JE OUTPUT_3
		JMP OUTPUT_4
OUTPUT_3:
		; 将数字转换为 ASCII 码并输出
		MOV DL,AL
		ADD DL,30H
		MOV AH,2
		INT 21H
		; 标记已经输出过数字
		MOV SI,1
OUTPUT_4:
		; 将 BX 设置为 10000
		MOV AX,BX
		MOV DX,0
		MOV BX,10
		; 将 BX 除以 10, 商存在 BX 中, 余数存在 DX 中
		DIV BX
		; 将商存储到 BX 中, 继续下一次循环
		MOV BX,AX
		LOOP OUTPUT_2
		; 显示提示信息
		CALL Crlf
		DISPLAY continueReminder
		; 等待输入
		MOV AH,1
		INT 21H
		; 如果用户输入 q 或 Q, 则退出
		CMP AL,'q'
		JE OUTPUT_END
		CMP AL,'Q'
		JE OUTPUT_END
		; 将下一个运算结果的最高位设置为 0, 准备进行下一轮计算
		MOV WORD PTR[DI+2],0
		; 重置 DI 和 SI, 准备读入下一个运算符和数字
		CALL Crlf
		LEA DI,number
		LEA SI,operator
		JMP START1
OUTPUT_END:
		; 退出程序
		CALL Crlf
		DISPLAY exitReminder
		CALL Crlf
		MOV AH,4CH
		INT 21H


; 回车换行子程序
Crlf PROC
		PUSH AX
		PUSH DX
		MOV AH,2
		MOV DL,0DH		;CR归位键
		INT 21H
		MOV AH,2
		MOV DL,0AH		;LF换行键
		INT 21H
		POP DX
		POP AX
		RET
Crlf ENDP

CODES ENDS

END START



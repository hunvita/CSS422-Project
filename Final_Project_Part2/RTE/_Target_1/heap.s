		AREA	|.text|, CODE, READONLY, ALIGN=2
		THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; System Call Table FINAL
HEAP_TOP	EQU		0x20001000
HEAP_BOT	EQU		0x20004FE0
MAX_SIZE	EQU		0x00004000		; 16KB = 2^14
MIN_SIZE	EQU		0x00000020		; 32B  = 2^5
	
MCB_TOP		EQU		0x20006800      ; 2^10B = 1K Space
MCB_BOT		EQU		0x20006BFE
MCB_ENT_SZ	EQU		0x00000002		; 2B per entry
MCB_TOTAL	EQU		512				; 2^9 = 512 entries
	
INVALID		EQU		-1				; an invalid id

;
; Each MCB Entry
; FEDCBA9876543210
; 00SSSSSSSSS0000U					S bits are used for Heap size, U=1 Used U=0 Not Used

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Memory Control Block Initialization
; void _kinit( )
; this routine must be called from Reset_Handler in startup_TM4C129.s
; before you invoke main( ) in driver_keil
		EXPORT	_kinit
_kinit
		; you must correctly set the value of each MCB block
		; complete your code
		LDR		R4, =MCB_TOP			; R4 = 0x20006800
		MOV		R5, #MAX_SIZE			; R5 = 0x4000
		STR		R5, [R4]				; 0x20006800 -> 0x4000
		
loop1	
		LDR		R6, =MCB_BOT			
		CMP		R4, R6
		BGT		stop1
		ADD		R4, R4, #0x2
		MOV		R5, #0x0
		STR		R5, [R4]
		B		loop1
stop1		
		BX		LR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory Allocation
; void* _k_alloc( int size )
		EXPORT	_kalloc
_kalloc
		; complete your code
		; return value should be saved into r0
		PUSH	{LR}			; R0 = size
		LDR		R1, =MCB_TOP	; left_mcb_addr
		LDR		R2, =MCB_BOT	; right_mcb_addr
		BL		_ralloc
		POP		{LR}
		MOV		R0, R10
		BX		LR
		
_ralloc	
		PUSH	{LR}
		SUBS	R3, R2, R1				; right_mcb_addr - left_mcb_addr
		ADDS	R3, R3, #MCB_ENT_SZ		; R3 = entire_mcb_addr_space
		ASRS	R4, R3, #1				; R4 = half_mcb_addr_space
		ADDS	R5, R1, R4				; R5 = midpoint_mcb_addr
		MOV		R10, #0x0				; R10 = heap_addr
		LSLS	R7, R3, #4				; R7 = act_entire_heap_size	
		LSLS	R8, R4, #4				; R8 = act_half_heap_size
		
		CMP		R0, R8	; if ( size <= act_half_heap_size )
		BEQ		branchM1
		BLT		branchM1

; size >= act_half_heap_size
branchM2	
		LDR		R9, [R1]
		AND		R9, R9, #0x01
		CMP		R9, #0x0
		BEQ		branchM21
		MOV		R10, #0x0
		BL		done			
		
branchM21						
		LDR		R9, [R1]
		CMP		R9, R7
		BLT		branchM211			
		ORR		R9, R7, #0x01
		STR		R9, [R1]
		
		LDR		R9, =MCB_TOP
		SUB		R9, R1, R9
		LSL		R9, R9, #0x4
		LDR		R11, =HEAP_TOP
		ADD		R9, R9, R11
		MOV		R10, R9
		BL		done
		
branchM211
		MOV		R10, #0x0
		BL		done

; size <= act_half_heap_size
branchM1
		PUSH 	{R0-R9}
		SUBS	R2, R5, #MCB_ENT_SZ
		BL		_ralloc
		POP		{R0-R9}
		CMP		R10, #0x0
		BEQ		branchM11
		LDR		R9, [R5]
		AND		R9, R9, #0x01
		CMP		R9, #0x0
		BEQ		branchM12
		BL		done
		
branchM12
		STR		R8, [R5]
		BL		done
		
branchM11
		PUSH	{R0-R9}
		MOV		R1, R5
		BL		_ralloc
		POP		{R0-R9}
		BL		done
		
done	
		POP		{LR}
		BX		LR
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Kernel Memory De-allocation
; void *_kfree( void *ptr )	
		EXPORT	_kfree
_kfree
		; complete your code
		; return value should be saved into r0
		PUSH	{LR}
		MOV		R4, R0
		
		LDR		R1, =HEAP_TOP
		LDR		R2, =HEAP_BOT
		CMP		R4, R1
		BLT		branchKfree
		CMP		R4, R2
		BGT		branchKfree
		
		LDR		R5, =MCB_TOP
		SUB		R6, R4, R1
		ASR		R6, R6, #0x4
		ADD		R6, R6, R5
		
		MOV		R0, R6
		PUSH	{R4}
		BL		_rfree
		POP		{R4}
		
		CMP		R10, #0x0
		BEQ		branchKfree
		MOV		R0, R4
		BL		done3
		
branchKfree
		MOV		R0, #0x0
		BL		done3

done3
		POP		{LR}
		BX		LR
		
_rfree	
		PUSH	{LR}				; R0 = mcb_addr
		LDR		R1, [R0]			; R1 = mcb_contents
		LDR		R5, =MCB_TOP
		SUB		R2, R0, R5			; R2 = mcb_index
		ASR		R1, R1, #0x4		; R1 = mcb_contents = mcb_contents / 16
		MOV		R3, R1				; R3 = mcb_disp
		LSL		R1, R1, #0x4		; R1 = mcb_contents = mcb_contents * 16
		MOV		R4, R1				; R4 = my_size
		
		STR		R1, [R0]			; clear the used bit
		UDIV	R5, R2, R3			
		AND		R5, R5, #0x01		; if ( ( mcb_index / mcb_disp ) % 2 == 0 )
		CMP		R5, #0x0
		BEQ		branchF1
		BNE		branchF2
		
branchF1
		ADD		R5, R0, R3
		LDR		R8, =MCB_BOT
		CMP		R5, R8				; if ( mcb_addr + mcb_disp >= mcb_bot )
		BLT		branchF11
		MOV		R10, #0x0
		BL		done2
		
branchF11
		ADD		R5, R0, R3
		LDR		R6, [R5]			; R6 = mcb_buddy
		AND		R5, R6, #0x01
		CMP		R5, #0x0			; if ( ( mcb_buddy & 0x0001 ) == 0 )
		BEQ		branchF111
		MOV		R10, R0
		BL		done2

branchF111
		ASR		R5, R6, #0x5
		LSL		R5, R5, #0x5
		MOV		R6, R5				; mcb_buddy = ( mcb_buddy / 32 ) * 32; // clear bit 4-0
		CMP		R6, R4				; if ( mcb_buddy == my_size )
		BEQ		branchF1111
		MOV		R10, R0
		BL		done2
		
branchF1111
		ADD		R5, R0, R3
		MOV		R7, #0x0
		STR		R7, [R5]
		LSL		R4, R4, #0x01		; my_size *= 2
		STR		R4, [R0]			; *(short *)&array[ m2a( mcb_addr ) ] = my_size
		PUSH	{R0-R9}
		BL		_rfree
		POP		{R0-R9}
		BL		done2
		
branchF2
		SUB		R5, R0, R3
		LDR		R8, =MCB_TOP
		CMP		R5, R8				; if ( mcb_addr - mcb_disp < mcb_top )
		BGT		branchF21
		BEQ		branchF21
		MOV		R10, #0x0
		BL 		done2
		
branchF21
		SUB		R5, R0, R3
		LDR		R6, [R5]			; mcb_buddy = *(short *)&array[ m2a( mcb_addr - mcb_disp ) ]
		AND		R5, R6, #0x01
		CMP		R5, #0x0			; if ( ( mcb_buddy & 0x0001 ) == 0 )
		BEQ		branchF211
		MOV		R10, R0
		BL		done2
		
branchF211
		ASR		R5, R6, #0x5
		LSL		R5, R5, #0x5
		MOV		R6, R5				; mcb_buddy = ( mcb_buddy / 32 ) * 32; // clear bit 4-0
		CMP		R6, R4				; if ( mcb_buddy == my_size )
		BEQ		branchF2111
		MOV		R10, R0
		BL		done2
		
branchF2111
		MOV		R7, #0x0
		STR		R7, [R0]
		LSL		R4, R4, #0x01		; my_size *= 2
		SUB		R5, R0, R3
		STR		R4, [R5]
		PUSH	{R0-R9}
		SUB		R0, R0, R3
		BL		_rfree
		POP		{R0-R9}
		BL 		done2
		
done2
		POP		{LR}
		BX		LR	
		
		
		END
		

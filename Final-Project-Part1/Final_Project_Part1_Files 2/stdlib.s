			AREA	|.text|, CODE, READONLY, ALIGN=2
			THUMB

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _bzero( void *s, int n )
; Parameters
;	s 		- pointer to the memory location to zero-initialize
;	n		- a number of bytes to zero-initialize
; Return value
;   none
			EXPORT	_bzero
_bzero		
			; r0 = s
			; r1 = n
			PUSH 	{r1-r12,lr}		
			; you need to add some code here for part 1 implmentation
loop		CMP		R1, #0			; compare R1 with 0
			BEQ		return			; return to main if R1 = 0
			MOV		R8, #0			; assign 0 to R8
			STRB	R8, [R0], #1	; changing each byte to 0
			SUB		R1, R1, #1		; update the counter
			B		loop			; loop back up
return		POP 	{r1-r12,lr}		; return
			BX		lr



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; char* _strncpy( char* dest, char* src, int size )
; Parameters
;   dest 	- pointer to the buffer to copy to
;	src		- pointer to the zero-terminated string to copy from
;	size	- a total of n bytes
; Return value
;   dest
			EXPORT	_strncpy
_strncpy
			; r0 = dest
			; r1 = src
			; r2 = size
			PUSH 	{r1-r12,lr}		
			; you need to add some code here for part 1 implmentation
loop2		CMP		R2, #0			; compare R2 to 0
			BEQ		return2			; if R2 = 0, return to main
			LDRB	R8, [R1], #1	; load the content that R1 pointing to into R8 and offset by 1
			STRB	R8, [R0], #1	; store the content that R8 just got from R1 to R0
			SUB		R2, R2, #1		; substrack R2 by 1 to update the counter
			B		loop2			; go back to loop
return2		POP 	{r1-r12,lr}		; return
			BX		lr
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void* _malloc( int size )
; Parameters
;	size	- #bytes to allocate
; Return value
;   void*	a pointer to the allocated space
			EXPORT	_malloc
_malloc
			; r0 = size
			PUSH 	{r1-r12,lr}		
			; you need to add some code here for part 2 implmentation
			POP 	{r1-r12,lr}	
			BX		lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void _free( void* addr )
; Parameters
;	size	- the address of a space to deallocate
; Return value
;   none
			EXPORT	_free
_free
			; r0 = addr
			PUSH 	{r1-r12,lr}		
			; you need to add some code here for part 2 implmentation
			POP 	{r1-r12,lr}	
			BX		lr
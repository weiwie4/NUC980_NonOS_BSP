;/*
; * FreeRTOS Kernel V10.0.0
; * Copyright (C) 2017 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
; *
; * Permission is hereby granted, free of charge, to any person obtaining a copy of
; * this software and associated documentation files (the "Software"), to deal in
; * the Software without restriction, including without limitation the rights to
; * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
; * the Software, and to permit persons to whom the Software is furnished to do so,
; * subject to the following conditions:
; *
; * The above copyright notice and this permission notice shall be included in all
; * copies or substantial portions of the Software. If you wish to use our Amazon
; * FreeRTOS name, please do so in a fair use way that does not cause confusion.
; *
; * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
; * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
; * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
; * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
; * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; *
; * http://www.FreeRTOS.org
; * http://aws.amazon.com/freertos
; *
; * 1 tab == 4 spaces!
; */

	INCLUDE portmacro.inc

	IMPORT	vTaskSwitchContext
	IMPORT	xTaskIncrementTick
	IMPORT	systemIrqHandler

	EXPORT	vPortYieldProcessor
	EXPORT	vPortStartFirstTask
	EXPORT	vPreemptiveTick
	EXPORT	vPortYield


REG_AIC_IRQNUM	EQU	0xB0042120
REG_AIC_EOIS	EQU	0xB0042150
REG_ETMR5_ISR	EQU	0xB0052110
IRQ_TIMER5		EQU	0x00000022

	ARM
	AREA	PORT_ASM, CODE, READONLY



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Starting the first task is done by just restoring the context
; setup by pxPortInitialiseStack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vPortStartFirstTask

	PRESERVE8

	portRESTORE_CONTEXT

vPortYield

	PRESERVE8

	SVC 0
	bx lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt service routine for the SWI interrupt.  The vector table is
; configured in the startup.s file.
;
; vPortYieldProcessor() is used to manually force a context switch.  The
; SWI interrupt is generated by a call to taskYIELD() or portYIELD().
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vPortYieldProcessor

	PRESERVE8

	; Within an IRQ ISR the link register has an offset from the true return
	; address, but an SWI ISR does not.  Add the offset manually so the same
	; ISR return code can be used in both cases.
	ADD	LR, LR, #4

	; Perform the context switch.
	portSAVE_CONTEXT					; Save current task context
	LDR R0, =vTaskSwitchContext			; Get the address of the context switch function
	MOV LR, PC							; Store the return address
	BX	R0								; Call the contedxt switch function
	portRESTORE_CONTEXT					; restore the context of the selected task



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt service routine for preemptive scheduler tick timer
; Only used if portUSE_PREEMPTION is set to 1 in portmacro.h
;
; Uses timer 5 of NUC980
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vPreemptiveTick

	PRESERVE8

	portSAVE_CONTEXT					; Save the context of the current task.

	LDR R0, =REG_AIC_IRQNUM				;
	LDR R0, [R0]
	CMP R0, #IRQ_TIMER5					; Check the interrupt is from Timer 5 or not.
	BEQ SkipIrqHandler

	LDR R1, =systemIrqHandler			; Call to real interrupt handler of non-OS.    
	MOV LR, PC							;
	BX  R1								;

	B RestoreContext

SkipIrqHandler
	LDR R0, =xTaskIncrementTick			; Increment the tick count.  
	MOV LR, PC							; This may make a delayed task ready
	BX R0								; to run.

	CMP R0, #0
	BEQ SkipContextSwitch
	LDR R0, =vTaskSwitchContext			; Find the highest priority task that 
	MOV LR, PC							; is ready to run.
	BX R0

SkipContextSwitch
	LDR R0, =REG_ETMR5_ISR				; Clear the timer interrupt.
	LDR R1, =1
	STR R1, [R0] 

	LDR R0, =REG_AIC_EOIS				; Acknowledge end of IRQ handler.
	STR R1,[R0]

RestoreContext
	portRESTORE_CONTEXT					; Restore the context of the highest 
										; priority task that is ready to run.
	END


;****************************
;�����	: ������ �����		*
;���� 	: 20.01.2015		*
;��� AVR: ATtiny13			*
;�������� �������:4.8 ���	*
;****************************
;����������� �������: 
;��������� ���������� �� DS18B20

.device ATtiny13A
;.nolist
;.include "d:\MyProgs\Asm\Appnotes\tn13def.inc"
;.list

.def temp1=r16
.def temp2=r17

.def ds_reg=r19
.def res_reg=r20
.def control=r21

.cseg
.org 0
;******************** ������� ���������� ******************************
rjmp reset					;RESET
reti						;INT0 External Interrupt Request 0
reti						;PCINT0 Pin Change Interrupt Request 0
reti						;TIM0_OVF Timer/Counter Overflow
reti						;EE_RDY EEPROM Ready
reti						;ANA_COMP Analog Comparator
reti						;TIM0_COMPA Timer/Counter Compare Match A
reti						;TIM0_COMPB Timer/Counter Compare Match B
reti						;WDT Watchdog Time-out
reti						;ADC ADC Conversion Complete
;******************* ��������� ���������� *****************************
reset:
		ldi	temp1,ramend
		out	SPL,temp1
		ldi temp1,0b00101110;
		out ddrb,temp1
		clr temp1
		out portb,temp1
		ldi temp1,18
		mov r0,r16
		ldi temp1,4
		mov r1,r16
		ldi temp1,0b00100010
		out admux,temp1
		ldi temp1,0b10000100
		out adcsra,temp1
	
;********************* ������� ��������� *******************************		
;������ ������������ � ������
loop1:
		clt
		rcall init			;����� ������������� �������
		brts loop1			;������� � ������, ���� ������ �� ������
		ldi ds_reg,0xCC		;�������� ROM-������ Skip ROM(0���)
		rcall ds_write
		ldi ds_reg,0x4E		;�������� �����. ������� write scratchpad
		rcall ds_write
		ldi ds_reg,0x51		;������ �������� TH
		rcall ds_write
		ldi ds_reg,0x12		;������ �������� TL
		rcall ds_write
		ldi ds_reg,0x1f		;������ �������� ������������
		rcall ds_write
;������ ������������ � EEPROM �������
		rcall init			;����� ������������� �������
		brts loop1			;������� � ������, ���� ������ �� ������
		ldi ds_reg,0xCC		;�������� ROM-������ Skip ROM(0���)
		rcall ds_write
		ldi ds_reg,0x48		;�������� �����. ������� copy scratchpad
		rcall ds_write
		ldi temp2,0x47
		rcall longdelay
		
		clt
loop2:
		rcall init			;����� ������������� �������
		brts loop2-1		;������� � ������, ���� ������ �� ������
		ldi ds_reg,0xCC		;�������� ROM-������ Skip ROM(0���)
		rcall ds_write
		ldi ds_reg,0x44		;�������� �����. ������� ConvertT
		rcall ds_write
		ldi temp2,0xff
		rcall longdelay
		ldi temp2,0xff
		rcall longdelay
		ldi temp2,0x47
		rcall longdelay

		sbi adcsra,adsc		;����� �� ��������������
label_2:
		sbic adcsra,adsc	;�������� ��������� �� ��������������
		rjmp label_2		;�������������� 420 ���
		
		rcall init			;����� ������������� �������
		brts loop2-1		;������� � ������, ���� ������ �� ������
		ldi ds_reg,0xCC		;�������� ROM-������ Skip ROM(0���)
		rcall ds_write
		ldi ds_reg,0xBE		;�������� �����. ������� Read Scratchpad
		rcall ds_write
		ldi temp1,2			;������������ 2,71 ���
		rcall shortdelay	;����� ����� ���������
		rcall ds_read
		mov xl,ds_reg
		rcall ds_read
		mov xh,ds_reg
		rcall init
		brts loop2-1		;������� � ������, ���� ������ �� ������
		rcall ds_convert
		cbi portb,2			;���������� ���������� "������"
;***************** ������������� ����������� ***************************
		in temp1,adch
		lsr temp1
		lsr temp1
		add temp1,r0
		sbis portb,1
		rjmp heat_on
		cp res_reg,temp1
		brlt PC+3
		cbi portb,1
		cbi portb,3			;���������� ���������� "������"
		rjmp loop2
heat_on:
		sub temp1,r1
		cp temp1,res_reg
		brlt PC+3
		sbi portb,1
		sbi portb,3			;��������� ���������� "������"
		rjmp loop2
;****************** ����� ������� ��������� ****************************

;************************** �������� ***********************************
;�������� �������� �� 2,08 ��� �� 160.83 ���
shortdelay:
		dec 	temp1		;��������� �������� (������� ����� �������)
		brne	shortdelay	;���� temp1<>0, ������� � �����
ret
;������� �������� �� 164 ��� �� 41,54 ��
longdelay:
		ldi 	temp1,0xFF	;����� ������� ��� �������� ��������
		rcall 	shortdelay	;����� �������� ��������
		dec 	temp2		;��������� �������� (������� ����� �������)
		brne 	longdelay	;���� temp2<>0, ������� � �����
ret
;******************* ������������� ������� *****************************
init:
		sbi ddrb,0			;����������� ������ ������ �������
		ldi temp2,0x03		;������������ 485,83 ���
		rcall longdelay		;������ �������� 
		ldi temp2,0x03		;���-�� �������� ������� �����������
		cbi ddrb,0
cycle_1:
		ldi temp1,0x1e		;������������ 20,21 ���
		rcall shortdelay	;����� ��������
		sbis pinb,0			;�������� ������� �����������
		rjmp presence		;������� ���� �� ��0=0
		dec temp2			;��������� ���-�� ��������, ���� �� ��0=1
		breq PC+2			;���� ���-�� �������� <> 0, ��
		rjmp cycle_1		;��������� � ���� 1
		rcall error			;
		ret
presence:
		ldi temp1,0x5e		;������������ 60,21 ���
		rcall shortdelay	;����� ��������
		sbis pinb,0			;�������� �� ��������� ������� �����������
		rjmp presence		;���� �� ���������, ��������� ��������
		ldi temp1,0xfe		;������������ 160,21 ���
		rcall shortdelay	;����� ��������
		ldi temp1,0x1e		;������������ 20,21 ���
		rcall shortdelay	;����� ��������
		ret
;********************** ������ � ������ ********************************
ds_write:
		ldi temp2,9			;���-�� �������� + 1
cycle_2:
		ldi temp1,2			;������������ 2,5 ���
		rcall shortdelay	;����� ����� ������
		dec temp2			;���������������� �������
		brne PC+2			;���� ������� = 0 ����� �� ������������
		ret
		lsr ds_reg			;����� ���� � ���� �������� (���� �)
		brcc write_0		;���� ���� �������, ������� � ������ 0
		sbi ddrb,0			;����������� ������ ������������� ������
		ldi temp1,2			;������������ 2,5 ���
		rcall shortdelay	;����� ��������
		cbi ddrb,0
		ldi temp1,0x5e		;������������  60,21 ���
		rcall shortdelay	;����� ��������
		rjmp cycle_2		;��������� � ���� 2
write_0:
		sbi ddrb,0			;����������� ������ ������������� � ������ 0
		ldi temp1,0x61		;������������ 62,08 ���
		rcall shortdelay	;����� ��������
		cbi ddrb,0
		rjmp cycle_2		;��������� � ���� 2
;********************* ������ �� ������� *******************************
ds_read:
		clr ds_reg
		ldi temp2,8			;���-�� ��������
cycle_3:
		sbi ddrb,0			;����������� ������ ������������� ������
		ldi temp1,2			;������������ 2,5 ���
		rcall shortdelay	;����� ��������
		cbi ddrb,0
		ldi temp1,0x13		;������������ 13,33 ���
		rcall shortdelay	;����� ��������
		sbis pinb,0
		rjmp read_0
		lsr ds_reg
		ori ds_reg,0x80
		rjmp label_1
read_0:
		lsr ds_reg
		nop
label_1:
		ldi temp1,0x4a		;������������ 47,71 ���
		rcall shortdelay	;����� ��������
		dec temp2			;���������������� �������
		brne PC+2			;���� ������� = 0 ����� �� ������������
		ret
		rjmp cycle_3		;��������� � ���� 3
;*************** �������������� ������ ������� *************************		
ds_convert:
		mov temp2,XH
		andi temp2,0b11111000
		cpi temp2,0
		breq PC+3
		rcall error
		ret
		swap XH
		mov temp2,XL
		andi temp2,0b11110000
		swap temp2
		or XH,temp2
		mov res_reg,XH
		ret
;******************* ���� ��������� ������ *****************************
error:
		cbi portb,1			;���������� �������
		sbi portb,2			;��������� ���������� "������"
		set
ret


; Replace with your application code
start:
    inc r16
    rjmp start

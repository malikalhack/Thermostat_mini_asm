;****************************
;Автор	: Чернов Антон		*
;Дата 	: 20.01.2015		*
;Для AVR: ATtiny13			*
;Тактовая частота:4.8 МГц	*
;****************************
;Выполняемые функции: 
;Цифрового термометра на DS18B20

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
;******************** Вектора прерываний ******************************
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
;******************* Обработка прерываний *****************************
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
	
;********************* Главная программа *******************************		
;Запись конфигурации в датчик
loop1:
		clt
		rcall init			;Вызов инициализации датчика
		brts loop1			;Переход в начало, если датчик не найден
		ldi ds_reg,0xCC		;Передача ROM-комады Skip ROM(0хСС)
		rcall ds_write
		ldi ds_reg,0x4E		;Передача функц. команды write scratchpad
		rcall ds_write
		ldi ds_reg,0x51		;Запись регистра TH
		rcall ds_write
		ldi ds_reg,0x12		;Запись регистра TL
		rcall ds_write
		ldi ds_reg,0x1f		;Запись регистра конфигурации
		rcall ds_write
;Запись конфигурации в EEPROM датчика
		rcall init			;Вызов инициализации датчика
		brts loop1			;Переход в начало, если датчик не найден
		ldi ds_reg,0xCC		;Передача ROM-комады Skip ROM(0хСС)
		rcall ds_write
		ldi ds_reg,0x48		;Передача функц. команды copy scratchpad
		rcall ds_write
		ldi temp2,0x47
		rcall longdelay
		
		clt
loop2:
		rcall init			;Вызов инициализации датчика
		brts loop2-1		;Переход в начало, если датчик не найден
		ldi ds_reg,0xCC		;Передача ROM-комады Skip ROM(0хСС)
		rcall ds_write
		ldi ds_reg,0x44		;Передача функц. команды ConvertT
		rcall ds_write
		ldi temp2,0xff
		rcall longdelay
		ldi temp2,0xff
		rcall longdelay
		ldi temp2,0x47
		rcall longdelay

		sbi adcsra,adsc		;старт АЦ преобразования
label_2:
		sbic adcsra,adsc	;ожидание окончания АЦ преобразования
		rjmp label_2		;приблизительно 420 мкс
		
		rcall init			;Вызов инициализации датчика
		brts loop2-1		;Переход в начало, если датчик не найден
		ldi ds_reg,0xCC		;Передача ROM-комады Skip ROM(0хСС)
		rcall ds_write
		ldi ds_reg,0xBE		;Передача функц. команды Read Scratchpad
		rcall ds_write
		ldi temp1,2			;длительность 2,71 мкс
		rcall shortdelay	;пауза между командами
		rcall ds_read
		mov xl,ds_reg
		rcall ds_read
		mov xh,ds_reg
		rcall init
		brts loop2-1		;Переход в начало, если датчик не найден
		rcall ds_convert
		cbi portb,2			;отключение светодиода "Ошибка"
;***************** Регулирование температуры ***************************
		in temp1,adch
		lsr temp1
		lsr temp1
		add temp1,r0
		sbis portb,1
		rjmp heat_on
		cp res_reg,temp1
		brlt PC+3
		cbi portb,1
		cbi portb,3			;отключение светодиода "Нагрев"
		rjmp loop2
heat_on:
		sub temp1,r1
		cp temp1,res_reg
		brlt PC+3
		sbi portb,1
		sbi portb,3			;включение светодиода "Нагрев"
		rjmp loop2
;****************** Конец главной программы ****************************

;************************** Задержки ***********************************
;Короткая задержка от 2,08 мкс до 160.83 мкс
shortdelay:
		dec 	temp1		;декремент счётчика (задаётся перед вызовом)
		brne	shortdelay	;если temp1<>0, возврат к метке
ret
;Длинная задержка от 164 мкс до 41,54 мс
longdelay:
		ldi 	temp1,0xFF	;задаём счётчик для короткой задержки
		rcall 	shortdelay	;вызов короткой задержки
		dec 	temp2		;декремент счётчика (задаётся перед вызовом)
		brne 	longdelay	;если temp2<>0, возврат к метке
ret
;******************* Инициализация датчика *****************************
init:
		sbi ddrb,0			;формируется сигнал сброса датчика
		ldi temp2,0x03		;длительность 485,83 мкс
		rcall longdelay		;Запуск задержка 
		ldi temp2,0x03		;Кол-во проверок сигнала присутствия
		cbi ddrb,0
cycle_1:
		ldi temp1,0x1e		;длительность 20,21 мкс
		rcall shortdelay	;вызов задержки
		sbis pinb,0			;проверка сигнала присутствия
		rjmp presence		;переход если на РВ0=0
		dec temp2			;уменьшить кол-во проверок, если на РВ0=1
		breq PC+2			;если кол-во проверок <> 0, то
		rjmp cycle_1		;вернуться в цикл 1
		rcall error			;
		ret
presence:
		ldi temp1,0x5e		;длительность 60,21 мкс
		rcall shortdelay	;вызов задержки
		sbis pinb,0			;проверка на окончание сигнала присутствия
		rjmp presence		;если не окончился, повторить проверку
		ldi temp1,0xfe		;длительность 160,21 мкс
		rcall shortdelay	;вызов задержки
		ldi temp1,0x1e		;длительность 20,21 мкс
		rcall shortdelay	;вызов задержки
		ret
;********************** Запись в датчик ********************************
ds_write:
		ldi temp2,9			;кол-во проходов + 1
cycle_2:
		ldi temp1,2			;длительность 2,5 мкс
		rcall shortdelay	;пауза между битами
		dec temp2			;декрементировать счётчик
		brne PC+2			;если счётчик = 0 выйти из подпрограммы
		ret
		lsr ds_reg			;сдвиг бита в флаг переноса (флаг С)
		brcc write_0		;если флаг сброшен, перейти к записи 0
		sbi ddrb,0			;формируется сигнал инициализации записи
		ldi temp1,2			;длительность 2,5 мкс
		rcall shortdelay	;вызов задержки
		cbi ddrb,0
		ldi temp1,0x5e		;длительность  60,21 мкс
		rcall shortdelay	;вызов задержки
		rjmp cycle_2		;вернуться в цикл 2
write_0:
		sbi ddrb,0			;формируется сигнал инициализации и записи 0
		ldi temp1,0x61		;длительность 62,08 мкс
		rcall shortdelay	;вызов задержки
		cbi ddrb,0
		rjmp cycle_2		;вернуться в цикл 2
;********************* Чтение из датчика *******************************
ds_read:
		clr ds_reg
		ldi temp2,8			;кол-во проходов
cycle_3:
		sbi ddrb,0			;формируется сигнал инициализации чтения
		ldi temp1,2			;длительность 2,5 мкс
		rcall shortdelay	;вызов задержки
		cbi ddrb,0
		ldi temp1,0x13		;длительность 13,33 мкс
		rcall shortdelay	;вызов задержки
		sbis pinb,0
		rjmp read_0
		lsr ds_reg
		ori ds_reg,0x80
		rjmp label_1
read_0:
		lsr ds_reg
		nop
label_1:
		ldi temp1,0x4a		;длительность 47,71 мкс
		rcall shortdelay	;вызов задержки
		dec temp2			;декрементировать счётчик
		brne PC+2			;если счётчик = 0 выйти из подпрограммы
		ret
		rjmp cycle_3		;вернуться в цикл 3
;*************** Преобразование данных датчика *************************		
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
;******************* Блок обработки ошибок *****************************
error:
		cbi portb,1			;отключение нагрева
		sbi portb,2			;включение светодиода "Ошибка"
		set
ret


; Replace with your application code
start:
    inc r16
    rjmp start

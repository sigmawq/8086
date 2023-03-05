package main

import "core:fmt"
import "core:os"

main :: proc() {
	args := os.args[1:]

	if len(args) != 1 {
		fmt.println("File name required")
		return
	}

	data, ok := os.read_entire_file_from_filename(args[0])
	if !ok {
		fmt.println("Failed to read file")
		return
	}

	for len(data) >= 2 {
		first_byte := transmute(u8)data[0]
		second_byte := transmute(u8)data[1]
		advance: int

		get_register_name :: proc(v: u8, wide: bool) -> string {
			result: string 
			if !wide {
				switch v {
					case 0b000: result = "AL"
					case 0b001: result = "CL"
					case 0b010: result = "DL"
					case 0b011: result = "BL"
					case 0b100: result = "AH"
					case 0b101: result = "CH"
					case 0b110: result = "DH"
					case 0b111: result = "BH"
				}	
			} else {
				switch v {
					case 0b000: result = "AX"
					case 0b001: result = "CX"
					case 0b010: result = "DX"
					case 0b011: result = "BX"
					case 0b100: result = "SP"
					case 0b101: result = "BP"
					case 0b110: result = "SI"
					case 0b111: result = "DI"
				}
			}
			
			return result
		}

		if (first_byte >> 2) == 0b100010 { // Register/memory to/from register
			source: string
			dest: string

			reg := (second_byte & 0b00111000) >> 3
			rm := (second_byte & 0b00000111)
			wide := (first_byte & 0b00000001) > 0

			mod := (second_byte >> 6)
			if mod == 0b11 {
				source = get_register_name(reg, wide)
				dest = 	get_register_name(rm, wide)

				advance = 2
			} else if mod == 0b01 {
				advance = 3

				prefix: string
				switch rm {
					case 0b000: prefix = "BX + SI + "
					case 0b001: prefix = "BX + DI + "
					case 0b010: prefix = "BP + SI + "
					case 0b011: prefix = "BP + DI + "
					case 0b100: prefix = "SI + "
					case 0b101: prefix = "DI + "
					case 0b110: prefix = "BP + "
					case 0b111: prefix = "BX + "
				}

				disp := (transmute(^u8)&data[2])^
				dest = fmt.tprintf("[%v%v]", prefix, disp)
				source = get_register_name(reg, wide)
			} else if mod == 0b10 {
				advance = 4

				prefix: string
				switch rm {
					case 0b000: prefix = "BX + SI + "
					case 0b001: prefix = "BX + DI + "
					case 0b010: prefix = "BP + SI + "
					case 0b011: prefix = "BP + DI + "
					case 0b100: prefix = "SI + "
					case 0b101: prefix = "DI + "
					case 0b110: prefix = "BP + "
					case 0b111: prefix = "BX + "
				}

				disp := (transmute(^u16)&data[2])^
				dest = fmt.tprintf("[%v%v]", prefix, disp)
				source = get_register_name(reg, wide)
			} else if mod == 0b00 {
				advance = 2
				switch rm {
					case 0b000: dest = "[BX + SI]"
					case 0b001: dest = "[BX + DI]"
					case 0b010: dest = "[BP + SI]"
					case 0b011: dest = "[BP + DI]"
					case 0b100: dest = "[SI]"
					case 0b101: dest = "[DI]"
					case 0b110: {
						advance = 4
						address := (transmute(^u16)&data[2])^
						dest = fmt.tprintf("[%v]", address)
					}
					case 0b111: dest = "[BX]"
				}

				source = get_register_name(reg, wide)
			}

			if (first_byte & 0b00000010) > 0 {
				temp := source
				source = dest
				dest = temp
			}
			fmt.printf("mov %v, %v\n", dest, source)
		} else if (first_byte >> 1) == 0b1100011 { // Immediate to register/memory
			source: string
			dest: string

			rm := (second_byte & 0b00000111)
			wide := (first_byte & 0b00000001) > 0

			advance = 2

			mod := (second_byte >> 6)
			immediate_value: int
			if mod == 0b01 {
				disp := (transmute(^u16)(&data[2]))^
				advance += 1

				if wide {
					advance += 2
					immediate_value = cast(int)(transmute(^u16)(&data[3]))^
				} else {
					advance += 1
					immediate_value = cast(int)(transmute(^u8)(&data[3]))^
				}

				prefix: string
				switch rm {
					case 0b000: prefix = "BX + SI + "
					case 0b001: prefix = "BX + DI + "
					case 0b010: prefix = "BP + SI + "
					case 0b011: prefix = "BP + DI + "
					case 0b100: prefix = "SI + "
					case 0b101: prefix = "DI + "
					case 0b110: prefix = "BP + "
					case 0b111: prefix = "BX + "
				}

				dest = fmt.tprintf("[%v%v]", prefix, disp)
				source = fmt.tprintf("%v", immediate_value)
			} else if mod == 0b10 {
				disp := (transmute(^u16)(&data[2]))^
				advance += 2

				if wide {
					advance += 2
					immediate_value = cast(int)(transmute(^u16)(&data[4]))^
				} else {
					advance += 1
					immediate_value = cast(int)(transmute(^u8)(&data[4]))^
				}

				prefix: string
				switch rm {
					case 0b000: prefix = "BX + SI + "
					case 0b001: prefix = "BX + DI + "
					case 0b010: prefix = "BP + SI + "
					case 0b011: prefix = "BP + DI + "
					case 0b100: prefix = "SI + "
					case 0b101: prefix = "DI + "
					case 0b110: prefix = "BP + "
					case 0b111: prefix = "BX + "
				}

				dest = fmt.tprintf("[%v%v]", prefix, disp)
				source = fmt.tprintf("%v", immediate_value)
			} else if mod == 0b00 {
				if wide {
					advance += 2
					immediate_value = cast(int)(transmute(^u16)(&data[2]))^
				} else {
					advance += 1
					immediate_value = cast(int)(transmute(^u8)(&data[2]))^
				}

				switch rm {
					case 0b000: dest = "BX + SI"
					case 0b001: dest = "BX + DI"
					case 0b010: dest = "BP + SI"
					case 0b011: dest = "BP + DI"
					case 0b100: dest = "SI"
					case 0b101: dest = "DI"
					case 0b110: {
						advance = 4
						address := (transmute(^u16)&data[2])^
						dest = fmt.tprintf("%v", address)
					}
					case 0b111: dest = "BX"
				}

				source = fmt.tprintf("%v", immediate_value)
			} else if mod == 0b11 {
				if wide {
					advance += 2
					immediate_value = cast(int)(transmute(^u16)(&data[2]))^
				} else {
					advance += 1
					immediate_value = cast(int)(transmute(^u8)(&data[2]))^
				}

				dest = get_register_name(rm, wide)
				source = fmt.tprintf("%v", immediate_value)
			}

			fmt.printf("mov %v, %v\n", dest, source)
		} else if (first_byte >> 4) == 0b1011 {
			reg := first_byte & 0b0000_0111
			wide := (first_byte & 0b0000_1000) > 0

			immediate_value: int
			if wide {
				advance = 3
				immediate_value = cast(int)(transmute(^u16)(&data[1]))^
			} else {
				advance = 2
				immediate_value = cast(int)(transmute(^u8)(&data[1]))^
			}

			fmt.printf("mov %v, %v\n", get_register_name(reg, wide), immediate_value)
		} else {
			fmt.panicf("Unrecognized instruction: %#b\n", first_byte)
		}

		data = data[advance:]
	}


}
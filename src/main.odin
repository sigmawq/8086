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

		if (first_byte >> 2) == 0b100010 {
			source: string
			dest: string

			if (second_byte >> 6) != 0b11 {
				panic("Not supported")
			}

			reg := (second_byte & 0b00111000) >> 3
			rm := (second_byte & 0b00000111)

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

			if (first_byte & 0b00000001) > 0 {
				source = get_register_name(reg, true)
				dest = 	get_register_name(rm, true)
			} else {
				source = get_register_name(reg, false)
				dest = 	get_register_name(rm, false)
			}

			if ((first_byte & 0b00000010) >> 1) > 0 {
				temp := source
				source = dest
				dest = temp
			}

			fmt.printf("mov %v, %v\n", dest, source)
		} 

		data = data[2:]
	}
}
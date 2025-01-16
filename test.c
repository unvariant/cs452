#include "rpi.h"

// int kmain() {
// 	// set up GPIO pins for both console and marklin uarts
// 	gpio_init();
// 	// not strictly necessary, since console is configured during boot
// 	uart_config_and_enable(CONSOLE);
// 	// welcome message
// 	uart_puts(CONSOLE, "\r\nHello world, this is version: " __DATE__ " / " __TIME__ "\r\n\r\nPress 'q' to reboot\r\n");

// 	uart_config_and_enable(2);
// 	uart_puts(2, "\r\nhi\r\n");

// 	while (1) {}

// 	unsigned int counter = 1;
// 	for (;;) {
// 		uart_printf(CONSOLE, "PI[%u]> ", counter++);
// 		for (;;) {
// 			char c = uart_getc(CONSOLE);
// 			uart_putc(CONSOLE, c);
// 			if (c == '\r') {
// 				uart_putc(CONSOLE, '\n');
// 				break;
// 			} else if (c == 'q' || c == 'Q') {
// 				uart_puts(CONSOLE, "\r\n");
// 				return 0;
// 			}
// 		}
// 	}
// }

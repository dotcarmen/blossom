#![feature(custom_test_frameworks)]
#![no_main]
#![no_std]
#![reexport_test_harness_main = "test_main"]
#![test_runner(crate::test_runner)]

#[macro_use]
extern crate log;

use uefi::prelude::*;

#[entry]
fn main() -> Status {
	uefi::helpers::init().unwrap();
	// log::set_logger(&Logger);

	info!("hello, world!");

	#[cfg(test)]
	test_main();

	loop {}
}

#[cfg(test)]
fn test_runner(tests: &[&dyn Fn()]) {
	info!("running {} tests", tests.len());

	for test in tests {
		test();
	}
}

#[test_case]
fn test_example() {
	info!("hi!!!");
}

// struct Logger;

// impl log::Log for Logger {
// 	fn enabled(&self, metadata: &log::Metadata) -> bool {
// 		true
// 	}

// 	fn log(&self, record: &log::Record) {
// 		use log::Level;
// 		use uefi::proto::console::text::Color;

// 		if !self.enabled(record.metadata()) {
// 			return;
// 		}

// 		let color = match record.level() {
// 			Level::Error => Color::Red,
// 			Level::Warn => Color::Yellow,
// 			Level::Info => Color::Green,
// 			Level::Debug => Color::Blue,
// 			Level::Trace => Color::Magenta,
// 		};

// 		let res = system::with_stdout(|stdout| {
// 			stdout.write_char('[')?;
// 			Ok(())
// 			// stdout.set_color(text::Color::, background);
// 		});

// 		if let Err(err) = res {
// 			system::with_stderr(|stderr| {
// 				stderr.wr
// 			})
// 		}
// 	}

// 	fn flush(&self) {
// 		todo!()
// 	}
// }

#![feature(no_std)]
#![feature(core)]
#![crate_type = "lib"]
#![no_std]
extern crate core;
use core::ops::Add;

struct S {
    x: usize,
}

trait T {
    fn f(&self) -> usize;
}

impl T for S {
    fn f(&self) -> usize {
        self.x
    }
}

impl Add<S> for S {
    type Output = S;
    fn add(self, other: S) -> S {
        S { x: self.x + other.x }
    }
}

fn crust_init() -> (S,) { (S { x: 0 },) }

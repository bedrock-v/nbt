module nbt

import math

struct Writer {
mut:
	data []u8
}

fn (mut w Writer) u8(v u8) {
	w.data << v
}

fn (mut w Writer) write_raw(b []u8) {
	w.data << b
}

fn (mut w Writer) le_i16(v i16) {
	x := u16(v)
	w.data << u8(x)
	w.data << u8(x >> 8)
}

fn (mut w Writer) le_u32(v u32) {
	w.data << u8(v)
	w.data << u8(v >> 8)
	w.data << u8(v >> 16)
	w.data << u8(v >> 24)
}

fn (mut w Writer) le_u64(v u64) {
	for i in 0 .. 8 {
		w.data << u8(v >> (u64(i) * 8))
	}
}

fn (mut w Writer) le_f32(v f32) {
	w.le_u32(math.f32_bits(v))
}

fn (mut w Writer) le_f64(v f64) {
	w.le_u64(math.f64_bits(v))
}

fn (mut w Writer) write_varuint32(value u32) {
	mut v := value
	for v >= 0x80 {
		w.data << u8(v) | 0x80
		v >>= 7
	}
	w.data << u8(v)
}

fn (mut w Writer) write_varint32(value i32) {
	mut ux := u32(value) << 1
	if value < 0 {
		ux = ~ux
	}
	w.write_varuint32(ux)
}

fn (mut w Writer) write_varuint64(value u64) {
	mut v := value
	for v >= 0x80 {
		w.data << u8(v) | 0x80
		v >>= 7
	}
	w.data << u8(v)
}

fn (mut w Writer) write_varint64(value i64) {
	mut ux := u64(value) << 1
	if value < 0 {
		ux = ~ux
	}
	w.write_varuint64(ux)
}

fn (mut w Writer) write_string(v string) {
	w.write_varuint32(u32(v.len))
	w.write_raw(v.bytes())
}

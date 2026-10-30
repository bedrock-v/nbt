module nbt

import math

struct Writer {
	encoding Encoding
mut:
	data []u8
}

fn (mut w Writer) u8(v u8) {
	w.data << v
}

fn (mut w Writer) write_raw(b []u8) {
	w.data << b
}

// fixed writes the low n bytes of v in the encoding's byte order. Only big
// endian differs: the network form is little endian too.
fn (mut w Writer) fixed(v u64, n int) {
	for i in 0 .. n {
		shift := if w.encoding == .big_endian { u64(n - 1 - i) * 8 } else { u64(i) * 8 }
		w.data << u8(v >> shift)
	}
}

fn (mut w Writer) short(v i16) {
	w.fixed(u64(u16(v)), 2)
}

fn (mut w Writer) int(v i32) {
	if w.encoding == .network_little_endian {
		w.write_varint32(v)
		return
	}
	w.fixed(u64(u32(v)), 4)
}

fn (mut w Writer) long(v i64) {
	if w.encoding == .network_little_endian {
		w.write_varint64(v)
		return
	}
	w.fixed(u64(v), 8)
}

fn (mut w Writer) float(v f32) {
	w.fixed(u64(math.f32_bits(v)), 4)
}

fn (mut w Writer) double(v f64) {
	w.fixed(math.f64_bits(v), 8)
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

// write_string refuses a string the fixed forms can't hold: their length is a
// u16 and cutting the string would corrupt everything written after it.
fn (mut w Writer) write_string(v string) ! {
	if w.encoding == .network_little_endian {
		w.write_varuint32(u32(v.len))
	} else {
		if v.len > max_fixed_string {
			return error('nbt: a string of ${v.len} bytes is longer than ${max_fixed_string}, the most ${w.encoding} can hold')
		}
		w.fixed(u64(v.len), 2)
	}
	w.write_raw(v.bytes())
}

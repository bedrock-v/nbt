module nbt

import math

struct Reader {
	data     []u8
	encoding Encoding
mut:
	offset int
}

fn (mut r Reader) need(n int) ! {
	if r.offset + n > r.data.len {
		return error('nbt: unexpected end of buffer at offset ${r.offset}')
	}
}

fn (mut r Reader) u8() !u8 {
	r.need(1)!
	b := r.data[r.offset]
	r.offset++
	return b
}

fn (mut r Reader) read_raw(n int) ![]u8 {
	r.need(n)!
	out := r.data[r.offset..r.offset + n].clone()
	r.offset += n
	return out
}

// fixed reads n bytes as an unsigned number in the encoding's byte order. Only
// big endian differs: the network form is little endian too.
fn (mut r Reader) fixed(n int) !u64 {
	r.need(n)!
	mut v := u64(0)
	for i in 0 .. n {
		b := u64(r.data[r.offset + i])
		if r.encoding == .big_endian {
			v = v << 8 | b
		} else {
			v |= b << (u64(i) * 8)
		}
	}
	r.offset += n
	return v
}

fn (mut r Reader) short() !i16 {
	return i16(r.fixed(2)!)
}

fn (mut r Reader) int() !i32 {
	if r.encoding == .network_little_endian {
		return r.read_varint32()
	}
	return i32(r.fixed(4)!)
}

fn (mut r Reader) long() !i64 {
	if r.encoding == .network_little_endian {
		return r.read_varint64()
	}
	return i64(r.fixed(8)!)
}

fn (mut r Reader) float() !f32 {
	return math.f32_from_bits(u32(r.fixed(4)!))
}

fn (mut r Reader) double() !f64 {
	return math.f64_from_bits(r.fixed(8)!)
}

// length reads the element count of an array or list.
fn (mut r Reader) length() !int {
	n := int(r.int()!)
	if n < 0 || n > r.data.len - r.offset {
		return error('nbt: length ${n} at offset ${r.offset} does not fit the buffer')
	}
	return n
}

fn (mut r Reader) read_varuint32() !u32 {
	mut value := u32(0)
	mut shift := u32(0)
	for shift < 35 {
		b := r.u8()!
		value |= u32(b & 0x7f) << shift
		if b & 0x80 == 0 {
			return value
		}
		shift += 7
	}
	return error('nbt: varuint32 did not terminate')
}

fn (mut r Reader) read_varint32() !i32 {
	ux := r.read_varuint32()!
	mut x := i32(ux >> 1)
	if ux & 1 != 0 {
		x = ~x
	}
	return x
}

fn (mut r Reader) read_varuint64() !u64 {
	mut value := u64(0)
	mut shift := u64(0)
	for shift < 70 {
		b := r.u8()!
		value |= u64(b & 0x7f) << shift
		if b & 0x80 == 0 {
			return value
		}
		shift += 7
	}
	return error('nbt: varuint64 did not terminate')
}

fn (mut r Reader) read_varint64() !i64 {
	ux := r.read_varuint64()!
	mut x := i64(ux >> 1)
	if ux & 1 != 0 {
		x = ~x
	}
	return x
}

fn (mut r Reader) read_string() !string {
	length := if r.encoding == .network_little_endian {
		int(r.read_varuint32()!)
	} else {
		int(r.fixed(2)!)
	}
	return r.read_raw(length)!.bytestr()
}

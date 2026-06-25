module nbt

import math

struct Reader {
	data []u8
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

fn (mut r Reader) le_i16() !i16 {
	r.need(2)!
	v := u16(r.data[r.offset]) | (u16(r.data[r.offset + 1]) << 8)
	r.offset += 2
	return i16(v)
}

fn (mut r Reader) le_u32() !u32 {
	r.need(4)!
	v := u32(r.data[r.offset]) | (u32(r.data[r.offset + 1]) << 8) | (u32(r.data[r.offset + 2]) << 16) | (u32(r.data[r.offset + 3]) << 24)
	r.offset += 4
	return v
}

fn (mut r Reader) le_u64() !u64 {
	r.need(8)!
	mut v := u64(0)
	for i in 0 .. 8 {
		v |= u64(r.data[r.offset + i]) << (u64(i) * 8)
	}
	r.offset += 8
	return v
}

fn (mut r Reader) le_f32() !f32 {
	return math.f32_from_bits(r.le_u32()!)
}

fn (mut r Reader) le_f64() !f64 {
	return math.f64_from_bits(r.le_u64()!)
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
	length := int(r.read_varuint32()!)
	return r.read_raw(length)!.bytestr()
}

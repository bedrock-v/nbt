module nbt

pub const tag_end = u8(0)
pub const tag_byte = u8(1)
pub const tag_short = u8(2)
pub const tag_int = u8(3)
pub const tag_long = u8(4)
pub const tag_float = u8(5)
pub const tag_double = u8(6)
pub const tag_byte_array = u8(7)
pub const tag_string = u8(8)
pub const tag_list = u8(9)
pub const tag_compound = u8(10)
pub const tag_int_array = u8(11)
pub const tag_long_array = u8(12)

pub struct ByteArray {
pub mut:
	values []u8
}

pub struct IntArray {
pub mut:
	values []i32
}

pub struct LongArray {
pub mut:
	values []i64
}

pub struct List {
pub mut:
	element_type u8
	values       []Tag
}

pub struct Compound {
pub mut:
	values map[string]Tag
}

pub type Tag = ByteArray
	| Compound
	| IntArray
	| List
	| LongArray
	| f32
	| f64
	| i16
	| i32
	| i64
	| i8
	| string

pub fn tag_id(t Tag) u8 {
	return match t {
		i8 { tag_byte }
		i16 { tag_short }
		i32 { tag_int }
		i64 { tag_long }
		f32 { tag_float }
		f64 { tag_double }
		ByteArray { tag_byte_array }
		string { tag_string }
		List { tag_list }
		Compound { tag_compound }
		IntArray { tag_int_array }
		LongArray { tag_long_array }
	}
}

pub fn new_compound() Compound {
	return Compound{
		values: map[string]Tag{}
	}
}

pub fn (c &Compound) get(key string) ?Tag {
	return c.values[key] or { return none }
}

pub fn (mut c Compound) set(key string, value Tag) {
	c.values[key] = value
}

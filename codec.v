module nbt

pub struct RootTag {
pub mut:
	name string
	tag  Tag
}

pub struct DecodeResult {
pub:
	root RootTag
	read int
}

pub fn decode(data []u8) !DecodeResult {
	mut r := Reader{
		data: data
	}
	id := r.u8()!
	if id != tag_compound {
		return error('nbt: root tag must be a compound, got ${id}')
	}
	name := r.read_string()!
	tag := decode_payload(mut r, id)!
	return DecodeResult{
		root: RootTag{
			name: name
			tag:  tag
		}
		read: r.offset
	}
}

pub fn encode(root RootTag) []u8 {
	mut w := Writer{}
	w.u8(tag_id(root.tag))
	w.write_string(root.name)
	encode_payload(mut w, root.tag)
	return w.data
}

fn decode_payload(mut r Reader, id u8) !Tag {
	match id {
		tag_byte {
			return Tag(i8(r.u8()!))
		}
		tag_short {
			return Tag(r.le_i16()!)
		}
		tag_int {
			return Tag(r.read_varint32()!)
		}
		tag_long {
			return Tag(r.read_varint64()!)
		}
		tag_float {
			return Tag(r.le_f32()!)
		}
		tag_double {
			return Tag(r.le_f64()!)
		}
		tag_byte_array {
			length := int(r.read_varint32()!)
			return Tag(ByteArray{
				values: r.read_raw(length)!
			})
		}
		tag_string {
			return Tag(r.read_string()!)
		}
		tag_list {
			element_type := r.u8()!
			length := int(r.read_varint32()!)
			mut values := []Tag{cap: length}
			for _ in 0 .. length {
				values << decode_payload(mut r, element_type)!
			}
			return Tag(List{
				element_type: element_type
				values:       values
			})
		}
		tag_compound {
			mut values := map[string]Tag{}
			for {
				child_id := r.u8()!
				if child_id == tag_end {
					break
				}
				name := r.read_string()!
				values[name] = decode_payload(mut r, child_id)!
			}
			return Tag(Compound{
				values: values
			})
		}
		tag_int_array {
			length := int(r.read_varint32()!)
			mut values := []i32{cap: length}
			for _ in 0 .. length {
				values << r.read_varint32()!
			}
			return Tag(IntArray{
				values: values
			})
		}
		tag_long_array {
			length := int(r.read_varint32()!)
			mut values := []i64{cap: length}
			for _ in 0 .. length {
				values << r.read_varint64()!
			}
			return Tag(LongArray{
				values: values
			})
		}
		else {
			return error('nbt: unknown tag id ${id}')
		}
	}
}

fn encode_payload(mut w Writer, t Tag) {
	match t {
		i8 {
			w.u8(u8(t))
		}
		i16 {
			w.le_i16(t)
		}
		i32 {
			w.write_varint32(t)
		}
		i64 {
			w.write_varint64(t)
		}
		f32 {
			w.le_f32(t)
		}
		f64 {
			w.le_f64(t)
		}
		ByteArray {
			w.write_varint32(i32(t.values.len))
			w.write_raw(t.values)
		}
		string {
			w.write_string(t)
		}
		List {
			w.u8(t.element_type)
			w.write_varint32(i32(t.values.len))
			for value in t.values {
				encode_payload(mut w, value)
			}
		}
		Compound {
			for key, value in t.values {
				w.u8(tag_id(value))
				w.write_string(key)
				encode_payload(mut w, value)
			}
			w.u8(tag_end)
		}
		IntArray {
			w.write_varint32(i32(t.values.len))
			for value in t.values {
				w.write_varint32(value)
			}
		}
		LongArray {
			w.write_varint32(i32(t.values.len))
			for value in t.values {
				w.write_varint64(value)
			}
		}
	}
}

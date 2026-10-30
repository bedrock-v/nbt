module nbt

pub struct RootTag {
pub mut:
	name string
	tag  Tag
}

// Encoding is the form NBT is written in.
pub enum Encoding {
	// network_little_endian is what Bedrock sends over the network: ints, longs
	// and lengths are varints.
	network_little_endian
	// little_endian is what Bedrock writes to disk (LevelDB worlds) and hashes
	// block states over: every number has a fixed size.
	little_endian
	// big_endian is the fixed size form Java Edition uses and some Bedrock data
	// files are distributed in.
	big_endian
}

// max_fixed_string is the longest string, in bytes, the fixed size forms can
// hold. Their string length is a u16.
pub const max_fixed_string = 65535

@[params]
pub struct Options {
pub:
	encoding Encoding = .network_little_endian
}

pub struct DecodeResult {
pub:
	root RootTag
	read int
}

pub fn decode(data []u8, opts Options) !DecodeResult {
	mut r := Reader{
		data:     data
		encoding: opts.encoding
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

// encode writes a root tag. In the fixed size forms a string longer than
// max_fixed_string can't be written and encode panics on one rather than
// write NBT that misreads everything after it. encode_checked returns that as
// an error instead.
pub fn encode(root RootTag, opts Options) []u8 {
	return encode_checked(root, opts) or { panic(err) }
}

// encode_checked writes a root tag, or fails on one the encoding can't hold.
pub fn encode_checked(root RootTag, opts Options) ![]u8 {
	mut w := Writer{
		encoding: opts.encoding
	}
	w.u8(tag_id(root.tag))
	w.write_string(root.name)!
	encode_payload(mut w, root.tag)!
	return w.data
}

fn decode_payload(mut r Reader, id u8) !Tag {
	match id {
		tag_byte {
			return Tag(i8(r.u8()!))
		}
		tag_short {
			return Tag(r.short()!)
		}
		tag_int {
			return Tag(r.int()!)
		}
		tag_long {
			return Tag(r.long()!)
		}
		tag_float {
			return Tag(r.float()!)
		}
		tag_double {
			return Tag(r.double()!)
		}
		tag_byte_array {
			length := r.length()!
			return Tag(ByteArray{
				values: r.read_raw(length)!
			})
		}
		tag_string {
			return Tag(r.read_string()!)
		}
		tag_list {
			r.enter()!
			defer {
				r.depth--
			}
			element_type := r.u8()!
			length := r.length()!
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
			r.enter()!
			defer {
				r.depth--
			}
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
			length := r.length()!
			mut values := []i32{cap: length}
			for _ in 0 .. length {
				values << r.int()!
			}
			return Tag(IntArray{
				values: values
			})
		}
		tag_long_array {
			length := r.length()!
			mut values := []i64{cap: length}
			for _ in 0 .. length {
				values << r.long()!
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

fn encode_payload(mut w Writer, t Tag) ! {
	match t {
		i8 {
			w.u8(u8(t))
		}
		i16 {
			w.short(t)
		}
		i32 {
			w.int(t)
		}
		i64 {
			w.long(t)
		}
		f32 {
			w.float(t)
		}
		f64 {
			w.double(t)
		}
		ByteArray {
			w.int(i32(t.values.len))
			w.write_raw(t.values)
		}
		string {
			w.write_string(t)!
		}
		List {
			w.u8(t.element_type)
			w.int(i32(t.values.len))
			for value in t.values {
				encode_payload(mut w, value)!
			}
		}
		Compound {
			for key, value in t.values {
				w.u8(tag_id(value))
				w.write_string(key)!
				encode_payload(mut w, value)!
			}
			w.u8(tag_end)
		}
		IntArray {
			w.int(i32(t.values.len))
			for value in t.values {
				w.int(value)
			}
		}
		LongArray {
			w.int(i32(t.values.len))
			for value in t.values {
				w.long(value)
			}
		}
	}
}

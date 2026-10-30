module nbt

fn every_tag() RootTag {
	mut inner := new_compound()
	inner.set('nested', Tag(i32(-2)))
	mut c := new_compound()
	c.set('byte', Tag(i8(-5)))
	c.set('short', Tag(i16(-12345)))
	c.set('int', Tag(i32(-2147483648)))
	c.set('long', Tag(i64(-1234567890123456789)))
	c.set('float', Tag(f32(1.5)))
	c.set('double', Tag(f64(-2.25)))
	c.set('bytes', Tag(ByteArray{
		values: [u8(1), 2, 255]
	}))
	c.set('string', Tag('minecraft:stone'))
	c.set('list', Tag(List{
		element_type: tag_int
		values:       [Tag(i32(7)), Tag(i32(-7))]
	}))
	c.set('compound', Tag(inner))
	c.set('ints', Tag(IntArray{
		values: [i32(1), -1, 2147483647]
	}))
	c.set('longs', Tag(LongArray{
		values: [i64(1), -1, 9223372036854775807]
	}))
	return RootTag{
		name: 'root'
		tag:  Tag(c)
	}
}

fn test_every_tag_round_trips_in_each_encoding() {
	root := every_tag()
	for encoding in [Encoding.network_little_endian, .little_endian, .big_endian] {
		data := encode(root, encoding: encoding)
		res := decode(data, encoding: encoding) or { panic('${encoding}: ${err}') }
		assert res.read == data.len, '${encoding} left bytes unread'
		assert res.root.name == 'root'
		assert encode(res.root, encoding: encoding) == data, '${encoding} changed on the way back'
		c := res.root.tag as Compound
		assert c.get('int')? as i32 == -2147483648, '${encoding} lost the sign of an int'
		assert c.get('long')? as i64 == -1234567890123456789, '${encoding} lost a long'
		assert c.get('short')? as i16 == -12345, '${encoding} lost a short'
		assert c.get('double')? as f64 == -2.25, '${encoding} lost a double'
	}
}

fn test_the_fixed_forms_are_laid_out_as_minecraft_expects() {
	mut c := new_compound()
	c.set('a', Tag(i32(-2)))
	root := RootTag{
		tag: Tag(c)
	}
	assert encode(root, encoding: .little_endian) == [u8(0x0a), 0x00, 0x00, 0x03, 0x01, 0x00,
		`a`, 0xfe, 0xff, 0xff, 0xff, 0x00]
	assert encode(root, encoding: .big_endian) == [u8(0x0a), 0x00, 0x00, 0x03, 0x00, 0x01,
		`a`, 0xff, 0xff, 0xff, 0xfe, 0x00]
}

fn test_a_list_longer_than_its_input_is_refused() {
	data := [u8(0x0a), 0x00, 0x00, 0x09, 0x00, 0x01, `l`, 0x03, 0x7f, 0xff, 0xff, 0xff]
	if _ := decode(data, encoding: .big_endian) {
		assert false, 'a list longer than its input was decoded'
	}
}

fn test_a_string_too_long_for_a_fixed_form_is_refused() {
	mut c := new_compound()
	c.set('s', Tag('x'.repeat(max_fixed_string + 1)))
	root := RootTag{
		tag: Tag(c)
	}
	for encoding in [Encoding.little_endian, .big_endian] {
		if _ := encode_checked(root, encoding: encoding) {
			assert false, '${encoding} wrote a string its u16 length cannot hold'
		}
	}
	encode_checked(root)!
}

fn test_only_an_empty_list_of_end_tags_is_valid() {
	mut c := new_compound()
	c.set('empty', Tag(List{
		element_type: tag_end
	}))
	root := RootTag{
		tag: Tag(c)
	}
	for encoding in [Encoding.network_little_endian, .little_endian, .big_endian] {
		data := encode(root, encoding: encoding)
		res := decode(data, encoding: encoding) or { panic('${encoding}: ${err}') }
		assert encode(res.root, encoding: encoding) == data
	}
	data := [u8(0x0a), 0x00, 0x00, 0x09, 0x00, 0x01, `l`, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00]
	if _ := decode(data, encoding: .big_endian) {
		assert false, 'a list of end tags with an element was decoded'
	}
}

fn test_a_number_cut_short_is_refused() {
	values := [Tag(i16(1)), Tag(i32(1)), Tag(i64(1)), Tag(f32(1)), Tag(f64(1))]
	for encoding in [Encoding.little_endian, .big_endian] {
		for value in values {
			mut c := new_compound()
			c.set('v', value)
			data := encode(RootTag{ tag: Tag(c) }, encoding: encoding)
			if _ := decode(data[..data.len - 2], encoding: encoding) {
				assert false, '${encoding} read a ${value.type_name()} past the end of its input'
			}
		}
	}
}

fn nested_lists(n int) []u8 {
	mut data := [u8(0x0a), 0x00, 0x09, 0x01, `l`]
	for _ in 1 .. n {
		data << [u8(0x09), 0x02]
	}
	data << [u8(0x00), 0x00, 0x00]
	return data
}

fn test_nbt_nested_past_the_limit_is_refused_not_a_crash() {
	decode(nested_lists(511))!
	if _ := decode(nested_lists(512)) {
		assert false, 'lists nested past the limit were decoded'
	}
	if _ := decode(nested_lists(200_000)) {
		assert false, 'lists nested 200,000 deep were decoded'
	} else {
		assert err.msg().contains('deeper'), 'refused for another reason: ${err}'
	}
}

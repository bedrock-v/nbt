# nbt

A standalone V library for Minecraft's NBT format, in the three forms Bedrock
uses:

| Encoding | Used for |
|----------|----------|
| `network_little_endian` (default) | packets |
| `little_endian` | world saves (LevelDB) and block state hashes |
| `big_endian` | Java Edition and some distributed data files |

## Format

Network NBT encoding:

| Tag | Encoding |
|-----|----------|
| Byte (1) | 1 byte |
| Short (2) | LE int16 |
| Int (3) | zigzag varint (varint32) |
| Long (4) | zigzag varint (varint64) |
| Float (5) | LE f32 |
| Double (6) | LE f64 |
| ByteArray (7) | zigzag varint length + bytes |
| String (8) | varuint32 length + UTF-8 bytes |
| List (9) | element type byte + zigzag varint length + elements |
| Compound (10) | (type byte, name, payload)\* + TAG_End |
| IntArray (11) | zigzag varint length + zigzag varints |
| LongArray (12) | zigzag varint length + zigzag varints |

Names are always written as `String` (with a varuint32 length prefix).

The fixed size forms differ from the table: Short is 2 bytes, Int and every
length are 4, Long is 8, and a String's length is a u16, so a string can be at
most 65535 bytes long. `little_endian` writes them least significant byte first,
`big_endian` most significant first.

## API

```v
import nbt

// Build
mut c := nbt.new_compound()
c.set('name', nbt.Tag('Steve'))
c.set('health', nbt.Tag(i16(20)))

root := nbt.RootTag{ name: '', tag: nbt.Tag(c) }

// Encode
data := nbt.encode(root)
disk := nbt.encode(root, encoding: .little_endian)
// encode panics on a string longer than 65535 bytes in the fixed size forms;
// encode_checked returns that as an error.
checked := nbt.encode_checked(root, encoding: .little_endian)!

// Decode (read = number of bytes consumed; for advancing a position within a stream)
res := nbt.decode(data)!
compound := res.root.tag as nbt.Compound
health := compound.get('health') or { nbt.Tag(i16(0)) } as i16
```

`Tag` is a sum type with the following variants:
`i8, i16, i32, i64, f32, f64, string, ByteArray, List, Compound, IntArray, LongArray`.

## Build

```bash
v -shared -skip-unused .
```

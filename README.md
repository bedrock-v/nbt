# nbt

A standalone V library for Minecraft Bedrock Edition's network (little-endian /
varint) NBT format.

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

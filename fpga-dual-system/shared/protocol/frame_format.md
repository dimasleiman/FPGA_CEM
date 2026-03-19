# UART Frame Format

The UART link carries one fixed 5-byte frame per transmitted sample.

## Byte Layout

| Byte Index | Name         | Value / Meaning |
|------------|--------------|-----------------|
| 0          | Header       | `x"AA"` |
| 1          | Sample[11:4] | Upper 8 bits of the 12-bit sample |
| 2          | Sample[3:0]  | Lower nibble in bits `[3:0]`, bits `[7:4]` are `0` |
| 3          | Flags        | Bit 0 = warning, bit 1 = error, all others `0` |
| 4          | Footer       | `x"55"` |

## Sample Reconstruction

The receiver reconstructs the 12-bit value as:

```text
sample_value = byte1 & byte2(3 downto 0)
```

## Flag Meaning

- `warning = 1`: sample is in the warning range
- `error = 1`: sample is in the error range
- both flags low: sample is in the normal range

In this starter design, malformed frames are ignored by the decoder.

# NORD-10 micro code reference dumps

The two files here are the ground truth for the NORD-10 assembler in this
project. `NORD-10.uc` and `NORD-10-CE.uc` in the folder above must assemble
to them byte for byte; `TestND110/TestND10RoundTrip.cs` checks that.

| File | Words | What it is |
|---|---|---|
| `NORD-10-1K-prom.hex` | 1024 | The standard NORD-10 micro program, the 1k x 32-bit ROM that ND-06.010.01 "NORD-10/S MICROPROGRAM" describes. |
| `NORD-10-CE-4K-prom4k.hex` | 4096 | The 4k x 32-bit ROM of the NORD-10/CE: the standard micro program in words 0000-1777 (octal) and the extension in 2000-7777. |

Format: one 32-bit word per line as eight uppercase hexadecimal digits, LF
line ends, word 0 first. Bit 31 is the leftmost bit of the micro word.

## Where they come from

Both files are copies of `prom.hex` and `prom4k.hex` from Anders Magnusson's
`nord10-microcode` tool set (the `ragge/norsk_data` repository), committed
there on 2024-03-30. That repository does not say which machine the PROMs
were read from. Its README calls the 4k file "4k (CE extension)" and the
micro code emulator in the same set calls it "commercial microcode".

SHA-1 of the copies, identical to the originals:

```
3a6e71884d26c883b248e1d0b6732c60e3686665  NORD-10-1K-prom.hex
f3189148c10bf2c7eabd9f6a87cdea6b9872f9cf  NORD-10-CE-4K-prom4k.hex
```

## How the two relate

Compared word by word, the first 1024 words of the 4k file equal the 1k file
except for one word: address 1064 (octal) is `53108C9C` in the 1k file and
`43108C9C` in the 4k file, one bit, bit 28. In the 1k file that bit gives the
INTERBLOCK word an ALU select (bits 28-25) of 11 octal, a value the manual's
table 2.1 does not list; in the 4k file the select is 1, PLUS. Which of the
two is a read error is not known.

Words 2000-7777 of the 4k file are all real code, no fill. The user
instructions USER0..USER3 (op codes 140100, 140300, 140500, 140700) have
their entry points at 2200-2203, so they exist only in the 4k ROM; the
reference emulator treats an entry point beyond the loaded ROM as an
illegal instruction.

## What confirms the manual matches the dump

The label table in ND-06.010.01 section 3.3 lists 153 labels with their ROM
addresses. 150 of those addresses are the targets of JMP or CJMP words in the
1k dump. That is why the `.uc` sources carry the manual's label names.

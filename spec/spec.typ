#set text(font: "IBM Plex Mono")
#set page(paper: "a4")
#show raw: set text(font: "Jetbrains Mono", size: 1em)
#show table: set table(inset: 10pt)

#align(left)[
  *Document*: Specification of the ThetaChip ISA\
  *Last update*: #datetime.today().display()\
  #image("boxtheta.svg", format: "svg", )
]

#pagebreak()

#set page(numbering: "I")
#counter(page).update(1)
#let version = "2025-11-25-draft"
= Revision history

#table(
  columns: 3,
  table.header([Author], [Date], [Summary]),
  [Matheus Xavier], [2025-11-19], [Initial specification.],
  [Matheus Xavier], [2025-11-25], [Include instruction format section.],
)

#line(length: 100%, end: none)

#metadata(())<front_matter>

#pagebreak()
= Table of contents
#outline()

#pagebreak()
#set page(footer: context
[
  #align(right)[#sym.copyright #datetime.today().year() BoxTheta, all rights reserved. -- #counter(page).display(), #version]
]
)

// ------------
// Content
// ------------

#set page(numbering: "1")
#counter(page).update(1)
= General description

The ThetaChip is a general purpose RISC
#link("https://en.wikipedia.org/wiki/Von_Neumann_architecture",
[Von Neumann architecture]
)
design, it is intended to be flexible and is 64 bit wide but allows for easy use of 128-bit values using the combined registers
techniques described further along in this document.

#box(inset: 10pt, stroke: black)[
  Bitfields are specified in a `start + (span - 1)` form, i.e

  let $S_i$ be the start and $n$ be the span then the bits of a field will be:\
  $S_i .. S_(n-1)$
]

#set heading(numbering: "1.1.a")

= Registers<registers>
The cpu has distinct types of registers a listing of these types and their respective registers is provided bellow.

== General purpose registers
The cpu provides 63 general purpose registers named `r1` to `r63`, all general purpose
registers are 64-bit wide. `r0` is a special register described in @special_regs.

=== Combination registers<combination_regs>
Combination registers are *fixed* combinations of the high 32 of the 63 general purpose registers and are organized as follows,

- 16 double wide (128-bit) `rd_0` to `rd_15`
- 8 quad wide (256-bit) `rq_0` to `rq_7`
- 4 oct wide (512-bit) `ro_0` to `ro_3`
- 2 hexa wide (1024-bit) `rh_0` and `rh_1`

The `oct` and `hexa` are optional and the flag `CPU_COMBO_REGS_EXT` in the `sts` register allows to verify
if support for the feature was synthesized.

== Special registers<special_regs>
The special registers are:
/ r0: always reads 0, writes are ignored but raise no error;
/ jve: jump vector, used by all variants of the jump opcode except `jimm`;
/ pic: program index counter;
/ six: stack index;
/ sts: status register which is a bitfield;
/ non, vrb: noun and verb, see @noun_verb for an explanation;

All special registers are 64-bit wide, except for the `non` and `vrb` registers, they correspond to
the lower and upper half respectively of an internal 32-bit register, and are thus 16-bit wide each.

=== Bitmap of the sts register
#figure(
table(
  columns: 4,
  table.header([Start],[Span], [Name],[Notes]),
  [0], [8], [CPU_REV_MINOR], [],
  [8], [8], [CPU_REV_MINOR], [],
  [16], [16], [ERR_CODE], [See @errors],
  [32], [2], [PRIV_LVL], [See @priv_levels],
  [34], [1], [CPU_COMBO_REGS_EXT], [See @combination_regs],
  [35], [1], [ALU_CMP_RES], [Compare result],
  [36], [1], [ALU_OVERFLOW], [Overflow],
  [--], [63], [--], [_Unspecified bits are_ *Reserved*]
),
caption: [sts register bitmap]
)<sts_bitmap>

#box(inset: 10pt, stroke: black)[
  / Reserved: means you should not modify the values read from the register;
]

=== Privilege levels <priv_levels>
The supported privilege modes are:\

#box(inset: 10pt, stroke: black)[
/ 00: Supervisory
/ 01: Kernel
/ 10: Unused, the cpu will never be in this mode
/ 11: Userland
]\
/ MMU: Memory Management Unit
/ IOMU: IO Management Unit
/ INTMU: Intettup Management Unit
/ PMC: Power Management Complex
/ iv: interrupt vector

*Kernel* mode allows full control of the processor, including the MMU, IOMU, INTMU and PMC.
Entered via jump from the boot supervisor code, or the interrupt vector 0 for syscalls,
most verb-noun pairs are available to kernel code. Kernel code has access to any instructions
marked `PL_K` and lower in the opcode reference, attempting to execute an opcode tagged
`PL_S` will immediately halt the CPU and assert the `CPU_RST_REQ` signal (*ONLY* in kernel mode).

*Userland* has a linear address space translated by the MMU, any access to an address
in an unmapped page will result in a `ERR_VIOLATION_PAGE` error, and control being returned
to the kernel mode via iv 1, if userland code attempts to execute any instruction marked
other than `PL_U` it will result in `ERR_VIOLATION_PRIVILEGE` and the kernel getting control
via iv 1.

Userland code can make IO operations via DMA requests allowable as per the IOMU configuration
`ERR_VIOLATION_IO` will be raised like the previously described faults.

*Supervisory* has unrestricted access to the system, and can execute any instructions, and
can access all verb-noun pairs, see @sup_mode for further detail.

== Noun and verb registers<noun_verb>
This system allows the baking at synthesis time of extra information in the form of 64-bit values,
addressed in a `row x column` form such as cpu vendor information, an annex shall be provided with
the required noun and verbs.

A sample assembly program to retrieve the cpu vendor string:
```asm
mov r0, r1; load 0 into r1
mov r1, non; load the lower 16-bits of r1 into non
mov #0x1, r1; load the immediate 1 into r1
mov r1, vrb; same as line 2 but for vrb
rdnv; reads the noun and verb, clobbers r62 and r64 with the null terminated string
```

#pagebreak()

= Error codes<errors>
Error codes can be broken up into 4-bit tags:

#figure(
table(
  columns: 2,
  inset: 10pt,
  table.header([Prefix (0b)], [Name]),
  [0b000], [VIOLATION],
  [0b001], [INVALID],
  [0b010], [HW_FAULT],
  [0b011], [FATAL],
  [--], [RESERVED],
),
caption: [Error type tags])<error_tags>

A full list of errors is provided in the errors.csv that should accompany
this document, a copy can be found at @errors_list.


= Instructions<instructions>
Intructions are with the exception of immediate loads always 32-bit wide made up of 3 fields:
#figure(
  table(
    columns: 3,
    [20-bit], [6-bit], [6-bit],
    [opcode], [reg A], [reg B]
  ),
  caption: [Instruction format]
)

Immediate load instructions follow the same layout, plus 4, 8 or 64 bytes, this allows for
the pipeline to be a slotted design, where each slot is 32-bit wide, and the longest
instruction possible would be 17 slots wide (512-bit immediate).


#pagebreak()

// ------------
// Back matter
// ------------

#metadata(())<back_matter>
#set page(numbering: "I")
#set heading(numbering: "I.A.a")
= Supervisory mode annex<sup_mode>
#pagebreak()
= Errors code full table<errors_list>
#let errors_table = csv("errors.csv")

#table(
  columns: 2,
  table.header([Error code (HEX)],[Symbol]),
  ..errors_table.flatten(),
)

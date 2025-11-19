#set text(font: "IBM Plex Mono")
#show raw: set text(font: "Jetbrains Mono", size: 1em)

#align(left)[
  *Document*: Specification of the ThetaChip ISA\
  *Last update*: #datetime.today().display()\ 
  #image("boxtheta.svg", format: "svg", )
]

#pagebreak()

= Revision history

#table(
  columns: 3,
  align: horizon,
  inset: 10pt,
  table.header([Author], [Date], [Summary]),
  [Matheus Xavier], [2025-11-19], [Initial specification.]
)

#line(length: 100%, end: none)

== Glossary

/ Bitfield: a value whose bits are interpreted independently or subgrouped;
/ Datawidth: the size in bits of the internal bus and the width of the regular registers;

#pagebreak()
// Insert TOC here

= TOC GOES HERE

#pagebreak()
#counter(page).update(1)
#set page(footer: context 
[
  #align(right)[#sym.copyright #datetime.today().year() BoxTheta, all rights reserved. -- #counter(page).display()]
]
)

= General description

The ThetaChip is a general purpose RISC
#link("https://en.wikipedia.org/wiki/Von_Neumann_architecture",
[Von Neumann architecture]
)
design, it is intended to be flexible and is parametrized for 32, 64 and 128 bit.

#box(inset: 10pt, stroke: black)[
  Note: This document refers to the chosen width as synthesis width or _sw_ for short,
  where _sw_ appears replace with your chosen width, in formulas it will be shown as
  $W_s$.
]

#box(inset: 10pt, stroke: black)[
  Bitfields are specified in a `start + (span - 1)` form, i.e
  
  let $S_i$ be the start and $n$ be the span then the bits of a field will be:\
  $S_i .. S_(n-1)$
]

#set heading(numbering: "1.1.a")

= Registers<registers>
The cpu provides 32 general purpose registers named `r1` to `r32`, all general purpose
registers are _sw_ wide.

== Special registers<special_regs>
The special registers are:
/ r0: always reads 0, writes are ignored but raise no error;
/ jve: jump vector, used by all variants of the jump opcode except `jimm`;
/ pic: program index counter;
/ sbp: stack base pointer;
/ six: stack index;
/ sts: status register which is a bitfield;
/ non, vrb: noun and verb, see @noun_verb for an explanation;

All special registers are _sw_ wide except the `sts` register as it is
a bitfield 64-bit wide, independent of _sw_.

=== Bitmap of the sts register
#table(
  columns: 4,
  inset: 10pt,
  table.header([Start],[Span], [Name],[Notes]),
  [0], [8], [CPU_REV_MINOR], [],
  [8], [8], [CPU_REV_MINOR], [],
  [16], [16], [ERR_CODE], [See @errors],
  [32], [2], [PRIV_LVL], [See @priv_levels],
  [--], [--], [--], [_Unspecified bits are_ *Reserved*]
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
in an unmapped page will result in a `ERR_PAGE_FAULT` error, and control being returned
to the kernel mode via iv 1, if userland code attempts to execute any instruction marked
other than `PL_U` it will result in `ERR_PRIV_VIOLATION` and the kernel getting control
via iv 1.

Userland code can make IO operations via DMA requests allowable as per the IOMU configuration
`ERR_IO_VIOLATION` will be raised like the previously described faults.

*Supervisory* has unrestricted access to the system, and can execute any instructions, and
can access all verb-noun pairs, see @sup_mode for further detail.

== Noun and verb registers<noun_verb>
These are special registers to 

= Error codes<errors>
= Supervisory mode annex<sup_mode>
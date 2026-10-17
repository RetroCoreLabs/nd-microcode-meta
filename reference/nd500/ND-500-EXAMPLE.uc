# ND-500 micro code example - exercises the ND500Compiler feature set.
# Syntax per ND-05.012.01 ch. 14: mnemonics separated by spaces, ';' ends the
# instruction, '#' at a whitespace boundary starts a comment ('#' inside a
# token is a register select, e.g. B,X#0), 'nnnn/' sets the address, all
# constants are octal.
# The compiled .CODE file is a PACKED18 8K control store image - open it in
# the nd500uc web disassembler to inspect the result.

# Word 0: CS0 (bits 15-0) is left free so the assembler stamps the assembly
# date there (year/month/day), like the original N500 assembler did.
0/ NEXT ;

# Basic ALU operation: TOS := P + X0
START:  A,P B,X#0 ALU,A+B D,TOS NEXT ;

# Short argument: A-operand is the sign-extended octal constant 123456
        A,XD,SARG 123456 B,X#0 ALU,A+B D,X#0 NEXT ;

# Long argument: 32-bit constant 000012,034567 to TOS
        A,XD,LARG 12,34567 D,TOS NEXT ;

# Conditional sequence: on zero jump to START, else fall through
        COND,ZRO C,SEQ JMP START F,NEXT ;

# Conditional ALU: A+B when the condition is true, A-B when false
        C,ALU ALU,A+B F,A-B A,P B,DATA D,TOS NEXT ;

# Subroutine call (forward label reference)
        JSR SUB1 ;

# Memory read, one byte, byte data type
        MEM,RD1 TYP,BY NEXT ;

# Subroutine placed at octal address 2000; decrement loop counter and return
2000/ SUB1: LCDECR POPRET ;

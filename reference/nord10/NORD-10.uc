%   NORD-10 MICROPROGRAM  -  standard 1k x 32 bit ROM
%
%   This is the micro program listed in ND-06.010.01 "NORD-10/S MICROPROGRAM",
%   section 3.4, in the form the listing prints it: address column, label,
%   MICMAC mnemonics, comment. The labels, the comment text and the order of
%   the mnemonics on each line were read from the listing pages of that
%   manual. The bits are the truth of the PROM dump NORD-10-REFERENCE/NORD-10-1K-prom.hex:
%   every line assembles to exactly the word the dump holds
%   (TestND110/TestND10RoundTrip.cs checks that), and where the page could
%   not be read with certainty the line carries the disassembler's mnemonics
%   for the dump word instead, which name the same bits.
%
%   Two words of the dump are not what the listing prints:
%     1064  the dump has bit 28 set (written here as the octal constant
%           2000000000); the listing and the 4k ROM read IARM PLUS
%     1774  the listing labels this word MCLS, a name the listing also gives
%           to 0331 (the one the code jumps to); it stays a comment here
%
%   Notation: "->" stands for the arrow of the listing, "ΔH" is the
%   sign-extended low byte of H. A bare octal number ORs into the word.
%
0000          JMP 1402                          %STOP
0001          JMP 1401                          %MASTER CLEAR

0002  %ROUTINE TO CONVERT FROM FLOATING NUMBER IN T,A,D-REG,
0002  %TO INTEGER NUMBER IN A-REG
0002  %D-REG AND T-REG IS SET TO ZERO
0002  DNZC,   ARM PLUS A,DH B,T D,A             %T + ΔH -> A
0003          ARM PLUS D,SS B,B4 A,A            %A + 20 -> SS
0004          LOGM AND B,B16 A,SS               %TEST BIT 16 IN SS-REG
0005          CJMP ZERO ZTAD                    %JMP IF OVERFLOW
0006          LOGM AND D,D B,B16 A,A            %TEST BIT 16 IN A-REG
0007          CJMP NZERO FETCZ                  %JMP IF OVERFLOW
0010          LOGM ADIR A,A D,SC                %SET SHIFTCOUNT
0011          LOOP SHR SHZE TSC0                %SHIFT RIGHT TO SC = 0
0012          LOGM BDIR B,SH D,A                %SH -> A
0013          LOGM BDIR B,T                     %TEST SIGN
0014          CARM SNEG BMINA A,A B,Z D,A       %INVERT IF SIGN NEG
0015          LOGM CFC ADIR A,Z D,T             %0 -> T, FETCH
0016  SRB,    ARM BM1 B,X D,P CPTR              %STORE BLOCK, X -1 -> CP
0017          LOGM ADIR D,P A,SP                %UNSAVE CP
0020          ILOGM ADIR ORIN2 A,SP             %READ SP SPES, LEV
0021          LOGM CWR1 A,SP                    %STORE SP
0022          ILOGM ADIR ORIN2 A,X              %READ X
0023          ARM CWR1 A,SP
0024          ILOGM ADIR ORIN2 A,T              %READ T
0025          ARM CWR1 A,SP
0026          ILOGM ADIR ORIN2 A,A              %READ A
0027          ARM CWR1 A,SP
0030          ILOGM ADIR A,D ORIN2              %READ D
0031          ARM CWR1 A,SP
0032          ILOGM ADIR ORIN2 A,L              %READ L
0033          ARM CWR1 A,SP
0034          ILOGM ADIR ORIN2 A,S              %READ STATUS
0035          ARM CWR1 A,SP
0036          ILOGM ADIR ORIN2 A,B              %READ B
0037          LOGM CWR1 A,SP
0040          ARM BM1 CFC                       %FETCH
0041  MINC,   LOGM ADIR A,R D,P                 %R -> CP
0042          ARM BM1 B,P D,P                   %CP -1 -> CP
0043          ARM CPTR PLUS ADD1 A,H B,Z D,SCR  %CP -> R  H + 1 -> SCR
0044          LOGL CWR1 BDIR A,SCR B,SH D,P     %SCR -> (R + 1), SH(L) -> CP
0045          CARM ZERO CFC PLUS ADD1 A,P B,Z D,P %CP + 1 -> CP
0046  SWPCC,  LOGM ADIRC ORSW3                  %ZERO:CP + 1 -> CP
0047  SWPC,   LOGM ADIR ORSKP D,SP              %REG -> REG (ONE'COMPL)
0050          ARM ORSW3 BDI
0051          LOGM CFC ORSW2 COND CO17 ADIR A,SP

0052  %ROUTINE TO CONVERT FROM INTEGER TO FLOATING NUMBER
0052  %INTEGER IN A-REG, FLOATING IN T, A, D-REG
0052  NLZC,   LOGM ADIR A,A D,SH                %A -> SH
0053          CJMP ZERO ZTAD                    %RESULT ZERO IF A = 0
0054          ARL B,B16 PLUS A,DH D,T           %40000 + H (0-7) -> T, T -> AC(L)
0055          CJMP POS *3
0056          ARL B,B17 PLUS A,T D,T            %SET SIGN BIT, T -> AC(L)
0057          ARM B,Z BMINA A,A D,SH            %-A -> SH IF A < 0
0060          ARM BDIR B,B4 D,SC                %20 -> SC
0061          LOOP B,AC BM1 SHZE TSH31          %SHIFT LEFT TO SH31 = 1
0062          LOGL BDIR B,AC D,T                %AC -> T
0063          LOGM BDIR B,SH D,A CFC            %SH -> A, FETCH
0064  LDBC,   LOGM ADIR A,X                     %X -> AC
0065          ARM BM1 B,HAC D,SH                %1/2*AC -1 -> SH
0066          ARM CPTR PLUS A,T B,SH D,P        %T + SH -> CP, CP -> R
0067          LOGM CRR1 ADIR A,SP D,P           %(R + 1) -> H, SP -> CP
0070          LOGM AND A,X B,B0                 %TEST LEFT RIGHT
0071          CJMP ZERO LEFT
0072          ARM B,B10 D,SH                    %377 -> SH
0073          LOGM CFC AND A,H B,SH D,A         %BYTE -> A-REG, FETCH
0074  LEFT,   ARM BM1 D,SC B,B3                 %7 -> SC
0075          ARM PLUS A,H                      %H -> AC
0076          LOOP BDI BDIA SHR SHZE B,HAC TSC0
0077          LOGM BDIR CFC D,A B,HAC           %BYTE -> A-REG, FETCH
0100          ARM CW A,Z                        %STZ, ZERO -> EFFECTIVE ADDRESS
0101  FETCH,  ARM CFC                           %FETCH REQUEST
0102          ARM CW A,A                        %STA, A-REG -> EA
0103          ARM CFC                           %FETCH
0104          ARM CW A,T                        %STT, T-REG, -> EA
0105          ARM CFC                           %FETCH
0106          ARM CW A,X                        %STX, X-REG -> EA
0107          ARM CFC                           %FETCH
0110          ARM CW A,A                        %STD, A-REG -> EA
0111          JMP STDC
0112          ARM CR                            %LDD, (EA) -> H
0113          JMP LDDC
0114          ARM CW A,T                        %STF, T-REG -> EA
0115          JMP STFC                          %JUMP TO CONTINUE STF
0116          ARM CR                            %LDF, READ REQUEST
0117          JMP LDFC
0120          LOGL CR ADIR A,P D,SH             %MIN, CP -> SH          READ MEMORY
0121          JMP MINC
0122          ARM CR                            %LDA, (EA) -> H
0123          LOGM CFC ADIR A,H D,A             %H -> A, FETCH REQUEST
0124          ARM CR                            %LDT, (EA) -> H
0125          LOGM CFC ADIR A,H D,T             %H -> T, FETCH REQUEST
0126          ARM CR                            %LDX, (EA) -> H
0127          LOGM CFC ADIR A,H D,X             %H -> X, FETCH REQUEST
0130          ARM CR                            %ADD, (EA) -> H
0131          ARM CFC PLUS SACO A,H B,A D,A     %H + A -> A, FETCH
0132          ARM CR                            %SUB, (EA) -> H
0133          ARM CFC BMINA SACO A,H B,A D,A    %A - H -> A, FETCH
0134          ARM CR                            %AND, (EA) -> H
0135          LOGM CFC AND A,H B,A D,A          %A · H -> A, FETCH
0136          ARM CR                            %ORA, (EA) -> H
0137          LOGM CFC OR A,H B,A D,A           %A + H -> A, FETCH
0140  FAD,    LOGM ANDCB B,B1 A,S D,S           %STARTADD. FAD, RESET "TG"
0141          JMP FADC
0142  FSB,    LOGM ANDCB B,B1 A,S D,S           %START FSB, RESET "TG"
0143          JMP FSBC
0144  FMU,    LOGM ANDCB B,B1 A,S D,S           %START FMU, RESET "TG"
0145          JMP FMUC
0146  FDV,    LOGM ANDCB B,B1 A,S D,S           %START FDV, RESET "TG"
0147          JMP FDVC
0150  MPY,    LOGM BDIR B,B4 D,SC               %START MPY, SET SHIFTCOUNTER
0151          JMP MPYC
0152          ARM CEATR                         %JMP, EA -> R
0153          LOGM CFC ADIR A,R D,P             %R -> CP, (R) -> H, IR
0154  KONE2,  LOGM ANDCB B,BM ORBW              %0 -> SPECIFIED BIT
0155          LOGM CFC OR B,B2 A,S D,S          %1 -> K, FETCH
0156          LOGM CEATR ADIR A,P D,L           %JPL, EA -> R, CP -> L
0157          LOGM CFC ADIR A,R D,P             %R -> CP, (R) -> H, IR
0160  EXEC,   LOGM ADIR ORSKP D,SP              %REG -> SP
0161          LOGM EXOR A,H B,AC D,SS           %TEST EXEC. INSTR IN REG
0162          LOGM ANDCB A,SS B,SH
0163          CJMP ZERO FETCZ                   %JMP IF EXECUT INSTR IN REG
0164          ARM A,SP B,IR D,IO                %INSTRUC. -> IR
0165  STFC,   ARM BM1 CWR1 A,A                  %A -> (R + 1)
0166  STDC,   ARM CWR1 A,D                      %D -> (R + 1)
0167          ARM CFC
0170  IOT,    JMP PRIV IOTC                     %JMP IOT CONTINUE
0171  FETC1,  LOGL CFC BDIR B,SH D,D            %SH(L) -> D, FETCH
0172  IOX,    LOGM ADIR A,A BIO D,IO            %A-REG -> IO-BUS
0173          LOGM A,IO BIO                     %IO-BUS -> H-REG
0174          LOGM CFC ADIR A,H D,A             %H-REG -> A-REG FETCH
0175  SADC,   LOOP ORSHT SH32 TSC0              %SHIFT, TERM:SC = 0
0176          LOGM BDIR B,SH D,A                %SH -> A
0177          LOGL CFC BDIR B,SH D,D            %SH(L) -> D, FETCH
0200          ARM BMINA ORSKP                   %SKP
0201          CARM ORSKP PLUS ADD1 CFC A,Z B,P D,P %TRUE CP + 1 -> CP, FETCH
0202          LOGL BDIR CFC D,D B,2AC           %2AC(L) -> D
0203          ARM BM1 D,SH B,B6                 %EXECUTE, GENERATE MASK
0204          JMP EXEC
0205  RMPY,   LOGM ADIR ORSKP D,SP              %FIRST OPERAND -> SP , REGISTER MULTIPLY
0206          JMP MPYDC
0207  RDIV,   LOGM BDIR B,B4 D,SC               %20 - SC, REGISTER DIVIDE
0210          JMP RDIVC
0211  LDB,    LOGM ADIR A,P D,SP                %LOAD BYTE, CP -> SP
0212          JMP LDBC
0213  STB,    LOGM ADIR A,P D,SP                %STORE BYTE, SAVE CP REG
0214          JMP STBC
0215  MPX3,   ARL BM1 B,A D,SCR                 %INSTR:(A-1) * 3 -> SCRA -> AC
0216          ARL CFC PLUS A,SCR B,2AC D,X      %2 · AC + SCR -> SCR
0217          JMP IOX                           %IDENT
0220          JMP SWPC                          %SWAP
0221          JMP SWPCC                         %SWAP CM1
0222          LOGM CFC AND ORROP                %RAND, D · S -> D
0223          LOGM CFC ANDCA ORROP              %RAND CM1, D · S' -> D
0224          LOGM CFC EXOR ORROP               %REXO, DVS -> D
0225          LOGM CFC EXORC ORROP              %REXO CM1, DVS' -> D
0226          LOGM CFC OR ORROP                 %RORA, D + S -> D
0227          LOGM CFC ORCA ORROP               %OR CM1, D + S' -> D
0230          ARM CFC PLUS ORROP SACO           %RADD, COPY, EXIT, RCLR, D + S -> D
0231          ARM CFC BMAM1 ORROP SACO          %RADD CM1, D - S - 1 -> D, RDCR
0232          ARM CFC PLUS ADD1 ORROP SACO      %RADD AD1, D + S + 1 -> D, RINC
0233          ARM CFC BMINA ORROP SACO          %RADD AD1 CM1, D - S -> D  RSUB
0234          ARM PLUS ADDC CFC SACO ORROP      %RADD ADC, D + S + C -> D
0235          ARM CFC BMAM1 ADDC ORROP SACO     %RADD ADC CM1, D - S - 1 + C -> D
0236          ARM CFC PLUS ADD1 ORROP SACO      %RADD AD1 ADC, D + S + 1 -> D
0237          ARM CFC BMINA ORROP SACO          %RADD AD1 ADC CM1, D - S -> D
0240  MISS,   LOGM AND A,H B,B6                 %MST, MCL, TRA, TRR, TEST BIT 6
0241          JMP PRIV TTMMC
0242  IIPP,   JMP PRIV CIIPP                    %IOF, ION, PON, POF
0243          0
0244  WAIT,   ARM A,IO B,PID                    %READ PID
0245          JMP PRIV WAITC
0246  NLZ,    LOGM BDIR B,Z D,D                 %START NLZ, 0 -> D
0247          JMP NLZC
0250  DNZ,    LOGM ADIR D,SH A,A                %START DNZ, A -> SH
0251          JMP DNZC
0252          LOGM ADIR A,P D,SP                %LOAD/STORE REGISTER BLOCK, CP -> SP
0253          JMP PRIV SLRB
0254  MON,    LOGM BDIR B,B4 D,SCR              %MONITOR CALL, 4 -> SCR
0255          JMP MONC
0256  PUTG,   LOGM AND A,H B,B7                 %TEST IRR, IRW
0257          JMP PRIV PUTGC
0260          LOGM ADIR A,H D,SC                %SHT, H(0 - 5) -> SC
0261          LOGM ADIR A,T D,SH                %T -> SH
0262          LOOP ORSHT TSC0                   %SHIFT TO SC = 0
0263          LOGM CFC BDIR B,SH D,T            %SH -> T, (R) -> H, IR
0264          LOGM ADIR A,H D,SC                %SHD, H (0 - 5) -> SC
0265          LOGM ADIR A,D D,SH                %D -> SH
0266          LOOP ORSHT TSC0                   %SHIFT TO SC = 0
0267          LOGM CFC BDIR B,SH D,D            %SH -> D
0270          LOGM ADIR A,H D,SC                %SHA, H (0 - 5) -> SC
0271          LOGM ADIR A,A D,SH                %A -> SH
0272          LOOP ORSHT TSC0                   %SHIFT, TERMINATION:SC = 0
0273          LOGM CFC BDIR B,SH D,A            %SH -> A, (R) -> H, IR
0274          LOGM ADIR A,H D,SC                %SAD, H (0-5) -> SC
0275          LOGM ADIR A,A D,SH                %A -> SH
0276          LOGL ADIR A,D D,SH                %D -> SH (LEAST SIGNIFICANT)
0277          JMP SADC
0300          LOGM CEATR ADIR A,A               %JAP, EA -> R, TEST A
0301          CLOGM CFC POS ADIR A,R D,P        %(A > 0):R -> CP, (R) -> H, IR
0302          LOGM CEATR ADIR A,A               %JAN, EA -> R TEST A
0303          CLOGM CFC NEG ADIR A,R D,P        %(A < 0):R -> CP, (R) -> H, IR
0304          LOGM CEATR ADIR A,A               %JAZ, EA -> R, TEST A
0305          CLOGM CFC ZERO ADIR A,R D,P       %A = 0:R -> CP, (R) -> H, IR
0306          LOGM CEATR ADIR A,A               %JAF, EA -> R, TEST A
0307          CLOGM CFC NZERO ADIR A,R D,P      %(A # 0):R -> CP, (R) -> H, IR
0310          ARM CEATR BDI ADD1 B,X D,X        %JPC, X + 1 -> X, EA -> R
0311          CLOGM CFC SPOS ADIR A,R D,P       %(X > 0):R -> CP, (R) -> H, IR
0312          ARM CEATR BDI ADD1 B,X D,X        %JNC, X + 1 -> X, EA -> R
0313          CLOGM CFC SNEG ADIR A,R D,P       %(X < 0):R -> CP, (R) -> H, IR
0314          LOGM CEATR ADIR A,X               %JXZ, EA -> R, TEST X
0315          CLOGM CFC ZERO ADIR A,R D,P       %(X = 0):R -> CP
0316          LOGM CEATR ADIR A,X               %JXN, EA -> R, TEST X
0317          CLOGM CFC NEG ADIR A,R D,P        %(X < 0):R -> CP, (R) -> H, IR
0320  TTMMC,  CJMP ZERO ZIR6                    %JMP IF BIT 6 = 0
0321          LOGM AND A,H B,B7                 %TEST BIT 7
0322          CJMP ZERO TRRS                    %JMP IF BIT 7 = 0
0323  MSTS,   ARM A,IO BIR3                     %MST, REG -> H
0324          LOGM OR A,H B,A D,SP              %H + A -> SP
0325          LOGM ADIR A,SP BIR3 D,IO          %SP -> REG
0326          JMP FETCH
0327  TRRS,   LOGM A,A BIR3 D,IO ADIR           %TRR, A -> REG
0330          JMP FETCH
0331  MCLS,   ARM A,IO BIR3                     %MCL, REG -> H
0332          LOGM ANDCB A,H B,A D,SP           %N(A), H -> SP
0333          LOGM A,SP BIR3 D,IO ADIR          %SP -> REG
0334          JMP FETCH
0335  LDFC,   LOGM CRR1 ADIR A,H D,T            %H -> T, (R + 1) -> H
0336  LDDC,   LOGM CRR1 ADIR A,H D,A            %H -> A, (R + 1) -> H
0337          LOGM CFC ADIR A,H D,D             %H -> D, (R) -> H, IR
0340          LOGM CFC ADIR A,DH D,B            %H (0 - 7) -> B, FETCH
0341  FETC5,  LOGL BDIR B,AC D,D CFC            %AC (L) -> D
0342          LOGM CFC ADIR A,DH D,A            %SAA, H (0 - 7) -> A, (R) -> H, IR
0343  FETCZ,  LOGM CFC OR A,S B,B3 D,S          %1 -> Z, FETCH
0344          LOGM CFC ADIR A,DH D,T            %SAT, H(0-7) -> T, (R) -> H, IR
0345          JMP *
0346          LOGM CFC ADIR A,DH D,X            %SAX, H(0-7) -> X, (R) -> H, IR
0347  FETC3,  ARM CFC BM1 B,T D,T               %DECR, EXPONENT, FETCH
0350          ARM CFC PLUS SACO A,DH B,B D,B    %AAB, H(0-7) + B -> B (R) -> H, IR
0351          0
0352          ARM CFC PLUS SACO A,DH B,A D,A    %AAA, H (0-7) + A -> A, (R) -> H, IR
0353  GETR,   ILOGM CFC ADIR ORBWO D,A          %REG -> A, FETCH, IRR
0354          ARM CFC PLUS SACO A,DH B,T D,T    %AAT, H(0-7) + T -> T, (R) -> H, IR
0355  OVERF,  LOGM OR B,B5 A,S D,S CFC          %SET STATIC OVERF, FETCH
0356          ARM CFC PLUS SACO A,DH B,X D,X    %AAX, H(0-7) + X -> X, (R) -> H, IR
0357  FETC4,  LOGL CFC BDIR B,2AC D,D           %2 · AC(L) -> D, FETCH
0360          LOGM ANDCB B,BM ORBW CFC          %BSET ZERO.
0361  BSBSH,  LOGM OR B,BM ORBW CFC             %BSET ONE
0362          LOGM EXOR B,BM ORBW CFC           %BSET BCM
0363          JMP BSBAC                         %JMP TO BSET BAC
0364          JMP BSZC                          %JMP TO BSKP ZERO
0365          JMP BSOC                          %JMP TO BSKP ONE
0366          JMP BSKCC                         %JMP BSKP K0
0367          JMP BSKC                          %JMP BSKP K
0370          JMP BSTCC                         %JMP BSTC
0371          JMP BSTAC                         %JMP BSTA
0372          JMP BLDCC                         %JMP BLDC
0373          JMP BLDAC                         %JMP BLDA
0374          JMP BANCC                         %JMP BANC
0375          JMP BANDC                         %JMP BAND
0376          JMP BORCC                         %JMP BORC
0377          JMP BORAC                         %JMP BORA
0400          LOGM CHLEV ADIR A,P D,SP          %INTERRUPT, SAVE CP-REG
0401          LOGM CFC ADIR A,SP D,P            %SAVE CP AND FETCH ON NEW LEVEL
0402  IOTC,   LOGM ADIR A,A BIO D,IO            %A-REG -> IO-BUS
0403          LOGM A,IO BIO                     %IO-BUS -> H-REG
0404          LOGM ADIR A,H D,A                 %H -> A-REG
0405          LOGM A,IO B,PES                   %PES -> H-REG
0406          LOGM ADIR A,H                     %TEST BIT 15 PES  (N-1 SKIP)
0407          CARM CFC SNEG BDI ADD1 B,P D,P    %IF MPC 15 = 1 THEN P + 1 -> P
0410  ZIR6,   LOGM AND A,H B,B7                 %TEST BIT 7
0411          CJMP NZERO MCLS                   %JMP IF BIT 7 = 1
0412          ARM A,IO BIR3                     %TRA, REG -> H
0413          LOGM CFC ADIR A,H D,A             %H -> A, (R) -> H, IR
0414  BSKCC,  LOGM AND A,S B,B2                 %TEST K
0415          CJMP NZERO BSZC                   %JMP IF K = 1
0416  BSOC,   LOGM AND ORBWO B,BM               %TEST BIT
0417          CARM CFC NZERO BDI ADD1 B,P D,P   %IF SPECIFIED BIT = 1:CP + 1 -> CP, FETCH
0420  BSKC,   LOGM AND A,S B,B2                 %TEST K
0421          CJMP NZERO BSOC                   %JMP IF K = 1
0422  BSZC,   LOGM AND ORBWO B,BM               %TEST BIT
0423          CARM CFC ZERO BDI ADD1 B,P D,P    %IF SPECIFIED BIT = 0:CP + 1 -> CP
0424  STBC,   ARM BDI B,X                       %X -> AC
0425          ARM BM1 B,HAC D,SH                %1/2*AC - 1 -> SH
0426          ARM CPTR PLUS A,T B,SH D,P        %T + SH -> CP, CP -> R
0427          ARM PLUS A,SP B,Z D,P CRR1        %(R + 1) -> H
0430          ARM CPTR PLUS A,T B,SH D,P
0431          ARM BM1 B,B10 D,SCR               %377 -> SH
0432          LOGM AND B,B0 A,X                 %TEST LEFT RIGHT
0433          CJMP ZERO LEFTB
0434          LOGM AND A,SCR B,A D,SS           %MASK OUT RIGHT PART
0435          LOGM ADIRC A,SCR D,SH
0436          JMP STORB
0437  LEFTB,  ARM BM1 B,B3 D,SC                 %7 -> SC
0440          LOGL BDIR B,A
0441          LOOP BDI BDIA B,2AC               %SHIFT TO LEFT BYTE
0442          LOGL BDIR B,2AC D,SS
0443          LOGM ADIR A,SCR D,SH
0444  STORB,  LOGM AND A,H B,SH D,SH
0445          LOGM ADIR A,SP D,P                %SP -> CP
0446          LOGM OR A,SS B,SH D,SS            %NEW BYTE + OLD BYTE -> SS-REG
0447          LOGM CWR1 A,SS                    %STORE BYTE
0450          LOGM CFC                          %FETCH
0451  FSBC,   ARM CR BM1 B,B5 D,SS              %37 -> SS
0452          LOGM EXOR B,B17 A,H D,SCR         %EXPONENT -> SCR, INVERT BIT 17
0453          JMP FAFSC
0454  FADC,   ARM CR BM1 B,B5 D,SS              %37 -> SS
0455          LOGM ADIR A,H D,SCR               %H -> SCR
0456  FAFSC,  LOGM ANDCB B,B17 A,T D,SH         %RESET SIGN BIT
0457          LOGM ANDCB B,B17 A,SCR D,SP       %RESET SIGN BIT
0460          ARM CRR1 BMINA B,SH A,SP D,SC     %SP - SH -> SC
0461          CJMP SNEG NED1                    %JMP IF NUMB. IN MEMORY GREATEST
0462          CJMP ZERO EQUAL                   %JMP EXPONENTS EQUAL
0463          LOGM ANDCA B,AC A,SS              %TEST AC <40
0464          CJMP NZERO FETCH                  %NO MANTISS OVERLAP IF NOT ZERO
0465          LOGM CRR1 ADIR A,H D,SH           %H -> SH
0466          LOGL ADIR A,H D,SH                %H -> SH(L)
0467          LOOP SHR SH32 TGSH0 SHZE          %SHIFT RIGHT TERM:SC = 0
0470          LOGM EXOR A,SCR B,T               %TEST EQUAL SIGNS
0471          CJMP SNEG SUBF                    %JMP IF DIFFERENT SIGN
0472  ADDF,   LOGL BDIR B,SH D,SCR              %SH(L) -> SCR
0473          ARM PLUS A,SCR B,D D,D SACO       %ADD. OF LEAST MANT.
0474          ARM PLUS ADDC A,A B,SH D,A SACO   %ADD. OF MOST. MANT.
0475          CJMP GREM CRY1                    %JMP IF CRY
0476  NOCRY,  LOGM AND B,B1 A,S                 %TEST TG      * CFC is added in N12/42
0477          CJMP ZERO FETCH                   %ZERO:FINISHED
0500          LOGM CFC OR A,D B,B0 D,D
0501  CRY1,   LOGL A,D ADIR                     %D -> AC(L)
0502          LOGL BDIR B,HAC D,D               %1/2 AC(L) -> D
0503          LOGM BDIR B,HAC D,A               %1/2 AC -> A  CRY -> AA
0504          ARM PLUS B,B0 A,T D,T CFC         %T + 1 -> T, FETCH
0505  NED1,   LOGM ORC A,SS B,AC                %TEST:AC > -40
0506          CJMP NZERO NORMA2                 %NO MANTISSE OVERLAP IF NOT ZERO
0507          LOGL ADIR A,D D,SH
0510          LOGM ADIR A,A D,SH                %READ MOST SIGNIF:MANT
0511          LOGM CRR1 ADIR A,H D,SP
0512          LOGM ADIR A,H D,D
0513          LOGM ADIR A,SP D,A
0514          LOOP SHR SH32 TGSH0 SHZE TSC0     %SHIFT RIGHT. TERMIN; SC = 0
0515          LOGM EXOR A,SCR B,T               %TEST FOR EQUAL SIGN
0516          CJMP SNEG SUBF2                   %JMP TO SUBTRACTION IF UNEQUAL
0517          LOGM ADIR A,SCR D,T
0520          JMP ADDF
0521  NORMA2, LOGM CRR1 ADIR A,H D,A            %H -> A READ LEAST SIGNIF MANT.
0522          LOGM ADIR A,H D,D
0523          LOGM CFC ADIR A,SCR D,T           %EXPONENT -> T-REG, FETCH
0524  SUBF2,  LOGM ADIR A,SCR D,T
0525  SUBF,   LOGL BDIR B,SH D,SCR              %LEAST NUMB -> REG. ON A-BUS
0526          LOGM BDIR B,SH D,SP
0527          ARM BMINA B,D A,SCR D,D SACO      %D - SCR -> SCR
0530          ARM BMAM1 ADDC B,A A,SP D,SH      %A - SP -> SH
0531          LOGM AND B,B1 A,S                 %TEST TG
0532          CJMP ZERO *2
0533          LOGL OR B,B0 A,D D,D              %SET D0 -> 1
0534          LOGL ADIR A,D D,SH
0535          JMP 0557
0536  EQUAL,  LOGM EXOR A,SCR B,T               %TEST EQUAL SIGNS
0537          CJMP SNEG SUBF3                   %UNEQUAL JMP TO SUB
0540          LOGM ADIR A,H D,SH CRR1           %H -> SH, READ LEASTS. MANT
0541          LOGM ADIR A,H D,SCR               %LEAST SIGN. MANT -> SCR
0542          JMP ADDF+1
0543  SUBF3,  LOGM ADIRC A,H D,SP CRR1          %H -> SCR READ LEASTS. MANT
0544          LOGM ADIRC A,H D,SCR              %H -> SP, ONE'S COMPL
0545          ARM PLUS A,SCR B,D D,SCR SACO     %D + SCR -> SCR
0546          ARM PLUS ADDC A,SP B,A D,SH SACO  %A + SP -> SP
0547          CJMP NEGM INV                     %INVERT IF CARRY = 0
0550          ARM PLUS ADD1 A,SCR D,SCR SACO    %SCR + 1 -> SCR
0551          ARM PLUS ADDC B,SH D,SH           %SH + CARRY -> SH
0552          JMP NOINV
0553  INV,    LOGL EXOR B,B17 A,T D,T           %INVERT SIGN
0554          LOGL ADIRC A,SCR D,SCR            %ONE'S COMPL. OF SCR -> SCR
0555          LOGM BDIRC B,SH D,SH              %ONE'S COMP. OF SH -> SH
0556  NOINV,  LOGL ADIR A,SCR D,SH              %SCR -> SH
0557          LOGM BDIR B,B5 D,SC               %40 -> SC
0560          LOGL BDIR B,T                     %T -> AC(L)
0561          LOOP BM1 BM1A TSH31 SH32 B,AC     %SHIFT LEFT TO SH31 = CRY
0562          LOGL BDIR B,AC D,T                %EXPONENT -> T-REG
0563          LOGM BDIR B,SH D,A                %SH -> A
0564          CJMP SPOS ZTAD                    %RESULT ZERO
0565          LOGL CFC BDIR B,SH D,D            %SH(L) -> D, FETCH
0566  FDVO,   LOGM OR B,B3 A,S D,S              %1 -> Z
0567  ZTAD,   LOGM ADIR A,Z D,T                 %0 -> T
0570          LOGM ADIR A,Z D,A                 %0 -> A
0571          LOGM CFC ADIR A,Z D,D             %0 -> D, FETCH
0572  FMUC,   LOGM CR BDIR B,B5 D,SC            %40 -> SC, READ EXPO.
0573          ARM PLUS A,H B,T D,SP             %H + T -> SP
0574          LOGM ANDCB B,B17 A,SP D,SP        %RESET BIT 17 IN SP
0575          LOGM CRR1 EXOR B,T A,H            %TEST SIGN
0576          CJMP SPOS *2
0577          LOGM OR B,B17 A,SP D,SP           %SET BIT 17 IF NEG. RESULT
0600          LOGM CRR1 ADIR A,H D,SH           %H -> SH, READ LEAST S. M.
0601          LOGM EXOR B,B16 A,SP D,T          %INVERT BIAS BIT
0602          LOGL ADIR A,H D,SH
0603          LOGL BDIR A,D B,Z                 %D -> A-LATCH, 0 -> AC(L)
0604          LOGM BDIR A,A B,Z
0605          LOOP BDI PLUSA B,HAC SH32 ASH0 SHR TGAC0 SACO %MULTIPLY LOOP
0606          CJMP GREM MCRY1                   %JMP IF CARRY
0607          CJMP ZERO ZTAD                    %JMP IF ZERO
0610          LOGL BDIR B,AC D,D                %AC(L) -> D
0611          LOGM BDIR B,AC D,A                %AC -> A
0612          ARM BM1 B,T D,T                   %T - 1 -> T
0613  TTGN,   LOGM AND B,B1 A,S                 %TEST TG      * CFC is added in N12/42
0614          CJMP ZERO FETCH                   %JMP IF TG = 0
0615          LOGM CFC OR B,B0 A,D D,D          %SET BIT 0 -> 1
0616  MCRY1,  LOGL BDIR B,HAC D,D               %1/2 AC(L) -> D
0617          LOGM BDIR B,HAC D,A               %1/2 AC -> A
0620          JMP TTGN
0621  FDVC,   LOGM CR BDIR B,B5 D,SC            %40 -> SC, READ EXPO.
0622          LOGL BDIR B,B0 D,SH               %SET SH(L) -> 1, DIV ALGOR.
0623          ARM BMINA B,T A,H D,SP            %T - H -> SP
0624          LOGM ANDCB B,B17 A,SP D,SP        %RESET BIT 17 IN SP
0625          LOGM CRR1 EXOR A,H B,T            %TEST SIGN, READ MOST S.M.
0626          CJMP SPOS *2
0627          LOGM OR B,B17 A,SP D,SP           %SET BIT 17 -> 1, NEGATIVE
0630          LOGM CRR1 ADIR A,H D,SCR          %H -> SCR, READ LEAST S.M.
0631          CJMP SPOS FDVO                    %OVERF. IF ZERO
0632          LOGM EXOR B,B16 A,SP D,T          %INVERT BIAS BIT
0633          LOGL BDIR B,D                     %D -> AC(L)
0634          ARM BDI B,A                       %A -> AC
0635          CJMP SPOS ZTAD
0636          LOGL BDIR B,HAC A,H               %1/2 AC(L) -> AC(L), H -> A-LATCH
0637          LOGM BDIR B,HAC A,SCR
0640  FDVLO,  LOOP PLUS BMAA B,2AC SACO SH32 ASH0 ENDID TGS0 %FDV LOOP
0641          LOGM BDIR B,SH D,A                %SH -> A
0642          CJMP SPOS POSDV                   %JMP TO SHIFT
0643          ARM BDI ADD1 B,T D,T              %T + 1 -> T
0644          LOGL BDIR B,SH D,D
0645  TGTN2,  LOGM AND B,B1 A,S                 %TEST TG      * CFC is added in N12/42
0646          CJMP NZERO FETCH
0647          LOGM CFC OR B,B0 A,D D,D          %SET BIT 0 -> 1
0650  POSDV,  LOGL BDIR B,SH D,D                %SH(L) -> D
0651          LOGM BDIR B,2AC D,A               %2 · AC -> A
0652          LOGL BDIR B,2AC D,D               %2 · AC(L) -> D
0653          JMP TGTN2

0654  % MONITOR CALL CONTINUES
0654  MONC,   ARM A,SCR BMISC D,IO              %SCR -> MISC, BIT 4 MISC -> 1
0655          ARM A,Z BMISC D,IO                %0 -> MISC
0656          ILOGM ADIR CFC A,DH D,T LE16 DSPL %ΔH -> T, LEV14, FETCH
0657  PUTGC,  CJMP NZERO GETR                   %JMP IF IRR
0660          ILOGM CFC BDIR ORBW B,A DSPL      %A -> REG

0661  %DOUBLE PRESISON MULTIPLY
0661  %OPERANDS IN TWO GENERAL-REGISTERS
0661  %RETURN WITH ANSWER IN A (MOST SIGN.) AND -D-REG
0661  MPYDC,  LOGM BDIR ORSKP D,A               %SECOND OPERAND -> A
0662          LOGL EXOR A,SP B,A D,SS           %SIGN -> SS
0663          CARM NEG BMINA A,A B,Z D,A        %INVERT A-REG
0664          LOGM ADIR A,SP D,SH
0665          CARM NEG BMINA B,Z A,SP D,SH      %INVERT IF NEG
0666          LOGM BDIR B,B4 D,SC               %16 -> SC
0667          LOGL BDIR A,A B,Z
0670          LOOP BDI PLUSA B,2AC ASH31        %MOST SIGN. PART -> A-REG
0671          LOGM BDIR B,AC D,A                %TEST SIGN
0672          LOGM ADIR A,SS
0673          CJMP SPOS FETC5
0674          LOGL BDIR B,AC D,D                %AC(L) -> D
0675          ARM BMINA SACO B,Z A,D D,D        %-D -> D
0676          ARM CFC BMAM1 ADDC B,Z A,A D,A    %-A -> A

0677  %INTEGER DIVISON
0677  %DIVIDEND IN A-D-REGISTER, DIVISOR IN SPESYFIED REGISTER
0677  %RESULT IN A-REGISTER, REST IN D-REGISTER
0677  RDIVC,  LOGM ORSKP ADIR D,SCR             %DIVISOR -> SCR
0700          CARL NEG BMINA A,SCR B,Z D,SCR    %INVERT SCR
0701          LOGM EXOR A,A B,AC D,SS           %SIGN -> SS17
0702          LOGM BDIR B,A D,SP                %A -> SP
0703          CJMP POS *3
0704          ARM B,Z BMINA A,D D,D SACO        %INVERT D-REG
0705          ARM B,Z BMAM1 A,A D,A ADDC        %INVERT A-REG
0706          ARM BMINA B,A A,SCR D,SH          %A - SCR -> SH
0707          CJMP POSM FETCZ
0710          LOGL B,Z BDIR D,SH                %0 -> SH(L)
0711          LOGL B,D BDIR A,Z                 %D -> AC, 0 -> A (LATCH)
0712          LOGM BDIR B,SH A,SCR              %SH -> AC, SCR -> A (LATCH)
0713          LOOP B,2AC PLUS BMAA SH32 ASH0 ENDID TSC0
0714          LOGM B,AC BDIR D,D                %AC -> D, REST
0715          LOGL BDIR B,SH D,A                %RESULT -> A
0716          LOGM B,B0 AND A,A
0717          CARM PLUS B,D A,SCR D,D ZERO      %SCR + D -> D IF A (0) = 0
0720          LOGM A,SP ADIR                    %TEST SIGN OF DIVIDEND
0721          CARM BMINA A,D B,Z D,D NEG        %INVERT D IF NEG
0722          LOGM A,SS ADIR                    %SIGN TEST
0723          CARM NEG BMINA A,A B,Z D,A        %COMPL. IF NEG
0724          LOGM EXOR B,A A,SS                %OVERFLOW TEST
0725          CJMP SNEG FETCZ
0726          ARM CFC
0727  SLRB,   LOGM AND B,B7 A,H                 %TEST LOAD, STORE BLOCK
0730          CJMP ZERO SRB
0731  LRB,    ARM CPTR BM1 B,X D,P              %X - 1 -> CP, CP -> R
0732          LOGM CRR1 ADIR A,SP D,P           %SP -> CP
0733          LOGM ADIR A,H D,SH                %CP -> SH
0734          ILOGM BDIR B,SH D,SP ORIN DSPL CRR1 %LOAD SP
0735          LOGM ADIR A,H D,SH                %X -> SH
0736          ILOGM BDIR B,SH D,X ORIN DSPL CRR1 %LOAD X
0737          LOGM ADIR A,H D,SH                %T -> SH
0740          ILOGM BDIR B,SH D,T ORIN DSPL CRR1 %LOAD T
0741          LOGM ADIR A,H D,SH                %A -> SH
0742          ILOGM BDIR B,SH D,A ORIN DSPL CRR1 %LOAD A
0743          LOGM ADIR A,H D,SH                %D -> SH
0744          ILOGM BDIR B,SH D,D ORIN DSPL CRR1 %LOAD D
0745          LOGM ADIR A,H D,SH                %L -> SH
0746          ILOGM BDIR B,SH D,L ORIN DSPL CRR1 %LOAD L
0747          LOGM ADIR A,H D,SH                %S -> SH
0750          ILOGM BDIR B,SH D,S ORIN DSPL CRR1 %LOAD S
0751          LOGM ADIR A,H D,SH                %B -> SH
0752          ILOGM BDIR B,SH D,B ORIN DSPL CFC %LOAD B, FETCH

0753  %MULTIPLY CONTINUED
0753  %ONE OPERAND IN A-REG
0753  %SECOND OPERAND, CONTENT OF EFFECTIVE ADDRESS
0753  MPYC,   LOGM ADIR A,A D,SCR CR            %A -> SCR, READ SEC. OPE.
0754          CARM NEG BMINA A,A B,Z D,SCR      %INVERT IF NEG
0755          LOGM ANDCB B,B4 A,S D,S           %RESET DYNAMIC OVERFL.
0756          LOGM ADIR A,H D,SH                %SECOND OPER. -> SH
0757          CARM NEG BMINA B,Z A,H D,SH       %INVERT IF NEG
0760          LOGM BDIR A,Z B,Z                 %ZERO -> AC AND A-LATCH
0761          LOGL BDIR A,SCR B,Z               %ZERO -> AC(L) AND A -> A-LATCH
0762          LOOP BDI PLUSA B,2AC ASH31        %MULTIPLY LOOP
0763          LOGM BDIR B,2AC                   %TEST OVERF
0764          CJMP ZERO *3                      %JMP IF NOT OVERFL.
0765          LOGM OR B,B4 A,S D,S              %SET STATIC OVERFL
0766          LOGM OR B,B5 A,S D,S              %SET DYNAMIC OVERFL
0767          LOGM EXOR A,H B,A                 %TEST SIGN
0770          LOGL BDIR B,AC D,A                %RESULT -> A
0771          CARM NEG CFC BMINA A,A B,Z D,A    %INVERT IF NEG.
0772  WAITC,  LOGM ADIR A,H D,SH                %PID -> SH
0773          ARM A,IO B,PIM                    %DECODED PIL -> H
0774          LOGM ANDCA A,H B,SH D,SCR         %CLEAR BIT IN PID
0775          ARM A,SCR B,PID D,IO              %SET PID
0776          JMP FETCH
0777          0

1000  %ENTRY PANEL INTERRUPT
1000  PANIN,  LOGM ADIR A,P D,SP
1001          JMP PANINC
1002  BSBAC,  LOGM AND A,S B,B2                 %TEST K
1003          CJMP NZERO BSBSH
1004          LOGM CFC ANDCB B,BM ORBW          %0 -> BIT, FETCH
1005  BSTCC,  LOGM AND A,S B,B2                 %TEST K
1006          CJMP NZERO KONE2                  %JMP IF K = 1
1007          LOGM OR B,BM ORBW                 %1 -> SPECIFIED BIT
1010          LOGM CFC OR B,B2 A,S D,S          %1 -> K, FETCH
1011  BSTAC,  LOGM AND A,S B,B2                 %TEST K
1012          CJMP NZERO KONE3                  %JMP IF K = 1
1013          LOGM ANDCB B,BM ORBW              %0 -> SPECIFIED BIT
1014          LOGM CFC ANDCB B,B2 A,S D,S       %0 -> K, FETCH
1015  BLDCC,  LOGM AND ORBWO B,BM               %TEST BIT
1016          CJMP NZERO BONE1                  %JMP IF BIT = 1
1017          LOGM CFC OR B,B2 A,S D,S          %1 -> K, FETCH
1020  BLDAC,  LOGM AND ORBWO B,BM               %TEST BIT
1021          CJMP NZERO BLDCC+2                %JMP IF B = 1
1022  BONE1,  LOGM CFC ANDCB B,B2 A,S D,S       %0 -> K, FETCH
1023  BANDC,  LOGM AND ORBWO B,BM               %TEST BIT
1024          CJMP NZERO FETCH
1025          LOGM CFC ANDCB B,B2 A,S D,S       %0 -> K, FETCH
1026  BANCC,  LOGM AND ORBWO B,BM               %TEST BIT
1027          CJMP NZERO BANDC+2                %JMP IF BIT = 1
1030          LOGM CFC                          %K -> K, FETCH
1031  BORAC,  LOGM AND ORBWO B,BM               %TEST BIT
1032          CJMP NZERO BORCC+2                %JMP IF BIT = 1
1033          LOGM CFC                          %K -> K, FETCH
1034  BORCC,  LOGM AND ORBWO B,BM               %TEST BIT
1035          CJMP NZERO BORAC+2                %JMP IF BIT = 1
1036          LOGM CFC OR B,B2 A,S D,S          %1 -> K, FETCH
1037  KONE3,  LOGM OR B,BM ORBW                 %1 -> SPECIFIED BIT
1040          LOGM CFC ANDCB B,B2 A,S D,S       %0 -> K, FETCH
1041  CIIPP,  ARM A,H B,MIS D,IO                %ION, IOF, PON, POF
1042          ARM CFC

1043  % MOPC
1043  % OPERATORS COMMUNICATION FOR NORD-10
1043  MOPCM,  ARM A,Z B,PIE D,IO                %MASTER CLEAR, RESET PIE
1044          ARM CHLEV                         %CHANGE LEVEL
1045          LOGM OR A,Z B,B2 D,SCR            %SET BIT 2 IN SCR -> 1
1046          ARM A,SCR B,PCR D,IO              %SET BANKNUMBER -> 0
1047          ARM BDI ADD1 B,B2 D,SCR           %5 -> SCR
1050          ARM A,SCR B,MIS D,IO              %RESET PAGING AND INTERRUPT
1051          LOGM BDIR B,B5 D,P                %BIT5 -> CP
1052          ARM A,P B,MIS D,IO                %SET MOPC-BIT, BIT 5 MISC
1053          JMP MOPCR
1054  MOPC,   LOGM ADIR A,P D,SP                %CP -> SP
1055          LOGM BDIR B,B5 D,P                %BIT5 -> CP
1056          ARM A,P B,MIS D,IO                %BIT-5 -> MISC
1057          ILOGM ADIR A,A D,SS LE11 DSPL     %SAVE A-REG
1060  MOPCR,  LOGM BDIR B,B15 D,SCR             %BIT TO RESET LOAD LIGHT
1061          LOGM A,SCR B,PAC D,IO
1062          LOGM BDIR B,B5 D,SCR
1063          LOGM BDIR B,B4 D,SH
1064          IARM PLUS 2000000000 A,SCR B,SH D,SCR LE10 DSPL %60 -> SCR LEV10      (bit 28, the 2000000000, is set in the 1k PROM dump only; the listing and the 4k ROM read IARM PLUS)
1065          LOGM BDIR B,B3 D,SCR
1066          ARM PLUS A,SCR B,B1 D,SH          %12 -> SCR LEV 6
1067          ILOGM BDIR B,SH D,SCR LE6 DSPL
1070          LOGM ADIR A,Z D,SS                %MOPC STATUS, 0 -> (SS LEV0)
1071          ILOGM ADIR A,Z D,SS LE12 DSPL     %CLEAR EXAMINE ADDRESS
1072          LOGM BDIR D,SCR B,B6              %100 -> SCR
1073          ARM PLUS B,B7 A,SCR D,SCR         %SET BIT 7
1074          ILOGM ADIR A,SCR D,SS LE17 DSPL   %300 -> (SS LEV17) CONSOLE DEV NR.
1075  NYFAF,  ARM A,IO B,MPC                    %SAVE RETUR ADD.
1076          JMP ACT
1077  REAC,   ARM A,IO B,MPC                    %SAVE MPC
1100          JMP ASS8

1101  %TEST TERMINATING CHARACTER IN A-REG
1101  %OCTAL NUMBER IN SH IF BIT14 SS IS ONE
1101          LOGM ADIR A,A
1102          CJMP ZERO REAC                    %IGNORE BLANK’S
1103          LOGM BDIR B,B6 D,SCR              %100 -> SCR
1104          ARM BMINA A,SCR B,A D,A           %100-A -> A
1105          CJMP ZERO MOPCM                   %CHARACTER ”100” READ
1106          LOGM BDIR B,B3 D,SCR
1107          ARM BMAM1 B,A A,SCR
1110          CJMP ZERO IEX                     %111, CHARACTER 1”
1111          ARM BMAM1 B,AC A,SCR D,SCR        %111, CHARACTER "I"
1112          CJMP ZERO REX                     %122, CHARACTER ”R”
1113          ARM PLUS B,B4 A,SCR               %122, CHARACTER "R"
1114          CJMP ZERO BANK                    %102, B
1115          ARM PLUS A,A B,B4 D,A ADD1        %A + 20 + 1 -> A
1116          CJMP ZERO EXAM                    %CHARACTER "/"
1117          ARM PLUS A,A B,B2 ADD1 D,A        %TEST, 52*
1120          CJMP ZERO CLC
1121          ARM PLUS A,A B,B2 D,A             %A + 10 -> A
1122          CJMP ZERO ETSGN                   %CHAR. "&"
1123          ARM PLUS A,A B,B1 D,A             %A + 2 -> A
1124          CJMP ZERO DOLL                    %CHAR. "$"
1125          ARM PLUS A,A B,B1 ADD1 D,A        %A + 3 -> A
1126          CJMP ZERO STPR                    %CHAR. "!"
1127          ARM BDI ADD1 D,A B,A
1130          CJMP ZERO REAC                    %SPACE
1131          ARM PLUS A,A B,B4 D,A             %A + 20 -> A
1132          ARM PLUS A,A B,B1 ADD1            %A + 3 -> A
1133          CJMP ZERO CHCR                    %CARRIAGE RET.
1134  QUM,    LOGM BDIR D,SCR B,B6
1135          ARM PLUS B,B7 A,SCR D,SCR         %300 -> SCR
1136          ILOGM ADIR A,SCR D,SS LE17 DSPL   %300 -> SS(LEV17) CONSOLE DEVICE
1137          ARM BM1 B,B6 D,A                  %77 -> A
1140          LOGM ANDCB B,B17 D,SS             %RESET LOAD BIT
1141          ARM A,IO B,MPC                    %SAVE MPC
1142          JMP OUTCH                         %PRINT "?"
1143          LOGM BDIR B,B14 D,SCR             %SET BIT 14
1144          ARM A,SCR B,PAC D,IO              %SET ERROR INDICATOR
1145          JMP MOPCR                         %READ NEXT CHAR.

1146  %ROUTINE TO PRINT OCTAL NUMBERS
1146  %PRINTS ON OPCOMDEV
1146  %NUMBER IN SH-MOST SIGN.
1146  OUT8,   IARM PLUS ADD1 A,H LE16 D,SCR DSPL %SAVE RETUR
1147          LOGM BDIR B,B0 D,SC
1150          LOOP SHRO TSC0                    %SHIFT LEFT SHRO 16
1151          LOGM BDIR B,SH D,A
1152          LOGM AND B,B0 A,A D,A             %FIRST OCTAL NUMB -> A-REG
1153          IARM PLUS A,SCR B,AC D,A LE10     %ADD 60
1154          ARM A,IO B,MPC                    %SAVE MPC
1155          JMP OUTCH                         %PRINT FIRST DIGIT
1156          ARM PLUS A,Z ADD1 B,B2 D,SCR      %5 -> SCR
1157          IARM BMINA D,SCR B,Z A,SCR LE12 DSPL %-SCR -> SCR (LEV12)
1160  NECHP,  ARM BM1 B,B2 D,SC                 %3 -> SC
1161          LOOP SHRO TSC0                    %SHIFT 3 SHRO LEFT
1162          ARM BM1 B,B3 D,SCR                %7 -> SCR
1163          LOGM AND B,SH A,SCR               %SH · 7 -> AC
1164          IARM PLUS A,SCR B,AC D,A LE10     %AC + 60 -> AC
1165          ARM A,IO B,MPC                    %SAVE MPC
1166          JMP OUTCH                         %PRINT ONE DIGIT
1167          ILOGM ADIR D,SCR A,SCR LE12
1170          IARM PLUS ADD1 D,SCR B,Z A,SCR LE12 DSPL %COUNT
1171          CJMP NZERO NECHP
1172          LOGM BDIR D,A B,B5                %40 -> A
1173          LOGM ADIR B,MPC A,IO
1174          CALL OUTCH                        %PRINT SPACE
1175          JMP RETU1

1176  %THIS ROUTINE READS AN OCTAL NUMBER
1176  %RETURN :OCTAL NUMBER IN SH(MOSTS)
1176  %TERMINATING CHARACTER IN A-REG
1176  ASS8,   IARM PLUS ADD1 A,H B,Z D,SCR LE16 DSPL %SAVE RETUR.
1177          LOGM ADIR A,Z D,SH                %0 -> SH
1200          LOGM ANDCB B,B14 A,SS D,SS        %RESET OCTAL FLAG
1201  RLOOP,  ARM A,IO B,MPC                    %SAVE RETUR.
1202          JMP INCH                          %READ ONE CHARACTER
1203          LOGM ANDCB D,P B,B7 A,A           %RESET PARITY
1204          IARM BMINA D,A B,AC A,SCR LE10    %AC - 60 -> A
1205          CJMP SNEG EASS8                   %JMP IF NOT OCT. DIGIT
1206          LOGM BDIR B,B3 D,SCR              %10 -> SCR
1207          ARM BMINA B,A A,SCR D,A           %A-10 -> A
1210          CJMP SPOS EASS8                   %JMP IF NOT OCT. DIGIT
1211          ARM BM1 B,B3 D,A                  %7 -> A
1212          LOGM AND A,P B,A D,SCR            %CP · A -> SCR
1213          ARM BM1 B,B2 D,SC                 %3 -> SC
1214          LOOP TSC0                         %SHIFT 3 LEFT
1215          LOGM OR A,SCR B,SH D,SH           %NEW OCTAL DIGIT -> SH
1216          LOGM OR A,SS B,B14 D,SS           %SET OCTAL FLAG
1217          JMP RLOOP                         %READ NEXT CHAR.
1220  EASS8,  LOGM ADIR D,A A,P                 %TERMINATION CHAR. FROM P
1221          IARM BMINA B,AC A,SCR LE6         %TEST FOR LF
1222          CJMP ZERO RLOOP                   %LINE FEED IGNORE
1223  RETU1,  ILOGM ADIR A,SCR D,P LE16         %RETUR ADD. TO SCR
1224  RETU,   LOGM A,P B,CAR D,IO               %SCR -> CAR
1225          JMP,CAR
1226  PANINC, LOGM BDIR B,B5 D,P                %BIT 5 SET IN CP
1227          ARM A,P B,MIS D,IO                %SET MOPC-BIT 5 IN MISC
1230          ARM A,IO B,OPR                    %READ OPR
1231          ILOGM ADIR D,SS A,H LE12 DSPL     %SAVE OPR
1232          ARM A,IO B,PAS                    %READ PANEL STATUS
1233          LOGM ADIR A,H D,P
1234          LOGM BDIR B,B6 D,SS               %SET STATUS FOR PANEL INTERRUPT
1235          JMP PANT2

1236  %THIS ROUTINE TESTS PANEL BUTTONS  AND
1236  PANTT,  LOGM AND B,B17 A,SS               %TEST LOAD
1237          CJMP NZERO RPANT                  %JMP TO INCH
1240          ILOGM BDIR LE2 B,SH D,SS DSPL     %SAVE SH-REG
1241          ARM A,IO B,PAS                    %PANEL STATUS -> H
1242          LOGM ADIR A,H D,P                 %SAVE PAS
1243          ILOGM ADIR A,SS D,A LE11          %UNSAVE A
1244          LOGM AND B,B14 A,H                %TEST SET ADDRESS
1245          CJMP NZERO SETAD
1246          LOGM AND B,B12 A,H                %TEST RESTART
1247          CJMP NZERO RESTA                  %JMP TO RESTART
1250          LOGM AND B,B13 A,H                %TEST DEPOSIT
1251          CJMP NZERO DEPP                   %DEPOSIT, ADDR. IN SS LE12
1252          LOGM AND B,B11 A,H                %TEST CONTINUE
1253          CJMP NZERO STFP                   %START PROG. IN MAIN MEM.
1254          LOGM AND B,B10 A,H                %TEST LOAD
1255          CJMP NZERO LOAD                   %LOAD FROM LOAD DEV.
1256  PANT1,  ILOGM BDIR B,SH D,SS LE2 DSPL     %SAVE SH
1257  PANT2,  LOGM AND B,B15 A,P                %TEST NOOP
1260          CJMP NZERO RETPA
1261          ARM BM1 B,B7 D,SH
1262          LOGM AND B,SH A,P D,SCR           %RESET BIT IN PAS
1263          ARM A,SCR B,PAC D,IO              %SET PAC
1264          LOGM AND B,B7 A,P                 %TEST REG. OR MEM. EXAM.
1265          CJMP NZERO MEXM
1266          ARM A,P B,CAR D,IO                %SET CAR
1267          ARM
1270          ILOGM ADIR ORBWO D,SCR            %READ REG
1271          ARM A,SCR B,LMP D,IO              %SET LAMP DISP.
1272          JMP RETPA

1273  %JMP TO THIS ROUTINE WHEN "/" IS TYPED
1273  EXAM,   LOGM OR B,B10 A,SS D,SS           %SET EXAM BIT
1274          LOGM AND B,B7 A,SS                %TEST REGISTER EXAM
1275          CJMP NZERO REXAM                  %JMP REG EXAM IF NOT ZERO
1276          LOGM ANDCB B,B16 A,SS D,SS        %RESET REG DEP
1277          ILOGM BDIR B,SH D,SS LE12 DSPL    %SAVE ADDRESS
1300  EXRO,   ILOGM ADIR A,SS D,P LE12          %ADDRESS -> CP
1301          ARM CPTR BM1 B,P D,P              %CP - 1 -> CP
1302          ARM CRR1
1303          JMP IEXA1

1304  %START, <OCTALN.>!
1304  %START ADDRESS IN SH IF OCTALNUMBER WRITTEN ELSE IN
1304  %SP (CONTINUE)
1304  RESTA,  LOGM BDIR B,B4 D,SP               %SET RESTART ADDRESS
1305  STSP,   ARM A,Z B,PIE D,IO                %RESET PIE
1306          ARM CHLEV                         %CHANGE LEVEL
1307  STFP,   LOGM ADIR A,Z D,SS                %0 -> SS, 0 -> OCTAL FLAG
1310  STPR,   LOGM AND B,B14 A,SS D,SS          %PREPARE OCTAL TEST
1311          ILOGM ADIR A,SS D,A LE11          %UNSAVE A-REG
1312          ARM A,Z B,MIS D,IO                %0 -> MISC
1313          ILOGM ADIR A,SS LE0               %TEST OCTAL FLAG
1314          CLOGM NZERO BDIR B,SH D,SP        %START ADDRESS -> SP
1315          LOGM BDIR B,B15 D,SCR             %SET BIT FOR RESET LOAD
1316          LOGM OR B,B11 A,SCR D,SCR         %SET CONTINUE BIT
1317          ARM A,SCR B,PAC D,IO              %SET BITS TO PANEL CONT.
1320          LOGM ADIR A,SP D,P CFC            %START ADDRESS -> CP, START

1321  %REGISTER EXAMIN. JMP FROM EXAM
1321  %TESTS ON BIT 15 IN STATUS(SS) AND JUMPS
1321  %TO IEXAM IF "INTERNAL REG"
1321  REXAM,  LOGM ANDCB B,B7 A,SS D,SS         %RESET REG EXAM
1322          LOGM OR B,B16 A,SS D,SS           %SET REG DEP
1323          ILOGM BDIR B,SH D,SS LE7 DSPL     %SAVE REG NUMBER
1324          LOGM AND A,SS B,B15               %TEST INTERNAL REG
1325          CJMP NZERO IEXAM                  %"INTERNAL REG" IF NOT ZERO
1326  ERDP,   ILOGM ADIR A,SS D,SH LE7          %UNSAVE REG NUMB.
1327          ARM BM1 B,B3 D,SCR                %7 -> SCR
1330          LOGM AND A,SCR B,SH D,SCR         %MASK REG NUMB
1331          ILOGM ADIR A,SS D,SH LE14         %READ LEVEL
1332          ARM BM1 B,B2 D,SC                 %3 -> SC
1333          LOOP TSC0                         %SHIFT REG NUMB
1334          LOGM OR A,SCR B,SH D,SCR          %GENERATE REG AND LEVEL
1335          ARM A,SCR B,CAR D,IO
1336          ILOGM ADIR A,SS D,A LE11          %UNSAVE A
1337          LOGM AND B,B11 A,SS               %TEST DEPOSIT
1340          CJMP NZERO REDEP                  %RETUR TO DEPOSIT
1341          ILOGM ADIR ORBWO D,SH             %READ REGISTER
1342          JMP IEXA

1343  %DEPOSIT ROUTINE,  ENTERED AFTER CARRIAGE RETURN
1343  CHCR,   ARM A,IO B,MPC                    %SAVE RETUR
1344          JMP PRLF                          %PRINT LF
1345          LOGM ANDCB B,B7 A,SS D,SS         %RESET BIT FOR RI (INT-REG)
1346          LOGM AND B,B16 A,SS               %TEST REG DEPOSIT
1347          CJMP NZERO REGDP                  %JMP TO REG DEPOSIT IF NOT ZERO
1350          LOGM AND B,B14 A,SS               %TEST OCTAL NUMB. WRITTEN
1351          CJMP ZERO NDEP
1352          LOGM AND B,B10 A,SS               %/ FLAG NOT SET
1353          CJMP ZERO QUM
1354  DEPM,   ILOGM ADIR A,SS D,P LE12          %READ ADDRESS
1355          ARM CPTR BM1 B,P D,P              %CP - 1 -> CP, CP -> R
1356          LOGM BDIR B,SH D,SCR              %DATA TO A-BUS REG.
1357          ARM CWR1 A,SCR                    %WRITE SCR
1360  NDEP,   LOGM AND B,B10 A,SS               %TEST EXAM BIT
1361          CJMP ZERO REAC                    %NO DEPOSIT
1362          ILOGM ADIR D,P A,SS LE12
1363          IARM BDI ADD1 D,SS B,P LE12 DSPL  %INCREMENT ADDRESS
1364          JMP EXRO

1365  %INTERNAL REGISTER DEPOSIT
1365  IRD,    ILOGM ADIR A,SS D,SCR LE7         %READ REG NUMB.
1366          ARM A,SCR B,CAR D,IO              %SET REG. NUMBER IN CAR
1367          LOGM BDIR B,SH D,SCR              %NUMBER WRITTEN IN SCR
1370          ARM ADIR A,SCR B,IR3 D,IO         %DEPOSIT IN SPESY. REG
1371          LOGM ANDCB A,SS B,B15 D,SS        %RESET INTERNAL REG BIT
1372          JMP NRDP
1373  BANK,   LOGM BDIR B,SH D,SCR
1374          LOGM OR B,B2 A,SCR D,SCR          %SET BIT 2 IN SCR -> 1
1375          ARM A,SCR B,PCR D,IO              %SET BANKNUMBER IN PCR
1376          LOGM ANDCB B,B7 A,SS D,SS         %RESET BIT FOR R-I
1377          JMP NRDP1

1400  %*=*=*=*
1400          JMP 400                           %INTERRUPT AND PANEL INT
1401          JMP MOPCM                         %MASTER CLEAR
1402          JMP MOPC                          %STOP

1403  %*=*=*=*
1403  REDEP,  ILOGM ADIR A,SCR D,SH LE1         %READ NUMBER
1404  RPDEP,  ILOGM BDIR ORBW DSPL B,SH         %DEPOSIT IN REG
1405          ILOGM ADIR A,A D,SS LE11 DSPL     %SAVE A-REG
1406  NRDP,   LOGM ANDCB B,B11 A,SS D,SS        %RESET DEPOSIT BIT
1407          LOGM ANDCB A,SS B,B16 D,SS        %RESTORE REGEX BIT
1410  NRDP1,  LOGM ANDCB A,SS B,B10 D,SS        %RESET / BIT
1411          JMP REAC

1412  %ROUTINE FOR REGISTER DEPOSIT
1412  REGDP,  LOGM AND B,B14 A,SS               %TEST OCTAL NUMBER WRITTEN
1413          CJMP ZERO NRDP                    %NO DEPOSIT
1414          LOGM AND B,B15 A,SS               %TEST "INTERNAL REG"
1415          CJMP NZERO IRD                    %INTERNAL REGISTER DEPOSIT
1416          ILOGM BDIR B,SH D,SCR LE1 DSPL    %SAVE NUMBER
1417          LOGM OR B,B11 A,SS D,SS           %SET BIT FOR DEPOSIT
1420          JMP ERDP                          %JMP TO GEN, REGNR. AND LEVEL

1421  %"INTERNAL REG"  EXAMIN
1421  IEXAM,  LOGM BDIR B,SH D,SCR              %REG. NUMBER -> SCR
1422          ARM A,SCR B,CAR D,IO              %SET REG. NUMBER -> CAR
1423          ARM A,IO B,IR3                    %READ REG CONTENT
1424  IEXA1,  LOGM ADIR A,H D,SH
1425  IEXA,   ARM A,IO B,MPC                    %SAVE RETUR
1426          JMP OUT8                          %PRINT NUMBER
1427          JMP REAC                          %READ NEXT INP
1430  PRLF,   IARM PLUS A,H B,Z ADD1 D,SCR LE5 DSPL %SAVE RETUR
1431          ILOGM ADIR A,SCR LE6 D,A          %12 -> A
1432          ARM A,IO B,MPC                    %SAVE RETUR
1433          JMP OUTCH                         %PRINT LF
1434  RETU5,  ILOGM ADIR A,SCR D,P LE5          %RETUR ADR -> CP
1435          JMP RETU

1436  %CHARACTER "I" WRITTEN
1436  IEX,    LOGM OR B,B15 A,SS D,SS           %SET FLAG FOR I
1437          LOGM OR B,B7 A,SS D,SS            %SET FLAG FOR R + I
1440          JMP NRDP1
1441  CLC,    ILOGM ADIR A,SS D,SH LE12         %READ CURRENT LOC. COUNTER
1442          JMP IEXA

1443  %CHARACTER "R" WRITTEN
1443  REX,    ILOGM BDIR B,SH D,SS LE14 DSPL    %SAVE LEVEL
1444          LOGM ANDCB B,B15 A,SS D,SS        %RESET BIT FOR I
1445          JMP IEX+1
1446  SETAD,  ARM A,IO B,OPR                    %READ SWITCH REGISTER
1447          ILOGM ADIR A,H D,SS LE12 DSPL     %SAVE ADDRESS
1450          LOGM OR B,B0 A,P D,SH             %SET BIT 0 (BIT 2 PCR)
1451          LOGM BDIR B,B1 D,SC               %SET SHIFT COUNTER
1452          LOOP SHRO TSC0                    %SHIFT BANK NUMBER
1453          LOGM BDIR B,SH D,SCR
1454          ARM A,SCR B,PCR D,IO              %SET BANKNUMBER
1455          JMP REAC
1456  MEXM,   ILOGM ADIR A,SS D,P LE12          %READ ADDRESS
1457          ARM BM1 B,P D,P CPTR
1460          ARM CRR1
1461          ARM A,H B,LMP D,IO                %SET DATA
1462  RETPA,  ILOGM ADIR A,SS D,SH LE2          %UNSAVE SH
1463          LOGM AND B,B6 A,SS                %TEST PANEL INTERRUPT
1464          CJMP ZERO RPANT                   %RETUR TO INCH
1465          ARM A,Z B,MIS D,IO                %RESET MOPC BIT
1466          LOGM CFC ADIR A,SP D,P            %SP -> CP, FETCH
1467  DEPP,   ARM A,IO B,OPR                    %READ OPR
1470          LOGM AND B,B7 A,P                 %TEST REG. OR MEM. DEPOSITE
1471          CJMP ZERO RDEP
1472          ILOGM ADIR A,SS D,P LE12          %READ ADDRESS
1473          ARM BM1 B,P D,P CPTR
1474          ARM CWR1 A,H                      %DEPOSITE IN MEM.
1475          JMP REAC
1476  RDEP,   ARM A,P B,CAR D,IO                %SET REG. N. AND LEVEL -> CAR
1477          LOGM ADIR A,H D,SH                %DATA -> SH
1500          JMP RPDEP

1501  %ENTRY IN MOPC AFTER $, & OR LOAD COMMAND
1501  %(SH1)= ALD-NUMBER, SPECIFIED ON CONSOLE DEVICE
1501  %IF NO ALD NUMBER IS SPECIFIED, THE DEFAULT NUMBER IS READ FROM ALD
1501  %ALD NUMBER FORMAT
1501  %BIT 15 : EXTN, EXTENDED LOAD FUNCTION
1501  %BIT 14 : RESTART
1501  %BIT 13 : MASS STORAGE LOAD
1501  %BIT 12 : OTAL LOAD
1501  DOLL,   LOGM BDIR D,A B,B14               %10000 -> A, AFTER $
1502          JMP DOLET
1503  LOAD,   LOGM BDIR B,B17 D,SS              %SET LOAD-FLAG, RESET OCTAL READ FLAG
1504  ETSGN,  LOGM BDIR D,A B,Z                 %0 -> A, AFTER & OR LOAD
1505  DOLET,  LOGM ADIR B,PAS A,IO              %READ PANEL
1506          ARM BM1 D,P B,B10                 %377 -> P
1507          LOGM AND D,P B,P A,H
1510          LOGM OR D,P B,B10 A,P
1511          LOGM ADIR D,IO B,PAC A,P          %SET LOAD BIT IN PANEL CONTROL
1512          LOGM AND B,B14 A,SS               %TEST IF OCTAL NUMBER READ
1513          CJMP NZERO DE0                    %JMP OCTAL READ
1514          LOGM ADIR B,ALD A,IO              %GET ALD
1515          LOGM ADIR D,SH A,H
1516  DE0,    LOGM OR D,A A,A B,SH              %OR IN B14 IF $ WRITTEN
1517          LOGM AND B,B17 A,A
1520          CJMP NZERO EXTN                   %EXTENDED LOAD FUNCTION
1521          LOGM AND B,B16 A,A                %RESTART FUNCTION?
1522          CJMP NZERO RSTRT                  %YES
1523          LOGM AND B,B15 A,A
1524          CJMP NZERO MASS                   %MASS STORAGE LOAD
1525  DE1,    ILOGM ADIR D,SS A,A LE17 DSPL     %DEV. NR. -> SS LEV17
1526          LOGM BDIR D,SS B,B17              %SET LOAD FLAG
1527          LOGM OR D,SS B,B10 A,SS           %SET EXAMINE BIT IN SS
1530          LOGM AND B,B14 A,A
1531          CJMP NZERO NYFAF                  %OCTAL LOAD IF A = 010000

1532  %BINARY LOAD
1532  %WILL PICK UP NECESSZRY PARAMETERS FROM A STANDARD (OCTAL)
1532  %BOOTSTRAP AND LOAD THE BINARY INFORMATION INTO CORE
1532  %IMMEDIATELY FOLLOWING THE CHECKSUM THERE IS AN ACTION
1532  %COMMAND. IF TERMINATING
1532  %CHARACTER IS A BLANK, THEN THE LOADED PROGRAM IS STARTED IN
1532  %THE START ADDRESS FOUND IN THE BOOTSTRAP.  OTHERWISE THE COMMAND
1532  %IS ACTED UPON BY MOPC
1532  BINL,   LOGM ADIR B,MPC A,IO
1533          CALL ACT                          %ACTIVATE DEVICE
1534          LOGM ADIR D,SH A,Z                %0 -> SH
1535  SEEK,   LOGM BDIR D,SP B,SH               %SH -> SP (POSSIBLE START ADDRESS)
1536  SIKI,   LOGM ADIR B,MPC A,IO
1537          CALL ASS8
1540          LOGM AND B,B14 A,SS               %OCTAL NUMBER READ?
1541          CJMP ZERO SIKI                    %NO
1542          ARM BMINA B,B5 A,A                %A - 40 -> AC
1543          ARM PLUS ADD1 B,AC A,Z            %AC + 1 -> AC
1544          CJMP NZERO SEEK                   %SEEK FOR '!' AS TERMINATOR
1545          LOGM ADIR B,MPC A,IO
1546          CALL BIN
1547          ARM BM1 D,P B,SH CPTR             %SH - 1 -> CP, CP -> R, BLOCK START
1550          LOGM ADIR B,MPC A,IO
1551          CALL BIN
1552          LOGM BDIR D,T B,SH                %SH -> T, WORD COUNT
1553          LOGM ADIR D,D A,Z                 %0 -> D
1554  STLP,   LOGM ADIR B,MPC A,IO              %STORE LOOP
1555          CALL BIN
1556          LOGM BDIR D,A B,SH                %SH -> A, BINARY WORD
1557          ARM PLUS D,D B,D A,A              %ACCUMULATE CHECKSUM
1560          ARM BM1 D,T B,T CWR1 A,A          %T - 1 -> T, STORE A IN (R) + 1
1561          CJMP NZERO STLP
1562          LOGM ADIR B,MPC A,IO
1563          CALL BIN                          %READ CHECKSUM
1564          LOGM EXOR B,SH A,D
1565          CJMP NZERO QUM                    %CHECKSUM ERROR
1566          LOGM BDIR D,SS B,B17              %SET LOAD BIT
1567          LOGM ADIR B,MPC A,IO
1570          CALL ASS8                         %READ ACTION CODE
1571          LOGM ADIR A,A
1572          CJMP ZERO STSP                    %START PROGRAM (TERMINATOR = BLANK)
1573          JMP REAC+2

1574  %EXTN
1574  %EXTENDED LOAD FUNCTION
1574  %WHEN THE EXTN-BIT (BIT15) IN A IS SET, A MICRO-JUMP TO THE ADDRESS
1574  %FOUND IN A BIT0-10 IS PERFORMED
1574  %NO FURTHER DECODING OF ALD TAKES PLACE
1574  EXTN,   LOGM ADIR D,IO B,CAR A,A
1575          JMP,CAR

1576  %RSTRT
1576  %RESTART FUNCTION (NOT TO BE CONFUSED WITH THE RESTART BUTTON)
1576  %WHEN THE RSTRT-BIT (BIT 14) OF A IS SET, THE CPU IS STARTED
1576  %IN 4* (THE ADDRESS FOUND IN BIT0-13 IN A ). BIT 0-1 IN THE
1576  %RESULTING ADDRESS IS 0
1576  RSTRT,  ARM PLUS D,A B,A A,A              %*2
1577          ARM PLUS D,SP B,A A,A             %*4
1600          JMP STSP                          %START PROGRAM

1601  %MASS
1601  %MASS STORAGE LOAD
1601  %MASS WILL LOAD 1K WORDS FROM MASS STORAGE ADDRESS 0 INTO MEMORY
1601  %FROM MEMORY ADDRESS0
1601  %(LOWEST)  MASS STORAGE REGISTER ADDRESS IS FOUND IN BIT 0-10 IN ALD
1601  %THE ACTUAL MASS STORAGE MUST CONFORM WITH THE DRUM/DISC
1601  %PROGRAMMING SPECIFICATION.
1601  MASS,   ARM PLUS D,P B,B0 A,A CPTR        %DEV NR(DNO) + 1 -> CP, CP -> R
1602  MAS1,   LOGM ADIR D,A A,Z                 %0 -> A
1603          LOGM ADIR D,SCR A,R               %DNO + 1
1604          LOGM ADIR B,MPC A,IO
1605          CALL IOXR                         %0 -> CORE ADDRESS
1606          ARM PLUS D,SCR B,B1 A,R           %DNO + 3
1607          LOGM ADIR B,MPC A,IO
1610          CALL IOXR                         %0 -> BLOCK ADDRESS
1611          LOGM BDIR D,A B,B12               %2000 -> A
1612          ARM PLUS D,SCR B,B2 A,SCR         %DNO + 7
1613          LOGM ADIR B,MPC A,IO
1614          CALL IOXR                         %2000 -> WORD COUNTER
1615          LOGM BDIR D,A B,B2                %4 -> A
1616          ARM PLUS D,SCR B,B2 A,R           %DNO + 5
1617          LOGM ADIR B,MPC A,IO
1620          CALL IOXR                         %ACTIVATE DEVICE
1621          ARM PLUS ADD1 D,SCR B,B1 A,R      %DNO + 4
1622  MAS2,   LOGM ADIR B,MPC A,IO
1623          CALL IOXR
1624          LOGM AND B,B2 A,A                 %DEVICE ACTIVE
1625          CJMP NZERO MAS2
1626          LOGM ADIR D,SP A,Z                %START IN MEMORY ADDRESS 0
1627          LOGM AND B,B4 A,A                 %ERROR?
1630          CJMP ZERO STSP                    %OK
1631          JMP MAS1                          %ERROR' TRY AGAIN

1632  %IOX
1632  %IOX EXECUTES A GENERAL IOX OPERATION
1632  %CALL WITH : IOX_INSTRUCTION OR DEVICE-NUMBER IN SCR0
1632  %  DATA IN A0
1632  %RETURN WITH : DATA IN A0  '  IOXR INSTRUCTION IN SCR0
1632  %
1632  IOXR,   ARM PLUS D,P B,B0 A,H             %SAVE RETURN = CALL + 1
1633          ARM BM1 B,B13                     %3777 -> AC
1634          LOGM AND D,SCR B,AC A,SCR         %STRIP OFF DEVICE NUMBER
1635          ARM BM1 B,B13                     %3777 -> AC
1636          LOGM ORCB D,SCR B,AC A,SCR        %17400 + SCR -> SCR
1637          LOGM ANDCB D,SCR B,B14 A,SCR      %167777 · SCR -> SCR
1640          LOGM ADIR D,IO B,CAR A,SCR        %SET UP CAR
1641          LOGM ADIR D,IO BIO A,A            %OUT -
1642          LOGM ADIR BIO A,IO                %- IN -
1643          LOGM ADIR D,A A,H                 %- TO A-REG
1644          JMP RETU                          %STANDARD RETURN

1645  %BIN
1645  %BIN READS A 16BIT WORD IN TWO BYTES
1645  %CALL WITH : DEVICE-NO IN SS17
1645  %RETURNS WITH : DATA IN SH1
1645  BIN,    IARM PLUS ADD1 D,SCR B,Z A,H LE5 DSPL %SAVE RETURN
1646  BIN1,   LOGM ADIR B,MPC A,IO
1647          CALL INCH                         %READ 1, BYTE
1650          LOGM ADIR D,SH A,A
1651          LOGM BDIR D,SC B,B3               %8 -> SC
1652          LOOP                              %SHIFT 8 LEFT
1653  BIN2,   LOGM ADIR B,MPC A,IO
1654          CALL INCH                         %READ 2, BYTE
1655          LOGM OR D,SH B,SH A,A             %JOIN
1656          JMP RETU5                         %STANDARD RETURN

1657  %MAIN MEMORY CHECK
1657  %MICRO-PROGRAM, VERSION C
1657  %NJL 6/6/73
1657  %
1657  %TESTS MEMORY FROM ADDRESS SPECIFIED IN B-REG AND UP TO
1657  %ADDRESS SPECIFIED IN X-REG
1657  %
1657  %ERROR INDICATION:
1657  %    T=FAILING BITS          [OR6 ]
1657  %    P=FAILING ADDRESS       [OR2 ]
1657  %    D=ERROR PATTERN         [OR1 ]
1657  %    L=TEST PATTERN          [OR4 ]
1657  %    B=START ADDRESS         [OR3 ]
1657  %    X=STOP ADDRESS          [OR7 ]
1657  %
1657  %IF NO ERROR IS FOUND T = 000000
1657  %
1657  %PATTERNS USED :
1657  %
1657  %    000001
1657  %    000002
1657  %    000004
1657  %    ......
1657  %    ......
1657  %    100000
1657  %
1657  %    ADDRESS STORED IN ADDRESS (THIS PATTERN IS RUN 16 TIMES)
1657  %
1657  %    AND THEIR  COMPLEMENTS
1657  %
1657  %USE OF REGISTERS IN THIS PROGRAM :
1657  %
1657  %    A = 000000  USE T AS TEST DATA
1657  %    A = 177777  USE ADDRESS AS TEST DATA
1657  %
1657  %    SCR = 000000  WRITE TEST DATA INTO CORE
1657  %    SCR = 177777  READ TEST DATA FROM CORE
1657  %
1657  %    D = 000000 USE TEST DATA AS IS
1657  %    D = 177777 USE COMPLEMENT OF TEST DATA
1657  %
1657  %    L =        TEST DATA
1657  %
1657  MMCC,   LOGM ADIR D,A A,Z                 %0 -> SS               INIT PHASE
1660  MM00,   LOGM ADIR D,D A,Z                 %0 -> D                INIT POLARITY
1661  MM0,    LOGM BDIR D,T B,B0                %1 -> T                INIT DATA
1662  MM1,    LOGM ADIR D,SCR A,Z               %0 -> SCR              INIT STORE
1663  MM2,    ARM BM1 D,P B,B CPTR              %(B) - 1 -> CP, CP -> R     INIT ADDRESS
1664  MM3,    ARM PLUS ADD1 D,L B,Z A,R         %(R) + 1 -> L          MAKE DATA
1665          LOGM ADIR A,A
1666          CLOGM ADIR ZERO D,L A,T           %(T) -> L IF (A) = 0
1667          LOGM EXOR D,L B,D A,L             %(L) -> L IF (D) = 177777
1670          LOGM ADIR A,SCR
1671          CJMP NZERO MM4                    %LOAD IF (SCR) = 0
1672          ARM A,L CWR1                      %STORE L IN (R) + 1
1673          JMP MM41
1674  MM4,    ARM CRR1
1675          LOGM EXOR B,L A,H                 %((R) + 1) -> H
1676          CJMP NZERO ERR                    %ERROR DETECTED
1677  MM41,   ARM BMINA B,X A,R                 %TEST FOR LAST LOCATION
1700          CJMP NZERO MM3                    %CONTINUE
1701          LOGM ADIRC D,SCR A,SCR            %SWITCH LOAD/STORE
1702          CJMP NZERO MM2
1703          ARM PLUS D,T B,T A,T              %T + T -> T            SWITCH DATA
1704          CJMP NZERO MM1
1705  MM45,   LOGM ADIRC D,D A,D                %                      SWITCH POLARITY
1706          CJMP NZERO MM0                    %DO COMPLEMENT
1707  MM5,    LOGM ADIRC D,A A,A                %                      SWITCH PHASE
1710          CJMP NZERO MM00                   %CONTINUE WITH ADDRESS IN ADDRESS
1711          JMP MOPC                          %END OF TEST
1712  ERR,    LOGM ADIR D,D A,H                 %DATA READ
1713          LOGM ADIR D,SP A,R                %FAILING ADDRESS R -> SP
1714          LOGM EXOR D,T B,L A,D             %FAILING BITS -> T
1715          JMP QUM                           %MOPC ERROR ENTRY-POINT

1716  %INCH
1716  %INPUT CHARACTER (BYTE) FROM DEVICE FOUND IN (SS17)
1716  %RETURNS CHARACTER IN A0
1716  %*** SCR0 IS DESTROYED ***
1716  %IF LOAD-BIT IS SET (BIT17 IN SS0) THEN THERE WILL BE NO ECHOING
1716  %ON DEVICE-NUMBER (SS17) +4
1716  INCH,   IARM PLUS ADD1 D,SCR B,Z A,H LE15 DSPL
1717  RPANT,  ILOGM ADIR D,SCR A,SS LE17        %(RETURN FROM PANTT) DN0 -> SCR
1720          ARM PLUS D,SCR B,B1 A,SCR         %DN0 + 2 -> SCR
1721          LOGM ADIR B,MPC A,IO
1722          CALL IOXR                         %READ STATUS
1723          LOGM AND B,B3 A,A                 %READY FOR TRANSFER ?
1724          CJMP ZERO PANTT                   %NO, TEST PANEL
1725          ILOGM ADIR D,SCR A,SS LE17        %YES, DN0 -> SCR
1726          LOGM ADIR B,MPC A,IO
1727          CALL IOXR                         %READ CHARACTER
1730          ILOGM ADIR D,SCR A,A DSPL LE13    %SAVE A
1731          LOGM ADIR B,MPC A,IO
1732          CALL ACT                          %ACTIVATE DEVICE
1733          ILOGM ADIR D,A A,SCR LE13         %UNSAVE A0
1734          JMP OUT1                          %FOR ECHO-ING

1735  %OUTCH
1735  %WRITES A CHARACTER ON DEVICE (SS17) +4
1735  %*** SCR0 IS DESTROYED ***
1735  OUTCH,  IARM PLUS ADD1 D,SCR B,Z A,H LE15 DSPL
1736  OUT1,   LOGM AND B,B17 A,SS
1737          CJMP NZERO OUT3                   %NO OUTPUT IF LOAD MODE
1740          ILOGM ADIR D,SCR A,A LE13 DSPL    %SAVE A0
1741          IARM PLUS ADD1 D,SCR B,Z A,SS LE17 %DN0 + 1 -> SCR
1742          ARM PLUS ADD1 D,SCR B,B2 A,SCR    %DN0 + 6 -> SCR
1743  OUT2,   LOGM ADIR B,MPC A,IO
1744          CALL IOXR                         %READ STATUS
1745          LOGM AND B,B3 A,A                 %READY FOR TRANSFER?
1746          CJMP ZERO OUT2                    %NO
1747          LOGM ADIR A,SCR                   %SCR -> AC
1750          ARM BM1 D,SCR B,AC                %DN0 + 5 -> SCR
1751          ILOGM ADIR D,A A,SCR LE13         %UNSAVE A0
1752          LOGM ADIR B,MPC A,IO
1753          CALL IOXR                         %WRITE CHARACTER
1754  OUT3,   ILOGM ADIR D,P A,SCR LE15
1755          JMP RETU                          %STANDARD RETURN

1756  %ACTIVATES DEVICE
1756  ACT,    IARM PLUS ADD1 D,SCR B,Z A,SS LE17 %DN0 + 1 -> SCR
1757          ARM PLUS D,SCR B,B1 A,SCR         %DN0 + 3 -> SCR
1760          ARM PLUS ADD1 A,Z B,B2 D,A        %5 -> A
1761          LOGM AND B,B17 A,SS               %LOAD MODE ?
1762          CJMP NZERO ACT1                   %YES. DO NOT SET PARITY ETC.
1763          ARM PLUS A,A B,B13 D,A            %4005 -> A
1764          LOGM OR D,A B,B17 A,A
1765          LOGM OR D,A B,B16 A,A             %144005 -> A
1766  ACT1,   CALL IOXR                         %(RETURN ADDRESS ALREADY IN H-REG)

1767  %THIS PROGRAM STORES THE L-REGISTER IN THE LOCATION CONTAINED
1767  %IN B-REGISTER.  IT THEN LOADS THE SAME ADDRESS INTO THE D-REGISTER
1767  %AND FORMS EXCLUSIVE OR OF L- AND D-REGISTER IN THE T-REGISTERS
1767  %THIS LOOP CAN ONLY BE TERMINATED BY PUSHING MASTER CLEAR.
1767  MLOOP,  ARM BM1 D,P B,B CPTR              %B - 1 -> CP, CP -> R
1770  MLP1,   CLOGM ADIR CWR1 ZERO A,L          %STORE L (ACTIVATE CONDITION)
1771          LOGM ADIR D,D A,H CPTR            %H -> D, CP -> R
1772          LOGM EXOR D,T B,L A,D CRR1        %L V D -> T, LOAD H
1773          JMP MLOOP

1774  % MCLS, in the listing - the second word with this label
1774          ARM A,IO BIR3                     %MCL, REG -> H
1775          LOGM ANDCB A,H B,A D,SP           %N(A), H -> SP
1776          LOGM A,SP BIR3 D,IO ADIR          %REG -> SP
1777          JMP FETCH

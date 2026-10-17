%   NORD-10/CE MICROPROGRAM  -  4k x 32 bit ROM
%
%   Words 0000-1777 are the standard NORD-10 micro program of ND-06.010.01,
%   with the labels, comments and mnemonic order of that manual's listing
%   (see NORD-10.uc for how they were read). Words 2000-7777 are the
%   NORD-10/CE extension, for which no listing is known: they are the lossless
%   disassembly of the PROM dump NORD-10-REFERENCE/NORD-10-CE-4K-prom4k.hex, with
%   every jump target given the name L<address>. The four user instructions
%   USER0..USER3 (op codes 140100, 140300, 140500, 140700) enter at 2200-2203.
%
%   Every line assembles to exactly the word the dump holds
%   (TestND110/TestND10RoundTrip.cs checks that). The one word where the two
%   dumps differ, 1064, reads IARM PLUS here, as the listing prints it.
%
0000  L0000,  JMP 1402                          %STOP
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
0060  L0060,  ARM BDIR B,B4 D,SC                %20 -> SC
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
0345  L0345,  JMP *
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
0400  L0400,  LOGM CHLEV ADIR A,P D,SP          %INTERRUPT, SAVE CP-REG
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
0473  L0473,  ARM PLUS A,SCR B,D D,D SACO       %ADD. OF LEAST MANT.
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
0534  L0534,  LOGL ADIR A,D D,SH
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
0557  L0557,  LOGM BDIR B,B5 D,SC               %40 -> SC
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
0600  L0600,  LOGM CRR1 ADIR A,H D,SH           %H -> SH, READ LEAST S. M.
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
0630  L0630,  LOGM CRR1 ADIR A,H D,SCR          %H -> SCR, READ LEAST S.M.
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
0706  L0706,  ARM BMINA B,A A,SCR D,SH          %A - SCR -> SH
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
0767  L0767,  LOGM EXOR A,H B,A                 %TEST SIGN
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
1017  L1017,  LOGM CFC OR B,B2 A,S D,S          %1 -> K, FETCH
1020  BLDAC,  LOGM AND ORBWO B,BM               %TEST BIT
1021          CJMP NZERO BLDCC+2                %JMP IF B = 1
1022  BONE1,  LOGM CFC ANDCB B,B2 A,S D,S       %0 -> K, FETCH
1023  BANDC,  LOGM AND ORBWO B,BM               %TEST BIT
1024          CJMP NZERO FETCH
1025  L1025,  LOGM CFC ANDCB B,B2 A,S D,S       %0 -> K, FETCH
1026  BANCC,  LOGM AND ORBWO B,BM               %TEST BIT
1027          CJMP NZERO BANDC+2                %JMP IF BIT = 1
1030          LOGM CFC                          %K -> K, FETCH
1031  BORAC,  LOGM AND ORBWO B,BM               %TEST BIT
1032          CJMP NZERO BORCC+2                %JMP IF BIT = 1
1033  L1033,  LOGM CFC                          %K -> K, FETCH
1034  BORCC,  LOGM AND ORBWO B,BM               %TEST BIT
1035          CJMP NZERO BORAC+2                %JMP IF BIT = 1
1036  L1036,  LOGM CFC OR B,B2 A,S D,S          %1 -> K, FETCH
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
1064          IARM PLUS A,SCR B,SH D,SCR LE10 DSPL   %60 -> SCR LEV10
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
1101  L1101,  LOGM ADIR A,A
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
1142  L1142,  JMP OUTCH                         %PRINT "?"
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
1222  L1222,  CJMP ZERO RLOOP                   %LINE FEED IGNORE
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
1312  L1312,  ARM A,Z B,MIS D,IO                %0 -> MISC
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
1401  L1401,  JMP MOPCM                         %MASTER CLEAR
1402  L1402,  JMP MOPC                          %STOP

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
1437  L1437,  LOGM OR B,B7 A,SS D,SS            %SET FLAG FOR R + I
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
1727  L1727,  CALL IOXR                         %READ CHARACTER
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

%   ---- NORD-10/CE extension, words 2000-7777: disassembly of the dump ----

2000          ARM PLUS ADD1 D,SCR B,B2 A,SCR
2001  L2001,  LOGM ADIR B,MPC A,IO
2002          JMP L1727                         %-> 1727
2003          LOGM AND B,B3 A,A
2004          CJMP ZERO L2001                   %-> 2001
2005          LOGM ADIR A,SCR
2006          ARM BM1 D,SCR B,AC
2007          ILOGM ADIR LE13 D,A A,SCR
2010          LOGM ADIR B,MPC A,IO
2011          JMP L1727                         %-> 1727
2012          ILOGM ADIR LE15 D,P A,SCR
2013          JMP L1312                         %-> 1312
2014          IARM PLUS ADD1 LE17 D,SCR A,SS
2015          ARM PLUS D,SCR B,B1 A,SCR
2016          ARM PLUS ADD1 D,A B,B2
2017          LOGM AND B,B17 A,SS
2020          CJMP NZERO L2024                  %-> 2024
2021          ARM PLUS D,A B,B13 A,A
2022          LOGM OR D,A B,B17 A,A
2023          LOGM OR D,A B,B16 A,A
2024  L2024,  JMP L1727                         %-> 1727
2025          LOGM ADIR D,A
2026  L2026,  LOGM ADIR D,D
2027  L2027,  LOGM BDIR D,T B,B0
2030  L2030,  LOGM ADIR D,SCR
2031  L2031,  ARM BM1 CPTR D,P B,B
2032  L2032,  ARM PLUS ADD1 D,L A,R
2033          LOGM ADIR A,A
2034          CLOGM ADIR ZERO D,L A,T
2035          LOGM EXOR D,L B,D A,L
2036          LOGM ADIR A,SCR
2037          CJMP NZERO L2042                  %-> 2042
2040          ARM BM1 CWR1 A,L
2041          JMP L2045                         %-> 2045
2042  L2042,  ARM BM1 CRR1
2043          LOGM EXOR B,L A,H
2044          CJMP NZERO L2060                  %-> 2060
2045  L2045,  ARM BMINA B,X A,R
2046          CJMP NZERO L2032                  %-> 2032
2047          LOGM ADIRC D,SCR A,SCR
2050          CJMP NZERO L2031                  %-> 2031
2051          ARM PLUS D,T B,T A,T
2052          CJMP NZERO L2030                  %-> 2030
2053          LOGM ADIRC D,D A,D
2054          CJMP NZERO L2027                  %-> 2027
2055          LOGM ADIRC D,A A,A
2056          CJMP NZERO L2026                  %-> 2026
2057          JMP L1142                         %-> 1142
2060  L2060,  LOGM ADIR D,D A,H
2061          LOGM ADIR D,SP A,R
2062          LOGM EXOR D,T B,L A,D
2063          JMP L1222                         %-> 1222
2064  L2064,  ARM BM1 CPTR D,P B,B
2065          CLOGM ADIR CWR1 ZERO A,L
2066          LOGM ADIR CPTR D,D A,H
2067          LOGM EXOR CRR1 D,T B,L A,D
2070          JMP L2064                         %-> 2064
2071          ARM BM1 B,BIR3 A,IO
2072          LOGM ANDCB D,SP B,A A,H
2073          LOGM ADIR D,IO B,IR3 A,SP
2074          JMP FETCH                         %-> 0101
2075  L2075,  LOGM ADIR D,SP A,P
2076          ARM BM1 D,SC B,B3
2077          ARM BM1 B,B10
2100          LOGM AND D,SCR B,AC A,A
2101          LOGL BDIR
2102          LOOP BDI BDIA B,2AC TSC0
2103          LOGM OR D,SS B,2AC A,SCR
2104          ARM BM1 B,B14
2105          LOGM AND D,SH B,AC A,T
2106          CJMP ZERO L2305                   %-> 2305
2107          LOGM ADIR D,IO B,CAR
2110          LOGM ADIRC D,P
2111          LOGM AND B,B16 A,T
2112          CLOGM ADIR NZERO D,IO B,CAR A,P
2113          ARM BM1 CPTR D,P B,X
2114          LOGM ADIR CRR1 D,P A,SP
2115          LOGL ADIR D,SH A,H
2116          LOGM AND B,B17 A,T
2117          CARM BM1 ZERO D,SH B,SH
2120          LOGM BDIR B,SH
2121          ARM PLUS B,HAC A,X
2122          ARM BM1 CPTR D,P B,AC
2123          LOGM ADIR CRR1 D,P A,SP
2124          ARM BM1 CPTR D,P B,X
2125          LOGM ADIR D,P A,SP
2126          LOGM AND B,B17 A,T
2127          CJMP NZERO L2171                  %-> 2171
2130          ARM BDI ADD1 D,SH B,SH
2131  L2131,  LOGL ADIR D,SH A,H
2132          LOGM ADIR D,SP A,A
2133          LOGM BDIR D,SCR B,B3
2134  L2134,  LOGM BDIR D,A B,B7
2135  L2135,  ARM BMINA D,SH B,SH A,SCR
2136          CJMP NEG L2163                    %-> 2163
2137          LOGM BDIRC CWR1 A,SS
2140          LOGM BDIRC CWR1 A,SS
2141          LOGM BDIRC CWR1 A,SS
2142          LOGM BDIRC CWR1 A,SS
2143          ARM BMINA D,A B,A A,SCR
2144          CJMP POS L2135                    %-> 2135
2145          ARM PLUS D,A B,B7 A,SCR
2146          LOGM BDIR B,A
2147          ARM PLUS D,X B,HAC A,X
2150          ARM BMINA D,T B,T A,A
2151          ARM BM1 B,PID A,IO
2152          LOGM ADIR D,A A,H
2153          ARM BM1 B,PIE A,IO
2154          LOGM AND D,A B,A A,H
2155          ARM BM1 B,B12
2156          LOGM ANDCB B,AC A,A
2157          CJMP NZERO L2161                  %-> 2161
2160          JMP L2134                         %-> 2134
2161  L2161,  LOGM ADIR D,A A,SP
2162          ARM BM1 CFC D,P B,P
2163  L2163,  ARM PLUS D,SH B,SH A,SCR
2164          LOGM BDIR D,SCR B,B1
2165  L2165,  ARM BMINA D,SH B,SH A,SCR
2166          CJMP NEG L2266                    %-> 2266
2167          LOGM BDIRC CWR1 A,SS
2170          JMP L2165                         %-> 2165
2171  L2171,  ARM BM1 D,SP B,B10
2172          LOGL ANDCA B,SH A,SP
2173          LOGL OR D,SCR B,AC A,SCR
2174          LOGM BDIRC CWR1 A,SCR
2175          ARM BM1 D,SH B,SH
2176          JMP L2131                         %-> 2131
2177  L2177,  ARM BM1 CFC
2200  %ENTRY POINT USER0 (op code 140100)
2200          JMP L2220                         %-> 2220
2201  %ENTRY POINT USER1 (op code 140300)
2201          JMP L4000                         %-> 4000
2202  %ENTRY POINT USER2 (op code 140500)
2202          JMP L4000                         %-> 4000
2203  %ENTRY POINT USER3 (op code 140700)
2203          JMP L4000                         %-> 4000
2204          JMP L4000                         %-> 4000
2205          JMP L4000                         %-> 4000
2206          JMP L4000                         %-> 4000
2207          JMP L4000                         %-> 4000
2210          JMP L4000                         %-> 4000
2211          JMP L4000                         %-> 4000
2212          JMP L4000                         %-> 4000
2213          JMP L4000                         %-> 4000
2214          JMP L4000                         %-> 4000
2215          JMP L4000                         %-> 4000
2216          JMP L4000                         %-> 4000
2217          JMP L4000                         %-> 4000
2220  L2220,  LOGM AND B,B5 A,H
2221          CJMP NZERO L4000                  %-> 4000
2222          LOGM AND B,B4 A,H
2223          CJMP ZERO L4000                   %-> 4000
2224          LOGM AND B,B3 A,H
2225          CJMP ZERO L2240                   %-> 2240
2226          LOGM AND B,B2 A,H
2227          CJMP NZERO L4000                  %-> 4000
2230          LOGM AND B,B1 A,H
2231          CJMP ZERO L2235                   %-> 2235
2232          LOGM AND B,B0 A,H
2233          CJMP ZERO L2306                   %-> 2306
2234          JMP L4000                         %-> 4000
2235  L2235,  LOGM AND B,B0 A,H
2236          CJMP ZERO L2075                   %-> 2075
2237          JMP L2310                         %-> 2310
2240  L2240,  LOGM ADIR D,SCR A,H
2241          ARM BM1 B,S A,IO
2242          LOGM AND B,B13 A,H
2243          CJMP NZERO L4000                  %-> 4000
2244          LOGM AND B,B2 A,SCR
2245          CJMP ZERO L2256                   %-> 2256
2246          LOGM AND B,B1 A,SCR
2247          CJMP NZERO L2253                  %-> 2253
2250          LOGM AND B,B0 A,SCR
2251          CJMP ZERO L3431                   %-> 3431
2252          JMP L4167                         %-> 4167
2253  L2253,  LOGM AND B,B0 A,SCR
2254          CJMP ZERO L5070                   %-> 5070
2255          JMP L5072                         %-> 5072
2256  L2256,  LOGM AND B,B1 A,SCR
2257          CJMP ZERO L2263                   %-> 2263
2260          LOGM AND B,B0 A,SCR
2261          CJMP ZERO L5724                   %-> 5724
2262          JMP L4000                         %-> 4000
2263  L2263,  LOGM AND B,B0 A,SCR
2264          CJMP ZERO L5730                   %-> 5730
2265          JMP L5726                         %-> 5726
2266  L2266,  ARM PLUS B,SH A,SCR
2267          CJMP ZERO L2300                   %-> 2300
2270          ARM BM1 D,SCR B,B10
2271          LOGM ANDCB D,SS B,AC A,SS
2272          LOGL AND B,SH A,SCR
2273          LOGL OR D,SS B,AC A,SS
2274          LOGM BDIRC CWR1 A,SS
2275          LOGM OR D,T B,B17 A,T
2276          LOGM ADIR D,X A,R
2277          JMP L2302                         %-> 2302
2300  L2300,  ARM PLUS ADD1 D,X A,R
2301          LOGM ANDCB D,T B,B17 A,T
2302  L2302,  LOGM ADIR D,A A,SP
2303          ARM BM1 B,B14
2304          LOGM ANDCB D,T B,AC A,T
2305  L2305,  ARM BDI ADD1 CFC D,P B,P
2306  L2306,  LOGM OR D,T B,B14 A,T
2307          JMP L2311                         %-> 2311
2310  L2310,  LOGM ANDCB D,T B,B14 A,T
2311  L2311,  ARM BM1 D,SH B,B14
2312          LOGM AND D,SCR B,SH A,T
2313          CJMP ZERO L2322                   %-> 2322
2314          LOGM ANDCB D,SP B,SH A,D
2315          LOGM ANDCB D,SS B,SH A,T
2316          LOGM AND D,SH B,SH A,D
2317          CJMP NZERO L2324                  %-> 2324
2320          LOGM AND B,B14 A,T
2321          CLOGM ADIR ZERO D,T A,SS
2322  L2322,  ARM BDI ADD1 D,P B,P
2323          JMP L3167                         %-> 3167
2324  L2324,  ARM BMINA B,SH A,SCR
2325          CLOGM BDIR NEG D,SCR B,SH
2326          LOGM AND B,B14 A,T
2327          CJMP NZERO L2335                  %-> 2335
2330          LOGM AND B,B15 A,T
2331          CJMP NZERO L2335                  %-> 2335
2332          LOGM ADIR D,SH A,SCR
2333          LOGM OR D,T B,SH A,SS
2334          LOGM OR D,D B,SH A,SP
2335  L2335,  LOGM ADIR D,SP A,P
2336          LOGM ADIR D,IO B,CAR
2337          LOGM ADIRC D,P
2340          LOGM AND B,B16 A,T
2341          CLOGM ADIR NZERO D,IO B,CAR A,P
2342          ARM BM1 CPTR D,P B,X
2343          LOGM ADIR CRR1 D,P A,SP
2344          LOGL ADIR D,SH A,SCR
2345          LOGM AND B,B17 A,T
2346          CARL BM1 ZERO D,SH B,SH
2347          LOGL BDIR B,SH
2350          ARL PLUS D,SH B,HAC A,X
2351          ARL BM1 CPTR D,P B,AC
2352          LOGM ADIR CRR1 D,P A,SP
2353          LOGM ADIR D,IO B,CAR
2354          LOGM ADIRC D,P
2355          LOGM AND B,B16 A,D
2356          CLOGM ADIR NZERO D,IO B,CAR A,P
2357          ARM BM1 CPTR D,P B,A
2360          LOGM ADIR CRR1 D,P A,SP
2361          LOGM ADIR D,SH A,SCR
2362          JMP L2363                         %-> 2363
2363  L2363,  LOGM AND B,B17 A,D
2364          CARM BM1 ZERO D,SH B,SH
2365          LOGM BDIR B,SH
2366          ARM PLUS D,SS B,HAC A,A
2367          ARM BM1 CPTR D,P B,AC
2370          LOGM ADIR CRR1 D,P A,SP
2371          LOGM ANDCB D,D B,B14 A,D
2372          LOGM EXOR D,P B,T A,D
2373          LOGM AND B,B16 A,P
2374          CJMP NZERO L2420                  %-> 2420
2375          LOGM AND B,B14 A,T
2376          CJMP NZERO L2403                  %-> 2403
2377          LOGM BDIR D,P B,B14
2400          ARM BMAM1 B,X A,A
2401          CLOGM OR POS D,D B,D A,P
2402          JMP L2420                         %-> 2420
2403  L2403,  ARM BMAM1 B,X A,SS
2404          CJMP POSM L2420                   %-> 2420
2405          ARM BMAM1 B,X A,A
2406          CJMP NEGM L2420                   %-> 2420
2407          ARM BMINA B,X A,SS
2410          CJMP NZERO L2416                  %-> 2416
2411          LOGM AND B,B17 A,T
2412          CJMP ZERO L2416                   %-> 2416
2413          LOGM BDIR D,P B,SH
2414          LOGM AND B,B0 A,P
2415          CJMP ZERO L2420                   %-> 2420
2416  L2416,  LOGM ADIR D,P A,SP
2417          LOGM ANDCB CFC D,T B,B14 A,T
2420  L2420,  LOGM AND B,B17 A,D
2421          CJMP NZERO L2425                  %-> 2425
2422          LOGM AND B,B17 A,T
2423          CJMP ZERO L2626                   %-> 2626
2424          JMP L2635                         %-> 2635
2425  L2425,  LOGM AND B,B17 A,T
2426          CJMP ZERO L3067                   %-> 3067
2427          LOGM AND B,B14 A,D
2430          CJMP NZERO L2526                  %-> 2526
2431          LOGM ADIR D,SS A,SCR
2432          ARM BM1 B,MPC A,IO
2433          JMP L3204                         %-> 3204
2434          ARM BDI ADD1 D,A B,A
2435          ARM BDI ADD1 D,X B,X
2436          LOGM ADIR A,SS
2437          ARM BM1 D,SCR B,AC
2440          ARM BM1 D,D B,D
2441          LOGM AND B,B14 A,T
2442          CARM BM1 NZERO D,T B,T
2443  L2443,  LOGM ADIR D,SS A,L
2444  L2444,  LOGM BDIR D,L B,B6
2445          ARM BMINA B,B6 A,SCR
2446          CLOGM ADIR POS D,L A,SCR
2447  L2447,  LOGM BDIR D,SCR B,B3
2450          ARM BMINA D,L B,L A,SCR
2451          CJMP NEG L2476                    %-> 2476
2452          LOGM ADIR D,IO B,CAR
2453          LOGM ADIRC D,P
2454          LOGM AND B,B16 A,D
2455          CLOGM ADIR NZERO D,IO B,CAR A,P
2456          ARM BM1 CPTR D,P B,A
2457          ARM PLUS CRR1 D,A B,B2 A,A
2460          LOGM ADIR CRR1 D,SCR A,H
2461          LOGM ADIR CRR1 D,SH A,H
2462          LOGL ADIR CRR1 D,SH A,H
2463          LOGM ADIR D,IO B,CAR
2464          LOGM ADIRC D,P
2465          LOGM AND B,B16 A,T
2466          CLOGM ADIR NZERO D,IO B,CAR A,P
2467          ARM BM1 CPTR D,P B,X
2470          LOGM BDIR CWR1 D,P B,SH A,SCR
2471          LOGL BDIR CWR1 D,SCR B,SH A,P
2472          ARM BM1 CWR1 A,SCR
2473          ARM BM1 CWR1 A,H
2474          ARM PLUS D,X B,B2 A,X
2475          JMP L2447                         %-> 2447
2476  L2476,  ARM BM1 B,MPC A,IO
2477          JMP L3316                         %-> 3316
2500          JMP L2444                         %-> 2444
2501          LOGM BDIR D,SCR B,B1
2502  L2502,  ARM BMINA D,L B,L A,SCR
2503          CJMP NEG L2521                    %-> 2521
2504          LOGM ADIR D,IO B,CAR
2505          LOGM ADIRC D,P
2506          LOGM AND B,B16 A,D
2507          CLOGM ADIR NZERO D,IO B,CAR A,P
2510          ARM BM1 CPTR D,P B,A
2511          ARM BDI ADD1 CRR1 D,A B,A
2512          LOGM ADIR D,IO B,CAR
2513          LOGM ADIRC D,P
2514          LOGM AND B,B16 A,T
2515          CLOGM ADIR NZERO D,IO B,CAR A,P
2516          ARM BM1 CPTR D,P B,X
2517          ARM BDI ADD1 CWR1 D,X B,X A,H
2520          JMP L2502                         %-> 2502
2521  L2521,  ARM PLUS D,L B,B1 A,L
2522          CJMP ZERO L3116                   %-> 3116
2523          ARM BM1 B,MPC A,IO
2524          JMP L3230                         %-> 3230
2525          JMP L3116                         %-> 3116
2526  L2526,  LOGM ADIR D,A A,SS
2527          LOGL BDIR D,X B,SH
2530          LOGM AND B,B0 A,SCR
2531          CJMP NZERO L2542                  %-> 2542
2532  L2532,  LOGM ADIR D,SS A,SCR
2533          ARM BM1 B,MPC A,IO
2534          JMP L3230                         %-> 3230
2535          ARM BM1 D,X B,X
2536          ARM BM1 D,A B,A
2537          LOGM ADIR A,SS
2540          ARM BM1 D,SCR B,AC
2541          ARM BM1 D,D B,D
2542  L2542,  LOGM ADIR D,SS A,L
2543  L2543,  LOGM BDIR D,L B,B6
2544          ARM BMINA B,B6 A,SCR
2545          CLOGM ADIR POS D,L A,SCR
2546  L2546,  LOGM BDIR D,SCR B,B3
2547          ARM BMINA D,L B,L A,SCR
2550          CJMP NEG L2576                    %-> 2576
2551          LOGM ADIR D,IO B,CAR
2552          LOGM ADIRC D,P
2553          LOGM AND B,B16 A,D
2554          CLOGM ADIR NZERO D,IO B,CAR A,P
2555          LOGM BDIR D,SCR B,B2
2556          ARM BMINA D,A B,A A,SCR
2557          LOGM ADIR CPTR D,P A,A
2560          ARM BMINA CRR1 D,X B,X A,SCR
2561          LOGM ADIR CRR1 D,SCR A,H
2562          LOGM ADIR CRR1 D,SH A,H
2563          LOGL ADIR CRR1 D,SH A,H
2564          LOGM ADIR D,IO B,CAR
2565          LOGM ADIRC D,P
2566          LOGM AND B,B16 A,T
2567          CLOGM ADIR NZERO D,IO B,CAR A,P
2570          LOGM ADIR CPTR D,P A,X
2571          LOGM BDIR CWR1 D,P B,SH A,SCR
2572          LOGL BDIR CWR1 D,SCR B,SH A,P
2573          ARM BM1 CWR1 A,SCR
2574          ARM BM1 CWR1 A,H
2575          JMP L2546                         %-> 2546
2576  L2576,  ARM BM1 B,MPC A,IO
2577          JMP L3366                         %-> 3366
2600          JMP L2543                         %-> 2543
2601          LOGM BDIR D,SCR B,B1
2602  L2602,  ARM BMINA D,L B,L A,SCR
2603          CJMP NEG L2621                    %-> 2621
2604          LOGM ADIR D,IO B,CAR
2605          LOGM ADIRC D,P
2606          LOGM AND B,B16 A,D
2607          CLOGM ADIR NZERO D,IO B,CAR A,P
2610          ARM BM1 CPTR D,P B,A
2611          ARM BM1 CRR1 D,A B,A
2612          LOGM ADIR D,IO B,CAR
2613          LOGM ADIRC D,P
2614          LOGM AND B,B16 A,T
2615          CLOGM ADIR NZERO D,IO B,CAR A,P
2616          ARM BM1 CPTR D,P B,X
2617          ARM BM1 CWR1 D,X B,X A,H
2620          JMP L2602                         %-> 2602
2621  L2621,  ARM BDI ADD1 D,L B,L
2622          CJMP NZERO L3103                  %-> 3103
2623          ARM BM1 B,MPC A,IO
2624          JMP L3204                         %-> 3204
2625          JMP L3103                         %-> 3103
2626  L2626,  LOGM AND B,B14 A,D
2627          CJMP ZERO L2443                   %-> 2443
2630          LOGM ADIR D,A A,SS
2631          LOGL BDIR D,X B,SH
2632          LOGM AND B,B0 A,SCR
2633          CJMP NZERO L2532                  %-> 2532
2634          JMP L2542                         %-> 2542
2635  L2635,  LOGM AND B,B14 A,D
2636          CJMP NZERO L2751                  %-> 2751
2637          ARM BM1 CPTR D,P B,A
2640          ARM BM1 CRR1
2641          LOGM ADIR D,SH A,H
2642          LOGM ADIR D,SS A,H
2643          ARM BM1 B,MPC A,IO
2644          JMP L3275                         %-> 3275
2645          ARM BDI ADD1 D,X B,X
2646          LOGM ADIR A,SCR
2647          ARM BM1 D,SCR B,AC
2650          ARM BM1 D,D B,D
2651          LOGM AND B,B14 A,T
2652          CARM BM1 NZERO D,T B,T
2653          LOGM ADIR D,SH A,SS
2654  L2654,  ARM BDI ADD1 D,A B,A
2655          LOGM ADIR D,SS A,L
2656  L2656,  LOGM BDIR D,L B,B6
2657          ARM BMINA B,B6 A,SCR
2660          CLOGM ADIR POS D,L A,SCR
2661          LOGM BDIR D,SCR B,B2
2662  L2662,  LOGM ADIR D,IO B,CAR
2663          LOGM ADIRC D,P
2664          LOGM AND B,B16 A,D
2665          CLOGM ADIR NZERO D,IO B,CAR A,P
2666          ARM BM1 CPTR D,P B,A
2667          ARM BMINA D,L B,L A,SCR
2670          CJMP NEG L2714                    %-> 2714
2671          ARM BM1 D,P B,B10
2672          LOGM AND CRR1 D,SH B,SH A,P
2673          LOGL ADIR CRR1 D,SH A,H
2674          LOGM ANDCB D,P B,P A,H
2675          LOGM OR D,SH B,SH A,P
2676          LOGM BDIR D,SC B,B3
2677          LOOP BM1 BM1A SHRO SH32 TSC0
2700          LOGM ADIR D,IO B,CAR
2701          LOGM ADIRC D,P
2702          LOGM AND B,B16 A,T
2703          CLOGM ADIR NZERO D,IO B,CAR A,P
2704          ARM BM1 CPTR D,P B,X
2705          LOGM BDIR D,P B,SH
2706          ARM BDI ADD1 CWR1 D,A B,A A,P
2707          LOGL BDIR D,P B,SH
2710          ARM BDI ADD1 CWR1 D,A B,A A,P
2711          ARM PLUS D,X B,B1 A,X
2712          LOGM ADIR D,SH A,H
2713          JMP L2662                         %-> 2662
2714  L2714,  ARM BM1 B,MPC A,IO
2715          JMP L3316                         %-> 3316
2716          JMP L2656                         %-> 2656
2717          ARM BMINA B,B0 A,L
2720          CJMP NEG L2726                    %-> 2726
2721  L2721,  ARM BMINA B,B0 A,L
2722          CJMP NZERO L3126                  %-> 3126
2723          ARM BM1 B,MPC A,IO
2724          JMP L3254                         %-> 3254
2725          JMP L3126                         %-> 3126
2726  L2726,  ARM BM1 CPTR D,P B,A
2727          ARM BM1 CRR1 D,P B,B10
2730          LOGM AND D,SCR B,SH A,P
2731          LOGM ANDCB B,P A,H
2732          LOGM OR D,SH B,AC A,SCR
2733          LOGM BDIR D,SC B,B3
2734          LOOP BM1 BM1A SHRO TSC0
2735          LOGM BDIR D,SCR B,SH
2736          LOGM ADIR D,IO B,CAR
2737          LOGM ADIRC D,P
2740          LOGM AND B,B16 A,T
2741          CLOGM ADIR NZERO D,IO B,CAR A,P
2742          ARM BM1 CPTR D,P B,X
2743          ARM BDI ADD1 CWR1 D,X B,X A,SCR
2744          ARM BDI ADD1 D,A B,A
2745          ARM BM1 D,L B,L
2746          ARM BM1 D,L B,L
2747          LOGM ADIR D,SH A,H
2750          JMP L2721                         %-> 2721
2751  L2751,  LOGM ADIR D,A A,SS
2752          LOGL BDIR D,X B,SH
2753          LOGM ADIR D,SH A,H
2754          LOGM AND B,B0 A,SCR
2755          CJMP NZERO L2766                  %-> 2766
2756  L2756,  LOGM ADIR D,SS A,H
2757          ARM BM1 B,MPC A,IO
2760          JMP L3254                         %-> 3254
2761          ARM BM1 D,X B,X
2762          LOGM ADIR A,SCR
2763          ARM BM1 D,SCR B,AC
2764          ARM BM1 D,D B,D
2765          LOGM ADIR D,SH A,SS
2766  L2766,  ARM BM1 D,A B,A
2767          LOGM BDIR D,SS B,L
2770  L2770,  LOGM BDIR D,L B,B6
2771          ARM BMINA B,B6 A,SCR
2772          CLOGM ADIR POS D,L A,SCR
2773          LOGM BDIR D,SCR B,B2
2774  L2774,  LOGM ADIR D,IO B,CAR
2775          LOGM ADIRC D,P
2776          LOGM AND B,B16 A,D
2777          CLOGM ADIR NZERO D,IO B,CAR A,P
3000          ARM BMINA D,L B,L A,SCR
3001          CJMP NEG L3032                    %-> 3032
3002          ARM BM1 CPTR D,P B,A
3003          ARM BM1 D,P B,B10
3004          LOGM ANDCA CRR1 D,SH B,SH A,P
3005          ARM BM1 D,A B,A
3006          ARM BM1 CPTR D,P B,A
3007          LOGL ADIR CRR1 D,SH A,H
3010          ARM BM1 B,B10
3011          LOGM AND D,P B,AC A,H
3012          LOGM OR D,SH B,SH A,P
3013          LOGM BDIR D,SC B,B3
3014          LOOP BM1 BM1A SHRO SH32 TSC0
3015          ARM BM1 D,X B,X
3016          ARM BM1 D,X B,X
3017          LOGM ADIR D,IO B,CAR
3020          LOGM ADIRC D,P
3021          LOGM AND B,B16 A,T
3022          CLOGM ADIR NZERO D,IO B,CAR A,P
3023          LOGM ADIR CPTR D,P A,X
3024          LOGM BDIR D,P B,SH
3025          ARM BM1 CWR1 D,A B,A A,P
3026          LOGL BDIR D,P B,SH
3027          ARM BM1 CWR1 A,P
3030          LOGM ADIR D,SH A,H
3031          JMP L2774                         %-> 2774
3032  L3032,  ARM BM1 B,MPC A,IO
3033          JMP L3366                         %-> 3366
3034          JMP L2770                         %-> 2770
3035          ARM BMINA B,B0 A,L
3036          CJMP NEGM L3044                   %-> 3044
3037  L3037,  ARM BMINA B,B0 A,L
3040          CJMP NZERO L3137                  %-> 3137
3041          ARM BM1 B,MPC A,IO
3042          JMP L3275                         %-> 3275
3043          JMP L3142                         %-> 3142
3044  L3044,  ARM BM1 CPTR D,P B,A
3045          ARM BM1 CRR1 D,P B,B10
3046          LOGM ANDCA D,SCR B,SH A,P
3047          LOGM AND B,P A,H
3050          LOGM OR D,SH B,AC A,SCR
3051          LOGM BDIR D,SC B,B3
3052          LOOP BM1 BM1A SHRO TSC0
3053          LOGM BDIR D,SCR B,SH
3054          LOGM ADIR D,IO B,CAR
3055          LOGM ADIRC D,P
3056          LOGM AND B,B16 A,T
3057          CLOGM ADIR NZERO D,IO B,CAR A,P
3060          ARM BM1 CPTR D,P B,X
3061          ARM BM1 CWR1 D,A B,A A,SCR
3062          ARM BM1 D,L B,L
3063          ARM BM1 D,L B,L
3064          ARM BM1 D,X B,X
3065          LOGM ADIR D,SH A,H
3066          JMP L3037                         %-> 3037
3067  L3067,  LOGM AND B,B14 A,D
3070          CJMP NZERO L3075                  %-> 3075
3071          ARM BM1 CPTR D,P B,A
3072          ARM BM1 CRR1
3073          LOGM ADIR D,SH A,H
3074          JMP L2654                         %-> 2654
3075  L3075,  LOGM ADIR D,A A,SS
3076          LOGL BDIR D,X B,SH
3077          LOGM ADIR D,SH A,H
3100          LOGM AND B,B0 A,SCR
3101          CJMP ZERO L2766                   %-> 2766
3102          JMP L2756                         %-> 2756
3103  L3103,  ARM BM1 B,B14
3104          LOGM AND D,SH B,AC A,T
3105          LOGM AND B,B17 A,T
3106          CARM BDI ADD1 NZERO D,SH B,SH
3107          LOGM BDIR B,SH
3110          LOGM BDIR D,SH B,HAC
3111          LOGM AND B,B17 A,T
3112          CARM BDI ADD1 ZERO D,SH B,SH
3113          ARM PLUS D,A B,SH A,A
3114          ARM PLUS D,X B,SH A,X
3115          JMP L3151                         %-> 3151
3116  L3116,  LOGM ADIR A,L
3117          CJMP NZERO L3123                  %-> 3123
3120          LOGM ANDCB D,T B,B17 A,T
3121          LOGM ANDCB D,D B,B17 A,D
3122          JMP L3165                         %-> 3165
3123  L3123,  LOGM OR D,T B,B17 A,T
3124          LOGM OR D,D B,B17 A,D
3125          JMP L3165                         %-> 3165
3126  L3126,  LOGM ADIR A,L
3127          CJMP NZERO L3134                  %-> 3134
3130          ARM BM1 D,A B,A
3131          LOGM ANDCB D,T B,B17 A,T
3132          LOGM OR D,D B,B17 A,D
3133          JMP L3165                         %-> 3165
3134  L3134,  LOGM OR D,T B,B17 A,T
3135          LOGM ANDCB D,D B,B17 A,D
3136          JMP L3165                         %-> 3165
3137  L3137,  LOGM AND B,B0 A,T
3140          CARM BDI ADD1 NZERO D,A B,A
3141          JMP L3144                         %-> 3144
3142  L3142,  LOGM AND B,B0 A,T
3143          CARM BM1 ZERO D,X B,X
3144  L3144,  ARM BM1 B,B14
3145          LOGM AND B,AC A,T
3146          LOGM BDIR D,SH B,HAC
3147          ARM PLUS ADD1 D,A B,SH A,A
3150          ARM PLUS ADD1 D,X B,SH A,X
3151  L3151,  LOGM AND B,B0 A,T
3152          CJMP ZERO L3165                   %-> 3165
3153          LOGM AND B,B17 A,D
3154          CJMP ZERO L3157                   %-> 3157
3155          LOGM ANDCB D,D B,B17 A,D
3156          JMP L3160                         %-> 3160
3157  L3157,  LOGM OR D,D B,B17 A,D
3160  L3160,  LOGM AND B,B17 A,T
3161          CJMP ZERO L3164                   %-> 3164
3162          LOGM ANDCB D,T B,B17 A,T
3163          JMP L3165                         %-> 3165
3164  L3164,  LOGM OR D,T B,B17 A,T
3165  L3165,  ARM PLUS ADD1 D,P A,SP
3166          LOGM ADIR D,L A,SS
3167  L3167,  LOGM ANDCB D,T B,B15 A,T
3170          LOGM ANDCB D,D B,B14 A,D
3171          ARM BM1 D,SCR B,B14
3172          LOGM AND B,B14 A,T
3173          CJMP NZERO L3175                  %-> 3175
3174          LOGM ANDCA CFC D,D B,D A,SCR
3175  L3175,  LOGM AND D,SS B,D A,SCR
3176          LOGM AND D,SH B,T A,SCR
3177          ARM BMINA B,SH A,SS
3200          CLOGM BDIR NEG D,SS B,SH
3201          ARM BMINA D,D B,D A,SS
3202          ARM BMINA D,T B,T A,SS
3203          LOGM ANDCB CFC D,T B,B14 A,T
3204  L3204,  ARL PLUS D,SH B,B0 A,H
3205          LOGM ADIR D,IO B,CAR
3206          LOGM ADIRC D,P
3207          LOGM AND B,B16 A,D
3210          CLOGM ADIR NZERO D,IO B,CAR A,P
3211          ARM BM1 CPTR D,P B,A
3212          ARM BM1 CRR1 D,SH B,B10
3213          LOGM ADIR D,IO B,CAR
3214          LOGM ADIRC D,P
3215          LOGM AND B,B16 A,T
3216          CLOGM ADIR NZERO D,IO B,CAR A,P
3217          ARM BM1 CPTR D,P B,X
3220          LOGM AND CRR1 D,SCR B,SH A,H
3221          LOGM ANDCB B,SH A,H
3222          LOGM OR D,SCR B,AC A,SCR
3223          ARM BM1 CPTR D,P B,X
3224          ARM BM1 CWR1 A,SCR
3225          LOGL BDIR D,SCR B,SH
3226          ARM BM1 D,IO B,CAR A,SCR
3227          JMP ,CAR
3230  L3230,  ARL PLUS D,SH B,B0 A,H
3231          LOGM ADIR D,IO B,CAR
3232          LOGM ADIRC D,P
3233          LOGM AND B,B16 A,D
3234          CLOGM ADIR NZERO D,IO B,CAR A,P
3235          ARM BM1 CPTR D,P B,A
3236          ARM BM1 CRR1 D,SH B,B10
3237          LOGM ADIR D,IO B,CAR
3240          LOGM ADIRC D,P
3241          LOGM AND B,B16 A,T
3242          CLOGM ADIR NZERO D,IO B,CAR A,P
3243          ARM BM1 CPTR D,P B,X
3244          LOGM ANDCB CRR1 D,SCR B,SH A,H
3245          LOGM AND B,SH A,H
3246          LOGM OR D,SCR B,AC A,SCR
3247          ARM BM1 CPTR D,P B,X
3250          ARM BM1 CWR1 A,SCR
3251          LOGL BDIR D,SCR B,SH
3252          ARM BM1 D,IO B,CAR A,SCR
3253          JMP ,CAR
3254  L3254,  ARL PLUS D,SH B,B0 A,H
3255          LOGM ADIR D,IO B,CAR
3256          LOGM ADIRC D,P
3257          LOGM AND B,B16 A,T
3260          CLOGM ADIR NZERO D,IO B,CAR A,P
3261          ARM BM1 CPTR D,P B,X
3262          LOGL BDIR CRR1 D,P B,SH
3263          ARM BM1 D,IO B,CAR A,P
3264          LOGM BDIR D,SC B,B3
3265          LOOP BM1 BM1A SHZE TSC0
3266          ARM BM1 B,B10
3267          LOGM AND D,P B,AC A,H
3270          LOGM OR D,SH B,SH A,P
3271          ARM BM1 CPTR D,P B,X
3272          LOGM BDIR D,P B,SH
3273          LOGM BDIRC CWR1 A,P
3274          JMP ,CAR
3275  L3275,  ARL PLUS D,SH B,B0 A,H
3276          LOGM ADIR D,IO B,CAR
3277          LOGM ADIRC D,P
3300          LOGM AND B,B16 A,T
3301          CLOGM ADIR NZERO D,IO B,CAR A,P
3302          ARM BM1 CPTR D,P B,X
3303          LOGL BDIR CRR1 D,P B,SH
3304          ARM BM1 D,IO B,CAR A,P
3305          LOGM BDIR D,SC B,B3
3306          LOOP BM1 BM1A SHR SHZE TSC0
3307          ARM BM1 B,B10
3310          LOGM ANDCB D,P B,AC A,H
3311          LOGM OR D,SH B,SH A,P
3312          ARM BM1 CPTR D,P B,X
3313          LOGM BDIR D,P B,SH
3314          ARM BM1 CWR1 A,P
3315          JMP ,CAR
3316  L3316,  ARM PLUS D,L B,L A,SCR
3317          ARM BM1 D,P B,B14
3320          LOGM AND D,SCR B,AC A,D
3321          LOGM AND D,P B,T A,P
3322          ARM BMINA B,AC A,SCR
3323          CLOGM ADIR NEG D,SCR A,P
3324          ARM BMINA D,SCR B,B6 A,SCR
3325          CJMP NEGM L3331                   %-> 3331
3326          ARM PLUS D,SCR B,B1 A,H
3327          ARM BM1 D,IO B,CAR A,SCR
3330          JMP ,CAR
3331  L3331,  LOGM BDIR D,L B,B6
3332          ARM BMINA D,D B,D A,L
3333          LOGM AND B,B14 A,T
3334          CARM BMINA NZERO D,T B,T A,L
3335          ARM PLUS D,L B,B0 A,H
3336          ARM BM1 D,IO B,CAR A,L
3337          ARM BM1 B,PID A,IO
3340          LOGM ADIR D,L A,H
3341          ARM BM1 B,PIE A,IO
3342          LOGM AND D,L B,L A,H
3343          ARM BM1 B,B12
3344          LOGM ANDCB B,AC A,L
3345          CJMP NZERO L3350                  %-> 3350
3346          ARM BMINA D,SCR A,SCR
3347          JMP ,CAR
3350  L3350,  LOGM ADIR A,SP
3351          ARM BM1 D,P B,AC
3352          LOGM ADIR D,L A,SS
3353          LOGM OR D,T B,B15 A,T
3354          LOGM OR D,SS B,T A,D
3355          LOGM AND B,B17 A,SS
3356          CJMP ZERO L2177                   %-> 2177
3357          LOGM AND B,B17 A,T
3360          CJMP ZERO L3365                   %-> 3365
3361          ARM BDI ADD1 D,D B,D
3362          LOGM AND B,B14 A,T
3363          CARM BDI ADD1 NZERO D,T B,T
3364          ARM BM1 D,X B,X
3365  L3365,  ARM BM1 CFC D,A B,A
3366  L3366,  ARM PLUS D,L B,L A,SCR
3367          ARM BM1 D,P B,B14
3370          LOGM AND D,SCR B,AC A,D
3371          ARM BMINA D,SCR B,B6 A,SCR
3372          CJMP NEG L3376                    %-> 3376
3373          ARM PLUS D,SCR B,B1 A,H
3374          ARM BM1 D,IO B,CAR A,SCR
3375          JMP ,CAR
3376  L3376,  LOGM BDIR D,L B,B6
3377          ARM BMINA D,D B,D A,L
3400          ARM PLUS D,L B,B0 A,H
3401          ARM BM1 D,IO B,CAR A,L
3402          ARM BM1 B,PID A,IO
3403          LOGM ADIR D,L A,H
3404          ARM BM1 B,PIE A,IO
3405          LOGM AND D,L B,L A,H
3406          ARM BMINA D,SCR A,SCR
3407          ARM BM1 B,B12
3410          LOGM ANDCB B,AC A,L
3411          CJMP NZERO L3413                  %-> 3413
3412          JMP ,CAR
3413  L3413,  LOGM ADIR A,SP
3414          ARM BM1 D,P B,AC
3415          LOGM ADIR D,L A,SS
3416          LOGM OR D,T B,B15 A,T
3417          LOGM ADIR D,SH A,SCR
3420          ARM BM1 B,SH
3421          LOGM BDIR B,AC
3422          LOGM BDIR D,SCR B,HAC
3423          ARM BMINA D,A B,A A,SCR
3424          ARM BMINA D,X B,X A,SCR
3425          LOGM AND B,B17 A,D
3426          CJMP NZERO L2177                  %-> 2177
3427          LOGM AND B,B17 A,T
3430          CARM BDI ADD1 CFC NZERO D,A B,A
3431  L3431,  ARM BM1 B,MPC A,IO
3432          JMP L5040                         %-> 5040
3433          ARM BM1 B,B5
3434          ILOGM AND DSPL LE13 D,SS B,AC A,T
3435          CJMP NZERO L3440                  %-> 3440
3436          IARM BM1 DSPL LE13 D,SCR B,X
3437          JMP L3455                         %-> 3455
3440  L3440,  ILOGM ADIR LE10 D,P A,SCR
3441          ARM BM1 D,IO B,CAR A,P
3442          ARM BM1 CPTR D,P B,X
3443          ILOGM ADIR CRR1 LE17 D,P A,SCR
3444          LOGM ADIR D,SCR A,X
3445          LOGM ADIR D,SS A,T
3446          ARM BM1 B,MPC A,IO
3447          JMP L4725                         %-> 4725
3450          ILOGM ADIR DSPL LE13 D,SS A,SS
3451          ILOGM BDIR DSPL LE13 D,SCR B,SH
3452          ARM BM1 CPTR D,P B,SH
3453          ILOGM ADIR CRR1 LE17 D,P A,SCR
3454          ILOGM ADIR DSPL LE14 D,SCR A,H
3455  L3455,  LOGM BDIR D,SCR B,B4
3456          LOGM OR D,SCR B,B5 A,SCR
3457          ILOGM ADIR DSPL LE15 D,SS A,SCR
3460          LOGM OR D,SCR B,B3 A,SCR
3461          LOGM OR D,SCR B,B1 A,SCR
3462          ILOGM ADIR DSPL LE14 D,SS A,SCR
3463          LOGM BDIR D,SCR B,B14
3464          LOGM OR D,SCR B,B15 A,SCR
3465          ILOGM ADIR DSPL LE11 D,SS A,SCR
3466          LOGM OR D,SCR B,B13 A,SCR
3467          LOGM OR D,SCR B,B11 A,SCR
3470          ILOGM ADIR DSPL LE11 D,SCR A,SCR
3471          ARM BM1 B,B5
3472          LOGM AND B,AC A,D
3473          CJMP NZERO L3500                  %-> 3500
3474          ARM BM1 D,B B,A
3475          LOGM BDIR D,SCR B,B4
3476          ILOGM ADIR LE13 D,L A,SCR
3477          JMP L3566                         %-> 3566
3500  L3500,  ILOGM ADIR LE10 D,P A,SS
3501          ARM BM1 D,IO B,CAR A,P
3502          ARM BM1 CPTR D,P B,A
3503          ILOGM ADIR CRR1 LE17 D,P A,SCR
3504          LOGM ANDCB D,P B,B7 A,H
3505          LOGM ANDCB D,P B,B17 A,P
3506          ILOGM ADIR DSPL LE12 D,SCR A,P
3507          LOGM ADIR D,SCR A,A
3510          LOGM ADIR D,SS A,D
3511          ARM BM1 B,MPC A,IO
3512          JMP L4711                         %-> 4711
3513          ARM BMINA B,SH A,A
3514          CJMP NZERO L3525                  %-> 3525
3515          ILOGM ADIR LE12 D,SP A,SCR
3516          ARL BM1 D,SH B,B10
3517          LOGM AND B,B17 A,D
3520          CJMP ZERO L3530                   %-> 3530
3521          LOGL AND B,SH A,SP
3522          ILOGL OR LE11 D,SP B,AC A,SS
3523          LOGL BDIRC D,SH B,SH
3524          JMP L3530                         %-> 3530
3525  L3525,  ARM BM1 CPTR D,P B,SH
3526          ILOGM ADIR CRR1 LE17 D,P A,SCR
3527          LOGM ADIR D,SP A,H
3530  L3530,  ARM BM1 D,B B,SH
3531          ILOGM ADIR LE13 D,L A,SCR
3532          LOGM ADIR D,SCR
3533          ARM BM1 B,MPC A,IO
3534          JMP L4744                         %-> 4744
3535          ARM BM1 D,SCR B,B14
3536          ARM BM1 B,B10
3537          ILOGM ANDCB DSPL LE13 D,SCR B,AC A,SCR
3540          LOGM ANDCB D,SP B,B7 A,SP
3541          LOGM ANDCB D,SP B,B17 A,SP
3542          LOGM AND B,B15 A,D
3543          CJMP NZERO L3563                  %-> 3563
3544          LOGM AND B,B14 A,D
3545          CJMP NZERO L3551                  %-> 3551
3546          LOGM AND B,B13 A,D
3547          CJMP NZERO L3702                  %-> 3702
3550          JMP L3572                         %-> 3572
3551  L3551,  ARM BMINA B,SH A,A
3552          CJMP NZERO L3560                  %-> 3560
3553          LOGL AND D,SH B,SH A,SP
3554          LOGM AND B,B17 A,D
3555          CJMP ZERO L3557                   %-> 3557
3556          ILOGL OR LE15 D,SH B,SH A,SS
3557  L3557,  ILOGL OR LE11 D,SP B,SH A,SS
3560  L3560,  LOGM AND B,B13 A,D
3561          CJMP NZERO L3746                  %-> 3746
3562          JMP L3605                         %-> 3605
3563  L3563,  LOGM BDIR D,SCR B,B3
3564          LOGM AND B,B0 A,SS
3565          CLOGM ADIR ZERO D,SCR
3566  L3566,  LOGM BDIR D,SS B,B1
3567          LOGM OR D,SS B,B3 A,SS
3570          LOGM ADIR D,D
3571          JMP L3760                         %-> 3760
3572  L3572,  LOGM ADIR D,SH A,SP
3573          LOGM AND B,B0 A,SS
3574          CJMP ZERO L3601                   %-> 3601
3575          LOGM BDIR D,SCR B,B4
3576          LOGM BDIR D,SC B,B3
3577          LOOP BM1 BM1A SHR SHZE TSC0
3600          JMP L3620                         %-> 3620
3601  L3601,  LOGM BDIR D,SCR B,B3
3602          ARM BM1 D,SS B,B10
3603          LOGM AND D,SH B,SH A,SS
3604          JMP L3620                         %-> 3620
3605  L3605,  ILOGM ADIR LE12 D,SH A,SCR
3606          LOGM BDIR D,SCR B,B3
3607          LOGM AND B,B0 A,SS
3610          CLOGM ADIR ZERO D,SCR
3611          LOGM AND B,B17 A,D
3612          CJMP ZERO L3616                   %-> 3616
3613          ARM BM1 D,SS B,B10
3614          LOGM AND D,SH B,SH A,SS
3615          JMP L3620                         %-> 3620
3616  L3616,  LOGM BDIR D,SC B,B3
3617          LOOP BM1 BM1A SHR SHZE TSC0
3620  L3620,  ARM BDI ADD1 D,SS B,B6
3621          LOGM OR D,SS B,B3 A,SS
3622          ARM BMAM1 B,SH A,SS
3623          CJMP NEG L3645                    %-> 3645
3624          ARM PLUS ADD1 D,T B,B3 A,SS
3625          ARM BMAM1 B,SH A,T
3626          CJMP NEG L3641                    %-> 3641
3627          LOGM BDIR D,T B,SH
3630          LOGM BDIR D,SH
3631          ARM BM1 D,SS B,B7
3632          LOGM ANDCB D,SS B,B2 A,SS
3633          ARM BMINA B,T A,SS
3634          CJMP ZERO L3652                   %-> 3652
3635          ARM PLUS D,SS B,B1 A,SS
3636          ARM BMINA B,T A,SS
3637          CJMP ZERO L3642                   %-> 3642
3640          JMP L5017                         %-> 5017
3641  L3641,  ARM BMINA D,SH B,SH A,SS
3642  L3642,  ARM BDI ADD1 D,SS B,B3
3643          LOGM OR D,SS B,B1 A,SS
3644          JMP L3654                         %-> 3654
3645  L3645,  ARM BDI ADD1 D,SS B,B6
3646          ARM BMINA B,SH A,SS
3647          CJMP NEG L5017                    %-> 5017
3650          ARM BM1 D,SS B,B4
3651          LOGM AND D,SH B,SH A,SS
3652  L3652,  LOGM BDIR D,SS B,B3
3653          LOGM OR D,SS B,B1 A,SS
3654  L3654,  LOGM BDIR B,B14
3655          ILOGM AND LE17 B,AC A,SS
3656          CJMP NZERO L3664                  %-> 3664
3657          LOGM BDIR D,D B,B2
3660          LOGM BDIR D,SC B,B2
3661          LOOP BM1 BM1A SHZE TSC0
3662          LOGM OR D,SS B,SH A,SS
3663          JMP L3760                         %-> 3760
3664  L3664,  LOGM ADIR D,D
3665          ILOGM BDIR DSPL LE12 D,SS B,SH
3666          ARM BMAM1 B,A A,B
3667          CJMP NZERO L3760                  %-> 3760
3670          LOGM BDIR B,B17
3671          ILOGM AND LE17 B,AC A,SS
3672          CJMP ZERO L3676                   %-> 3676
3673          ILOGM OR LE15 B,SH A,SS
3674          ILOGM OR LE11 D,SP B,AC A,SS
3675          JMP L3760                         %-> 3760
3676  L3676,  LOGM BDIR D,SC B,B3
3677          LOOP BM1 BM1A SHZE TSC0
3700          LOGM OR D,SP B,SH A,SP
3701          JMP L3760                         %-> 3760
3702  L3702,  LOGM ADIR D,T A,SP
3703          ARM BM1 D,SH B,B10
3704          LOGM AND B,B0 A,SS
3705          CJMP ZERO L3724                   %-> 3724
3706          LOGM BDIR D,SCR B,B4
3707  L3707,  LOGM ANDCB D,T B,SH A,T
3710          LOGM BDIR D,SS B,B10
3711          LOGM OR D,SS B,B13 A,SS
3712          LOGM OR D,SS B,B15 A,SS
3713          LOGM OR B,B11 A,SS
3714          ARM BMINA B,AC A,T
3715          CJMP ZERO L3743                   %-> 3743
3716          ARM BMINA B,B15 A,T
3717          CJMP ZERO L3743                   %-> 3743
3720          LOGM OR B,B12 A,SS
3721          ARM BMINA B,AC A,T
3722          CJMP ZERO L3740                   %-> 3740
3723          JMP L5017                         %-> 5017
3724  L3724,  LOGM BDIR D,SCR B,B3
3725  L3725,  LOGM AND D,T B,SH A,T
3726          ARM BM1 D,SS B,B6
3727          LOGM ANDCB D,SS B,B4 A,SS
3730          LOGM ANDCB D,SS B,B2 A,SS
3731          ARM BMINA B,AC A,T
3732          CJMP ZERO L3743                   %-> 3743
3733          ARM BMINA B,B5 A,T
3734          CJMP ZERO L3743                   %-> 3743
3735          ARM PLUS B,B1 A,SS
3736          ARM BMINA B,AC A,T
3737          CJMP NZERO L5017                  %-> 5017
3740  L3740,  ARM BDI ADD1 D,SS B,B3
3741          LOGM OR D,SS B,B1 A,SS
3742          JMP L3757                         %-> 3757
3743  L3743,  ARM BDI D,SS B,B3
3744          LOGM OR D,SS B,B1 A,SS
3745          JMP L3757                         %-> 3757
3746  L3746,  LOGM BDIR D,SCR B,B3
3747          LOGM AND B,B0 A,SS
3750          CLOGM ADIR ZERO D,SCR
3751          ILOGM ADIR DSPL LE12 D,SS
3752          ILOGM ADIR LE12 D,T A,SCR
3753          ARM BM1 D,SH B,B10
3754          LOGM AND B,B17 A,D
3755          CJMP NZERO L3725                  %-> 3725
3756          JMP L3707                         %-> 3707
3757  L3757,  LOGM ADIR D,D
3760  L3760,  LOGM BDIR B,B1
3761          ILOGM AND LE13 B,AC A,SS
3762          CJMP NZERO L3765                  %-> 3765
3763          ARM PLUS D,D B,B2 A,D
3764          JMP L3776                         %-> 3776
3765  L3765,  ARM PLUS D,D B,B3 A,D
3766          ARM PLUS D,D B,B2 A,D
3767          LOGM BDIR D,SC B,B3
3770          LOGM ADIR D,SH A,SS
3771          LOOP BM1 BM1A SHZE TSC0
3772          LOGM BDIR D,SS B,SH
3773          ARM BM1 B,B10
3774          ILOGM AND LE14 B,AC A,SCR
3775          LOGM OR D,SS B,AC A,SS
3776  L3776,  ARM BM1 D,T B,B4
3777          JMP L4001                         %-> 4001
4000  L4000,  JMP L0000                         %-> 0000
4001  L4001,  ILOGM ADIR LE13 A,SS
4002          CLOGM ANDCB ZERO D,SS B,T A,SS
4003          JMP L4005                         %-> 4005
4004          LOGM ADIR D,SS
4005  L4005,  ARM BMAM1 B,B4 A,D
4006          CJMP NEG L4131                    %-> 4131
4007  L4007,  ARM BMINA B,B3 A,SCR
4010          CJMP NEG L4043                    %-> 4043
4011  L4011,  ARM BM1 D,T B,B10
4012          LOGM ADIR A,SCR
4013          CJMP ZERO L4034                   %-> 4034
4014          LOGM ANDCB D,SH B,T A,SP
4015          IARM BMINA LE11 B,SH A,SS
4016          CJMP NEG L5013                    %-> 5013
4017          IARM BMINA LE11 B,SH A,SCR
4020          CJMP POS L5013                    %-> 5013
4021          ILOGM ADIR LE13 D,T A,SCR
4022  L4022,  LOGM AND D,SH B,T A,SP
4023          ARM BMINA D,SC B,D A,SCR
4024          CJMP NEG L4027                    %-> 4027
4025          LOOP BM1 BM1A SHZE TSC0
4026          JMP L4030                         %-> 4030
4027  L4027,  LOOP BM1 BM1A SHR SHZE TSC0
4030  L4030,  LOGM OR D,SS B,SH A,SS
4031          ARM PLUS D,D B,B2 A,D
4032          ARM PLUS D,SCR B,B3 A,SCR
4033          JMP L4005                         %-> 4005
4034  L4034,  LOGM AND D,SH B,T A,SP
4035          IARM BMINA LE15 B,SH A,SS
4036          CJMP NEG L5013                    %-> 5013
4037          IARM BMINA LE14 B,SH A,SS
4040          CJMP POS L5013                    %-> 5013
4041          ARM BM1 D,T B,B4
4042          JMP L4022                         %-> 4022
4043  L4043,  ILOGM ADIR LE10 D,P A,SS
4044          ARM BM1 D,IO B,CAR A,P
4045          LOGM ADIR A,A
4046          CJMP NZERO L4051                  %-> 4051
4047          ARM BDI ADD1 B,B
4050          CJMP ZERO L4116                   %-> 4116
4051  L4051,  ARM BMAM1 B,B A,A
4052          CJMP NEGM L4061                   %-> 4061
4053          ARM BM1 CPTR D,P B,B
4054          ARM BM1 CRR1 D,B B,B
4055          LOGM ANDCB D,P B,B7 A,H
4056          LOGM ANDCB D,SP B,B17 A,P
4057  L4057,  LOGM ADIR D,SCR
4060          JMP L4011                         %-> 4011
4061  L4061,  ARM BMINA B,B A,A
4062          CJMP NZERO L4116                  %-> 4116
4063          ILOGM ADIR LE12 D,SP A,SCR
4064          ARM BM1 D,B B,B
4065          LOGM BDIR B,B14
4066          ILOGM AND LE17 B,AC A,SS
4067          CJMP NZERO L4077                  %-> 4077
4070          LOGM BDIR B,B17
4071          ILOGM AND LE17 B,AC A,SS
4072          CJMP ZERO L4057                   %-> 4057
4073          ARM BM1 B,B10
4074          LOGM AND B,AC A,SP
4075          ILOGM OR LE11 D,SP B,AC A,SS
4076          JMP L4057                         %-> 4057
4077  L4077,  LOGM BDIR B,B17
4100          ILOGM AND LE17 B,AC A,SS
4101          CJMP ZERO L4106                   %-> 4106
4102          ILOGM ADIR LE12 A,SS
4103          ILOGM OR LE15 B,AC A,SS
4104          ILOGM OR LE11 D,SP B,AC A,SS
4105          JMP L4057                         %-> 4057
4106  L4106,  ILOGM ADIR LE12 D,SH A,SS
4107          LOGM BDIR D,SC B,B3
4110          LOOP BM1 BM1A SHZE TSC0
4111          ARM BM1 B,B10
4112          LOGM AND D,SP B,AC A,SP
4113          LOGM OR B,SH A,SP
4114          ILOGM OR LE11 D,SP B,AC A,SS
4115          JMP L4057                         %-> 4057
4116  L4116,  LOGM ADIR A,X
4117          CJMP NZERO L4122                  %-> 4122
4120          ARM BDI ADD1 B,L
4121          CJMP ZERO L4124                   %-> 4124
4122  L4122,  ARM BMINA B,L A,X
4123          CJMP POSM L4127                   %-> 4127
4124  L4124,  LOGM ADIR A,SS
4125          CJMP NZERO L5004                  %-> 5004
4126          JMP L5062                         %-> 5062
4127  L4127,  LOGM BDIR D,D B,B5
4130          JMP L4005                         %-> 4005
4131  L4131,  ILOGM ADIR LE10 D,P A,SCR
4132          ARM BM1 D,IO B,CAR A,P
4133          ARM BM1 CPTR D,P B,L
4134          LOGM ADIR A,X
4135          CJMP NZERO L4140                  %-> 4140
4136          ARM BDI ADD1 B,L
4137          CJMP ZERO L4164                   %-> 4164
4140  L4140,  ARM BMAM1 B,L A,X
4141          CJMP NEGM L4146                   %-> 4146
4142  L4142,  ARM BM1 CWR1 D,L B,L A,SS
4143  L4143,  LOGM ADIR D,D
4144          LOGM ADIR D,SS
4145          JMP L4007                         %-> 4007
4146  L4146,  ARM BMINA B,L A,X
4147          CJMP NZERO L4164                  %-> 4164
4150          ILOGM ADIR LE15 D,T A,SCR
4151          LOGM AND B,B17 A,T
4152          CJMP ZERO L4142                   %-> 4142
4153          ARM BM1 CRR1 D,SH B,B10
4154          LOGM ANDCB D,T B,SH A,H
4155          LOGM AND B,SH A,SS
4156          LOGM OR D,T B,AC A,T
4157          ARM BM1 CPTR D,P B,L
4160          ARM BM1 CWR1 D,L B,L A,T
4161          LOGM ANDCB B,SH A,SS
4162          CJMP NZERO L5004                  %-> 5004
4163          JMP L4143                         %-> 4143
4164  L4164,  LOGM ADIR A,SS
4165          CJMP ZERO L4143                   %-> 4143
4166          JMP L5004                         %-> 5004
4167  L4167,  ARM BM1 B,MPC A,IO
4170          JMP L5040                         %-> 5040
4171          ARM BM1 B,B5
4172          LOGM AND B,AC A,T
4173          CJMP NZERO L4177                  %-> 4177
4174          IARM BM1 DSPL LE13 D,SCR B,X
4175          ILOGM ADIR DSPL LE13 D,SS
4176          JMP L4215                         %-> 4215
4177  L4177,  ILOGM ADIR LE10 D,P A,SCR
4200          ARM BM1 D,IO B,CAR A,P
4201          ARM BM1 CPTR D,P B,X
4202          ILOGM ADIR CRR1 LE17 D,P A,SCR
4203          ILOGM ADIR DSPL LE11 D,SCR A,H
4204          LOGM ADIR D,SCR A,X
4205          LOGM ADIR D,SS A,T
4206          ARM BM1 B,MPC A,IO
4207          JMP L4711                         %-> 4711
4210          ILOGM BDIR DSPL LE13 D,SCR B,SH
4211          ILOGM ADIR DSPL LE13 D,SS A,SS
4212          ARM BM1 CPTR D,P B,SH
4213          ILOGM ADIR CRR1 LE17 D,P A,SCR
4214          ILOGM ADIR DSPL LE14 D,SCR A,H
4215  L4215,  ARM BM1 B,B5
4216          LOGM AND B,AC A,D
4217          CJMP NZERO L4226                  %-> 4226
4220          ARM BM1 D,B B,A
4221          LOGM BDIR D,SP B,B3
4222          LOGM OR D,SP B,B1 A,SP
4223          LOGM ANDCB D,SS B,B1 A,SS
4224          ILOGM ADIR LE13 D,L A,SCR
4225          JMP L4257                         %-> 4257
4226  L4226,  ILOGM ADIR LE10 D,P A,SS
4227          ARM BM1 D,IO B,CAR A,P
4230          ARM BM1 CPTR D,P B,A
4231          ILOGM ADIR CRR1 LE17 D,P A,SCR
4232          ILOGM ADIR DSPL LE11 D,SS A,H
4233          LOGM ADIR D,SCR A,A
4234          LOGM ADIR D,SS A,D
4235          ARM BM1 B,MPC A,IO
4236          JMP L4725                         %-> 4725
4237          ARM BMINA B,SH A,A
4240          CJMP NZERO L4247                  %-> 4247
4241          ILOGM ADIR LE11 D,SP A,SS
4242          LOGM AND B,B17 A,D
4243          CJMP ZERO L4252                   %-> 4252
4244          ARM BM1 B,B10
4245          LOGM AND D,SP B,AC A,SP
4246          JMP L4252                         %-> 4252
4247  L4247,  ARM BM1 CPTR D,P B,SH
4250          ILOGM ADIR CRR1 LE17 D,P A,SCR
4251          LOGM ADIR D,SP A,H
4252  L4252,  ARM BM1 D,B B,SH
4253          ILOGM ADIR LE13 D,L A,SCR
4254          LOGM ADIRC D,SCR
4255          ARM BM1 B,MPC A,IO
4256          JMP L4744                         %-> 4744
4257  L4257,  LOGM BDIR D,SCR B,B4
4260          LOGM OR D,SCR B,B5 A,SCR
4261          LOGM OR D,SCR B,B14 A,SCR
4262          LOGM OR D,SCR B,B15 A,SCR
4263          ILOGM ADIR DSPL LE12 D,SCR A,SCR
4264          ARM BM1 D,SCR B,B14
4265          ARM BM1 B,B10
4266          ILOGM ANDCB DSPL LE13 D,SCR B,AC A,SCR
4267          LOGM BDIR D,SCR B,B1
4270          LOGM OR D,SCR B,B3 A,SCR
4271          ILOGM ADIR DSPL LE15 D,SS A,SCR
4272          LOGM BDIR D,SCR B,B11
4273          LOGM OR D,SCR B,B13 A,SCR
4274          ILOGM ADIR DSPL LE14 D,SS A,SCR
4275          LOGM ADIR D,P A,SP
4276          LOGM AND B,B1 A,SS
4277          CJMP ZERO L4305                   %-> 4305
4300          LOGM BDIR D,SCR B,B3
4301          ILOGM AND LE13 B,P A,SCR
4302          IARM BMINA LE14 B,AC A,SS
4303          CJMP POS L4313                    %-> 4313
4304          JMP L5013                         %-> 5013
4305  L4305,  LOGM BDIR D,SCR B,B2
4306          ARM BM1 B,B4
4307          LOGM AND B,AC A,SP
4310          IARM BMINA LE15 B,AC A,SS
4311          CJMP POS L4313                    %-> 4313
4312          JMP L5013                         %-> 5013
4313  L4313,  ILOGM ADIR LE13 A,SS
4314          CJMP ZERO L4410                   %-> 4410
4315          LOGM AND B,B15 A,T
4316          CJMP NZERO L4410                  %-> 4410
4317          LOGM AND B,B14 A,T
4320          CJMP NZERO L4416                  %-> 4416
4321          LOGM AND B,B13 A,T
4322          CJMP NZERO L4350                  %-> 4350
4323          LOGM AND B,B1 A,SS
4324          CJMP NZERO L4337                  %-> 4337
4325          LOGM BDIR D,D B,B3
4326          ARM BM1 D,SC B,B2
4327          ARM BM1 B,B4
4330          LOGM AND D,SCR B,AC A,SP
4331          LOGM ADIR A,SP
4332  L4332,  LOOP BDI BDIA B,HAC TSC0
4333          LOGM BDIR D,SS B,HAC
4334          ARM BM1 B,MPC A,IO
4335          JMP L4657                         %-> 4657
4336          JMP L4372                         %-> 4372
4337  L4337,  LOGM BDIR D,D B,B4
4340          LOGM ADIR D,SH A,SP
4341          LOGM BDIR D,SC B,B3
4342          LOOP BM1 BM1A SHR SHZE TSC0
4343          ARM BM1 D,SCR B,B4
4344          LOGM AND D,SCR B,SH A,SCR
4345          ARM BM1 D,SC B,B2
4346          LOGM BDIR B,SH
4347          JMP L4332                         %-> 4332
4350  L4350,  ARM BDI ADD1 D,SCR B,B5
4351          LOGM OR D,SCR B,B3 A,SCR
4352          LOGM AND B,B1 A,SS
4353          CJMP NZERO L4363                  %-> 4363
4354          LOGM AND B,B0 A,SP
4355          CJMP ZERO L4360                   %-> 4360
4356          LOGM OR D,SS B,B2 A,SCR
4357          JMP L4361                         %-> 4361
4360  L4360,  LOGM OR D,SS B,B1 A,SCR
4361  L4361,  LOGM BDIR D,D B,B2
4362          JMP L4372                         %-> 4372
4363  L4363,  LOGM AND B,B10 A,SP
4364          CJMP ZERO L4367                   %-> 4367
4365          LOGM OR D,SS B,B2 A,SCR
4366          JMP L4370                         %-> 4370
4367  L4367,  LOGM OR D,SS B,B1 A,SCR
4370  L4370,  LOGM BDIR D,D B,B3
4371          LOGM OR D,D B,B2 A,D
4372  L4372,  ILOGM ADIR LE13 D,T A,SS
4373          LOGM AND B,B0 A,T
4374          CJMP NZERO L4401                  %-> 4401
4375  L4375,  LOGM OR D,SS B,B15 A,SS
4376          LOGM OR D,SS B,B14 A,SS
4377          LOGM BDIR D,SCR B,B3
4400          JMP L4445                         %-> 4445
4401  L4401,  ARM BM1 B,B10
4402          ILOGM AND LE14 D,SCR B,AC A,SCR
4403          LOGM BDIR D,SC B,B3
4404          LOGM ADIR D,SH A,SS
4405          LOOP BM1 BM1A SHZE TSC0
4406          LOGM OR D,SS B,SH A,SCR
4407          JMP L4541                         %-> 4541
4410  L4410,  LOGM BDIR D,D B,B2
4411          LOGM AND B,B1 A,SS
4412          CJMP NZERO L4414                  %-> 4414
4413          JMP L4434                         %-> 4434
4414  L4414,  LOGM OR D,D B,B3 A,D
4415          JMP L4434                         %-> 4434
4416  L4416,  LOGM AND B,B1 A,SS
4417          CJMP NZERO L4424                  %-> 4424
4420          ARM BM1 B,B4
4421          LOGM AND D,SS B,AC A,SP
4422          LOGM BDIR D,D B,B2
4423          JMP L4433                         %-> 4433
4424  L4424,  ARM BM1 D,SCR B,B4
4425          ARM BM1 D,SC B,B3
4426          LOGM ADIR A,SP
4427          LOOP BDI BDIA B,HAC TSC0
4430          LOGM AND D,SS B,HAC A,SCR
4431          LOGM BDIR D,D B,B3
4432          LOGM OR D,D B,B2 A,D
4433  L4433,  ILOGM ADIR DSPL LE12 D,SS A,SS
4434  L4434,  ILOGM ADIR LE13 D,T A,SS
4435          LOGM AND B,B0 A,T
4436          CJMP NZERO L4441                  %-> 4441
4437          LOGM ADIR D,SCR
4440          JMP L4444                         %-> 4444
4441  L4441,  ARM BM1 B,B10
4442          ILOGM AND LE14 D,SS B,AC A,SCR
4443          JMP L4375                         %-> 4375
4444  L4444,  ILOGM ADIR LE12 D,SS A,SCR
4445  L4445,  ARM BMINA B,B3 A,SCR
4446          CJMP NEG L4541                    %-> 4541
4447  L4447,  ARM BMAM1 B,B4 A,D
4450          CJMP NEG L4475                    %-> 4475
4451  L4451,  LOGM ADIR D,SH A,SP
4452          ARM BMINA D,SC B,D A,SCR
4453          CJMP POS L4456                    %-> 4456
4454          LOOP BM1 BM1A SHZE TSC0
4455          JMP L4457                         %-> 4457
4456  L4456,  LOOP BM1 BM1A SHR SHZE TSC0
4457  L4457,  LOGM ADIR A,SCR
4460          CJMP ZERO L4470                   %-> 4470
4461          ILOGM AND LE13 D,SH B,SH A,SCR
4462          IARM BMINA LE14 B,SH A,SS
4463          CJMP POS L5012                    %-> 5012
4464  L4464,  LOGM OR D,SS B,SH A,SS
4465          ARM PLUS D,D B,B2 A,D
4466          ARM PLUS D,SCR B,B3 A,SCR
4467          JMP L4445                         %-> 4445
4470  L4470,  ARM BM1 D,T B,B4
4471          LOGM AND D,SH B,SH A,T
4472          IARM BMINA LE15 B,SH A,SS
4473          CJMP POS L5012                    %-> 5012
4474          JMP L4464                         %-> 4464
4475  L4475,  LOGM ADIR A,A
4476          CJMP NZERO L4501                  %-> 4501
4477          ARM BDI ADD1 B,B
4500          CJMP ZERO L4524                   %-> 4524
4501  L4501,  ARM BMAM1 B,B A,A
4502          CJMP NEGM L4512                   %-> 4512
4503          ILOGM ADIR LE10 D,P A,SS
4504          ARM BM1 D,IO B,CAR A,P
4505          ARM BM1 CPTR D,P B,B
4506          ARM BM1 CRR1 D,B B,B
4507          LOGM ADIR D,SP A,H
4510  L4510,  LOGM ADIR D,D
4511          JMP L4451                         %-> 4451
4512  L4512,  ARM BMINA B,B A,A
4513          CJMP NZERO L4524                  %-> 4524
4514          ARM BM1 D,B B,B
4515          ILOGM ADIR LE11 D,SP A,SS
4516          ILOGM ADIR LE17 D,T A,SS
4517          LOGM AND B,B17 A,T
4520          CJMP ZERO L4510                   %-> 4510
4521          ARM BM1 B,B10
4522          LOGM AND D,SP B,AC A,SP
4523          JMP L4510                         %-> 4510
4524  L4524,  LOGM ADIR A,X
4525          CJMP NZERO L4530                  %-> 4530
4526          ARM BDI ADD1 B,L
4527          CJMP ZERO L4532                   %-> 4532
4530  L4530,  ARM BMINA B,L A,X
4531          CJMP POSM L4536                   %-> 4536
4532  L4532,  LOGM ADIR A,SS
4533          ILOGM EXOR LE12 B,AC A,SCR
4534          CJMP NZERO L5004                  %-> 5004
4535          JMP L5062                         %-> 5062
4536  L4536,  LOGM BDIR D,SCR B,B4
4537          LOGM ADIR D,SH
4540          JMP L4445                         %-> 4445
4541  L4541,  ILOGM ADIR LE10 D,P A,SCR
4542          ARM BM1 D,IO B,CAR A,P
4543          ARM BM1 CPTR D,P B,L
4544          LOGM ADIR A,X
4545          CJMP NZERO L4550                  %-> 4550
4546          ARM BDI ADD1 B,L
4547          CJMP ZERO L4575                   %-> 4575
4550  L4550,  ARM BMAM1 B,L A,X
4551          CJMP NEGM L4556                   %-> 4556
4552  L4552,  ARM BM1 CWR1 D,L B,L A,SS
4553  L4553,  LOGM ADIR D,SCR
4554          ILOGM ADIR LE12 D,SS A,SCR
4555          JMP L4447                         %-> 4447
4556  L4556,  ARM BMINA B,L A,X
4557          CJMP NZERO L4575                  %-> 4575
4560          ILOGM ADIR LE15 D,T A,SCR
4561          LOGM AND B,B14 A,T
4562          CJMP NZERO L4602                  %-> 4602
4563          LOGM AND B,B17 A,T
4564          CJMP NZERO L4566                  %-> 4566
4565          JMP L4552                         %-> 4552
4566  L4566,  ARM BM1 D,T B,B10
4567          ILOGM ANDCB LE11 D,SCR B,AC A,SCR
4570          LOGM AND B,T A,SS
4571          LOGM OR D,SS B,AC A,SCR
4572  L4572,  ARM BM1 CPTR D,P B,L
4573          ARM BM1 CWR1 D,L B,L A,SS
4574          JMP L4577                         %-> 4577
4575  L4575,  LOGM ADIR A,SS
4576          ILOGM EXOR LE12 D,SH B,AC A,SCR
4577  L4577,  LOGM BDIR B,SH
4600          CJMP ZERO L4553                   %-> 4553
4601          JMP L5004                         %-> 5004
4602  L4602,  ILOGM ADIR LE12 D,SCR A,SS
4603          LOGM AND B,B13 A,T
4604          CJMP NZERO L4630                  %-> 4630
4605          LOGM AND B,B17 A,T
4606          CJMP ZERO L4612                   %-> 4612
4607          ARM BM1 B,MPC A,IO
4610          JMP L4657                         %-> 4657
4611          JMP L4566                         %-> 4566
4612  L4612,  LOGM BDIR D,SC B,B3
4613          LOOP BM1 BM1A SHR SHZE TSC0
4614          ILOGM ADIR DSPL LE12 D,SS A,SS
4615          LOGM BDIR D,SS B,SH
4616          ARM BM1 B,MPC A,IO
4617          JMP L4657                         %-> 4657
4620          ILOGM ADIR LE12 D,SCR A,SS
4621          ARM BM1 B,B10
4622          LOGM AND D,SCR B,AC A,SCR
4623          LOGM BDIR D,SC B,B3
4624          LOGM ADIR D,SH A,SS
4625          LOOP BM1 BM1A SHZE TSC0
4626          LOGM OR D,SS B,SH A,SCR
4627          JMP L4552                         %-> 4552
4630  L4630,  ILOGM ADIR DSPL LE12 D,SS A,SS
4631          ARM BDI ADD1 D,SS B,B5
4632          LOGM OR D,SS B,B3 A,SS
4633          LOGM AND B,B0 A,SCR
4634          CJMP ZERO L4637                   %-> 4637
4635          LOGM OR D,SS B,B2 A,SS
4636          JMP L4640                         %-> 4640
4637  L4637,  LOGM OR D,SS B,B1 A,SS
4640  L4640,  LOGM AND B,B17 A,T
4641          CJMP ZERO L4645                   %-> 4645
4642          ILOGM ADIR LE12 A,SS
4643          ILOGM EXOR LE12 D,SH B,AC A,SCR
4644          JMP L4566                         %-> 4566
4645  L4645,  ARM BM1 D,SCR B,B10
4646          ILOGM ADIR LE12 A,SS
4647          LOGM AND D,SCR B,AC A,SCR
4650          ILOGM BDIR DSPL LE12 D,SS B,SH
4651          LOGM BDIR D,SC B,B3
4652          LOGM ADIR D,SH A,SS
4653          LOOP BM1 BM1A SHZE TSC0
4654          LOGM OR D,SS B,SH A,SCR
4655          ILOGM ADIR LE12 D,SH A,SS
4656          JMP L4572                         %-> 4572
4657  L4657,  ARM PLUS D,T B,B0 A,H
4660          ARM BM1 D,IO B,CAR A,T
4661          ARM BM1 B,B4
4662          LOGM AND D,SS B,AC A,SS
4663          IARM BMINA LE15 B,AC A,SS
4664          CJMP POS L4707                    %-> 4707
4665          LOGM AND B,B0 A,SCR
4666          CJMP ZERO L4700                   %-> 4700
4667          LOGM ADIR A,SS
4670          CJMP ZERO L4675                   %-> 4675
4671          ARM BDI ADD1 D,SCR B,B3
4672          LOGL OR D,SH B,B6 A,SCR
4673          ARL PLUS D,SS B,SH A,SS
4674          JMP ,CAR
4675  L4675,  ARM BM1 D,SS B,B7
4676          LOGM ANDCB D,SS B,B1 A,SS
4677          JMP ,CAR
4700  L4700,  LOGM ADIR A,SS
4701          CJMP ZERO L4704                   %-> 4704
4702          ARM PLUS D,SS B,B6 A,SS
4703          JMP ,CAR
4704  L4704,  ARM BM1 D,SS B,B7
4705          LOGM ANDCB D,SS B,B2 A,SS
4706          JMP ,CAR
4707  L4707,  LOGM ADIR D,SCR A,D
4710          JMP L5017                         %-> 5017
4711  L4711,  ARM BM1 B,B5
4712          LOGM AND D,SP B,AC A,SS
4713          LOGM AND B,B17 A,SS
4714          CARM PLUS ADD1 NZERO D,SP A,SP
4715          LOGM ADIR D,SS A,SP
4716          LOGM BDIR D,SH B,HAC
4717          ARM PLUS D,SH B,SH A,SCR
4720          LOGM AND B,B0 A,SS
4721          CARM BM1 ZERO D,SH B,SH
4722          ARM PLUS D,SP B,B0 A,H
4723          ARM BM1 D,IO B,CAR A,SP
4724          JMP ,CAR
4725  L4725,  LOGL BDIR D,SH B,B1
4726          ARM BM1 B,B5
4727          LOGM AND D,SP B,AC A,SS
4730          LOGM AND B,B0 A,SS
4731          CARM PLUS ADD1 NZERO D,SP A,SP
4732          LOGM AND B,B17 A,SS
4733          CARL PLUS NZERO D,SP B,SH A,SP
4734          LOGM ADIR D,SS A,SP
4735          LOGM BDIR B,HAC
4736          ARM PLUS D,SH B,HAC A,SCR
4737          LOGM AND B,B1 A,SS
4740          CARM BM1 ZERO D,SH B,SH
4741          ARM PLUS D,SP B,B0 A,H
4742          ARM BM1 D,IO B,CAR A,SP
4743          JMP ,CAR
4744  L4744,  ARM PLUS D,P B,B0 A,H
4745          ARM BM1 D,IO B,CAR A,P
4746          ILOGM ADIR LE13 A,SS
4747          CJMP ,CAR ZERO
4750          LOGM EXOR D,P B,D A,T
4751          LOGM AND B,B16 A,P
4752          CJMP ,CAR NZERO
4753          ARM BMINA B,L A,A
4754          CJMP ,CAR NEGM
4755          LOGM ADIR A,SCR
4756          CJMP NZERO L4775                  %-> 4775
4757          ARM BMAM1 B,SH A,L
4760          CJMP ,CAR NEGM
4761  L4761,  ARM BMINA B,L A,A
4762          CJMP ZERO L4767                   %-> 4767
4763  L4763,  ARM BM1 B,B5
4764          LOGM ANDCB D,D B,AC A,D
4765          LOGM OR D,D B,B0 A,D
4766          JMP L5034                         %-> 5034
4767  L4767,  LOGM AND B,B17 A,D
4770          CJMP ZERO L4763                   %-> 4763
4771          LOGM BDIR B,B1
4772          ILOGM AND LE13 B,AC A,SS
4773          CJMP ZERO L4763                   %-> 4763
4774          JMP ,CAR
4775  L4775,  LOGM BDIR D,SCR B,SH
4776          ARM BMINA D,SCR B,L A,SCR
4777          CJMP NEGM L4761                   %-> 4761
5000          ARM BMINA B,SH A,A
5001          ARM BMAM1 B,AC A,SCR
5002          CJMP ,CAR NEGM
5003          JMP L4761                         %-> 4761
5004  L5004,  ILOGM ADIR LE17 D,P A,SCR
5005          ARM BM1 B,B5
5006          ILOGM ANDCB LE17 D,D B,AC A,SS
5007          LOGM OR D,D B,B0 A,D
5010          LOGM OR D,D B,B1 A,D
5011          JMP L5065                         %-> 5065
5012  L5012,  LOGM ADIR D,SCR A,D
5013  L5013,  ARM BM1 B,B5
5014          ILOGM ANDCB LE17 D,D B,AC A,SS
5015          LOGM OR D,D B,B1 A,D
5016          JMP L5026                         %-> 5026
5017  L5017,  ARM BMINA D,SCR B,B2 A,SCR
5020          ARM BMINA D,SCR A,SCR
5021          ARM BM1 B,B5
5022          ILOGM ANDCB LE17 D,D B,AC A,SS
5023          LOGM OR D,D B,B1 A,D
5024          LOGM AND B,B14 A,D
5025          CJMP NZERO L5034                  %-> 5034
5026  L5026,  ARM BDI ADD1 D,A B,B
5027          ARM BMINA B,B2 A,SCR
5030          CJMP POS L5033                    %-> 5033
5031          LOGM ANDCB D,D B,B17 A,D
5032          JMP L5034                         %-> 5034
5033  L5033,  LOGM OR D,D B,B17 A,D
5034  L5034,  ILOGM ADIR LE17 D,P A,SCR
5035          JMP L5065                         %-> 5065
5036  L5036,  ILOGM ADIR DSPL LE15 D,SS A,A
5037          ILOGM ADIR DSPL LE14 D,SS A,X
5040  L5040,  ILOGM ADIR DSPL LE17 D,SS A,D
5041          ILOGM ADIR DSPL LE17 D,SCR A,P
5042          ILOGM ADIR DSPL LE16 D,SS A,B
5043          ILOGM ADIR DSPL LE16 D,SCR A,L
5044          ILOGM ADIR DSPL LE15 D,SCR A,T
5045          LOGM ADIR D,SCR
5046          LOGM AND B,B16 A,D
5047          CLOGM ADIRC NZERO D,SCR
5050          ILOGM ADIR DSPL LE10 D,SS A,SCR
5051          LOGM ADIR D,SCR
5052          LOGM AND B,B16 A,T
5053          CLOGM ADIRC NZERO D,SCR
5054          ILOGM ADIR DSPL LE10 D,SCR A,SCR
5055          ARM PLUS D,SCR B,B0 A,H
5056          ARM BM1 D,IO B,CAR A,SCR
5057          JMP ,CAR
5060  L5060,  ILOGM ADIR LE15 D,A A,SS
5061          ILOGM ADIR LE14 D,X A,SS
5062  L5062,  ILOGM ADIR LE17 D,D A,SS
5063          ILOGM ADIR LE17 A,SCR
5064          ARM BDI ADD1 D,P B,AC
5065  L5065,  ILOGM ADIR LE16 D,B A,SS
5066          ILOGM ADIR LE16 D,L A,SCR
5067          ILOGM ADIR CFC LE15 D,T A,SCR
5070  L5070,  ILOGM ADIR DSPL LE14 D,SCR
5071          JMP L5076                         %-> 5076
5072  L5072,  ARM BM1 B,B6
5073          LOGM AND B,AC A,T
5074          CJMP ZERO L5070                   %-> 5070
5075          ILOGM ADIRC DSPL LE14 D,SCR
5076  L5076,  ARM BM1 B,B5
5077          ILOGM AND DSPL LE12 D,SCR B,AC A,D
5100          CJMP ZERO L2177                   %-> 2177
5101          ARM BM1 B,MPC A,IO
5102          JMP L5036                         %-> 5036
5103          ILOGM ADIR LE10 D,P A,SS
5104          ARM BM1 D,IO B,CAR A,P
5105          ARM BM1 CPTR D,P B,A
5106          ILOGM ADIR CRR1 LE17 D,P A,SCR
5107          ARM BM1 D,SH B,B10
5110          LOGM AND B,B17 A,D
5111          CLOGM ADIRC ZERO D,SH
5112          ILOGM AND DSPL LE12 D,SS B,SH A,H
5113          LOGM ADIR D,SCR A,A
5114          LOGM ADIR D,SS A,D
5115          ARM BM1 B,MPC A,IO
5116          JMP L4725                         %-> 4725
5117          ILOGM ADIR DSPL LE13 D,SCR A,SS
5120          ARM BM1 CPTR D,P B,SH
5121          ILOGM ADIR CRR1 LE17 D,P A,SCR
5122          ILOGM ADIR DSPL LE13 D,SS A,H
5123          LOGM AND B,B17 A,T
5124          ILOGM OR LE12 D,SS B,AC A,SCR
5125          LOGM ADIR D,SCR A,X
5126          ARM BM1 B,MPC A,IO
5127          JMP L4725                         %-> 4725
5130          ILOGM ADIR LE10 D,P A,SCR
5131          ARM BM1 D,IO B,CAR A,P
5132          ARM BM1 CPTR D,P B,X
5133          ILOGM ADIR CRR1 LE17 D,P A,SCR
5134          ARM BM1 CPTR D,P B,SH
5135          ARM BM1 D,SH B,B10
5136          LOGM AND B,B17 A,T
5137          CLOGM ADIRC ZERO D,SH
5140          ILOGM ANDCB DSPL LE11 D,SS B,SH A,H
5141          ILOGM ADIR CRR1 LE17 D,P A,SCR
5142          LOGM ADIR D,L A,R
5143          ILOGM ADIR LE13 D,SCR A,SCR
5144          LOGM AND B,B1 A,SCR
5145          CJMP NZERO L5172                  %-> 5172
5146          ARM BM1 D,SH B,B4
5147          ILOGM ANDCB LE13 D,SCR B,AC A,SS
5150          ILOGM AND LE13 D,SH B,SH A,SS
5151          LOGM ADIR D,B
5152          LOGM AND B,B1 A,SS
5153          CJMP NZERO L5164                  %-> 5164
5154          LOGM BDIR D,T B,B3
5155          ILOGM ADIR DSPL LE12 D,SCR
5156  L5156,  ILOGM BDIR DSPL LE13 D,SCR B,SH
5157          ILOGM ADIR DSPL LE13 D,SS A,SCR
5160          LOGM BDIR B,B5
5161          ILOGM AND LE15 B,AC A,SCR
5162          CJMP NZERO L5432                  %-> 5432
5163          JMP L5207                         %-> 5207
5164  L5164,  ARM BM1 B,B10
5165          ILOGM AND DSPL LE12 D,SCR B,AC A,H
5166          LOGM ADIR D,T
5167  L5167,  LOGM BDIR D,SC B,B3
5170          LOOP BM1 BM1A SHRO TSC0
5171          JMP L5156                         %-> 5156
5172  L5172,  ILOGM ADIR DSPL LE12 D,SCR
5173          ARL BM1 D,SH B,B10
5174          ILOGL ANDCB LE13 D,SCR B,AC A,SS
5175          ARM BM1 D,B B,B14
5176          LOGM AND D,SH B,AC A,SCR
5177          LOGM ANDCB D,SCR B,B A,SCR
5200          LOGM BDIR D,B B,B1
5201          LOGM BDIR D,T B,B3
5202          LOGM AND B,B1 A,SS
5203          CJMP ZERO L5167                   %-> 5167
5204          ILOGL AND DSPL LE12 D,SCR B,SH A,H
5205          LOGM BDIR D,T
5206          JMP L5156                         %-> 5156
5207  L5207,  ARM BM1 D,SH B,B5
5210          ILOGM AND LE15 D,SCR B,SH A,SCR
5211          LOGM AND D,SH B,SH A,D
5212          ARM BMAM1 D,SS B,AC A,SCR
5213          CARM BM1 NEG D,SCR B,SH
5214          ARM PLUS D,B B,B A,SS
5215          ILOGM ADIR DSPL LE14 D,SCR A,SS
5216          ILOGM ADIR LE12 D,SS A,SS
5217          ILOGM ADIR LE10 D,P A,SS
5220          ARM BM1 D,IO B,CAR A,P
5221          LOGM ADIR CPTR D,P A,A
5222          LOGM BDIR D,P B,B1
5223          LOGM AND B,B17 A,D
5224          CARM PLUS NZERO D,SCR B,P A,SCR
5225          LOGM BDIR B,B0
5226          ILOGM AND LE17 B,AC A,SS
5227          CARM PLUS ADD1 NZERO D,SCR A,SCR
5230          LOGM ADIR D,D A,SCR
5231          LOGM BDIR D,SCR B,B2
5232  L5232,  ARM BMINA D,D B,D A,SCR
5233          CJMP NEG L5241                    %-> 5241
5234          LOGM ADIR A,SS
5235          CJMP NZERO L5335                  %-> 5335
5236          LOGM BDIRC CRR1
5237          LOGM ADIR D,SS A,H
5240          JMP L5232                         %-> 5232
5241  L5241,  LOGL ADIR D,SH
5242          ARM PLUS D,D B,B2 A,D
5243          LOGM BDIR B,2AC
5244          LOGM BDIR D,SC B,2AC
5245          LOGM BDIR D,D B,AC
5246          LOGM BDIRC D,SH
5247          LOOP BM1 BM1A SHR SHZE TSC0
5250          LOGM ANDCB B,SH A,SS
5251          CJMP ZERO L5254                   %-> 5254
5252          ILOGM ADIR LE17 A,SCR
5253          IARM BM1 DSPL LE17 D,SCR B,AC
5254  L5254,  ARM PLUS ADD1 D,A A,R
5255          ILOGM ADIR DSPL LE12 D,SS A,SS
5256  L5256,  ILOGM ADIR LE11 D,SP A,SS
5257          LOGM BDIR D,T B,B3
5260          LOGM BDIR D,P B,B2
5261          LOGM BDIR B,B17
5262          ILOGM AND LE15 B,AC A,SCR
5263          CLOGM ADIR ZERO D,T
5264          LOGM BDIR B,B0
5265          ILOGM AND LE17 B,AC A,SS
5266          CLOGM OR NZERO D,T B,T A,P
5267          ILOGM ADIR LE14 A,SCR
5270          ARM BM1 B,AC
5271          CJMP NEG L5411                    %-> 5411
5272          LOGM ADIR D,SC A,D
5273          LOGM ADIRC D,SH
5274          LOOP BM1 BM1A SHR SHZE TSC0
5275          ILOGM BDIR DSPL LE14 D,SCR B,SH
5276          ARM BMINA D,D B,D A,T
5277          ARM BM1 D,T B,D
5300          ARM BMINA B,B3 A,D
5301          CJMP POS L5303                    %-> 5303
5302          ARM BMINA D,D A,SCR
5303  L5303,  LOGM BDIRC D,SH
5304          LOGM ADIR D,SC A,D
5305          ARM BM1 B,D
5306          CJMP POS L5312                    %-> 5312
5307          LOOP BM1 BM1A SHR SHZE TSC0
5310          LOGM BDIRC D,SS B,SH
5311          JMP L5314                         %-> 5314
5312  L5312,  LOOP BM1 BM1A SHZE TSC0
5313          LOGM BDIR D,SS B,SH
5314  L5314,  ARM BMINA D,B B,B A,SCR
5315          CJMP NEG L5355                    %-> 5355
5316          ILOGM ADIR LE12 D,SH A,SS
5317  L5317,  ILOGM AND LE14 D,SH B,SH A,SCR
5320          LOGM ADIR D,SC A,D
5321          CJMP SNEG L5324                   %-> 5324
5322          LOOP BM1 BM1A SHRO TSC0
5323          JMP L5325                         %-> 5325
5324  L5324,  LOOP BM1 BM1A SHR SHRO TSC0
5325  L5325,  LOGM ADIR A,T
5326          CJMP SNEG L5332                   %-> 5332
5327          LOGM AND B,SH A,SS
5330          LOGM OR D,SP B,AC A,SP
5331          JMP L5357                         %-> 5357
5332  L5332,  LOGM ANDCA B,SH A,SS
5333          LOGM OR D,SP B,AC A,SP
5334          JMP L5375                         %-> 5375
5335  L5335,  ILOGM ADIR LE17 A,SCR
5336          IARM BM1 DSPL LE17 D,SCR B,AC
5337          ARM PLUS B,B2 A,D
5340          LOGM BDIR B,HAC
5341          ARM PLUS D,A B,HAC A,R
5342          LOGL ADIR D,SH
5343          ARM BM1 B,B2
5344          LOGM AND B,AC A,D
5345          LOGM BDIR B,2AC
5346          LOGM BDIR D,D B,2AC
5347          ILOGM ADIR LE10 D,P A,SS
5350          ARM BM1 D,IO B,CAR A,P
5351          ARM BM1 CPTR D,P B,A
5352          ARM BDI ADD1 CRR1 D,A B,A
5353          ILOGM ADIR DSPL LE12 D,SS A,H
5354          JMP L5256                         %-> 5256
5355  L5355,  ILOGM ADIR LE13 D,SH A,SS
5356          JMP L5317                         %-> 5317
5357  L5357,  ARM BMINA D,B B,B A,SCR
5360          CJMP NEG L5405                    %-> 5405
5361          ILOGM ADIR LE10 D,P A,SS
5362          ARM BM1 D,IO B,CAR A,P
5363          ARM BM1 CPTR D,P B,A
5364          ARM BDI ADD1 CRR1 D,A B,A
5365          LOGM ADIR D,SH A,H
5366  L5366,  LOGM ADIR D,SC A,D
5367          CJMP SNEG L5372                   %-> 5372
5370          LOOP BM1 BM1A SHRO TSC0
5371          JMP L5373                         %-> 5373
5372  L5372,  LOOP BM1 BM1A SHR SHRO TSC0
5373  L5373,  LOGM ANDCA B,SH A,SS
5374          LOGM OR D,SP B,AC A,SP
5375  L5375,  ILOGM ADIR LE10 D,P A,SCR
5376          ARM BM1 D,IO B,CAR A,P
5377          ARM BM1 CPTR D,P B,X
5400          ARM BMINA B,L A,X
5401          CJMP ZERO L5424                   %-> 5424
5402          ARM BDI ADD1 CWR1 D,X B,X A,SP
5403          LOGM AND D,SP B,SH A,SS
5404          JMP L5357                         %-> 5357
5405  L5405,  ARM PLUS B,B A,SCR
5406          CJMP NEG L5411                    %-> 5411
5407          ILOGM ADIR LE13 D,SH A,SS
5410          JMP L5366                         %-> 5366
5411  L5411,  ILOGM ADIR LE10 D,P A,SCR
5412          ARM BM1 D,IO B,CAR A,P
5413          ARM BM1 CPTR D,P B,X
5414          ARM BMINA B,X A,L
5415          CJMP POSM L5424                   %-> 5424
5416          ARM BDI ADD1 CWR1 D,X B,X A,SP
5417  L5417,  ARM BMAM1 B,L A,X
5420          CJMP NEGM L5423                   %-> 5423
5421          ARM BDI ADD1 CWR1 D,X B,X
5422          JMP L5417                         %-> 5417
5423  L5423,  LOGM ADIR D,SP
5424  L5424,  ILOGM ADIR LE12 A,SCR
5425          LOGM OR D,SP B,AC A,SP
5426          ILOGM ADIR LE13 A,SCR
5427          LOGM OR D,SP B,AC A,SP
5430          LOGM BDIRC CWR1 A,SP
5431          JMP L5060                         %-> 5060
5432  L5432,  ILOGM ADIR LE12 D,SP A,SCR
5433          ILOGM OR LE13 D,SP B,AC A,SCR
5434          ARM BM1 D,SH B,B5
5435          IARM BMINA LE15 D,SCR A,SCR
5436          LOGM AND D,SCR B,SH A,SCR
5437          LOGM AND D,SH B,SH A,D
5440          LOGM AND B,B0 A,D
5441          CARM BDI ADD1 NZERO D,SH B,SH
5442          LOGM BDIR D,SS B,B1
5443          ARM BMINA D,SH B,SH A,SCR
5444          ARM BMINA D,SH B,SH A,SS
5445          CJMP POS L5462                    %-> 5462
5446          ARM BDI ADD1 B,SH
5447          CJMP NZERO L5650                  %-> 5650
5450          LOGM AND B,B17 A,D
5451          CJMP NZERO L5462                  %-> 5462
5452          LOGM BDIR D,P B,B2
5453          ARM BMINA D,B B,B A,P
5454          ARM BM1 D,A B,A
5455          ARM BM1 D,SH B,B2
5456          LOGM ADIR D,SCR
5457          JMP L5502                         %-> 5502
5460  L5460,  ILOGM ADIR LE12 D,SCR A,SS
5461          JMP L5502                         %-> 5502
5462  L5462,  LOGM BDIR D,B B,SH
5463          LOGM AND B,B17 A,D
5464          CJMP ZERO L5467                   %-> 5467
5465          ARM PLUS D,B B,B A,SS
5466          ARM PLUS D,SH B,SH A,SS
5467  L5467,  LOGM BDIR D,P B,B2
5470          ARM BMINA D,B B,B A,P
5471          CJMP NEG L5460                    %-> 5460
5472          LOGM BDIR B,SH
5473          LOGM BDIR B,HAC
5474          ARM PLUS D,A B,HAC A,A
5475          ILOGM ADIR LE10 D,P A,SS
5476          ARM BM1 D,IO B,CAR A,P
5477          ARM BM1 CPTR D,P B,A
5500          ARM BM1 CRR1
5501          LOGM ADIR D,SCR A,H
5502  L5502,  ARM BM1 D,A B,A
5503          LOGL ADIR D,SH
5504          ARM BM1 D,P B,B2
5505          LOGM AND B,SH A,P
5506          LOGM BDIR B,2AC
5507          LOGM BDIR D,D B,2AC
5510          LOGM BDIR D,SS B,B3
5511          LOGM OR B,B2 A,SS
5512          ARM BMINA D,SC B,AC A,D
5513          LOGM BDIRC D,SH
5514          LOOP BM1 BM1A SHZE TSC0
5515          ILOGM BDIR DSPL LE12 D,SCR B,SH
5516          IARM BMINA DSPL LE13 D,SS B,D A,T
5517          ILOGM BDIR DSPL LE13 D,SCR B,AC
5520          LOGM BDIR D,T B,AC
5521          ARM BMINA B,B3 A,T
5522          CJMP POS L5525                    %-> 5525
5523          LOGM BDIR D,T B,B2
5524          IARM BMINA DSPL LE13 D,SS A,T
5525  L5525,  LOGM BDIRC D,SH
5526          ILOGM ADIR LE13 D,SC A,SS
5527          CJMP SPOS L5533                   %-> 5533
5530          LOOP BM1 BM1A SHR SHZE TSC0
5531          ILOGM BDIRC DSPL LE11 D,SCR B,SH
5532          JMP L5535                         %-> 5535
5533  L5533,  LOOP BM1 BM1A SHZE TSC0
5534          ILOGM BDIR DSPL LE11 D,SCR B,SH
5535  L5535,  LOGM ADIR D,SH A,SCR
5536          ILOGM ADIR LE14 A,SCR
5537          CJMP ZERO L5572                   %-> 5572
5540          ARM BMINA D,SC B,B3 A,D
5541          LOGM BDIR D,P B,B3
5542          LOGM OR B,B2 A,P
5543          ARM BMINA D,SS B,AC A,D
5544          CJMP NZERO L5553                  %-> 5553
5545          ILOGM ADIR LE10 D,P A,SS
5546          ARM BM1 D,IO B,CAR A,P
5547          ARM BDI ADD1 CPTR D,P B,A
5550          LOGM BDIR D,P B,B3
5551          LOGM OR CRR1 D,SC B,B2 A,P
5552          LOGM ADIR D,SH A,H
5553  L5553,  LOOP BM1 BM1A SHR TSC0
5554          ARM BM1 D,P B,B4
5555          LOGM AND D,P B,SH A,P
5556          ARM BDI ADD1 B,B2
5557          ARM BMAM1 B,AC A,P
5560          CJMP POS L5570                    %-> 5570
5561          LOGM BDIR D,SC B,B2
5562          LOOP BM1 BM1A SHR TSC0
5563          LOGM ADIR A,SS
5564          CLOGM ADIR ZERO D,SH A,SCR
5565          ARM BM1 B,MPC A,IO
5566          JMP L5675                         %-> 5675
5567          JMP L5572                         %-> 5572
5570  L5570,  ILOGM ADIR DSPL LE14 D,SCR
5571          LOGM ADIR D,SH A,SCR
5572  L5572,  LOGM BDIR D,SCR B,B2
5573          ILOGM AND LE12 D,SH B,SH A,SCR
5574          ILOGM ADIR LE13 D,SC A,SS
5575          CJMP SNEG L5600                   %-> 5600
5576          LOOP BM1 BM1A SHRO TSC0
5577          JMP L5601                         %-> 5601
5600  L5600,  LOOP BM1 BM1A SHR SHRO TSC0
5601  L5601,  ILOGM ADIR LE13 A,SCR
5602          CJMP SPOS L5606                   %-> 5606
5603          ILOGM ANDCA LE11 B,SH A,SCR
5604          LOGM OR D,SP B,AC A,SP
5605          JMP L5611                         %-> 5611
5606  L5606,  ILOGM AND LE11 B,SH A,SCR
5607          LOGM OR D,SP B,AC A,SP
5610          JMP L5631                         %-> 5631
5611  L5611,  ARM BMINA D,B B,B A,SCR
5612          CJMP NEG L5644                    %-> 5644
5613          ILOGM ADIR LE10 D,P A,SS
5614          ARM BM1 D,IO B,CAR A,P
5615          ARM BM1 CPTR D,P B,A
5616          ARM BM1 CRR1 D,A B,A
5617          LOGM ADIR D,SH A,H
5620  L5620,  ILOGM ADIR LE14 A,SCR
5621          CJMP NZERO L5641                  %-> 5641
5622  L5622,  ILOGM ADIR LE13 D,SC A,SS
5623          CJMP SNEG L5626                   %-> 5626
5624          LOOP BM1 BM1A SHRO TSC0
5625          JMP L5627                         %-> 5627
5626  L5626,  LOOP BM1 BM1A SHR SHRO TSC0
5627  L5627,  ILOGM AND LE11 B,SH A,SCR
5630          LOGM OR D,SP B,AC A,SP
5631  L5631,  ILOGM ADIR LE10 D,P A,SCR
5632          ARM BM1 D,IO B,CAR A,P
5633          ARM BM1 CPTR D,P B,L
5634          ARM BMINA B,L A,X
5635          CJMP ZERO L5670                   %-> 5670
5636          ARM BM1 CWR1 D,L B,L A,SP
5637          ILOGM ANDCA LE11 D,SP B,SH A,SCR
5640          JMP L5611                         %-> 5611
5641  L5641,  ARM BM1 B,MPC A,IO
5642          JMP L5677                         %-> 5677
5643          JMP L5622                         %-> 5622
5644  L5644,  ARM PLUS B,B A,SCR
5645          CJMP NEG L5651                    %-> 5651
5646          ILOGM ADIR LE12 D,SH A,SS
5647          JMP L5620                         %-> 5620
5650  L5650,  ILOGM ADIR DSPL LE14 D,SCR
5651  L5651,  ILOGM ADIR LE10 D,P A,SCR
5652          ARM BM1 D,IO B,CAR A,P
5653          LOGM ADIR D,SH
5654          ILOGM ADIR LE14 A,SCR
5655          CJMP NZERO L5641                  %-> 5641
5656          ARM BM1 CPTR D,P B,L
5657          ARM BMAM1 B,L A,X
5660          CJMP NEGM L5670                   %-> 5670
5661          ARM BM1 CWR1 D,L B,L A,SP
5662  L5662,  ARM BMAM1 B,L A,X
5663          CJMP NEGM L5667                   %-> 5667
5664          ARM BM1 CPTR D,P B,L
5665          ARM BM1 CWR1 D,L B,L
5666          JMP L5662                         %-> 5662
5667  L5667,  LOGM ADIR D,SP
5670  L5670,  LOGM ADIR A,SP
5671          ILOGM OR LE11 D,SP B,AC A,SS
5672          ARM BM1 CPTR D,P B,L
5673          LOGM BDIRC CWR1 A,SP
5674          JMP L5060                         %-> 5060
5675  L5675,  LOGM BDIR D,SCR B,B2
5676          ARM BM1 D,T B,B4
5677  L5677,  ARM PLUS D,SS B,B0 A,H
5700          ARM BM1 D,IO B,CAR A,SS
5701          ARM BDI ADD1 B,B3
5702          ARM BDI ADD1 D,SS B,AC
5703  L5703,  ARM BDI ADD1 D,SH B,SH
5704          LOGM AND B,SH A,T
5705          ARM BMINA B,AC A,SS
5706          CJMP NEG L5720                    %-> 5720
5707          LOGM ANDCA D,SH B,SH A,T
5710          LOGM BDIR D,SC B,B2
5711          LOOP BM1 BM1A SHR SH32 TSC0
5712          ARM BMINA D,D B,D A,SCR
5713          CJMP POS L5703                    %-> 5703
5714  L5714,  LOGL BDIR D,D B,SH
5715          LOGM ADIR D,SH A,D
5716          ARM PLUS D,D B,B1 A,SS
5717          JMP ,CAR
5720  L5720,  ARM PLUS D,SC B,D A,SCR
5721          LOOP BM1 BM1A SHR SH32 TSC0
5722          ILOGM BDIR DSPL LE14 D,SCR
5723          JMP L5714                         %-> 5714
5724  L5724,  IARM BM1 DSPL LE15 D,SS
5725          JMP L5731                         %-> 5731
5726  L5726,  IARM PLUS ADD1 DSPL LE15 D,SS
5727          JMP L5731                         %-> 5731
5730  L5730,  ILOGM BDIR DSPL LE15 D,SS
5731  L5731,  ILOGM ADIR DSPL LE10 D,SS A,P
5732          LOGM ADIR D,SP A,P
5733          ILOGM ADIR DSPL LE14 D,SCR
5734          LOGM ADIR D,SCR
5735          LOGM AND B,B16 A,D
5736          CARM BM1 NZERO D,SCR
5737          ARM BM1 D,IO B,CAR A,SCR
5740          ILOGM ADIR DSPL LE11 D,SCR A,SCR
5741          ARM BM1 D,P B,A
5742          ARM BM1 CPTR D,SS B,B5
5743          LOGM ADIR CRR1 D,P A,SP
5744          ARM BM1 D,P B,A
5745          LOGM AND D,SCR B,D A,SS
5746          LOGM AND B,B0 A,SCR
5747          CARM PLUS ADD1 NZERO D,SCR A,SCR
5750          ILOGM ADIR DSPL LE12 D,SS A,SCR
5751          CJMP ZERO L6341                   %-> 6341
5752  L5752,  LOGM BDIR D,SH B,HAC
5753          ARM BM1 D,SCR B,SH
5754          LOGM AND B,B17 A,D
5755          CARM PLUS ADD1 NZERO D,SCR A,SCR
5756          LOGM ADIR A,SCR
5757          ARM PLUS CPTR D,P B,HAC A,P
5760          LOGM ADIR CRR1 D,P A,SP
5761          ARM BM1 D,P B,X
5762          ILOGM ADIR CPTR DSPL LE12 D,SCR A,H
5763          LOGM ADIR D,P
5764          LOGM AND B,B16 A,T
5765          CARM BM1 NZERO D,P
5766          ARM BM1 D,IO B,CAR A,P
5767          ILOGM ADIR DSPL LE10 D,SCR A,P
5770          LOGM ADIR CRR1 D,P A,SP
5771          ARM BM1 D,P B,X
5772          LOGM AND D,SS B,T A,SS
5773          LOGM AND B,B0 A,SS
5774          CARM PLUS ADD1 NZERO D,SS A,SS
5775          ILOGM ADIR DSPL LE13 D,SS A,SS
5776          CJMP ZERO L6350                   %-> 6350
5777  L5777,  LOGM BDIR D,SH B,HAC
6000          ARM BM1 D,SS B,SH
6001          LOGM AND B,B17 A,T
6002          CARM PLUS ADD1 NZERO D,SS A,SS
6003          LOGM ADIR A,SS
6004          ARM PLUS CPTR D,P B,HAC A,P
6005          LOGM ADIR CRR1 D,P A,SP
6006          ILOGM ADIR LE11 D,SP A,SCR
6007          ILOGM ADIR DSPL LE13 D,SCR A,H
6010          ILOGM ADIR DSPL LE17 D,SCR A,D
6011          ILOGM ADIR DSPL LE17 D,SS A,T
6012          ILOGM ADIR DSPL LE16 D,SCR A,L
6013          ILOGM ADIR DSPL LE16 D,SS A,B
6014          ILOGM ADIR DSPL LE11 D,SS A,X
6015          IARM PLUS ADD1 LE15 A,SS
6016          CJMP ZERO L6735                   %-> 6735
6017          ILOGM ADIR DSPL LE11 D,SCR A,A
6020          LOGM ADIR D,B A,SCR
6021          LOGM ADIR D,L A,SS
6022          IARM BDI DSPL LE14 D,SCR
6023          LOGM BDIR B,B
6024          ARM PLUS D,A B,HAC A,A
6025          ARM BM1 D,A B,A
6026          ILOGM ADIR LE12 D,SH A,SCR
6027          LOGM AND B,B0 A,B
6030          CJMP NZERO L6035                  %-> 6035
6031          LOGM BDIR D,SC B,B3
6032          LOOP BM1 BM1A SHR SH32 TSC0
6033          LOGM BDIR D,B B,B1
6034          JMP L6036                         %-> 6036
6035  L6035,  LOGM BDIR D,B B,B2
6036  L6036,  LOGM BDIR D,SC B,B2
6037          LOGM BDIR D,SCR B,SH
6040          LOOP BM1 BM1A SHR SH32 TSC0
6041          LOGM BDIR D,D B,SH
6042          ILOGL BDIR DSPL LE14 D,SS B,SH
6043          ILOGM ADIR LE13 D,SH A,SCR
6044          ILOGM ADIR DSPL LE15 D,SCR A,L
6045          ARM PLUS D,X B,HAC A,X
6046          ARM BM1 D,X B,X
6047          LOGM AND B,B0 A,L
6050          CJMP NZERO L6055                  %-> 6055
6051          LOGM BDIR D,SC B,B3
6052          LOOP BM1 BM1A SHR SH32 TSC0
6053          LOGM BDIR D,L B,B1
6054          JMP L6056                         %-> 6056
6055  L6055,  LOGM BDIR D,L B,B2
6056  L6056,  ILOGM EXOR LE15 B,SH A,SS
6057          ILOGM EXOR DSPL LE15 D,SS B,AC A,SCR
6060          LOGM BDIR D,SC B,B2
6061          LOOP BM1 BM1A SHR TSC0
6062          LOGM BDIR D,T B,SH
6063          ARM BM1 D,SH B,B12
6064          LOGM BDIR D,SCR B,B2
6065          ARM PLUS D,SC B,B0 A,SCR
6066          ILOGM AND LE17 D,SS B,SH A,SS
6067          ILOGM AND LE17 D,SH B,SH A,SCR
6070          LOGM ADIR A,SS
6071          LOOP BDI BDIA SHR B,HAC TSC0
6072          LOGM BDIR D,SS B,AC
6073          ARM BMINA D,SH B,SH A,SS
6074          CJMP POS L6164                    %-> 6164
6075          IARM PLUS LE13 D,SS B,SH A,SS
6076          ILOGM ADIR DSPL LE13 D,SS A,SS
6077          ILOGL ADIR LE15 D,X A,SCR
6100          LOGL BDIR D,L B,2AC
6101          ARM PLUS D,L B,SH A,L
6102          LOGM ADIR A,L
6103          LOGM BDIR B,HAC
6104          IARM PLUS LE11 D,X B,HAC A,SS
6105          ILOGM ADIR LE10 D,P A,SCR
6106          ARM BM1 D,IO B,CAR A,P
6107          ARM BM1 D,P B,X
6110          ARM BM1 CPTR D,X B,X
6111          ARM BM1 CRR1
6112          LOGM ADIR D,SH A,H
6113          ARM BM1 D,SS B,B2
6114          LOGM AND D,L B,L A,SS
6115          ILOGM ADIR LE17 D,SS A,SS
6116          LOGM AND B,B12 A,SS
6117          CJMP ZERO L6153                   %-> 6153
6120          LOGL ADIR
6121          ARM BMINA B,B1 A,L
6122          CJMP NEG L6142                    %-> 6142
6123          LOGM BDIR B,2AC
6124          LOGM BDIR D,SC B,2AC
6125          LOOP BM1 BM1A SHR TSC0
6126          ILOGM BDIR D,SCR B,SH
6127          LOGM BDIR D,SC B,B2
6130          LOOP BM1 BM1A SHR TSC0
6131          LOGM BDIR D,T B,SH
6132          ARM BM1 D,SH B,B4
6133          LOGM AND D,SH B,SH A,SCR
6134  L6134,  ARM BDI ADD1 D,SCR B,B2
6135          ARM BMINA B,SH A,SCR
6136          CJMP NEG L6141                    %-> 6141
6137          LOGM BDIR D,SCR B,B0
6140          ILOGM ADIR DSPL LE14 D,SCR A,SCR
6141  L6141,  JMP L6162                         %-> 6162
6142  L6142,  LOGM BDIR D,T B,SH
6143          ARM BDI ADD1 CPTR D,P B,X
6144          ARM BM1 CRR1
6145          LOGM ADIR D,SH A,H
6146          LOGM BDIR D,SC B,B2
6147          LOOP BM1 BM1A SHRO TSC0
6150          ARM BM1 D,SCR B,B4
6151          LOGM AND D,SH B,SH A,SCR
6152          JMP L6134                         %-> 6134
6153  L6153,  LOGL ADIR
6154          ARM BM1 B,B2
6155          ARM BMINA B,AC A,L
6156          LOGM BDIR B,2AC
6157          LOGM BDIR D,SC B,2AC
6160          LOOP BM1 BM1A SHR TSC0
6161          LOGM BDIR D,T B,SH
6162  L6162,  ARM PLUS D,L B,B1 A,L
6163          JMP L6167                         %-> 6167
6164  L6164,  ILOGM BDIR DSPL LE15 D,SCR B,SH
6165          ILOGM ADIR LE15 A,SCR
6166          CJMP NZERO L6427                  %-> 6427
6167  L6167,  ILOGL ADIR LE14 D,SH A,SS
6170  L6170,  ARM BM1 D,SS B,B4
6171          LOGM BDIR D,SCR B,B3
6172          LOGM OR D,SCR B,B1 A,SCR
6173          ILOGM ADIR DSPL LE15 D,SCR A,SCR
6174  L6174,  ILOGM ADIR LE12 A,SS
6175          IARM BM1 DSPL LE12 D,SS B,AC
6176          CJMP ZERO L6261                   %-> 6261
6177          ARM BM1 D,B B,B
6200          CJMP ZERO L6251                   %-> 6251
6201  L6201,  ILOGM ADIR LE13 A,SS
6202          IARM BM1 DSPL LE13 D,SS B,AC
6203          CJMP ZERO L6354                   %-> 6354
6204          ARM BM1 D,L B,L
6205          CJMP ZERO L6242                   %-> 6242
6206  L6206,  LOGM AND D,SH B,D A,SS
6207          LOGM AND D,SCR B,T A,SS
6210          LOGM BDIR B,B0
6211          ILOGM AND LE15 B,AC A,SS
6212          CJMP NZERO L6232                  %-> 6232
6213          ARM PLUS D,SH B,SH A,SCR
6214          IARM PLUS LE14 D,SH B,SH A,SCR
6215          ILOGM ADIR DSPL LE14 D,SCR
6216          IARM BMINA LE15 D,SCR B,SH A,SCR
6217          CJMP NEG L6223                    %-> 6223
6220          LOGM BDIR B,B0
6221          ILOGM BDIR DSPL LE14 D,SCR B,AC
6222          LOGM ADIR D,SH A,SCR
6223  L6223,  LOGM BDIR D,SC B,B2
6224          LOGM ADIR A,D
6225          LOGL ADIR A,T
6226          LOOP BDI BDIA SHR SH32 B,HAC TSC0
6227          LOGL BDIR D,T B,AC
6230          LOGM BDIR D,D B,AC
6231          JMP L6174                         %-> 6174
6232  L6232,  IARM BMINA LE14 D,SH B,SH A,SCR
6233          ILOGM ADIR DSPL LE14 D,SCR
6234          ARM BMINA D,SH B,SH A,SCR
6235          CJMP POS L6223                    %-> 6223
6236          LOGM BDIR D,SCR B,B0
6237          ILOGM ADIR DSPL LE14 D,SCR A,SCR
6240          IARM PLUS LE15 D,SH B,SH A,SCR
6241          JMP L6223                         %-> 6223
6242  L6242,  ILOGM ADIR LE10 D,P A,SCR
6243          ARM BM1 D,IO B,CAR A,P
6244          ARM BM1 CPTR D,P B,X
6245          ARM BM1 CRR1 D,X B,X
6246          LOGM ADIR D,T A,H
6247          LOGM BDIR D,L B,B2
6250          JMP L6206                         %-> 6206
6251  L6251,  ARM BM1 D,IO B,CAR A,SP
6252          ARM BDI CPTR D,P B,A
6253          LOGL BDIR D,SCR B,SH
6254          ARM BM1 CWR1 D,A B,A A,SCR
6255          LOGM ADIR CPTR D,P A,A
6256          LOGM BDIR CRR1 D,B B,B2
6257          LOGM ADIR D,D A,H
6260          JMP L6201                         %-> 6201
6261  L6261,  LOGM AND B,B1 A,B
6262          CJMP ZERO L6266                   %-> 6266
6263          LOGM ADIR D,SH A,D
6264          LOGM BDIR D,SC B,B3
6265          LOOP BM1 BM1A SHR SH32 TSC0
6266  L6266,  LOGL BDIR D,SCR B,SH
6267          ARM BM1 D,IO B,CAR A,SP
6270          LOGM ADIR CPTR D,P A,A
6271          ARM BM1 CWR1 A,SCR
6272          LOGM BDIR B,B0
6273          ILOGM AND LE15 B,AC A,SS
6274          CJMP NZERO L6453                  %-> 6453
6275          ILOGM ADIR LE13 D,B A,SS
6276          CJMP ZERO L6324                   %-> 6324
6277  L6277,  ARM BM1 D,SS B,B4
6300          ARM BM1 D,B B,B
6301          CJMP ZERO L6324                   %-> 6324
6302          ARM BM1 D,L B,L
6303          CJMP ZERO L6315                   %-> 6315
6304  L6304,  LOGM AND D,SH B,T A,SS
6305          CJMP ZERO L6310                   %-> 6310
6306          IARM BM1 DSPL LE14 D,SCR
6307          JMP L6324                         %-> 6324
6310  L6310,  LOGM ADIR D,SH A,T
6311          LOGM BDIR D,SC B,B2
6312          LOOP BM1 BM1A SHR TSC0
6313          LOGM BDIR D,T B,SH
6314          JMP L6277                         %-> 6277
6315  L6315,  ILOGM ADIR LE10 D,P A,SCR
6316          ARM BM1 D,IO B,CAR A,P
6317          ARM BM1 CPTR D,P B,X
6320          ARM BM1 CRR1 D,X B,X
6321          LOGM ADIR D,T A,H
6322          LOGM BDIR D,L B,B2
6323          JMP L6304                         %-> 6304
6324  L6324,  ILOGM ADIR LE11 D,A A,SCR
6325          ILOGM ADIR LE11 D,X A,SS
6326          ILOGM ADIR LE17 D,D A,SCR
6327          ILOGM ADIR LE17 D,T A,SS
6330          ILOGM ADIR LE16 D,L A,SCR
6331          ILOGM ADIR LE16 D,B A,SS
6332          LOGM AND B,B0 A,D
6333          CJMP NZERO L6635                  %-> 6635
6334  L6334,  ILOGM ADIR LE10 D,P A,SS
6335          ILOGM ADIR LE14 A,SCR
6336          CJMP NZERO L6340                  %-> 6340
6337          ARM PLUS ADD1 D,P A,P
6340  L6340,  LOGM BDIRC CFC
6341  L6341,  IARM PLUS ADD1 LE15 A,SS
6342          CJMP ZERO L5752                   %-> 5752
6343          ARM BM1 D,SS B,B5
6344          LOGM AND B,T A,SS
6345          CJMP ZERO L6334                   %-> 6334
6346          ILOGM BDIRC DSPL LE14 D,SCR
6347          JMP L6334                         %-> 6334
6350  L6350,  IARM PLUS ADD1 LE15 A,SS
6351          CJMP ZERO L5777                   %-> 5777
6352          ILOGM BDIR DSPL LE14 D,SCR
6353          JMP L6334                         %-> 6334
6354  L6354,  ILOGM ADIR LE14 D,SCR A,SCR
6355          CJMP ZERO L6412                   %-> 6412
6356          LOGM BDIR B,B0
6357          ILOGM AND LE15 B,AC A,SS
6360          CJMP NZERO L6626                  %-> 6626
6361          LOGM AND D,SH B,D A,SS
6362          ARM BDI ADD1 D,SH B,SH
6363          ILOGM ADIR DSPL LE14 D,SCR
6364          IARM BMINA LE15 D,SCR B,SH A,SCR
6365          CJMP NEG L6370                    %-> 6370
6366          IARM BDI ADD1 DSPL LE14 D,SCR
6367          LOGM ADIR D,SH A,SCR
6370  L6370,  LOGM BDIR D,SC B,B2
6371          LOGM ADIR A,D
6372          LOOP BDI BDIA SHR SH32 B,HAC TSC0
6373          LOGM BDIR D,D B,AC
6374          ILOGM ADIR LE12 D,SH A,SS
6375          IARM BM1 DSPL LE12 D,SS B,SH
6376          CJMP ZERO L6261                   %-> 6261
6377          ARM BM1 D,B B,B
6400          CJMP ZERO L6402                   %-> 6402
6401          JMP L6354                         %-> 6354
6402  L6402,  ARM BDI CPTR D,P B,A
6403          ARM BM1 D,IO B,CAR A,SP
6404          LOGL BDIR D,SCR B,SH
6405          ARM BM1 CWR1 D,P B,A A,SCR
6406          LOGM ADIR CPTR D,A A,P
6407          LOGM BDIR CRR1 D,B B,B2
6410          LOGM ADIR D,D A,H
6411          JMP L6354                         %-> 6354
6412  L6412,  LOGM AND B,B2 A,B
6413          CJMP NZERO L6324                  %-> 6324
6414          LOGL BDIR B,B
6415          LOGL BDIR B,2AC
6416          LOGL BDIR D,SCR B,2AC
6417          LOGM ADIR D,SC A,SCR
6420          LOGM ADIR D,SH A,D
6421          LOOP BM1 BM1A SHR SH32 TSC0
6422          ARM BM1 D,IO B,CAR A,SP
6423          LOGM ADIR D,P A,A
6424          LOGL BDIR CPTR D,SCR B,SH
6425          LOGM BDIRC CWR1 A,SCR
6426          JMP L6324                         %-> 6324
6427  L6427,  ILOGL ADIR LE14 D,SH A,SS
6430  L6430,  ILOGM ADIR LE12 A,SS
6431          IARM BM1 DSPL LE12 D,SS B,AC
6432          CJMP ZERO L6261                   %-> 6261
6433          ARM BM1 D,B B,B
6434          CJMP ZERO L6445                   %-> 6445
6435  L6435,  LOGM ADIR D,SH A,D
6436          LOGM BDIR D,SC B,B2
6437          LOOP BM1 BM1A SHR SH32 TSC0
6440          LOGM BDIR D,D B,SH
6441          ILOGM ADIR LE15 A,SCR
6442          IARM BM1 DSPL LE15 D,SCR B,AC
6443          CJMP NZERO L6430                  %-> 6430
6444          JMP L6170                         %-> 6170
6445  L6445,  ARM BM1 D,P B,A
6446          ARM BM1 D,IO B,CAR A,SP
6447          ARM BM1 CPTR D,A B,A
6450          LOGM BDIR CRR1 D,B B,B2
6451          LOGM ADIR D,D A,H
6452          JMP L6435                         %-> 6435
6453  L6453,  ILOGM ADIR LE14 A,SCR
6454          CJMP NZERO L6475                  %-> 6475
6455          IARM PLUS ADD1 DSPL LE12 D,SS
6456          ILOGM ADIR LE13 D,SH A,SS
6457          CJMP ZERO L6324                   %-> 6324
6460  L6460,  ILOGM ADIR LE13 D,SH A,SS
6461          IARM BM1 DSPL LE13 D,SS B,SH
6462          CJMP ZERO L6502                   %-> 6502
6463          ARM BM1 D,L B,L
6464          CJMP ZERO L6505                   %-> 6505
6465  L6465,  LOGM AND D,SH B,T A,SS
6466          CJMP NZERO L6514                  %-> 6514
6467  L6467,  LOGM ADIR D,SH A,T
6470          LOGM BDIR D,SC B,B2
6471          LOOP BM1 BM1A SHR TSC0
6472          LOGM BDIR D,T B,SH
6473          ILOGM ADIR DSPL LE12 D,SS
6474          JMP L6460                         %-> 6460
6475  L6475,  ILOGM ADIR DSPL LE14 D,SCR
6476          ILOGM ADIR LE13 A,SS
6477          CJMP ZERO L6524                   %-> 6524
6500          ILOGM ADIR DSPL LE15 D,SS
6501          JMP L6460                         %-> 6460
6502  L6502,  ILOGM ADIR LE15 A,SS
6503          CJMP ZERO L6524                   %-> 6524
6504          JMP L6324                         %-> 6324
6505  L6505,  ILOGM ADIR LE10 D,P A,SCR
6506          ARM BM1 D,IO B,CAR A,P
6507          ARM BM1 D,P B,X
6510          ARM BM1 CPTR D,X B,X
6511          LOGM BDIR CRR1 D,L B,B2
6512          LOGM ADIR D,T A,H
6513          JMP L6465                         %-> 6465
6514  L6514,  IARM PLUS ADD1 DSPL LE14 D,SCR
6515          ILOGM ADIR DSPL LE15 D,SS
6516          ILOGM ADIR LE12 A,SS
6517          CJMP ZERO L6467                   %-> 6467
6520          ARM BM1 B,SH
6521          CJMP NZERO L6467                  %-> 6467
6522          IARM PLUS DSPL LE14 D,SCR
6523          JMP L6467                         %-> 6467
6524  L6524,  ARM BM1 D,SH B,B5
6525          ILOGM AND LE17 D,T B,SH A,SCR
6526          LOGM AND B,B0 A,T
6527          CARM BDI ADD1 NZERO D,T B,T
6530          LOGM ADIR A,T
6531          LOGM BDIR D,SH B,HAC
6532          ARM BM1 D,SCR B,SH
6533          ILOGM ADIR LE17 D,L A,SCR
6534          ILOGM ADIR LE11 D,P A,SCR
6535          ARM BM1 D,P B,P
6536          LOGM AND B,B17 A,L
6537          CARM PLUS ADD1 NZERO D,SCR A,SCR
6540          LOGM ADIR A,SCR
6541          ARM PLUS CPTR D,P B,HAC A,P
6542          ARM BM1 D,IO B,CAR A,SP
6543          ARM BDI CRR1 D,B B,B2
6544          LOGM ADIR D,SH A,H
6545          LOGM AND B,B0 A,SCR
6546          CJMP NZERO L6552                  %-> 6552
6547          LOGM BDIR D,SC B,B3
6550          LOOP BM1 BM1A SHR SH32 TSC0
6551          LOGM BDIR D,B B,B1
6552  L6552,  LOGM BDIR D,D B,SH
6553          LOGM EXOR D,SH B,B0 A,D
6554          LOGM BDIR D,SC B,B2
6555          LOOP BM1 BM1A SHR SH32 TSC0
6556          LOGM BDIR D,D B,SH
6557          LOGM ADIR D,L
6560  L6560,  ARM BM1 D,T B,T
6561          CJMP ZERO L6614                   %-> 6614
6562          ARM BM1 D,B B,B
6563          CJMP ZERO L6604                   %-> 6604
6564  L6564,  LOGM ADIR A,L
6565          CJMP NZERO L6574                  %-> 6574
6566          LOGM AND D,SH B,D A,SS
6567          CJMP ZERO L6577                   %-> 6577
6570          IARM BMINA LE15 D,SCR B,SH A,SCR
6571          ARM BMINA D,SH A,SCR
6572          LOGM BDIR D,L B,B0
6573          JMP L6577                         %-> 6577
6574  L6574,  LOGM AND D,SH B,D A,SS
6575          IARM BMINA LE15 D,SCR B,SH A,SCR
6576          ARM BMAM1 D,SH A,SCR
6577  L6577,  LOGM BDIR D,SC B,B2
6600          LOGM ADIR A,D
6601          LOOP BDI BDIA SHR SH32 B,HAC TSC0
6602          LOGM BDIR D,D B,AC
6603          JMP L6560                         %-> 6560
6604  L6604,  LOGL BDIR CPTR D,SCR B,SH
6605          ARM BM1 D,IO B,CAR A,SP
6606          ARM BM1 CWR1 D,A B,P A,SCR
6607          LOGM ADIR CPTR D,P A,A
6610          LOGM ADIR CRR1 D,P A,A
6611          LOGM ADIR D,D A,H
6612          LOGM BDIR D,B B,B2
6613          JMP L6564                         %-> 6564
6614  L6614,  LOGM AND B,B1 A,B
6615          CJMP ZERO L6621                   %-> 6621
6616          LOGM ADIR D,SH A,D
6617          LOGM BDIR D,SC B,B3
6620          LOOP BM1 BM1A SHR SH32 TSC0
6621  L6621,  LOGM ADIR D,P A,A
6622          ARM BM1 D,IO B,CAR A,SP
6623          LOGL BDIR CPTR D,SCR B,SH
6624          LOGM BDIRC CWR1 A,SCR
6625          JMP L6324                         %-> 6324
6626  L6626,  LOGM AND D,SH B,D A,SS
6627          ILOGM ADIR DSPL LE14 D,SCR
6630          ARM BM1 D,SH B,SH
6631          CJMP POS L6370                    %-> 6370
6632          IARM PLUS ADD1 DSPL LE14 D,SCR
6633          IARM PLUS LE15 D,SH B,SH A,SCR
6634          JMP L6370                         %-> 6370
6635  L6635,  ARM BM1 D,P B,A
6636          ARM BM1 CPTR D,IO B,CAR A,SP
6637          LOGM AND CRR1 B,B17 A,D
6640          CJMP NZERO L6646                  %-> 6646
6641          ARM BM1 D,SH B,B14
6642          LOGM ANDCB B,SH A,H
6643          CJMP ZERO L6334                   %-> 6334
6644          IARM PLUS ADD1 DSPL LE14 D,SCR
6645          JMP L6653                         %-> 6653
6646  L6646,  ARM BM1 D,SH B,B10
6647          LOGM ORCB D,SH B,SH A,SS
6650          LOGM ANDCB B,SH A,H
6651          CJMP ZERO L6334                   %-> 6334
6652          IARM PLUS ADD1 DSPL LE14 D,SCR
6653  L6653,  LOGM AND CPTR D,SCR B,SH A,H
6654          ARM BM1 CWR1 A,SCR
6655          JMP L6334                         %-> 6334
6656  L6656,  ARM PLUS D,SP B,B0 A,H
6657          LOGM ADIR D,P A,A
6660          ILOGM ADIR CPTR LE11 D,SCR A,SCR
6661          ARM BM1 D,IO B,CAR A,SCR
6662          ARM BDI ADD1 CRR1 D,A B,A
6663          LOGM ADIR D,P A,X
6664          ILOGM ADIR CPTR LE10 D,SCR A,SCR
6665          ARM BM1 D,IO B,CAR A,SCR
6666          LOGM ADIR D,D A,H
6667          ARM BDI ADD1 CRR1 D,X B,X
6670          ARM BM1 D,IO B,CAR A,SP
6671          JMP ,CAR
6672          ARM PLUS D,SP B,B0 A,H
6673          LOGM ADIR D,P A,X
6674          ILOGM ADIR CPTR LE11 D,SCR A,SCR
6675          ARM BM1 D,IO B,CAR A,SCR
6676          ARM BDI ADD1 CRR1 D,X B,X
6677          LOGM ADIR D,P A,A
6700          ILOGM ADIR CPTR LE11 D,SCR A,SCR
6701          ARM BM1 D,IO B,CAR A,SCR
6702          LOGM ADIR D,T A,H
6703          ARM BDI ADD1 CRR1 D,A B,A
6704          ARM BM1 D,IO B,CAR A,SP
6705          JMP ,CAR
6706  L6706,  ARM PLUS D,SP B,B0 A,H
6707          LOGM ADIR D,P A,A
6710          ILOGM ADIR CPTR LE11 D,SCR A,SCR
6711          ARM BM1 D,IO B,CAR A,SCR
6712          ARM BDI ADD1 CRR1 D,A B,A
6713          ARM BM1 D,IO B,CAR A,SP
6714          JMP ,CAR
6715  L6715,  ARM PLUS D,SP B,B0 A,H
6716          LOGM ADIR D,P A,X
6717          ILOGM ADIR CPTR LE10 D,SCR A,SCR
6720          ARM BM1 D,IO B,CAR A,SCR
6721          ARM BDI ADD1 CRR1 D,X B,X
6722          ARM BM1 D,IO B,CAR A,SP
6723          JMP ,CAR
6724  L6724,  ARM BM1 D,A
6725          JMP L6733                         %-> 6733
6726  L6726,  ILOGM ADIR LE12 A,SS
6727          CJMP ZERO L6732                   %-> 6732
6730          ARM BDI D,A B,B0
6731          JMP L6733                         %-> 6733
6732  L6732,  LOGM ADIR D,A
6733  L6733,  ILOGM ADIR DSPL LE12 D,SCR
6734          JMP L7715                         %-> 7715
6735  L6735,  ILOGM ADIR DSPL LE14 D,SCR
6736          ILOGM ADIR DSPL LE11 D,SCR A,SP
6737          ILOGM ADIR LE12 D,SH A,SCR
6740          LOGM AND B,B0 A,SCR
6741          CJMP NZERO L6744                  %-> 6744
6742          LOGM BDIR D,SC B,B3
6743          LOOP BM1 BM1A SHR TSC0
6744  L6744,  ILOGM ADIR LE12 A,SS
6745          CJMP NZERO L6747                  %-> 6747
6746          LOGM ADIR D,SH
6747  L6747,  ILOGM BDIR DSPL LE12 D,SCR B,SH
6750          LOGM BDIR D,D B,SH
6751          ILOGM ADIR LE13 D,SH A,SCR
6752          ILOGM ADIR DSPL LE13 D,SCR
6753          LOGM AND B,B0 A,SS
6754          CJMP NZERO L6757                  %-> 6757
6755          LOGM BDIR D,SC B,B3
6756          LOOP BM1 BM1A SHR TSC0
6757  L6757,  ILOGM ADIR LE13 A,SS
6760          CJMP ZERO L6726                   %-> 6726
6761          ILOGM ADIR LE12 A,SS
6762          CJMP ZERO L6724                   %-> 6724
6763          ILOGM ADIR DSPL LE15 D,SCR
6764          LOGM EXOR D,T B,SH A,D
6765          LOGM AND B,B0 A,T
6766          CJMP NZERO L7754                  %-> 7754
6767          ARM BM1 D,L B,B5
6770          ARM PLUS ADD1 D,SC B,B2
6771          ILOGL ADIR LE17 D,SH A,SS
6772          ILOGM ADIR LE17 D,SH A,SCR
6773          LOOP BM1 BM1A SHR SH32 TSC0
6774          LOGM AND D,B B,SH A,L
6775          LOGL AND D,L B,SH A,L
6776          ILOGM ADIR LE12 D,SH A,SS
6777          ARM BMINA D,B B,SH A,B
7000          ILOGM ADIR LE13 D,SH A,SS
7001          ARM BMINA D,L B,SH A,L
7002          ARM BMINA D,T B,B A,L
7003          CJMP ZERO L7070                   %-> 7070
7004          CJMP POS L7061                    %-> 7061
7005          ARM BMINA D,T B,L A,B
7006          LOGM ADIR D,SH A,A
7007          ARM BM1 D,A B,X
7010          ARM BM1 D,X B,SH
7011          ILOGM ADIR LE12 D,SH A,SS
7012          ILOGM ADIR LE13 A,SS
7013          ARM BM1 D,B B,AC
7014          ARM BM1 D,L B,SH
7015          ILOGM ADIR LE10 D,SH A,SCR
7016          ILOGM ADIR LE11 A,SCR
7017          ILOGM BDIR DSPL LE10 D,SCR B,AC
7020          ILOGM BDIR DSPL LE11 D,SCR B,SH
7021          ILOGM ADIR LE17 D,SH A,SCR
7022          ILOGM ADIR LE17 A,SS
7023          ILOGM BDIR DSPL LE17 D,SCR B,AC
7024          ILOGM BDIR DSPL LE17 D,SS B,SH
7025          IARM PLUS ADD1 DSPL LE13 D,SCR
7026  L7026,  ILOGM ADIR LE17 D,SCR A,SCR
7027          LOGM AND B,B17 A,SCR
7030          CJMP NZERO L7046                  %-> 7046
7031  L7031,  LOGM ADIR A,T
7032          CJMP ZERO L7504                   %-> 7504
7033          ARM BM1 B,MPC A,IO
7034          JMP L6706                         %-> 6706
7035          LOGM BDIR D,SCR B,B2
7036          ARM BMINA B,T A,SCR
7037          CJMP NEG L7474                    %-> 7474
7040          LOGM ADIR A,H
7041          CJMP NZERO L7714                  %-> 7714
7042          ARM BMINA D,T B,T A,SCR
7043          CJMP ZERO L7503                   %-> 7503
7044          ARM BMINA D,B B,B A,SCR
7045          JMP L7031                         %-> 7031
7046  L7046,  ARM BM1 B,MPC A,IO
7047          JMP L6706                         %-> 6706
7050          LOGM BDIR D,SCR B,B1
7051          ARM BMINA B,T A,SCR
7052          CJMP NEG L7705                    %-> 7705
7053          ARM BM1 D,SH B,B10
7054          LOGM AND B,SH A,H
7055          CJMP NZERO L7714                  %-> 7714
7056          ARM BMINA D,T B,T A,SCR
7057          ARM BMINA D,B B,B A,SCR
7060          JMP L7031                         %-> 7031
7061  L7061,  ARM BM1 D,X B,X
7062          ARM BM1 D,A B,A
7063          ILOGM ADIR LE12 D,SH A,SS
7064          ARM BM1 D,B B,SH
7065          ILOGM ADIR LE13 D,SH A,SS
7066          ARM BM1 D,L B,SH
7067          JMP L7026                         %-> 7026
7070  L7070,  ARM BM1 D,SH
7071          IARM PLUS LE12 D,B B,SH A,SS
7072          IARM PLUS LE13 D,L B,SH A,SS
7073          ARM BM1 D,A B,A
7074          ARM BM1 D,X B,X
7075          LOGM BDIR D,SH B,B17
7076          ILOGM AND LE17 B,SH A,SCR
7077          CJMP NZERO L7116                  %-> 7116
7100  L7100,  ILOGM AND LE17 B,SH A,SS
7101          CJMP NZERO L7155                  %-> 7155
7102  L7102,  ARM BM1 B,MPC A,IO
7103          JMP L6656                         %-> 6656
7104          LOGM BDIR D,SCR B,B2
7105          ARM BMINA D,B B,B A,SCR
7106          CJMP NEG L7300                    %-> 7300
7107          ARM BMINA D,L B,L A,SCR
7110          CJMP NEG L7277                    %-> 7277
7111          ARM BMINA B,D A,H
7112          CJMP NZERO L7114                  %-> 7114
7113          JMP L7102                         %-> 7102
7114  L7114,  CJMP POSM L7714                   %-> 7714
7115          JMP L7745                         %-> 7745
7116  L7116,  ILOGM AND LE17 B,SH A,SS
7117          CJMP NZERO L7140                  %-> 7140
7120          LOGM ADIR D,SCR A,A
7121          LOGM ADIR D,A A,X
7122          LOGM ADIR D,X A,SCR
7123          LOGM ADIR D,SCR A,B
7124          LOGM ADIR D,B A,L
7125          LOGM ADIR D,L A,SCR
7126          ILOGM ADIR LE10 D,SH A,SCR
7127          ILOGM ADIR LE11 A,SCR
7130          ILOGM BDIR DSPL LE10 D,SCR B,AC
7131          ILOGM BDIR DSPL LE11 D,SCR B,SH
7132          ILOGM ADIR LE17 D,SCR A,SCR
7133          ILOGM ADIR LE17 A,SS
7134          ILOGM BDIR DSPL LE17 D,SCR B,AC
7135          ILOGM ADIR DSPL LE17 D,SS A,SCR
7136          IARM BDI ADD1 DSPL LE13 D,SCR
7137          JMP L7155                         %-> 7155
7140  L7140,  ARM BM1 B,MPC A,IO
7141          JMP L6656                         %-> 6656
7142  L7142,  LOGM BDIR D,SCR B,B1
7143          ARM BMINA D,B B,B A,SCR
7144          CJMP NEG L7203                    %-> 7203
7145          ARM BMINA D,L B,L A,SCR
7146          CJMP NEG L7221                    %-> 7221
7147          ARM BM1 D,SH B,B10
7150          LOGM AND D,D B,SH A,D
7151          LOGM AND D,SCR B,SH A,H
7152          ARM BMINA B,D A,SCR
7153          CJMP NZERO L7114                  %-> 7114
7154          JMP L7102                         %-> 7102
7155  L7155,  ARM BM1 B,MPC A,IO
7156          JMP L6715                         %-> 6715
7157  L7157,  LOGM ADIR D,T A,H
7160          ARM BM1 B,L
7161          CJMP ZERO L7456                   %-> 7456
7162          ARM BM1 B,MPC A,IO
7163          JMP L6656                         %-> 6656
7164          LOGM BDIR D,SCR B,B2
7165          ARM BMINA D,B B,B A,SCR
7166          CJMP NEG L7371                    %-> 7371
7167          ARM BMINA D,L B,L A,SCR
7170          CJMP NEG L7442                    %-> 7442
7171          LOGL ADIR D,SH A,H
7172          LOGM ADIR D,SH A,T
7173          LOGM BDIR D,SC B,B3
7174          LOOP BM1 BM1A SH32 TSC0
7175          ARM BMINA B,SH A,D
7176          CJMP NZERO L7201                  %-> 7201
7177          LOGM ADIR D,T A,H
7200          JMP L7157                         %-> 7157
7201  L7201,  CJMP NEGM L7714                   %-> 7714
7202          JMP L7745                         %-> 7745
7203  L7203,  ARM BM1 D,SH B,B10
7204          ARM BM1 D,SCR B,B4
7205          LOGM ANDCA D,SH B,SH A,SCR
7206          LOGM AND D,D B,SH A,D
7207          LOGM AND D,SH B,SH A,H
7210          ARM BMINA B,SH A,D
7211          CJMP NZERO L7201                  %-> 7201
7212          ARM BM1 D,L B,L
7213          CJMP NZERO L7747                  %-> 7747
7214          LOGM ADIR D,SH A,H
7215          LOGM AND B,SH A,SCR
7216          CJMP NZERO L7745                  %-> 7745
7217          ARM BM1 D,L B,L
7220          JMP L7233                         %-> 7233
7221  L7221,  ARM BM1 D,SH B,B10
7222          ARM BM1 D,SCR B,B4
7223          LOGM ANDCA D,SH B,SH A,SCR
7224          LOGM AND D,T B,SH A,D
7225          LOGM AND D,SH B,SH A,H
7226          ARM BMINA B,SH A,T
7227          CJMP NZERO L7201                  %-> 7201
7230          LOGM AND B,D A,SCR
7231          CJMP NZERO L7714                  %-> 7714
7232          JMP L7255                         %-> 7255
7233  L7233,  ARM BM1 B,MPC A,IO
7234          JMP L6715                         %-> 6715
7235  L7235,  LOGM BDIR D,SCR B,B2
7236          ARM BMINA D,L B,L A,SCR
7237          CJMP NEG L7243                    %-> 7243
7240          LOGM ADIR A,H
7241          CJMP ZERO L7233                   %-> 7233
7242          JMP L7745                         %-> 7745
7243  L7243,  ARM PLUS ADD1 D,L A,L
7244          CJMP ZERO L7251                   %-> 7251
7245          ARM BM1 D,SH B,B14
7246          LOGM ANDCB B,SH A,H
7247          CJMP NZERO L7745                  %-> 7745
7250          JMP L7747                         %-> 7747
7251  L7251,  ARM BM1 D,SH B,B4
7252          LOGM ANDCB B,SH A,H
7253          CJMP NZERO L7745                  %-> 7745
7254          JMP L7747                         %-> 7747
7255  L7255,  ARM BM1 B,MPC A,IO
7256          JMP L6706                         %-> 6706
7257          LOGM BDIR D,SCR B,B2
7260          ARM BMINA D,B B,B A,SCR
7261          CJMP NEG L7265                    %-> 7265
7262          LOGM ADIR A,H
7263          CJMP ZERO L7255                   %-> 7255
7264          JMP L7714                         %-> 7714
7265  L7265,  ARM PLUS ADD1 D,B A,B
7266          CJMP ZERO L7273                   %-> 7273
7267          ARM BM1 D,SH B,B14
7270          LOGM ANDCB B,SH A,H
7271          CJMP NZERO L7714                  %-> 7714
7272          JMP L7747                         %-> 7747
7273  L7273,  ARM BM1 D,SH B,B4
7274          LOGM ANDCB B,SH A,H
7275          CJMP NZERO L7714                  %-> 7714
7276          JMP L7747                         %-> 7747
7277  L7277,  ARM PLUS D,B B,B2 A,B
7300  L7300,  ARM PLUS D,B B,B2 A,B
7301          ARM BMINA B,B A,L
7302          CJMP POS L7327                    %-> 7327
7303          LOGM ADIR D,SCR A,B
7304          LOGM ADIR D,B A,L
7305          LOGM ADIR D,L A,SCR
7306          LOGM ADIR D,T A,D
7307          LOGM ADIR D,D A,H
7310          LOGM ADIR D,SCR A,A
7311          LOGM ADIR D,A A,X
7312          LOGM ADIR D,X A,SCR
7313          ILOGM ADIR LE10 D,SH A,SCR
7314          ILOGM ADIR LE11 A,SCR
7315          ILOGM BDIR DSPL LE10 D,SCR B,AC
7316          ILOGM BDIR DSPL LE11 D,SCR B,SH
7317          ILOGM ADIR LE17 D,SCR A,SCR
7320          ILOGM ADIR LE17 A,SS
7321          ILOGM BDIR DSPL LE17 D,SCR B,AC
7322          ILOGM ADIR DSPL LE17 D,SS A,SCR
7323          LOGM BDIR D,SH B,B0
7324          ILOGM ADIR LE13 D,SCR A,SCR
7325          ILOGM EXOR DSPL LE13 D,SCR B,SH A,SCR
7326          JMP L7330                         %-> 7330
7327  L7327,  LOGM ADIR D,T A,H
7330  L7330,  ARM BDI ADD1 D,SCR B,B1
7331          ARM BMINA B,L A,SCR
7332          CJMP ZERO L7356                   %-> 7356
7333          ARM BM1 D,SCR B,B14
7334          LOGM ANDCA D,SH B,D A,SCR
7335          LOGM ANDCA D,T B,T A,SCR
7336          ARM BMINA B,SH A,T
7337          CJMP NZERO L7114                  %-> 7114
7340  L7340,  ARM BM1 D,B B,B
7341          CJMP ZERO L7747                   %-> 7747
7342          LOGM BDIR D,T B,B1
7343          ARM BMINA D,B B,B A,T
7344          CJMP ZERO L7351                   %-> 7351
7345          LOGM AND B,D A,SCR
7346          CJMP NZERO L7714                  %-> 7714
7347          ARM BM1 D,B B,B
7350          JMP L7255                         %-> 7255
7351  L7351,  ARM BM1 D,SH B,B4
7352          LOGM ANDCB D,SCR B,SH A,SCR
7353          LOGM AND B,D A,SCR
7354          CJMP NZERO L7714                  %-> 7714
7355          JMP L7747                         %-> 7747
7356  L7356,  ARM BM1 D,SCR B,B4
7357          LOGM ANDCA D,SH B,D A,SCR
7360          LOGM ANDCA D,T B,T A,SCR
7361          ARM BMINA B,SH A,T
7362          CJMP NZERO L7114                  %-> 7114
7363          ARM PLUS ADD1 D,T B,B1
7364          ARM BMINA D,B B,B A,T
7365          CJMP ZERO L7747                   %-> 7747
7366          LOGM AND B,D A,SCR
7367          CJMP NZERO L7714                  %-> 7714
7370          JMP L7255                         %-> 7255
7371  L7371,  ARM PLUS ADD1 D,B B,B1 A,B
7372          CJMP ZERO L7425                   %-> 7425
7373          ARM BM1 D,SCR B,B4
7374          LOGM ANDCA D,D B,D A,SCR
7375          LOGM ADIR D,SH A,T
7376          LOGL ADIR D,SH A,H
7377          LOGM BDIR D,SC B,B3
7400          LOOP BM1 BM1A SH32 TSC0
7401          LOGM ANDCA D,T B,SH A,SCR
7402          ARM BMINA B,D A,T
7403          CJMP NZERO L7114                  %-> 7114
7404          LOGM ADIR D,T A,H
7405          ARM BM1 D,SCR B,B2
7406          ARM BMINA D,L B,L A,SCR
7407          CJMP ZERO L7747                   %-> 7747
7410          ARM BM1 D,SCR B,B14
7411          LOGM BDIR D,SCR B,B1
7412          ARM BMINA D,L B,L A,SCR
7413          CJMP ZERO L7420                   %-> 7420
7414          LOGM AND B,T A,SCR
7415          CJMP NZERO L7745                  %-> 7745
7416          ARM BM1 D,L B,L
7417          JMP L7233                         %-> 7233
7420  L7420,  ARM BM1 D,SH B,B4
7421          LOGM ANDCB D,SCR B,SH A,SCR
7422          LOGM AND B,T A,SCR
7423          CJMP NZERO L7745                  %-> 7745
7424          JMP L7747                         %-> 7747
7425  L7425,  LOGM ADIR D,SH A,T
7426          LOGM BDIR D,SC B,B3
7427          LOOP BM1 BM1A TSC0
7430          ARM BM1 D,SCR B,B14
7431          LOGM ANDCA D,SH B,SH A,SCR
7432          LOGM ANDCA D,D B,D A,SCR
7433          ARM BMINA B,SH A,D
7434          CJMP NZERO L7201                  %-> 7201
7435          ARM BM1 D,L B,L
7436          ARM BM1 D,SCR B,B4
7437          LOGM AND B,T A,SCR
7440          CJMP NZERO L7745                  %-> 7745
7441          JMP L7235                         %-> 7235
7442  L7442,  LOGM ADIR D,SH A,T
7443          LOGL ADIR D,SH A,H
7444          LOGM BDIR D,SC B,B3
7445          LOOP BM1 BM1A SH32 TSC0
7446          ARM BM1 D,SCR B,B4
7447          LOGM ANDCA D,SH B,SH A,SCR
7450          LOGM ANDCA D,T B,D A,SCR
7451          ARM BMINA B,SH A,T
7452          CJMP NZERO L7201                  %-> 7201
7453          LOGM AND B,D A,SCR
7454          CJMP NZERO L7714                  %-> 7714
7455          JMP L7255                         %-> 7255
7456  L7456,  LOGM ADIR D,SH A,T
7457          LOGM BDIR D,SC B,B3
7460          LOOP BM1 BM1A TSC0
7461          ARM BM1 D,SCR B,B14
7462          LOGM ANDCA D,SH B,SH A,SCR
7463          LOGM ANDCA D,L B,D A,SCR
7464          ARM BM1 B,MPC A,IO
7465          JMP L6706                         %-> 6706
7466          LOGM ADIR D,D A,H
7467          ARM BM1 D,SCR B,B14
7470          LOGM ANDCA D,L B,D A,SCR
7471          ARM BMINA B,SH A,L
7472          CJMP NZERO L7201                  %-> 7201
7473          JMP L7340                         %-> 7340
7474  L7474,  LOGM BDIR D,SCR B,B1
7475          LOGM ADIR D,D A,H
7476          ARM BMINA B,T A,SCR
7477          CJMP ZERO L7506                   %-> 7506
7500          ARM BM1 B,T
7501          CJMP ZERO L7531                   %-> 7531
7502          JMP L7670                         %-> 7670
7503  L7503,  ARM BMINA D,B B,B A,SCR
7504  L7504,  LOGM BDIR D,SH B,B17
7505          JMP L7100                         %-> 7100
7506  L7506,  ARM BM1 D,SH B,B10
7507          LOGM ANDCB B,SH A,H
7510          CJMP NZERO L7714                  %-> 7714
7511          ARM BM1 D,B B,B
7512          ARM BM1 D,B B,B
7513          LOGM BDIR D,SH B,B17
7514          ILOGM AND LE17 B,SH A,SS
7515          CJMP NZERO L7526                  %-> 7526
7516          LOGM ADIR D,SH A,H
7517          LOGM BDIR D,SC B,B3
7520          LOOP BM1 BM1A TSC0
7521          LOGM BDIR D,D B,SH
7522          IARM BDI ADD1 DSPL LE12 D,SS B,B
7523          IARM BDI ADD1 DSPL LE13 D,SS B,L
7524          ARM PLUS ADD1 D,B B,B1
7525          JMP L7547                         %-> 7547
7526  L7526,  ARM BM1 B,MPC A,IO
7527          JMP L6715                         %-> 6715
7530          JMP L7142                         %-> 7142
7531  L7531,  ARM BM1 D,SCR B,B14
7532          LOGM ANDCA B,D A,SCR
7533          CJMP NZERO L7714                  %-> 7714
7534          ARM BM1 D,B B,B
7535          IARM BDI ADD1 DSPL LE12 D,SS B,B
7536          LOGM BDIR D,B B,B2
7537          IARM BDI ADD1 DSPL LE13 D,SS B,L
7540          LOGM ADIR D,SH A,D
7541          LOGM BDIR D,SC B,B2
7542          LOOP BM1 BM1A TSC0
7543          LOGM BDIR D,D B,SH
7544  L7544,  LOGM BDIR D,SH B,B17
7545          ILOGM AND LE17 B,SH A,SS
7546          CJMP NZERO L7660                  %-> 7660
7547  L7547,  ARM BM1 B,MPC A,IO
7550          JMP L6715                         %-> 6715
7551          LOGM ADIR D,T A,H
7552          ARM BDI ADD1 D,L B,B2
7553  L7553,  ARM BM1 D,SS B,B14
7554  L7554,  ILOGM ADIR LE12 A,SS
7555          IARM BM1 DSPL LE12 D,SS B,AC
7556          CJMP ZERO L7616                   %-> 7616
7557          ARM BM1 D,B B,B
7560          CJMP ZERO L7604                   %-> 7604
7561  L7561,  ILOGM ADIR LE13 A,SS
7562          IARM BM1 DSPL LE13 D,SS B,AC
7563          CJMP ZERO L7632                   %-> 7632
7564          ARM BM1 D,L B,L
7565          CJMP ZERO L7611                   %-> 7611
7566  L7566,  LOGM ANDCA D,SH B,D A,SS
7567          CJMP NZERO L7602                  %-> 7602
7570  L7570,  LOGM ANDCA D,SCR B,T A,SS
7571          ARM BMINA B,SH A,SCR
7572          CJMP NZERO L7114                  %-> 7114
7573          LOGM BDIR D,SC B,B2
7574          LOGL ADIR D,SH A,T
7575          LOGM ADIR D,SH A,D
7576          LOOP BM1 BM1A SH32 TSC0
7577          LOGL BDIR D,T B,SH
7600          LOGM BDIR D,D B,SH
7601          JMP L7554                         %-> 7554
7602  L7602,  IARM BDI ADD1 DSPL LE15 D,SCR
7603          JMP L7570                         %-> 7570
7604  L7604,  ARM BM1 B,MPC A,IO
7605          JMP L6706                         %-> 6706
7606          LOGM ADIR D,D A,H
7607          LOGM BDIR D,B B,B2
7610          JMP L7561                         %-> 7561
7611  L7611,  ARM BM1 B,MPC A,IO
7612          JMP L6715                         %-> 6715
7613          LOGM ADIR D,T A,H
7614          LOGM BDIR D,L B,B2
7615          JMP L7566                         %-> 7566
7616  L7616,  ILOGM ADIR LE13 A,SS
7617          IARM BM1 DSPL LE13 D,SS B,AC
7620          CJMP ZERO L7747                   %-> 7747
7621          ARM BM1 D,L B,L
7622          CJMP ZERO L7646                   %-> 7646
7623  L7623,  LOGM ANDCA B,T A,SS
7624          CJMP NZERO L7745                  %-> 7745
7625          LOGM BDIR D,SH B,T
7626          LOGM BDIR D,SC B,B2
7627          LOOP BM1 BM1A TSC0
7630          LOGM BDIR D,T B,SH
7631          JMP L7616                         %-> 7616
7632  L7632,  LOGM ANDCA B,D A,SS
7633          CJMP NZERO L7714                  %-> 7714
7634          LOGM BDIR D,SC B,B2
7635          LOGM ADIR D,SH A,D
7636          LOOP BM1 BM1A TSC0
7637          LOGM BDIR D,D B,SH
7640          ILOGM ADIR LE12 A,SS
7641          IARM BM1 DSPL LE12 D,SS B,AC
7642          CJMP ZERO L7747                   %-> 7747
7643          ARM BM1 D,B B,B
7644          CJMP ZERO L7653                   %-> 7653
7645          JMP L7632                         %-> 7632
7646  L7646,  ARM BM1 B,MPC A,IO
7647          JMP L6715                         %-> 6715
7650          LOGM ADIR D,T A,H
7651          LOGM BDIR D,L B,B2
7652          JMP L7623                         %-> 7623
7653  L7653,  ARM BM1 B,MPC A,IO
7654          JMP L6706                         %-> 6706
7655          LOGM ADIR D,D A,H
7656          LOGM BDIR D,B B,B2
7657          JMP L7632                         %-> 7632
7660  L7660,  ARM BM1 B,MPC A,IO
7661          JMP L6715                         %-> 6715
7662          LOGM ADIR D,SH A,H
7663          LOGM BDIR D,SC B,B3
7664          LOOP BM1 BM1A TSC0
7665          LOGM BDIR D,T B,SH
7666          ARM BDI ADD1 D,L B,B1
7667          JMP L7553                         %-> 7553
7670  L7670,  LOGM ANDCA B,D A,SS
7671          CJMP NZERO L7714                  %-> 7714
7672          ARM BDI ADD1 D,SCR B,B1
7673          ARM BMINA D,B B,B A,SCR
7674  L7674,  IARM BDI ADD1 DSPL LE12 D,SS B,B
7675          LOGM BDIR D,B B,B1
7676          IARM BDI ADD1 DSPL LE13 D,SS B,L
7677          LOGM ADIR D,SH A,D
7700          LOGM BDIR D,SC B,B2
7701          LOOP BM1 BM1A SHR SH32 TSC0
7702          LOGL BDIR D,T B,SH
7703          LOGM ADIR D,D A,T
7704          JMP L7544                         %-> 7544
7705  L7705,  ARM BM1 D,SH B,B10
7706          LOGM AND D,D B,SH A,H
7707          ARM BM1 D,SS B,B4
7710          LOGM ANDCA B,D A,SS
7711          CJMP NZERO L7714                  %-> 7714
7712          ARM BM1 D,B B,B
7713          JMP L7674                         %-> 7674
7714  L7714,  ARM BDI ADD1 D,A
7715  L7715,  ILOGM ADIR LE13 D,SCR A,SCR
7716          LOGM AND B,B0 A,SCR
7717          CJMP NZERO L7751                  %-> 7751
7720          ILOGM ADIR LE17 D,D A,SCR
7721          ILOGM ADIR LE17 D,T A,SS
7722  L7722,  ILOGM ADIR LE11 D,X A,SS
7723          ILOGM ADIR LE16 D,B A,SS
7724          ILOGM ADIR LE16 D,L A,SCR
7725          ILOGM ADIR LE12 D,SH A,SCR
7726          ILOGM EXOR LE13 D,SCR B,SH A,SCR
7727          LOGM AND B,B0 A,SCR
7730          CJMP NZERO L7757                  %-> 7757
7731  L7731,  ILOGM ADIR LE14 A,SCR
7732          CJMP ZERO L7741                   %-> 7741
7733          LOGM ADIR A,A
7734          CJMP ZERO L7742                   %-> 7742
7735  L7735,  ARM BDI ADD1 D,A
7736          ILOGM ADIR LE12 D,SCR A,SCR
7737          LOGM AND B,B0 A,SCR
7740          CARM BM1 NZERO D,A
7741  L7741,  IARM PLUS ADD1 CFC LE10 D,P A,SS
7742  L7742,  ILOGM ADIR LE15 A,SCR
7743          CJMP NZERO L7735                  %-> 7735
7744          JMP L7741                         %-> 7741
7745  L7745,  ARM BM1 D,A
7746          JMP L7715                         %-> 7715
7747  L7747,  LOGM ADIR D,A
7750          JMP L7715                         %-> 7715
7751  L7751,  ILOGM ADIR LE17 D,T A,SCR
7752          ILOGM ADIR LE17 D,D A,SS
7753          JMP L7722                         %-> 7722
7754  L7754,  LOGM BDIR D,T B,B0
7755          IARM BDI ADD1 DSPL LE14 D,SCR
7756          JMP L7061                         %-> 7061
7757  L7757,  LOGM ADIR A,A
7760          CJMP ZERO L7731                   %-> 7731
7761          ARM BM1 B,A
7762          CJMP ZERO L7765                   %-> 7765
7763          LOGM BDIR D,A B,B0
7764          JMP L7731                         %-> 7731
7765  L7765,  ARM BM1 D,A
7766          JMP L7731                         %-> 7731
7767          IARM BM1 ADDC DSPL LE14 D,S B,B A,B
7770          LOOP 4000000000 ANDCA BM1A SHR SHRO 4000 B,B 4 ASH0
7771          LOOP 4000000000 ANDCB 100000000 4000 TGSH0 4 ASH0
7772          JMP ,CAR 1014000000 50000 4404
7773          LOOP BM1 ADDC PLUSA SHR 60000 SH32 2000 TGAC0 4 ENDID ASH0
7774          CARM 2000000000 CHLEV POSM D,S B,A A,SCR
7775          CJMP ,CAR PRIV 1020000000 NZERO 4167
7776          IARL BMINA CR DSPL LE13 D,S B,ALD A,IO
7777          LOOP BMAM1 ADDC 20000000 SHR SHRO SH32 4000 B,L TSH31 ENDID

// +build amd64,!appengine

#define ROUND(v0, v1, v2, v3) \
	ADDQ v1, v0; \
	RORQ $51, v1; \
	ADDQ v3, v2; \
	RORQ $48, v3; \
	XORQ v0, v1; \
	RORQ $32, v0; \
	XORQ v2, v3; \
	ADDQ v1, v2; \
	ADDQ v3, v0; \
	RORQ $43, v3; \
	RORQ $47, v1; \
	XORQ v0, v3; \
	XORQ v2, v1; \
	RORQ $32, v2

// func Hash128(k0, k1 uint64, b []byte) (r0 uint64, r1 uint64)
TEXT	·Hash128(SB),4,$0-56
	MOVQ	k0+0(FP),AX
	MOVQ	k1+8(FP),BX

	MOVQ	b_base+16(FP),SI
	MOVQ	b_len+24(FP),CX

	MOVQ	$0x736F6D6570736575,R9
	MOVQ	$0x646F72616E646F6D,R10
	MOVQ	$0x6C7967656E657261,R11
	MOVQ	$0x7465646279746573,R12

	XORQ	AX,R9		// v0 := k0 ^ 0x736f6d6570736575
	XORQ	BX,R10		// v1 := k1 ^ 0x646f72616e646f6d
	XORQ	AX,R11		// v2 := k0 ^ 0x6c7967656e657261
	XORQ	BX,R12		// v3 := k1 ^ 0x7465646279746573

	MOVQ	CX,BX
	SHLQ	$56,BX		// t := len(p) << 56

        XORB    $0xee,R10        // v1 ^= 0xee
	JMP	cmp

body:
	MOVQ	(SI),DX		// m := *(*uint64)&p[0]
	LEAQ	8(SI),SI	// p = p[BlockSize:]

	XORQ    DX,R12		// v3 ^= m
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)
	XORQ	DX,R9		// v0 ^= m
cmp:
	SUBQ	$8,CX
	JGE	body		// for len(p) >= BlockSize

	TESTB	$7,CL		// if len(p) % BlockSize == 0
	JZ	nocompress

	// compress last block
	MOVQ	(SI)(CX*1),DX   // off := (len(p) % BlockSize) - BlockSize
	LEAQ	(CX*8),CX	// shift := -(8 * off)
	NEGB	CL
	SHRQ	CL,DX
	ORQ	DX,BX		// t |= *(*uint64)&p[off] >> shift

nocompress:
	XORQ    BX,R12		// v3 ^= t
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)
	XORQ	BX,R9		// v0 ^= t

	// finalization
	XORB	$0xee,R11	// v2 ^= 0xff
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)

        MOVQ    R9,AX
        XORQ    R10,AX
        XORQ    R11,AX
        XORQ    R12,AX
        MOVQ    AX,ret+40(FP)	// r0 = v0 ^ v1 ^ v2 ^ v3

        XORB    $0xdd,R10       // v1 ^= 0xdd
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)
	ROUND(R9,R10,R11,R12)

	XORQ	R10,R9
	XORQ	R12,R11
	XORQ	R11,R9

	MOVQ	R9,unnamed+48(FP) // r1 = v0 ^ v1 ^ v2 ^ v3
	RET

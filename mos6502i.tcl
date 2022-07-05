oo::class create MOS6502 {
    variable IR AD 
    variable A X Y SP PC P
    variable mem
    variable MOS6502_NF MOS6502_VF MOS6502_XF MOS6502_BF 
    variable MOS6502_DF MOS6502_IF MOS6502_ZF MOS6502_CF
    variable cycles
    variable ops

    constructor {m} {
        set mem $m
        set IR 0; set AD 0
        set A 0; set X 0; set Y 0; set SP 0; set PC 0; set P 0
        set ops {
            {
                {{$A____ $M___}{$A_JSR $M_R_}{$A____ $M_R_},{$A____ $M_R_}{$A_IMM $M_R_}{$A_IMM $M_R_}{$A_IMM $M_R_}{$A_IMM $M_R_}}
            }
        }

        set MOS6502_NF 0x80; set MOS6502_VF 0x40; set MOS6502_XF 0x20; set MOS6502_BF 0x10 
        set MOS6502_DF 0x08; set MOS6502_IF 0x04; set MOS6502_ZF 0x02; set MOS6502_CF 0x01

        set cycles 0
    }

    method _NZ {val} { set P [expr ($P & ~($MOS6502_NF|$MOS6502_ZF)) | ($val & 0xFF ? ($val & $MOS6502_NF) : $MOS6502_ZF)]; return P }

    method ASL {val} {
        set P [expr {([_NZ [expr {$val << 1}]] & ~$MOS6502_CF) | (($val & 0x80) ? $MOS6502_CF : 0)}]
        return [expr val << 1]
    }

    method PUSH {byte} { incr $SP -1; $mem set [expr {0x100 | $SP}] $byte }

    method HI {word} { return [expr {($word >> 8) & 0xFF}] }
    method LO {word} { return [expr {$word & 0xFF}] }
    method ADDR {hi lo} { return [expr {($hi << 8) & $lo}] }

    method CYCLES {num} { incr cycles $num }

    method FlagString {} {
        return [format "%s%s%s%s%s%s%s%s" \
            [expr {($P & $MOS6502_NF) != 0 ? "N" : "n"}] \
            [expr {($P & $MOS6502_VF) != 0 ? "V" : "v"}] \
            [expr {($P & $MOS6502_XF) != 0 ? "X" : "x"}] \
            [expr {($P & $MOS6502_BF) != 0 ? "B" : "b"}] \
            [expr {($P & $MOS6502_DF) != 0 ? "D" : "d"}] \
            [expr {($P & $MOS6502_IF) != 0 ? "I" : "i"}] \
            [expr {($P & $MOS6502_ZF) != 0 ? "Z" : "z"}] \
            [expr {($P & $MOS6502_CF) != 0 ? "C" : "c"}]]
    }

    method reset {} {
        set PC [$mem get 0xFFFC]
        set PC [expr {$PC | ([$mem get 0xFFFD] << 8)}]
    }

    method debugPrint {} {
        puts {PC   IR A  X  Y  SP P  Flags}
        puts [format {%04X %02X %02X %02X %02X %02X %02X %s} $PC $IR $A $X $Y $SP $P [my FlagString]]
    }

    method FETCH {} {
        incr PC
    }

    method nextInstruction {} {

        set IR [$mem get $PC]
        
        switch [format %02X $IR] {
            # BRK              1b 7c
            00 { my CYCLES 7 }

            # ORA (indirect,X) 2b 6c
            01 { 
                incr PC
                set AD [$mem get $PC]
                incr AD $X
                set AD [expr {[$mem get $AD] | ([$mem get [expr {$AD + 1}]] << 8)}]
                set A [expr {$A | $AD}]
                my _NZ $A
                my FETCH
                my CYCLES 6
            }

            # ORA zeropage     2b 3c
            05 {
                incr PC
                set A [expr {$A | [$mem get [$mem get $PC]]}]
                my _NZ $A
                my FETCH
                my CYCLES 3
            }

            # ASL zeropage     2b 5c
            06 {
                incr PC
                set AD [$mem get $PC]
                set tmp [$mem get $AD]
                [$mem set $AD [my ASL $tmp]]
                my FETCH
                my CYCLES 5
            }

            # PHP              1b 3c
            08 { incr SP -1; [$mem set [expr {0x0100 | $SP}] [expr {$MOS6502_XF | $P}]]; my FETCH; my CYCLES 3 }

            # ORA immediate    2b 2c
            09 { incr PC; set A [expr {$A | [$mem get $PC]}]; my _NZ $A; my FETCH; my CYCLES 2 }

            # ASL implied      1b 2c
            0A { set A [my ASL $A]; my FETCH; my CYCLES 2 }

            # ORA absolute     3b 4c
            0D { 
                incr PC
                set AD [$mem get $PC]
                incr PC
                set AD [expr {$AD | ([$mem get $PC] << 8)}]
                set A [expr $A | [$mem get $AD]]
                my _NZ $A 
                my FETCH
                my CYCLES 4
            }

            # ASL absolute     3b 6c
            0E { 
                incr PC
                set AD [$mem get $PC]
                incr PC 
                set AD [expr {$AD | ([$mem get $PC] << 8)}]
                set tmp [$mem get $AD]
                [$mem set $AD [my ASL $tmp]]
                my FETCH
                my CYCLES 6
            }

            # BPL              2b 2c**
            10 {
                incr PC
                set AD [expr {$PC + [$mem get $PC]}]
                if {($P & $MOS6502_NF) != 0} { break }
                set PC $AD
                my FETCH
                my CYCLES 2 ;# fixme
            }

            # ORA (indirect),Y 2b 5c*
            11 { 
                incr PC
                set AD [$mem get $PC]
                set AD [expr {[$mem get $AD] | ([$mem get [expr {($AD + 1) & 0xFF}]] << 8)}]
                set IR [expr {$IR + (~(($AD >> 8) - (($AD + $Y) >> 8))) & 1}]
                set A [expr {$A | [$mem get [expr {$AD + $Y}]]}]
                my _NZ $A
                my FETCH
                my CYCLES 5 ;# fixme
            }

            # ORA zeropage,X   2b 4c
            15 {
                incr PC
                set AD [expr {[$mem get $PC] | $X}]
                set A [expr {$A | $AD}]
                my _NZ $A
                my FETCH
                my CYCLES 4
            }

            # ASL zeropage,X   2b 6c
            16 {
                incr PC
                set AD [expr {([$mem get ([$mem get $PC] + $X)]) & 0xFF}]
                set tmp [$mem get $AD]
                $mem set $AD [my ASL $tmp]
                my FETCH
                my CYCLES 6
            }

            # CLC implied      1b 2c
            18 { set $P [expr {$P & ~($MOS6502_CF)}]; my FETCH; my CYCLES 2 }

            # ORA absolute,Y   3b 4c*
            19 { 
                incr PC; set BAL [$mem get $PC]
                incr PC; set BAH [$mem get $PC]
                set ADL [expr {($BAL + $Y) & 0xFF}]
                set ADH [expr {$BAH + ((($BAL & 0x80) & ($Y & 0x80)) ? 1 : 0)}]
                set AD [my ADDR $ADH $ADL]
                set A [expr {$A | [$mem get $AD]}]
                my _NZ $A
                my FETCH
                my CYCLES 4
            }

            # ORA absolute,X   3b 4c*
            1D {
                incr PC; set BAL [$mem get $PC]
                incr PC; set BAH [$mem get $PC]
                set ADL [expr {($BAL + $X) & 0xFF}]
                set ADH [expr {$BAH + ((($BAL & 0x80) & ($X & 0x80)) ? 1 : 0)}]
                set AD [my ADDR $ADH $ADL]
                set A [expr {$A | [$mem get $AD]}]
                my _NZ $A
                my FETCH
                my CYCLES 4 ;# fixme
            }

            # ASL absolute,X   3b 7c
            1E {
                incr PC; set BAL [$mem get $PC]
                incr PC; set BAH [$mem get $PC]
                set ADL [expr {$BAL + $X) & 0xFF}]
                set ADH [expr {$BAH + ((($BAL & 0x80) & ($X & 0x80)) ? 1 : 0)}]
                set AD [my ADDR $ADH $ADL]
                set tmp [$mem get $AD]
                $mem set $AD [my ASL $tmp]
                my FETCH
                my CYCLES 7
            }

            # JSR absolute     3b 6c
            20 {
                incr PC; set ADL [$mem get $PC]
                my PUSH [my HI $PC] 
                my PUSH [my LO $PC]
                incr PC; set ADH [$mem get $PC]
                set PC [my ADDR $ADH $ADL]
                my CYCLES 6
            }

            # AND (indirect,X) 2b 6c
            21 {
                incr PC; set BAL [$mem get $PC]
                set ADL [$mem get [expr {$BAL + $X}]]
                set ADH [$mem get [expr {$BAL + $X + 1}]]
                set tmp [$mem get [my ADDR $ADH $ADL]]
                set A [expr {$A & $tmp}]; my _NZ $A
                my FETCH
                my CYCLES 6
            }

            # BIT zeropage     2b 3c
            24 {
                incr PC; set ADL [$mem get $PC]
                set tmp [$mem get $ADL]
                set tmp [expr {$A & $tmp}]
                set P [expr {($P & ~($MOS6502_NF|$MOS6502_VF)) | ($tmp & ($MOS6502_NF|$MOS6502_VF))}]
                if {!$tmp} { set P [expr {($P | $MOS6502_ZF)}] }
                my FETCH
                my CYCLES 3
            }

            # AND zeropage     2b 3c
            25 {
                incr PC; set ADL [$mem get $PC]
                set tmp [$mem get $ADL]
                my FETCH
                my CYCLES 3
            }

            # NOP
            EA { my FETCH }

            4C { incr PC; set PC [expr {[$mem get $PC] | [$mem get [expr {$PC + 1}]]}] }

            default { throw {BAD_OPCODE} {Unknown opcode [format "%02X tick #%d" $IR $tick]} }
        }
    }
}
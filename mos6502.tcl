variable MOS6502_NF 0x80 MOS6502_VF 0x40 MOS6502_XF 0x20 MOS6502_BF 0x10 
variable MOS6502_DF 0x08 MOS6502_IF 0x04 MOS6502_ZF 0x02 MOS6502_CF 0x01

oo::class create MOS6502 {
    variable IR tick AD 
    variable A X Y SP PC P
    variable PINS ;# DATA ADDR SYNC RDWR RDY IRQ_ NMI_ SO RST_

    constructor {} {

    }

    method _ON {pin} { set PINS($pin) 1 }
    method _OFF {pin} { set PINS($pin) 0 }
    method _WR {} { _ON(RDWR) }
    method _RD {} { _OFF(RDWR) }
    method _SA {addr} { set PINS(ADDR) $addr }
    method _GA {} { return $PINS(ADDR) }
    method _SD {data} { set PINS(DATA) $data }
    method _GD {} { return $PINS(ADDR) }
    method _FETCH {} { _SA($PC) set PINS(SYNC) 1 }
    method _NZ {val} { set P [expr ($P & ~($MOS6502_NF|$MOS6502_ZF)) | ($val & 0xFF ? ($val & $MOS6502_NF) : $MOS6502_ZF)]; return P }

    method ASL {val} {
        set P [expr ((_NZ [expr $val << 1]) & ~$MOS6502_CF) | (($val & 0x80) ? $MOS6502_CF : 0)]
        return [expr val << 1]
    }

    method tick {pins} {

        if {$PINS(SYNC)} {
            set IR $PINS(DATA)
            set tick 0
            set PINS(SYNC) 0
            incr PC
        }

        _RD
        switch [format %02X.%d $IR $tick] {
            # BRK              1b 7c
            00.0 { puts "BRK.0" }
            00.1 { puts "BRK.1" }
            00.2 { puts "BRK.2" }
            00.3 { puts "BRK.3" }
            00.4 { puts "BRK.4" }
            00.5 { puts "BRK.5" }
            00.6 { puts "BRK.6" }

            # ORA (indirect,X) 2b 6c
            01.0 { incr PC; _SA $PC }
            01.1 { set AD _GD; _SA $AD }
            01.2 { incr AD $X; _SA $AD }
            01.3 { _SA [expr $AD + 1]; set AD _GD }
            01.4 { _SA [expr $AD | (_GD << 8)] }
            01.5 { set A [expr $A | _GD]; _NZ $A; _FETCH }

            # ORA zeropage   2b 3c
            05.0 { incr PC; _SA $PC }
            05.1 { _SA _GD }
            05.2 { set A [expr $A | _GD]; _NZ $A; _FETCH }

            # ASL zeropage   2b 5c
            06.0 { incr PC; _SA $PC }
            06.1 { _SA _GD }
            06.2 { set AD _GD; _WR }
            06.3 { _SD (ASL $AD); _WR }
            06.4 { _FETCH }

            # PHP              1b 3c
            08.0 { _SA $PC }
            08.1 { incr SP -1; _SA [expr 0x0100 | $SP]; _SD [expr $MOS6502_XF | $P]; _WR }
            08.2 { _FETCH }

            # ORA immediate  2b 2c
            09.0 { incr PC; _SA $PC }
            09.1 { set A [expr $A | _GD]; _NZ $A; _FETCH } 

            # ASL implied    1b 2c
            0A.0 { _SA $PC }
            0A.1 { set A [ASL $A]; _FETCH }

            # ORA absolute   3b 4c
            0D.0 { incr PC; _SA $PC }
            0D.1 { set AD _GD; incr PC; _SA $PC }
            0D.2 { _SA [expr $AD | (_GD << 8)] }
            0D.3 { set A [expr $A | _GD]; _NZ $A; _FETCH }

            # ASL absolute   3b 6c
            0E.0 { incr PC; _SA $PC }
            0E.1 { set AD _GD; incr PC; _SA $PC }
            0E.2 { _SA [expr $AD | (_GD << 8)] }
            0E.3 { set AD _GD; _WR }
            0E.4 { _SD (ASL $AD); _WR }
            0E.5 { _FETCH } 

            # BPL              2b 2c**
            10.0 { incr PC; _SA $PC }
            10.1 { _SA $PC; set AD [expr $PC + _GD]; if {($P & 0x80) != 0} { _FETCH } }
            10.2 { 
                _SA [expr $PC | ($AD & 0x00FF)]
                if {($AD & 0xFF00) == ($PC & 0xFF00)} { 
                    set PC $AD
                    set irq_pip [expr irq_pip >> 1]
                    set nmi_pip [expr nmi_pip >> 1]
                    _FETCH
                } 
            }
            10.3 { set PC $AD; _FETCH }

            # ORA (indirect),Y 2b 5c*
            11.1 { incr $PC; _SA $PC }
            11.2 { set AD _GD; _SA $AD }
            11.3 { _SA [expr ($AD + 1) & 0xFF]; set AD _GD}
            11.4 { 
                set AD [expr $AD | (_GD << 8)] 
                _SA [expr ($AD & 0xFF00) | (($AD + $Y) & 0xFF)]
                set IR [expr IR + ]}
            11.5

            # NOP
            EA.1 { _SA $PC }
            EA.2 { _FETCH }

            default { throw {BAD_OPCODE} {Unknown opcode [format "%02X tick #%d" $IR $tick]} }
        }

        incr $tick

        return $PINS
    }
}
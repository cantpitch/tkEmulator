source gen_memory.tcl
source mos6502i.tcl

set mem [Memory new 65536]
set cpu [MOS6502 new $mem]

$cpu reset

set program { 0xEA 0xEA 0xEA 0xEA 0xEA 0xEA 0x4C 0x00 0x00 }
$mem setRange 0x0000 $program

for {set i 0} {$i < [llength $program]} {incr i} {

    $cpu nextInstruction
    $cpu debugPrint
}

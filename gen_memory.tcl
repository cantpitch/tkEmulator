oo::class create Memory {
    variable data

    constructor {size} {
        for {set i 0} {$i < $size} {incr i} {
            set data($i) 0 
        }
    }

    method get {addr} {
        return $data([expr {int($addr)}])
    }

    method set {addr byte} {
        set data([expr {int($addr)}]) [expr {$byte & 0xFF}]
    }

    method setRange {addr byteList} {
        set i 0
        foreach x $byteList {
            my set [expr {$addr + $i}] $x
            incr i
        }
    }
}

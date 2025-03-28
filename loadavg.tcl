#! /bin/sh
# \
exec tclsh "$0" ${1+"$@"}

source [file join [file dirname [file normalize [info script]]] wapp.tcl]
set docRoot [file join [file dirname [file normalize [info script]]] public_html]


proc wapp-default {} {
    variable docRoot
    wapp-content-security-policy {default_src 'self' 'unsafe-inline'}
    set f [open [file join $docRoot index.html] r]
    wapp [read $f]
    close $f
}


set loadAvgChan [open /proc/loadavg r]


proc wapp-page-loadavg {} {
    variable loadAvgChan

    seek $loadAvgChan 0
    lassign [read $loadAvgChan] a b c _

    wapp-mimetype application/json
    set date [clock format [clock seconds] -format {%H:%M:%S}]
    wapp "{\"date\": \"$date\", \"avg\": \[$a, $b, $c\]}"
}


wapp-start [list -server [lindex $argv 0]]

close $loadAvgChan


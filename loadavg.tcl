#! /bin/sh
# -*- Tcl -*- \
exec tclsh "$0" ${1+"$@"}


package require sqlite3
source [file join [file dirname [file normalize [info script]]] wapp.tcl]

set dbFile loadavg.sqlite3
set updateInterval 10; # in seconds
set intervalDays 7; # save data for this number of days
set loadAvgChan [open /proc/loadavg r]

set docRoot [file join [file dirname [file normalize [info script]]] public_html]


proc wapp-default {} {
    variable docRoot
    wapp-content-security-policy {default_src 'self' 'unsafe-inline'}
    set f [open [file join $docRoot index.html] r]
    wapp [read $f]
    close $f
}


proc wapp-page-days {} {
    wapp-mimetype application/json
    wapp $::intervalDays
}


proc wapp-page-update {} {
    wapp-mimetype application/json
    wapp $::updateInterval
}

proc wapp-page-last {} {
    set last [lindex [db eval {
        SELECT '{"date": "' || strftime('%Y-%m-%d %H:%M:%S', dt,'unixepoch') ||
            '", "avg": [' || la1 || ', ' || la2 || ', ' || la3 || ']}'
          FROM loadavg
         ORDER BY dt DESC LIMIT 1
    }] 0]
    wapp-mimetype application/json
    wapp $last\n
}


proc wapp-page-dump {} {
    wapp-allow-xorigin-params
    set days [wapp-param days]
    if {![string is integer -strict $days]} {
        set days 1
    }

    if {$days > $::intervalDays} {
        set days $::intervalDays
    }
    
    set i [expr {60 * 60 * 24 * $days}]

    wapp-mimetype application/json
    wapp \[\n
    db eval {
        SELECT '{"date": "' || strftime("%Y-%m-%d %H:%M:%S", dt,"unixepoch") ||
            '", "avg": [' || la1 || ', ' || la2 || ', ' || la3 || ']}' AS json
          FROM loadavg
         WHERE dt >= strftime('%s','now') - :i
         ORDER BY dt ASC
    } r {
        wapp $r(json),\n
    }
    wapp "{}\n]\n"
}


proc initDB {} {
    sqlite3 db $::dbFile
    db eval {
        CREATE TABLE IF NOT EXISTS loadavg
        ( dt INTEGER PRIMARY KEY
	  , la1 TEXT NOT NULL
	  , la2 TEXT NOT NULL
	  , la3 TEXT NOT NULL
	  );
    }
    cleanupAVG
}


proc cleanupAVG {} {
    set older [expr {60 * 60 * 24 * $::intervalDays}]
    db eval {
        DELETE FROM loadavg WHERE dt < strftime('%s','now') - :older
    }
}


proc updateDB {} {
    seek $::loadAvgChan 0
    lassign [read $::loadAvgChan] a b c _
    db eval {
        INSERT INTO loadavg (dt, la1, la2, la3)
        VALUES (strftime('%s','now'), :a, :b, :c);
    }

    after [expr {$::updateInterval * 1000}] [info level 0]
}


initDB
updateDB

wapp-start [list -server [lindex $argv 0]]
#vwait forever

close $loadAvgChan


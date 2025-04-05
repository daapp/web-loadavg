#! /bin/sh
# -*- Tcl -*- \
exec tclsh "$0" ${1+"$@"}


package require sqlite3
source [file join [file dirname [file normalize [info script]]] wapp.tcl]

set dbFile loadavg.sqlite3
set updateInterval 10; # in seconds
set intervalDays 7; # save data for this number of days
set loadAvgChan [open /proc/loadavg r]

set DOC_ROOT [file join [file dirname [file normalize [info script]]] public_html]


proc wapp-return-file {filename {encoding utf-8}} {
    set f [open $filename r]
    fconfigure $f -encoding $encoding; # -translation binary
    wapp [read $f]
    close $f
}


proc wapp-default {} {
    wapp-mimetype "text/html; charset=utf-8"
    wapp-return-file [file join $::DOC_ROOT index.html]
}


proc wapp-page-style.css {} {
    wapp-mimetype "text/css; charset=utf-8"
    wapp-return-file [file join $::DOC_ROOT style.css]
}


proc wapp-page-script.js {} {
    wapp-mimetype "text/javascript"
    wapp-return-file [file join $::DOC_ROOT script.js]
}


proc wapp-page-chart.js {} {
    wapp-mimetype "text/javascript"
    wapp-return-file [file join $::DOC_ROOT chart.js]
}


proc wapp-page-days {} {
    wapp-mimetype text/json
    wapp $::intervalDays
}


proc wapp-page-update {} {
    wapp-mimetype text/json
    wapp $::updateInterval
}


proc wapp-page-last {} {
    set last [lindex [db eval {
        SELECT '{"date": "' || strftime('%Y-%m-%d %H:%M:%S', dt,'unixepoch','localtime') ||
            '", "avg": [' || la1 || ', ' || la2 || ', ' || la3 || ']}'
          FROM loadavg
         ORDER BY dt DESC LIMIT 1
    }] 0]
    wapp-mimetype text/json
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

    wapp-mimetype text/json
    wapp \[\n
    db eval {
        SELECT '{"date": "' || strftime("%Y-%m-%d %H:%M:%S", dt,'unixepoch', 'localtime') ||
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


close $loadAvgChan


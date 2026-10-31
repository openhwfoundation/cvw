# CoverageExclude.do
# David_Harris@hmc.edu 27 October 2026
#
# Helpers for coverage-exclusions-<config>.do that do not depend on line numbers or on Questa's numbering of
# focused expression/condition (FEC) rows, both of which change with edits and between configurations.
#
#   TagLine file tag
#     The line of file that carries the comment "exclusion-tag: tag" (the tag ends at white space or the end
#     of the line, so tag a-b does not match a-b-c).  It is an error for the tag to be missing or to appear
#     more than once.
#
#   ExcludeRows scope kind terms ?line?
#     Exclude the FEC rows of instance scope whose target is one of terms (glob patterns such as
#     AccessRWXC_0 or AtomicAllowed_*).  kind is e (expression) or c (condition).  Without line, the
#     expression is found as the only one in the instance that has a row for every term; with line, only
#     that source line is searched.  It is an error for a term to match no row, or, without line, for the
#     terms to fit no expression or more than one.  Hit rows can be excluded too, so the exclusions'
#     correctness rests on their comments, not on this lookup.  Only expressions that are still below 100% are
#     searched (Questa lists the rows of no other), so a fully hit expression never makes a lookup ambiguous,
#     and an expression whose rows an earlier command excluded is no longer seen.  A term matches either a row's whole target,
#     such as {(PageType > 1)_1} (a target with spaces, braced in Tcl), or its first word, such as (PageType
#     (which matches both rows of that subexpression).  Terms are string match patterns, so brackets in a
#     target are escaped: {SelRegions\[3\]_1}.  A term written +term only picks the expression: it must
#     match a row, which is not excluded.  For example {ReadAccessM_0 +ExecuteAccessF_*} excludes
#     ReadAccessM_0 in the one expression that has both ReadAccessM and ExecuteAccessF rows.
#
#   ExcludeTermRows scope kind terms
#     Exclude the rows that match terms in every FEC expression of instance scope.  Use it for an input that
#     is constant in the instance (a tied-off port, or a region a parameter removes): the row for its other
#     value cannot be reached in any expression, e.g. ExecuteAccessF_0 in the instruction MMU.  It is an
#     error for a term to match no row of the instance.
#
#   ExcludeGenRows scope block kind terms ?line?
#     ExcludeRows for the rows of generate block scope/block, such as counters/cntr[21].  Questa does not
#     report a generate block as an instance (coverage report -instance= rejects it); its rows are listed
#     under the enclosing instance scope, where every iteration of the block shares one source line.  The
#     rows are found there, by terms that name the iteration (such as {MCOUNTINHIBIT_REGW\[21\]_*}), and
#     excluded in scope/block.
#
# A component of the CORE-V-WALLY configurable RISC-V project.
# https://github.com/openhwfoundation/cvw
#
# Copyright (C) 2021-26 Harvey Mudd College & Oklahoma State University
#
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

proc TagLine {file tag} {
    set f [open $file]
    set lines [split [read $f] "\n"]
    close $f
    set found [lsearch -all -regexp $lines "exclusion-tag: [regsub -all {\W} $tag {\\&}](\\s|\$)"]
    if {[llength $found] != 1} {
        error "TagLine: exclusion-tag: $tag appears [llength $found] times in $file (expected once)"
    }
    return [expr {[lindex $found 0] + 1}]
}

# The FEC rows of instance scope: a dict of line -> list of {row target}.  A row line has one hit column, or
# two in a bimodal view, each a count, ***0***, or E/E-hit when the row is excluded; the target follows, and
# may contain single spaces.  The report lists the rows of an expression only while it is below 100%.
proc FecRows {scope kind} {
    set tmp [file join [pwd] .fecrows.[pid].rpt]
    coverage report -details -showexcluded -code $kind -instance=$scope -output $tmp
    set f [open $tmp]
    set lines [split [read $f] "\n"]
    close $f
    file delete $tmp
    set rows [dict create]
    set line ""
    set view 0
    foreach l $lines {
        if {[regexp {^-+Focused (Expression|Condition) View} $l]} { set view 1; continue }
        if {$view && [regexp {^Line\s+(\d+)\s+Item} $l -> line]} { continue }
        if {$view && $line ne "" &&
            [regexp {^\s*Row\s+(\d+):\s+(?:(?:\*\*\*0\*\*\*|\d+|E-hit|E)\s+){1,2}(\S+(?: \S+)*)} $l -> r target]} {
            dict lappend rows $line [list $r $target]
        }
    }
    return $rows
}

# The rows of rts (a list of {row target}) whose target, or its first word, matches pattern t.
proc MatchingRows {rts t} {
    set hit {}
    foreach rt $rts {
        set target [lindex $rt 1]
        if {[string match $t $target] || [string match $t [lindex [split $target] 0]]} { lappend hit [lindex $rt 0] }
    }
    return $hit
}

# The one line of rows (from FecRows) that has a row matching every term, and those rows: {line rowlist}.
# who names the caller and where the scope in the error message.
proc MatchRows {rows terms line who where} {
    set candidates [expr {$line eq "" ? [dict keys $rows] : [list $line]}]
    set matches {}
    foreach ln $candidates {
        if {![dict exists $rows $ln]} { continue }
        set sel {}
        set ok 1
        foreach t $terms {
            set context [string match +* $t]
            if {$context} { set t [string range $t 1 end] }
            set hit [MatchingRows [dict get $rows $ln] $t]
            if {$hit eq ""} { set ok 0; break }
            if {!$context} { lappend sel {*}$hit }
        }
        if {$ok} { lappend matches [list $ln [lsort -integer -unique $sel]] }
    }
    if {$line ne ""} { set where "line $line of $where" }
    if {[llength $matches] != 1} {
        error "$who: rows {$terms} fit [llength $matches] expressions in $where (expected one)"
    }
    return [lindex $matches 0]
}

proc ExcludeRows {scope kind terms {line ""}} {
    lassign [MatchRows [FecRows $scope $kind] $terms $line ExcludeRows $scope] ln sel
    set opt [expr {$kind eq "e" ? "-fecexprrow" : "-feccondrow"}]
    coverage exclude -scope $scope $opt $ln {*}$sel
}

proc ExcludeGenRows {scope block kind terms {line ""}} {
    lassign [MatchRows [FecRows $scope $kind] $terms $line ExcludeGenRows $scope] ln sel
    set opt [expr {$kind eq "e" ? "-fecexprrow" : "-feccondrow"}]
    coverage exclude -scope $scope/$block $opt $ln {*}$sel
}

proc ExcludeTermRows {scope kind terms} {
    set rows [FecRows $scope $kind]
    set opt [expr {$kind eq "e" ? "-fecexprrow" : "-feccondrow"}]
    set found {}
    dict for {ln rts} $rows {
        set sel {}
        foreach t $terms {
            set hit [MatchingRows $rts $t]
            if {$hit ne ""} { lappend found $t; lappend sel {*}$hit }
        }
        if {$sel ne ""} { coverage exclude -scope $scope $opt $ln {*}[lsort -integer -unique $sel] }
    }
    foreach t $terms {
        if {$t ni $found} { error "ExcludeTermRows: term $t matches no row in $scope" }
    }
}

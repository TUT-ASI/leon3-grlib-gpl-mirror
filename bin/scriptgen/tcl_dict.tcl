# dict.tcl
# http://wiki.tcl.tk/10609
#
# Tcl 8.4-compatible implementation of the [dict] command.
#
# Known deficiencies:
# - In error messages, the variable name doesn't always appear correctly.  This
#   is due to use of [upvar] which renames the variable.
# - Tcl 8.4 offers no way for [return], [break], etc. inside the script to
#   affect the caller.  [uplevel] doesn't quite do everything that's needed.
# - Some usage error messages show different names for formal parameters.
# - Performance is reduced.
#
# Test failures (prefix each name with "dict-"):
# 3.12    4.5     5.7     9.7     9.8     11.15   12.7    12.8    12.10
# 13.7    13.8    13.9    14.1    14.2    14.3    14.4    14.12   14.13
# 14.22   15.9    15.10   15.11   16.8    16.9    16.17   16.18   17.13
# 17.16   17.18   21.1    21.2    21.3    21.4    21.13   21.14   21.15
# 22.1    22.2    22.3    22.10   22.14   22.15   23.1    23.2    24.1
# 24.2    24.3    24.4    24.12   24.13   24.20.1 24.21   24.24   24.25

# Only create [dict] command if it doesn't already exist.
if {[catch {dict get {}}]} {
    # Tcl 8.4-style implementation of namespace ensembles.
    namespace eval ::dict {}
    proc ::dict {subcommand args} {
        # Confirm $subcommand is a [dict] command or unambiguous prefix thereof.
        if {[regexp {[][*?\\]} $subcommand]
         || [llength [set command [info commands ::dict::$subcommand*]]] != 1} {
            set commands [string map {::dict:: {}}\
                    [lsort [info commands ::dict::*]]]
            if {[llength $commands] > 1} {
                lset commands end "or [lindex $commands end]"
            }
            if {[llength $commands] > 2} {
                set commands [join $commands ", "]
            } else {
                set commands [join $commands]
            }
            return -code error "unknown or ambiguous subcommand\
                    \"$subcommand\": must be $commands"
        }

        # Invoke the command.
        if {[catch {uplevel 1 [concat [list $command] $args]} msg]} {
            # Rewrite the command name on error.
            regsub {^(wrong # args: should be \")::(dict)::} $msg {\1\2 } msg
            return -code error $msg
        } else {
            return $msg
        }
    }

    # [dict append]
    proc ::dict::append {varName key args} {
        upvar 1 $varName var

        # Locate the matching key.  On match, append to the key's value.
        if {[::info exists var]} {
            ::set var [get $var]
            ::for {::set i 0} {$i < [llength $var]} {::incr i 2} {
                if {[lindex $var $i] eq $key} {
                    ::incr i
                    return [lset var $i [lindex $var $i][join $args {}]]
                }
            }
        }

        # On search failure, add the key to the dict.  This code also will
        # create the dict if it doesn't already exist.
        ::lappend var $key [join $args {}]
    }

    # [dict create]
    proc ::dict::create {args} {
        if {[llength $args] & 1} {
            return -code error "wrong # args: should be\
                    \"dict create ?key value ...?\""
        }
        get $args
    }

    # [dict exists]
    proc ::dict::exists {dictionary key args} {
        # Traverse through nested dicts searching for matches.
        ::set sub $dictionary
        foreach key [concat [list $key] $args] {
            if {[llength $sub] & 1} {
                return 0
            }
            ::set match 0
            foreach {subkey sub} $sub {
                if {$subkey eq $key} {
                    ::set match 1
                    break
                }
            }
            if {!$match} {
                return 0
            }
        }
        return $match
    }

    # [dict filter]
    proc ::dict::filter {dictionary filterType args} {
        # Invoke the correct filter handler.
        ::set result {}
        switch $filterType {
        k - ke - key {
            # Filter on keys.
            foreach {key val} [get $dictionary] {
                foreach pattern $args {
                    if {[string match $pattern $key]} {
                        ::lappend result $key $val
                        break
                    }
                }
            }
        } v - va - val - valu - value {
            # Filter on values.
            foreach {key val} [get $dictionary] {
                foreach pattern $args {
                    if {[string match $pattern $val]} {
                        ::lappend result $key $val
                        break
                    }
                }
            }
        } s - sc - scr - scri - scrip - script {
            # Filter on script returning true.
            if {[llength $args] != 2} {
                return -code error "wrong # args: should be\
                        \"dict filter dictionary script\
                        {keyVarName valueVarName} filterScript\""
            } elseif {[llength [lindex $args 0]] != 2} {
                return -code error "must have exactly two variable names"
            }
            upvar 1 [lindex $args 0 0] key [lindex $args 0 1] val
            foreach {key val} [get $dictionary] {
                if {[uplevel 1 [lindex $args 1]]} {
                    ::lappend result $key $val
                }
            }
        } default {
            return -code error "bad filterType \"$filterType\":\
                    must be key, script, or value"
        }}
        return $result
    }

    # [dict for]
    proc ::dict::for {keyVarValueVar dictionary script} {
        if {[llength $keyVarValueVar] != 2} {
            return -code error "must have exactly two variable names"
        }

        # [foreach] does what's needed, mostly.  Tcl 8.4 offers no way for
        # [return], etc. inside the script to make the caller return.
        uplevel 1 [list foreach $keyVarValueVar [get $dictionary] $script]
    }

    # [dict get]
    proc ::dict::get {dictionary args} {
        if {[llength $args]} {
            # When given multiple arguments, traverse nested dicts to find the
            # requested key.  Fail if the key is not found.
            ::set sub $dictionary
            foreach key $args {
                if {[llength $sub] & 1} {
                    return -code error "missing value to go with key"
                }
                ::for {::set i [expr {[llength $sub] - 2}]} {1} {::incr i -2} {
                    if {$i < 0} {
                        return -code error "key \"$key\" not known\
                                in dictionary"
                    } elseif {[lindex $sub $i] eq $key} {
                        break
                    }
                }
                ::set sub [lindex $sub [expr {$i + 1}]]
            }
            return $sub
        } else {
            # With only one argument, convert that argument to a canonical dict.
            if {[llength $dictionary] & 1} {
                return -code error "missing value to go with key"
            }
            ::for {::set i 0} {$i < [llength $dictionary]} {::incr i 2} {
                if {[::info exists indexes([lindex $dictionary $i])]} {
                    lset dictionary $indexes([lindex $dictionary $i])\
                            [lindex $dictionary [expr {$i + 1}]]
                    ::set dictionary [lreplace $dictionary $i [expr {$i + 1}]]
                    ::incr i -2
                } else {
                    ::set indexes([lindex $dictionary $i]) [expr {$i + 1}]
                }
            }
            return $dictionary
        }
    }

    # [dict incr]
    proc ::dict::incr {varName key {increment 1}} {
        upvar 1 $varName var

        # Disallow non-integer increments.
        if {![string is integer -strict $increment]} {
            return -code error "expected integer but got \"$increment\""
        }

        # Locate the matching key and increment its value.
        if {[::info exists var]} {
            ::set var [get $var]
            ::for {::set i 0} {$i < [llength $var]} {::incr i 2} {
                if {$key eq [lindex $var $i]} {
                    ::incr i

                    # Disallow non-integer values.
                    if {![string is integer -strict [lindex $var $i]]} {
                        return -code error "expected integer but\
                                got \"[lindex $var $i]\""
                    }

                    # Increment the value in place.
                    return [lset var $i [expr {[lindex $var $i] + $increment}]]
                }
            }
        }

        # On search failure, add the key to the dict.  This code also will
        # create the dict if it doesn't already exist.
        ::lappend var $key $increment
    }

    # [dict info]
    proc ::dict::info {dictionary} {
        # Make sure the dictionary is valid.
        if {[llength $dictionary] & 1} {
            return -code error "missing value to go with key"
        }

        # No hash table.
        return "dict is represented as plain list"
    }

    # [dict keys]
    proc ::dict::keys {dictionary {pattern *}} {
        # Build and return a list of matching keys.
        ::set result {}
        foreach {key val} [get $dictionary] {
            if {[string match $pattern $key]} {
                ::lappend result $key
            }
        }
        return $result
    }

    # [dict lappend]
    proc ::dict::lappend {varName key args} {
        upvar 1 $varName var

        # Locate the matching key and append a list element to its value.
        if {[::info exists var]} {
            ::set var [get $var]
            ::for {::set i 0} {$i < [llength $var]} {::incr i 2} {
                if {$key eq [lindex $var $i]} {
                    ::incr i

                    # Disallow non-list values.
                    llength [lindex $var $i]

                    # Increment the value in place.
                    return [lset var $i [concat [lindex $var $i] $args]]
                }
            }
        }

        # On search failure, add the key to the dict.  This code also will
        # create the dict if it doesn't already exist.
        ::lappend var $key $args
    }

    # [dict map]
    proc ::dict::map {keyVarValueVar dictionary script} {
        # Confirm argument syntax.
        if {[llength $keyVarValueVar] != 2} {
            return -code error "must have exactly two variable names"
        }

        # Link to local variables which will be used as iterators.
        upvar 1 [lindex $keyVarValueVar 0] key [lindex $keyVarValueVar 1] val

        # Accumulate and return the result.
        ::set result {}
        foreach {key val} [get $dictionary] {
            ::lappend result $key [uplevel 1 $script]
        }
        return $result
    }

    # [dict merge]
    proc ::dict::merge {args} {
        # Confirm each argument is a dict.
        foreach dict $args {
            if {[llength $dict] & 1} {
                return -code error "missing value to go with key"
            }
        }

        # Merge the dicts, then normalize.
        get [eval [list concat] $args]
    }

    # [dict remove]
    proc ::dict::remove {dictionary args} {
        # Remove all dictionary keys matching any of the key arguments.
        ::set dictionary [get $dictionary]
        ::set args [lsort -unique $args]
        ::for {::set i 0} {$i < [llength $dictionary]} {::incr i 2} {
            ::set index [lsearch -exact -sorted $args [lindex $dictionary $i]]
            if {$index >= 0} {
                ::set dictionary [lreplace $dictionary $i [expr {$i + 1}]]
                ::set args [lreplace $args $index $index]
                if {![llength $args]} {
                    break
                }
                ::incr i -2
            }
        }
        return $dictionary
    }

    # [dict replace]
    proc ::dict::replace {dictionary args} {
        # Confirm correct argument parity.
        if {[llength $args] & 1} {
            return -code error "wrong # args:\
                    should be \"dict replace dictionary ?key value ...?\""
        }

        # Concatenate the dicts then use [get] to canonicalize the result.
        get [eval [list concat $dictionary] $args]
    }

    # [dict set]
    proc ::dict::set {varName key args} {
        upvar 1 $varName var

        # Confirm that a value argument was given.
        if {![llength $args]} {
            return -code error "wrong # args:\
                    should be \"dict set varName key ?key ...? value\""
        }

        # Default the dictionary to empty.
        if {![::info exists var]} {
            ::set var {}
        }

        # Shuffle the arguments into the right variables.
        ::set keys [concat [list $key] [lrange $args 0 end-1]]
        ::set val [lindex $args end]

        # Traverse through nested dicts to find the key to insert or replace.
        ::set path {}
        ::set sub $var
        ::for {::set i 0} {$i < [llength $keys]} {::incr i} {
            # Canonicalize each level of nested dicts.
            lset var $path [::set sub [get $sub]]

            # Search the current level to see if any keys match.
            ::for {::set j 0} {1} {::incr j 2} {
                if {$j >= [llength $sub]} {
                    # On match failure, move the remaining keys into the value,
                    # transforming it into a nested dict, then set that value.
                    ::set j [expr {[llength $keys] - 1}]
                    ::for {} {$j > $i} {::incr j -1} {
                        ::set val [list [lindex $keys $j] $val]
                    }
                    lset var $path [concat $sub [list [lindex $keys $i] $val]]
                    return $var
                } elseif {[lindex $sub $j] eq [lindex $keys $i]} {
                    # On match success, advance to the next level of nesting.
                    break
                }
            }

            # Descend into the value associated with the matching key.
            ::incr j
            ::lappend path $j
            ::set sub [lindex $sub $j]
        }

        # Replace the value of the matched key.
        lset var $path $val
    }

    # [dict size]
    proc ::dict::size {dictionary} {
        # Canonicalize the dict and return half its length.
        expr {[llength [get $dictionary]] / 2}
    }

    # [dict unset]
    proc ::dict::unset {varName key args} {
        upvar 1 $varName var

        # Handle the case of the dict not existing.
        if {![::info exists var]} {
            if {[llength $args]} {
                # Fail when unsetting a nested key.
                return -code error "key \"$key\" not known in dictionary"
            } else {
                # Create the dict when unsetting a non-nested key.
                ::set var {}
                return
            }
        }

        # Traverse through nested dicts to find the key to remove.
        ::set keys [concat [list $key] $args]
        ::set path {}
        ::set sub $var
        ::for {::set i 0} {1} {::incr i} {
            # Canonicalize each level of nested dicts.
            lset var $path [::set sub [get $sub]]

            # Search the current level to see if any keys match.
            ::for {::set j 0} {$j < [llength $sub]} {::incr j 2} {
                if {[lindex $sub $j] eq [lindex $keys $i]} {
                    break
                }
            }

            # Handle outer and innermost nesting levels differently.
            if {$i < [llength $keys] - 1} {
                # In parent levels, search failure is an error.
                if {$j >= [llength $sub]} {
                    return -code error "key \"[lindex $keys $i]\"\
                            not known in dictionary"
                }

                # Descend into the value associated with the matching key.
                ::incr j
                ::lappend path $j
                ::set sub [lindex $sub $j]
            } else {
                # In the innermost level, search failure is acceptable.  On
                # search success, remove the key, otherwise just ignore.
                if {$j < [llength $sub]} {
                    lset var $path [lreplace $sub $j [expr {$j + 1}]]
                }

                # Return the updated dictionary.
                return $var
            }
        }
    }

    # [dict update]
    proc ::dict::update {varName key valVarName args} {
        # Confirm argument parity.
        if {!([llength $args] & 1)} {
            return -code error "wrong # args: should be\
                    \"dict update varName key valVarName\
                    ?key valVarName ...? script\""
        }
        ::set script [lindex $args end]

        # Convert the list of keys and variable names to an array.
        array set names [concat [list $key $valVarName] [lrange $args 0 end-1]]

        # Initially unset caller variables.
        ::set valVarNames {}
        foreach {key valVarName} [array get names] {
            lappend valVarNames $valVarName
        }
        uplevel 1 [list unset -nocomplain] $valVarNames

        # Copy the dict values into the caller's variables.
        upvar 1 $varName dict
        foreach {key val} [get $dict] {
            if {[::info exists names($key)]} {
                upvar 1 $names($key) valVar
                ::set valVar $val
            }
        }

        # Invoke the caller-supplied script.
        ::set result [uplevel 1 $script]

        # If the dict is gone, let it stay gone.  Otherwise update it.
        if {[::info exists dict]} {
            # Update the dict values from the caller's variables, and remove
            # keys corresponding to unset variables.
            ::for {::set i 0} {$i < [llength $dict]} {::incr i 2} {
                if {[::info exists names([lindex $dict $i])]} {
                    upvar 1 $names([lindex $dict $i]) valVar
                    ::unset names([lindex $dict $i])
                    if {[::info exists valVar]} {
                        lset dict [expr {$i + 1}] $valVar
                    } else {
                        ::set dict [lreplace $dict $i [expr {$i + 1}]]
                        ::incr i -2
                    }
                }
            }

            # Add keys back to the dict from the caller's variables, in case the
            # caller removed some keys directly from the dict.
            foreach {key valVarName} [array get names] {
                upvar 1 $valVarName valVar
                if {[::info exists valVar]} {
                    ::lappend dict $key $valVar
                }
            }
        }

        # Return the result of the script.
        return $result
    }

    # [dict values]
    proc ::dict::values {dictionary {pattern *}} {
        # Build and return a list of matching values.
        ::set result {}
        foreach {key val} [get $dictionary] {
            if {[string match $pattern $val]} {
                ::lappend result $val
            }
        }
        return $result
    }

    # [dict with]
    proc ::dict::with {varName args} {
        upvar 1 $varName dict

        # Confirm a script argument was supplied.
        if {![llength $args]} {
            return -code error "wrong # args:\
                    should be \"dict with varName ?key ...? script\""
        }
        ::set script [lindex $args end]
        ::set args [lrange $args 0 end-1]

        # Traverse through nested dicts to find the dict on which to operate.
        ::set path {}
        ::set sub [get $dict]
        foreach key $args {
            # Canonicalize each level of nested dicts.
            lset dict $path $sub

            # Search the current level to see if any keys match.
            ::for {::set i 0} {$i < [llength $sub]} {::incr i 2} {
                if {[lindex $sub $i] eq $key} {
                    break
                }
            }

            # Terminate on match failure.
            if {$i >= [llength $sub]} {
                return -code error "key \"$key\" not known in dictionary"
            }

            # Descend into the value associated with the matching key.
            ::incr i
            ::set sub [get [lindex $sub $i]]
            ::lappend path $i
        }

        # Copy the dict values into the caller's variables.  Make an array to
        # keep track of all the keys in the dict.
        foreach {key val} $sub {
            upvar 1 $key valVar
            ::set valVar $val
            ::set keys($key) {}
        }

        # Invoke the caller-supplied script.
        ::set result [uplevel 1 $script]

        # If the dict is gone, let it stay gone.  Otherwise update it.
        if {[::info exists dict]} {
            # Traverse through nested dicts again in case the caller-supplied
            # script reorganized the dict.
            ::set path {}
            ::set sub [get $dict]
            foreach key $args {
                # Canonicalize each level of nested dicts.
                lset dict $path $sub

                # Search the current level to see if any keys match.
                ::for {::set i 0} {$i < [llength $sub]} {::incr i 2} {
                    if {[lindex $sub $i] eq $key} {
                        break
                    }
                }

                # Terminate on match failure.
                if {$i >= [llength $sub]} {
                    return -code error "key \"$key\" not known in dictionary"
                }

                # Descend into the value associated with the matching key.
                ::incr i
                ::set sub [get [lindex $sub $i]]
                ::lappend path $i
            }

            # Update the dict values from the caller's variables, and remove
            # keys corresponding to unset variables.
            ::for {::set i 0} {$i < [llength $sub]} {::incr i 2} {
                if {[::info exists keys([lindex $sub $i])]} {
                    upvar 1 [lindex $sub $i] valVar
                    ::unset keys([lindex $sub $i])
                    if {[::info exists valVar]} {
                        lset sub [expr {$i + 1}] $valVar
                    } else {
                        ::set sub [lreplace $sub $i [expr {$i + 1}]]
                        ::incr i -2
                    }
                }
            }

            # Add keys back to the dict from the caller's variables, in case the
            # caller removed some keys directly from the dict.
            foreach key [array names keys] {
                upvar 1 $key valVar
                if {[::info exists valVar]} {
                    ::lappend sub $key $valVar
                }
            }

            # Save the updated nested dict back into the dict variable.
            lset dict $path $sub
        }

        # Return the result of the script.
        return $result
    }
}

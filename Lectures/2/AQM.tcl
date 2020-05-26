#
# AQM.tcl is a simulation script to experiment with queue management
# schemes.  This has been used in the Computer Networks
# course 6.829 at MIT.
#
# Xiaowei Yang 
# Updated by Todd Nightingale   9.25.02

# To be run using NS:
# % ns AQM.tcl
# 
# Options can be set using -OPTION VAULE
# % ns AQM.tcl -test "RED" -qlen 100


# Generic Testing Class
Class TestSuite

# Specific Testing Classes
Class Test/FQCBR -superclass TestSuite
Class Test/FQTCP -superclass TestSuite
Class Test/RED -superclass TestSuite
Class Test/ECN -superclass TestSuite
Class Test/REDECN -superclass TestSuite
Class Test/ECNCHEAT -superclass TestSuite
Class Test/ECNCHEATALL -superclass TestSuite
Class Test/DropTail -superclass TestSuite
Class Test/Pareto -superclass TestSuite
Class Test/ParetoDropTail -superclass TestSuite


# set defaults for all user specifiable parameters
# (there are the parameters students will change from the command line)
proc default-options {} {
    global opt

    set opt(test) "RED"
    set opt(outdir) "out"
    set opt(qtrace) "on"
    set opt(traceall) "on"
    set opt(pipe) "on"
    set opt(cwndtrace) "on"
    set opt(namtrace) "off"
    set opt(autonam) "off"
    set opt(stoptime) 200
    set opt(startuptime) 20
    set opt(nconn) 3
    set opt(delay) 2ms
    set opt(bw) 100Mb
    set opt(qlen) 54
    set opt(bndelay) 40ms
    set opt(bnbw) 1.5Mb
    set opt(maxwin) 120
    set opt(pktsize) 1000
    set opt(topo) "net0"
    set opt(ncheat) 1
    set opt(npareto) 1
    set opt(seed) 27
    set opt(loss_interval) 100
    set opt(interval) 1.0
}

proc usage {} {
    global opt
    puts "Options:"
    puts "\t-test <LFN/FQ/RED/ECN/REDECN/ECNCHEAT>. The test to run. Default: $opt(test)."
    puts "\t-outdir <value>. Data file output directory. Default: $opt(outdir)."
    puts "\t-qtrace <on/off>. Queue tracing on or off. Default: $opt(qtrace)."
    puts "\t-traceall <on/off>. Trace all on or off. Default: $opt(traceall)."
    puts "\t-namtrace <on/off>. Nam tracing on or off. Default: $opt(namtrace)."
    puts "\t-autonam <on/off>. Execute nam at the end of simulation. Default: $opt(autonam)."
    puts "\t-stoptime <value>. The simulation stop time. Default: $opt(stoptime)."
    puts "\t-startuptime <value>. Each connection randoms starts between time 0 and value. Default: $opt(startuptime)."
    puts "\t-nconn <value>. Number of connections. Default: $opt(nconn)."
    puts "\t-delay <value>. Non-bottleneck Link Delay. Default: $opt(delay)."
    puts "\t-bw <value>. Non-bottleneck link bandwidth. Default: $opt(bw)."
    puts "\t-qlen <value>. Bottleneck max queue length. Default: $opt(qlen)."
    puts "\t-bndelay <value>. Bottleneck propagation delay. Default: $opt(bndelay)."
    puts "\t-bnbw <value>. Bottleneck bandwidth. Default: $opt(bnbw)."
    puts "\t-maxwin <value>. Maximum TCP window size. Default: $opt(maxwin)."
    puts "\t-pktsize <value>. Maximum TCP segment size. Default: $opt(pktsize)."
    puts "\t-topo <net0|net1|net2>. Topology. Default: $opt(topo)."
    puts "\t-ncheat <value>. Number of cheating ECNs. Used in test ECNCHEAT. Default: $opt(ncheat)."
    puts "\t-npareto <value>. Number of paretos. Used in test Pareto*. Default: $opt(npareto)."
    puts "\t-seed <0-63>. The random seed for generating startup time for different flows. Default: $opt(seed)."
    puts "\t-loss_interval <int>. The interval in terms of packets to sample short term loss rate."
    puts "\t-interval <value>. The time interval to sample short term throughput and link utilization."
}


TestSuite instproc init {} {
    global opt
    $self instvar ns_ qmon S_ D_ R_ allf namf testName_ rng_ cwndf
    
    # set up topology
    remove-packet-header AODV ARP
    Trace set show_tcphdr_ 1
    Agent/TCP/FullTcp set segsize_ $opt(pktsize)
    Agent/TCP/FullTcp set window_ $opt(maxwin)
    Agent/TCP/FullTcp set slow_start_restart_ false

    set ns_ [new Simulator]
    if {$opt(traceall) == "on"} {
	if {$opt(pipe) == "on"} {
	    # Magic of awk will handle data
	    set allf [open "| awk -f script/tput.awk nconn=$opt(nconn) prefix=$opt(outdir)/${testName_} loss_interval=$opt(loss_interval) interval=$opt(interval)" w]
	} else {
	    set allf [open "$opt(outdir)/${testName_}-all.dat" w]
	}
	$ns_ trace-all $allf
    }
    
    if {$opt(namtrace) == "on" } {
	set namf [open $opt(outdir)/${testName_}-nam.dat w]
	$ns_ namtrace-all $namf
    }

    if {$opt(cwndtrace) == "on"} {
	for {set i 0} {$i < $opt(nconn)} {incr i} {
	    set cwndf($i) [open "| awk -f script/cwnd1.awk cwndfile=$opt(outdir)/${testName_}-cwnd-$i.dat" w]
	}
    }
    
    set rng_ [new RNG]
    $rng_ seed "predef" [expr $opt(seed) % 63]

    set color(0) red
    set color(1) green
    set color(2) cyan
    set color(3) orange
    set color(4) blue
    set color(5) yellow

    for {set i 0} {$i < $opt(nconn)} {incr i} {
	$ns_ color $i $color([expr $i % 6])
    }
    
}

TestSuite instproc create-net0 {} {
    global opt
    $self instvar ns_ S_ D_ R_ qf
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set S_($i) [$ns_ node]
    }
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set D_($i) [$ns_ node]
    }
    
    set R_(0) [$ns_ node]
    set R_(1) [$ns_ node]
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	$ns_ duplex-link $S_($i) $R_(0) 100M $opt(delay) DropTail
	$ns_ duplex-link $R_(1) $D_($i) 100M $opt(delay) DropTail
    }
}

TestSuite instproc create-net1 {} {
    global opt
    $self instvar ns_ S_ D_ R_ qf
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set S_($i) [$ns_ node]
    }
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set D_($i) [$ns_ node]
    }
    
    set R_(0) [$ns_ node]
    set R_(1) [$ns_ node]
    
    $ns_ duplex-link $S_(0) $R_(0) 100M $opt(delay) DropTail
    $ns_ duplex-link $R_(1) $D_(0) 56K $opt(delay) DropTail

    for {set i 1} {$i < $opt(nconn)} {incr i} {
	$ns_ duplex-link $S_($i) $R_(0) 100M $opt(delay) DropTail
	$ns_ duplex-link $R_(1) $D_($i) 100M $opt(delay) DropTail
    }
}

TestSuite instproc create-net2 {} {
    global opt
    $self instvar ns_ S_ D_ R_ qf
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set S_($i) [$ns_ node]
    }
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set D_($i) [$ns_ node]
    }
    
    set R_(0) [$ns_ node]
    set R_(1) [$ns_ node]
    
    $ns_ duplex-link $S_(0) $R_(0) 100M $opt(delay) DropTail
    $ns_ duplex-link $R_(1) $D_(0) 100M 200ms DropTail
    
    for {set i 1} {$i < $opt(nconn)} {incr i} {
	$ns_ duplex-link $S_($i) $R_(0) 100M $opt(delay) DropTail
	$ns_ duplex-link $R_(1) $D_($i) 100M $opt(delay) DropTail
    }
}


TestSuite instproc create-btnk {{qtype "RED"}} {
    global opt
    $self instvar ns_ R_ S_ D_  qf testName_
    
    # set up bottleneck link
    $ns_ duplex-link $R_(0) $R_(1) $opt(bnbw) $opt(bndelay) $qtype
    $ns_ queue-limit $R_(0) $R_(1) $opt(qlen)
    $ns_ duplex-link-op $R_(0) $R_(1) queuePos 0.5
    
    set bnk [$ns_ link $R_(0) $R_(1)]
    set btnkq [$bnk queue]
    
    if {$qtype == "RED"} {
	$btnkq set thresh_ 6
	$btnkq set maxthresh_ 18
	$btnkq set mean_pktsize_ $opt(pktsize)
	$btnkq set q_weight_ 0.002
	$btnkq set linterm_ 10
	$btnkq set gentle_ true
	$btnkq set setbit_ true
	
	if {$opt(qtrace) == "on"} {
	    if {$opt(pipe) == "on"} {
		set qf [open  "| awk -f script/redq.awk Qfile=$opt(outdir)/${testName_}-q.dat afile=$opt(outdir)/${testName_}-a.dat" w]
	    } else {
		set qf [open  $opt(outdir)/${testName_}-redq.dat w]
	    }
	}
	$btnkq trace curq_
	$btnkq trace ave_
	$btnkq attach $qf
    } else {
	if {$opt(qtrace) == "on"} {
	    if {$opt(pipe) == "on"} {
		set qf [open  "| awk -f script/dtq.awk Qfile=$opt(outdir)/${testName_}-dtq.dat" w]
	    } else {
		set qf [open  $opt(outdir)/${testName_}-dtq.dat w]
	    }			    
	    $ns_ monitor-queue $R_(0) $R_(1) $qf
	    $bnk start-tracing
	}
    }
}


TestSuite instproc create-ftp {i {ecn "false"} {ecn_cheat "false"}} {
    global opt
    $self instvar ns_  S_ D_  cwndf testName_ rng_
    
    #set tcp [new Agent/TCP/FullTcp/$opt(tcptype)]
    set tcp [new Agent/TCP/FullTcp]
    set tcpsink [new Agent/TCP/FullTcp]
    #set tcpsink [new Agent/TCP/FullTcp/$opt(tcptype)]
    $tcp set fid_ $i
    $tcpsink set fid_ $i

    if {$opt(cwndtrace) == "on"} {
	#set cwndf($i) [open "$opt(outdir)/${testName_}-cwnd-$i.dat" w]
	$tcp attach $cwndf($i)
	$tcp tracevar cwnd_ 
	$tcp tracevar ssthresh_
    }
    if {$ecn == "true"} {
	$tcp set ecn_ true
	$tcpsink set ecn_ true
    }
    if {$ecn_cheat == "true"} {
	$tcpsink set ecn_cheat_ true
    }
    $ns_ attach-agent $S_($i) $tcp
    $ns_ attach-agent $D_($i) $tcpsink
    $tcpsink listen
    $ns_ connect $tcp $tcpsink
    set ftp [new Application/FTP]
    $ftp attach-agent $tcp

    set starttime [$rng_ uniform 0 $opt(startuptime)]
    puts "starttime $starttime"
    $ns_ at $starttime "$ftp start"
    #$ns_ at $opt(startuptime) "$ftp start"
}

TestSuite instproc create-cbr { i } {
    global opt
    $self instvar ns_ S_ D_ rng_

    set udp [new Agent/UDP]
    set null [new Agent/Null]
    $udp set fid_ $i
    $null set fid_ $i
    $ns_ attach-agent $S_($i) $udp
    $ns_ attach-agent $D_($i) $null
    $ns_ connect $udp $null
    set cbr [new Application/Traffic/CBR]
    $cbr set packetSize_ 1000
    $cbr set rate_ [expr $opt(pktsize) * 8 * 200]
    $cbr attach-agent $udp

    set starttime [$rng_ uniform 0 $opt(startuptime)]
    $ns_ at $starttime "$cbr start"
}


TestSuite instproc create-pareto {i} {
    global opt
    $self instvar ns_  S_ D_ rng_ testName_ cwndf rng_
    
    set udp [new Agent/UDP]
    set null [new Agent/Null]
    $udp set fid_ $i
    $null set fid_ $i
    $ns_ attach-agent $S_($i) $udp
    $ns_ attach-agent $D_($i) $null
    $ns_ connect $udp $null
    
    set rng($i) [new RNG]
    $rng($i) seed "predef" [expr ($i + 37) % 64]
    set pareto [new Application/Traffic/Pareto]
    $pareto use-rng $rng($i)
    $pareto set packetSize_ $opt(pktsize)
    $pareto set burst_time_ 100ms
    $pareto set idle_time_ 900ms
    $pareto set rate_ 800K
    $pareto set shape_ 1.5
    $pareto attach-agent $udp
    
    set starttime [$rng_ uniform 0 $opt(startuptime)]
    puts "starttime $starttime"
    $ns_ at $starttime "$pareto start"
}

TestSuite instproc run {} {
    global opt
    $self instvar ns_
    
    $ns_ at $opt(stoptime) "$self finish"
    $ns_ run
}

TestSuite instproc finish {} {
    global opt
    $self instvar ns_ allf qf  namf cwndf testName_

    $ns_ flush-trace
    
    if {$opt(traceall) == "on"} {
	flush $allf
	close $allf
    }
    

    if {$opt(cwndtrace) == "on"} {
	for {set i 0} {$i < $opt(nconn)} {incr i} {
	    flush $cwndf($i)
	    close $cwndf($i)
	}
    }
    
    if {$opt(qtrace) == "on"} {
	flush $qf
	close $qf
    }
    
    if {$opt(namtrace) == "on"} {
	flush $namf
	close $namf
    }
    
    if {$opt(autonam) == "on"} {
	exec nam $opt(outdir)/${testName_}-nam.dat &
    }

    #exec awk -f script/xplot3.awk  $opt(outdir)/all.dat > $opt(outdir)/all-$opt(qlen).xpl &
    exit 0
}

Test/ECN instproc init {topo} {
    global opt

    $self instvar testName_ 
    $self set testName_ $opt(test):$topo
    $self next
    $self create-$topo
    
    $self create-btnk
    set ecn "true"
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	$self create-ftp $i $ecn 
    }
}

Test/RED instproc init {topo} {
    global opt
    $self instvar testName_ 

    $self set testName_ $opt(test):$topo
    $self next
    $self create-$topo
    
    $self create-btnk
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	$self create-ftp $i
    }
}

Test/REDECN instproc init {topo} {
    global opt

    $self instvar testName_ 
    $self set testName_ $opt(test):$topo
    $self next
    $self create-$topo
    
    $self create-btnk
    set ecn "true"
    set ecn_cheat "false"
    set half [expr $opt(nconn) / 2]
    for {set i 0 } {$i < $half} {incr i} {
	$self create-ftp $i $ecn
    }
    set ecn "false"
    for {set i $half} {$i < $opt(nconn)} {incr i} { 
	$self create-ftp $i $ecn
    }
}

Test/ECNCHEAT instproc init {topo} {
    global opt

    $self instvar testName_ 
    $self set testName_ $opt(test):$topo:$opt(ncheat)
    $self next
    $self create-$topo
    
    $self create-btnk
    set ecn "true"
    set ecn_cheat "true"
    if {$opt(ncheat) > $opt(nconn)} {
	puts "ncheat should be no greater than nconn"
	exit 1
    }
    for {set i 0} {$i < $opt(ncheat)} {incr i} {
	$self create-ftp $i $ecn $ecn_cheat
    }
    for {set i $opt(ncheat)} {$i < $opt(nconn)} {incr i} {
	$self create-ftp $i $ecn
    }
}

Test/FQCBR instproc init {topo} {
    global opt
    
    $self instvar testName_ 
    $self set testName_ $opt(test):$topo
    $self next
    $self create-$topo
    
    $self create-btnk "FQ"
    $self create-cbr 0
    for {set i 1} {$i < $opt(nconn)} {incr i} {
	 $self create-ftp $i
    }
}

Test/FQTCP instproc init {topo} {
    global opt
    
    $self instvar testName_ 
    $self set testName_ $opt(test):$topo
    $self next
    $self create-$topo
    
    $self create-btnk "FQ"
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	 $self create-ftp $i
    }
}

Test/DropTail instproc init {topo} {
    global opt
    
    $self instvar testName_ 
    $self set testName_ $opt(test):$topo
    $self next
    $self create-$topo
    
    $self create-btnk "DropTail"
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	$self create-ftp $i
    }
}

Test/Pareto instproc init { topo } {
    global opt
    
    $self instvar testName_ 
    $self set testName_ $opt(test):$topo:$opt(npareto)
    $self next
    $self create-$topo
    
    $self create-btnk "RED"

    for {set i 0 } {$i < $opt(npareto)} {incr i} {
	$self create-pareto $i
    }
    
    for {set i $opt(npareto)} {$i < $opt(nconn)} {incr i} {
	 $self create-ftp $i
    }
}

Test/ParetoDropTail instproc init {topo} {
    global opt
    
    $self instvar testName_
    
    $self set testName_ $opt(test):$topo:$opt(npareto)
    $self next
    $self create-$topo
    
    $self create-btnk "DropTail"

    for {set i 0 } {$i < $opt(npareto)} {incr i} {
	$self create-pareto $i
    }
    
    for {set i $opt(npareto)} {$i < $opt(nconn)} {incr i} {
	 $self create-ftp $i
    }
}

# Runs One Test
proc runtest {arg} {
    global opt
    
    default-options
    set b [llength $arg]
    
    for {set i 0} {$i < $b} {incr i} {
        set tmp [lindex $arg $i]
        if {[string range $tmp 0 0] != "-"} continue
        set name [string range $tmp 1 end]
        if {$name == "help"} {
            usage
        } elseif {[info exists opt($name)]} {
            set val [lindex $arg [incr i]]
            global opt($name)
            set opt($name) $val
            puts "-$name set to $opt($name)"
        } else {
            puts "Invalid option: $name"
            usage
        }       
    }

    set t [new Test/$opt(test) $opt(topo)]
    $t run 
}

global argv arg0

runtest $argv

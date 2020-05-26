#
# LFN.tcl is a simulation script to study the relation between the
# optimal buffer size and link utilization.  This has been used in the
# Computer Networks course 6.829 at MIT.
#
# Xiaowei Yang 


Class TestSuite

Class Test/LFN -superclass TestSuite

proc default-options {} {
    global opt

    set opt(test) "LFN"
    set opt(outdir) "out"
    set opt(qtrace) "on"
    set opt(cwndtrace) "on"
    set opt(traceall) "on"
    set opt(namtrace) "off"
    set opt(autonam) "off"
    set opt(stoptime) 200
    set opt(startuptime) 5
    set opt(nconn) 1
    #set opt(filesize) 5000
    set opt(delay) 2ms
    set opt(bw) 100Mb
    set opt(qlen) 10
    set opt(bndelay) 16ms
    set opt(bnbw) 1.5Mb
    set opt(maxwin) 400
    set opt(maxseg) 1000
}

proc usage {} {
    
    global opt

    puts "Options:"
    puts "\t-test <LFN>. The test to run. Default: $opt(test)."
    puts "\t-outdir <value>. Data file output directory. Default: $opt(outdir)."
    puts "\t-qtrace <on/off>. Queue tracing on or off. Default: $opt(qtrace)."
    puts "\t-cwndtrace <on/off>. Congestion window tracing on or off. Default: $opt(cwndtrace)."
    puts "\t-traceall <on/off>. Trace all on or off. Default: $opt(traceall)."
    puts "\t-namtrace <on/off>. Nam tracing on or off. Default: $opt(namtrace)."
    puts "\t-autonam <on/off>. Execute nam at the end of simulation. Default: $opt(autonam)."
    puts "\t-stoptime <value>. The simulation stop time. Default: $opt(stoptime)."
    puts "\t-startuptime <value>. Each connection randoms starts between time 0 and value. Default: $opt(startuptime)."
    puts "\t-nconn <value>. Number of connections. Default: $opt(nconn)."
    puts "\t-filesize <value>. Length of transfer file size, in packets. Default: $opt(filesize)."
    puts "\t-delay <value>. Non-bottleneck Link Delay. Default: $opt(delay)."
    puts "\t-bw <value>. Non-bottleneck link bandwidth. Default: $opt(bw)."
    puts "\t-qlen <value>. Bottleneck max queue length. Default: $opt(qlen)."
    puts "\t-bndelay <value>. Bottleneck propagation delay. Default: $opt(bndelay)."
    puts "\t-bnbw <value>. Bottleneck bandwidth. Default: $opt(bnbw)."
    puts "\t-maxwin <value>. Maximum TCP window size. Default: $opt(maxwin)."
    puts "\t-maxseg <value>. Maximum TCP segment size. Default: $opt(maxseg)."
}


TestSuite instproc init {} {
    global opt
    $self instvar ns_ qmon S_ D_ R_ allf namf
    
    # set up topology
    remove-packet-header AODV ARP
    Trace set show_tcphdr_ 1
    Agent/TCP/FullTcp set segsize_ $opt(maxseg);
    Agent/TCP/FullTcp set window_ $opt(maxwin);

    set ns_ [new Simulator]
    #set allf [open "| awk -f script/xplot3.awk > $opt(outdir)/all.xpl" w]
    if {$opt(traceall) == "on"} {
	set allf [open "$opt(outdir)/all.out" w]
	$ns_ trace-all $allf
    }
    
    if {$opt(namtrace) == "on" } {
	set namf [open nam.out w]
	$ns_ namtrace-all $namf
    }
    
}

TestSuite instproc finish {} {
    global opt
    $self instvar ns_ allf qf cwndf namf
    
    if {$opt(traceall) == "on"} {
	flush $allf
	close $allf
    }
    
    if {$opt(qtrace) == "on"} {
	flush $qf
	close $qf
    }
    
    if {$opt(namtrace) == "on"} {
	flush $namf
	close $namf
    }
    
    if {$opt(cwndtrace) == "on"} {
	flush $cwndf
	close $cwndf
    }
    
    if {$opt(autonam) == "on"} {
	exec nam $opt(outdir)/nam.out &
    }
    #exec awk -f script/xplot3.awk  $opt(outdir)/all.out > $opt(outdir)/all-$opt(qlen).xpl &
    exit 0
}

Test/LFN instproc init {} {
    global opt
    
    $self instvar testName_
    $self set testName_ $opt(test)
    $self next
    $self create-topology
}

Test/LFN instproc create-topology {} {
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
	$ns_ duplex-link $S_($i) $R_(0) $opt(bw) $opt(delay) DropTail
	$ns_ duplex-link $R_(1) $D_($i) $opt(bw)  $opt(delay) DropTail
    }
    
    # set up bottleneck link
    $ns_ duplex-link $R_(0) $R_(1) $opt(bnbw) $opt(bndelay) DropTail
    $ns_ queue-limit $R_(0) $R_(1) $opt(qlen)
    
    if {$opt(qtrace) == "on"} {
	#set qf [open "| awk -f script/queue.awk > $opt(outdir)/queue-$opt(qlen).xpl" w]
	set qf [open  $opt(outdir)/queue-$opt(qlen).out w]
	set bnk [$ns_ link $R_(0) $R_(1)]
	$ns_ monitor-queue $R_(0) $R_(1) $qf
	$bnk start-tracing
    }
}

Test/LFN instproc run {} {
    global opt
    $self instvar ns_ R_ S_ D_ cwndf qf
    
    if {$opt(cwndtrace) == "on"} {
	#set cwndf [open "| awk -f script/cwnd.awk > $opt(outdir)/cwnd-$opt(qlen).xpl" w]
	set cwndf [open $opt(outdir)/cwnd-$opt(qlen).out w]
    }
    
    set rng [new RNG]
    
    for {set i 0} {$i < $opt(nconn)} {incr i} {
	set tcp [new Agent/TCP/FullTcp]
	set tcpsink [new Agent/TCP/FullTcp]
	$ns_ attach-agent $S_($i) $tcp
	$ns_ attach-agent $D_($i) $tcpsink
	$tcpsink listen
	$ns_ connect $tcp $tcpsink
    	set ftp [new Application/FTP]
	$ftp attach-agent $tcp
	if {$opt(cwndtrace) == "on"} {
	    $tcp attach $cwndf
	    $tcp tracevar cwnd_ 
	    #$tcp tracevar ssthresh_
	}
	set starttime [$rng uniform 0 $opt(startuptime)]
	#$ns_ at $starttime "$ftp produce $opt(filesize)"
	$ns_ at $starttime "$ftp start"
    }
    $ns_ at $opt(stoptime) "$self finish"
    $ns_ run
}

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

    set t [new Test/$opt(test)]
    $t run 
}

global argv arg0

runtest $argv



#
# Helper script. Works with AQM.tcl. Assume FullTCP show_hdr
# formate. $8 is the flow id. 
# Compute goodput of TCP, throughput of other sources
# Compute loss rate
# Compute link utilization
# Works only for dumpbell topologies, where nodes i < nconn are
# sources, 2*nconn > i >= nconn are destinations, 2*nconn is the router
# connecting all sources, and 2*nconn+1 is the router connecting all
# destinations.
# This has been used in the Computer Networks course 6.829 at MIT.
#
# Xiaowei Yang 

BEGIN {
    nconn = 2;
    for (i = 0; i < nconn; i++) {
#	src[i] = i;
	dst[i] = nconn + i;
	bytes[i] = 0;
	start[i] = 0;
	virgin[i] = 1;
	loss[i] = 0;
	total[i] = 0;
	prevT[i] = 0;
	prevB[i] = 0;
	prevL[i] = 0;
	prevP[i] = 0;
    }
    prefix = "";
    interval = 1.0;
    loss_interval = 100;
    startuptime = 25;
    bw = 1500000;
    totalB = 0;
    prevtotalB = 0;
    prevtotalT = 0;
}

{
    if (NR == 1) {
	split(FILENAME, a, "-");
	if (a[1] == "") {
	    a[1] = prefix;
	}
    }
    # compute tcp throughput. only count data bytes, no header.
    tcpput = (($1 == "+") && ($5 == "ack") && ($3 >= nconn) && ($3 < 2*nconn));
    nontcpput = (($1 == "r") && (($5 == "cbr") || ($5 == "pareto")) && ($3 == (2 * nconn + 1)));
    
    if (tcpput || nontcpput) {
	fid = $8;
	if (virgin[fid]) {
	    start[fid] = prevT[fid] = $2;
	    virgin[fid] = 0;
	} else {
	    if (tcpput) {
		bytes[fid] = $13;
	    } else {
		bytes[fid] += $6;
	    }
	    printf "%f %6.5f\n", $2,  bytes[fid] * 8.0 / ($2 - start[fid]) > a[1]"-tput-"fid".dat";
	    if (($2 - prevT[fid]) > interval) {
		printf "%f %6.5f\n", $2, (bytes[fid] - prevB[fid]) * 8.0 / ($2 - prevT[fid]) > a[1]"-stput-"fid".dat";
		prevT[fid] = $2;
		prevB[fid] = bytes[fid];
	    }
	}
    }
    
    if (($1 == "+") && ($4 == (2 * nconn))) {
	fid = $8;
	total[fid]++;
	printf "%f %6.5f\n", $2, loss[fid] * 1.0 / total[fid] > a[1]"-loss-"fid".dat";
	if ((total[fid] - prevP[fid]) > loss_interval ) {
	    printf "%f %6.5f\n", $2, (loss[fid] - prevL[fid]) / (total[fid] - prevP[fid]) > a[1]"-sloss-"fid".dat";
	    prevP[fid] = total[fid];
	    prevL[fid] = loss[fid];
	}
    }
    
    if ($1 == "d") {
	fid = $8;
	loss[fid]++;
    }

    if (($1 == "-") && ($3 == 2*nconn) && ($4 == (2*nconn + 1))) {
	totalB += $6;
	if ($2 - prevtotalT > interval) {
	    printf "%f %6.5f\n", $2, (totalB - prevtotalB) * 8.0 / ($2 - prevtotalT) / bw > a[1]"-linkutil.dat";
	    prevtotalB = totalB;
	    prevtotalT = $2;
	}
    }
}

BEGIN {
    nconn = 2;
    for (i = 0; i < nconn; i++) {
	loss[i] = 0;
	total[i] = 0;
    }
    startup = 2;
}

{
    if (($1 == "+") && ($4 == (2 * nconn))) {
	total[$8]++;
    }

    if ($1 == "d") {
	loss[$8]++;
    }
}

END {
    for (i = 0; i < nconn; i++) {
	printf "%d %6.5f\n", i, loss[i] * 1.0 / total[i]; 
    }
}

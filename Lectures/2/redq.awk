{
if ($1 == "Q" && NF>2) 
    print $2, $3 > Qfile 
else if ($1 == "a" && NF>2)
		    print $2, $3 > afile
}



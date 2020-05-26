/*
 * A libasync client for the web-like server.
 * 
 * Note: fd 1 is standard output
 */

void start_connect (char *host, int port, char *filename);
void write_request (int s, char *filename);
void read_data (int s);
void write_data (int s, char *buf, int len);

int
main (int argc, char *argv[])
{
  char *host;
  int port;
  char *filename;
  int r; 

  assert (argc == 4);
  host = argv[1];
  port = atoi (argv[2]);
  filename = argv[3];

  make_async (1);

  start_connect (host, port, filename);
  /* start_connect (host2, port2, filename2); */

  amain ();
}

void start_connect (char *host, int port, char *filename)
{
  int r, s;
  struct sockaddr_in sin;

  /* Setup the socket and make it asynchronous! */
  s = socket (AF_INET, SOCK_STREAM, 0);
  make_async (s);

  /* Make the connection; get ready for select */
  bzero (&sin, sizeof (sin));
  sin.sin_family = AF_INET;
  sin.sin_port = htons (port);
  inet_aton (host, &sin.sin_addr);
  connect (s, (struct sockaddr *) &sin, sizeof (sin));
  /* This no longer blocks! */

  fdcb (s, selwrite, wrap (write_request, s, filename));
}

void write_request (int s, char *filename)
{
  write (s, filename, strlen (filename));
  write (s, "\n", 1);

  fdcb (s, selwrite, NULL);
  fdcb (s, selread, wrap (read_data, s));
}

void read_data (int s)
{
  int r;
  /* char buf[1024]; */ /* WRONG! */
  char *buf = (char *) malloc (1024);
  r = read (s, buf, 1024);

  fdcb (s, selread, NULL);
  if (r > 0) {
    fdcb (1, selwrite, wrap (write_data, s, buf, r));
  } else {
    close (s);
    exit (0);
  }
}

void write_data (int s, char *buf, int len)
{
  write (1, buf, len);
  free (buf);
  fdcb (1, selwrite, NULL);
  fdcb (s, selread, wrap (read_data, s));
}
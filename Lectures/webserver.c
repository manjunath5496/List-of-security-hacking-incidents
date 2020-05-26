/*
 * A web-like server. Fully functional, but no error checking
 * and not secure. Two versions: server_1() uses only one
 * process, while server_2() forks a new process for each client.
 */

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/wait.h>

/* s1 is a TCP socket from a client */
handle(int s1)
{
  char request[1024], buf[8192];
  int i = 0, n, fd;
  char c;

  /* Read the request (a file name) from the client. */
  while(read(s1, &c, 1) == 1 && c != '\n' && c != '\r'
        && i < sizeof(request)-1)
    request[i++] = c;
  request[i] = '\0';

  /* Open the file, send the contents to the client. */
  fd = open(request, 0);
  while((n = read(fd, buf, sizeof(buf))) > 0)
    write(s1, buf, n);
  close(fd);
  close(s1);
}

setup()
{
  int s;
  struct sockaddr_in sin;

  /* Allocate a TCP/IP socket. */
  s = socket(AF_INET, SOCK_STREAM, 0);
  
  /* Listen for connections on port 80 (http). */
  bzero(&sin, sizeof(sin));
  sin.sin_family = AF_INET;
  sin.sin_port = htons(80);
  bind(s, &sin, sizeof(sin));
  listen(s, 128);

  return(s);
}

server_1()
{
  int s, s1, addrlen;
  struct sockaddr_in from;

  /* create a TCP socket that listens for HTTP connections */
  s = setup();

  while(1){
    /* Wait for a new connection from a client. */
    addrlen = sizeof(from);
    s1 = accept(s, &from, &addrlen);

    /* Perform the client's request. */
    handle(s1);
  }
}


server_2()
{
  int s, s1, addrlen, status;
  struct sockaddr_in from;

  s = setup();

  while(1){
    /* Wait for a new connection from a client. */
    addrlen = sizeof(from);
    s1 = accept(s, &from, &addrlen);

    /* Create a new child process. */
    if(fork() == 0){
      /* Perform the client's request in the child process. */
      handle(s1);
      exit(0);
    }
    close(s1);

    /* Collect dead children, but don't wait for them. */
    waitpid(-1, &status, WNOHANG);
  }
}

main()
{
  server_1();
  /* server_2(); */
}
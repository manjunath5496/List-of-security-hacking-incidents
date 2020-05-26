/*
 * syscall.c
 */



/*
Conceptual UNIX system call life-cycle.

Application:
  close(3);

C library:
  close(x) {
    R0 <- 73
    R1 <- x
    TRAP
    RET
  }

TRAP instruction (like 6.004 Beta):
  XP <- PC
  switch to kernel address space
  set privileged flag
  PC <- address of kernel trap handler

Kernel trap handler:
  save registers to this process's "process control block" (PCB)
  set SP to kernel stack
  call sys_close(), an ordinary C function
  ... now executing in the "kernel half" of the process ...
  restore registers from PCB
  TRAPRET

TRAPRET instruction:
  PC <- XP
  clear privileged flag
  switch to process address space
  continue execution
*/
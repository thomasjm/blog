---
layout: post
title: Haskell's slow close_fds problem
---

On most Linux systems, the following simple Haskell program will print "hiii" immediately. But with one simple configuration change, it can bring your system to its knees for several minutes.

```haskell
module Main where

import System.Process

main :: IO ()
main = do
  (_, _, _, p) <- createProcess (shell "echo hiii")
  _ <- waitForProcess p
  return ()
```

Can you guess the configuration change?

<details style="margin-bottom: 1em">
    <summary>Spoiler warning</summary>

    The configuration change is to run <code>ulimit -n 1073741815</code>.

    (You might have to raise your system's hard limit and/or any user-specific limits before you can do this.)
</details>


Why does this happen? Well, the default `CreateProcess` values used in `System.Process` contain the flag `close_fds=True`. This is the flag that says to close all the file descriptors from the parent process before `exec`-ing the child process, and it's pretty important from a security perspective.

Processing this flag eventually leads into some C code that looks like this:

```c
if ((flags & RUN_PROCESS_IN_CLOSE_FDS) != 0) {
    int max_fd = get_max_fd();
    // XXX Not the pipe
    for (int i = 3; i < max_fd; i++) {
        if (i != forkCommunicationFds[1]) {
            close(i);
        }
    }
}
```

We're brute-force looping over all possible file descriptors available to the process in order to close them all!

The rest of this post explores how this might be fixed and what other programming languages have done about it.

By the way, I first encountered this problem on a somewhat unusual system (NixOS running a Kind Kubernetes cluster). On a more normal system like my Ubuntu laptop, the file descriptor limit is 1M. If your system is the same, this means that on every such `fork/exec` your Haskell program is doing 1 million unnecessary syscalls. It's not a huge catastrophe for most workloads--I had never noticed it before--but it's not great.

### A zoo of platform-specific solutions

https://github.com/python/cpython/blob/main/Modules/_posixsubprocess.c
https://peps.python.org/pep-0446/#related-work
https://bugs.python.org/issue1663329

### How stable are syscalls really?

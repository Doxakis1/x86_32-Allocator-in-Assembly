# x86_32-Allocator-in-Assembly
I made a simple malloc implementation in x86 assembly. The heap is resizable to your needs but please remember to free memeory :c
#How to use my malloc

1) call reserve_init() with no arguments if it returns non-zero value, something didnt go well
   
3) Use reserve() with the size in eax if it return zero, there was an error

4) Use free() with the address of the memory to free on eax if error occurs 1 will be returned to eax, else 0

5) Use reserve_clear() with no arguments when you no longer need the heap, so it gets freed (before you exit)
       You can however call reserve_init() again whenever you want to get heap again

Cheers!

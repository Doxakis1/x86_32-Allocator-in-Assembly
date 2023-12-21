# x86_32-Allocator-in-Assembly
I made a simple malloc implementation in x86 assembly. The heap is resizable to your needs but please remember to free memeory :c
#How to use my malloc

1) call reserve_init() with no arguments
    if it returns non-zero value, something didnt go well
2) Use reserve() with the size in eax
    if it return zero, there was an error
3) Use free() with the address of the memory to free on eax
    if error occurs 1 will be returned to eax, else 0

Cheers!

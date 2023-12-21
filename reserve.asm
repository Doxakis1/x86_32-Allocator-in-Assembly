; The function takes the number of bytes needed in EAX and returns the address of the allocation in EAX
; if the allocation failed 0 is returned
; EAX will be handled as UNSINGED INT32

%define HEAP_SIZE  1048576 ; I will make the original size be 2 ^ 20 but I  allow expansion
%define sys_brk 45 
%define sys_exit 1
%define NODE_FREE 424242
%define NODE_ALLOCED 696969
section .data
section .bss
    brk_start resd 1 ; holds heap start
    brk_end   resd 1 ; holds heap finish

section .text
    global reserve
    global free
    global _start
    global reserve_init
    global reserve_clear

reserve_clear: ; call at start of the program
    push ebp
    mov ebp, esp
    mov ebx, [brk_start]
    mov eax, sys_brk
    int 0x80
    mov [brk_end], ebx
    mov esp, ebp
    mov eax, 1
    pop ebp
    ret


reserved_init: ; this is only called by the reserve function if initial heap hasnt been allocated
; returns a non-zero value on eax if everything happened properly, else 0
    push ebp
    mov ebp, esp
    
    ; NOTE: Revise the flag instructions
    ; if brk fails it sets the carry flag on so I guess I will unset it first and then check if it is on after the int
    CLC
    mov eax, sys_brk
    mov ebx, dword 0
    int 0x80 ; brk(0)
    jc _reserved_init_error
    ; if we get here means succesful and we got the brk_start
    mov [brk_start], eax ;
   
    ; calculating new end
    mov ebx, dword HEAP_SIZE
    add ebx, eax ; now ebx holds original brk_start + our desired heap size
    mov eax, sys_brk
    int 0x80 ; brk(brk_start + HEAP_SIZE)
    jc _reserved_init_error
    ; if we get here means succesful
    mov [brk_end], eax
    mov eax, dword [brk_start]
    lea esi, [eax]
    mov ebx, dword HEAP_SIZE
    sub ebx, dword 8 ; int[2] for the head data
    mov [esi], ebx ; int[0] =  HEAP_SIZE - 2 * sizeof(int)
    lea esi, [eax + 4]
    mov [esi], dword NODE_FREE ;  int[1] = NODE_FREE 
    jmp _reserved_init_ret
_reserved_init_error:
    mov eax, dword 0
_reserved_init_ret:
    mov esp, ebp
    pop ebp
    ret

reserve_more_heap:
    push ebp
    mov ebp, esp
    mov ebx, dword [brk_end]
    add ebx, dword HEAP_SIZE
    jo _reserve_more_heap_error ; checks if size overflows uint32
    mov eax, sys_brk
    int 0x80
    cmp eax, 0
    je _reserve_more_heap_ret
    mov [brk_end], eax
    jmp _reserve_more_heap_ret
_reserve_more_heap_error:
    mov eax, 0
_reserve_more_heap_ret:
    mov esp, ebp
    pop ebp
    ret
reserve:
    push ebp
    mov ebp, esp
    sub esp, 24 ; in[6]
    mov [esp] , eax ; int[0] = requested_size
    mov eax, dword [brk_start] ; int[1] = brk_start
    mov [esp+4], eax
    mov eax, dword [brk_end]  ; int[2] = brk_end
    mov [esp+8], eax
    mov [esp+12], dword 0 ; int[3] = 0
    mov [esp+16], dword 0 ; int[4] = 0
    mov [esp+12], dword 0 ; int[5] = 0

_reserve_find_loop: ; find chuck were we can fit our size held bt int[0]
    ; get  chunck_data:
    mov eax, dword [esp+4]
    lea esi, [eax]
    mov ebx, dword [esi] 
    mov [esp+12], ebx ; int[3] = current_node.size
    lea esi, [eax+4]
    mov eax, dword [esi]  
    mov [esp+16], eax ; int[4] = current_node.type
    cmp eax, dword NODE_ALLOCED
    je _reserve_next_node
    mov edx, dword [esp]
    cmp ebx, edx
    jnae _reserve_next_node ; if (node.type == NODE_ALLOCED || node.size < requested)
    ; we come here if we found a location where we have enough memory for our requested chunck
    mov eax, dword [esp+4]
    lea esi, [eax+4]
    mov [esi], dword NODE_ALLOCED ; update nodes type to alloced
    lea esi, [eax]
    mov edx, dword[esp] ; requested size
    mov [esi], edx ; move new size to chuck head
    mov eax, dword [esp+4] ; node start
    mov ebx, dword [esp+12] ; previous size
    mov ecx, dword [esp] ; requested size
    sub ebx, 8 ; node head size
    cmp ecx, ebx ; if ecx < ebx + 8 then we have memory left to make a new chunck under
    jae _update_heap_node_nonew
    mov eax, dword [esp+4]
    mov ebx, dword [esp]
    add eax, ebx
    add eax, 8 ; add chuck_size and sizeof(header)
    lea esi, [eax+4]
    mov [esi], dword NODE_FREE
    lea esi, [eax]
    mov ebx, dword [esp+12]
    mov edx, dword [esp]
    ; new_chuck_data.type = NODE_FREE
    ; new_chuck_data.size = prev_size - requested size - 8
    add edx, dword 8
    sub ebx, edx
    mov [esi], ebx
    mov eax, dword [esp+4] 
    add eax, dword 8 ; return the address of the allocated area
    jmp _reserve_ret
_update_heap_node_nonew: ; if there is no memory to declare a new free node under our allocation
; we then make the previous now allocated node have the same size as the previous free had
    mov eax, dword [esp+4]
    mov ebx, dword [esp+12]
    lea esi, [eax]
    mov [esi], ebx
    add eax, dword 8
    jmp _reserve_ret
_reserve_next_node:
    mov ebx, dword [esp+12] ; chuncks size
    mov edx, dword [esp+4]
    add edx, dword 8
    add edx, ebx ; add chuck size + 8 to skip chuck data size
    mov eax, dword [esp+8]
    cmp edx, eax
    jb _reserve_next_inc
    call reserve_more_heap
    cmp eax, 0
    je _reserve_error
    mov eax, [esp+16] ; prev_nodes.type
    cmp eax, dword NODE_ALLOCED
    je _reserve_next_newheap
    mov eax, [esp+4] ; if previous was free we just extend it
    lea esi, [eax]
    mov eax, dword [esi]
    add eax, dword HEAP_SIZE ; no need to check for overflow since the node can never overflow in size if the heap hasnt overflowed which is captured in reserve_more_heap
    mov [esi], eax
    jmp _reserve_find_loop ; we jump back to see if the new node size is enough for the caller
_reserve_next_newheap:
    lea esi, [edx]
    mov [esi], dword HEAP_SIZE
    add esi, 4
    mov [esi], dword NODE_FREE
_reserve_next_inc:
    mov [esp+4], edx ; hold next node location
    jmp _reserve_find_loop
_reserve_error:
    mov eax, dword 0
_reserve_ret:
    mov esp, ebp
    pop ebp
    ret

free: ; needs eax to hold the address we want to free for now will return 1 on eax if error happens
    push ebp
    mov ebp, esp
    sub esp, 20 ; int[4]
    mov [esp], eax ; address_to_free
    mov eax, dword [brk_start]
    mov [esp+4], eax ; start of heap
    mov [esp+12], eax ; start of heap here too
    mov eax, dword [brk_end]
    mov [esp+8], eax ; end of heap

_free_check_node: ;the node we are checking can be invalid if 2 things happen
; There is no valid header before it
; If we treverse the heap we dont land on it
    mov eax, dword [esp]
    lea esi, [eax-4] ; to get chunck type
    mov eax, dword [esi] 
    cmp eax, dword NODE_ALLOCED
    jne _free_error
    mov eax, dword [esp]
    lea esi, [eax-8] ; to get chunck type
    mov eax, dword [esi] 
    mov [esp+16], eax ; hold the size
_free_find_previous:
    mov eax, dword [esp+4]
    mov ebx, dword [esp+8]
    cmp eax, ebx
    jae _free_error ; node is not part of our tree
    mov ebx, dword [esp]
    sub ebx, 8
    cmp eax, ebx
    je _free_found_myself
    mov [esp+12], eax ; hold previous node start
    lea esi, [eax]
    mov ebx, dword [esi]
    add ebx, 8
    add eax, ebx
    mov [esp+4], eax
    jmp _free_find_previous
_free_found_myself:
    mov eax, [esp+12]
    mov ebx, [esp]
    cmp eax, ebx
    je _free_check_next_node
    lea esi, [eax+4]
    mov eax, dword[esi]
    cmp eax, dword NODE_FREE
    jne _free_check_next_node
    mov eax, [esp+12]
    lea esi, [eax]
    mov ebx, dword [esi]
    mov edx, dword [esp+16]
    add edx, dword 8
    add ebx, edx
    mov [esi], edx
    mov eax, [esp+12]
    add eax, dword 8
    mov [esp], eax
_free_check_next_node:
    mov eax, [esp]
    lea esi, [eax-8]
    mov ebx, dword [esi]
    mov eax, [esp]
    lea esi, [eax+ebx] ; next node
    mov ecx, dword [esp+8]
    mov eax, esi
    cmp eax, ecx
    jae _free_end
    add esi, 4
    mov edx, dword [esi]
    cmp edx, dword NODE_FREE
    jne _free_end
    ; if we get here, next node is also free
    sub esi, 4
    mov eax, dword [esp]
    mov ebx, dword [esi]
    lea esi, [eax-8]
    mov eax, dword [esi]
    add eax, ebx
    add eax, dword 8
    mov [esi], eax ; added the next free chunck size to our chucnk size
_free_end:
    mov eax, [esp]
    lea esi, [eax-4]
    mov [esi], dword NODE_FREE
    mov eax, dword 0
    jmp _free_ret
_free_error:
    mov eax, dword 1
_free_ret:
    mov esp, ebp
    pop ebp
    ret

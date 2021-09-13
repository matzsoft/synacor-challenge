5483: set r0, 4
5486: set r1, 1
5489: call 6027
5491: eq r1, r0, 6
5495: jf r1, 5579       # Don't take this branch!
5498: push r0
...
6027: jt r0, 6035
6030: add r0, r1, 1
6034: ret
6035: jt r1, 6048
6038: add r0, r0, 32767
6042: set r1, r7
6045: call 6027
6047: ret
6048: push r0
6050: add r1, r1, 32767
6054: call 6027
6056: set r1, r0
6059: pop r0
6061: add r0, r0, 32767
6065: call 6027
6067: ret



r0 = 4
r1 = 1
call function
a: if r0 == 6
    push r0          # This is where you want to be!
...
function function()
    if r0 == 0
        r0 = r1 + 1
        return
    if r1 == 0
        r0 -= 1
        r1 = r7
        call function
        b: return
    push r0
    r1 -= 1
    call function
    c: r1 = r0
    pop r0
    r0 -= 1
    call function
    d: return

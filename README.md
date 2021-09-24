# Synacor Challenge

This repository contains my notes and solution for the [Synacor Challenge](https://challenge.synacor.com/). This is a programming puzzle created by Eric Wastl, the man who gave us [Advent of Code](https://adventofcode.com). What follows is my description of how I solved the challenge. Be aware that there are spoilers, so if you want to solve the challenge yourself stop reading now.

## Getting Started

When you sign up on the website you receive a download containing the architectural description of a virtual machine and a binary file with the initial memory of a program that runs on that machine. The description file also contains some hints and the first of eight codes to be entered into the website to record your progress.

Implementing the virtual machine was very straight forward so I decided to complete that first. But one of the hints was that you only needed to implement 3 instructions to get started. So, I did that and was rewarded with a welcome message and the second of the eight codes. The welcome message gives the next hint, the virtual machine must pass a self-test. So, I implemented the remaining instructions. Now running again, the self-test passes, a third code is revealed, and you enter the beginning of text-based adventure game. There are obvious references to Advent, Zork, and the many that followed.

## Let There be Light

The beginning of the game is quite simple. I saw no need to draw a map until I had discovered an empty lantern, an area of deadly Darkness, and a maze of Twisty Passages at the bottom of a ladder. The passages are not quite as all alike as they first seem so I was able to map the maze without resorting to dropping items. I soon discovered two more entrances to the Darkness. At this point I was unsure if all three areas of Darkness were the same or different.

Next, I decided I needed to be able to save my game and restore it to avoid the trek from the foothills to the ladder. This first implementation allowed for only a single save and kept it in memory. But even this simple tool made it much easier to map the maze.

Once I fully mapped the maze, I found the can of oil and that allowed me to light the lantern. I then found that the two areas of Darkness at the bottom of the ladder were the same and uninteresting. Now it was time to go back up the ladder.

[Ladder Map](ladderMap.png)

[Darkness Map](darknessMap.png)

## The Ruins

The Darkness above the ladder was much more interesting. Too simple to map but you find five coins and puzzle to solve using them.

Coins Values
- Red      = 2
- Blue     = 9
- Concave  = 7
- Shiny    = 5
- Corroded = 3

The puzzle was to place the five coins in the five slots in the correct order to solve the equation displayed on the monument. I was able to deduce that only certain values could go in the squared and cubed slots. This allowed me to find the answer by hand in only three tries.

9 + 2 * 5^2 + 7^3 - 3 or Blue, Red, Shiny, Concave, and Corroded

Solving the puzzle opened a door leading to the next part of the challenge.

## The Teleporter

Once you solve the puzzle of the coins, you are granted access to a room containing a teleporter. The obvious thing to do is to take and use it. This leads you to a new area that is largely useless except for a strange book. The book explains what you need to proceed. You must hack the program controlling the game in order to change the "eighth" register, or r7. This will allow you to make the teleporter take you to an alternate location.

### Debug Mode and Trace

As a way to interact with the virtual machine was needed, I decided to implement a debug mode. The first capability I gave it was tracing. So, I could take the teleporter, turn trace on, use the teleporter, and then dump the trace buffer for analysis. This gave me a remarkably small output that allowed me to easily see where the check for `r7 == 0` was performed. Then of course the code branched off to Synacor headquarters so I needed a way to bypass that check.

### Breakpoints and Probing.

The next additions to debug mode were the ability to examine and modify memory, the registers, and the instruction pointer (ip). So, this time I set r7 to one just before using the teleporter to see what would happen. Then the game entered the confirmation process which was claimed to take billions of years to complete. Examination of the trace this time showed a call to a small, but deeply recursive subroutine. So, I decided to add breakpoints to my debug mode.

Now I could set a breakpoint at the call. When the breakpoint was reached, I changed the ip to skip the call and let it proceed. This caused a miscalibration to be detected and the teleportation to be aborted. Now the trace showed what was expected from the confirmation call. So, I ran again. This time when the breakpoint was hit, I changed the ip to the destination of the successful confirmation.

This gave a better result. I was teleported to a new location, a beach. Also, my seventh code was revealed. But when I entered it into the website the code was invalid. Now the trace showed that the value of r7 was used to generate the seventh code. So as stated in the book, the value of r7 needed to be correct and for that I needed to understand the confirmation code.

### Disassembly

The trace output is good for tracking program flow, but not so good for understanding a particular section of the code. So, I added a disassemble option to debug mode. When given an address, it starts disassembling from there understanding the effect of each instruction on the control flow. This creates branches of disassembly. When all branches are exhausted the output is sorted for readability. From the output I was able to extract:

[The confirmation routine](confirmation.asm)

It's amazing that such a small amount of code can produce such deep recursion and still produce a meaningful result. At first, I tried following the code by hand and keeping track of r0, r1, and the stack on paper, looking for patterns. This quickly became tedious and error prone. So, I added some more to debug mode.

### Stack Trace

I implemented a mode similar to trace mode, but it only traced instructions that affect the stack. These are push, pop, call, and ret. I had this create a table with ip, opcode, value pushed to or popped from the stack, r0, r1, and a cross reference column. So, for example, the cross reference of a pop instruction is the row number in the table of the push instruction that pushed that value. This output gave me some insight into what was going on but also made it clear that the recursion depth was too great to continue on this path. It did strengthen the nagging feeling that there was something familiar about this code.

### The Ackermann Function

Finally, a bell went off and I recognized that we had the Ackermann function with a twist (or two).

- Original

```
A(0,n) = n + 1
A(m,0) = A(m-1,1)
A(m,n) = A(m-1,A(m,n-1))
```

- With a Twist

```
A(0,n) = n + 1
A(m,0) = A(m-1,r7)
A(m,n) = A(m-1,A(m,n-1))
```

So, I implemented the twisty little function, but with memoization as I knew that was an essential optimization. This worked great for `r7 == 1` but blew out my stack at `r7 == 2`.

Next, I reimplemented the function without recursion. Again, this worked fine at `r7 == 1` but was still running for `r7 == 2` when I noticed that my memory footprint was up to 30GB. After a lot of head scratching, I realized that I had missed the second twist.

That second twist was the 15-bit arithmetic. This puts an upper limit on the `n + 1`, the only place where a value increases, and greatly reduces the recursion depth. So now I had code that could calculate the confirmation function quickly and I could proceed.

### Solving the Teleporter

In my investigations I noticed that the even/odd bit of r7 was always the same as the function result. This allowed me to only search the even values of r7 as I was looking for a result of 6. So, I implemented a command `solve teleporter` that:

1. Scans the even values to find the correct value for r7.
2. Sets r7 to that value (25734).
3. Changes the call to the confirmation function to two noop instructions.
4. Modifies the instruction that checks the return value so that it always returns true.

So now I can say `solve teleporter` and `use teleporter` and I go to the beach with the correct seventh code (hBkeilrLOQAn).

## The Beach and the Vault

I figured that since I had seven of the eight codes, I was now in the endgame and it would be more difficult than before. So, I started making a map of the beach area immediately. It turns out that wasn't needed.

[Beach Map](beachMap.png)

The only thing of importance here is the journal, which describes what you face in the vault ahead. Once you get to the vault, a map is helpful.

[Vault Map](vaultMap.png)

Now your task is to transform the weight of the orb from its initial value of 22 to the desired value 30 by taking the correct path through the vault. Visual inspection of the map gave me two easy candidates but when I arrived at the vault the hourglass had expired.

Knowing the author's fondness for the Manhattan Distance I mentally checked all 20 paths with the minimum distance with no success. So, I decided to write code to find the shortest path. A simple breadth first search did the trick.

So, I implemented a `solve vault` command that takes the orb, calculates and navigates the correct path. Running this command from the Vault Antechamber leaves you at the unlocked vault door.

Entering the vault reveals untold riches and a mirror. Using the mirror reveals that the final code is written on your forehead. But when I entered this code, it was rejected. I racked my brain trying to figure out what I could have done wrong until I realized it was a mirror. By design all the letters in the code were either symmetrical or transformed to another valid letter in the mirror. Once I flipped the code I was done.

## The Code for the Solution

I implemented my solution in Swift, my current language of choice. There are five source files.

### main.swift

This file is the entry point.  It merely changes the working directory to where the `challenge.bin` file resides and then creates a `Game` structure referencing that file and calls its `interactive` method.

### Utils.swift

This file just contains two things.  The first is the `RuntimeError` structure definition.  This structure is used for throwing exceptions for unexpected errors.  The second is the definition of the `switchToDirectory` function used by `main.swift`.

### SynacorCode.swift

This is the biggest of the source files.  It contains the simulator for the virtual machine that is at the heart of the challenge.  The most important method is `step` which executes a single instruction. But there are also methods to do the grunt work of the trace, stack trace, and disassembly functions.

### Game.swift

This file provides the interface between the parson playing the game and the virtual machine.  It accepts input from the terminal, processes any metacommands, and passes the rest to the virtual machine.  Any output produced by the virtual machine is displayed on the terminal.  All the debug mode commands are handled here; including breakpoints, tracing, etc.

### Vault.swift

This file is used to find the optimal solution to the vault. I want to give a shout out here to Swift's `enum` with associated values which allows me to define the map of the vault in a way that visually corresponds to the grid of the vault.

```
        map = [
            [ Node.operation( * ), Node.value( 8 ),     Node.operation( - ), Node.target( 1 )    ],
            [ Node.value( 4 ),     Node.operation( * ), Node.value( 11 ),    Node.operation( * ) ],
            [ Node.operation( + ), Node.value( 4 ),     Node.operation( - ), Node.value( 18 )    ],
            [ Node.start,          Node.operation( - ), Node.value( 9 ),     Node.operation( * ) ],
        ].reversed()
```
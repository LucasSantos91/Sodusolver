Fastest Sudoku solver.

Clues are given through standard in. Pass clues as such: A12, where A is the row, 1 is the column and 2 is the digit.

Example:
```
echo B63 B88 B95 C31 C52 D45 D67 E34 E71 F29 G15 G87 G93 H32 H51 I54 I99 | Sodusolver.exe

Given grid:
  1 2 3 4 5 6 7 8 9
 *******************
A* | | * | | * | | *
 -------------------
B* | | * | |3* |8|5*
 -------------------
C* | |1* |2| * | | *
 *******************
D* | | *5| |7* | | *
 -------------------
E* | |4* | | *1| | *
 -------------------
F* |9| * | | * | | *
 *******************
G*5| | * | | * |7|3*
 -------------------
H* | |2* |1| * | | *
 -------------------
I* | | * |4| * | |9*
 *******************
 ```

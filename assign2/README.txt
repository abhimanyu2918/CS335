Submitted by: Abhimanyu, Shresth Soni and Shubhojyoti Nath

-Run 'make' to generate codegen binary.
-Run 'make clean' to remove 'bin' directory.
-'test' directory contains IR codes for testing

INTERMEDIATE CODE SPECIFICATION
---------------------------------------------------------------------------------------------------
Syntax: line_number, operator, arg1, [arg2, ...]

Details:
1. Mathematical Operations ['+', '-', '*', '/', 'rem', '&', '|', '<<', '>>']
line, operator, destination, arg1 (variable or integer), arg2 (variable or integer)
2. Function Calls
line, call, function_name
3. Code Labels
line, label, label_name
4. Conditional Jumps ['<=', '>=', '==', '>', '<', '!=']
line, ifgoto, condition, operand1, operand2, jump_location (label or line)
5. Unconditional Jumps
line, goto, jump_location (label or line)
6. Exit Call
line, exit
[NOTE: There is only one exit in whole IR code that is to exit the main function.]
7. Print Instruction
line, print, variable_name (or integer)
8. Assignment Instruction
line, =, destination_var, source_var (or integer)
9. Function Definitions
line, function, function_name
10. Return from Function
line, return, value (variable or integer)
[NOTE: Return must be passed a value and function must end with return IR code.]
11. Take an integer input
line, scanint
12. Read return value from function into a variable
line, getreturnval, variable_name
13. Read from array
line, readarr, array_name, index (variable or integer), variable_to_store_value
14. Write into array
line, writearr, array_name, index (variable or integer), value_to_write (variable or integer)
15. Negation Instruction
line, ~, destination_var, soure (variable or integer)

Note that the function definitions must be in the end of the program

RUNNING THE GENERATED ASSEMBLY CODE
---------------------------------------------------------------------------------------------------
spim xspim test.s

THE DESCRIPTION OF DATA STRUCTURES DEFINED IN CODEGEN.C IS AS FOLLOWS:
---------------------------------------------------------------------------------------------------
1. IRCode
The contents in the intermediate representations of every instruction. IRCodeArray is array of IRCode structs (one index per line).

2. SymbolTable
The list of variable names found in the Intermediate Code along with other information like whether any variable is currently live and when it will be used again.

3. RegDescriptor
Array of 8 entries for each register from t0-t7 that stores what variable each register is holding.

4. NextUseTable
An array of size equal to number of lines which stores what variables are dead and their next use for each line.

5. AddrDescEntry
An array of size equal to number of variable that store where is most recent value of a variable stored.

THE DESCRIPTION OF THE FUNCTIONS DEFINED IN CODEGEN.C IS AS FOLLOWS:
---------------------------------------------------------------------------------------------------
1. void pushVarNode(struct VarNode** head_ref, char* data)
Pushes a node corresponding to a new variable with the given data passed as an argument in the linked-list starting from head_ref.
2. void printVarList(struct VarNode *node)
Prints the entire linked-list of variable nodes.
3. bool isValidNumber(char * string)
Checks whether a string is a valid number (positive or negative).
4. void addrDescinit()
Initialises AddressDescriptor array to set all entries to "mem"
5. void symbTableinit()
Creates and initialises SymbolTable.
6. void regDescinit()
Initialises RegisterDescriptor to "EMPTYREG" for all registers.
7. char * getAddDesc(char * variable)
Return location of variable from address descriptor table. Returned value is a register or "mem".
8. void setAddDesc(char * variable, char * location)
Modifies address descriptor table entry for the particular variable and sets it's entry to the given location.
9. void setRegDesc(int reg, char *variable)
Puts content corresponding to a variable in the specified register.
10. int getRegNum(char *variable)
Returns the registor number corresponding to (storing) a variable, otherwise returns -1.
11. void storeAllInMem()
Store all variables that are in registers to memory.
12. int getReg(char * variable, int Line, int dont_touch_reg1, int dont_touch_reg2)
This is an important function. The function takes the variable and instruction number as parameters and implements the spilling. It gets the register from the nextuseTable. dont_touch_reg(i), i =1, 2 specify the registors (if any) which should not be touched during the registor allocation process as they have been allocated to other variables used in the same instruction.
13. void translate(int lineNum)  
Translates the instruction given in the line number "lineNum" into assembly code.


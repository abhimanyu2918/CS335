#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

typedef struct Sym_Entry{
    char iden_name[15];
    int var_type;
    int arr_size;
    int structIndex;
    char ref_name[15];
}Sym_Entry;

typedef struct SymbolTableStruct
{
  struct Sym_Entry Table[150];
  int offset;
  int curr_offset;
  int var_count;
  struct SymbolTableStruct * parent;
}SymbolTableStruct;

extern FILE * stringFile;
extern void PrintStrings();
extern char *StoreString(char *s);
extern struct SymbolTableStruct * CurrentTable;
extern FILE *  yyin;
extern FILE *  VariableOutFile;
extern int yyparse (void);

int pullArgIndex = 0; //helper variable for 'pull'

struct IRCode
{
	int lineNum;
	char operator[15];
	bool isop1Num;
	bool isop2Num;
	bool isop3Num;
	bool isop4Num;
	void *op1;
	void *op2;
	void *op3;	
	void *op4;
};

struct SymbolTableEntry
{
	char varName[20];
	int arr_size;
	bool isLive;
	int liveAt;
};

struct RegDescEntry{
	char varName[20];
};

typedef struct
{
	struct SymbolTableEntry * Table;
}NextUseEntry;

struct AddrDescEntry
{
	char varName[20];
	int arr_size;
	char address[5];
};
// t0 - t7
struct VarNode
{
  char* data;
  int arr_size;
  struct VarNode *next;
};

int LINES=0;
int VARIABLES_COUNT=0;
struct VarNode *varHead;
struct AddrDescEntry *AddrDescriptor;
struct SymbolTableEntry *SymbolTable;
struct RegDescEntry RegDescriptor[8];
struct IRCode *IRCodeArray;
NextUseEntry * NextUseTable;

// void pushVarNode(struct VarNode** head_ref, char* data)
void pushVarNode(struct VarNode** head_ref, char* data, int arraySize)
{
	// printf("pushed var %s\n",data);
	struct VarNode* tempHead = *head_ref;
	while(tempHead!=NULL){
		if(strcmp(tempHead->data,data)==0){
			return;}
		tempHead = tempHead->next;
	}
	VARIABLES_COUNT++;
    struct VarNode* new_node = (struct VarNode*) malloc(sizeof(struct VarNode));

    new_node->data  = strdup(data);
    new_node->arr_size = arraySize;
    new_node->next = (*head_ref);

    (*head_ref)    = new_node;
}

void printVarList(struct VarNode *node)
{
	if(node==NULL)return;
	while (node != NULL)
	{
		printf("%s\n",node->data);
		node = node->next;
	}
}

bool isValidNumber(char * string)
{
   for(int i = 0; i < strlen( string ); i ++)
   {
      if(i==0 && (string[i]==43 || string[i]==45) && strlen(string)>1)continue;
      if (string[i] < 48 || string[i] > 57)
         return false;
   }

   return true;
}

void addrDescinit(){
	struct VarNode *tempHead = varHead;
	int i=0;
	while(tempHead!=NULL){
		strcpy(AddrDescriptor[i].varName,tempHead->data);
		strcpy(AddrDescriptor[i].address, "mem");
		AddrDescriptor[i].arr_size=tempHead->arr_size;
		i++;
		tempHead = tempHead->next;
	}
}

void symbTableinit(){
	struct VarNode *tempHead = varHead;
	int i=0;
	while(tempHead!=NULL){
		strcpy(SymbolTable[i].varName,tempHead->data);
		SymbolTable[i].isLive = false;
		SymbolTable[i].liveAt = -1;
		SymbolTable[i].arr_size=tempHead->arr_size;
		i++;
		tempHead = tempHead->next;
	}
}

void regDescinit(){
	for (int i = 0; i < 8; ++i)
	{
		strcpy(RegDescriptor[i].varName, "EMPTYREG");
	}
}

char * getAddDesc(char * variable){
	for (int i = 0; i < VARIABLES_COUNT; ++i)
	{
		if(strcmp(AddrDescriptor[i].varName,variable)==0)
			return AddrDescriptor[i].address;
	}
}

void setAddDesc(char * variable, char * location){
	for (int i = 0; i < VARIABLES_COUNT; ++i)
	{
		if(strcmp(AddrDescriptor[i].varName,variable)==0){
			strcpy(AddrDescriptor[i].address,location);
			return;
		}
	}
}

void setRegDesc(int reg, char *variable){
	strcpy(RegDescriptor[reg].varName, variable);
}

int getRegNum(char *variable){
	for(int i=0; i<8; i++){
		if(strcmp(RegDescriptor[i].varName,variable)==0)return i;
	}

	return -1;
}

void storeAllInMem(){
	for (int j = 0; j < VARIABLES_COUNT; ++j)
		{
			if(strcmp(AddrDescriptor[j].address,"mem")!=0){
				if(AddrDescriptor[j].arr_size==0)
					printf("sw $t%d, %s\n", getRegNum(AddrDescriptor[j].varName), AddrDescriptor[j].varName);
				setAddDesc(AddrDescriptor[j].varName, "mem");
			}
		}
}

int getReg(char * variable, int Line, int dont_touch_reg1, int dont_touch_reg2){
	int i,j;

	//checking if variable is already allocated a register
	for(i = 0; i < 8; i++){
		if(strcmp(variable, RegDescriptor[i].varName) == 0){
			return i;
		}
	}

	//checking if a free register exist
	for(i = 0; i < 8; i++){
		if(strcmp(RegDescriptor[i].varName, "EMPTYREG")==0){
			return i;
		}
	}

	//spilling a register
	int maxNextUse = -1;
	int registor_no = -1;
	for(i = 0; i < 8; i++){
		if(i==dont_touch_reg1 || i==dont_touch_reg2)
			continue;

		for(j = 0; j < VARIABLES_COUNT; j++){
			if(strcmp(RegDescriptor[i].varName,NextUseTable[Line].Table[j].varName) == 0){

				//checking is variable is dead already
				if(!NextUseTable[Line].Table[j].isLive){
					registor_no = i;
					i = 10; //break from outer loop
					break;
				}

				//checking if variable next use is greater than maxNextUse
				if(maxNextUse < NextUseTable[Line].Table[j].liveAt){
					maxNextUse = NextUseTable[Line].Table[j].liveAt;
					registor_no = i;
				}
				break;
			}
		}
	}
	printf("sw $t%d, %s\n", registor_no, RegDescriptor[registor_no].varName);
	setAddDesc(RegDescriptor[registor_no].varName, "mem");
	return registor_no;
}


void translate(int lineNum){
	if(strcmp(IRCodeArray[lineNum].operator,"scan")==0){
		printf("jal _scan_int\n");
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"Print")==0){
		if(IRCodeArray[lineNum].isop1Num){
			storeAllInMem();
			printf("li $a0, %d\n", *((int *)(IRCodeArray[lineNum].op1)));
			printf("jal _print_int\n");
		}else{
			//argument is a variable
			char *sourceVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
			char *sourceVarLoc = getAddDesc(sourceVar);
			if(strcmp(sourceVarLoc,"mem")==0){
				printf("lw $a0, %s\n", sourceVar);
				storeAllInMem();
				printf("jal _print_int\n");
			}else{
				//argument is in register
				printf("move $a0, %s\n", sourceVarLoc);
				storeAllInMem();
				printf("jal _print_int\n");
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"PrintChar")==0){
		if(IRCodeArray[lineNum].isop1Num){
			storeAllInMem();
			printf("li $a0, %d\n", *((int *)(IRCodeArray[lineNum].op1)));
			printf("jal _print_char\n");
		}else{
			//argument is a variable
			char *sourceVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
			char *sourceVarLoc = getAddDesc(sourceVar);
			if(strcmp(sourceVarLoc,"mem")==0){
				printf("lw $a0, %s\n", sourceVar);
				storeAllInMem();
				printf("jal _print_char\n");
			}else{
				//argument is in register
				printf("move $a0, %s\n", sourceVarLoc);
				storeAllInMem();
				printf("jal _print_char\n");
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"PrintStr")==0){
		char *string =((char *)(IRCodeArray[lineNum].op1));
		printf("la $a0, %s\n",string);
		storeAllInMem();
		printf("jal _print_str\n");
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"exit")==0){
		storeAllInMem();
		printf("li $v0, 10\n");
		printf("syscall\n");
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"moveSP")==0){
		printf("sub $sp, $sp, %d\n", *((int *)(IRCodeArray[lineNum].op1)));
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"return")==0){
		if(IRCodeArray[lineNum].isop1Num){
			//return value is number
			printf("li $v0, %d\n", *((int *)(IRCodeArray[lineNum].op1)));
		}else{
			//return value is variable's value
			char *sourceVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
			char *sourceVarLoc = getAddDesc(sourceVar);
			if(strcmp(sourceVarLoc,"mem")==0){
				//source in mem
				printf("lw $v0, %s\n",sourceVar);
			}else{
				//source in reg
				printf("move $v0, %s\n", sourceVarLoc);
			}
		}
		storeAllInMem();
		// printf("lw $ra,($sp)\n");
		// printf("addiu $sp,$sp,4\n");
		// printf("jr $ra\n");
		printf("move $sp, $fp\n");
		printf("lw $fp, ($fp)\n");
		printf("addiu $sp,$sp,4\n");
		printf("lw $ra,($sp)\n");
		printf("addiu $sp,$sp,4\n");
		printf("jr $ra\n");
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"push")==0){
		printf("sub $sp, $sp, 4\n");
		if(IRCodeArray[lineNum].isop1Num){
			//value is number
			printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op1)));
			printf("sw $t8, ($sp)\n");
		}else{
			//value is variable's value
			char *sourceVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
			char *sourceVarLoc = getAddDesc(sourceVar);
			if(strcmp(sourceVarLoc,"mem")==0){
				//source in mem
				printf("lw $t8, %s\n",sourceVar);
				printf("sw $t8, ($sp)\n");
			}else{
				//source in reg
				printf("sw %s, ($sp)\n", sourceVarLoc);
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"pull")==0){
		// getreturnval, a
		printf("sub $sp, $sp, 4\n");
		pullArgIndex+=1;
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(strcmp(destVarLoc,"mem")==0){
			//destVar in memory
			int regdest = getReg(destVar,lineNum, -1, -1);
			//update address descriptor for destVar
			char s[5];
			sprintf(s, "$t%d",regdest);
			setAddDesc(destVar,s);
			//update regdesc
			setRegDesc(regdest,destVar);
			printf("lw $t%d, %d($sp)\n", regdest,(pullArgIndex)*4);
		}else{
			//destVar in reg
			printf("lw %s, %d($sp)\n", destVarLoc,(pullArgIndex)*4);
		}
		pullArgIndex+=1;
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"function")==0){
		pullArgIndex=2;
		storeAllInMem();
		printf("%s:\n",(char *)(IRCodeArray[lineNum].op1));
		printf("sub $sp, $sp, 4\n");
		printf("sw $ra, ($sp)\n");
		printf("sub $sp, $sp, 4\n");
		printf("sw $fp, ($sp)\n");
		printf("move $fp,$sp\n");
		// sub $sp, $sp, 4
		// sw $ra, ($sp)
		// sub $sp, $sp, 4
		// sw $fp, ($sp)
		// move $fp,$sp
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"goto")==0){
		storeAllInMem();
		if(IRCodeArray[lineNum].isop1Num)
			printf("j L%d\n", *((int *)(IRCodeArray[lineNum].op1)));
		else
			printf("j %s\n", (char *)(IRCodeArray[lineNum].op1));

	}
	else if(strcmp(IRCodeArray[lineNum].operator,"label")==0){
		storeAllInMem();
		printf("%s:\n",(char *)(IRCodeArray[lineNum].op1));

	}
	else if(strcmp(IRCodeArray[lineNum].operator,"ifgoto")==0){
		char *operation = (char *)(IRCodeArray[lineNum].op1);
		if(strcmp(operation, "<=")==0){
			if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				//both are number
				storeAllInMem();
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
				if(IRCodeArray[lineNum].isop4Num){
					printf("ble $t8, $t9, L%d\n", *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("ble $t8, $t9, %s\n", (char *)(IRCodeArray[lineNum].op4));
				}
			}else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				int regoper1;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("ble $t%d, $t9, L%d\n", regoper1, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("ble $t%d, $t9, %s\n", regoper1, (char *)(IRCodeArray[lineNum].op4));
				}

			}else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper2;
				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}

				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("ble  $t8, $t%d, L%d\n", regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("ble  $t8, $t%d, %s\n", regoper2, (char *)(IRCodeArray[lineNum].op4));
				}
			}else{
				//both are variable
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper1,regoper2;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}
				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("ble  $t%d, $t%d, L%d\n", regoper1,regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("ble  $t%d, $t%d, %s\n", regoper1, regoper2, (char *)(IRCodeArray[lineNum].op4));
				}

			}
		}else if(strcmp(operation, "<")==0){
			if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				//both are number
				storeAllInMem();
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
				if(IRCodeArray[lineNum].isop4Num){
					printf("blt $t8, $t9, L%d\n", *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("blt $t8, $t9, %s\n", (char *)(IRCodeArray[lineNum].op4));
				}
			}else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				int regoper1;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("blt $t%d, $t9, L%d\n", regoper1, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("blt $t%d, $t9, %s\n", regoper1, (char *)(IRCodeArray[lineNum].op4));
				}

			}else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper2;
				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}

				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("blt  $t8, $t%d, L%d\n", regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("blt  $t8, $t%d, %s\n", regoper2, (char *)(IRCodeArray[lineNum].op4));
				}
			}else{
				//both are variable
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper1,regoper2;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}
				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("blt  $t%d, $t%d, L%d\n", regoper1,regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("blt  $t%d, $t%d, %s\n", regoper1, regoper2, (char *)(IRCodeArray[lineNum].op4));
				}

			}

		}else if(strcmp(operation, ">=")==0){
						if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				//both are number
				storeAllInMem();
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
				if(IRCodeArray[lineNum].isop4Num){
					printf("bge $t8, $t9, L%d\n", *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bge $t8, $t9, %s\n", (char *)(IRCodeArray[lineNum].op4));
				}
			}else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				int regoper1;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bge $t%d, $t9, L%d\n", regoper1, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bge $t%d, $t9, %s\n", regoper1, (char *)(IRCodeArray[lineNum].op4));
				}

			}else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper2;
				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}

				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bge  $t8, $t%d, L%d\n", regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bge  $t8, $t%d, %s\n", regoper2, (char *)(IRCodeArray[lineNum].op4));
				}
			}else{
				//both are variable
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper1,regoper2;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}
				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bge  $t%d, $t%d, L%d\n", regoper1,regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bge  $t%d, $t%d, %s\n", regoper1, regoper2, (char *)(IRCodeArray[lineNum].op4));
				}

			}

		}else if(strcmp(operation, ">")==0){
			if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				//both are number
				storeAllInMem();
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
				if(IRCodeArray[lineNum].isop4Num){
					printf("bgt $t8, $t9, L%d\n", *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bgt $t8, $t9, %s\n", (char *)(IRCodeArray[lineNum].op4));
				}
			}else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				int regoper1;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bgt $t%d, $t9, L%d\n", regoper1, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bgt $t%d, $t9, %s\n", regoper1, (char *)(IRCodeArray[lineNum].op4));
				}

			}else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper2;
				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}

				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bgt  $t8, $t%d, L%d\n", regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bgt  $t8, $t%d, %s\n", regoper2, (char *)(IRCodeArray[lineNum].op4));
				}
			}else{
				//both are variable
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper1,regoper2;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}
				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bgt  $t%d, $t%d, L%d\n", regoper1,regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bgt  $t%d, $t%d, %s\n", regoper1, regoper2, (char *)(IRCodeArray[lineNum].op4));
				}

			}

		}else if(strcmp(operation, "==")==0){
						if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				//both are number
				storeAllInMem();
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
				if(IRCodeArray[lineNum].isop4Num){
					printf("beq $t8, $t9, L%d\n", *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("beq $t8, $t9, %s\n", (char *)(IRCodeArray[lineNum].op4));
				}
			}else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				int regoper1;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("beq $t%d, $t9, L%d\n", regoper1, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("beq $t%d, $t9, %s\n", regoper1, (char *)(IRCodeArray[lineNum].op4));
				}

			}else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper2;
				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}

				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("beq  $t8, $t%d, L%d\n", regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("beq  $t8, $t%d, %s\n", regoper2, (char *)(IRCodeArray[lineNum].op4));
				}
			}else{
				//both are variable
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper1,regoper2;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}
				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("beq  $t%d, $t%d, L%d\n", regoper1,regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("beq  $t%d, $t%d, %s\n", regoper1, regoper2, (char *)(IRCodeArray[lineNum].op4));
				}

			}

		}else if(strcmp(operation, "!=")==0){
						if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				//both are number
				storeAllInMem();
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
				if(IRCodeArray[lineNum].isop4Num){
					printf("bne $t8, $t9, L%d\n", *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bne $t8, $t9, %s\n", (char *)(IRCodeArray[lineNum].op4));
				}
			}else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				int regoper1;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bne $t%d, $t9, L%d\n", regoper1, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bne $t%d, $t9, %s\n", regoper1, (char *)(IRCodeArray[lineNum].op4));
				}

			}else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper2;
				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}

				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));

				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bne  $t8, $t%d, L%d\n", regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bne  $t8, $t%d, %s\n", regoper2, (char *)(IRCodeArray[lineNum].op4));
				}
			}else{
				//both are variable
				char *operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
				char *operVarLoc1 = getAddDesc(operVar1);
				char *operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
				char *operVarLoc2 = getAddDesc(operVar2);
				int regoper1,regoper2;
				if(strcmp(operVarLoc1,"mem")==0){
					regoper1 = getReg(operVar1,lineNum, -1, -1);
					//update address descriptor for operVar1
					char s[5];
					sprintf(s, "$t%d",regoper1);
					setAddDesc(operVar1,s);
					//update regdesc
					setRegDesc(regoper1,operVar1);
					printf("lw $t%d, %s\n",regoper1,operVar1);
				}else{
					regoper1 = getRegNum(operVar1);
				}

				if(strcmp(operVarLoc2,"mem")==0){
					regoper2 = getReg(operVar2,lineNum, -1, -1);
					//update address descriptor for operVar2
					char s[5];
					sprintf(s, "$t%d",regoper2);
					setAddDesc(operVar2,s);
					//update regdesc
					setRegDesc(regoper2,operVar2);
					printf("lw $t%d, %s\n",regoper2,operVar2);
				}else{
					regoper2 = getRegNum(operVar2);
				}
				storeAllInMem();
				if(IRCodeArray[lineNum].isop4Num){
					printf("bne  $t%d, $t%d, L%d\n", regoper1,regoper2, *((int *)(IRCodeArray[lineNum].op4)));
				}else{
					printf("bne  $t%d, $t%d, %s\n", regoper1, regoper2, (char *)(IRCodeArray[lineNum].op4));
				}

			}

		}

	}
	else if(strcmp(IRCodeArray[lineNum].operator,"getreturnval")==0){
		// getreturnval, a
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(strcmp(destVarLoc,"mem")==0){
			//destVar in memory
			int regdest = getReg(destVar,lineNum, -1, -1);
			//update address descriptor for destVar
			char s[5];
			sprintf(s, "$t%d",regdest);
			setAddDesc(destVar,s);
			//update regdesc
			setRegDesc(regdest,destVar);
			printf("move $t%d, $v0\n", regdest);
		}else{
			//destVar in reg
			printf("move %s, $v0\n", destVarLoc);
		}

	}
	else if(strcmp(IRCodeArray[lineNum].operator,"writearr")==0){
		// printf("came for %d\n", lineNum);
		// writearr, arrname, 4, c
		// printf("here for writearr------------------------\n");
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		// printf("no-----------%s \n",destVar);
		destVarLoc = getAddDesc(destVar);
		// printf("array name is  --------------%s\n", destVar);
		int regdest;
		if(strcmp(destVarLoc,"mem")==0){
			// printf("mem------------------\n");
			// printf("here----------\n");
			//array in memory...need to load address in register
			regdest = getReg(destVar,lineNum, -1, -1);
			//update address descriptor for destVar
			char s[5];
			sprintf(s, "$t%d",regdest);
			setAddDesc(destVar,s);
			//update regdesc
			setRegDesc(regdest,destVar);
			printf("la $t%d, %s\n",regdest, destVar);
		}else{
			// printf("here22----------\n");
			regdest = getRegNum(destVar);
		}
		//regdest contains the effective address of array

		//load index into $t8
		if(IRCodeArray[lineNum].isop2Num){
			//index is passed as integer
			printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
		}else{
			//index is passes as variable
			char *indexVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			char *indexVarLoc = getAddDesc(indexVar);
			if(strcmp(indexVarLoc,"mem")==0){
				printf("lw $t8, %s\n", indexVar);
			}else{
				printf("move $t8, %s\n", indexVarLoc);
			}
		}

		printf("add $t8, $t8, $t8\n");
		printf("add $t8, $t8, $t8\n");
		printf("add $t8, $t%d, $t8\n", regdest);
		//$t8 now contains the required address of memory

		//$t9 will contain the value to store in the array
		if(IRCodeArray[lineNum].isop3Num){
			printf("li $t9, %d\n", *((int *)(IRCodeArray[lineNum].op3)));
			printf("sw $t9, ($t8)\n");
		}else{
			char *valueVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			char *valueVarLoc = getAddDesc(valueVar);
			if(strcmp(valueVarLoc,"mem")==0){
				printf("lw $t9, %s\n", valueVar);
				printf("sw $t9, ($t8)\n");
			}else{
				printf("move $t9, %s\n", valueVarLoc);
				printf("sw $t9, ($t8)\n");
			}
		}
		// printf("writearr over----------------\n");
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"readarr")==0){
		// readarr, arrname, 7, a
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		int regdest;
		if(strcmp(destVarLoc,"mem")==0){
			//array in memory...need to load address in register
			regdest = getReg(destVar,lineNum, -1, -1);
			//update address descriptor for destVar
			char s[5];
			sprintf(s, "$t%d",regdest);
			setAddDesc(destVar,s);
			//update regdesc
			setRegDesc(regdest,destVar);
			printf("la $t%d, %s\n",regdest, destVar);
		}else{
			regdest = getRegNum(destVar);
		}
		//regdest contains the effective address of array

		//load index into $t8
		if(IRCodeArray[lineNum].isop2Num){
			//index is passed as integer
			printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
		}else{
			//index is passes as variable
			char *indexVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			char *indexVarLoc = getAddDesc(indexVar);
			if(strcmp(indexVarLoc,"mem")==0){
				printf("lw $t8, %s\n", indexVar);
			}else{
				printf("move $t8, %s\n", indexVarLoc);
			}
		}

		printf("add $t8, $t8, $t8\n");
		printf("add $t8, $t8, $t8\n");
		printf("add $t8, $t%d, $t8\n", regdest);
		//$t8 now contains the required address of memory

		char *valueVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
		char *valueVarLoc = getAddDesc(valueVar);
		if(strcmp(valueVarLoc,"mem")==0){
			// printf("lw $t9, %s\n", valueVar);
			// printf("sw $t9, ($t8)\n");
			int regvalue = getReg(valueVar,lineNum, regdest, -1);
			//update address descriptor for valueVar
			char s1[5];
			sprintf(s1, "$t%d",regvalue);
			setAddDesc(valueVar,s1);
			//update regdesc
			setRegDesc(regvalue,valueVar);
			printf("lw $t%d, ($t8)\n", regvalue);
		}else{
			printf("lw %s, ($t8)\n", valueVarLoc);
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"call")==0){
		storeAllInMem();
		if(strcmp((char *)(IRCodeArray[lineNum].op1),"scan")==0)
			printf("jal _scan_int\n");
		else
			printf("jal %s\n",(char *)(IRCodeArray[lineNum].op1));
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"=")==0){

		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num){
			// source is number
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)));
			}else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)));
			}
		}else{
			// source is a variable
			char * operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			char *operVarLoc = getAddDesc(operVar);
			// printf("%s\n", operVarLoc);
			if(strcmp(destVarLoc,"mem")==0 && strcmp(operVarLoc,"mem")==0){
				//source and dest both in mem
				//reg for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("lw $t%d, %s\n", regdest, operVar);

			}else if(strcmp(destVarLoc,"mem")==0 && strcmp(operVarLoc,"mem")!=0){
				//source in reg and dest in mem
				//reg for destVar
				int regdest = getReg(destVar,lineNum, getRegNum(operVar), -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);

				printf("move $t%d, %s\n", regdest, operVarLoc);

			}else if(strcmp(destVarLoc,"mem")!=0 && strcmp(operVarLoc,"mem")==0){
				//source in mem and dest in reg

				printf("lw %s, %s\n", destVarLoc, operVar);
			}else{
				//both in reg
				printf("move %s, %s\n", destVarLoc, operVarLoc);
			}
		}

	}
	else if(strcmp(IRCodeArray[lineNum].operator,"~")==0){

		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num){
			// source is number
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("nor $t%d, $t8, $0\n", regdest);
			}else{
				printf("li $t8, %d\n", *((int *)(IRCodeArray[lineNum].op2)));
				printf("nor %s, $t8, $0\n",destVarLoc);
			}
		}else{
			// source is a variable
			char * operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			char *operVarLoc = getAddDesc(operVar);
			// printf("%s\n", operVarLoc);
			if(strcmp(destVarLoc,"mem")==0 && strcmp(operVarLoc,"mem")==0){
				//source and dest both in mem
				//reg for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("lw $t8, %s\n", operVar);
				printf("nor $t%d, $t8, $0\n", regdest);

			}else if(strcmp(destVarLoc,"mem")==0 && strcmp(operVarLoc,"mem")!=0){
				//source in reg and dest in mem
				//reg for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("nor $t%d, %s, $0\n", regdest,operVarLoc);

			}else if(strcmp(destVarLoc,"mem")!=0 && strcmp(operVarLoc,"mem")==0){
				//source in mem and dest in reg

				printf("lw $t8, %s\n", operVar);
				printf("nor %s, $t8, $0\n", destVarLoc);
			}else{
				//both in reg
				printf("nor %s, %s, $0\n", destVarLoc, operVarLoc);
			}

		}

	}
	else if(strcmp(IRCodeArray[lineNum].operator,"+")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) + *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) + *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar);
					printf("addi $t%d, $t%d, %d\n",regdest,regdest,*((int *)(IRCodeArray[lineNum].op3)));
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("addi $t%d, $t%d, %d\n",regdest,regdest1,*((int *)(IRCodeArray[lineNum].op3)));
				}
				else{
					printf("addi $t%d, %s, %d\n",regdest,operVarLoc,*((int *)(IRCodeArray[lineNum].op3)));
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("addi %s, $t%d, %d\n",destVarLoc,regdest1,*((int *)(IRCodeArray[lineNum].op3)));
				}
				else{
					printf("addi %s, %s, %d\n",destVarLoc,operVarLoc,*((int *)(IRCodeArray[lineNum].op3)));
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar);
					printf("addi $t%d, $t%d, %d\n",regdest,regdest,*((int *)(IRCodeArray[lineNum].op2)));
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("addi $t%d, $t%d, %d\n",regdest,regdest1,*((int *)(IRCodeArray[lineNum].op2)));
				}
				else{
					printf("addi $t%d, %s, %d\n",regdest,operVarLoc,*((int *)(IRCodeArray[lineNum].op2)));
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("addi %s, $t%d, %d\n",destVarLoc,regdest1,*((int *)(IRCodeArray[lineNum].op2)));
				}
				else{
					printf("addi %s, %s, %d\n",destVarLoc,operVarLoc,*((int *)(IRCodeArray[lineNum].op2)));
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar1);
					printf("add $t%d, $t%d, $t%d\n",regdest,regdest,regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("add $t%d, $t%d, $t%d\n",regdest,regdest,regdest2);
					}else{
						printf("add $t%d, $t%d, %s\n",regdest,regdest,operVar2Loc);
					}
				}
				else if(strcmp(operVar2,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar2);
					if(strcmp(operVar1Loc,"mem")==0){
						int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest1);
						setAddDesc(operVar1,s2);
						//update regdesc
						setRegDesc(regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("add $t%d, $t%d, $t%d\n",regdest,regdest,regdest1);
					}else{
						printf("add $t%d, $t%d, %s\n",regdest,regdest,operVar1Loc);
					}
				}
				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("add $t%d, $t%d, $t%d\n",regdest,regdest1,regdest2);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("add $t%d, $t%d, %s\n",regdest,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("add $t%d, %s, $t%d\n",regdest,operVar1Loc,regdest2);
					}else{
						printf("add $t%d, %s, %s\n",regdest,operVar1Loc,operVar2Loc);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("add %s, $t%d, $t%d\n",destVarLoc,regdest1,regdest2);
					}else{
						printf("add %s, $t%d, %s\n",destVarLoc,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("add %s, %s, $t%d\n",destVarLoc,operVar1Loc,regdest2);
					}else{
						printf("add %s, %s, %s\n",destVarLoc,operVar1Loc,operVar2Loc);
					}
				}
			}
		}
	}

	else if(strcmp(IRCodeArray[lineNum].operator,"-")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) - *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) - *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sub $t%d, $t%d, $t8\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sub $t%d, $t%d, $t8\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sub $t%d, %s, $t8\n",regdest,operVarLoc);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sub %s, $t%d, $t8\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sub %s, %s, $t8\n",destVarLoc,operVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sub $t%d, $t8, $t%d\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sub $t%d, $t8, $t%d\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sub $t%d, $t8, %s\n",regdest,operVarLoc);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sub %s, $t8, $t%d\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sub %s, $t8, %s\n",destVarLoc,operVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    printf("sub $t%d, $t%d, $t%d\n",regdest,regdest,regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    if(strcmp(operVar2Loc,"mem")==0){
				        int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest2);
				        setAddDesc(operVar2,s2);
				        //update regdesc
				        setRegDesc(regdest2,operVar2);
				        printf("lw $t%d, %s\n",regdest2,operVar2);
				        printf("sub $t%d, $t%d, $t%d\n",regdest,regdest,regdest2);
				    }else{
				        printf("sub $t%d, $t%d, %s\n",regdest,regdest,operVar2Loc);
				    }
				}
				else if(strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar2);
				    if(strcmp(operVar1Loc,"mem")==0){
				        int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest1);
				        setAddDesc(operVar1,s2);
				        //update regdesc
				        setRegDesc(regdest1,operVar1);
				        printf("lw $t%d, %s\n",regdest1,operVar1);
				        printf("sub $t%d, $t%d, $t%d\n",regdest,regdest,regdest1);
				    }else{
				        printf("sub $t%d, $t%d, %s\n",regdest,regdest,operVar1Loc);
				    }
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sub $t%d, $t%d, $t%d\n",regdest,regdest1,regdest2);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("sub $t%d, $t%d, %s\n",regdest,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sub $t%d, %s, $t%d\n",regdest,operVar1Loc,regdest2);
					}else{
						printf("sub $t%d, %s, %s\n",regdest,operVar1Loc,operVar2Loc);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sub %s, $t%d, $t%d\n",destVarLoc,regdest1,regdest2);
					}else{
						printf("sub %s, $t%d, %s\n",destVarLoc,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sub %s, %s, $t%d\n",destVarLoc,operVar1Loc,regdest2);
					}else{
						printf("sub %s, %s, %s\n",destVarLoc,operVar1Loc,operVar2Loc);
					}
				}
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"/")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) / *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) / *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
				    printf("div $t%d, $t8\n",regdest);
					printf("mflo $t%d\n",regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div $t%d, $t8\n",regdest1);
					printf("mflo $t%d\n",regdest);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div %s, $t8\n",operVarLoc);
					printf("mflo $t%d\n",regdest);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div $t%d, $t8\n",regdest1);
					printf("mflo %s\n",destVarLoc);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div %s, $t8\n",operVarLoc);
					printf("mflo %s\n",destVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
				    printf("div $t8, $t%d\n",regdest);
					printf("mflo $t%d\n",regdest);
				}

				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, $t%d\n",regdest1);
					printf("mflo $t%d\n",regdest);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, %s\n",operVarLoc);
					printf("mflo $t%d\n",regdest);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, $t%d\n",regdest1);
					printf("mflo %s\n",destVarLoc);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, %s\n",operVarLoc);
					printf("mflo %s\n",destVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
					printf("div $t%d, $t%d\n",regdest,regdest);
					printf("mflo $t%d\n",regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    if(strcmp(operVar2Loc,"mem")==0){
				        int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest2);
				        setAddDesc(operVar2,s2);
				        //update regdesc
				        setRegDesc(regdest2,operVar2);
				        printf("lw $t%d, %s\n",regdest2,operVar2);
				        printf("div $t%d, $t%d\n",regdest,regdest2);
						printf("mflo $t%d\n",regdest);
				    }else{
				        printf("div $t%d, %s\n",regdest,operVar2Loc);
						printf("mflo $t%d\n",regdest);
				    }
				}
				else if(strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar2);
				    if(strcmp(operVar1Loc,"mem")==0){
				        int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest1);
				        setAddDesc(operVar1,s2);
				        //update regdesc
				        setRegDesc(regdest1,operVar1);
				        printf("lw $t%d, %s\n",regdest1,operVar1);
				        printf("div $t%d, $t%d\n",regdest,regdest1);
						printf("mflo $t%d\n",regdest);
				    }else{
				        printf("div $t%d, %s\n",regdest,operVar1Loc);
						printf("mflo $t%d\n",regdest);
				    }
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div $t%d, $t%d\n",regdest1,regdest2);
						printf("mflo $t%d\n",regdest);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("div $t%d, %s\n",regdest1,operVar2Loc);
						printf("mflo $t%d\n",regdest);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div %s, $t%d\n",operVar1Loc,regdest2);
						printf("mflo $t%d\n",regdest);
					}else{
						printf("div %s, %s\n",operVar1Loc,operVar2Loc);
						printf("mflo $t%d\n",regdest);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div $t%d, $t%d\n",regdest1,regdest2);
						printf("mflo %s\n",destVarLoc);
					}else{
						printf("div $t%d, %s\n",regdest1,operVar2Loc);
						printf("mflo %s\n",destVarLoc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div %s, $t%d\n",operVar1Loc,regdest2);
						printf("mflo %s\n",destVarLoc);
					}else{
						printf("div %s, %s\n",operVar1Loc,operVar2Loc);
						printf("mflo %s\n",destVarLoc);
					}
				}
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"*")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) * *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) * *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
				    printf("mult $t%d, $t8\n",regdest);
					printf("mflo $t%d\n",regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("mult $t%d, $t8\n",regdest1);
					printf("mflo $t%d\n",regdest);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("mult %s, $t8\n",operVarLoc);
					printf("mflo $t%d\n",regdest);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("mult $t%d, $t8\n",regdest1);
					printf("mflo %s\n",destVarLoc);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("mult %s, $t8\n",operVarLoc);
					printf("mflo %s\n",destVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
				    printf("mult $t8, $t%d\n",regdest);
					printf("mflo $t%d\n",regdest);
				}

				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("mult $t8, $t%d\n",regdest1);
					printf("mflo $t%d\n",regdest);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("mult $t8, %s\n",operVarLoc);
					printf("mflo $t%d\n",regdest);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("mult $t8, $t%d\n",regdest1);
					printf("mflo %s\n",destVarLoc);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("mult $t8, %s\n",operVarLoc);
					printf("mflo %s\n",destVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
					printf("mult $t%d, $t%d\n",regdest,regdest);
					printf("mflo $t%d\n",regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    if(strcmp(operVar2Loc,"mem")==0){
				        int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest2);
				        setAddDesc(operVar2,s2);
				        //update regdesc
				        setRegDesc(regdest2,operVar2);
				        printf("lw $t%d, %s\n",regdest2,operVar2);
				        printf("mult $t%d, $t%d\n",regdest,regdest2);
						printf("mflo $t%d\n",regdest);
				    }else{
				        printf("mult $t%d, %s\n",regdest,operVar2Loc);
						printf("mflo $t%d\n",regdest);
				    }
				}
				else if(strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar2);
				    if(strcmp(operVar1Loc,"mem")==0){
				        int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest1);
				        setAddDesc(operVar1,s2);
				        //update regdesc
				        setRegDesc(regdest1,operVar1);
				        printf("lw $t%d, %s\n",regdest1,operVar1);
				        printf("mult $t%d, $t%d\n",regdest,regdest1);
						printf("mflo $t%d\n",regdest);
				    }else{
				        printf("mult $t%d, %s\n",regdest,operVar1Loc);
						printf("mflo $t%d\n",regdest);
				    }
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("mult $t%d, $t%d\n",regdest1,regdest2);
						printf("mflo $t%d\n",regdest);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("mult $t%d, %s\n",regdest1,operVar2Loc);
						printf("mflo $t%d\n",regdest);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("mult %s, $t%d\n",operVar1Loc,regdest2);
						printf("mflo $t%d\n",regdest);
					}else{
						printf("mult %s, %s\n",operVar1Loc,operVar2Loc);
						printf("mflo $t%d\n",regdest);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("mult $t%d, $t%d\n",regdest1,regdest2);
						printf("mflo %s\n",destVarLoc);
					}else{
						printf("mult $t%d, %s\n",regdest1,operVar2Loc);
						printf("mflo %s\n",destVarLoc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("mult %s, $t%d\n",operVar1Loc,regdest2);
						printf("mflo %s\n",destVarLoc);
					}else{
						printf("mult %s, %s\n",operVar1Loc,operVar2Loc);
						printf("mflo %s\n",destVarLoc);
					}
				}
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"rem")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) % *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) % *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
				    printf("div $t%d, $t8\n",regdest);
					printf("mfhi $t%d\n",regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div $t%d, $t8\n",regdest1);
					printf("mfhi $t%d\n",regdest);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div %s, $t8\n",operVarLoc);
					printf("mfhi $t%d\n",regdest);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div $t%d, $t8\n",regdest1);
					printf("mfhi %s\n",destVarLoc);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("div %s, $t8\n",operVarLoc);
					printf("mfhi %s\n",destVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
				    printf("div $t8, $t%d\n",regdest);
					printf("mfhi $t%d\n",regdest);
				}

				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, $t%d\n",regdest1);
					printf("mfhi $t%d\n",regdest);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, %s\n",operVarLoc);
					printf("mfhi $t%d\n",regdest);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, $t%d\n",regdest1);
					printf("mfhi %s\n",destVarLoc);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("div $t8, %s\n",operVarLoc);
					printf("mfhi %s\n",destVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
					printf("div $t%d, $t%d\n",regdest,regdest);
					printf("mfhi $t%d\n",regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    if(strcmp(operVar2Loc,"mem")==0){
				        int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest2);
				        setAddDesc(operVar2,s2);
				        //update regdesc
				        setRegDesc(regdest2,operVar2);
				        printf("lw $t%d, %s\n",regdest2,operVar2);
				        printf("div $t%d, $t%d\n",regdest,regdest2);
						printf("mfhi $t%d\n",regdest);
				    }else{
				        printf("div $t%d, %s\n",regdest,operVar2Loc);
						printf("mfhi $t%d\n",regdest);
				    }
				}
				else if(strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar2);
				    if(strcmp(operVar1Loc,"mem")==0){
				        int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest1);
				        setAddDesc(operVar1,s2);
				        //update regdesc
				        setRegDesc(regdest1,operVar1);
				        printf("lw $t%d, %s\n",regdest1,operVar1);
				        printf("div $t%d, $t%d\n",regdest,regdest1);
						printf("mfhi $t%d\n",regdest);
				    }else{
				        printf("div $t%d, %s\n",regdest,operVar1Loc);
						printf("mfhi $t%d\n",regdest);
				    }
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div $t%d, $t%d\n",regdest1,regdest2);
						printf("mfhi $t%d\n",regdest);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("div $t%d, %s\n",regdest1,operVar2Loc);
						printf("mfhi $t%d\n",regdest);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div %s, $t%d\n",operVar1Loc,regdest2);
						printf("mfhi $t%d\n",regdest);
					}else{
						printf("div %s, %s\n",operVar1Loc,operVar2Loc);
						printf("mfhi $t%d\n",regdest);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div $t%d, $t%d\n",regdest1,regdest2);
						printf("mfhi %s\n",destVarLoc);
					}else{
						printf("div $t%d, %s\n",regdest1,operVar2Loc);
						printf("mfhi %s\n",destVarLoc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("div %s, $t%d\n",operVar1Loc,regdest2);
						printf("mfhi %s\n",destVarLoc);
					}else{
						printf("div %s, %s\n",operVar1Loc,operVar2Loc);
						printf("mfhi %s\n",destVarLoc);
					}
				}
			}
		}
	}else if(strcmp(IRCodeArray[lineNum].operator,"|")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) | *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) | *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("or $t%d, $t%d, $t8\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("or $t%d, $t%d, $t8\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("or $t%d, %s, $t8\n",regdest,operVarLoc);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("or %s, $t%d, $t8\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("or %s, %s, $t8\n",destVarLoc,operVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("or $t%d, $t8, $t%d\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("or $t%d, $t8, $t%d\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("or $t%d, $t8, %s\n",regdest,operVarLoc);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("or %s, $t8, $t%d\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("or %s, $t8, %s\n",destVarLoc,operVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    printf("or $t%d, $t%d, $t%d\n",regdest,regdest,regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    if(strcmp(operVar2Loc,"mem")==0){
				        int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest2);
				        setAddDesc(operVar2,s2);
				        //update regdesc
				        setRegDesc(regdest2,operVar2);
				        printf("lw $t%d, %s\n",regdest2,operVar2);
				        printf("or $t%d, $t%d, $t%d\n",regdest,regdest,regdest2);
				    }else{
				        printf("or $t%d, $t%d, %s\n",regdest,regdest,operVar2Loc);
				    }
				}
				else if(strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar2);
				    if(strcmp(operVar1Loc,"mem")==0){
				        int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest1);
				        setAddDesc(operVar1,s2);
				        //update regdesc
				        setRegDesc(regdest1,operVar1);
				        printf("lw $t%d, %s\n",regdest1,operVar1);
				        printf("or $t%d, $t%d, $t%d\n",regdest,regdest,regdest1);
				    }else{
				        printf("or $t%d, $t%d, %s\n",regdest,regdest,operVar1Loc);
				    }
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("or $t%d, $t%d, $t%d\n",regdest,regdest1,regdest2);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("or $t%d, $t%d, %s\n",regdest,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("or $t%d, %s, $t%d\n",regdest,operVar1Loc,regdest2);
					}else{
						printf("or $t%d, %s, %s\n",regdest,operVar1Loc,operVar2Loc);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("or %s, $t%d, $t%d\n",destVarLoc,regdest1,regdest2);
					}else{
						printf("or %s, $t%d, %s\n",destVarLoc,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("or %s, %s, $t%d\n",destVarLoc,operVar1Loc,regdest2);
					}else{
						printf("or %s, %s, %s\n",destVarLoc,operVar1Loc,operVar2Loc);
					}
				}
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"&")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("li $t%d, %d\n",regdest,*((int *)(IRCodeArray[lineNum].op2)) & *((int *)(IRCodeArray[lineNum].op3)));
			}
			else{
				printf("li %s, %d\n",destVarLoc,*((int *)(IRCodeArray[lineNum].op2)) & *((int *)(IRCodeArray[lineNum].op3)));
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("and $t%d, $t%d, $t8\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("and $t%d, $t%d, $t8\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("and $t%d, %s, $t8\n",regdest,operVarLoc);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("and %s, $t%d, $t8\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("and %s, %s, $t8\n",destVarLoc,operVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("and $t%d, $t8, $t%d\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("and $t%d, $t8, $t%d\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("and $t%d, $t8, %s\n",regdest,operVarLoc);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("and %s, $t8, $t%d\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("and %s, $t8, %s\n",destVarLoc,operVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    printf("and $t%d, $t%d, $t%d\n",regdest,regdest,regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar1);
				    if(strcmp(operVar2Loc,"mem")==0){
				        int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest2);
				        setAddDesc(operVar2,s2);
				        //update regdesc
				        setRegDesc(regdest2,operVar2);
				        printf("lw $t%d, %s\n",regdest2,operVar2);
				        printf("and $t%d, $t%d, $t%d\n",regdest,regdest,regdest2);
				    }else{
				        printf("and $t%d, $t%d, %s\n",regdest,regdest,operVar2Loc);
				    }
				}
				else if(strcmp(operVar2,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar2);
				    if(strcmp(operVar1Loc,"mem")==0){
				        int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
				        //update address descriptor for destVar
				        char s2[5];
				        sprintf(s2, "$t%d",regdest1);
				        setAddDesc(operVar1,s2);
				        //update regdesc
				        setRegDesc(regdest1,operVar1);
				        printf("lw $t%d, %s\n",regdest1,operVar1);
				        printf("and $t%d, $t%d, $t%d\n",regdest,regdest,regdest1);
				    }else{
				        printf("and $t%d, $t%d, %s\n",regdest,regdest,operVar1Loc);
				    }
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("and $t%d, $t%d, $t%d\n",regdest,regdest1,regdest2);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("and $t%d, $t%d, %s\n",regdest,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("and $t%d, %s, $t%d\n",regdest,operVar1Loc,regdest2);
					}else{
						printf("and $t%d, %s, %s\n",regdest,operVar1Loc,operVar2Loc);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("and %s, $t%d, $t%d\n",destVarLoc,regdest1,regdest2);
					}else{
						printf("and %s, $t%d, %s\n",destVarLoc,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("and %s, %s, $t%d\n",destVarLoc,operVar1Loc,regdest2);
					}else{
						printf("and %s, %s, %s\n",destVarLoc,operVar1Loc,operVar2Loc);
					}
				}
			}
		}
	}
	else if(strcmp(IRCodeArray[lineNum].operator,"<<")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
		printf("li $t9, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("sllv $t%d, $t8, $t9\n",regdest);
			}
			else{
				printf("sllv %s, $t8, $t9\n",destVarLoc);
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
				    printf("sllv $t%d, $t%d, $t8\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sllv $t%d, $t%d, $t8\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sllv $t%d, %s, $t8\n",regdest,operVarLoc);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sllv %s, $t%d, $t8\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("sllv %s, %s, $t8\n",destVarLoc,operVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);


				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
				    printf("sllv $t%d, $t8, $t%d\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sllv $t%d, $t8, $t%d\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sllv $t%d, $t8, %s\n",regdest,operVarLoc);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sllv %s, $t8, $t%d\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("sllv %s, $t8, %s\n",destVarLoc,operVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar1);
					printf("sllv $t%d, $t%d, $t%d\n",regdest,regdest,regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sllv $t%d, $t%d, $t%d\n",regdest,regdest,regdest2);
					}else{
						printf("sllv $t%d, $t%d, %s\n",regdest,regdest,operVar2Loc);
					}
				}
				else if(strcmp(operVar2,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar2);
					if(strcmp(operVar1Loc,"mem")==0){
						int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest1);
						setAddDesc(operVar1,s2);
						//update regdesc
						setRegDesc(regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("sllv $t%d, $t%d, $t%d\n",regdest,regdest,regdest1);
					}else{
						printf("sllv $t%d, $t%d, %s\n",regdest,regdest,operVar1Loc);
					}
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sllv $t%d, $t%d, $t%d\n",regdest,regdest1,regdest2);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("sllv $t%d, $t%d, %s\n",regdest,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sllv $t%d, %s, $t%d\n",regdest,operVar1Loc,regdest2);
					}else{
						printf("sllv $t%d, %s, %s\n",regdest,operVar1Loc,operVar2Loc);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sllv %s, $t%d, $t%d\n",destVarLoc,regdest1,regdest2);
					}else{
						printf("sllv %s, $t%d, %s\n",destVarLoc,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("sllv %s, %s, $t%d\n",destVarLoc,operVar1Loc,regdest2);
					}else{
						printf("sllv %s, %s, %s\n",destVarLoc,operVar1Loc,operVar2Loc);
					}
				}
			}
		}
	}else if(strcmp(IRCodeArray[lineNum].operator,">>")==0){
		char *destVar,*destVarLoc;
		destVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op1))->varName;
		destVarLoc = getAddDesc(destVar);
		printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
		printf("li $t9, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
		if(IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum, -1, -1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				printf("srlv $t%d, $t8, $t9\n",regdest);
			}
			else{
				printf("srlv %s, $t8, $t9\n",destVarLoc);
			}
		}
		else if(!IRCodeArray[lineNum].isop2Num && IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
				    printf("srlv $t%d, $t%d, $t8\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("srlv $t%d, $t%d, $t8\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("srlv $t%d, %s, $t8\n",regdest,operVarLoc);
				}

			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("srlv %s, $t%d, $t8\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op3)));
					printf("srlv %s, %s, $t8\n",destVarLoc,operVarLoc);
				}
			}
		}
		else if(IRCodeArray[lineNum].isop2Num && !IRCodeArray[lineNum].isop3Num){
			char *operVar,*operVarLoc;
			operVar = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVarLoc = getAddDesc(operVar);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);


				if(strcmp(operVar,destVar)==0){
				    printf("lw $t%d, %s\n",regdest,operVar);
				    printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
				    printf("srlv $t%d, $t8, $t%d\n",regdest,regdest);
				}
				else if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,regdest,-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("srlv $t%d, $t8, $t%d\n",regdest,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("srlv $t%d, $t8, %s\n",regdest,operVarLoc);
				}
			}
			else{
				if(strcmp(operVarLoc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar,s1);
					//update regdesc
					setRegDesc(regdest1,operVar);
					printf("lw $t%d, %s\n",regdest1,operVar);
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("srlv %s, $t8, $t%d\n",destVarLoc,regdest1);
				}
				else{
					printf("li $t8, %d\n",*((int *)(IRCodeArray[lineNum].op2)));
					printf("srlv %s, $t8, %s\n",destVarLoc,operVarLoc);
				}
			}
		}
		else{
			char *operVar1,*operVar1Loc,*operVar2,*operVar2Loc;
			operVar1 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op2))->varName;
			operVar1Loc = getAddDesc(operVar1);
			operVar2 = ((struct SymbolTableEntry*)(IRCodeArray[lineNum].op3))->varName;
			operVar2Loc = getAddDesc(operVar2);
			if(strcmp(destVarLoc,"mem")==0){
				//get register for destVar
				int regdest = getReg(destVar,lineNum ,-1,-1);
				//update address descriptor for destVar
				char s[5];
				sprintf(s, "$t%d",regdest);
				setAddDesc(destVar,s);
				//update regdesc
				setRegDesc(regdest,destVar);
				if(strcmp(operVar1,destVar)==0 && strcmp(operVar2,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar1);
					printf("srlv $t%d, $t%d, $t%d\n",regdest,regdest,regdest);
				}
				else if(strcmp(operVar1,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("srlv $t%d, $t%d, $t%d\n",regdest,regdest,regdest2);
					}else{
						printf("srlv $t%d, $t%d, %s\n",regdest,regdest,operVar2Loc);
					}
				}
				else if(strcmp(operVar2,destVar)==0){
					printf("lw $t%d, %s\n",regdest,operVar2);
					if(strcmp(operVar1Loc,"mem")==0){
						int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest1);
						setAddDesc(operVar1,s2);
						//update regdesc
						setRegDesc(regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("srlv $t%d, $t%d, $t%d\n",regdest,regdest,regdest1);
					}else{
						printf("srlv $t%d, $t%d, %s\n",regdest,regdest,operVar1Loc);
					}
				}

				else if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("srlv $t%d, $t%d, $t%d\n",regdest,regdest1,regdest2);
					}else{
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("srlv $t%d, $t%d, %s\n",regdest,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("srlv $t%d, %s, $t%d\n",regdest,operVar1Loc,regdest2);
					}else{
						printf("srlv $t%d, %s, %s\n",regdest,operVar1Loc,operVar2Loc);
					}
				}
			}else{
				if(strcmp(operVar1Loc,"mem")==0){
					//get register for destVar
					int regdest1 = getReg(operVar1,lineNum ,getRegNum(destVar),-1);
					//update address descriptor for destVar
					char s1[5];
					sprintf(s1, "$t%d",regdest1);
					setAddDesc(operVar1,s1);
					//update regdesc
					setRegDesc(regdest1,operVar1);
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest1,operVar1);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("srlv %s, $t%d, $t%d\n",destVarLoc,regdest1,regdest2);
					}else{
						printf("srlv %s, $t%d, %s\n",destVarLoc,regdest1,operVar2Loc);
					}
				}else{
					if(strcmp(operVar2Loc,"mem")==0){
						int regdest2 = getReg(operVar2,lineNum ,getRegNum(destVar),getRegNum(operVar1));
						//update address descriptor for destVar
						char s2[5];
						sprintf(s2, "$t%d",regdest2);
						setAddDesc(operVar2,s2);
						//update regdesc
						setRegDesc(regdest2,operVar2);
						printf("lw $t%d, %s\n",regdest2,operVar2);
						printf("srlv %s, %s, $t%d\n",destVarLoc,operVar1Loc,regdest2);
					}else{
						printf("srlv %s, %s, %s\n",destVarLoc,operVar1Loc,operVar2Loc);
					}
				}
			}
		}
	}
}
extern int ParserStatus;

int main(int argc, char const *argv[])
{
	// printf("here");
	StoreString("\\n");
    CurrentTable = (SymbolTableStruct *)malloc(sizeof(SymbolTableStruct));
    CurrentTable->var_count=0;
    if(argc<2){
        printf("Usage: parser <path_to_c#_code>\n");
        exit(1);
    }
    yyin = fopen(argv[1], "r");
    VariableOutFile = fopen("var.txt", "w");
    if (yyin == NULL){
        printf("Error: %s does not exist\n",argv[1]);
        exit(EXIT_FAILURE);
    }
    yyparse();
    // PrintStrings();
    fclose(yyin);
    fclose(VariableOutFile);
    // int abc = system("cat ir_code.txt");
    // return 0;
    
    if(ParserStatus==0)
    	return 0;
	// if(argc<2){
	// 	printf("Usage: ./codegen code.ir\n");
	// 	return 0;
	// }
	FILE *fp;
	char * line = NULL;
    size_t len = 0;
    ssize_t read;


	fp = fopen("ir_code.txt","r");
	if(fp == NULL){
		printf("Unable to read file\n");
		return 0;
	}

	while ((read = getline(&line, &len, fp)) != -1) {
        if(strlen(line)>1)LINES++;
    }

	fseek(fp, 0L, SEEK_SET);

	// printf("here-----\n" );
	//constucting varHead linked list for variables
	FILE *VarFile = fopen("var.txt","r");
	while ((read = getline(&line, &len, VarFile)) != -1) {
    	
        char *varName = strtok(line, ", ");
	    int arr_size = atoi(strtok(NULL, ", "));
	    pushVarNode(&varHead,varName,arr_size);
    }

	AddrDescriptor = (struct AddrDescEntry*)malloc(VARIABLES_COUNT*sizeof(struct AddrDescEntry));
	addrDescinit();
	SymbolTable = (struct SymbolTableEntry*)malloc(VARIABLES_COUNT*sizeof(struct SymbolTableEntry));
	symbTableinit();
	regDescinit();
	fseek(fp, 0L, SEEK_SET);
	IRCodeArray = (struct IRCode*)malloc(LINES*sizeof(struct IRCode));
	NextUseTable = (NextUseEntry*)malloc(LINES*sizeof(NextUseEntry));

	for (int i = 0; i < LINES; ++i)
	{
		NextUseTable[i].Table = (struct SymbolTableEntry*)malloc(VARIABLES_COUNT*sizeof(struct SymbolTableEntry));
	}

	int i=0,j=0;

	//constructing IRCodeArray-----------
	while ((read = getline(&line, &len, fp)) != -1) {
		if(strlen(line)<=1)continue;
        char *token = strtok(line, ", ");
        IRCodeArray[i].lineNum = atoi(token);
	    token = strtok(NULL, ", ");
	    if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
	    strcpy(IRCodeArray[i].operator,token);
	    if(strcmp(token,"function")==0 || strcmp(token,"call")==0 || strcmp(token,"label")==0){
	    	token = strtok(NULL, ", ");
	    	if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
   			IRCodeArray[i].isop1Num = false;
   			IRCodeArray[i].op1 = (char *)malloc(strlen(token)+2);
   			strcpy(IRCodeArray[i].op1,token);
   		}
   		else if(strcmp(token,"goto")==0){
   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
    			IRCodeArray[i].isop1Num = true;
    			IRCodeArray[i].op1 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op1) = atoi(token);
    		}else{
	   			IRCodeArray[i].isop1Num = false;
	   			IRCodeArray[i].op1 = (char *)malloc(strlen(token)+2);
	   			strcpy(IRCodeArray[i].op1,token);
   			}
   		}
   		else if(strcmp(token, "exit") == 0){

   		}else if(strcmp(token, "scan") == 0){

   		}
   		else if(strcmp(token, "return") == 0){
   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
    			IRCodeArray[i].isop1Num = true;
    			IRCodeArray[i].op1 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op1) = atoi(token);
    		}else{
    			IRCodeArray[i].isop1Num = false;
	   			for ( j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op1 = SymbolTable + j;
    		}
   		}
   		else if(strcmp(token, "pull") == 0){
   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		IRCodeArray[i].isop1Num = false;
   			for ( j = 0; j < VARIABLES_COUNT; ++j)
   			{
   				if(strcmp(SymbolTable[j].varName,token)==0)break;
   			}
   			IRCodeArray[i].op1 = SymbolTable + j;
    	}
   		else if(strcmp(token, "push") == 0){
   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
    			IRCodeArray[i].isop1Num = true;
    			IRCodeArray[i].op1 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op1) = atoi(token);
    		}else{
    			IRCodeArray[i].isop1Num = false;
	   			for ( j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op1 = SymbolTable + j;
    		}
   		}
   		else if(strcmp(token, "moveSP") == 0){
   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
			IRCodeArray[i].isop1Num = true;
			IRCodeArray[i].op1 = (int *)malloc(sizeof(int));
			*(int *)(IRCodeArray[i].op1) = atoi(token);
   		}
   		else if(strcmp(token, "Print") == 0){
   			token = strtok(NULL, ", ");
	    	if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
    			IRCodeArray[i].isop1Num = true;
    			IRCodeArray[i].op1 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op1) = atoi(token);
    		}else{
	   			IRCodeArray[i].isop1Num = false;
	   			for ( j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op1 = SymbolTable + j;
   			}
   		}
   		else if(strcmp(token, "PrintChar") == 0){
   			token = strtok(NULL, ", ");
	    	if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
    			IRCodeArray[i].isop1Num = true;
    			IRCodeArray[i].op1 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op1) = atoi(token);
    		}else{
	   			IRCodeArray[i].isop1Num = false;
	   			for ( j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op1 = SymbolTable + j;
   			}
   		}
   		else if(strcmp(token, "PrintStr") == 0){
   			token = strtok(NULL, ", ");
	    	if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		IRCodeArray[i].isop1Num = false;
   			IRCodeArray[i].op1 = (char *)malloc(strlen(token)+2);
	   		strcpy(IRCodeArray[i].op1,token);	
   		}
   		else if(strcmp(token, "getreturnval") == 0){
   			token = strtok(NULL, ", ");
	    	if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
			IRCodeArray[i].isop1Num = false;
   			for ( j = 0; j < VARIABLES_COUNT; ++j)
   			{
   				if(strcmp(SymbolTable[j].varName,token)==0)break;
   			}
   			IRCodeArray[i].op1 = SymbolTable + j;
   		}
   		else if(strcmp(token, "ifgoto")==0){
   			token = strtok(NULL, ", ");
   			IRCodeArray[i].isop1Num = false;
	   		IRCodeArray[i].op1 = (char *)malloc(strlen(token)+2);
	   		strcpy(IRCodeArray[i].op1,token);

   			token = strtok(NULL, ", ");
   			if(isValidNumber(token)){
   				IRCodeArray[i].isop2Num = true;
    			IRCodeArray[i].op2 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op2) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop2Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op2 = SymbolTable + j;
   			}

   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
   			if(isValidNumber(token)){
   				IRCodeArray[i].isop3Num = true;
    			IRCodeArray[i].op3 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op3) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop3Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op3 = SymbolTable + j;
   			}

   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		// IRCodeArray[i].isop4Num = true;
	   		// IRCodeArray[i].op4 = (int *)malloc(sizeof(int));
   			// *(int *)(IRCodeArray[i].op4) = atoi(token);

   			if(isValidNumber(token)){
    			IRCodeArray[i].isop4Num = true;
    			IRCodeArray[i].op4 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op4) = atoi(token);
    		}else{
	   			IRCodeArray[i].isop4Num = false;
	   			IRCodeArray[i].op4 = (char *)malloc(strlen(token)+2);
	   			strcpy(IRCodeArray[i].op4,token);
   			}

   		}
   		else if(strcmp(token, "readarr")==0 || strcmp(token, "writearr")==0){
   			token = strtok(NULL, ", ");
   			IRCodeArray[i].isop1Num = false;
   			for (j = 0; j < VARIABLES_COUNT; ++j)
   			{
   			// printf("for token is %s\n",SymbolTable[j].varName);
   			// printf("token is %s\n",token);
   				if(strcmp(SymbolTable[j].varName,token)==0){
   					break;
   				}
   			}
   			IRCodeArray[i].op1 = SymbolTable + j;

   			token = strtok(NULL, ", ");
   			if(isValidNumber(token)){
   				IRCodeArray[i].isop2Num = true;
    			IRCodeArray[i].op2 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op2) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop2Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op2 = SymbolTable + j;
   			}

   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
   			if(isValidNumber(token)){
   				IRCodeArray[i].isop3Num = true;
    			IRCodeArray[i].op3 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op3) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop3Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op3 = SymbolTable + j;
   			}
   		}
   		else if(strcmp(token, "=")==0){
   			token = strtok(NULL, ", ");
   			IRCodeArray[i].isop1Num = false;
   			for (j = 0; j < VARIABLES_COUNT; ++j)
   			{
   				if(strcmp(SymbolTable[j].varName,token)==0)break;
   			}
   			IRCodeArray[i].op1 = SymbolTable + j;

   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
   				IRCodeArray[i].isop2Num = true;
    			IRCodeArray[i].op2 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op2) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop2Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}

	   			IRCodeArray[i].op2 = SymbolTable + j;
   			}
   		}
   		else if(strcmp(token, "~")==0){
   			token = strtok(NULL, ", ");
   			IRCodeArray[i].isop1Num = false;
   			for (j = 0; j < VARIABLES_COUNT; ++j)
   			{
   				if(strcmp(SymbolTable[j].varName,token)==0)break;
   			}
   			IRCodeArray[i].op1 = SymbolTable + j;

   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
    		if(isValidNumber(token)){
   				IRCodeArray[i].isop2Num = true;
    			IRCodeArray[i].op2 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op2) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop2Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}

	   			IRCodeArray[i].op2 = SymbolTable + j;
   			}
   		}
   		else{
   			token = strtok(NULL, ", ");
   			IRCodeArray[i].isop1Num = false;
   			for (j = 0; j < VARIABLES_COUNT; ++j)
   			{
   				if(strcmp(SymbolTable[j].varName,token)==0)break;
   			}

   			IRCodeArray[i].op1 = SymbolTable + j;

   			token = strtok(NULL, ", ");
   			if(isValidNumber(token)){
   				IRCodeArray[i].isop2Num = true;
    			IRCodeArray[i].op2 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op2) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop2Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op2 = SymbolTable + j;
   			}

   			token = strtok(NULL, ", ");
   			if(token[strlen(token)-1] == '\n')
    			token[strlen(token)-1] = 0;
   			if(isValidNumber(token)){
   				IRCodeArray[i].isop3Num = true;
    			IRCodeArray[i].op3 = (int *)malloc(sizeof(int));
    			*(int *)(IRCodeArray[i].op3) = atoi(token);
   			}else{
	   			IRCodeArray[i].isop3Num = false;
				for (j = 0; j < VARIABLES_COUNT; ++j)
	   			{
	   				if(strcmp(SymbolTable[j].varName,token)==0)break;
	   			}
	   			IRCodeArray[i].op3 = SymbolTable + j;
   			}

   		}
	    i++;
	}
	//finding leaders-------------
	bool isLeader[LINES];
	for (int i = 0; i < LINES; ++i)
	{
		isLeader[i]=false;
	}

	isLeader[0]=true;
	for (int i = 0; i < LINES; ++i)
	{
		if(strcmp(IRCodeArray[i].operator, "ifgoto")==0){
			if(i==LINES-1)break;
			isLeader[i+1] = true;
			if(IRCodeArray[i].isop4Num)
				isLeader[*((int *)(IRCodeArray[i].op4))-1] = true;
		}
		else if(strcmp(IRCodeArray[i].operator, "goto")==0){
			if(i==LINES-1)break;
			isLeader[i+1] = true;
			if(IRCodeArray[i].isop1Num)
				isLeader[*((int *)(IRCodeArray[i].op1))-1] = true;
		}
		else if(strcmp(IRCodeArray[i].operator, "label")==0){
			isLeader[i] = true;
		}
		else if(strcmp(IRCodeArray[i].operator, "Print")==0 || 
				strcmp(IRCodeArray[i].operator, "return")==0 ||
				strcmp(IRCodeArray[i].operator, "scan")==0 ||
				strcmp(IRCodeArray[i].operator, "PrintChar")==0 ||
				strcmp(IRCodeArray[i].operator, "PrintStr")==0  ){
			if(i==LINES-1)break;
			isLeader[i+1] = true;
		}
		else if(strcmp(IRCodeArray[i].operator, "function")==0){
			isLeader[i] = true;
		}else if(strcmp(IRCodeArray[i].operator, "call")==0){
			if(i==LINES-1)break;
			isLeader[i+1] = true;
		}
	}

	//constructing next use table
	int leaderCount=0;
	for (int i = 0; i < LINES; ++i){
		if(isLeader[i]){
			leaderCount++;
		}
	}
	int leaders[leaderCount];
	j=0;
	for (int i = 0; i < LINES; ++i){
		if(isLeader[i]){
			leaders[j] = i;
			j++;
		}
	}

	int startIns,endIns;
	for(int i=0;i<leaderCount;i++){
		startIns = leaders[i];
		if(i==leaderCount-1)
			endIns=LINES-1;
		else
			endIns = leaders[i+1]-1;
		symbTableinit();
		for(int k=endIns;k>=startIns;k--){
			for(int j=0;j<VARIABLES_COUNT;j++){
				strcpy(NextUseTable[k].Table[j].varName,SymbolTable[j].varName);
				NextUseTable[k].Table[j].isLive = SymbolTable[j].isLive;
				NextUseTable[k].Table[j].liveAt = SymbolTable[j].liveAt;
			}

			if(strcmp(IRCodeArray[k].operator,"Print")==0){
				if(IRCodeArray[k].isop1Num==false){
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				}
			}
			if(strcmp(IRCodeArray[k].operator,"PrintChar")==0){
				if(IRCodeArray[k].isop1Num==false){
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				}
			}
			else if(strcmp(IRCodeArray[k].operator,"return")==0){
				if(IRCodeArray[k].isop1Num==false){
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				}
			}
			else if(strcmp(IRCodeArray[k].operator,"push")==0){
				if(IRCodeArray[k].isop1Num==false){
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				}
			}
			else if(strcmp(IRCodeArray[k].operator,"pull")==0){
				if(IRCodeArray[k].isop1Num==false){
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				}
			}
			else if(strcmp(IRCodeArray[k].operator,"getreturnval")==0){
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = false;
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = -1;
			}
			else if(strcmp(IRCodeArray[k].operator,"ifgoto")==0){
				if(IRCodeArray[k].isop2Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->liveAt = k;
				}
				if(IRCodeArray[k].isop3Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->liveAt = k;
				}
			}else if(strcmp(IRCodeArray[k].operator,"=")==0){
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = false;
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = -1;
				if(IRCodeArray[k].isop2Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->liveAt = k;
				}
			}else if(strcmp(IRCodeArray[k].operator,"~")==0){
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = false;
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = -1;
				if(IRCodeArray[k].isop2Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->liveAt = k;
				}
			}
			else if(strcmp(IRCodeArray[k].operator,"readarr")==0){
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				if(IRCodeArray[k].isop2Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->liveAt = k;
				}
				if(IRCodeArray[k].isop3Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->isLive = false;
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->liveAt = -1;
				}
			}else if ( strcmp(IRCodeArray[k].operator,"writearr")==0){
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = true;
				((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = k;
				if(IRCodeArray[k].isop2Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->liveAt = k;
				}
				if(IRCodeArray[k].isop3Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->liveAt = k;
				}
			}
			else if(strcmp(IRCodeArray[k].operator,"+")==0 ||
						strcmp(IRCodeArray[k].operator,"-")==0 ||
						strcmp(IRCodeArray[k].operator,"*")==0 ||
						strcmp(IRCodeArray[k].operator,"/")==0 ||
						strcmp(IRCodeArray[k].operator,"rem")==0 ||
						strcmp(IRCodeArray[k].operator,"|")==0 ||
						strcmp(IRCodeArray[k].operator,"&")==0 ||
						strcmp(IRCodeArray[k].operator,"<<")==0 ||
						strcmp(IRCodeArray[k].operator,">>")==0){
				if(IRCodeArray[k].isop1Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->isLive = false;
					((struct SymbolTableEntry *)IRCodeArray[k].op1)->liveAt = -1;
				}
				if(IRCodeArray[k].isop2Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op2)->liveAt = k;
				}
				if(IRCodeArray[k].isop3Num == false){
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->isLive = true;
					((struct SymbolTableEntry *)IRCodeArray[k].op3)->liveAt = k;
				}
			}

		}
	}
	//data section
	// int_array:  .word   0:36
	printf("\t.data\n");
	PrintStrings();
	// printf("_NEWLINE_:\t.asciiz\t\"\\n\"\n");
	for (int i = 0; i < VARIABLES_COUNT; ++i)
	{
		if(strstr(SymbolTable[i].varName, "$fp") != NULL)
			continue;
		printf("%s:\t.word\t%d\n", SymbolTable[i].varName,SymbolTable[i].arr_size);
	}



	//text section
	printf("\n\t.text\n");
	for(int i=0;i<leaderCount;i++){
		regDescinit();
		startIns = leaders[i];
		if(i==leaderCount-1)
			endIns=LINES-1;
		else
			endIns = leaders[i+1]-1;

		printf("L%d:\n",startIns+1);
		for(int k=startIns;k<=endIns;k++){
			translate(k);
			if(k==endIns) storeAllInMem();
		}
	}
	printf("\n_print_int:\n");
	printf("li $v0, 1\n");
	printf("syscall\n");
	printf("jr $ra\n");
	// printf("li $v0, 4\n");
    // printf("la $a0, _NEWLINE_\n");
	// printf("syscall\n");
	
	printf("\n_print_char:\n");
	printf("li $v0, 11\n");
	printf("syscall\n");
	printf("jr $ra\n");

	printf("\n_print_str:\n");
	printf("li $v0, 4\n");
	printf("syscall\n");
	printf("jr $ra\n");

	printf("\n_scan_int:\n");
	printf("li $v0, 5\n");
	printf("syscall\n");
	printf("jr $ra\n");
	fclose(fp);
	int stat=system("rm ./ir_code.txt");
	stat = system("rm ./var.txt");
	return 0;
}
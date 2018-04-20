//PrintStr PrintChar push pull
%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_RESET   "\x1b[0m"

#define TYPE_INT 0
#define TYPE_CHAR 1
#define TYPE_BOOL 2
#define TYPE_INT_ARRAY 3
#define TYPE_CHAR_ARRAY 4
#define TYPE_BOOL_ARRAY 5
#define TYPE_VOID 6
int isStruct=0,_Struct_Index_=0;
int method_call_counter=0;
int _TYPE_,_ARRAYSIZE_=0;
int yyerror(char *);
int yylex(void);
FILE *f,*outFile;
extern FILE *yyin;
extern int LINE_NO;
typedef struct Node
{
    char *s;
    struct Node *next;
    struct Node *prev;
} Node;

FILE *VariableOutFile;
FILE * stringFile;

Node *head;

const int NON_TERM_COUNT=65;
const char nonTermArray[65][30] = {"Block_or_Semi","Literal","Print_Stm","Print_Args","Print_Arg","Type","Base_Type",
"Other_Type","Expression_Opt","Expression","Conditional_Exp","Or_Exp","And_Exp",
"Logical_Or_Exp","Logical_Xor_Exp","Logical_And_Exp","Equality_Exp","Compare_Exp","Shift_Exp",
"Add_Exp","Mult_Exp","Unary_Exp","Primary_Exp","Primary","Arg_List_Opt","Arg_List","Stm_List",
"Statement","Then_Stm","Normal_Stm","Block","Variable_Decs","Variable_Decs_Global","Variable_Declarator","Variable_Declarator_Global",
"Variable_Initializer","For_Init_Opt","For_Iterator_Opt","For_Condition_Opt",
"Statement_Exp_List","Local_Var_Decl","Local_Var_Decl_Global","Statement_Exp","Assign_Tail","Method",
"Compilation_Unit","Class_Decl","Class_Item_Decs_Opt","Class_Item","Field_Dec",
"Method_Dec","Formal_Param_List_Opt","Formal_Param_List","Formal_Param",
"Array_Initializer","Variable_Initializer_List","Switch_Sections_Opt",
"Switch_Section","Switch_Labels","Switch_Label","Array_Size_Opt","Block_Start","Block_Start_M","Block_End"};

typedef struct FuncEntry{
    char name[30];
    int numArgs;
    int lineNum;
}FuncEntry;

struct FuncEntry DefinedFuncTable[200];
struct FuncEntry CalledFuncTable[200];
int DefinedFuncTableCounter=0;
int CalledFuncTableCounter=0;

typedef struct StringEntry{
    char *string;
}StringEntry;

int StringArraySize=0;
struct StringEntry StringArray[150];


char *StoreString(char *s){
    for (int i = 0; i < StringArraySize; ++i)
    {
        if(strcmp(StringArray[i].string,s)==0){
            char *buf = (char *)malloc(20*sizeof(char));
            sprintf(buf,"string%d",i);
            return buf;
        }
    }
    StringArray[StringArraySize].string = (char *)malloc(50*sizeof(char));
    sprintf(StringArray[StringArraySize].string,"%s",s);
    char *buf = (char *)malloc(20*sizeof(char));
    sprintf(buf,"string%d",StringArraySize);
    StringArraySize++;
    return buf;
}

void PrintStrings(){
    for (int i = 0; i < StringArraySize; ++i)
    {
        printf("string%d:\t.asciiz\t\"%s\"\n",i,StringArray[i].string);
    }
    return;
}

typedef struct Sym_Entry{
    char iden_name[30];
    int var_type;
    int arr_size;
    int structIndex;
    char ref_name[30];
}Sym_Entry;

int temp_var_count=0;
int temp_label_count=0;

typedef struct SymbolTableStruct
{
  struct Sym_Entry Table[150];
  int offset;
  int curr_offset;
  int var_count;
  struct SymbolTableStruct * parent;
}SymbolTableStruct;

struct SymbolTableStruct * CurrentTable;

char * NewTempVar(){
    char * temp = (char*)malloc(10*sizeof(char));
    sprintf(temp,"var%d",temp_var_count);
    fprintf(VariableOutFile, "var%d, 0\n", temp_var_count);
    temp_var_count++;
    return temp;
}

char * NewTempLabel(){
    char * temp = (char*)malloc(10*sizeof(char));
    sprintf(temp,"label%d",temp_label_count);
    temp_label_count++;
    return temp;
}

char * RegisterVar(char * iden_name, int var_type,int arr_size,int loc,int offset){
    SymbolTableStruct * t = CurrentTable;
    for (int i = 0; i < t->var_count; ++i)
    {
        if(strcmp(iden_name,t->Table[i].iden_name)==0)
            return "error";
    }
    int i = CurrentTable->var_count;
    CurrentTable->var_count++;

    if(isStruct==1){
        CurrentTable->Table[i].structIndex = _Struct_Index_;
    }

    if(arr_size==0)
        CurrentTable->curr_offset+=4;
    else
        CurrentTable->curr_offset+=arr_size*4;

    sprintf(CurrentTable->Table[i].iden_name,"%s",iden_name);
    CurrentTable->Table[i].var_type=var_type;
    CurrentTable->Table[i].arr_size=arr_size;
    if (loc==0){
        sprintf(CurrentTable->Table[i].ref_name,"var%d",temp_var_count);
        if(arr_size==0)
            fprintf(VariableOutFile, "var%d, 0\n", temp_var_count);
        else
            fprintf(VariableOutFile, "var%d, %d\n", temp_var_count, arr_size);
        temp_var_count++;
    }
    else{
        if(arr_size==0){
            sprintf(CurrentTable->Table[i].ref_name,"-%d($fp)",offset);
            fprintf(VariableOutFile, "-%d($fp), 0\n", offset);
        }
        else{
            sprintf(CurrentTable->Table[i].ref_name,"-%d($fp)",offset+(arr_size-1)*4);
            fprintf(VariableOutFile, "-%d($fp), %d\n", offset+(arr_size-1)*4,arr_size);
        }

    }
    // printf("var: %s ref: %s",CurrentTable->Table[i].iden_name,CurrentTable->Table[i].ref_name);
    return CurrentTable->Table[i].ref_name;
}

int VarType(char *iden_name){
    SymbolTableStruct * t = CurrentTable;
    while(t!=NULL){
        // printf("in %d\n",t->var_count);
        for (int i = 0; i < t->var_count; ++i)
        {
            // printf("var: %s\n",t->Table[i].iden_name);
            if(strcmp(iden_name,t->Table[i].iden_name)==0){
                return t->Table[i].var_type;
            }
        }
        t=t->parent;
    }
    return -1;
}

int StructIndex(char *iden_name){
    SymbolTableStruct * t = CurrentTable;
    while(t!=NULL){
        for (int i = 0; i < t->var_count; ++i)
        {
            if(strcmp(iden_name,t->Table[i].iden_name)==0)
                return t->Table[i].structIndex;
        }
        t=t->parent;
    }
    return -1;
}


int ArrSize(char *iden_name){
    SymbolTableStruct * t = CurrentTable;
    while(t!=NULL){
        for (int i = 0; i < t->var_count; ++i)
        {
            if(strcmp(iden_name,t->Table[i].iden_name)==0)
                return t->Table[i].arr_size;
        }
        t=t->parent;
    }
    return -1;
}

char * ReqRefName(char *iden_name){
    SymbolTableStruct * t = CurrentTable;
    while(t!=NULL){
        for (int i = 0; i < t->var_count; ++i)
        {
            if(strcmp(iden_name,t->Table[i].iden_name)==0)
                return t->Table[i].ref_name;
        }
        t=t->parent;
    }
    return "error";
}

int DefinedFunc(char *name,int args){
    for (int i = 0; i < DefinedFuncTableCounter; ++i)
    {
        if(strcmp(DefinedFuncTable[i].name,name)==0)return 0;
    }
    sprintf(DefinedFuncTable[DefinedFuncTableCounter].name,"%s",name);
    DefinedFuncTable[DefinedFuncTableCounter].numArgs=args;
    DefinedFuncTableCounter++;
    return 1;
}

void CalledFunc(char *name,int args, int lineNum){
    sprintf(CalledFuncTable[CalledFuncTableCounter].name,"%s",name);
    CalledFuncTable[CalledFuncTableCounter].numArgs=args;
    CalledFuncTable[CalledFuncTableCounter].lineNum=lineNum;
    CalledFuncTableCounter++;
}

void pushNode(Node** head_ref, char* str)
{
    Node* new_node = (Node*) malloc(sizeof(Node));

    new_node->s  = strdup(str);
    new_node->next = NULL;
    new_node->prev = NULL;
    Node *t;
    t = *head_ref;
    if(t==NULL){
        *head_ref = new_node;
        return;
    }
    while(t->next != NULL){
        t=t->next;
    }
    t->next = new_node;
    new_node->prev = t;

}

int isNonTerminal(char *s){
    for (int i = 0; i < NON_TERM_COUNT; ++i)
    {
        if(strcmp(nonTermArray[i],s)==0){
            return 1;
        }
    }
    return 0;
}


typedef struct ArrayElement{
    char val[30];
    struct ArrayElement * next;
}ArrayElement;

void pushArrayElement(struct ArrayElement ** head, char * val){
    ArrayElement *node = (ArrayElement *)malloc(sizeof(ArrayElement));
    sprintf(node->val,"%s",val);
    ArrayElement *t;
    t = *head;
    if(t==NULL){
        *head = node;
        return;
    }
    while(t->next!=NULL)
        t=t->next;
    t->next = node;
    return;
}

typedef struct Code{
    char line[70];
}Code;

typedef struct node
{
    Code * code;
    int numLines;
    int type;
    int numArgs;
    int isArray;
    struct ArrayElement * arrayList;
    char * place;
    char * extra_info;
}node;

struct StructMember{
    int type;
    char member_name[50];
    int arr_size;
};

struct StructMemberList{
    struct StructMember memberArray[20];
    int memberCount;
};

struct StructDef{
    char struct_name[50];
    struct StructMember memberArray[20];
    int memberCount;
};

struct StructDef structDefArray[20];
int structDefArrayIndex=0;


%}

%union {
    char id[30];
    int dec_val;
    int bool_val;
    char char_val;
    char string_val[50];
    struct node *ptr;
    struct StructMemberList * memberList;
};

%type <ptr> Struct_Dec Type_Struct Base_Type_Struct 
%type <memberList> Member_Decl
%type <memberList> Variable_Decs_Struct
%token <ptr> token_struct

%type <ptr> Block_or_Semi Literal Print_Stm Print_Args Print_Arg Type Base_Type
%type <ptr> Other_Type Expression_Opt Expression Conditional_Exp Or_Exp And_Exp
%type <ptr> Logical_Or_Exp Logical_Xor_Exp Logical_And_Exp Equality_Exp Compare_Exp Shift_Exp
%type <ptr> Add_Exp Mult_Exp Unary_Exp Primary_Exp Primary Arg_List_Opt Arg_List Stm_List
%type <ptr> Statement Then_Stm Normal_Stm Block Variable_Decs Variable_Decs_Global Variable_Declarator Variable_Declarator_Global
%type <ptr> Variable_Initializer For_Init_Opt For_Iterator_Opt For_Condition_Opt
%type <ptr> Statement_Exp_List Local_Var_Decl Local_Var_Decl_Global Statement_Exp Assign_Tail Method
%type <ptr> Compilation_Unit Class_Decl Class_Item_Decs_Opt Class_Item Field_Dec
%type <ptr> Method_Dec Formal_Param_List_Opt Formal_Param_List Formal_Param
%type <ptr> Array_Initializer Variable_Initializer_List Switch_Sections_Opt
%type <ptr> Switch_Section Switch_Labels Switch_Label Block_Start Block_Start_M Block_End

%start Compilation_Unit

%token <ptr> token_class
%token <id> token_identifier
%token <ptr> token_int
%token <ptr> token_char
%token <ptr> token_bool
%token <ptr> token_void
%token <bool_val> token_true
%token <bool_val> token_false
%token <ptr> token_if
%token <ptr> token_while
%token <ptr> token_else
%token <ptr> token_for
%token <ptr> token_continue
%token <ptr> token_switch
%token <string_val> token_string_literal
%token <ptr> token_return
%token <ptr> token_endl
%token <dec_val> token_dec_literal
%token <dec_val> token_char_literal
%token <ptr> token_case
%token <ptr> token_break
%token <ptr> token_default
%token <ptr> token_print
%token <ptr> token_is
%token <ptr> token_plus_plus
%token <ptr> token_minus_minus
%token <ptr> token_plus_assign
%token <ptr> token_minus_assign
%token <ptr> token_bit_xor_assign
%token <ptr> token_bit_and_assign
%token <ptr> token_bit_or_assign
%token <ptr> token_remainder_assign
%token <ptr> token_eq
%token <ptr> token_not_eq
%token <ptr> token_less_eq
%token <ptr> token_greater_eq
%token <ptr> token_shift_left_assign
%token <ptr> token_shift_right_assign
%token <ptr> token_shift_left
%token <ptr> token_shift_right
%token <ptr> token_cond_and
%token <ptr> token_cond_or
%token <ptr> token_mul_assign
%token <ptr> token_quotient_assign

%%

Block_or_Semi:
            Block   {$$=$1;}
            | ';'   {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            ;

Block_Start:
                {
                    SymbolTableStruct * t = (SymbolTableStruct*)malloc(sizeof(SymbolTableStruct));
                    t->parent = CurrentTable;
                    t->offset=CurrentTable->offset+(4*CurrentTable->var_count);
                    t->var_count=0;
                    t->curr_offset=0;
                    CurrentTable = t;

                }
            ;
Block_Start_M:
                {
                    SymbolTableStruct * t = (SymbolTableStruct*)malloc(sizeof(SymbolTableStruct));
                    t->parent = CurrentTable;
                    t->offset=4;
                    t->var_count=0;
                    t->curr_offset=0;
                    CurrentTable = t;
                }
            ;

Block_End:
                {
                    CurrentTable = CurrentTable->parent;
                }
            ;

Literal:
            token_true {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_BOOL;
                p->place = (char*)malloc(10*sizeof(char));
                sprintf(p->place,"1");
                $$=p;
            }
            |  token_false {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_BOOL;
                p->place = (char*)malloc(10*sizeof(char));
                sprintf(p->place,"0");
                $$=p;
            }
            |  token_dec_literal {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_INT;
                p->place = (char*)malloc(10*sizeof(char));
                sprintf(p->place,"%d",$1);
                $$=p;}
            |  token_char_literal       {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_CHAR;
                p->place = (char*)malloc(4*sizeof(char));
                sprintf(p->place,"%d",$1);
                $$=p;
            }
            ;

Print_Stm:
            token_print Print_Args ';' {$$=$2;}
            ;

Print_Args:
            Print_Arg '+' Print_Args {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<$1->numLines+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-$1->numLines].line);
                }
                $$=p;
            }
            | Print_Arg {$$=$1;}
            | {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            ;

Print_Arg:
            token_string_literal {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                char *strRef = StoreString($1);
                sprintf(p->code[0].line,"PrintStr, %s",strRef);
                $$=p;
            }
            | token_identifier  {
                char *temp = ReqRefName($1);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                if(VarType($1)==TYPE_CHAR)
                    sprintf(p->code[0].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[0].line,"Print, %s",temp);
                $$=p;

            }
            | token_identifier '.' token_identifier  {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *temp = ReqRefName(name);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$1,$3);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                if(VarType(name)==TYPE_CHAR)
                    sprintf(p->code[0].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[0].line,"Print, %s",temp);
                $$=p;

            }
            | token_identifier '[' token_dec_literal ']'  {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$3,temp);
                if(VarType($1)==TYPE_CHAR_ARRAY)
                    sprintf(p->code[1].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[1].line,"Print, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_identifier '.' token_identifier '[' token_dec_literal ']'  {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$5,temp);
                if(VarType($1)==TYPE_CHAR_ARRAY)
                    sprintf(p->code[1].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[1].line,"Print, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_identifier '[' token_identifier ']' {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                char *index = ReqRefName($3);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$3);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                myType = VarType($3);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                if(VarType($1)==TYPE_CHAR_ARRAY)
                    sprintf(p->code[1].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[1].line,"Print, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;


            }
            | token_identifier '.' token_identifier '[' token_identifier ']' {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                char *index = ReqRefName($5);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$5);
                    yyerror(buf);
                }

                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                myType = VarType($5);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$5);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                if(VarType($1)==TYPE_CHAR_ARRAY)
                    sprintf(p->code[1].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[1].line,"Print, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;


            }
            | token_identifier '[' token_identifier '.' token_identifier ']' {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *index = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$3,$5);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                myType = VarType(name);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                if(VarType($1)==TYPE_CHAR_ARRAY)
                    sprintf(p->code[1].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[1].line,"Print, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;


            }
            | token_identifier '.' token_identifier '[' token_identifier '.' token_identifier ']' {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$1,$3);
                    yyerror(buf);
                }
                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                // char name[40];
                sprintf(name,"struct_%s_%s",$5,$7);
                char *index = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$5,$7);
                    yyerror(buf);
                }


                myType = VarType(name);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s.%s' is not Int type",LINE_NO,$5,$7);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                if(VarType($1)==TYPE_CHAR_ARRAY)
                    sprintf(p->code[1].line,"PrintChar, %s",temp);
                else
                    sprintf(p->code[1].line,"Print, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;


            }
            | token_endl {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"PrintStr, string0");
                $$=p;
            }
            ;


Type:
            Other_Type {_TYPE_=$1->type, $$=$1;}
            | Base_Type {_TYPE_=$1->type;$$=$1;}
            | Base_Type'['']' {
                if($1->type==TYPE_INT)
                    _TYPE_=TYPE_INT_ARRAY;
                else if($1->type==TYPE_CHAR)
                    _TYPE_=TYPE_CHAR_ARRAY;
                else
                    _TYPE_=TYPE_BOOL_ARRAY;
                _ARRAYSIZE_=0;
            }
            | Base_Type'[' token_dec_literal ']' {
                if($1->type==TYPE_INT)
                    _TYPE_=TYPE_INT_ARRAY;
                else if($1->type==TYPE_CHAR)
                    _TYPE_=TYPE_CHAR_ARRAY;
                else
                    _TYPE_=TYPE_BOOL_ARRAY;
                _ARRAYSIZE_=$3;
            }
            ;

Base_Type:
            token_int {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_INT;
                $$=p;
            }
            | token_char {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_CHAR;
                $$=p;
            }
            | token_bool {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_BOOL;
                $$=p;
            }
            ;

Other_Type:
            token_void {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_VOID;
                $$=p;
            }
            ;


Expression_Opt:
            Expression {$$=$1;}
            |   {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            ;

Expression:
             Conditional_Exp '=' Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"=, %s, %s",$1->place, $3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
             }
            |  Conditional_Exp token_plus_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"+, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_minus_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"-, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_mul_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"*, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_quotient_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"/, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_bit_xor_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=5 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                //A.~B + ~A.B
                char *t1=NewTempVar();
                char *t2=NewTempVar();
                //~, t1, 2.place
                //&, t1, temp, t1
                //~, t2, temp
                //&, t2, t2, 2.place
                //|, temp, t1 ,t2
                sprintf(p->code[p->numLines-5].line,"~, %s, %s",t1,$3->place);
                sprintf(p->code[p->numLines-4].line,"&, %s, %s, %s",t1,$1->place,t1);
                sprintf(p->code[p->numLines-3].line,"~, %s, %s",t2,$1->place);
                sprintf(p->code[p->numLines-2].line,"&, %s, %s, %s",t2,t2,$3->place);
                sprintf(p->code[p->numLines-1].line,"|, %s, %s, %s",$1->place,t1,t2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_bit_and_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"&, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_bit_or_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"|, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_remainder_assign  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"rem, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_shift_left_assign Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,"<<, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp token_shift_right_assign Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                sprintf(p->code[j].line,">>, %s, %s, %s",$1->place,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$1->place);
                $$=p;
            }
            |  Conditional_Exp {$$=$1;}
            ;

Conditional_Exp:
            Or_Exp '?' Or_Exp ':' Conditional_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines + $5->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j = $1->numLines + $3->numLines;
                for(int i=j;i<j+$5->numLines;i++){
                    sprintf(p->code[i].line,"%s",$5->code[i-j].line);
                }
                j = $1->numLines + $3->numLines + $5->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                // ifgoto, !=, Or_Exp.place, 0, label1
                // temp = Conditional_Exp.place
                // goto, label2
                // label, label1
                // temp = Or_Exp.place
                // label, label2
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$1->place, label1);
                sprintf(p->code[j+1].line,"=, %s, %s",temp,$5->place);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, %s",temp,$3->place);
                sprintf(p->code[j+5].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Or_Exp {$$=$1;}
            ;

Or_Exp:
            Or_Exp token_cond_or And_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=10 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                char *label3=NewTempLabel();
                // ifgoto, ==, 1.place, 0, label1
                // temp=1
                // goto, label2
                // label, label1
                // ifgoto, ==, 2.place, 0, label3
                // temp=1
                // goto, label2
                // label, label3
                // temp=0
                // label, label2
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$1->place, label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"ifgoto, !=, %s, 0, %s",$3->place, label3);
                sprintf(p->code[j+5].line,"=, %s, 0",temp);
                sprintf(p->code[j+6].line,"goto, %s",label2);
                sprintf(p->code[j+7].line,"label, %s",label3);
                sprintf(p->code[j+8].line,"=, %s, 1",temp);
                sprintf(p->code[j+9].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  And_Exp {$$=$1;}
            ;
And_Exp:
            And_Exp token_cond_and Logical_Or_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=10 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                char *label3=NewTempLabel();

                // ifgoto, !=, 1.place, 0, label1
                // temp=0
                // goto, label2
                // label, label1
                // ifgoto, !=, 2.place, 0, label3
                // temp=0
                // goto, label2
                // label, label3
                // temp=1
                // label, label2

                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$1->place, label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"ifgoto, !=, %s, 0, %s",$3->place, label3);
                sprintf(p->code[j+5].line,"=, %s, 0",temp);
                sprintf(p->code[j+6].line,"goto, %s",label2);
                sprintf(p->code[j+7].line,"label, %s",label3);
                sprintf(p->code[j+8].line,"=, %s, 1",temp);
                sprintf(p->code[j+9].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Logical_Or_Exp {$$=$1;}
            ;

Logical_Or_Exp:
            Logical_Or_Exp '|' Logical_Xor_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"|, %s, %s, %s",temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Logical_Xor_Exp {$$=$1;}
            ;

Logical_Xor_Exp:
            Logical_Xor_Exp '^' Logical_And_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=5 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *t1=NewTempVar();
                char *t2=NewTempVar();
                char *temp=NewTempVar();
                //~, t1, 2.place
                //&, t1, temp, t1
                //~, t2, temp
                //&, t2, t2, 2.place
                //|, temp, t1 ,t2
                sprintf(p->code[j+0].line,"~, %s, %s",t1,$3->place);
                sprintf(p->code[j+1].line,"&, %s, %s, %s",t1,$1->place,t1);
                sprintf(p->code[j+2].line,"~, %s, %s",t2,$1->place);
                sprintf(p->code[j+3].line,"&, %s, %s, %s",t2,t2,$3->place);
                sprintf(p->code[j+4].line,"|, %s, %s, %s",temp,t1,t2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Logical_And_Exp {$$=$1;}
            ;

Logical_And_Exp:
            Logical_And_Exp '&' Equality_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"&, %s, %s, %s",temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Equality_Exp {$$=$1;}
            ;

Equality_Exp:
            Equality_Exp token_eq Compare_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j+0].line,"ifgoto, ==, %s, %s, %s",$1->place,$3->place,label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, 1",temp);
                sprintf(p->code[j+5].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Equality_Exp token_not_eq Compare_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j+0].line,"ifgoto, !=, %s, %s, %s",$1->place,$3->place,label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, 1",temp);
                sprintf(p->code[j+5].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Compare_Exp {$$=$1;}
            ;

Compare_Exp:
            Compare_Exp '<' Shift_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j].line,"ifgoto, <, %s, %s, %s",$1->place,$3->place,label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, 1",temp);
                sprintf(p->code[j+5].line,"label, %s",label2);
                
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Compare_Exp '>' Shift_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j+0].line,"ifgoto, >, %s, %s, %s",$1->place,$3->place,label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, 1",temp);
                sprintf(p->code[j+5].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Compare_Exp token_less_eq Shift_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j+0].line,"ifgoto, <=, %s, %s, %s",$1->place,$3->place,label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, 1",temp);
                sprintf(p->code[j+5].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Compare_Exp token_greater_eq Shift_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j+0].line,"ifgoto, >=, %s, %s, %s",$1->place,$3->place,label1);
                sprintf(p->code[j+1].line,"=, %s, 0",temp);
                sprintf(p->code[j+2].line,"goto, %s",label2);
                sprintf(p->code[j+3].line,"label, %s",label1);
                sprintf(p->code[j+4].line,"=, %s, 1",temp);
                sprintf(p->code[j+5].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Compare_Exp token_is Type {}
            |  Shift_Exp {$$=$1;}
            ;

Shift_Exp:
            Shift_Exp token_shift_left Add_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"<<, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Shift_Exp token_shift_right Add_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,">>, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Add_Exp {$$=$1;}
            ;

Add_Exp:
            Add_Exp '+' Mult_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"+, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Add_Exp '-' Mult_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"-, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Mult_Exp {$$=$1;}
            ;

Mult_Exp:
            Mult_Exp '*' Unary_Exp  {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"*, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Mult_Exp '/' Unary_Exp  {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"/, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Mult_Exp '%' Unary_Exp  {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                j=$1->numLines+$3->numLines;
                char *temp=NewTempVar();
                sprintf(p->code[j].line,"rem, %s, %s, %s", temp,$1->place,$3->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Unary_Exp  {$$=$1;}
            ;

Unary_Exp:
            '!'  Unary_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=6 + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$2->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }
                int j = $2->numLines;
                char *temp = NewTempVar();
                char *label1 = NewTempLabel();
                char *label2 = NewTempLabel();
                // ifgoto, ==, Unary_Exp.place, 0, label1
                // temp=0
                // goto, label2
                // label, label1
                // temp=1
                // label, lable2
                sprintf(p->code[j].line,"ifgoto, ==, %s, 0, %s",$2->place,label1);
                sprintf(p->code[j].line,"=, %s, 0",temp);
                sprintf(p->code[j].line,"goto, %s",label2);
                sprintf(p->code[j].line,"label, %s",label1);
                sprintf(p->code[j].line,"=, %s, 1",temp);
                sprintf(p->code[j].line,"label, %s",label2);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  '~'  Unary_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$2->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }
                int j = $2->numLines;
                char *temp = NewTempVar();
                sprintf(p->code[j].line,"~, %s, %s",temp,$2->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  '-'  Unary_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$2->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }
                int j = $2->numLines;
                char *temp = NewTempVar();
                sprintf(p->code[j].line,"-, %s, 0, %s",temp,$2->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  '+'  Unary_Exp {$$=$2;}
            |  token_plus_plus Unary_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$2->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }
                int j = $2->numLines;
                // char *temp = NewTempVar();
                // sprintf(p->code[j].line,"=, %s, %s",temp,$2->place);
                sprintf(p->code[j].line,"+, %s, %s, 1",$2->place,$2->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$2->place);
                $$=p;
            }
            |  token_minus_minus Unary_Exp {
                //printf("%d\n",$2->numLines);
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1 + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$2->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }
                int j = $2->numLines;
                // char *temp = NewTempVar();
                // sprintf(p->code[j].line,"=, %s, %s",temp,$2->place);
                sprintf(p->code[j].line,"-, %s, %s, 1",$2->place,$2->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",$2->place);
                $$=p;
            }
            |  Unary_Exp token_minus_minus  {
                //printf("%d\n",$2->numLines);
                node *p = (node*)malloc(sizeof(node));
                p->numLines=2 + $1->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                char *temp = NewTempVar();
                sprintf(p->code[j].line,"=, %s, %s",temp,$1->place);
                sprintf(p->code[j+1].line,"-, %s, %s, 1",$1->place,$1->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Unary_Exp token_plus_plus  {
                //printf("%d\n",$2->numLines);
                node *p = (node*)malloc(sizeof(node));
                p->numLines=2 + $1->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                char *temp = NewTempVar();
                sprintf(p->code[j].line,"=, %s, %s",temp,$1->place);
                sprintf(p->code[j+1].line,"+, %s, %s, 1",$1->place,$1->place);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  Primary_Exp {$$=$1;}
            ;

Primary_Exp:
            Primary {$$=$1;}
            |  '(' Expression ')' {$$=$2;}
            |   Method {$$=$1;}
            ;

Primary:
            token_identifier {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                char *temp = ReqRefName($1);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_identifier '.' token_identifier {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *temp = ReqRefName(name);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$1,$3);
                    yyerror(buf);
                }
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_identifier '[' token_dec_literal ']' {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$3,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_identifier '.' token_identifier '[' token_dec_literal ']' {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' used but not declared",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$5,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_identifier '[' token_identifier ']' {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                char *index = ReqRefName($3);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$3);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                myType = VarType($3);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;

            }
            | token_identifier '.' token_identifier '[' token_identifier ']' {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                char *index = ReqRefName($5);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$5);
                    yyerror(buf);
                }

                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                myType = VarType($5);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$5);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;

            }
            | token_identifier '.' token_identifier '[' token_identifier '.' token_identifier ']' {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }
                // char name[40];
                sprintf(name,"struct_%s_%s",$5,$7);
                char *index = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$5);
                    yyerror(buf);
                }

                

                myType = VarType(name);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$5);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;

            }
            | token_identifier '[' token_identifier '.' token_identifier ']' {
                char name[40];
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$3);
                    yyerror(buf);
                }
                // char name[40];
                sprintf(name,"struct_%s_%s",$3,$5);
                char *index = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$5);
                    yyerror(buf);
                }

                

                myType = VarType(name);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$5);
                    yyerror(buf);
                }

                char *temp = NewTempVar();

                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  Literal        {$$=$1;}
            ;

Arg_List_Opt:
            Arg_List {
                $$=$1;
            }
            |  {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->numArgs=0;
                $$=p;
            }
            ;

Arg_List:
            Arg_List ',' Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1+$1->numLines+$3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                
                for(int i=0;i<$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i].line);
                }
                sprintf(p->code[$3->numLines].line,"push, %s",$3->place);
                for(int i=$3->numLines+1;i<$1->numLines+$3->numLines+1;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i-1-$3->numLines].line);
                }
                                

                // for(int i=0;i<$1->numLines;i++){
                //     sprintf(p->code[i].line,"%s",$1->code[i].line);
                // }
                // for(int i=$1->numLines;i<$1->numLines+$3->numLines;i++){
                //     sprintf(p->code[i].line,"%s",$3->code[i-$1->numLines].line);
                // }
                // sprintf(p->code[$1->numLines+$3->numLines].line,"push, %s",$3->place);
                p->numArgs=$1->numArgs+1;
                $$=p;

            }
            |  Expression {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1+$1->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                sprintf(p->code[$1->numLines].line,"push, %s",$1->place);
                p->numArgs=1;
                $$=p;
            }
            ;

Stm_List:
            Stm_List Statement {
                node *p = (node*)malloc(sizeof(node));
                p->numLines = $1->numLines + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<p->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i-$1->numLines].line);
                }
                $$=p;

            }
            |  Statement {$$=$1;}
            ;
Statement:
            Local_Var_Decl ';' {$$=$1;}
            |  token_if '(' Expression ')' Block_Start Statement Block_End {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$3->numLines+$6->numLines+4;

                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i].line);
                }
                int j=$3->numLines;
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$3->place,label1);
                sprintf(p->code[j+1].line,"goto, %s",label2);
                sprintf(p->code[j+2].line,"label, %s",label1);
                for(int i=j+3;i<$6->numLines+j+3;i++){
                    sprintf(p->code[i].line,"%s",$6->code[i-j-3].line);
                }
                sprintf(p->code[p->numLines-1].line,"label, %s",label2);

                $$=p;
            }
            |  token_if '(' Expression ')' Block_Start Then_Stm Block_End token_else Block_Start Statement Block_End {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$3->numLines+$6->numLines+$10->numLines+4;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i].line);
                }
                int j=$3->numLines;
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$3->place,label1);
                for(int i=j+1;i<$10->numLines+j+1;i++){
                    sprintf(p->code[i].line,"%s",$10->code[i-j-1].line);
                }
                j=$10->numLines+j;
                sprintf(p->code[j+1].line,"goto, %s",label2);
                sprintf(p->code[j+2].line,"label, %s",label1);
                for(int i=j+3;i<$6->numLines+j+3;i++){
                    sprintf(p->code[i].line,"%s",$6->code[i-j-3].line);
                }
                sprintf(p->code[p->numLines-1].line,"label, %s",label2);

                $$=p;
            }
            |  Block_Start token_for '(' For_Init_Opt ';' For_Condition_Opt ';' For_Iterator_Opt ')' Statement Block_End {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$4->numLines+$6->numLines+$8->numLines+$10->numLines+7;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$4->numLines;i++){
                    sprintf(p->code[i].line,"%s",$4->code[i].line);
                }

                int j=$4->numLines;
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                char *label3=NewTempLabel();
                char *label4=NewTempLabel();
                sprintf(p->code[j].line,"label, %s",label1);
                for(int i=j+1;i<$6->numLines+j+1;i++){
                    sprintf(p->code[i].line,"%s",$6->code[i-j-1].line);
                }
                j=$6->numLines+j+1;
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$6->place, label2);
                sprintf(p->code[j+1].line,"goto, %s",label3);
                sprintf(p->code[j+2].line,"label, %s",label2);
                for(int i=j+3;i<$10->numLines+j+3;i++){
                    if(strcmp($10->code[i-j-3].line,"break")==0){
                        sprintf(p->code[i].line,"goto, %s",label3);
                    }
                    else if(strcmp($10->code[i-j-3].line,"continue")==0){
                        // printf("asdfsad\n");
                        sprintf(p->code[i].line,"goto, %s",label4);
                    }
                    else
                        sprintf(p->code[i].line,"%s",$10->code[i-j-3].line);
                }
                j=$10->numLines+j+3;
                sprintf(p->code[j].line,"label, %s",label4);
                j++;
                for(int i=j;i<$8->numLines+j;i++){
                    sprintf(p->code[i].line,"%s",$8->code[i-j].line);
                }
                j=$8->numLines+j;
                //printf("XX");
                sprintf(p->code[j].line,"goto, %s",label1);
                sprintf(p->code[j+1].line,"label, %s",label3);
                $$=p;


            }
            |  token_while    '(' Expression ')' Block_Start Statement Block_End{
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$3->numLines + $6->numLines + 6;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                // label, label1
                // Expression.code
                // ifgoto, !=, exp.place, 0, label2
                // goto, label3
                // label, label2
                // Then_Stm.code
                // goto, label1
                // label, label3


                char *label1 = NewTempLabel();
                char *label2 = NewTempLabel();
                char *label3 = NewTempLabel();
                sprintf(p->code[0].line,"label, %s",label1);
                for (int i = 1; i < 1+$3->numLines; ++i)
                {
                    sprintf(p->code[i].line,"%s",$3->code[i-1].line);
                }
                int j = 1+$3->numLines;
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$3->place,label2);
                sprintf(p->code[j+1].line,"goto, %s",label3);
                sprintf(p->code[j+2].line,"label, %s",label2);
                j=j+3;
                for (int i = j; i < j+$6->numLines; ++i)
                {
                    if(strcmp($6->code[i-j].line,"break")==0){
                        sprintf(p->code[i].line,"goto, %s",label3);
                    }
                    else if(strcmp($6->code[i-j].line,"continue")==0){
                        sprintf(p->code[i].line,"goto, %s",label1);
                    }
                    else
                        sprintf(p->code[i].line,"%s",$6->code[i-j].line);
                }
                j=j+$6->numLines;
                sprintf(p->code[j].line,"goto, %s",label1);
                sprintf(p->code[j+1].line,"label, %s",label3);
                $$=p;

            }
            |  Normal_Stm   {$$=$1;}
            ;

Then_Stm:
            token_if '(' Expression ')' Block_Start Then_Stm Block_End token_else Block_Start Then_Stm Block_End {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$3->numLines+$6->numLines+$10->numLines+4;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i].line);
                }
                int j=$3->numLines;
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$3->place,label1);
                for(int i=j+1;i<$10->numLines+j+1;i++){
                    sprintf(p->code[i].line,"%s",$10->code[i-j-1].line);
                }
                j=$10->numLines+j;
                sprintf(p->code[j+1].line,"goto, %s",label2);
                sprintf(p->code[j+2].line,"label, %s",label1);
                for(int i=j+3;i<$6->numLines+j+3;i++){
                    sprintf(p->code[i].line,"%s",$6->code[i-j-3].line);
                }
                sprintf(p->code[p->numLines-1].line,"label, %s",label2);

                $$=p;
            }

            |  Block_Start token_for '(' For_Init_Opt ';' For_Condition_Opt ';' For_Iterator_Opt ')' Then_Stm Block_End{
                // printf("here1\n");
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$4->numLines+$6->numLines+$8->numLines+$10->numLines+7;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$4->numLines;i++){
                    sprintf(p->code[i].line,"%s",$4->code[i].line);
                }

                int j=$4->numLines;
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                char *label3=NewTempLabel();
                char *label4=NewTempLabel();
                sprintf(p->code[j].line,"label, %s",label1);
                for(int i=j+1;i<$6->numLines+j+1;i++){
                    sprintf(p->code[i].line,"%s",$6->code[i-j-1].line);
                }
                j=$6->numLines+j+1;
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$6->place, label2);
                sprintf(p->code[j+1].line,"goto, %s",label3);
                sprintf(p->code[j+2].line,"label, %s",label2);
                for(int i=j+3;i<$10->numLines+j+3;i++){
                    if(strcmp($10->code[i-j-3].line,"break")==0){
                        sprintf(p->code[i].line,"goto, %s",label3);
                    }
                    else if(strcmp($10->code[i-j-3].line,"continue")==0){
                        // printf("asdfsad\n");
                        sprintf(p->code[i].line,"goto, %s",label4);
                    }
                    else
                        sprintf(p->code[i].line,"%s",$10->code[i-j-3].line);
                }
                j=$10->numLines+j+3;
                sprintf(p->code[j].line,"label, %s",label4);
                j++;
                for(int i=j;i<$8->numLines+j;i++){
                    sprintf(p->code[i].line,"%s",$8->code[i-j].line);
                }
                j=$8->numLines+j;
                //printf("XX");
                sprintf(p->code[j].line,"goto, %s",label1);
                sprintf(p->code[j+1].line,"label, %s",label3);
                $$=p;

            }
            |  token_while '(' Expression ')' Block_Start Then_Stm Block_End{
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$3->numLines + $6->numLines + 6;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                // label, label1
                // Expression.code
                // ifgoto, !=, exp.place, 0, label2
                // goto, label3
                // label, label2
                // Then_Stm.code
                // goto, label1
                // label, label3


                char *label1 = NewTempLabel();
                char *label2 = NewTempLabel();
                char *label3 = NewTempLabel();
                sprintf(p->code[0].line,"label, %s",label1);
                for (int i = 1; i < 1+$3->numLines; ++i)
                {
                    sprintf(p->code[i].line,"%s",$3->code[i-1].line);
                }
                int j = 1+$3->numLines;
                sprintf(p->code[j].line,"ifgoto, !=, %s, 0, %s",$3->place,label2);
                sprintf(p->code[j+1].line,"goto, %s",label3);
                sprintf(p->code[j+2].line,"label, %s",label2);
                j=j+3;
                for (int i = j; i < j+$6->numLines; ++i)
                {
                    if(strcmp($6->code[i-j].line,"break")==0){
                        sprintf(p->code[i].line,"goto, %s",label3);
                    }
                    else if(strcmp($6->code[i-j].line,"continue")==0){
                        sprintf(p->code[i].line,"goto, %s",label1);
                    }
                    else
                        sprintf(p->code[i].line,"%s",$6->code[i-j].line);
                }
                j=j+$6->numLines;
                sprintf(p->code[j].line,"goto, %s",label1);
                sprintf(p->code[j+1].line,"label, %s",label3);
                $$=p;
            }
            |  Normal_Stm   {$$=$1;}
            ;

Normal_Stm:
            token_break ';' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"break");
                $$=p;

            }
            |  token_continue ';' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"continue");
                $$=p;
            }
            |  token_return Expression_Opt ';' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$2->numLines+1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$2->numLines;i++){

                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }

                sprintf(p->code[p->numLines-1].line,"return, %s",$2->place);
                $$=p;
            }
            |  Statement_Exp ';'        {$$=$1;}
            |  ';'  {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
                }
            |  Block_Start Block  Block_End  {$$=$2;}
            |  token_switch '(' Expression ')' '{' Switch_Sections_Opt '}' {
                //printf("XXXXX");
                node *p = (node*)malloc(sizeof(node));
                p->numLines = $3->numLines + $6->numLines+1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i].line);
                }
                int j=$3->numLines;

                char *label1=NewTempLabel();
                char *temp1=NewTempLabel();
                for(int i=j;i<$6->numLines+j;i++){
                    if(strcmp($6->code[i-j].line,"start_label")==0)
                    {
                        sprintf(p->code[i].line,"label, %s",temp1);
                    }
                    else if(strcmp($6->code[i-j].line,"end_label")==0){
                        temp1=NewTempLabel();
                        sprintf(p->code[i].line,"goto, %s",temp1);
                    }
                    else if(strstr($6->code[i-j].line,"statement_break")!=NULL)
                    {
                        char *temp=strchr($6->code[i-j].line,',');
                        char *var=strtok($6->code[i-j].line,",");
                        temp+=1;
                        char *label=strtok(temp,",");
                        sprintf(p->code[i].line,"ifgoto, ==, %s, %s, %s",$3->place,var,label);
                    }
                    else if(strcmp($6->code[i-j].line,"exit_label")==0){
                        sprintf(p->code[i].line,"goto, %s",label1);
                    }
                    else{
                    sprintf(p->code[i].line,"%s",$6->code[i-j].line);
                    }
                }
                j=$6->numLines+j;
                sprintf(p->code[j].line,"label, %s",label1);
                $$=p;
            }
            |  Print_Stm {$$=$1;}
            ;

Block:
            '{' Stm_List '}' {$$=$2;}
            |  '{' '}' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            ;

Variable_Decs_Global:
            Variable_Declarator_Global {$$=$1;}
            |  Variable_Decs_Global ',' Variable_Declarator_Global {

                node *p = (node*)malloc(sizeof(node));
                p->numLines = $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<p->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-$1->numLines].line);
                }
                $$=p;
            }
            ;

Variable_Declarator_Global:
            token_identifier {
                if(_TYPE_==TYPE_INT_ARRAY || _TYPE_==TYPE_CHAR_ARRAY || _TYPE_==TYPE_BOOL_ARRAY){
                    if(_ARRAYSIZE_==0){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Size of array '%s' is not specified",LINE_NO,$1);
                        yyerror(buf);
                    }
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                //int x=CurrentTable->offset + 4*(CurrentTable->var_count);
                //int x=100;
                char *temp = RegisterVar($1,_TYPE_,_ARRAYSIZE_,0,0);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                    yyerror(buf);
                }
                $$=p;
            }
            |  token_identifier '=' Variable_Initializer {
                if(_TYPE_==TYPE_INT || _TYPE_==TYPE_CHAR || _TYPE_==TYPE_BOOL){
                    node *p = (node*)malloc(sizeof(node));
                    p->numLines=$3->numLines+1;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$3->numLines;i++){
                        sprintf(p->code[i].line,"%s",$3->code[i].line);
                    }
                    //int x=CurrentTable->offset + 4*(CurrentTable->var_count);
                    //int x=100;
                    char *temp = RegisterVar($1,_TYPE_,0,0,0);
                    if(strcmp(temp,"error")==0){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                        yyerror(buf);
                    }
                    sprintf(p->code[p->numLines-1].line,"=, %s, %s",temp,$3->place);
                    p->type = $3->type;
                    p->place = (char *)malloc(15*sizeof(char));
                    sprintf(p->place,"%s",temp);
                    $$=p;
                }else{
                    ArrayElement *t = $3->arrayList;
                    if(t==NULL && _ARRAYSIZE_==0){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Size of array '%s' is not specified",LINE_NO,$1);
                        yyerror(buf);
                    }
                    if(t==NULL){
                        node *p = (node*)malloc(sizeof(node));
                        p->numLines=0;
                        //int x=CurrentTable->offset + 4*(CurrentTable->var_count);
                        //int x=100;
                        char *temp = RegisterVar($1,_TYPE_,_ARRAYSIZE_,0,0);
                        if(strcmp(temp,"error")==0){
                            char buf[100];
                            sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                            yyerror(buf);
                        }
                        $$=p;
                    }else{
                        // writearr, array_name, index (variable or integer), value_to_write (variable or integer)
                        int size=0;
                        while(t!=NULL){
                            t=t->next;
                            size++;
                        }
                        //int x=CurrentTable->offset + 4*(CurrentTable->var_count);
                        //int x=100;
                        char *temp = RegisterVar($1,_TYPE_,size,0,0);
                        if(strcmp(temp,"error")==0){
                            char buf[100];
                            sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                            yyerror(buf);
                        }
                        node *p = (node*)malloc(sizeof(node));
                        p->numLines=$3->numLines+size;
                        p->code = (Code*)malloc(p->numLines * sizeof(Code));
                        for(int i=0;i<$3->numLines;i++){
                            sprintf(p->code[i].line,"%s",$3->code[i].line);
                        }
                        int j=$3->numLines,i=0;
                        t = $3->arrayList;
                        // printf("%s\n",t->val);
                        // printf("here\n");
                        while(t!=NULL){
                            sprintf(p->code[j].line,"writearr, %s, %d, %s",temp,i,t->val);
                            j++;
                            i++;
                            t=t->next;
                        }
                        $$=p;
                    }
                }
            }
            ;





Variable_Decs:
            Variable_Declarator {$$=$1;}
            |  Variable_Decs ',' Variable_Declarator {

                node *p = (node*)malloc(sizeof(node));
                p->numLines = $1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<p->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-$1->numLines].line);
                }
                $$=p;
            }
            ;

Variable_Declarator:
            token_identifier {
                if(_TYPE_==TYPE_INT_ARRAY || _TYPE_==TYPE_CHAR_ARRAY || _TYPE_==TYPE_BOOL_ARRAY){
                    if(_ARRAYSIZE_==0){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Size of array '%s' is not specified",LINE_NO,$1);
                        yyerror(buf);
                    }
                }
                node *p = (node*)malloc(sizeof(node));
                //#*#*
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"moveSP, 4");    
                int x=CurrentTable->offset + (CurrentTable->curr_offset);
                char *temp = RegisterVar($1,_TYPE_,_ARRAYSIZE_,1,x);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                    yyerror(buf);
                }
                $$=p;

            }
            |  token_identifier '=' Variable_Initializer {

                if(_TYPE_==TYPE_INT || _TYPE_==TYPE_CHAR || _TYPE_==TYPE_BOOL){
                    node *p = (node*)malloc(sizeof(node));
                    p->numLines=$3->numLines+1+1;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"moveSP, 4");
                    for(int i=1;i<$3->numLines+1;i++){
                        sprintf(p->code[i].line,"%s",$3->code[i-1].line);
                    }
                    int x=CurrentTable->offset + (CurrentTable->curr_offset);
                    char *temp = RegisterVar($1,_TYPE_,0,1,x);
                    if(strcmp(temp,"error")==0){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                        yyerror(buf);
                    }

                    ArrayElement *t = $3->arrayList;
                    if(t!=NULL){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' is not array type",LINE_NO,$1);
                        yyerror(buf);
                    }
                    sprintf(p->code[p->numLines-1].line,"=, %s, %s",temp,$3->place);
                    p->type = $3->type;
                    p->place = (char *)malloc(15*sizeof(char));
                    sprintf(p->place,"%s",temp);
                    $$=p;
                }else{

                    ArrayElement *t = $3->arrayList;
                    if(t==NULL && _ARRAYSIZE_==0){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Size of array '%s' is not specified",LINE_NO,$1);
                        yyerror(buf);
                    }
                    if(t==NULL){

                        node *p = (node*)malloc(sizeof(node));
                        p->numLines=1;
                        p->code = (Code*)malloc(p->numLines * sizeof(Code));
                        sprintf(p->code[0].line,"moveSP, %d",_ARRAYSIZE_*4);    
                        int x=CurrentTable->offset + (CurrentTable->curr_offset);
                        char *temp = RegisterVar($1,_TYPE_,_ARRAYSIZE_,1,x);
                        if(strcmp(temp,"error")==0){
                            char buf[100];
                            sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                            yyerror(buf);
                        }
                        $$=p;
                    }else{
                        // writearr, array_name, index (variable or integer), value_to_write (variable or integer)
                        int size=0;
                        while(t!=NULL){
                            t=t->next;
                            size++;
                        }
                        int x=CurrentTable->offset + (CurrentTable->curr_offset);
                        char *temp = RegisterVar($1,_TYPE_,size,1,x);
                        if(strcmp(temp,"error")==0){
                            char buf[100];
                            sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,$1);
                            yyerror(buf);
                        }
                        node *p = (node*)malloc(sizeof(node));
                        p->numLines=$3->numLines+size+1;
                        p->code = (Code*)malloc(p->numLines * sizeof(Code));
                        sprintf(p->code[0].line,"moveSP, %d",size*4);    
                        for(int i=1;i<$3->numLines+1;i++){
                            sprintf(p->code[i].line,"%s",$3->code[i-1].line);
                        }
                        int j=$3->numLines+1,i=0;
                        t = $3->arrayList;
                        // printf("%s\n",t->val);
                        // printf("here\n");

                        while(t!=NULL){
                            sprintf(p->code[j].line,"writearr, %s, %d, %s",temp,i,t->val);
                            j++;
                            i++;
                            t=t->next;
                        }
                        $$=p;
                    }
                }
            }
            ;

Variable_Initializer:
            Expression {$$=$1;$$->isArray=0;}
            |  Array_Initializer {$$=$1;$$->isArray=1;}
            ;

For_Init_Opt:
            Local_Var_Decl {$$=$1;}
            |  Statement_Exp_List {$$=$1;}
            |  {node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
                }
            ;

For_Iterator_Opt:
            Statement_Exp_List {$$=$1;}
            |   {node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            ;

For_Condition_Opt:
            Expression {$$=$1;}
            |   {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%d",1);
                $$=p;
            }
            ;

Statement_Exp_List:
            Statement_Exp_List ',' Statement_Exp {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines + $3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j = $1->numLines;
                for(int i=j;i<j+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j].line);
                }
                $$=p;
            }
            |  Statement_Exp {$$=$1;}
            ;

Local_Var_Decl:
            Type Variable_Decs {
                $$=$2;
                _ARRAYSIZE_ = 0;
            }
            | token_struct token_identifier token_identifier {
                int foundFlag=0,structIndex=0;
                for (int i = 0; i < structDefArrayIndex; ++i)
                {
                    if(strcmp(structDefArray[i].struct_name,$2)==0){
                        foundFlag=1;
                        structIndex=i;
                        break;
                    }
                }
                if(foundFlag==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET "Struct '%s' not defined",LINE_NO,$2);
                    yyerror(buf);
                }
                int spSize=0;
                isStruct=1;
                _Struct_Index_=structIndex;
                for (int j = 0; j < structDefArray[structIndex].memberCount; ++j)
                {
                    // RegisterVar(char * iden_name, int var_type,int arr_size,int loc,int offset)
                    char name[40];
                    sprintf(name,"struct_%s_%s",$3,structDefArray[structIndex].memberArray[j].member_name);
                    // printf("registering struct_%s_%s\n",$3,structDefArray[structIndex].memberArray[j].member_name);
                    int var_type = structDefArray[structIndex].memberArray[j].type;
                    int arr_size = structDefArray[structIndex].memberArray[j].arr_size;
                    int x=CurrentTable->offset + (CurrentTable->curr_offset);
                    // char *temp = RegisterVar($2,$1->type,_ARRAYSIZE_,1,x);
                    RegisterVar(name, var_type, arr_size, 1, x);
                    if(arr_size==0)spSize+=4;
                    else spSize+=arr_size*4;
                    // printf("membername: %s arrSize: %d\n",structDefArray[i].memberArray[j].member_name,structDefArray[i].memberArray[j].arr_size);
                }
                isStruct=0;
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"moveSP, %d",spSize);
                $$=p;
            }
            ;

Local_Var_Decl_Global:
            Type Variable_Decs_Global {
                $$=$2;
                _ARRAYSIZE_ = 0;
            }
            | token_struct token_identifier token_identifier {
                int foundFlag=0,structIndex=0;
                for (int i = 0; i < structDefArrayIndex; ++i)
                {
                    if(strcmp(structDefArray[i].struct_name,$2)==0){
                        foundFlag=1;
                        structIndex=i;
                        break;
                    }
                }
                if(foundFlag==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET "Struct '%s' not defined",LINE_NO,$2);
                    yyerror(buf);
                }
                isStruct=1;
                _Struct_Index_=structIndex;
                for (int j = 0; j < structDefArray[structIndex].memberCount; ++j)
                {
                    // RegisterVar(char * iden_name, int var_type,int arr_size,int loc,int offset)
                    char name[40];
                    sprintf(name,"struct_%s_%s",$3,structDefArray[structIndex].memberArray[j].member_name);
                    // printf("registering struct_%s_%s\n",$3,structDefArray[structIndex].memberArray[j].member_name);
                    int var_type = structDefArray[structIndex].memberArray[j].type;
                    int arr_size = structDefArray[structIndex].memberArray[j].arr_size;
                    RegisterVar(name, var_type, arr_size, 0, 0);

                    // printf("membername: %s arrSize: %d\n",structDefArray[i].memberArray[j].member_name,structDefArray[i].memberArray[j].arr_size);
                }
                isStruct=0;
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            | token_identifier '.' token_identifier '=' Variable_Initializer {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                int _TYPE_ =  VarType(name),_ARRAYSIZE_=ArrSize(name);
                // printf("here----------------\n");
                if(_TYPE_==-1){
                    // printf("not defined-----------\n");
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET " Variable '%s' not defined",LINE_NO,$1);
                    yyerror(buf);
                }
                if(_TYPE_==TYPE_INT || _TYPE_==TYPE_CHAR || _TYPE_==TYPE_BOOL){
                    // printf("base type------\n");
                    node *p = (node*)malloc(sizeof(node));
                    p->numLines=$5->numLines+1;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$5->numLines;i++){
                        sprintf(p->code[i].line,"%s",$5->code[i].line);
                    }
                    char *temp = ReqRefName(name);
                    sprintf(p->code[p->numLines-1].line,"=, %s, %s",temp,$5->place);
                    p->type = $5->type;
                    p->place = (char *)malloc(15*sizeof(char));
                    sprintf(p->place,"%s",temp);
                    $$=p;
                }else{
                    ArrayElement *t = $5->arrayList;
                    int size=0;
                    while(t!=NULL){
                        t=t->next;
                        size++;
                    }
                    t = $5->arrayList;
                    if(t==NULL){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "You need to give initialising variables/constants",LINE_NO);
                        yyerror(buf);
                    }else if(size!=_ARRAYSIZE_){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Array size is %d but %d variables/constants are provided",LINE_NO,_ARRAYSIZE_,size);
                        yyerror(buf);
                    // printf("is arrayasfdasdf--------\n");
                    }
                    else{
                        char *temp = ReqRefName(name);
                        node *p = (node*)malloc(sizeof(node));
                        p->numLines=$5->numLines+size;
                        p->code = (Code*)malloc(p->numLines * sizeof(Code));
                        for(int i=0;i<$5->numLines;i++){
                            sprintf(p->code[i].line,"%s",$5->code[i].line);
                        }
                        int j=$5->numLines,i=0;
                        t = $5->arrayList;
                        // printf("%s\n",t->val);
                        // printf("here\n");
                        while(t!=NULL){
                            sprintf(p->code[j].line,"writearr, %s, %d, %s",temp,i,t->val);
                            j++;
                            i++;
                            t=t->next;
                        }
                        $$=p;
                    }
                }
                // printf("over------------------\n");
            }
            | token_identifier '.' token_identifier '[' token_dec_literal ']' '=' Variable_Initializer {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                int _TYPE_ =  VarType(name),_ARRAYSIZE_=ArrSize(name);
                // printf("here----------------\n");
                if(_TYPE_==-1){
                    // printf("not defined-----------\n");
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET " Variable '%s' not defined",LINE_NO,$1);
                    yyerror(buf);
                }
                if(_ARRAYSIZE_==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET " Member '%s' of '%s' is not array type",LINE_NO,$3,$1);
                    yyerror(buf);

                }
                if(1){
                    // printf("base type------\n");
                    node *p = (node*)malloc(sizeof(node));
                    p->numLines=$8->numLines+1;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$8->numLines;i++){
                        sprintf(p->code[i].line,"%s",$8->code[i].line);
                    }
                    //int x=CurrentTable->offset + 4*(CurrentTable->var_count);
                    //int x=100;
                    // char *temp = RegisterVar(name,_TYPE_,0,0,0);
                    char *temp = ReqRefName(name);
                    // if(strcmp(temp,"error")==0){
                    //     char buf[100];
                    //     sprintf(buf,ANSI_COLOR_RED "Line %d: "ANSI_COLOR_RESET "Variable '%s' already declared in this block",LINE_NO,name);
                    //     yyerror(buf);
                    // }
                    // sprintf(p->code[p->numLines-1].line,"=, %s, %s",temp,$8->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",temp,$5,$8->place);
                    p->type = $8->type;
                    p->place = (char *)malloc(15*sizeof(char));
                    sprintf(p->place,"%s",temp);
                    $$=p;

                }
                
                // printf("over------------------\n");
            }
            ;

Statement_Exp:
             Method {$$=$1;}
            |  token_plus_plus token_identifier {
                char *temp = ReqRefName($2);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$2);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"+, %s, %s, 1",temp,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            | token_plus_plus token_identifier '.' token_identifier {
                char name[40];
                sprintf(name,"struct_%s_%s",$2,$4);
                char *temp = ReqRefName(name);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$2);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"+, %s, %s, 1",temp,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  token_minus_minus token_identifier {
                char *temp = ReqRefName($2);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$2);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"-, %s, %s, 1",temp,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  token_minus_minus token_identifier '.' token_identifier {
                char name[40];
                sprintf(name,"struct_%s_%s",$2,$4);
                char *temp = ReqRefName(name);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$2);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"-, %s, %s, 1",temp,temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            |  token_identifier Assign_Tail {
                char *temp = ReqRefName($1);
                char *temp2 = NewTempVar();
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                //call temp_var from symbol table here------------------------------------------------
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$2->numLines + 1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$2->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i].line);
                }
                if(strcmp($2->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"=, %s, %s",temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_plus_plus")==0){
                    p->numLines=2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"=, %s, %s",temp2,temp);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp);
                }
                else if(strcmp($2->extra_info,"token_minus_minus")==0){
                    p->numLines=2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"=, %s, %s",temp2,temp);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp);
                }
                if(strcmp($2->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"+, %s, %s, %s",temp,temp,$2->place);
                }
                if(strcmp($2->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"-, %s, %s, %s",temp,temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"*, %s, %s, %s",temp,temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"/, %s, %s, %s",temp,temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$2->numLines + 5;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$2->numLines;i++){
                        sprintf(p->code[i].line,"%s",$2->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-5].line,"~, %s, %s",t1,$2->place);
                    sprintf(p->code[p->numLines-4].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-3].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s, %s",t2,t2,$2->place);
                    sprintf(p->code[p->numLines-1].line,"|, %s, %s, %s",temp,t1,t2);
                }
                else if(strcmp($2->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"&, %s, %s",temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"|, %s, %s",temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"rem, %s, %s",temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"<<, %s, %s",temp,$2->place);
                }
                else if(strcmp($2->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,">>, %s, %s",temp,$2->place);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($2->extra_info,"token_plus_plus")==0 || strcmp($2->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;


            }
            |   token_identifier '.' token_identifier Assign_Tail {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *temp = ReqRefName(name);
                // char *temp = ReqRefName($1);
                char *temp2 = NewTempVar();
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                //call temp_var from symbol table here------------------------------------------------
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$4->numLines + 1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$4->numLines;i++){
                    sprintf(p->code[i].line,"%s",$4->code[i].line);
                }
                if(strcmp($4->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"=, %s, %s",temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_plus_plus")==0){
                    p->numLines=2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"=, %s, %s",temp2,temp);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp);
                }
                else if(strcmp($4->extra_info,"token_minus_minus")==0){
                    p->numLines=2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"=, %s, %s",temp2,temp);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp);
                }
                if(strcmp($4->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"+, %s, %s, %s",temp,temp,$4->place);
                }
                if(strcmp($4->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"-, %s, %s, %s",temp,temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"*, %s, %s, %s",temp,temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"/, %s, %s, %s",temp,temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$4->numLines + 5;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$4->numLines;i++){
                        sprintf(p->code[i].line,"%s",$4->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-5].line,"~, %s, %s",t1,$4->place);
                    sprintf(p->code[p->numLines-4].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-3].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s, %s",t2,t2,$4->place);
                    sprintf(p->code[p->numLines-1].line,"|, %s, %s, %s",temp,t1,t2);
                }
                else if(strcmp($4->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"&, %s, %s",temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"|, %s, %s",temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"rem, %s, %s",temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,"<<, %s, %s",temp,$4->place);
                }
                else if(strcmp($4->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-1].line,">>, %s, %s",temp,$4->place);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($4->extra_info,"token_plus_plus")==0 || strcmp($4->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;


            }
            |  token_identifier '[' token_dec_literal ']' Assign_Tail {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                int myType = VarType($1);
                // printf("%d %d\n",myType,TYPE_INT_ARRAY);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                char *temp = NewTempVar();
                char *temp2 = NewTempVar();

                node *p = (node*)malloc(sizeof(node));

                p->numLines=$5->numLines + 1 +2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$5->numLines;i++){
                    sprintf(p->code[i].line,"%s",$5->code[i].line);
                }
                sprintf(p->code[p->numLines-3].line,"readarr, %s, %d, %s",arrayRef,$3,temp);

                if(strcmp($5->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"=, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_plus_plus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$3,temp2);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_minus_minus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$3,temp2);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                if(strcmp($5->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"+, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                if(strcmp($5->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"-, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"*, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"/, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$5->numLines + 5 + 2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$5->numLines;i++){
                        sprintf(p->code[i].line,"%s",$5->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-7].line,"readarr, %s, %d, %s",arrayRef,$3,temp);
                    sprintf(p->code[p->numLines-6].line,"~, %s, %s",t1,$5->place);
                    sprintf(p->code[p->numLines-5].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-4].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-3].line,"&, %s, %s, %s",t2,t2,$5->place);
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s, %s",temp,t1,t2);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"rem, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"<<, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                else if(strcmp($5->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,">>, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$3,temp);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($5->extra_info,"token_plus_plus")==0 || strcmp($5->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  token_identifier '.' token_identifier '[' token_dec_literal ']' Assign_Tail {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                // char *temp = ReqRefName(name);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                int myType = VarType(name);
                // printf("%d %d\n",myType,TYPE_INT_ARRAY);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();
                char *temp2 = NewTempVar();

                node *p = (node*)malloc(sizeof(node));

                p->numLines=$7->numLines + 1 +2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$7->numLines;i++){
                    sprintf(p->code[i].line,"%s",$7->code[i].line);
                }
                sprintf(p->code[p->numLines-3].line,"readarr, %s, %d, %s",arrayRef,$5,temp);

                if(strcmp($7->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"=, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_plus_plus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$5,temp2);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_minus_minus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %d, %s",arrayRef,$5,temp2);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                if(strcmp($7->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"+, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                if(strcmp($7->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"-, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"*, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"/, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$7->numLines + 5 + 2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$7->numLines;i++){
                        sprintf(p->code[i].line,"%s",$7->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-7].line,"readarr, %s, %d, %s",arrayRef,$5,temp);
                    sprintf(p->code[p->numLines-6].line,"~, %s, %s",t1,$7->place);
                    sprintf(p->code[p->numLines-5].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-4].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-3].line,"&, %s, %s, %s",t2,t2,$7->place);
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s, %s",temp,t1,t2);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"rem, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"<<, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                else if(strcmp($7->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,">>, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %d, %s",arrayRef,$5,temp);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($7->extra_info,"token_plus_plus")==0 || strcmp($7->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  token_identifier '[' token_identifier ']' Assign_Tail {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                char *index = ReqRefName($3);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$3);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                myType = VarType($3);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();
                char *temp2 = NewTempVar();

                node *p = (node*)malloc(sizeof(node));

                p->numLines=$5->numLines + 1 +2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$5->numLines;i++){
                    sprintf(p->code[i].line,"%s",$5->code[i].line);
                }
                sprintf(p->code[p->numLines-3].line,"readarr, %s, %s, %s",arrayRef,index,temp);

                if(strcmp($5->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"=, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_plus_plus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_minus_minus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($5->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"+, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($5->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"-, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"*, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"/, %s, %s, %s",temp,temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$5->numLines + 5 + 2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$5->numLines;i++){
                        sprintf(p->code[i].line,"%s",$5->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-7].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                    sprintf(p->code[p->numLines-6].line,"~, %s, %s",t1,$5->place);
                    sprintf(p->code[p->numLines-5].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-4].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-3].line,"&, %s, %s, %s",t2,t2,$5->place);
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s, %s",temp,t1,t2);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"rem, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"<<, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($5->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,">>, %s, %s",temp,$5->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($5->extra_info,"token_plus_plus")==0 || strcmp($5->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  token_identifier '.' token_identifier '[' token_identifier ']' Assign_Tail {
                // char *arrayRef = ReqRefName($1);
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                // char *temp = ReqRefName(name);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }

                char *index = ReqRefName($5);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$5);
                    yyerror(buf);
                }

                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }

                myType = VarType($5);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$5);
                    yyerror(buf);
                }

                char *temp = NewTempVar();
                char *temp2 = NewTempVar();

                node *p = (node*)malloc(sizeof(node));

                p->numLines=$7->numLines + 1 +2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$7->numLines;i++){
                    sprintf(p->code[i].line,"%s",$7->code[i].line);
                }
                sprintf(p->code[p->numLines-3].line,"readarr, %s, %s, %s",arrayRef,index,temp);

                if(strcmp($7->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"=, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_plus_plus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_minus_minus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($7->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"+, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($7->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"-, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"*, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"/, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$7->numLines + 5 + 2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$7->numLines;i++){
                        sprintf(p->code[i].line,"%s",$7->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-7].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                    sprintf(p->code[p->numLines-6].line,"~, %s, %s",t1,$7->place);
                    sprintf(p->code[p->numLines-5].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-4].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-3].line,"&, %s, %s, %s",t2,t2,$7->place);
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s, %s",temp,t1,t2);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"rem, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"<<, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,">>, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($7->extra_info,"token_plus_plus")==0 || strcmp($7->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  token_identifier '[' token_identifier '.' token_identifier ']' Assign_Tail {
                char *arrayRef = ReqRefName($1);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                char name[40];
                sprintf(name,"struct_%s_%s",$3,$5);
                char *index = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$3);
                    yyerror(buf);
                }

                int myType = VarType($1);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' is not Array type",LINE_NO,$1);
                    yyerror(buf);
                }

                myType = VarType(name);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();
                char *temp2 = NewTempVar();

                node *p = (node*)malloc(sizeof(node));

                p->numLines=$7->numLines + 1 +2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$7->numLines;i++){
                    sprintf(p->code[i].line,"%s",$7->code[i].line);
                }
                sprintf(p->code[p->numLines-3].line,"readarr, %s, %s, %s",arrayRef,index,temp);

                if(strcmp($7->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"=, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_plus_plus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_minus_minus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($7->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"+, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($7->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"-, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"*, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"/, %s, %s, %s",temp,temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$7->numLines + 5 + 2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$7->numLines;i++){
                        sprintf(p->code[i].line,"%s",$7->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-7].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                    sprintf(p->code[p->numLines-6].line,"~, %s, %s",t1,$7->place);
                    sprintf(p->code[p->numLines-5].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-4].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-3].line,"&, %s, %s, %s",t2,t2,$7->place);
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s, %s",temp,t1,t2);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"rem, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"<<, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($7->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,">>, %s, %s",temp,$7->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($7->extra_info,"token_plus_plus")==0 || strcmp($7->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;

            }
            |  token_identifier '.' token_identifier '[' token_identifier '.' token_identifier ']' Assign_Tail {
                char name[40];
                sprintf(name,"struct_%s_%s",$1,$3);
                char *arrayRef = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$1);
                    yyerror(buf);
                }
                int myType = VarType(name);
                if(myType != TYPE_INT_ARRAY && myType != TYPE_BOOL_ARRAY && myType != TYPE_CHAR_ARRAY){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s.%s' is not Array type",LINE_NO,$1,$3);
                    yyerror(buf);
                }
                sprintf(name,"struct_%s_%s",$5,$7);
                char *index = ReqRefName(name);
                if(strcmp(arrayRef,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Variable '%s' used but not declared",LINE_NO,$3);
                    yyerror(buf);
                }

                

                myType = VarType(name);
                if(myType != TYPE_INT){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Index Variable '%s' is not Int type",LINE_NO,$3);
                    yyerror(buf);
                }

                char *temp = NewTempVar();
                char *temp2 = NewTempVar();

                node *p = (node*)malloc(sizeof(node));

                p->numLines=$9->numLines + 1 +2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$9->numLines;i++){
                    sprintf(p->code[i].line,"%s",$9->code[i].line);
                }
                sprintf(p->code[p->numLines-3].line,"readarr, %s, %s, %s",arrayRef,index,temp);

                if(strcmp($9->extra_info,"= Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"=, %s, %s",temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_plus_plus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"+, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_minus_minus")==0){
                    p->numLines=3;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    sprintf(p->code[0].line,"readarr, %s, %s, %s",arrayRef,index,temp2);
                    sprintf(p->code[1].line,"-, %s, %s, 1",temp,temp2);
                    sprintf(p->code[2].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($9->extra_info,"token_plus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"+, %s, %s, %s",temp,temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                if(strcmp($9->extra_info,"token_minus_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"-, %s, %s, %s",temp,temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_mul_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"*, %s, %s, %s",temp,temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_quotient_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"/, %s, %s, %s",temp,temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_bit_xor_assign Expression")==0){
                    p->numLines=$9->numLines + 5 + 2;
                    p->code = (Code*)malloc(p->numLines * sizeof(Code));
                    for(int i=0;i<$9->numLines;i++){
                        sprintf(p->code[i].line,"%s",$9->code[i].line);
                    }
                    //A.~B + ~A.B
                    char *t1=NewTempVar();
                    char *t2=NewTempVar();
                    //~, t1, 2.place
                    //&, t1, temp, t1
                    //~, t2, temp
                    //&, t2, t2, 2.place
                    //|, temp, t1 ,t2
                    sprintf(p->code[p->numLines-7].line,"readarr, %s, %s, %s",arrayRef,index,temp);
                    sprintf(p->code[p->numLines-6].line,"~, %s, %s",t1,$9->place);
                    sprintf(p->code[p->numLines-5].line,"&, %s, %s, %s",t1,temp,t1);
                    sprintf(p->code[p->numLines-4].line,"~, %s, %s",t2,temp);
                    sprintf(p->code[p->numLines-3].line,"&, %s, %s, %s",t2,t2,$9->place);
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s, %s",temp,t1,t2);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_bit_and_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"&, %s, %s",temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_bit_or_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"|, %s, %s",temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_remainder_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"rem, %s, %s",temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_shift_left_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,"<<, %s, %s",temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                else if(strcmp($9->extra_info,"token_shift_right_assign Expression")==0){
                    sprintf(p->code[p->numLines-2].line,">>, %s, %s",temp,$9->place);
                    sprintf(p->code[p->numLines-1].line,"writearr, %s, %s, %s",arrayRef,index,temp);
                }
                p->place = (char *)malloc(15*sizeof(char));
                if(strcmp($9->extra_info,"token_plus_plus")==0 || strcmp($9->extra_info,"token_minus_minus")==0)
                    sprintf(p->place,"%s",temp2);
                else
                    sprintf(p->place,"%s",temp);
                $$=p;

            }

            ;

Assign_Tail:
             token_plus_plus {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_plus_plus");
             }
            |  token_minus_minus {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_minus_minus");
            }
            |  '=' Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"= Expression");
            }
            |  token_plus_assign Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_plus_assign Expression");
            }
            |  token_minus_assign  Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_minus_assign Expression");
            }
            |  token_mul_assign  Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_mul_assign Expression");
            }
            |  token_quotient_assign  Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_quotient_assign Expression");
            }
            |  token_bit_xor_assign Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_bit_xor_assign Expression");
            }
            |  token_bit_and_assign Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_bit_and_assign Expression");
            }
            |  token_bit_or_assign  Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_bit_or_assign Expression");
            }
            |  token_remainder_assign  Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_remainder_assign Expression");
            }
            |  token_shift_left_assign Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_shift_left_assign Expression");
            }
            |  token_shift_right_assign Expression {
                $$=$2;
                $$->extra_info = (char *)malloc(40*sizeof(char));
                sprintf($$->extra_info,"token_shift_right_assign Expression");
            }
            ;

Method:
            token_identifier '(' Arg_List_Opt ')' {
                CalledFunc($1,$3->numArgs,LINE_NO);
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1+$3->numLines+1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i].line);
                }
                sprintf(p->code[$3->numLines].line,"call, %s",$1);
                char *temp = NewTempVar();
                sprintf(p->code[p->numLines-1].line,"getreturnval, %s",temp);
                p->place = (char *)malloc(15*sizeof(char));
                sprintf(p->place,"%s",temp);
                $$=p;
            }
            ;

Compilation_Unit:
             Class_Decl {
                // for (int i = 0; i < structDefArrayIndex; ++i)
                // {
                //     printf("Struct name: %s %d\n",structDefArray[i].struct_name,structDefArray[i].memberCount);
                //     for (int j = 0; j < structDefArray[i].memberCount; ++j)
                //     {
                //         printf("membername: %s arrSize: %d\n",structDefArray[i].memberArray[j].member_name,structDefArray[i].memberArray[j].arr_size);
                //     }
                
                // }
                if(DefinedFunc("scan",0)==0){
                    char buf[100];
                    sprintf(buf,"Library Function 'scan' has multiple definition");
                    yyerror(buf);
                }
                if(DefinedFunc("main",0)==1){
                    char buf[100];
                    sprintf(buf,"Function 'main' not defined");
                    yyerror(buf);
                }
                for (int i = 0; i < CalledFuncTableCounter; ++i)
                {
                    int flag=0;
                    for (int j=0; j < DefinedFuncTableCounter; ++j){
                        if(strcmp(CalledFuncTable[i].name,DefinedFuncTable[j].name)==0){
                            if(CalledFuncTable[i].numArgs!=DefinedFuncTable[j].numArgs){
                                char buf[100];
                                sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET "Function '%s' expects %d arguments but %d are passed",CalledFuncTable[i].lineNum,CalledFuncTable[i].name,DefinedFuncTable[j].numArgs,CalledFuncTable[i].numArgs);
                                yyerror(buf);
                            }else
                                flag=1;
                        }
                    }
                    if(flag!=1){
                        char buf[100];
                        sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET " Function '%s' not defined",CalledFuncTable[i].lineNum,CalledFuncTable[i].name);
                        yyerror(buf);
                    }
                }
                FILE * f = fopen("ir_code.txt","w");
                for(int i=0;i<$1->numLines;i++){
                    // printf("%d, %s\n",i+1, $1->code[i].line);
                    fprintf(f,"%d, %s\n",i+1, $1->code[i].line);
                }
                fclose(f);
                return 0;
             }
             ;
Class_Decl:
            token_class token_identifier '{' Class_Item_Decs_Opt '}' {$$=$4;}
            ;



Class_Item_Decs_Opt:
            Class_Item_Decs_Opt Class_Item {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<p->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i-$1->numLines].line);
                }
                $$=p;

            }
            |  {node *p = (node*)malloc(sizeof(node));
                // printf("hereok");
                p->numLines=0;
                $$=p;
                }
            ;

Class_Item:
            Struct_Dec {node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;}
            |  Field_Dec {$$=$1;}
            |  Method_Dec {$$=$1;}
            ;

// struct StructMember{
//     int type;
//     char member_name[30];
//     int arr_size;
// };

// struct StructMemberList{
//     struct StructMember memberArray[20];
//     int memberCount;
// }

// struct StructDef{
//     char struct_name[30];
//     struct StructMember memberArray[20];
//     int memberCount;
// };

// struct StructDef structDefArray[20];
// int structDefArrayIndex=0;

// %token <ptr> Struct_Dec Type_Struct Base_Type_Struct token_struct
// %token <memberList> Member_Decl
// %token <memberList> Variable_Decs_Struct

// %union{
//     struct StructMemberList memberList;
// }

Struct_Dec: token_struct token_identifier '{' Member_Decl '}' ';' {
                // printf("here------------- %d\n",$4->memberCount);
                for (int i = 0; i < structDefArrayIndex; ++i)
                {
                    if(strcmp(structDefArray[i].struct_name,$2) == 0){
                        char buf[100];
                        sprintf(buf,"Line %d: Struct '%s' already defined",LINE_NO,$2);
                        yyerror(buf);
                    }
                }
                sprintf(structDefArray[structDefArrayIndex].struct_name,"%s",$2);

                for (int i = 0; i < $4->memberCount; ++i)
                {
                    sprintf(structDefArray[structDefArrayIndex].memberArray[i].member_name,"%s",$4->memberArray[i].member_name);
                    structDefArray[structDefArrayIndex].memberArray[i].type = $4->memberArray[i].type;
                    structDefArray[structDefArrayIndex].memberArray[i].arr_size = $4->memberArray[i].arr_size;
                    // printf("asdfddsf %d\n",structDefArray[structDefArrayIndex].memberCount);
                    structDefArray[structDefArrayIndex].memberCount++;
                }

                structDefArrayIndex++;
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }



Member_Decl: Type_Struct Variable_Decs_Struct ';'{
                for (int i = 0; i < $2->memberCount; ++i)
                {
                    $2->memberArray[i].type = _TYPE_;
                    $2->memberArray[i].arr_size = _ARRAYSIZE_;
                }
                $$=$2;
             }
             | Member_Decl Type_Struct Variable_Decs_Struct ';'{
                for (int i = 0; i < $3->memberCount; ++i)
                {
                    $3->memberArray[i].type = _TYPE_;
                    $3->memberArray[i].arr_size = _ARRAYSIZE_;
                }
                for (int i = $3->memberCount; i < $1->memberCount+$3->memberCount; ++i)
                {
                    sprintf($3->memberArray[i].member_name,"%s",$1->memberArray[i-$3->memberCount].member_name);
                    $3->memberArray[i].type = $1->memberArray[i-$3->memberCount].type;
                    $3->memberArray[i].arr_size = $1->memberArray[i-$3->memberCount].arr_size;
                }
                $3->memberCount += $1->memberCount;
                $$=$3;
             }

Type_Struct:
             Base_Type_Struct {_TYPE_=$1->type;_ARRAYSIZE_=0;$$=$1;}
            | Base_Type_Struct '[' token_dec_literal ']' {
                if($1->type==TYPE_INT)
                    _TYPE_=TYPE_INT_ARRAY;
                else if($1->type==TYPE_CHAR)
                    _TYPE_=TYPE_CHAR_ARRAY;
                else
                    _TYPE_=TYPE_BOOL_ARRAY;
                _ARRAYSIZE_=$3;
            }
            ;

Base_Type_Struct:
            token_int {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_INT;
                $$=p;
            }
            | token_char {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_CHAR;
                $$=p;
            }
            | token_bool {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->type = TYPE_BOOL;
                $$=p;
            }
            ;

Variable_Decs_Struct:
            token_identifier {
                struct StructMemberList * memberList = (struct StructMemberList *)malloc(sizeof(struct StructMemberList));
                memberList->memberCount=1;
                sprintf(memberList->memberArray[0].member_name,"%s",$1);
                $$=memberList;
            }
            |  Variable_Decs_Struct ',' token_identifier {
                sprintf($1->memberArray[$1->memberCount].member_name,"%s",$3);
                $1->memberCount+=1;
                $$=$1;
            }
            ;


Field_Dec:
            Local_Var_Decl_Global ';' {$$=$1;}
            ;

Method_Dec:
             Type token_identifier Block_Start_M '(' Formal_Param_List_Opt ')' Block_or_Semi Block_End {
                if(DefinedFunc($2,$5->numArgs)==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED"Line %d: " ANSI_COLOR_RESET "Function '%s' already defined",LINE_NO,$2);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                // printf("%d\n",$6->numLines);
                p->numLines=$5->numLines + $7->numLines + 1;
                if($7->numLines==0 || strstr($7->code[$7->numLines-1].line,"return,")==NULL)
                    p->numLines++;
                if(method_call_counter==0){
                    p->numLines+=2;
                }
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                int j=0;
                if(method_call_counter==0){
                    j=2;
                    sprintf(p->code[0].line,"call, main");
                    sprintf(p->code[1].line,"exit");
                }
                method_call_counter++;
                sprintf(p->code[j].line,"function, %s",$2);

                for(int i=j+1;i<$5->numLines+j+1;i++){
                    sprintf(p->code[i].line,"%s",$5->code[i-j-1].line);
                }

                for(int i=$5->numLines+j+1;i<$5->numLines+j+1+$7->numLines;i++){
                    sprintf(p->code[i].line,"%s",$7->code[i-$5->numLines-j-1].line);
                }
                if($7->numLines==0 || strstr($7->code[$7->numLines-1].line,"return,")==NULL)
                    sprintf(p->code[p->numLines-1].line,"return, 0");
                $$=p;
            }

            ;
Formal_Param_List_Opt:
            Formal_Param_List {$$=$1;}
            |   {node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                p->numArgs=0;
                $$=p;}
            ;

Formal_Param_List:
            Formal_Param {$$=$1;}
            | Formal_Param_List ',' Formal_Param {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines+$3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<$1->numLines+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-$1->numLines].line);
                }
                p->numArgs=$1->numArgs+$3->numArgs;
                $$=p;
            }
            ;

Formal_Param:
            Type token_identifier  {
                int x=CurrentTable->offset + (CurrentTable->curr_offset);
                char *temp = RegisterVar($2,$1->type,_ARRAYSIZE_,1,x);
                if(strcmp(temp,"error")==0){
                    char buf[100];
                    sprintf(buf,ANSI_COLOR_RED "Line %d: " ANSI_COLOR_RESET"Variable '%s' already declared in this block",LINE_NO,$2);
                    yyerror(buf);
                }
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"pull, %s",temp);
                p->numArgs=1;
                $$=p;
            }
            ;

Array_Initializer:
            '{'  '}' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            |  '{' Variable_Initializer_List '}' {
                $$=$2;
            }
            ;

Variable_Initializer_List:
            Variable_Initializer {
                $$=$1;
                pushArrayElement(&($$->arrayList),$1->place);
            }
            | Variable_Initializer_List ',' Variable_Initializer {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines+$3->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                for(int i=0;i<$1->numLines;i++){
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                for(int i=$1->numLines;i<$1->numLines+$3->numLines;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-$1->numLines].line);
                }
                p->arrayList = $1->arrayList;
                pushArrayElement(&(p->arrayList),$3->place);
                $$=p;
            }
            ;

Switch_Sections_Opt:
             Switch_Sections_Opt Switch_Section {
                 node *p = (node*)malloc(sizeof(node));
                 p->numLines=$1->numLines + $2->numLines;
                 p->code = (Code*)malloc(p->numLines * sizeof(Code));
                 for(int i=0;i<$1->numLines;i++){
                     sprintf(p->code[i].line,"%s",$1->code[i].line);
                 }
                 int j=$1->numLines;

                 for(int i=j;i<$2->numLines+j;i++){
                     sprintf(p->code[i].line,"%s",$2->code[i-j].line);
                 }

                 $$=p;
             }
            |   {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=0;
                $$=p;
            }
            ;

Switch_Section:
            Switch_Labels Block_Start Stm_List Block_End {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines + $3->numLines+2;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                char *label1=NewTempLabel();
                char *label2=NewTempLabel();
                for(int i=0;i<$1->numLines;i++){
                    if(strstr($1->code[i].line,"statement_break")!=NULL)
                    {
                        char *var=strtok($1->code[i].line,",");
                        sprintf(p->code[i].line,"%s,%s,statement_break",var,label1);
                    }
                    else{
                    sprintf(p->code[i].line,"%s",$1->code[i].line);
                    }
                }
                int j=$1->numLines;
                sprintf(p->code[j].line,"label, %s",label1);
                for(int i=j+1;i<$3->numLines+j+1;i++){
                    sprintf(p->code[i].line,"%s",$3->code[i-j-1].line);
                }
                j=$3->numLines+j+1;
                sprintf(p->code[j].line,"exit_label");
                $$=p;
            }
            ;

Switch_Labels:
             Switch_Label {$$=$1;}
            |  Switch_Labels Switch_Label {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$1->numLines + $2->numLines;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));

                for(int i=0;i<$1->numLines;i++){
                        sprintf(p->code[i].line,"%s",$1->code[i].line);
                }
                int j=$1->numLines;
                for(int i=j;i<p->numLines;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i-j].line);
                }
                $$=p;
            }
            ;

Switch_Label:
             token_case Expression ':' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=$2->numLines + 3;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"start_label");
                for(int i=1;i<$2->numLines+1;i++){
                    sprintf(p->code[i].line,"%s",$2->code[i-1].line);
                }
                int j=$2->numLines+1;
                sprintf(p->code[j].line,"%s,statement_break",$2->place);
                sprintf(p->code[j+1].line,"end_label");
                $$=p;
            }
            |  token_default ':' {
                node *p = (node*)malloc(sizeof(node));
                p->numLines=1;
                p->code = (Code*)malloc(p->numLines * sizeof(Code));
                sprintf(p->code[0].line,"start_label");
                $$=p;
            }
            ;
%%

int ParserStatus=1;

int yyerror(char *s){
    // printf("-------------------------------here\n");
    ParserStatus=0;
    // printf("%s", s);
    if(strstr(s,"syntax")!=NULL){
        printf(ANSI_COLOR_RED"Line %d: "ANSI_COLOR_RESET"Syntax Error\n",LINE_NO);
    }else printf("%s\n",s);
    // printf("-------------------------------hereover\n");
    // exit(0);
        return 0;
}

// int main(int argc, char *argv[]){
//     StoreString("\n");
//     CurrentTable = (SymbolTableStruct *)malloc(sizeof(SymbolTableStruct));
//     if(argc<2){
//         printf("Usage: parser <path_to_c#_code>\n");
//         exit(1);
//     }
//     yyin = fopen(argv[1], "r");
//     VariableOutFile = fopen("var.txt", "w");
//     if (yyin == NULL){
//         printf("Error: %s does not exist\n",argv[1]);
//         exit(EXIT_FAILURE);
//     }
//     yyparse();
//     fclose(yyin);
//     fclose(VariableOutFile);
//     return 0;
// }

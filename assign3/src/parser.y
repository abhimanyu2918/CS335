%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

Node *head;

const int NON_TERM_COUNT=57;
const char nonTermArray[57][25] = {"Block_or_Semi","Literal","Print_Stm","Print_Args","Print_Arg","Type","Base_Type",
"Other_Type","Expression_Opt","Expression","Conditional_Exp","Or_Exp","And_Exp",
"Logical_Or_Exp","Logical_Xor_Exp","Logical_And_Exp","Equality_Exp","Compare_Exp","Shift_Exp",
"Add_Exp","Mult_Exp","Unary_Exp","Primary_Exp","Primary","Arg_List_Opt","Arg_List","Stm_List",
"Statement","Then_Stm","Normal_Stm","Block","Variable_Decs","Variable_Declarator",
"Variable_Initializer","For_Init_Opt","For_Iterator_Opt","For_Condition_Opt",
"Statement_Exp_List","Local_Var_Decl","Statement_Exp","Assign_Tail","Method",
"Compilation_Unit","Class_Decl","Class_Item_Decs_Opt","Class_Item","Field_Dec",
"Method_Dec","Formal_Param_List_Opt","Formal_Param_List","Formal_Param",
"Array_Initializer","Variable_Initializer_List","Switch_Sections_Opt",
"Switch_Section","Switch_Labels","Switch_Label"}; 



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

%}

%start Compilation_Unit

%token token_class 
%token token_identifier 
%token token_int 
%token token_char 
%token token_bool 
%token token_void 
%token token_true 
%token token_false 
%token token_if
%token token_while
%token token_else
%token token_for
%token token_continue
%token token_switch
%token token_string_literal
%token token_return
%token token_endl
%token token_dec_literal
%token token_char_literal
%token token_case
%token token_break
%token token_default
%token token_print
%token token_is
%token token_plus_plus
%token token_minus_minus
%token token_plus_assign
%token token_minus_assign
%token token_bit_xor_assign
%token token_bit_and_assign
%token token_bit_or_assign
%token token_remainder_assign
%token token_eq
%token token_not_eq
%token token_less_eq
%token token_greater_eq
%token token_shift_left_assign
%token token_shift_right_assign
%token token_shift_left
%token token_shift_right
%token token_cond_and
%token token_cond_or
%token token_mul_assign
%token token_quotient_assign

%%

Block_or_Semi: 
            Block   {fprintf(f,"Block_or_Semi Block 0\n");}
            | ';'   {fprintf(f,"Block_or_Semi ; 0\n");}
            ;


Literal: 
            token_true {fprintf(f,"Literal token_true 0\n");}
            |  token_false {fprintf(f,"Literal token_false 0\n");}
            |  token_dec_literal {fprintf(f,"Literal token_dec_literal 0\n");}
            |  token_char_literal       {fprintf(f,"Literal token_char_literal 0\n");}
            ;

Print_Stm:
            token_print Print_Args ';' {fprintf(f,"Print_Stm token_print Print_Args ; 0\n");}
            ;   

Print_Args: 
            Print_Arg '+' Print_Args {fprintf(f,"Print_Args Print_Arg + Print_Args 0\n");}
            | Print_Arg {fprintf(f,"Print_Args Print_Arg 0\n");}
            | {fprintf(f,"Print_Args 0\n");}
            ;

Print_Arg:  
            token_string_literal {fprintf(f,"Print_Arg token_string_literal 0\n");} 
            | token_identifier  {fprintf(f,"Print_Arg token_identifier 0\n");}
            | token_endl {fprintf(f,"Print_Arg token_endl 0\n");}
            ;

Type: 
            Other_Type {fprintf(f,"Type Other_Type 0\n");}
            | Base_Type {fprintf(f,"Type Base_Type 0\n");}
            | Base_Type'['']' {fprintf(f,"Type Base_Type [ ] 0\n");}
            ;

Base_Type: 
            token_int {fprintf(f,"Base_Type token_int 0\n");} 
            | token_char {fprintf(f,"Base_Type token_char 0\n");}
            | token_bool {fprintf(f,"Base_Type token_bool 0\n");}
            ;

Other_Type: 
            token_void {fprintf(f,"Other_Type token_void 0\n");}
            ;

Expression_Opt: 
            Expression {fprintf(f,"Expression_Opt Expression 0\n");}
            |   {fprintf(f,"Expression_Opt 0\n");}
            ;


Expression:
             Conditional_Exp '='   Expression {fprintf(f,"Expression Conditional_Exp = Expression 0\n");}
            |  Conditional_Exp token_plus_assign  Expression {fprintf(f,"Expression Conditional_Exp token_plus_assign Expression 0\n");}
            |  Conditional_Exp token_minus_assign  Expression {fprintf(f,"Expression Conditional_Exp token_minus_assign Expression 0\n");}
            |  Conditional_Exp token_mul_assign  Expression {fprintf(f,"Expression Conditional_Exp token_mul_assign Expression 0\n");}
            |  Conditional_Exp token_quotient_assign  Expression {fprintf(f,"Expression Conditional_Exp token_quotient_assign Expression 0\n");}
            |  Conditional_Exp token_bit_xor_assign  Expression {fprintf(f,"Expression Conditional_Exp token_bit_xor_assign Expression 0\n");}
            |  Conditional_Exp token_bit_and_assign  Expression {fprintf(f,"Expression Conditional_Exp token_bit_and_assign Expression 0\n");}
            |  Conditional_Exp token_bit_or_assign  Expression {fprintf(f,"Expression Conditional_Exp token_bit_or_assign Expression 0\n");}
            |  Conditional_Exp token_remainder_assign  Expression {fprintf(f,"Expression Conditional_Exp token_remainder_assign Expression 0\n");}
            |  Conditional_Exp token_shift_left_assign Expression {fprintf(f,"Expression Conditional_Exp token_shift_left_assign Expression 0\n");}
            |  Conditional_Exp token_shift_right_assign Expression {fprintf(f,"Expression Conditional_Exp token_shift_right_assign Expression 0\n");}
            |  Conditional_Exp {fprintf(f,"Expression Conditional_Exp 0\n");}
            ;

Conditional_Exp: 
            Or_Exp '?' Or_Exp ':' Conditional_Exp {fprintf(f,"Conditional_Exp Or_Exp ? Or_Exp : Conditional_Exp 0\n");}
            |  Or_Exp {fprintf(f,"Conditional_Exp Or_Exp 0\n");}
            ;

Or_Exp: 
            Or_Exp token_cond_or And_Exp {fprintf(f,"Or_Exp Or_Exp token_cond_or And_Exp 0\n");}
            |  And_Exp {fprintf(f,"Or_Exp And_Exp 0\n");}
            ;
And_Exp:
            And_Exp token_cond_and Logical_Or_Exp {fprintf(f,"And_Exp And_Exp token_cond_and Logical_Or_Exp 0\n");}
            |  Logical_Or_Exp {fprintf(f,"And_Exp Logical_Or_Exp 0\n");}
            ;

Logical_Or_Exp: 
            Logical_Or_Exp '|' Logical_Xor_Exp {fprintf(f,"Logical_Or_Exp Logical_Or_Exp | Logical_Xor_Exp 0\n");}
            |  Logical_Xor_Exp {fprintf(f,"Logical_Or_Exp Logical_Xor_Exp 0\n");}
            ;

Logical_Xor_Exp:
            Logical_Xor_Exp '^' Logical_And_Exp {fprintf(f,"Logical_Xor_Exp Logical_Xor_Exp ^ Logical_And_Exp 0\n");}
            |  Logical_And_Exp {fprintf(f,"Logical_Xor_Exp Logical_And_Exp 0\n");}
            ;

Logical_And_Exp:
            Logical_And_Exp '&' Equality_Exp {fprintf(f,"Logical_And_Exp Logical_And_Exp & Equality_Exp 0\n");}
            |  Equality_Exp {fprintf(f,"Logical_And_Exp Equality_Exp 0\n");}
            ;

Equality_Exp:
            Equality_Exp token_eq Compare_Exp {fprintf(f,"Equality_Exp Equality_Exp token_eq Compare_Exp 0\n");}
            |  Equality_Exp token_not_eq Compare_Exp {fprintf(f,"Equality_Exp Equality_Exp token_not_eq Compare_Exp 0\n");}
            |  Compare_Exp {fprintf(f,"Equality_Exp Compare_Exp 0\n");}
            ;

Compare_Exp:
            Compare_Exp '<' Shift_Exp {fprintf(f,"Compare_Exp Compare_Exp < Shift_Exp 0\n");}
            |  Compare_Exp '>' Shift_Exp {fprintf(f,"Compare_Exp Compare_Exp > Shift_Exp 0\n");}
            |  Compare_Exp token_less_eq Shift_Exp {fprintf(f,"Compare_Exp Compare_Exp token_less_eq Shift_Exp 0\n");}
            |  Compare_Exp token_greater_eq Shift_Exp {fprintf(f,"Compare_Exp Compare_Exp token_greater_eq Shift_Exp 0\n");}
            |  Compare_Exp token_is Type {fprintf(f,"Compare_Exp Compare_Exp token_is Type 0\n");} 
            |  Shift_Exp {fprintf(f,"Compare_Exp Shift_Exp 0\n");}
            ; 

Shift_Exp:
            Shift_Exp token_shift_left Add_Exp {fprintf(f,"Shift_Exp Shift_Exp token_shift_left Add_Exp 0\n");}
            |  Shift_Exp token_shift_right Add_Exp {fprintf(f,"Shift_Exp Shift_Exp token_shift_right Add_Exp 0\n");}
            |  Add_Exp {fprintf(f,"Shift_Exp Add_Exp 0\n");}
            ;

Add_Exp: 
            Add_Exp '+' Mult_Exp {fprintf(f,"Add_Exp Add_Exp + Mult_Exp 0\n");}
            |  Add_Exp '-' Mult_Exp {fprintf(f,"Add_Exp Add_Exp - Mult_Exp 0\n");}
            |  Mult_Exp {fprintf(f,"Add_Exp Mult_Exp 0\n");}
            ;

Mult_Exp: 
            Mult_Exp '*' Unary_Exp  {fprintf(f,"Mult_Exp Mult_Exp * Unary_Exp 0\n");}
            |  Mult_Exp '/' Unary_Exp  {fprintf(f,"Mult_Exp Mult_Exp / Unary_Exp 0\n");}
            |  Mult_Exp '%' Unary_Exp  {fprintf(f,"Mult_Exp %% Unary_Exp 0\n");}
            |  Unary_Exp  {fprintf(f,"Mult_Exp Unary_Exp 0\n");}
            ;

Unary_Exp: 
            '!'  Unary_Exp {fprintf(f,"Unary_Exp ! Unary_Exp 0\n");}
            |  '~'  Unary_Exp {fprintf(f,"Unary_Exp ~ Unary_Exp 0\n");}
            |  '-'  Unary_Exp {fprintf(f,"Unary_Exp - Unary_Exp 0\n");}
            |  token_plus_plus Unary_Exp {fprintf(f,"Unary_Exp token_plus_plus Unary_Exp 0\n");}
            |  token_minus_minus Unary_Exp {fprintf(f,"Unary_Exp token_minus_minus Unary_Exp 0\n");}
            |  Primary_Exp {fprintf(f,"Unary_Exp Primary_Exp 0\n");}
            ;

Primary_Exp:  
            Primary {fprintf(f,"Primary_Exp Primary 0\n");}
            |  '(' Expression ')' {fprintf(f,"Primary_Exp ( Expression ) 0\n");}
            |   Method {fprintf(f,"Primary_Exp Method 0\n");}
            ;

Primary: 
            token_identifier {fprintf(f,"Primary token_identifier 0\n");}
            |  Literal        {fprintf(f,"Primary Literal 0\n");}
            ;

Arg_List_Opt: 
            Arg_List {fprintf(f,"Arg_List_Opt Arg_List 0\n");}
            |  {fprintf(f,"Arg_List_Opt 0\n");}
            ;

Arg_List: 
            Arg_List ',' Expression {fprintf(f,"Arg_List Arg_List , Expression 0\n");}
            |  Expression {fprintf(f,"Arg_List Expression 0\n");}
            ;

Stm_List: 
            Stm_List Statement {fprintf(f,"Stm_List Stm_List Statement 0\n");}
            |  Statement {fprintf(f,"Stm_List Statement 0\n");}
            ;
Statement:  
            Local_Var_Decl ';' {fprintf(f,"Statement Local_Var_Decl ; 0\n");}
            |  token_if '(' Expression ')' Statement {fprintf(f,"Statement token_if ( Expression ) Statement 0\n");}
            |  token_if '(' Expression ')' Then_Stm token_else Statement  {fprintf(f,"Statement token_if ( Expression ) Then_Stm token_else Statement 0\n");}      
            |  token_for '(' For_Init_Opt ';' For_Condition_Opt ';' For_Iterator_Opt ')' Statement {fprintf(f,"Statement token_for ( For_Init_Opt ; For_Condition_Opt ; For_Iterator_Opt ) Statement 0\n");}
            |  token_while    '(' Expression ')' Statement {fprintf(f,"Statement token_while ( Expression ) Statement 0\n");}
            |  Normal_Stm   {fprintf(f,"Statement Normal_Stm 0\n");}
            ;

Then_Stm: 
            token_if '(' Expression ')' Then_Stm token_else Then_Stm     {fprintf(f,"Then_Stm token_if ( Expression ) Then_Stm token_else Then_Stm 0\n");}   
            |  token_for '(' For_Init_Opt ';' For_Condition_Opt ';' For_Iterator_Opt ')' Then_Stm {fprintf(f,"Then_Stm token_for ( For_Init_Opt ; For_Condition_Opt ; For_Iterator_Opt ) Then_Stm 0\n");}
            |  token_while '(' Expression ')' Then_Stm {fprintf(f,"Then_Stm token_while ( Expression ) Then_Stm 0\n");}
            |  Normal_Stm   {fprintf(f,"Then_Stm Normal_Stm 0\n");}
            ;
          
Normal_Stm:  
            token_break ';' {fprintf(f,"Normal_Stm token_break ; 0\n");}
            |  token_continue ';' {fprintf(f,"Normal_Stm token_continue ; 0\n");}
            |  token_return Expression_Opt ';' {fprintf(f,"Normal_Stm token_return Expression_Opt ; 0\n");}
            |  Statement_Exp ';'        {fprintf(f,"Normal_Stm Statement_Exp ; 0\n");}
            |  ';'  {fprintf(f,"Normal_Stm ; 0\n");}
            |  Block    {fprintf(f,"Normal_Stm Block 0\n");}
            |  token_switch '(' Expression ')' '{' Switch_Sections_Opt '}' {fprintf(f,"Normal_Stm token_switch ( Expression ) { Switch_Sections_Opt } 0\n");}
            |  Print_Stm {fprintf(f,"Normal_Stm Print_Stm 0\n");}
            ;

Block:  
            '{' Stm_List '}' {fprintf(f,"Block { Stm_List } 0\n");}
            |  '{' '}' {fprintf(f,"Block { } 0\n");}
            ;

Variable_Decs: 
            Variable_Declarator {fprintf(f,"Variable_Decs Variable_Declarator 0\n");}
            |  Variable_Decs ',' Variable_Declarator {fprintf(f,"Variable_Decs Variable_Decs , Variable_Declarator 0\n");}
            ;

Variable_Declarator:
            token_identifier {fprintf(f,"Variable_Declarator token_identifier 0\n");}
            |  token_identifier '=' Variable_Initializer {fprintf(f,"Variable_Declarator token_identifier = Variable_Initializer 0\n");}
            ;

Variable_Initializer: 
            Expression {fprintf(f,"Variable_Initializer Expression 0\n");}
            |  Array_Initializer {fprintf(f,"Variable_Initializer Array_Initializer 0\n");}
            ;

For_Init_Opt:
            Local_Var_Decl {fprintf(f,"For_Init_Opt Local_Var_Decl 0\n");}
            |  Statement_Exp_List {fprintf(f,"For_Init_Opt Statement_Exp_List 0\n");}
            |  {fprintf(f,"For_Init_Opt 0\n");}
            ;

For_Iterator_Opt: 
            Statement_Exp_List {fprintf(f,"For_Iterator_Opt Statement_Exp_List 0\n");}
            |   {fprintf(f,"For_Iterator_Opt 0\n");}
            ;

For_Condition_Opt: 
            Expression {fprintf(f,"For_Condition_Opt Expression 0\n");}
            |   {fprintf(f,"For_Condition_Opt 0\n");}
            ;

Statement_Exp_List:
            Statement_Exp_List ',' Statement_Exp {fprintf(f,"Statement_Exp_List Statement_Exp_List , Statement_Exp 0\n");}
            |  Statement_Exp {fprintf(f,"Statement_Exp_List Statement_Exp 0\n");}
            ;

Local_Var_Decl: 
            Type Variable_Decs {fprintf(f,"Local_Var_Decl Type Variable_Decs 0\n");}
            ;

Statement_Exp:
             Method {fprintf(f,"Statement_Exp Method 0\n");}
            |  token_identifier Assign_Tail {fprintf(f,"Statement_Exp token_identifier Assign_Tail 0\n");}
            ;

Assign_Tail:
             token_plus_plus {fprintf(f,"Assign_Tail token_plus_plus 0\n");}
            |  token_minus_minus       {fprintf(f,"Assign_Tail token_minus_minus 0\n");}
            |  '=' Expression {fprintf(f,"Assign_Tail = Expression 0\n");}
            |  token_plus_assign  Expression {fprintf(f,"Assign_Tail token_plus_assign Expression 0\n");}
            |  token_minus_assign  Expression {fprintf(f,"Assign_Tail token_minus_assign Expression 0\n");}
            |  token_mul_assign  Expression {fprintf(f,"Assign_Tail token_mul_assign Expression 0\n");}
            |  token_quotient_assign  Expression {fprintf(f,"Assign_Tail token_quotient_assign Expression 0\n");}
            |  token_bit_xor_assign  Expression {fprintf(f,"Assign_Tail token_bit_xor_assign Expression 0\n");}
            |  token_bit_and_assign  Expression {fprintf(f,"Assign_Tail token_bit_and_assign Expression 0\n");}
            |  token_bit_or_assign  Expression {fprintf(f,"Assign_Tail token_bit_or_assign Expression 0\n");}
            |  token_remainder_assign  Expression {fprintf(f,"Assign_Tail token_remainder_assign Expression 0\n");}
            |  token_shift_left_assign Expression {fprintf(f,"Assign_Tail token_shift_left_assign Expression 0\n");}
            |  token_shift_right_assign Expression {fprintf(f,"Assign_Tail token_shift_right_assign Expression 0\n");}
            ;

Method: 
            token_identifier '(' Arg_List_Opt ')' {fprintf(f,"Method token_identifier ( Arg_List_Opt ) 0\n");}
            ;

Compilation_Unit:
             Class_Decl {fprintf(f,"Compilation_Unit Class_Decl 0\n");}
             ;
Class_Decl: 
            token_class token_identifier '{' Class_Item_Decs_Opt '}' {fprintf(f,"Class_Decl token_class token_identifier { Class_Item_Decs_Opt } 0\n");} 
            ;

Class_Item_Decs_Opt: 
            Class_Item_Decs_Opt Class_Item {fprintf(f,"Class_Item_Decs_Opt Class_Item_Decs_Opt Class_Item 0\n");}
            |  {fprintf(f,"Class_Item_Decs_Opt 0\n");}
            ;

Class_Item:  
            Field_Dec {fprintf(f,"Class_Item Field_Dec 0\n");}
            |  Method_Dec {fprintf(f,"Class_Item Method_Dec 0\n");}
            ;

Field_Dec: 
            Local_Var_Decl ';' {fprintf(f,"Field_Dec Local_Var_Decl ; 0\n");}
            ;

Method_Dec: 
            Type token_identifier '(' Formal_Param_List_Opt ')' Block_or_Semi {fprintf(f,"Method_Dec Type token_identifier ( Formal_Param_List_Opt ) Block_or_Semi 0\n");}
            ;
Formal_Param_List_Opt: 
            Formal_Param_List {fprintf(f,"Formal_Param_List_Opt Formal_Param_List 0\n");}
            |   {fprintf(f,"Formal_Param_List_Opt 0\n");}
            ;

Formal_Param_List:
            Formal_Param {fprintf(f,"Formal_Param_List Formal_Param 0\n");}
            | Formal_Param_List ',' Formal_Param {fprintf(f,"Formal_Param_List Formal_Param_List , Formal_Param 0\n");}
            ;

Formal_Param: 
            Type token_identifier  {fprintf(f,"Formal_Param Type token_identifier 0\n");}
            ;

Array_Initializer: 
            '{'  '}' {fprintf(f,"Array_Initializer { } 0\n");}
            |  '{' Variable_Initializer_List '}' {fprintf(f,"Array_Initializer { Variable_Initializer_List } 0\n");}
            ;

Variable_Initializer_List: 
            Variable_Initializer {fprintf(f,"Variable_Initializer_List Variable_Initializer 0\n");} 
            | Variable_Initializer_List ',' Variable_Initializer {fprintf(f,"Variable_Initializer_List Variable_Initializer_List , Variable_Initializer 0\n");}
            ;

Switch_Sections_Opt:
             Switch_Sections_Opt Switch_Section {fprintf(f,"Switch_Sections_Opt Switch_Sections_Opt Switch_Section 0\n");}
            |   {fprintf(f,"Switch_Sections_Opt 0\n");}
            ;

Switch_Section:
            Switch_Labels Stm_List {fprintf(f,"Switch_Section Switch_Labels Stm_List 0\n");}
            ;

Switch_Labels:
             Switch_Label {fprintf(f,"Switch_Labels Switch_Label 0\n");}
            |  Switch_Labels Switch_Label {fprintf(f,"Switch_Labels Switch_Labels Switch_Label 0\n");}
            ;

Switch_Label:
             token_case Expression ':' {fprintf(f,"Switch_Label token_case Expression : 0\n");}
            |  token_default ':' {fprintf(f,"Switch_Label token_default : 0\n");}
            ;
%%


int yyerror(char *s){
    printf("%s", s);
    if(strstr(s,"syntax")!=NULL){
        printf(" at line %d\n",LINE_NO);
    }else printf("\n");
    system("rm parser_temp_file");
    exit(0);
}

int main(int argc, char *argv[]){
    f = fopen("parser_temp_file", "w");
    if(argc<2){
    	printf("Usage: parser <path_to_c#_code>\n");
    	exit(1);
    }
    yyin = fopen(argv[1], "r"); 
    if (yyin == NULL){
    	printf("Error: %s does not exist\n",argv[1]);
        exit(EXIT_FAILURE);
    }
    char *path = strtok (argv[1],".");
    char *name,*temp_name = strtok(path,"/");
    while(temp_name!=NULL){
	    name=temp_name;
	    temp_name = strtok(NULL,"/");
    }
    char outFileName[20];
    sprintf(outFileName,"%s.html",name);
    yyparse();
    fclose(yyin);
    fclose(f);
    system("tac parser_temp_file > parser_temp_file2");
    outFile = fopen(outFileName, "w");
    fprintf(outFile,"<html><head>\n<title>Rightmost Derivation</title>\n<head>\n</head>\n<body>\n\n");
    FILE * fp;
    char * line = NULL;
    size_t len = 0;
    ssize_t read;

    fp = fopen("parser_temp_file2", "r");
    if (fp == NULL)
        exit(EXIT_FAILURE);
    int line_num=1;
    pushNode(&head,"Compilation_Unit");
    fprintf(outFile,"%d. <font color=\"red\"><u>Compilation_Unit</u></font><br><hr>\n",line_num);
    line_num++;
    while ((read = getline(&line, &len, fp)) != -1) {
        fprintf(outFile,"%d. <font color=\"blue\">", line_num);
        line_num++;
        char *word = strtok (line," ");
        Node *t = head; //non terminal that is being expanded
        
        while(t->next != NULL){
            t=t->next;
        }
        while(strcmp(t->s,word)!=0)t=t->prev;
        word = strtok (NULL, " ");
        Node *t1=NULL;   //linked list of expansion of t
        while (word != NULL )
        {
            if(strcmp(word,"0\n")==0 || strcmp(word,"0")==0)break;
            pushNode(&t1, word);
            word = strtok (NULL, " ");
        }
        if(t1==NULL)pushNode(&t1, " ");
        t1->prev = t->prev;
        if(t->prev!=NULL)t->prev->next=t1;
        else head = t1;
        Node* t2=t1; //t2 is to derived next
        while(t2->next!=NULL)t2=t2->next;
        t2->next = t->next;
        if(t->next!=NULL)t->next->prev=t2;
        while(t2->next!=NULL)t2=t2->next;
        while(t2!=NULL){
            if(isNonTerminal(t2->s)==1)break;
            t2=t2->prev;
        }
        Node *t3=head;
        int font=0,u=0;
        while(t3!=NULL){
            if(t3==t1){
                font=1;
                fprintf(outFile,"<font color=\"red\">");
            }
            if(t3==t->next){
                font=0;
                fprintf(outFile,"</font>");
            }
            if(t3==t2){
                u=1;
                fprintf(outFile,"<u><b><mark>");
            }
            fprintf(outFile,"%s ", t3->s);
            if(t3==t2){
                u=0;
                fprintf(outFile,"</mark></b></u>");
            }
            t3=t3->next;
        }
        if(u!=0)fprintf(outFile,"</b></u>");
        if(font!=0)fprintf(outFile,"</font>");
        fprintf(outFile,"</font><br><hr>\n");
    }
    fprintf(outFile,"</body>\n</html>\n");
    fclose(fp);
    fclose(outFile);
    system("rm parser_temp_file");
    system("rm parser_temp_file2");
    exit(EXIT_SUCCESS); 
    return 0;
}

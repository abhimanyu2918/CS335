%{
	#include <stdio.h>
	#include <stdlib.h>
	int yyerror(char *);
	int yylex(void);
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
%token token_bit_remainder_assign
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
            Block 
            | ';'
            ;


Literal: 
            token_true 
            |  token_false 
            |  token_dec_literal 
            |  token_char_literal       
			;

Print_Stm:
            token_print Print_Args ';'
            ;

Print_Args: 
            Print_Arg '+' Print_Args 
            | Print_Arg
            |
            ;

Print_Arg:  
            token_string_literal  
            | token_identifier 
            | token_endl
            ;

Type: 
            Other_Type 
            | Base_Type 
            | Base_Type'['']'
            ;

Base_Type: 
            token_int 
            | token_char 
            | token_bool
            ;

Other_Type: 
            token_void
            ;

Expression_Opt: 
            Expression 
            |   
            ;


Expression:
             Conditional_Exp '='   Expression
            |  Conditional_Exp token_plus_assign  Expression
            |  Conditional_Exp token_minus_assign  Expression
            |  Conditional_Exp token_mul_assign  Expression
            |  Conditional_Exp token_quotient_assign  Expression
            |  Conditional_Exp token_bit_xor_assign  Expression
            |  Conditional_Exp token_bit_and_assign  Expression
            |  Conditional_Exp token_bit_or_assign  Expression
            |  Conditional_Exp token_bit_remainder_assign  Expression
            |  Conditional_Exp token_shift_left_assign Expression
            |  Conditional_Exp token_shift_right_assign Expression
            |  Conditional_Exp
            ;

Conditional_Exp: 
            Or_Exp '?' Or_Exp ':' Conditional_Exp
            |  Or_Exp
            ;

Or_Exp: 
            Or_Exp token_cond_or And_Exp
            |  And_Exp
            ;
And_Exp:
            And_Exp token_cond_and Logical_Or_Exp
            |  Logical_Or_Exp
            ;

Logical_Or_Exp: 
            Logical_Or_Exp '|' Logical_Xor_Exp
            |  Logical_Xor_Exp
            ;

Logical_Xor_Exp:
            Logical_Xor_Exp '^' Logical_And_Exp
            |  Logical_And_Exp
            ;

Logical_And_Exp:
            Logical_And_Exp '&' Equality_Exp
            |  Equality_Exp
            ;

Equality_Exp:
            Equality_Exp token_eq Compare_Exp
            |  Equality_Exp token_not_eq Compare_Exp
            |  Compare_Exp
            ;

Compare_Exp:
            Compare_Exp '<'  Shift_Exp
            |  Compare_Exp '>'  Shift_Exp
            |  Compare_Exp token_less_eq Shift_Exp
            |  Compare_Exp token_greater_eq Shift_Exp
            |  Compare_Exp token_is Type 
            |  Shift_Exp 
            ; 

Shift_Exp:
            Shift_Exp token_shift_left Add_Exp
            |  Shift_Exp token_shift_right Add_Exp
            |  Add_Exp
            ;

Add_Exp: 
            Add_Exp '+' Mult_Exp
            |  Add_Exp '-' Mult_Exp
            |  Mult_Exp
            ;

Mult_Exp: 
            Mult_Exp '*' Unary_Exp  
            |  Mult_Exp '/' Unary_Exp  
            |  Mult_Exp '%' Unary_Exp  
            |  Unary_Exp  
            ;

Unary_Exp: 
            '!'  Unary_Exp
            |  '~'  Unary_Exp
            |  '-'  Unary_Exp
            |  token_plus_plus Unary_Exp
            |  token_minus_minus Unary_Exp
            |  Primary_Exp
            ;

Primary_Exp:  
            Primary
            |  '(' Expression ')' 
            |   Method
            ;

Primary: 
            token_identifier
            |  Literal        
            ;

Arg_List_Opt: 
            Arg_List 
            |  
            ;

Arg_List: 
            Arg_List ',' Expression 
            |  Expression
            ;

Stm_List: 
            Stm_List Statement
            |  Statement
            ;
Statement:  
            Local_Var_Decl ';'
            |  Print_Stm
            |  token_if '(' Expression ')' Statement
            |  token_if '(' Expression ')' Then_Stm token_else Statement        
            |  token_for '(' For_Init_Opt ';' For_Condition_Opt ';' For_Iterator_Opt ')' Statement
            |  token_while    '(' Expression ')' Statement
            |  Normal_Stm   
            ;

Then_Stm: 
            token_if       '(' Expression ')' Then_Stm token_else Then_Stm        
            |  token_for      '(' For_Init_Opt ';' For_Condition_Opt ';' For_Iterator_Opt ')' Then_Stm
            |  token_while    '(' Expression ')' Then_Stm
            |  Normal_Stm   
            ;
          
Normal_Stm:  
            token_break ';'
            |  token_continue ';'
            |  token_return Expression_Opt ';'
            |  Statement_Exp ';'        
            |  ';'
            |  Block    
            |  token_switch '(' Expression ')' '{' Switch_Sections_Opt '}'
            ;

Block: 
            '{' Stm_List '}'
            |  '{' '}' 
            ;

Variable_Decs: 
            Variable_Declarator
            |  Variable_Decs ',' Variable_Declarator
            ;

Variable_Declarator:
            token_identifier
            |  token_identifier '=' Variable_Initializer
            ;

Variable_Initializer:
            Expression
            |  Array_Initializer
            ;

For_Init_Opt:
            Local_Var_Decl
            |  Statement_Exp_List
            |  
            ;

For_Iterator_Opt: 
            Statement_Exp_List
            |   
            ;

For_Condition_Opt: 
            Expression
            |   
            ;

Statement_Exp_List:
            Statement_Exp_List ',' Statement_Exp
            |  Statement_Exp
            ;

Local_Var_Decl: 
            Type Variable_Decs 
            ;

Statement_Exp:
             Method
            |  token_identifier Assign_Tail
            ;

Assign_Tail:
             token_plus_plus
            |  token_minus_minus       
            |  '='   Expression
            |  token_plus_assign  Expression
            |  token_minus_assign  Expression
            |  token_mul_assign  Expression
            |  token_quotient_assign  Expression
            |  token_bit_xor_assign  Expression
            |  token_bit_and_assign  Expression
            |  token_bit_or_assign  Expression
            |  token_bit_remainder_assign  Expression
            |  token_shift_left_assign Expression
            |  token_shift_right_assign Expression
            ;

Method: 
            token_identifier '(' Arg_List_Opt ')' 
            ;

Compilation_Unit:
             Class_Decl 
             ;
Class_Decl: 
            token_class token_identifier '{' Class_Item_Decs_Opt '}' 
            ;

Class_Item_Decs_Opt: 
            Class_Item_Decs_Opt Class_Item
            |  
            ;

Class_Item:  
            Field_Dec 
            |  Method_Dec
            ;

Field_Dec: 
            Local_Var_Decl ';'
            ;

Method_Dec: 
            Type token_identifier '(' Formal_Param_List_Opt ')' Block_or_Semi
        
Formal_Param_List_Opt: 
            Formal_Param_List 
            |   
            ;

Formal_Param_List:
            Formal_Param 
            | Formal_Param_List','Formal_Param
            ;

Formal_Param: 
            Type token_identifier  
            ;

Array_Initializer: 
            '{'  '}'
            |  '{' Variable_Initializer_List '}'
            ;

Variable_Initializer_List: 
            Variable_Initializer
            | Variable_Initializer_List ',' Variable_Initializer
            ;

Switch_Sections_Opt:
             Switch_Sections_Opt Switch_Section
            | 
            ;

Switch_Section:
            Switch_Labels Stm_List
            ;

Switch_Labels:
             Switch_Label
            |  Switch_Labels Switch_Label
            ;

Switch_Label:
             token_case Expression ':'
            |  token_default ':'
            ;
%%

int yyerror(char *s){
	printf("Error: %s\n", s);
	return 0;
}

int main(int argc, char *argv[]){
	// yyin = fopen(argv[1], "r"); 
	yyparse();
    // fclose(yyin);
	return 0;
}
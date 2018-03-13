%{
	#include <stdio.h>
	#include <stdlib.h>
	int yyerror(char *);
	int yylex(void);
%}

%token token_class token_identifier token_int token_char token_bool token_void token_true token_false token_decLiteral token_charLiteral

%%

Class_Decl:
				token_class token_identifier '{' Class_Item_Decs_Opt '}' { printf("<Class Decl> ::= class Identifier '{' <Class Item Decs Opt> '}'\n");}
				;		

Class_Item_Decs_Opt:
				Class_Item_Decs_Opt Class_Item	{ printf("ClassItemDecOpt : ClassItemDecOpt ClassItem\n");}
        		|   { printf("ClassItemDecOpt: \n");}
        		;

Class_Item:  
				Field_Dec {printf("ClassItem: Field_Dec\n");}
				;

Field_Dec:
				Local_Var_Decl ';' {printf("Field_Dec: Local_Var_Decl ;\n");}
				;

Local_Var_Decl:
				Type Variable_Decs {printf("Local_Var_Decl : Type Variable_Decs\n");}
				;

Type: 	
				Other_Type {printf("Type: Other_Type\n");}
				| Base_Type {printf("Type: Base_Type\n");}
				| Base_Type'['']'
    			;

Base_Type: 
				token_int {printf("Base_Type: token_int\n");}
				| token_char {printf("Base_Type: token_char\n");}
				| token_bool {printf("Base_Type: token_bool\n");}
				;

Other_Type:
				token_void {printf("Other_Type: token_void\n");}
				;

Variable_Decs:
				Variable_Declarator {printf("Variable_Decs: Variable_Declarator\n");}
         		|  Variable_Decs ',' Variable_Declarator {printf("Variable_Decs: Variable_Decs , Variable_Declarator\n");}
         		;

Variable_Declarator:
				token_identifier {printf("Variable_Declarator: token_identifier\n");}
         		|  token_identifier '=' token_identifier {printf("Variable_Declarator: token_identifier = token_identifier\n");}
         		|  token_identifier '=' Literal {printf("Variable_Declarator : token_identifier = Literal\n");}
         		;

Literal:
				token_true {printf("Literal = token_true\n");}
				|  token_false {printf("Literal = token_false\n");}
				|  token_decLiteral {printf("Literal = token_decLiteral\n");}
				|  token_charLiteral {printf("Literal = token_charLiteral\n");}
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
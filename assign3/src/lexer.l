%{
	#include "y.tab.h"
	int yyerror(char *);
%}

ws			[ \t]+
decnumber	[-+]?[0-9]+
id			[a-zA-Z_]([_a-zA-Z0-9]*)?
string		\"([^"\\]|(\\.))*\" 						
nl 			[\n\r]


%%
\"              { BEGIN STRING; } 
<STRING>\\n     {}           
<STRING>\\t     {}           
<STRING>\\\"    {}           
<STRING>\"      {  
                    BEGIN 0;
                	return token_string_literal;
                }           
<STRING>\n      { yyerror("invaid string\n"); exit(1);}
<STRING>.       {}                

"//"			{BEGIN SINGLE_COMMENT;}
"/*"			{BEGIN MULTI_COMMENT;}
<SINGLE_COMMENT>\n 	{
                    BEGIN 0;
                    }

<SINGLE_COMMENT>.	{}
<MULTI_COMMENT>"*/"	{
                    BEGIN 0;
                    }

<MULTI_COMMENT>[\n\r] {}
<MULTI_COMMENT>.	{}
"int"			return token_int;
"char"			return token_char
"bool"			return token_bool;
"void"			return token_void;

"if"			return token_if;
"return"		return token_return;
"else"			return token_else;
"switch"		return token_switch;
"break"			return token_break;
"for"			return token_for;
"while"			return token_while;
"class"			return token_class;
"endl"			return token_endl;
"is"			return token_is;
"false"			return token_false;
"true"			return token_true;
"default"		return token_default;
"Print"			return token_print;
"continue"		return token_continue;
"case"			return token_case;
[ \t\n\r]*		;

{decnumber}{id} {yyerror("Error token: %s\n",yytext);exit(1);}

{id}	return token_identifier;

"'"."'"		return token_char_literal;
{decnumber}	return token_dec_literal;



"{"				return *yytext;
"}"				return *yytext;
"("				return *yytext;
")"				return *yytext;
"["				return *yytext;
"]"			    return *yytext;
":"			    return *yytext;
";"			    return *yytext;
","			    return *yytext;
"=="		    return token_eq;
"!="			return token_not_eq;
"!"				return *yytext;
"++"			return token_plus_plus
"+="				return token_plus_assign;
"+"				return *yytext;
"--"				return token_minus_minus;
"-="				return token_minus_assign;
"-"				return *yytext;
"||"				return token_cond_or;
"|="				return token_bit_or_assign;
"&&"				return token_cond_and;
"&="				return token_bit_and_assign;
"&"				return *yytext;
"|"				return *yytext;
"<<="				return token_shift_left_assign
"<<"				return token_shift_left;
"<="				return token_less_eq;
"<"				return *yytext;    
"^="				return token token_bit_or_assign;       
"^"				return *yytext;              
"*="				return token_mul_assign;           
"*"				return *yytext;  
"/="				return token_quotient_assign;      
"/"				return *yytext;
"%="				return token_remainder_assign;     
"%"				return *yytext;
">>="				return token_shift_right_assign;  
">>"				return token_shift_right;
">="				return token_greater_eq;     
">"				return *yytext;  
"."				return *yytext;            
"?"				return *yytext;	
"~"				return *yytext;
"="				return *yytext;
[ \t\n\r]*		;
.				{yyerror("invalid character");}


%%
//"	--ignore this comment
int yywrap(void) { 		
	return 1; 
}

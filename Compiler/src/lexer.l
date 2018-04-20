%{
	#include "y.tab.h"
	int yyerror(char *);
	int LINE_NO=1;
	//[-+]?
%}

ws			[ \t]+
decnumber	[0-9]+
id			[a-zA-Z_]([_a-zA-Z0-9]*)?
string		\"([^"\\]|(\\.))*\" 						
nl 			[\n\r]

%x STRING
%x IDENTIFIER
%x SINGLE_COMMENT
%x MULTI_COMMENT

%{
	char buf[100]; 
	char *s;
%}
%%
\"              { BEGIN STRING;s = buf; } 
<STRING>\\n     { *s++ = '\n';}           
<STRING>\\t     {*s++ = '\t';}           
<STRING>\\\"    {*s++ = '\"';}           
<STRING>\"      {  *s = 0;
                    sprintf(yylval.string_val,"%s",buf);
                    BEGIN 0;
                	return token_string_literal;
                }           
<STRING>\n      {   char error_str[30];
					sprintf(error_str,"Line %d: Invalid String",LINE_NO);
					yyerror(error_str);}
<STRING>.       {*s++ = *yytext;}                

"//"			{BEGIN SINGLE_COMMENT;}
"/*"			{BEGIN MULTI_COMMENT;}
<SINGLE_COMMENT>\n 	{
                    BEGIN 0;
                    LINE_NO++;
                    }

<SINGLE_COMMENT>.	{}
<MULTI_COMMENT>"*/"	{
                    BEGIN 0;
                    LINE_NO++;
                    }

<MULTI_COMMENT>[\n\r] {LINE_NO++;}
<MULTI_COMMENT>.	{}
"int"			return token_int;
"char"			return token_char;
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
"struct"		{return token_struct;}

{decnumber}{id} {
				char error_str[30];
				sprintf(error_str,"Error token at line %d: %s",LINE_NO,yytext);
	 yyerror(error_str);}

{id}	{
	sprintf(yylval.id,"%s",yytext); 
	return token_identifier;}

"'"."'"		{yylval.dec_val=*(yytext+1); return token_char_literal;}
{decnumber}	{yylval.dec_val=atoi(yytext); return token_dec_literal;}



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
"++"			return token_plus_plus;
"+="				return token_plus_assign;
"+"				return *yytext;
"--"				{ return token_minus_minus;}
"-="				return token_minus_assign;
"-"				return *yytext;
"||"				return token_cond_or;
"|="				return token_bit_or_assign;
"&&"				return token_cond_and;
"&="				return token_bit_and_assign;
"&"				return *yytext;
"|"				return *yytext;
"<<="				return token_shift_left_assign;
"<<"				return token_shift_left;
"<="				return token_less_eq;
"<"				return *yytext;    
"^="				return token_bit_xor_assign;       
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

[ \t]*			;
[\n\r]			LINE_NO++;
.				{char error_str[30];
				sprintf(error_str,"Error token at line %d: %s",LINE_NO,yytext);
	 yyerror(error_str);}


%%
//"	--ignore this comment
int yywrap(void) { 		
	return 1; 
}


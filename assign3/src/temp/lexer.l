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
"int"		  	return token_int;
"char"			return token_char;
"bool"			return token_bool;
"void"			return token_void;
"class"			return token_class;
"false"			return token_false;
"true"			return token_true;

{id}	return token_identifier;


"'"."'"		return token_charLiteral;
{decnumber}	 return token_decLiteral;

"{"				return *yytext;
"}"				return *yytext;
"("				return *yytext;
")"				return *yytext;
";"			    return *yytext;
","			    return *yytext;
"="				return *yytext;
[ \t\n\r]*		;
.				{yyerror("invalid character");}


%%
//"	--ignore this comment
int yywrap(void) { 		
	return 1; 
}

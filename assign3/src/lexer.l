%{
	#include <stdio.h>
	#include <stdlib.h>
%}

ws			[ \t]+
decnumber	[-+]?[0-9]+
id			[a-zA-Z_]([_a-zA-Z0-9]*)?
string		\"([^"\\]|(\\.))*\" 						
nl 			[\n\r]

%x STRING
%x IDENTIFIER
%x SINGLE_COMMENT
%x MULTI_COMMENT

%{
	//" --ignore this comment
	char buf[100]; 
    char *s;
	int lbrace_count=0;
	int rbrace_count=0;
	int lparen_count=0;
	int rparen_count=0;
	int lbrack_count=0;
    int rbrack_count=0;
    int colon_count=0;
    int semi_count=0;
    int comma_count=0;
    int eq_count=0;
	int assign_count=0;
	int not_eq_count=0;
	int not_count=0;
	int plus_plus_count=0;
	int plus_assign_count=0;
	int plus_count=0;
	int minus_minus_count=0;
	int minus_assign_count=0;
	int minus_count=0;
	int cond_or_count=0;
	int bit_or_assign_count=0;
	int cond_and_count=0;
	int bit_and_assign_count=0;
	int bit_and_count=0;
	int bit_or_count=0;
	int shift_left_assign_count=0;
	int shift_left_count=0;
	int less_or_equal_count=0;
	int less_count=0;                  
	int bit_xor_assign_count=0;       
	int bit_xor_count=0;              
	int mul_assign_count=0;           
	int mul_count=0;                  
	int quotient_assign_count=0;      
	int quotient_count=0;             
	int remainder_assign_count=0;     
	int remainder_count=0;            
	int shift_right_assign_count=0;   
	int shift_right_count=0;          
	int greater_or_equal_count=0;     
	int greater_count=0;              
	int dot_count=0;                  
	int apos_count=0;                 
	int quote_count=0;                
	int back_count=0;                 
	int mod_count=0;                  
	int multi_comm_start_count=0;
	int multi_comm_end_count=0;
	int single_comment_count=0;
	int quest_count=0;	
	int telda_count=0;

	int identifier_count=0;
	
	int keyword_ret_count=0;
	int keyword_if_count=0;
	int keyword_else_count=0;
	int keyword_switch_count=0;
	int keyword_break_count=0;
	int keyword_for_count=0;
	int keyword_while_count=0;
	int keyword_print_count=0;
	int keyword_continue_count=0;
	int keyword_class_count=0;
	int keyword_case_count=0;
	int keyword_default_count=0;
	int keyword_true_count=0;
	int keyword_false_count=0;
	int keyword_is_count=0;
	int keyword_endl_count=0;

	int type_int_count=0;
	int type_intarr_count=0;
	int type_char_count=0;
	int type_chararr_count=0;
	int type_bool_count=0;
	int type_boolarr_count=0;
	int type_void_count=0;

	int literal_int_count=0;
	int literal_string_count=0;
	int literal_comment_count=0;
	int literal_char_count=0;
	
%}

%{
	struct IdentifierNode
	{
	  char* data;
	  struct IdentifierNode *next;
	};

	struct LiteralIntNode
	{
	  int data;
	  struct LiteralIntNode *next;
	};

	struct LiteralStringNode
	{
	  char* data;
	  struct LiteralStringNode *next;
	};

	struct LiteralCommentNode
	{
	  char* data;
	  struct LiteralCommentNode *next;
	};

	struct LiteralCharNode
	{
	  char data;
	  struct LiteralCharNode *next;
	};	

	struct IdentifierNode* identifier_head;
	struct LiteralIntNode* literal_int_head;
	struct LiteralStringNode* literal_string_head;
	struct LiteralCharNode* literal_char_head;
	struct LiteralCommentNode* literal_comment_head;

	void pushIdentifierNode(struct IdentifierNode** head_ref, char* data)
	{
	    struct IdentifierNode* new_node = (struct IdentifierNode*) malloc(sizeof(struct IdentifierNode));
	 
	    new_node->data  = strdup(data);
	 
	    new_node->next = (*head_ref);
	 
	    (*head_ref)    = new_node;
	}

	void pushLiteralIntNode(struct LiteralIntNode** head_ref, int data)
	{
	    struct LiteralIntNode* new_node = (struct LiteralIntNode*) malloc(sizeof(struct LiteralIntNode));
	 
	    new_node->data  = data;
	 
	    new_node->next = (*head_ref);
	 
	    (*head_ref)    = new_node;
	}

	void pushLiteralStringNode(struct LiteralStringNode** head_ref, char* data)
	{
	    struct LiteralStringNode* new_node = (struct LiteralStringNode*) malloc(sizeof(struct LiteralStringNode));
	 
	    new_node->data  = strdup(data);
	 
	    new_node->next = (*head_ref);
	 
	    (*head_ref)    = new_node;
	}

	void pushLiteralCommentNode(struct LiteralCommentNode** head_ref, char* data)
	{
	    struct LiteralCommentNode* new_node = (struct LiteralCommentNode*) malloc(sizeof(struct LiteralCommentNode));
	 
	    new_node->data  = strdup(data);
	 
	    new_node->next = (*head_ref);
	 
	    (*head_ref)    = new_node;
	}

	void pushLiteralCharNode(struct LiteralCharNode** head_ref, char data)
	{
	    struct LiteralCharNode* new_node = (struct LiteralCharNode*) malloc(sizeof(struct LiteralCharNode));
	 
	    new_node->data  = data;
	 
	    new_node->next = (*head_ref);
	 
	    (*head_ref)    = new_node;
	}

	void printIdentifierList(struct IdentifierNode *node)
	{
		if(node==NULL)return;
		int first_flag=1;
		while (node != NULL)
		{
			if(first_flag==1){
				printf("%15s \t\t %10d \t\t %10s\n","IDENTIFIER",identifier_count,node->data);
				first_flag--;
			}else
				printf("%15s \t\t %10s \t\t %10s\n","","",node->data);
			node = node->next;
		}
	}

	void printLiteralIntList(struct LiteralIntNode *node)
	{
		if(node==NULL)return;
		int first_flag=1;
		while (node != NULL)
		{
			if(first_flag==1){
				printf("%15s \t\t %10d \t\t %10d\n","INT_CONST",literal_int_count,node->data);
				first_flag--;
			}else
				printf("%15s \t\t %10s \t\t %10d\n","","",node->data);
			node = node->next;
		}
	}

	void printLiteralStringList(struct LiteralStringNode *node)
	{
		if(node==NULL)return;
		int first_flag=1;
		while (node != NULL)
		{
			if(first_flag==1){
				printf("%15s \t\t %10d \t\t %10s\n","STRING",literal_string_count,node->data);
				first_flag--;
			}else
				printf("%15s \t\t %10s \t\t %10s\n","","",node->data);
			node = node->next;
		}
	}

	void printLiteralCommentList(struct LiteralCommentNode *node)
	{
		if(node==NULL)return;
		int first_flag=1;
		while (node != NULL)
		{
			if(first_flag==1){
				printf("%15s \t\t %10d \t\t %10s\n","COMMENT",literal_comment_count,node->data);
				first_flag--;
			}else
				printf("%15s \t\t %10s \t\t %10s\n","","",node->data);
			node = node->next;
		}
	}

	void printLiteralCharList(struct LiteralCharNode *node)
	{
		if(node==NULL)return;
		int first_flag=1;
		while (node != NULL)
		{
			if(first_flag==1){
				printf("%15s \t\t %10d \t\t %10c\n","CHAR_CONST",literal_char_count,node->data);
				first_flag--;
			}else
				printf("%15s \t\t %10s \t\t %10c\n","","",node->data);
			node = node->next;
		}
	}

%}

%%
\"              { BEGIN STRING; s = buf; } 
<STRING>\\n     {   *s++ = '\n';}           
<STRING>\\t     {   *s++ = '\t';}           
<STRING>\\\"    {   *s++ = '\"';}           
<STRING>\"      {  
                    *s = 0;
                    BEGIN 0;
                    literal_string_count++;
                    pushLiteralStringNode(&literal_string_head,buf); 
                }           
<STRING>\n      { printf("invaid string\n"); exit(1);}
<STRING>.       { *s++ = *yytext;}                

"//"			{single_comment_count++ ;BEGIN SINGLE_COMMENT; s=buf;}
"/*"			{multi_comm_start_count++; BEGIN MULTI_COMMENT; s=buf;}
<SINGLE_COMMENT>\n 		{*s = 0;
                    BEGIN 0;
                    literal_comment_count++;
                    pushLiteralCommentNode(&literal_comment_head,buf);
                	}

<SINGLE_COMMENT>.	{*s++ = *yytext;}
<MULTI_COMMENT>"*/"	{multi_comm_end_count++;*s = 0;
                    BEGIN 0;
                    literal_comment_count++;
                    pushLiteralCommentNode(&literal_comment_head,buf);}
<MULTI_COMMENT>[\n\r] {*s++ = '\n';}
<MULTI_COMMENT>.	{*s++ = *yytext;}
"int"			{ type_int_count++; }
"(""int"			{ type_int_count++; }
"int\[\]"		{ type_intarr_count++; }
"char"			{ type_char_count++; }
"char\[\]"		{ type_chararr_count++; }
"bool"			{ type_bool_count++; }
"bool\[\]"		{ type_boolarr_count++; }
"void"			{ type_void_count++; }

"if"			keyword_if_count++;
"return"		keyword_ret_count++;
"else"			keyword_else_count++;
"switch"		keyword_switch_count++;
"break"			keyword_break_count++;
"for"			keyword_for_count++;
"while"			keyword_while_count++;
"class"			keyword_class_count++;
"endl"			keyword_endl_count++;
"is"			keyword_is_count++;
"false"			keyword_false_count++;
"true"			keyword_true_count++;
"default"		keyword_default_count++;
"Print"			keyword_print_count++;
"continue"		keyword_continue_count++;
"case"			keyword_case_count++;
[ \t\n\r]*		;

{decnumber}{id} {printf("Error token: %s\n",yytext);exit(1);}

{id}	{
//	int i=yyleng-1; 	
//	while(yytext[i]==' ' || yytext[i]=='\t' || yytext[i]=='\n' || yytext[i]=='\r' )--i;
//	yytext[i+1]='\0';
								identifier_count++;
						pushIdentifierNode(&identifier_head,yytext);
					}


"'"."'"		{ 	literal_char_count++;
							pushLiteralCharNode(&literal_char_head,yytext[yyleng-2]);
						}
{decnumber}	{	literal_int_count++;
							pushLiteralIntNode(&literal_int_head,atoi(yytext));
						}




"{"				lbrace_count++;
"}"				rbrace_count++;
"("				lparen_count++;
")"				rparen_count++;
"["				lbrack_count++;
"]"			    rbrack_count++;
":"			    colon_count++;
";"			    semi_count++;
","			    comma_count++;
"=="		    eq_count++;
"!="				not_eq_count++;
"!"				not_count++;
"++"				plus_plus_count++;
"+="				plus_assign_count++;
"+"				plus_count++;
"--"				minus_minus_count++;
"-="				minus_assign_count++;
"-"				minus_count++;
"||"				cond_or_count++;
"|="				bit_or_assign_count++;
"&&"				cond_and_count++;
"&="				bit_and_assign_count++;
"&"				bit_and_count++;
"|"				bit_or_count++;
"<<="				shift_left_assign_count++;
"<<"				shift_left_count++;
"<="				less_or_equal_count++;
"<"				less_count++;                  
"^="				bit_xor_assign_count++;       
"^"				bit_xor_count++;              
"*="				mul_assign_count++;           
"*"				mul_count++;                  
"/="				quotient_assign_count++;      
"/"				quotient_count++;             
"%="				remainder_assign_count++;     
"%"				remainder_count++;            
">>="				shift_right_assign_count++;   
">>"				shift_right_count++;          
">="				greater_or_equal_count++;     
">"				greater_count++;              
"."				dot_count++;               
"?"				quest_count++;	
"~"				telda_count++;
"="				assign_count++;
.				{printf("Error token: %s\n",yytext);}


%%
//"	--ignore this comment
int yywrap(void) { 
	printf("%15s \t\t %15s \t %13s\n","Token","Occurrances","Lexemes");
	printf("-----------------------------------------------------------------------\n");
	printLiteralStringList(literal_string_head);	
	printLiteralCommentList(literal_comment_head);	
	printIdentifierList(identifier_head);	
	printLiteralIntList(literal_int_head);
	printLiteralCharList(literal_char_head);

	if(type_int_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_INT",type_int_count,"int");
	if(type_intarr_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_INT_ARR",type_intarr_count,"int[]");
	if(type_char_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_CHAR",type_char_count,"char");
	if(type_chararr_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_CHAR_ARR",type_chararr_count,"char[]");
	if(type_bool_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_BOOL",type_bool_count,"bool");
	if(type_boolarr_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_BOOL_ARR",type_boolarr_count,"bool[]");
	if(type_void_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TYPE_VOID",type_void_count,"void");

	if(keyword_ret_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","RETURN",keyword_ret_count,"return");
	if(keyword_if_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","IF",keyword_if_count,"if");
	if(keyword_else_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","ELSE",keyword_else_count,"else");
	if(keyword_switch_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","SWITCH",keyword_switch_count,"switch");
	if(keyword_break_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","BREAK",keyword_break_count,"break");
	if(keyword_for_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","FOR",keyword_for_count,"for");
	if(keyword_while_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","WHILE",keyword_while_count,"while");
	if(keyword_print_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","PRINT",keyword_print_count,"Print");
	if(keyword_continue_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","CONTINUE",keyword_continue_count,"continue");
	if(keyword_class_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","CLASS",keyword_class_count,"class");
	if(keyword_case_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","CASE",keyword_case_count,"case");
	if(keyword_default_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","DEFAULT",keyword_default_count,"default");
	if(keyword_true_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","TRUE",keyword_true_count,"true");
	if(keyword_false_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","FALSE",keyword_false_count,"false");
	if(keyword_is_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_IS",keyword_is_count,"is");
	if(keyword_endl_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","ENDL",keyword_endl_count,"endl");
	
	if(lbrace_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","BLOCK_BEGIN",lbrace_count,"{");
	if(rbrace_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","BLOCK_END",rbrace_count,"}");
	if(lparen_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","LPAREN",lparen_count,"(");
	if(rparen_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","RPAREN",rparen_count,")");
	if(lbrack_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","LBRACK",lbrack_count,"[");
    if(rbrack_count>0)
    	printf("%15s \t\t %10d \t\t %10s\n","RBRACK",rbrack_count,"]");
    if(colon_count>0)
    	printf("%15s \t\t %10d \t\t %10s\n","COLON",colon_count,":");
    if(semi_count>0)
    	printf("%15s \t\t %10d \t\t %10s\n","SEMI_COLON",semi_count,";");
    if(comma_count>0)
    	printf("%15s \t\t %10d \t\t %10s\n","COMMA",comma_count,",");
    if(eq_count>0)
    	printf("%15s \t\t %10d \t\t %10s\n","OP_EQ",eq_count,"==");
	if(assign_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_ASSIGN",assign_count,"=");
	if(not_eq_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_NOT_EQ",not_eq_count,"!=");
	if(not_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_NOT",not_count,"!");
	if(plus_plus_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_PLUS_PLUS",plus_plus_count,"++");
	if(plus_assign_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_PLUS_ASSIGN",plus_assign_count,"+=");
	if(plus_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_PLUS",plus_count,"+");
	if(minus_minus_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_MINUS_MINUS",minus_minus_count,"--");
	if(minus_assign_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_MINUS_ASSIGN",minus_assign_count,"-=");
	if(minus_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_MINUS",minus_count,"-");
	if(cond_or_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_COND_OR",cond_or_count,"||");
	if(bit_or_assign_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_BIT_OR_ASSIGN",bit_or_assign_count,"|=");
	if(cond_and_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_COND_AND",cond_and_count,"&&");
	if(bit_and_assign_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_BIT_AND_ASSIGN",bit_and_assign_count,"&=");
	if(bit_and_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_BIT_AND",bit_and_count,"&");
	if(bit_or_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_BIT_OR",bit_or_count,"|");
	if(shift_left_assign_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_SHIFT_LEFT_ASSIGN",shift_left_assign_count,"<<=");
	if(shift_left_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_SHIFT_LEFT",shift_left_count,"<<");
	if(less_or_equal_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_LESS_EQUAL",less_or_equal_count,"<=");
	if(less_count>0)                  
		printf("%15s \t\t %10d \t\t %10s\n","OP_LESS",less_count,"<");
	if(bit_xor_assign_count>0)       
		printf("%15s \t\t %10d \t\t %10s\n","OP_XOR_ASSIGN",bit_xor_assign_count,"^=");
	if(bit_xor_count>0)              
		printf("%15s \t\t %10d \t\t %10s\n","OP_XOR",bit_xor_count,"^");
	if(mul_assign_count>0)           
		printf("%15s \t\t %10d \t\t %10s\n","OP_MUL_ASSIGN",mul_assign_count,"*=");
	if(mul_count>0)                  
		printf("%15s \t\t %10d \t\t %10s\n","OP_MUL",mul_count,"*");
	if(quotient_assign_count>0)      
		printf("%15s \t\t %10d \t\t %10s\n","OP_QUOTIENT_ASSIGN",quotient_assign_count,"/=");
	if(quotient_count>0)             
		printf("%15s \t\t %10d \t\t %10s\n","OP_QUOTIENT",quotient_count,"/");
	if(remainder_assign_count>0)     
		printf("%15s \t\t %10d \t\t %10s\n","OP_REMAINDER_ASSIGN",remainder_assign_count,"%%=");
	if(remainder_count>0)            
		printf("%15s \t\t %10d \t\t %10s\n","OP_REMAINDER",remainder_count,"%%");
	if(shift_right_assign_count>0)   
		printf("%15s \t\t %10d \t\t %10s\n","OP_SHIFT_RIGHT_ASSIGN",shift_right_assign_count,">>=");
	if(shift_right_count>0)          
		printf("%15s \t\t %10d \t\t %10s\n","OP_SHIFT_RIGHT",shift_right_count,">>");
	if(greater_or_equal_count>0)     
		printf("%15s \t\t %10d \t\t %10s\n","OP_GREATER_EQUAL",greater_or_equal_count,">=");
	if(greater_count>0)              
		printf("%15s \t\t %10d \t\t %10s\n","OP_GREATER",greater_count,">");
	if(dot_count>0)                  
		printf("%15s \t\t %10d \t\t %10s\n","OP_DOT",dot_count,".");
	if(multi_comm_start_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","MULTI_COMM_START",multi_comm_start_count,"/*");
	if(multi_comm_end_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","MULTI_COMM_END",multi_comm_end_count,"*/");
	if(single_comment_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","SINGLE_COMM",single_comment_count,"//");
	if(quest_count>0)	
		printf("%15s \t\t %10d \t\t %10s\n","OP_QUEST",quest_count,"?");
	if(telda_count>0)
		printf("%15s \t\t %10d \t\t %10s\n","OP_TELDA",telda_count,"~");
		
	return 1; 
}

int main(int argc, char *argv[]) {
    yyin = fopen(argv[1], "r"); 
    yylex(); 
    fclose(yyin);  
	return 0; 
}

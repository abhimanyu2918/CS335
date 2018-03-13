lexer:	./src/lexer.l
	mkdir ./bin && lex -o ./bin/lex.yy.c ./src/lexer.l  && gcc ./bin/lex.yy.c -o ./bin/lexer && rm ./bin/lex.yy.c

clean:	
	rm -r ./bin 

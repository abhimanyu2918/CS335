comiler:	parser ./src/codegen.c
	gcc -o ./bin/compiler ./src/codegen.c ./bin/lex.yy.c ./bin/y.tab.c -O3; rm ./bin/lex.yy.c; rm ./bin/y.tab.c; rm ./bin/y.tab.h
	
parser: ./bin/lex.yy.c ./bin/y.tab.c
	# gcc ./bin/lex.yy.c ./bin/y.tab.c -o ./bin/parser; rm ./bin/lex.yy.c; rm ./bin/y.tab.h; rm ./bin/y.tab.c
./bin/lex.yy.c:	./src/lexer.l
	lex -o ./bin/lex.yy.c ./src/lexer.l
	
./bin/y.tab.c: ./src/parser.y
	yacc -d ./src/parser.y; mv y.tab.c ./bin/; mv y.tab.h ./bin/

clean:	
	rm -r ./bin/*


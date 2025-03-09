%{
	#include <stdio.h>
	#include <stdlib.h>
	#include "IR.h"
	
	extern int yyparse();
	extern int yylex();
	extern FILE *yyin;
	

	
	//#define DEBUGBISON
	//This code is for producing debug output.
	#ifdef DEBUGBISON
		#define debugBison(a) (printf("\n%d \n",a))
	#else
		#define debugBison(a)
	#endif
%}

%union {
	char *identifier;
	double double_literal;
	char *string_literal;
	llvm::Value* value; 
}

%token tok_printd
%token tok_prints
%token <identifier> tok_identifier
%token <double_literal> tok_double_literal
%token <string_literal> tok_string_literal

%type <value> term expression

%left '+' '-' 
%left '*' '/'
%left '(' ')'

%start root

%%

root:	/* empty */				{debugBison(1); addReturnInstr();}  	
	| prints  root				{debugBison(2);}
	| printd  root				{debugBison(3);}
	| assignment  root			{debugBison(4);}
	; 

prints:	tok_prints '(' tok_string_literal ')' ';'   {debugBison(5); printString($3); } 
	;

printd:	tok_printd '(' term ')' ';'		{debugBison(6); printDouble($3); }
	;

term:	tok_identifier				{debugBison(7); Value* ptr = getFromSymbolTable($1); $$ = builder.CreateLoad(builder.getDoubleTy(), ptr, "load_identifier"); free($1);}
	| tok_double_literal			{debugBison(8); $$ = createDoubleConstant($1);}
	;

assignment:  tok_identifier '=' expression ';'	{debugBison(9); setDouble($1, $3); free($1);}
	;

expression: term				{debugBison(10); $$= $1;}
	   | expression '+' expression		{debugBison(11); $$=performBinaryOperation($1, $3, '+');}
	   | expression '-' expression		{debugBison(12); $$=performBinaryOperation($1, $3, '-');}
	   | expression '/' expression		{debugBison(13); $$=performBinaryOperation($1, $3, '/');}
	   | expression '*' expression		{debugBison(14); $$=performBinaryOperation($1, $3, '*');}
	   | '(' expression ')'			{debugBison(15); $$= $2;}
	   ;	   
	      
	   

%%



int main(int argc, char** argv) {
	if (argc > 1) {
		FILE *fp = fopen(argv[1], "r");
		yyin = fp; //read from file when its name is provided.
	} 
	if (yyin == NULL) { 
		yyin = stdin; //otherwise read from terminal
	}
	
	//Function that initialize LLVM
	initLLVM();
	
	//yyparse will call internally yylex
	//It will get a token and insert it into AST
	int parserResult = yyparse();
		
	//print LLVM IR
	printLLVMIR();
	
	return EXIT_SUCCESS;
}


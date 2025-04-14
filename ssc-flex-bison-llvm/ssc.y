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
%token tok_if
%token tok_else
%token <identifier> tok_identifier
%token <double_literal> tok_double_literal
%token <string_literal> tok_string_literal

%type <value> term expression comparison

%left '+' '-' 
%left '*' '/'
%left GT LT EQ
%left '(' ')'

%start root

%%

root:	/* empty */				{ debugBison(1); addReturnInstr(); }  	
	| prints root				{ debugBison(2); }
	| printd root				{ debugBison(3); }
	| assignment root			{ debugBison(4); }
	| if_else root				{ debugBison(16); }
	; 

prints:	tok_prints '(' tok_string_literal ')' ';'   { debugBison(5); printString($3); } 
	;

printd:	tok_printd '(' term ')' ';'		{ debugBison(6); printDouble($3); }
	;

term:	tok_identifier				{ debugBison(7); Value* ptr = getFromSymbolTable($1); $$ = builder.CreateLoad(builder.getDoubleTy(), ptr, "load_identifier"); free($1); }
	| tok_double_literal			{ debugBison(8); $$ = createDoubleConstant($1); }
	;

assignment: tok_identifier '=' expression ';'	{ debugBison(9); setDouble($1, $3); free($1); }
	;

expression: term				{ debugBison(10); $$ = $1; }
	   | expression '+' expression		{ debugBison(11); $$ = performBinaryOperation($1, $3, '+'); }
	   | expression '-' expression		{ debugBison(12); $$ = performBinaryOperation($1, $3, '-'); }
	   | expression '/' expression		{ debugBison(13); $$ = performBinaryOperation($1, $3, '/'); }
	   | expression '*' expression		{ debugBison(14); $$ = performBinaryOperation($1, $3, '*'); }
	   | '(' expression ')'			{ debugBison(15); $$ = $2; }
	   ;	   

comparison: expression GT expression		{ debugBison(17); $$ = builder.CreateFCmpUGT($1, $3, "cmpgt"); }
	   | expression LT expression		{ debugBison(18); $$ = builder.CreateFCmpULT($1, $3, "cmplt"); }
	   | expression EQ expression		{ debugBison(19); $$ = builder.CreateFCmpUEQ($1, $3, "cmpeq"); }
	   ;

if_else: tok_if '(' comparison ')' '{' root '}'		{
		debugBison(20);
		BasicBlock *thenBB = BasicBlock::Create(context, "then", mainFunction);
		//BasicBlock *elseBB = BasicBlock::Create(context, "else");
		BasicBlock *mergeBB = BasicBlock::Create(context, "ifcont");
		
		builder.CreateCondBr($3, thenBB, mergeBB);
		
		// Emit then block
		builder.SetInsertPoint(thenBB);
		// Code for then block is in $6
		builder.CreateBr(mergeBB);
		
		// Emit merge block
		mainFunction->getBasicBlockList().push_back(mergeBB);
		builder.SetInsertPoint(mergeBB);
	}
	| tok_if '(' comparison ')' '{' root '}' tok_else '{' root '}'	{
		debugBison(21);
		BasicBlock *thenBB = BasicBlock::Create(context, "then", mainFunction);
		BasicBlock *elseBB = BasicBlock::Create(context, "else");
		BasicBlock *mergeBB = BasicBlock::Create(context, "ifcont");
		
		builder.CreateCondBr($3, thenBB, elseBB);
		
		// Emit then block
		builder.SetInsertPoint(thenBB);
		// Code for then block is in $6
		builder.CreateBr(mergeBB);
		thenBB = builder.GetInsertBlock();
		
		// Emit else block
		mainFunction->getBasicBlockList().push_back(elseBB);
		builder.SetInsertPoint(elseBB);
		// Code for else block is in $10
		builder.CreateBr(mergeBB);
				
		// Emit merge block
		mainFunction->getBasicBlockList().push_back(mergeBB);
		builder.SetInsertPoint(mergeBB);
	}
	;

%%

int main(int argc, char** argv) {
    if (argc > 1) {
        FILE *fp = fopen(argv[1], "r");
        yyin = fp;
    } 
    if (yyin == NULL) { 
        yyin = stdin;
    }
    
    initLLVM();
    int parserResult = yyparse();
    printLLVMIR();
    
    return EXIT_SUCCESS;
}
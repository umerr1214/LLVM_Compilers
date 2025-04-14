#include <string>
#include <map>
#include <stdio.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/BasicBlock.h>
#include <llvm/IR/Value.h>
#include <llvm/Support/raw_ostream.h>

using namespace llvm;

Value* getFromSymbolTable(const char *id);
void setDouble(const char *id, Value* value);
void printString(const char *str);
void printDouble(Value* value);
Value* performBinaryOperation(Value* lhs, Value* rhs, int op);
void yyerror(const char *err);
static void initLLVM();
void printLLVMIR();
void addReturnInstr();
Value* createDoubleConstant(double val);



static std::map<std::string, Value *> SymbolTable;

static LLVMContext context;
static Module *module = nullptr;
static IRBuilder<> builder(context);
static Function *mainFunction = nullptr;


/**
* init LLVM
* Create main function (similar to C-main) that returns a int but takes no parameters.
*/
static void initLLVM() {
	module = new Module("top", context);
	//returns an int and has fixed number of parameters. Do not take any parameters.
	FunctionType *mainTy = FunctionType::get(builder.getInt32Ty(), false);
	//the main function definition.
	mainFunction = Function::Create(mainTy, Function::ExternalLinkage, "main", module);
	//Create entry basic block of the main function.
	BasicBlock *entry = BasicBlock::Create(context, "entry", mainFunction);
	//Tell builder that instruction to be added in this basic block.
	builder.SetInsertPoint(entry);
}

void addReturnInstr() {
	builder.CreateRet(ConstantInt::get(context, APInt(32, 0)));
}


Value* createDoubleConstant(double val) {
	return ConstantFP::get(context, APFloat(val));

}

void printLLVMIR() {
	module->print(errs(), nullptr);
}

Value* getFromSymbolTable(const char *id) {
	std::string name(id);
	if(SymbolTable.find(name) != SymbolTable.end()) {
		return SymbolTable[name];
	} else {
		Value* defaultValue = builder.CreateAlloca(builder.getDoubleTy(), nullptr, name);
		SymbolTable[name] = defaultValue;
		return defaultValue;
	}
}


void setDouble(const char *id, Value* value) {
	Value *ptr = getFromSymbolTable(id);
	builder.CreateStore(value, ptr);
}

/**
* This is a general LLVM function to print a value in given format.
*/
void printfLLVM(const char *format, Value *inputValue) {
	//check if printf function already exist
	Function *printfFunc = module->getFunction("printf");
	//if it does not exist then create it.
	if(!printfFunc) {
		//The printf function returns integer.
		//It takes variable number of paramters.
		FunctionType *printfTy = FunctionType::get(builder.getInt32Ty(), PointerType::get(builder.getInt8Ty(), 0), true);
		printfFunc = Function::Create(printfTy, Function::ExternalLinkage, "printf", module); // function is created.
	}
	//create global string pointer for format.
	Value *formatVal = builder.CreateGlobalStringPtr(format);
	//Call the printf function using Call LLVM instruction
	builder.CreateCall(printfFunc, {formatVal, inputValue}, "printfCall");
}

void printString(const char *str) {
	//printf("%s\n", str);
	Value *strValue = builder.CreateGlobalStringPtr(str);
	printfLLVM("%s\n", strValue);
}

void printDouble(Value *value) {
	//printf("%f\n", value);
	printfLLVM("%f\n", value); 
}

Value* performBinaryOperation(Value* lhs, Value* rhs, int op) {
    switch (op) {
        case '+': return builder.CreateFAdd(lhs, rhs, "fadd");
        case '-': return builder.CreateFSub(lhs, rhs, "fsub");
        case '*': return builder.CreateFMul(lhs, rhs, "fmul");
        case '/': return builder.CreateFDiv(lhs, rhs, "fdiv");
        case '>': return builder.CreateFCmpUGT(lhs, rhs, "cmpgt");
        case '<': return builder.CreateFCmpULT(lhs, rhs, "cmplt");
        //case '==': return builder.CreateFCmpUEQ(lhs, rhs, "cmpeq");
        default: yyerror("illegal binary operation"); exit(EXIT_FAILURE);
    }
}

void yyerror(const char *err) {
	fprintf(stderr, "\n%s\n", err);
}


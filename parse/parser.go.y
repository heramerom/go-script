%{
package parse

import "github.com/heramerom/go-script/ast"
%}

%type<expr> expr
%type<stmts>  chunk
%type<stmts>  chunk1
%type<stmt> laststat
%type<stmt>  stat
%type<stmts> block
%type<exprlist> varlist
%type<exprlist> exprlist
%type<expr> prefixexp
%type<nameList> namelist
%type<funcName> funcname
%type<funcExpr> funcbody
%type<expr> functioncall
%type<stmts> elseifs
%type<funcName> funcname1
%type<expr> string
%type<expr> var
%type<funcExpr> afunctioncall
%type<exprlist> args
%type<expr> function
%type<parList> parlist
%type<expr> mapcontructor
%type<fieldList> mapfieldlist
%type<field> mapfield
%type<expr> slicecontructor
%type<exprlist> exprlist
%type<expr> case
%type<exprlist> caselist
%type<expr> chanexpr

%union {
    token ast.Token
    stmts []ast.Stmt
    stmt ast.Stmt
    funcName *ast.FuncName
    funcExpr *ast.FuncExpr

    exprlist []ast.Expr
    expr ast.Expr

    fieldList []*ast.Field
    field  *ast.Field
    fieldsep  string

    nameList []string
    parList *ast.ParList
}


%token<token> And Or Break Go If Else ElseIf False True For Func Range Nil Return Var FallThrough Defer Continue Select Case Default

%token<token> Eq Neq Lte Gte Ident Number String Dot3 ChanOp QuickVar '{' '[' ']' '}' '(' ')'

%left Or
%left And
%left '|'
%left '^'
%left '&'
%left ShiftLeft ShiftRight
%left '<' '>' Gte Lte Eq Neq
%left '+' '-'
%left '*' '/' '%'
%left UNARY
%left ChanOp

%%

chunk:
    chunk1 {
        $$ = $1
    } |
    chunk1 laststat {
        $$ = append($1, $2)
        if l, ok := yylex.(*Lexer); ok {
            l.Stmts = $$
        }
    } |
    chunk1 laststat ';' {
        $$ = append($1, $2)
        if l, ok := yylex.(*Lexer); ok {
            l.Stmts = $$
        }
    }


chunk1:
    {
        $$ = []ast.Stmt{}
    } |
    chunk1 stat {
        $$ = append($1, $2)
    } |
    chunk1 ';' {
        $$ = $1
    }

block:
    chunk {
        $$ = $1
    }

stat:
    varlist '=' exprlist {
        $$ = &ast.AssignStmt{Vars: $1, Exprs: $3}
        $$.SetLine($1[0].Line())
    } |
    prefixexp {
        if _, ok := $1.(*ast.FuncExpr); !ok {
            yylex.(*Lexer).Error("parse error")
        } else {
            $$ = &ast.FuncCallStmt{Expr: $1}
        }
    } |
    If expr '{' block '}' elseifs {
        $$ = &ast.IfStmt{Condition: $2, Then: $4}
        cur:= $$
        for _, elf := range $6 {
            cur.(*ast.IfStmt).Else = []ast.Stmt{elf}
            cur = elf
        }
    } |
    If expr '{' block '}' elseifs Else '{' block '}' {
        $$ = &ast.IfStmt{Condition: $2, Then: $4}
        cur:= $$
        for _, elf := range $6 {
            cur.(*ast.IfStmt).Else = []ast.Stmt{elf}
            cur = elf
        }
        cur.(*ast.IfStmt).Else = $9
    } |
    For '{' block '}' {
        $$ = &ast.ForStmt{Stmts: $3}
        $$.SetLine($1.Position.Line)
    } |
    For namelist '=' Range expr '{' block '}' {
        $$ = &ast.ForRangeStmt{Stmts: $7, Names: $2, Expr: $5}
        $$.SetLine($1.Line())
    } |
    For namelist '=' exprlist ';' expr ';' exprlist '{' block '}' {
        $$ = &ast.ForStmt{Stmts: $10, Names: $2, Init: $4, Limit: $6, Step: $8 }
        $$.SetLine($1.Position.Line)
    } |
    Func funcname funcbody {
        $$ = &ast.FuncDefStmt{Name: $2, Func: $3}
        $$.SetLine($1.Position.Line)
    } |
    Var namelist '=' exprlist {
        $$ = &ast.AssignStmt{Names: $2, Exprs: $4}
        $$.SetLine($1.Line())
    } |
    Var namelist {
        $$ = &ast.AssignStmt{Names: $2, Exprs: []ast.Expr{}}
        $$.SetLine($1.Line())
    } |
    Go functioncall {
        $$ = &ast.GoStmt{Expr: $2}
        $$.SetLine($1.Line())
    } |
    Defer functioncall {
        $$ = &ast.DeferStmt{Expr: $2}
        $$.SetLine($1.Line())
    } |
    Select '{' caselist  '}' {
        $$ = &ast.SelectStmt{Cases: $3}
        $$.SetLine($1.Line())
    }


caselist:
    case {
        $$ = []ast.Expr{$1}
    } |
    caselist case {
        $$ = append($1, $2)
    }

case:
    Case chanexpr ':' block {
        $$ = &ast.CaseExpr{Chan: $2, Stmts: $4, Default: false}
        $$.SetLine($1.Line())
    } |
    Case namelist '=' chanexpr ':' block {
        $$ = &ast.CaseExpr{Names: $2, Chan: $4, Stmts: $6, Default: false}
        $$.SetLine($1.Line())
    } |
    Default ':' block {
        $$ = &ast.CaseExpr{Stmts: $3}
        $$.SetLine($1.Line())
    }

elseifs: 
    {
        $$ = []ast.Stmt{}
    } |
    elseifs ElseIf expr '{' block '}' {
        $$ = append($1, &ast.IfStmt{Condition: $3, Then: $5})
    }

laststat:
    Return {
        $$ = &ast.ReturnStmt{Exprs: nil}
        $$.SetLine($1.Line())
    } |
    Return exprlist {
        $$ = &ast.ReturnStmt{Exprs: $2}
        $$.SetLine($1.Line())
    } |
    Break {
        $$ = &ast.BreakStmt{}
        $$.SetLine($1.Line())
    } | 
    Continue {
        $$ = &ast.ContinueStmt{}
        $$.SetLine($1.Line())
    }

funcname:
    funcname1 {
        $$ = $1
    } | 
    funcname1 '.' Ident {
        $$= &ast.FuncName{Func: nil, Receiver: $1.Func, Method: $3.Value}
    }


funcname1:
    Ident {
        $$ = &ast.FuncName{Method: $1.Value}
    } |
    funcname1 '.' Ident {
        $$ = &ast.FuncName{Func: nil, Receiver: $1.Func, Method: $3.Value}
    }


expr:
    Nil {
        $$ = &ast.NilExpr{}
        $$.SetLine($1.Line())
    } |
    Number {
        $$ = &ast.NumberExpr{Value: $1.Value}
        $$.SetLine($1.Line())
    } |
    True {
        $$ = &ast.TrueExpr{}
        $$.SetLine($1.Line())
    } |
    False {
        $$ = &ast.FalseExpr{}
        $$.SetLine($1.Line())
    } |
    functioncall {
        $$ = &ast.FuncCallExpr{}
    } |
    function {
        $$ = $1
    } |
    string {
        $$ = $1
    } |
    expr Or expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "or", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr And expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "and", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr Gte expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: ">=", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr '>' expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: ">", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr Lte expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "<=", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr '<' expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "<", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr Eq expr {
        $$= &ast.LogicalOpExpr{Lhs: $1, Operator: "==", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr Neq expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "!=", Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr '+' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"+", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr '-' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"-", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
     } |
    expr '*' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"*", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
     } |
    expr '/' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"/", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
     } |
    expr '%' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"%", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
     } |
    expr '^' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"^", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
     } |
    expr '|' expr {
        $$ = &ast.ArithmeticOpExpr{Op: "|", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
    } |
    expr '&' expr {
        $$ = &ast.ArithmeticOpExpr{Op: "&", Lhs: $1, Rhs: $3}
        $$.SetLine($1.Line())
    } |
    slicecontructor {
        $$ = $1
    } |
    mapcontructor {
        $$ = $1
    } |
    chanexpr {
        $$ = $1
    }

chanexpr:
    ChanOp expr {
        $$ = &ast.ChanSendExpr{Ch: $2}
        $$.SetLine($1.Line())
    } |
    expr ChanOp {
        $$ = &ast.ChanReceiveExpr{Ch: $1}
        $$.SetLine($1.Line())
    }

string:
    String {
        $$ = &ast.StringExpr{Value: $1.Value}
        $$.SetLine($1.Line())
    }

varlist:
    var {
        $$ = []ast.Expr{$1}
    } |
    varlist ',' var {
        $$ = append($1, $3)
    }

var:
    Ident {
        $$ = &ast.IdentExpr{Value: $1.Value}
        $$.SetLine($1.Line())
    } |
    prefixexp '[' expr ']' {
        $$ = &ast.AttrGetExpr{Object: $1, Key: $3}
    } |
    prefixexp '.' Ident {
        key:=&ast.StringExpr{Value: $3.Value}
        $$ = &ast.AttrGetExpr{Object: $1, Key: key}
    }

prefixexp:
    var {
        $$ = $1
    } |
    afunctioncall {
        $$ = $1
    } |
    functioncall {
        $$ = $1
    } |
    '(' expr ')' {
        $$ = $2
    }

afunctioncall:
    '(' functioncall ')' {
        $2.(*ast.FuncCallExpr).AdjustRet = true
    }

functioncall:
    prefixexp args {
        $$ = &ast.FuncCallExpr{Func: $1, Args: $2}
    } |
    prefixexp '.' Ident args {
        $$ = &ast.FuncCallExpr{Method: $3.Value, Receiver: $1, Args: $4}
    }

args:
    '(' ')' {
        $$ = []ast.Expr{}
    } |
    '(' exprlist ')' {
        $$ = $2
    }

function:
    Func funcbody {
        $$ = &ast.FuncExpr{ParList:$2.ParList, Stmts: $2.Stmts}
    }

funcbody:
    '(' ')' '{' block '}' {
        $$ = &ast.FuncExpr{Stmts: $4}
    } |
    '(' parlist ')' '{'  block '}' {
        $$ = &ast.FuncExpr{Stmts: $5, ParList: $2}
    }

parlist:
    namelist {
        $$ = &ast.ParList{HasVargs: false}
        $$.Names = append($$.Names, $1...)
    } |
    namelist ',' Ident Dot3 {
        $$ = &ast.ParList{HasVargs: true}
        $$.Names = append($$.Names, $1...)
    }


namelist:
    Ident {
        $$ = []string{$1.Value}
    } |
    namelist ',' Ident {
        $$ = append($1, $3.Value)
    }

mapcontructor:
    '{' '}' {
        $$ = &ast.MapExpr{}
        $$.SetLine($1.Line())
    } |
    '{' mapfieldlist '}' {
        $$ = &ast.MapExpr{Fields: $2}
        $$.SetLine($1.Line())
    }

mapfieldlist:
    mapfield {
        $$ = []*ast.Field{$1}
    } |
    mapfieldlist ',' mapfield {
        $$ = append($1, $3)
    }


mapfield:
    expr ':' expr {
        $$ = &ast.Field{Key: $1, Value: $3}
    }

slicecontructor:
    '[' ']' {
        $$ = &ast.SliceExpr{}
        $$.SetLine($1.Line())
    } |
    '[' exprlist ']' {
        $$ = &ast.SliceExpr{Values: $2}
        $$.SetLine($1.Line())
    }

exprlist:
    expr {
        $$ = []ast.Expr{$1}
    } |
    exprlist ',' expr {
        $$ = append($1, $3)
    }


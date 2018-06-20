%{
package parse
%}


%type<expr> expr

%union {
    token ast.Token
    stmts []ast.Stmt
    stmt ast.Stmt
    funcName *ast.FuncName
    funcExpr *ast.FuncExpr

    exprList []ast.Expr
    expr ast.Expr

    fieldList []*ast.Field
    field  *ast.Field
    fieldsep  string

    nameList []string
    parList *ast.Parlist
}


%token<token> And Or Break Go If Else ElseIf False True For Func Range Nil Return Var FallThrough Defer Continue

%token<token> Eq Neq Lte Gte Ident Number String '{' '['

%left And
%left Or
%left '<' '>' Gte Lte Eq Neq
%left '+' '-'
%left '*' '/' '%'
%left UNARY
%right '^'

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
        $$ = &ast.AssignStmt{Lhs: $1, Rhs: $3}
    } |
    prefixexp {
        if _, ok := $1.(*ast.FuncExpr); !ok {
            yylex.(*Lexer).Error("parse error")
        } else {
            $$ = &ast.ExprCallStmt{Expr: $1}
        }
    } |
    If expr '{' block '}' elseifs {
        $$ = &ast.IfStmt{Condition: $2, Then: $4}
        cur:= $$
        for _, elf := range $5 {
            cur.(*ast.IfStmt).Else = []ast.Stmt{elf}
            cur = elseif
        }
    }|
    If expr '{' block '}' elseifs else '{' block '}' {
        $$ = &ast.IfStmt{Condition: $2, Then: $4}
        cur:= $$
        for _, elf := range $5 {
            cur.(*ast.IfStmt).Else = []ast.Stmt{elf}
            cur = elseif
        }
        cur.(*ast.IfStmt).Else = $7       
    } |
    /* todo: for range*/
    For '{' block '}' {
        $$ = &ast.ForStmt{Stmts: $3}
    } |
    For namelist '=' Range expr '{' block '}' {
        $$ = &ast.ForRangeStmt{Stmts: $7, Names: $2, Expr: $5}
    } |
    For Var namelist '=' Range expr '{' block '}' {
        $$ = &ast.ForRangeStmt{Stmts: $8, Names: $3, Expr: $6}
    } |
    Func funcname funcbody {
        $$ = &ast.FuncDefStmt{Name: $2, Func: $3}
    } |
    Var Func Ident funcbody {
        $$ = &ast.AssignStmt{Names: []string{$3.Str}, Exprs: []*ast.Expr{$4}}
    } |
    Var namelist '=' exprlist {
        $$ = &ast.AssignStmt{Names: $2, Exprs: $4}
    } |
    Var namelist {
        $$ = &ast.AssignStmt{Names: $2, Exprs: []*ast.Expr{}}
    } |
    Go functioncall {
        $$ = &ast.GoStmt{Expr: $2}
    } |
    Defer functioncall {
        $$ = &ast.DeferStmt{Expr: $2}
    }



elseifs: 
    {
        $$ = []ast.Stmt{}
    } |
    elseifs ElseIf expr '{' block '}' {
        $$ = append{$1, &ast.IfStmt{Condition: $3, Then: $5}}
    }

laststat:
    Return {
        $$ = &ast.ReturnStmt{Exprs: nil}
    } |
    Return exprlist {
        $$ = &ast.ReturnStmt{Exprs: $2}
    } |
    Break {
        $$ = &ast.BreakStmt{}
    } | 
    Continue {
        $$ = &ast.ContinueStmt{}
    }

funcname:
    funcname1 {
        $$ = $1
    } | 
    funcname1 '.' Ident {
        $$= &ast.FuncName{Func: nil, Receiver: $1.Func, Method: $3.Str}
    }


funcname1:
    Ident {
        $$ = $1
    } |
    funcname1 '.' Ident {
        $$ = &ast.FuncName{Func: nil, Receiver: $1.Func, Method: $3.Str}
    }


expr:
    Nil {
        $$ = &ast.NilExpr{}
    } |
    Number {
        $$ = &ast.NumberExpr{Value: $1}
    } |
    String {
        $$ = &ast.StringExpr{Value: $1}
    } |
    True {
        $$ = &ast.TrueExpr{}
    } |
    False {
        $$ = &ast.FalseExpr{}
    } |
    functioncall {
        $$ = &ast.FunctionCallExpr{}
    } |
    expr Or expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "or", Rhs: $3}
    } |
    expr And expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "and", Rhs: $3}
    } |
    expr Gte expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: ">=", Rhs: $3}
    } |
    expr '>' expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: ">", Rhs: $3}
    } |
    expr Lte expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "<=", Rhs: $3}
    } |
    expr '<' expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "<", Rhs: $3}
    } |
    expr Eq expr {
        $$= &ast.LogicalOpExpr{Lhs: $1, Operator: "==", Rhs: $3}
    } |
    expr Neq expr {
        $$ = &ast.LogicalOpExpr{Lhs: $1, Operator: "!=", Rhs: $3}
    } |
    expr '+' expr {
        $$ = &ast.ArithmeticOpExpr{Op:"+", Lhs: $1, Rhs: $3}
    } |
    expr '-' expr {
         $$ = &ast.ArithmeticOpExpr{Op:"-", Lhs: $1, Rhs: $3}
     } |
    expr '*' expr {
         $$ = &ast.ArithmeticOpExpr{Op:"*", Lhs: $1, Rhs: $3}
     } |
    expr '/' expr {
         $$ = &ast.ArithmeticOpExpr{Op:"/", Lhs: $1, Rhs: $3}
     } |
    expr '%' expr {
         $$ = &ast.ArithmeticOpExpr{Op:"%", Lhs: $1, Rhs: $3}
     } |
    expr '^' expr {
         $$ = &ast.ArithmeticOpExpr{Op:"^", Lhs: $1, Rhs: $3}
     }

string:
    String {
        $$ = &ast.StringExpr{Value: $1.Str}
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
        $$ = &ast.IdentExpr{Value: $1.Str}
        $$.SetLine($1.Pos.Line)
    } |
    prefixexp '[' expr ']' {
        $$ = &ast.AttrGetExpr{Object: $1, Key: $3}
    } |
    prefixexp '.' Ident {
        key:=&ast.StringExpr{Value: $3.Str}
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
        $2.(*ast.FunctionCallExpr).AjustRet = ture
    }

functioncall:
    prefixexp args {
        $$ = &ast.FunctionCallExpr{Func: $1, Args: $2}
    } |
    prefixexp '.' Ident args {
        $$ = &ast.FunctionCallExpr{Method: $3.Expr, Receiver: $1, Args: $4}
    }

args:
    '(' ')' {
        $$ = []ast.Expr{}
    } |
    '(' exprlist ')' {
        $$ = $1
    }

function:
    Func funcbody {
        $$ = &ast.FuncExpr{ParList:$2.ParList, Stmts: $2.Stmts}
    }

funcbody:
    '(' ')' '{' block '}' {
        $$ = &ast.FunctionExpr{Stmt:$1}
    } |
    '(' parlist ')' '{'  block '}' {
        $$ = &ast.FunctionExpr{Stmts: $4, Args: $2}
    }

parlist:
    Ident Dot3 {
        $$ = &ast.ParList{VaArgs: $1.Str}
    } |
    namelist {
        $$ = &ast.ParList{}
        $$.Names = append($$.Names, $1...)
    } |
    namelist ',' Ident Dot3 {
        $$ = &ast.ParList{VaArgs: $1.Str}
        $$.Names = append($$.Names, $1...)
    }


namelist:
    Ident {
        $$ = []string{$1.Str}
    } |
    namelist ',' Ident {
        $$ = append($1, $3.Str)
    }

mapcontructor:
    '{' '}' {
        $$ = &ast.MapExpr{}
    } |
    '{' mapfieldlist '}' {
        $$ = &ast.MapExpr{Values: $2}
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
    } |
    '[' exprlist ']' {
        $$ = $ast.SliceExpr{Values: $2}
    }

exprlist:
    expr {
        $$ = []ast.Expr{$1}
    } |
    exprList ',' expr {
        $$ = append($1, $3)
    }

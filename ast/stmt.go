package ast

type Stmt interface {
	PositionHolder
	stmtMaker()
}

type StmtImpl struct {
	Stmt
}

func (*StmtImpl) stmtMaker() {}

type AssignStmt struct {
	StmtImpl

	Names []string
	Vars  []Expr
	Exprs []Expr
}

type FuncCallStmt struct {
	StmtImpl
	Expr Expr
}

type ForStmt struct {
	StmtImpl

	Names []string
	Init  []Expr
	Limit Expr
	Step  []Expr
	Stmts []Stmt
}

type ForRangeStmt struct {
	StmtImpl

	Names []string
	Expr  Expr
	Stmts []Stmt
}

type FuncDefineStmt struct {
	StmtImpl

	Stmt []Stmt
}

type BreakStmt struct {
	StmtImpl
}

type GoStmt struct {
	StmtImpl

	Expr Expr
}

type SwitchStmt struct {
	StmtImpl

	Default Stmt
}

type SelectStmt struct {
	StmtImpl

	Cases []Expr
}

type DeferStmt struct {
	StmtImpl

	Expr Expr
}

type ContinueStmt struct {
	StmtImpl
}

type IfStmt struct {
	StmtImpl

	Condition Expr
	Then      []Stmt
	Else      []Stmt
}

type FuncDefStmt struct {
	StmtImpl

	Name *FuncName
	Func Expr
}

type ReturnStmt struct {
	StmtImpl

	Exprs []Expr
}

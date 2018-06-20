package ast

type Stmt interface {
	PositionHolder
	stmtMaker()
}

type StmtImpl struct {
}

type AssignStmt struct {
	StmtImpl
	Lhs []Expr
	Rhs []Expr
}

type FuncCallStmt struct {
	StmtImpl
	Expr Expr
}

type ForStmt struct {
	StmtImpl

	Name  string
	Init  Expr
	Limit Expr
	Step  Expr
	Stmts []Stmt
}

type ForRangeStmt struct {
	StmtImpl

	Names []string
	Expr  Expr
	Stmt  []Stmt
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

	FuncCallStmt
}

type SwitchStmt struct {
	StmtImpl

	Default Stmt
}

type SelectStmt struct {
	StmtImpl

	Default Stmt
}

type DeferStmt struct {
	StmtImpl

	FuncCallStmt
}

type ContinueStmt struct {
	StmtImpl
}

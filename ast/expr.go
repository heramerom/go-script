package ast

type Expr interface {
	exprMaker()
}

type ConstExpr interface {
	Expr
	constExprMaker()
}

type TrueExpr struct {
	ConstExpr
}

type FalseExpr struct {
	ConstExpr
}

type NilExpr struct {
	ConstExpr
}

type NumberExpr struct {
	ConstExpr
	Num string
}

type StringExpr struct {
	Expr
	S string
}

type IdentExpr struct {
	Expr
	Value string
}

type SliceExpr struct {
	Expr
	Values []Expr
}

type MapExpr struct {
	Expr
	Dict map[Expr]Expr
}

type FuncCallExpr struct {
	Expr

	Func      Expr
	Receiver  Expr
	Method    string
	Args      []Expr
	AdjustRet bool
}

type LogicalOpExpr struct {
	Expr

	Operator string
	Lhs      string
	Rhs      string
}

type RelationalOpExpr struct {
	Expr
	Operator string
	Lhs      Expr
	Rhs      Expr
}

type ArithmeticOpExpr struct {
	Expr

	Operator string
	Left     Expr
	Right    Expr
}

type UnaryMinusOpExpr struct {
	Expr
	Value Expr
}

type FunctionExpr struct {
	Expr

	Stmts []Stmt
}

type CaseExpr struct {
	Expr

	Condition []Expr
	Then      []Stmt
}

type ChannelExpr struct {
	Expr

	Sender   Expr
	Receiver Expr
}

type FallThrough struct {
	Expr
}

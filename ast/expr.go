package ast

type Expr interface {
	PositionHolder
	exprMaker()
}

type ExprImpl struct {
	Node
}

func (*ExprImpl) exprMaker() {}

type ConstExpr interface {
	Expr
	constExprMaker()
}

type ConstExprImpl struct {
	ExprImpl
}

func (*ConstExprImpl) constExprMaker() {}

type TrueExpr struct {
	ConstExprImpl
}

type FalseExpr struct {
	ConstExprImpl
}

type NilExpr struct {
	ConstExprImpl
}

type NumberExpr struct {
	ConstExprImpl
	Value string
}

type StringExpr struct {
	ExprImpl
	Value string
}

type IdentExpr struct {
	ExprImpl
	Value string
}

type SliceExpr struct {
	ExprImpl
	Values []Expr
}

type MapExpr struct {
	ExprImpl
	Fields []*Field
}

type FuncCallExpr struct {
	ExprImpl

	Func      Expr
	Receiver  Expr
	Method    string
	Args      []Expr
	AdjustRet bool
}

type LogicalOpExpr struct {
	ExprImpl

	Operator string
	Lhs      Expr
	Rhs      Expr
}

type RelationalOpExpr struct {
	ExprImpl
	Operator string
	Lhs      Expr
	Rhs      Expr
}

type ArithmeticOpExpr struct {
	ExprImpl

	Op  string
	Lhs Expr
	Rhs Expr
}

type UnaryMinusOpExpr struct {
	ExprImpl
	Value Expr
}

type FuncExpr struct {
	ExprImpl

	ParList *ParList
	Stmts []Stmt
}

type CaseExpr struct {
	ExprImpl

	Names   []string
	Chan    Expr
	Stmts   []Stmt
	Default bool
}

type ChanSendExpr struct {
	ExprImpl

	Ch Expr
}

type ChanReceiveExpr struct {
	ExprImpl

	Ch Expr
}

type AttrGetExpr struct {
	ExprImpl

	Object Expr
	Key    Expr
}

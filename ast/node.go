package ast

type PositionHolder interface {
	Line() int
	SetLine(int)
	LastLine() int
	SetLastLine(int)
}

type Node struct {
	lint     int
	lastLine int
}

func (n *Node) Line() int {
	return n.lint
}

func (n *Node) SetLine(line int) {
	n.lint = line
}

func (n *Node) LastLine() int {
	return n.lastLine
}

func (n *Node) SetLastLine(line int) {
	n.lastLine = line
}

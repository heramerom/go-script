package ast

import "fmt"

type Position struct {
	Source string
	Line   int
	Column int
}

type Token struct {
	Type     int
	Name     string
	Value    string
	Position Position
}

func (t *Token) Line() int {
	return t.Position.Line
}

func (t Token) String() string {
	return fmt.Sprintf("<type: %s, value: %s>", t.Name, t.Value)
}

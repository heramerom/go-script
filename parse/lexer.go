package parse

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"strconv"

	"github.com/heramerom/go-script/ast"
)

const EOF = -1
const whitespace1 = 1<<'\t' | 1<<' '
const whitespace2 = 1<<'t' | 1<<'\n' | 1<<'\r' | 1<<' '

type Error struct {
	Pos     ast.Position
	Message string
	Token   string
}

func (e Error) Error() string {
	pos := e.Pos
	if pos.Line == EOF {
		return fmt.Sprintf("%v at EOF: 		%s\n", pos.Source, e.Message)
	} else {
		return fmt.Sprintf("%v line:%d column:%d near '%v':		%s\n", pos.Source, pos.Line, pos.Column, e.Token, e.Message)
	}
	return e.Message
}

func isDecimal(ch int) bool {
	return '0' <= ch && ch <= '9'
}

func isIdent(ch int, pos int) bool {
	return ch == '_' || 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || isDecimal(ch) && pos > 0
}

func isDigit(ch int) bool {
	return '0' <= ch && ch <= '9' || 'a' <= ch && ch <= 'f' || 'A' <= ch && ch <= 'F'
}

type Scanner struct {
	Pos    ast.Position
	reader *bufio.Reader
}

func NewSacnner(reader io.Reader, source string) *Scanner {
	return &Scanner{
		Pos:    ast.Position{Source: source, Line: 1, Column: 0},
		reader: bufio.NewReader(reader),
	}
}

func (sc *Scanner) Error(token string, message string) *Error {
	return &Error{Pos: sc.Pos, Token: token, Message: message}
}

func (sc *Scanner) TokenError(token ast.Token, message string) *Error {
	return &Error{Pos: token.Position, Token: token.Value, Message: message}
}

func (sc *Scanner) readNext() int {
	ch, err := sc.reader.ReadByte()
	if err == io.EOF {
		return EOF
	}
	return int(ch)
}

func (sc *Scanner) Peek() int {
	ch := sc.readNext()
	if ch != EOF {
		sc.reader.UnreadByte()
	}
	return ch
}

func (sc *Scanner) unreadNext(ch int) {
	if ch != EOF {
		sc.reader.UnreadByte()
	}
}

func (sc *Scanner) Next() int {
	ch := sc.readNext()
	switch ch {
	case '\r', '\n':
		sc.NewLine(ch)
		ch = int('\n')
	case EOF:
		sc.Pos.Line = EOF
		sc.Pos.Column = 0
	default:
		sc.Pos.Column++
	}
	return ch
}

func (sc *Scanner) NewLine(ch int) {
	if ch < 0 {
		return
	}
	sc.Pos.Line += 1
	sc.Pos.Column = 0
	next := sc.Peek()
	if ch == '\n' && next == '\r' || ch == '\r' && next == '\n' {
		sc.reader.ReadByte()
	}
}

func (sc *Scanner) skipWhitespace(whitespace int64) int {
	ch := sc.Next()
	for ; whitespace&(1<<uint(ch)) != 0; ch = sc.Next() {
	}
	return ch
}

func (sc *Scanner) skipComments(ch int) error {
	for ch != '\n' && ch != 'r' && ch != EOF {
		ch = sc.readNext()
	}
	return nil
}

func (sc *Scanner) scanIdent(ch int, buf *bytes.Buffer) error {
	for isIdent(ch, 1) {
		buf.WriteByte(byte(ch))
		ch = sc.readNext()
	}
	sc.unreadNext(ch)
	return nil
}

func (sc *Scanner) scanDecimal(ch int, buf *bytes.Buffer) error {
	for isDecimal(ch) {
		buf.WriteByte(byte(ch))
		ch = sc.readNext()
	}
	sc.unreadNext(ch)
	return nil
}

func (sc *Scanner) scanNumber(ch int, buf *bytes.Buffer) error {
	if ch == '0' {
		if sc.Peek() == 'x' || sc.Peek() == 'X' {
			buf.WriteByte(byte(ch))
			buf.WriteByte(byte(sc.Next()))
			has := false
			ch = sc.Next()
			if isDigit(ch) {
				buf.WriteByte(byte(ch))
				ch = sc.readNext()
				has = true
			}
			sc.unreadNext(ch)
			if !has {
				return sc.Error(buf.String(), "illegal hexadecimal number")
			}
			return nil
		} else if sc.Peek() != '.' && isDecimal(sc.Peek()) {
			ch = sc.Next()
		}
	}
	sc.scanDecimal(ch, buf)
	if sc.Peek() == '.' {
		buf.WriteByte(byte(sc.Next()))
		sc.scanDecimal(sc.Next(), buf)
	}
	if ch = sc.Peek(); ch == 'e' || ch == 'E' {
		buf.WriteByte(byte(sc.Next()))
		if ch = sc.Peek(); ch == '-' || ch == '+' {
			buf.WriteByte(byte(sc.Next()))
		}
		sc.scanDecimal(sc.Next(), buf)
	}
	return nil
}

func (sc *Scanner) scanEscape(ch int, buf *bytes.Buffer) error {
	ch = sc.Next()
	switch ch {
	case 'a':
		buf.WriteByte('\a')
	case 'b':
		buf.WriteByte('b')
	case 'f':
		buf.WriteByte('\f')
	case 'n':
		buf.WriteByte('\n')
	case 'r':
		buf.WriteByte('r')
	case 't':
		buf.WriteByte('\t')
	case 'v':
		buf.WriteByte('\v')
	case '\\':
		buf.WriteByte('\\')
	case '"':
		buf.WriteByte('"')
	case '\'':
		buf.WriteByte('\'')
	case '\n':
		buf.WriteByte('\n')
	case '\r':
		buf.WriteByte('\n')
		buf.WriteByte('\r')
	default:
		if '0' <= ch && ch <= '9' {
			bs := []byte{byte(ch)}
			for i := 0; i < 2 && isDecimal(sc.Peek()); i++ {
				bs = append(bs, byte(sc.Next()))
			}
			val, _ := strconv.ParseInt(string(bs), 10, 32)
			buf.WriteByte(byte(val))
		} else {
			buf.WriteByte('\\')
			buf.WriteByte(byte(ch))
			return sc.Error(buf.String(), "invalid escape sequence")
		}
	}

	return nil
}

func (sc *Scanner) scanString(quote int, buf *bytes.Buffer) error {
	ch := sc.Next()
	for ch != quote {
		if ch == '\n' || ch == '\r' || ch < 0 {
			return sc.Error(buf.String(), "unterminated string")
		}
		if ch == '\\' {
			if err := sc.scanEscape(ch, buf); err != nil {
				return err
			}
		} else {
			buf.WriteByte(byte(ch))
		}
		ch = sc.Next()
	}
	return nil
}

func (sc *Scanner) countSep(ch int) (int, int) {
	var count int
	for ; ch == '='; count += 1 {
		ch = sc.Next()
	}
	return count, ch
}

var reserveKeyWords = map[string]int{
	"go": Go, "if": If, "else": Else,
	"for": For, "break": Break, "continue": Continue,
	"func": Func, "return": Return, "nil": Nil,
	"range": Range, "true": True, "false": False,
	"var": Var, "defer": Defer, "select": Select,
}

func (sc *Scanner) Scan(lexer *Lexer) (ast.Token, error) {
redo:
	var err error
	token := ast.Token{}
	newLine := false

	ch := sc.skipWhitespace(whitespace1)
	if ch == '\n' || ch == '\r' {
		newLine = true
		ch = sc.skipWhitespace(whitespace2)
	}

	if ch == '(' && lexer.PrevTokenType == ')' {
		lexer.PNewLine = newLine
	} else {
		lexer.PNewLine = false
	}

	buf := bytes.NewBuffer(nil)
	token.Position = sc.Pos

	if isIdent(ch, 0) {
		token.Type = Ident
		err = sc.scanIdent(ch, buf)
		token.Value = buf.String()
		if err != nil {
			goto finally
		}
		if typ, ok := reserveKeyWords[token.Value]; ok {
			token.Type = typ
		}
		goto finally
	}

	if isDecimal(ch) {
		token.Type = Number
		err = sc.scanNumber(ch, buf)
		token.Value = buf.String()
		goto finally
	}

	switch ch {

	case EOF:
		token.Type = EOF

	case '/':
		if sc.Peek() == '/' {
			err = sc.skipComments(sc.Next())
			if err != nil {
				goto finally
			}
			goto redo
		} else {
			token.Type = ch
			token.Value = string(ch)
		}
	case '"', '\'':
		token.Type = String
		err = sc.scanString(ch, buf)
		token.Value = buf.String()
	case '=':
		if sc.Peek() == '=' {
			token.Type = Eq
			token.Value = "=="
			sc.Next()
		} else {
			token.Type = ch
			token.Value = string(ch)
		}
	case '!':
		if sc.Peek() == '=' {
			token.Type = Neq
			token.Value = "!="
			sc.Next()
		} else {
			err = sc.Error("!", "invalid '!' token")
		}
	case '<':
		switch sc.Peek() {
		case '=':
			token.Type = Lte
			token.Value = "<="
			sc.Next()
		case '-':
			token.Type = ChanOp
			token.Value = "<-"
			sc.Next()
		case '<':
			token.Type = ShiftLeft
			token.Value = "<<"
			sc.Next()
		default:
			token.Type = ch
			token.Value = string(ch)
		}
	case '>':
		switch sc.Peek() {
		case '=':
			token.Type = Gte
			token.Value = ">="
			sc.Next()
		case '>':
			token.Type = ShiftRight
			token.Value = ">>"
			sc.Next()
		default:
			token.Type = ch
			token.Value = string(ch)
		}
	case '|':
		if sc.Peek() == '|' {
			token.Type = Or
			token.Value = "||"
			sc.Next()
		} else {
			token.Type = ch
			token.Value = string(ch)
		}
	case '&':
		if sc.Peek() == '&' {
			token.Type = And
			token.Value = "&&"
			sc.Next()
		} else {
			token.Type = ch
			token.Value = string(ch)
		}

	case '.':
		ch2 := sc.Peek()
		if isDecimal(ch2) {
			token.Type = Number
			err = sc.scanNumber(ch, buf)
			token.Value = buf.String()
		} else if ch2 == '.' {
			buf.WriteByte(byte(ch))
			buf.WriteByte(byte(sc.Next()))
			if sc.Peek() == '.' {
				token.Type = Dot3
				buf.WriteByte(byte(sc.Next()))
				token.Value = buf.String()
			} else {
				err = sc.Error(buf.String(), "invalid token")
			}
		} else {
			token.Type = '.'
		}
		token.Value = buf.String()
	case ':':
		if sc.Peek() == '=' {
			token.Type = QuickVar
			token.Value = ":="
			sc.Next()
		} else {
			token.Type = ch
			token.Value = string(ch)
		}
	case '+', '-', '*', '%', '^', '(', ')', '{', '}', '[', ']', ';', ',':
		token.Type = ch
		token.Value = string(ch)
	default:
		buf.WriteByte(byte(ch))
		err = sc.Error(buf.String(), "invalid token")
		goto finally
	}

finally:
	return token, err
}

type Lexer struct {
	scanner       *Scanner
	Stmts         []ast.Stmt
	PNewLine      bool
	Token         ast.Token
	PrevTokenType int
}

func (lexer *Lexer) Lex(val *yySymType) int {
	lexer.PrevTokenType = lexer.Token.Type
	token, err := lexer.scanner.Scan(lexer)
	if err != nil {
		panic(err)
	}
	if token.Type < 0 {
		return 0
	}
	val.token = token
	lexer.Token = token
	return 0
}

func (lexer *Lexer) Error(message string) {
	panic(lexer.scanner.Error(lexer.Token.String(), message))
}

func (lexer *Lexer) TokenError(token ast.Token, message string) {
	panic(lexer.scanner.TokenError(token, message))
}

func Parse(reader io.Reader, name string) (chunk []ast.Stmt, err error) {
	lexer := &Lexer{
		scanner:       NewSacnner(reader, name),
		Stmts:         nil,
		PNewLine:      false,
		Token:         ast.Token{Value: ""},
		PrevTokenType: Nil,
	}
	defer func() {
		if e := recover(); e != nil {
			err, _ = e.(error)
		}
	}()
	yyParse(lexer)
	chunk = lexer.Stmts
	return
}

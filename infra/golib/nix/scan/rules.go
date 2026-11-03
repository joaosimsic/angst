package scan

import (
	"strings"
	"unicode"
)

const symbolCharacters = "!&()*+,-./:;<=>?@[]{}|"

type tokenRule struct {
	matches func(input string, start int) bool
	scan    func(input string, start int) (int, token, bool)
}

var tokenRules = []tokenRule{
	{matches: startsWhitespace, scan: skipWhitespace},
	{matches: startsLineComment, scan: scanLineComment},
	{matches: startsBlockComment, scan: scanBlockComment},
	{matches: startsQuoted, scan: scanQuoted},
	{matches: startsIndentedString, scan: scanIndentedString},
	{matches: startsAnglePath, scan: scanAnglePath},
	{matches: startsPath, scan: scanPath},
	{matches: startsIdentifier, scan: scanIdentifier},
	{matches: startsNumber, scan: scanNumber},
	{matches: startsSymbol, scan: scanSymbol},
}

func startsWhitespace(input string, start int) bool {
	return unicode.IsSpace(rune(input[start]))
}

func startsLineComment(input string, start int) bool {
	return input[start] == '#'
}

func startsBlockComment(input string, start int) bool {
	return input[start] == '/' && start+1 < len(input) && input[start+1] == '*'
}

func startsQuoted(input string, start int) bool {
	return input[start] == '"'
}

func startsIndentedString(input string, start int) bool {
	return input[start] == '\'' && start+1 < len(input) && input[start+1] == '\''
}

func startsAnglePath(input string, start int) bool {
	return input[start] == '<' && strings.IndexByte(input[start+1:], '>') >= 0
}

func startsPath(input string, start int) bool {
	if input[start] != '/' || start+1 >= len(input) {
		return false
	}

	next := input[start+1]

	return !isPathDelimiter(next) && next != '*' && next != '/'
}

func startsIdentifier(input string, start int) bool {
	return isIdentifierStart(input[start])
}

func startsNumber(input string, start int) bool {
	return input[start] >= '0' && input[start] <= '9'
}

func startsSymbol(input string, start int) bool {
	return strings.IndexByte(symbolCharacters, input[start]) >= 0
}

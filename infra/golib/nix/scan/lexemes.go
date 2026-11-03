package scan

import "strings"

func scanPath(input string, start int) (int, token, bool) {
	i := start + 1
	for i < len(input) && !isPathDelimiter(input[i]) {
		i++
	}

	return i, token{Kind: kindPath, Text: input[start:i]}, true
}

func scanIdentifier(input string, start int) (int, token, bool) {
	i := start + 1
	for i < len(input) && isIdentifierPart(input[i]) {
		i++
	}

	return i, token{Kind: kindIdent, Text: input[start:i]}, true
}

func scanNumber(input string, start int) (int, token, bool) {
	i := start + 1
	for i < len(input) && (input[i] >= '0' && input[i] <= '9' || input[i] == '.') {
		i++
	}

	return i, token{Kind: kindNumber, Text: input[start:i]}, true
}

func scanQuoted(input string, start int) (int, token, bool) {
	i := start + 1
	for i < len(input) {
		if input[i] == '\\' {
			i += 2
			continue
		}

		if input[i] == '"' {
			return i + 1, token{Kind: kindString}, true
		}
		i++
	}

	return i, token{Kind: kindString}, true
}

func scanIndentedString(input string, start int) (int, token, bool) {
	i := start + 2
	for i < len(input) {
		if input[i] == '\'' && i+1 < len(input) && input[i+1] == '\'' {
			if i+2 < len(input) && input[i+2] == '\'' {
				i += 3
				continue
			}

			return i + 2, token{Kind: kindString}, true
		}
		i++
	}

	return i, token{Kind: kindString}, true
}

func scanLineComment(input string, start int) (int, token, bool) {
	i := start
	for i < len(input) && input[i] != '\n' {
		i++
	}

	return i, token{}, false
}

func scanBlockComment(input string, start int) (int, token, bool) {
	i := start + 2
	for i+1 < len(input) {
		if input[i] == '*' && input[i+1] == '/' {
			return i + 2, token{}, false
		}
		i++
	}

	return len(input), token{}, false
}

func skipWhitespace(input string, start int) (int, token, bool) {
	return start + 1, token{}, false
}

func scanAnglePath(input string, start int) (int, token, bool) {
	end := start + strings.IndexByte(input[start+1:], '>') + 2

	return end, token{Kind: kindPath, Text: input[start:end]}, true
}

func scanSymbol(input string, start int) (int, token, bool) {
	return start + 1, token{Kind: kindSymbol, Text: input[start : start+1]}, true
}

func isPathDelimiter(character byte) bool {
	switch character {
	case ' ', '\t', '\n', '\r', ';', ',', ')', ']', '}':
		return true
	}

	return false
}

func isIdentifierStart(character byte) bool {
	return character == '_' || character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z'
}

func isIdentifierPart(character byte) bool {
	return isIdentifierStart(character) || character >= '0' && character <= '9' || character == '\'' || character == '-'
}

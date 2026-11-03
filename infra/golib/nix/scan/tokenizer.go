package scan

import "fmt"

func tokenize(input string) ([]token, error) {
	var tokens []token
	for i := 0; i < len(input); {
		next, current, emit, err := scanToken(input, i)
		if err != nil {
			return nil, err
		}

		if emit {
			tokens = append(tokens, current)
		}
		i = next
	}

	return tokens, nil
}

func scanToken(input string, start int) (int, token, bool, error) {
	for _, rule := range tokenRules {
		if rule.matches(input, start) {
			next, current, emit := rule.scan(input, start)

			return next, current, emit, nil
		}
	}

	return 0, token{}, false, fmt.Errorf("tokenize: unexpected byte %q at offset %d", input[start], start)
}

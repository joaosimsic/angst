package ftp

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"strings"
)

type kv struct {
	key string
	val interface{}
}

type orderedMap []kv

func (m orderedMap) get(k string) (interface{}, bool) {
	for _, e := range m {
		if e.key == k {
			return e.val, true
		}
	}
	return nil, false
}

func (m orderedMap) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, e := range m {
		if i > 0 {
			b.WriteByte(',')
		}
		kb, _ := json.Marshal(e.key)
		vb, _ := json.Marshal(e.val)
		b.Write(kb)
		b.WriteByte(':')
		b.Write(vb)
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}

func decodeValue(d *json.Decoder) (interface{}, error) {
	tok, err := d.Token()
	if err != nil {
		return nil, err
	}
	return buildValue(d, tok)
}

func buildValue(d *json.Decoder, tok json.Token) (interface{}, error) {
	switch t := tok.(type) {
	case json.Delim:
		switch t {
		case '{':
			m := orderedMap{}
			for d.More() {
				kt, err := d.Token()
				if err != nil {
					return nil, err
				}
				key, ok := kt.(string)
				if !ok {
					return nil, fmt.Errorf("unexpected object key token %v", kt)
				}
				v, err := decodeValue(d)
				if err != nil {
					return nil, err
				}
				m = append(m, kv{key, v})
			}
			if _, err := d.Token(); err != nil {
				return nil, err
			}
			return m, nil
		case '[':
			arr := []interface{}{}
			for d.More() {
				v, err := decodeValue(d)
				if err != nil {
					return nil, err
				}
				arr = append(arr, v)
			}
			if _, err := d.Token(); err != nil {
				return nil, err
			}
			return arr, nil
		}
	default:
		return tok, nil
	}
	return nil, fmt.Errorf("unexpected token %v", tok)
}

func jqTostring(v interface{}) string {
	switch t := v.(type) {
	case string:
		return t
	case json.Number:
		return t.String()
	case bool:
		if t {
			return "true"
		}
		return "false"
	case nil:
		return "null"
	default:
		b, err := json.Marshal(v)
		if err != nil {
			return ""
		}
		return string(b)
	}
}

func Transform(confPath string) (remote, path string, ini []byte, err error) {
	f, err := os.Open(confPath)
	if err != nil {
		return "", "", nil, err
	}
	defer f.Close()
	d := json.NewDecoder(f)
	d.UseNumber()
	val, err := decodeValue(d)
	if err != nil {
		return "", "", nil, err
	}
	obj, ok := val.(orderedMap)
	if !ok {
		return "", "", nil, fmt.Errorf("%s: expected a top-level JSON object", confPath)
	}
	if r, ok := obj.get("remote"); ok {
		if s, ok := r.(string); ok {
			remote = s
		}
	}
	pv, ok := obj.get("path")
	if ok && pv != nil {
		path = jqTostring(pv)
	}
	if path == "" {
		path = "/"
	}
	var b strings.Builder
	b.WriteString("[" + remote + "]\n")
	if cfg, ok := obj.get("config"); ok {
		if cm, ok := cfg.(orderedMap); ok {
			for _, e := range cm {
				b.WriteString(e.key + " = " + jqTostring(e.val) + "\n")
			}
		}
	}
	return remote, path, []byte(b.String()), nil
}

package logger

import "testing"

func TestLevelOf(t *testing.T) {
	cases := []struct {
		line string
		want Level
	}{
		{
			line: "[INFO] 08:27:02 Existing file '/home/joao/.config/nvim/lua/backend/adapters/markdown/markdown-preview.nvim/app/out/_next/static/chunks/pages/_error-942918685354aae9.js' is in the way of '/nix/store/g7igkn54ccnfpyd93gr6a2vjcmccq8na-home-manager-files/.config/nvim/lua/backend/adapters/markdown/markdown-preview.nvim/app/out/_next/static/chunks/pages/_error-942918685354aae9.js', will be skipped since they are the same",
			want: INFO,
		},
		{
			line: "error: builder for '/nix/store/abc.drv' failed with exit code 1:",
			want: ERROR,
		},
		{
			line: "[ERROR] 08:27:02 Existing file is in the way",
			want: ERROR,
		},
		{
			line: "error: unable to download 'https://cache.nixos.org'",
			want: ERROR,
		},
		{
			line: "evaluation warning: stdenv.isLinux is deprecated",
			want: WARN,
		},
		{
			line: "[STEP] 08:27:01 Starting Home Manager activation",
			want: STEP,
		},
	}

	for _, c := range cases {
		if got := LevelOf(c.line); got != c.want {
			t.Errorf("LevelOf(%q) = %s, want %s", c.line, got, c.want)
		}
	}
}

package rules

import "testing"

func TestRecipeInvokesKnit(t *testing.T) {
	tests := []struct {
		recipe string
		want   bool
	}{
		// knit as the first command
		{"knit", true},
		{"knit build", true},
		{"knit :all -t clean", true},
		{"knit -C sub build", true},
		// leading whitespace
		{"  knit build", true},
		{"\tknit build", true},
		// leading variable assignments
		{"CC=gcc knit build", true},
		{"A=1 B=2 knit -t clean", true},
		{"VAR=a=b knit x", true},
		// whitespace-separated commands and words that merely start with "knit"
		{"knit\tbuild", true},
		{"knitware build", false},
		{"knitting", false},
		{"echo knit build", false},
		{"", false},
		{"cd x && knit build", false}, // knit after shell operators is not detected
		// strings containing '=' that are not assignments
		{"knit=5", false},
		{"=knit x", false},
		{"A=1", false},
		{"FOO = knit", false},
	}
	for _, tt := range tests {
		if got := recipeInvokesKnit(tt.recipe); got != tt.want {
			t.Errorf("recipeInvokesKnit(%q) = %v, want %v", tt.recipe, got, tt.want)
		}
	}
}

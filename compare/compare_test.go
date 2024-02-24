package compare

import "testing"

func TestFoo(t *testing.T) {
	bar := Foo("foobar")
	if bar != "foobar" {
		t.Errorf("Expected 'foobar' but received '%s'", bar)
	}
}

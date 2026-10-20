package vm

import "testing"

func TestParseStartOptions(t *testing.T) {
	opts := parseStartOptions([]string{"--gtk", "--full-hd", "--detach"})
	if opts.headless {
		t.Fatal("expected gtk to disable headless")
	}
	if !opts.gtk || !opts.fullHD || !opts.detach {
		t.Fatalf("unexpected options: %+v", opts)
	}

	opts = parseStartOptions(nil)
	if !opts.headless || opts.gtk || opts.fullHD || opts.detach {
		t.Fatalf("unexpected defaults: %+v", opts)
	}
}

func TestBuildVMEnv(t *testing.T) {
	headless := buildVMEnv("vm", "/repo", "/shared", "/disk", true, false)
	if !containsEnv(headless, "QEMU_OPTS=-display none -device virtio-gpu-pci,xres=1280,yres=720") {
		t.Fatalf("unexpected headless qemu opts: %v", headless)
	}
	if !containsEnv(headless, "QEMU_KERNEL_PARAMS=video=Virtual-1:1280x720@60e") {
		t.Fatalf("unexpected headless kernel params: %v", headless)
	}

	gtk := buildVMEnv("vm", "/repo", "/shared", "/disk", false, true)
	if !containsEnv(gtk, "QEMU_OPTS=-device virtio-gpu-pci,xres=1920,yres=1080") {
		t.Fatalf("unexpected gtk qemu opts: %v", gtk)
	}
	if !containsEnv(gtk, "QEMU_KERNEL_PARAMS=video=Virtual-1:1920x1080@60e") {
		t.Fatalf("unexpected gtk kernel params: %v", gtk)
	}
}

func containsEnv(env []string, want string) bool {
	for _, item := range env {
		if item == want {
			return true
		}
	}
	return false
}

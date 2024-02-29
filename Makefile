SHELL_FILES := $(wildcard *.sh)

lint:
	@shellcheck --enable=require-variable-braces $(SHELL_FILES) && echo "ShellCheck passed"

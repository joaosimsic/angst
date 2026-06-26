" ShellCheck compiler
CompilerSet makeprg=shellcheck\ -f\ gcc
CompilerSet errorformat=
    \%f:%l:%c:\ %t%*[^:]:\ %m\ [%t%*[^]],
    \%f:%l:%c:\ %t%*[^:]:\ %m,
    %-G%.%#

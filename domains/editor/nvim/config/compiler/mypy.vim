" Mypy compiler
CompilerSet makeprg=mypy\ .
CompilerSet errorformat=
    \%f:%l:\ %t%*[^:]:\ %m,
    \%f:%l:%c:\ %t%*[^:]:\ %m,
    %-G%.%#

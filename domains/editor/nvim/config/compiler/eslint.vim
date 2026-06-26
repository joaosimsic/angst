" ESLint compiler
CompilerSet makeprg=npx\ eslint\ .
CompilerSet errorformat=
    \%f:\ line\ %l\\,\ col\ %c\\,\ %m\ (%t%*[^)])\ [%t%*[^]],
    \%f:\ line\ %l\\,\ col\ %c\\,\ %m,
    \%f:%l:%c:\ %m,
    %-G%.%#

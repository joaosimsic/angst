" Rust compiler (cargo check)
CompilerSet makeprg=cargo\ check
CompilerSet errorformat=
    \%-error:\ %m,
    \%warning:\ %m,
    \%-->\ %f:%l:%c,
    %m

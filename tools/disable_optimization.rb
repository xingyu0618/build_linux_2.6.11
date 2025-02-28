replace_text=<<EOF
#if defined(__OPTIMIZE__)
#error "optimization is enabled"
#endif
#if defined(__GNUC__) && (__GNUC__ >= 2) // && defined(__OPTIMIZE__)
EOF
target_text='#if defined(__GNUC__) && (__GNUC__ >= 2) && defined(__OPTIMIZE__)'

if $.==155 and $_.strip == target_text
 print replace_text
else
  print
end

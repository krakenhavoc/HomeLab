# Included by every location in default.conf that serves files.
#
# Cross-origin isolation. Only a threaded Godot export needs it; the current
# export is single-threaded. It's set anyway so switching to threads needs no
# change here, and it costs nothing: the game loads nothing cross-origin.
add_header Cross-Origin-Opener-Policy "same-origin" always;
add_header Cross-Origin-Embedder-Policy "require-corp" always;
add_header Cross-Origin-Resource-Policy "same-origin" always;
add_header X-Content-Type-Options "nosniff" always;

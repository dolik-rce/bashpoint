#!/bin/bash

# Simple wrapper around catimg (https://github.com/posva/catimg)

# Usage:
#   All the parameters are passed to catimg, the result
#   is printed to the standard output.

# Example:
#   ./catimg_wrapper.sh -w 58 -r2 my_image.png > my_slide

sed '
    # colored pixels
    s|\x1b\[0;38;2;\([0-9]*;[0-9]*;[0-9]*\)m▀|<bg \1>▀</bg>|g;
    s|\x1b\[0;38;2;\([0-9]*;[0-9]*;[0-9]*\)m▄|<fg \1>▄</fg>|g;
    s|\x1b\[48;2;\([0-9]*;[0-9]*;[0-9]*\)m\x1b\[38;2;\([0-9]*;[0-9]*;[0-9]*\)m▄|<fg \1><bg \2>▄</fg></bg>|g;

    # delete cursor save & hide
    s|\x1b\[s\x1b\[?25l||g;
    # delete cursor show
    s|\x1b\[?25h||g;

    # everything else
    s|\x1b\[m||g;

    # some editors strip whitespace at the end of line,
    # lets add a no-op tag to prevent it
    s| $| <nop>|g;' < <(catimg "$@")

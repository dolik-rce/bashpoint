Bashpoint
=========

Bashpoint is simple presentation tool for text interface.

It runs in terminal or in console and is driven by keyboard only.

The presentations are writen in simple HTML-like markup language.

Demo:
-----

To see what bashpoint can do, just run

        ./bashpoint.sh examples/demo.slides

In case you are to lazy to clone this repo, here is a picture:

![Demo](bashpoint.gif)

Usage:
------

Run a single-file presentation:

        ./bashpoint.sh [--debug] my_file

Run a multi-file presentation:

        ./bashpoint.sh [--debug] my_file_1 my_file_2, ...

Run a presentation suing all files in directory (or multiple directories):

        ./bashpoint.sh [--debug] my_directory ...

Bashpoint
=========

Bashpoint is simple but capable presentation tool with textual interface.

It runs in terminal or in console and is driven by keyboard only.

The presentations are writen in simple HTML-like markup language.

Demo:
-----

To see what bashpoint can do, just run

        ./bashpoint.sh examples/demo.slides

In case you are too lazy to clone this repo, here is a picture:

![Demo](bashpoint.gif)

Usage:
------

Run a single-file presentation:
```bash
./bashpoint.sh [--debug] my_file
```

Run a multi-file presentation:
```bash
./bashpoint.sh [--debug] my_file_1 my_file_2 ...
```

Run a presentation using all files in directory (or multiple directories):
```bash
./bashpoint.sh [--debug] my_directory ...
```
